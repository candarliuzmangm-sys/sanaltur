import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { buildSmartFloorplan } from '../../shared/floorplan/smart-floorplan';

@Injectable()
export class AiClientService {
  private readonly logger = new Logger(AiClientService.name);
  private readonly baseUrl: string;
  private readonly mock: boolean;

  constructor(config: ConfigService) {
    this.baseUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
    const mockFlag = (config.get<string>('AI_MOCK') ?? '').toLowerCase();
    this.mock = mockFlag === '1' || mockFlag === 'true' || mockFlag === 'yes';
    if (this.mock) {
      this.logger.log('AI service running in MOCK mode (no external calls)');
    }
  }

  async classifyRoom(payload: {
    roomId: string;
    imageUrls: string[];
    userType?: string;
  }): Promise<{ predictedType: string; confidence: number }> {
    if (this.mock) {
      return {
        predictedType: payload.userType ?? 'OTHER',
        confidence: 0.6,
      };
    }
    return this.post('/ai/classify-room', payload);
  }

  async classifyRooms(payload: {
    propertyId: string;
    rooms: Array<{ id: string; imageUrls: string[]; userType?: string }>;
  }) {
    if (this.mock) {
      return {
        classifications: payload.rooms.map((r) => ({
          roomId: r.id,
          predictedType: r.userType ?? 'OTHER',
          confidence: 0.6,
        })),
      };
    }
    return this.post('/ai/classify-rooms', payload);
  }

  async orderRooms(payload: {
    propertyId: string;
    rooms: Array<{ id: string; type: string }>;
  }) {
    if (this.mock) {
      const priority: Record<string, number> = {
        LIVING_ROOM: 0,
        KITCHEN: 1,
        DINING_ROOM: 2,
        BEDROOM: 3,
        BATHROOM: 4,
        HALLWAY: 5,
        BALCONY: 6,
        OFFICE: 7,
        OTHER: 99,
      };
      const sorted = [...payload.rooms].sort(
        (a, b) =>
          (priority[a.type] ?? 50) - (priority[b.type] ?? 50),
      );
      return { roomIds: sorted.map((r) => r.id) };
    }
    return this.post('/ai/order-rooms', payload);
  }

  async generateFloorplan(payload: {
    propertyId: string;
    rooms: Array<{ id: string; name?: string; type: string; imageUrls: string[] }>;
  }) {
    if (this.mock) {
      const r = buildSmartFloorplan(payload.rooms);
      return {
        svgContent: r.svgContent,
        estimatedAreaSqm: r.estimatedAreaSqm,
        rooms: r.rooms,
      };
    }
    return this.post('/ai/generate-floorplan', payload);
  }

  async generateDescription(payload: {
    title: string;
    address?: string;
    rooms: Array<{ name: string; type: string; mediaCount: number }>;
  }): Promise<{ description: string }> {
    if (this.mock) {
      const roomList = payload.rooms
        .map((r) => `${r.name} (${friendlyType(r.type)})`)
        .join(', ');
      const address = payload.address ? ` ${payload.address} adresindeki` : '';
      const description =
        `${payload.title},${address} ${payload.rooms.length} odadan oluşan modern bir gayrimenkuldür. ` +
        (roomList ? `İçeriğinde ${roomList} bulunmaktadır. ` : '') +
        'Aydınlık ve ferah yaşam alanları, pratik kullanım için tasarlanmıştır.';
      return { description };
    }
    return this.post('/ai/generate-description', payload);
  }

  private async post(path: string, body: unknown) {
    try {
      const response = await fetch(`${this.baseUrl}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const text = await response.text();
        this.logger.error(`AI service error: ${text}`);
        throw new Error(`AI service failed: ${response.status}`);
      }

      return response.json();
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      throw new Error(`AI service unreachable (${this.baseUrl}${path}): ${msg}`);
    }
  }
}

function friendlyType(type: string): string {
  const map: Record<string, string> = {
    LIVING_ROOM: 'salon',
    KITCHEN: 'mutfak',
    BEDROOM: 'yatak odası',
    BATHROOM: 'banyo',
    DINING_ROOM: 'yemek odası',
    HALLWAY: 'koridor',
    BALCONY: 'balkon',
    OFFICE: 'çalışma odası',
    OTHER: 'oda',
  };
  return map[type] ?? 'oda';
}

