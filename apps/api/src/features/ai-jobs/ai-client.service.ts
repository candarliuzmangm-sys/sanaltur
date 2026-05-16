import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

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
      return mockFloorplan(payload);
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

function mockFloorplan(payload: {
  propertyId: string;
  rooms: Array<{ id: string; name?: string; type: string }>;
}) {
  const cols = Math.ceil(Math.sqrt(payload.rooms.length));
  const cellSize = 100;
  const padding = 20;
  const layoutRooms = payload.rooms.map((r, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    const w = typicalWidth(r.type);
    const h = typicalHeight(r.type);
    return {
      id: r.id,
      name: r.name ?? friendlyType(r.type),
      type: r.type,
      x: padding + col * cellSize,
      y: padding + row * cellSize,
      width: w,
      height: h,
    };
  });

  const width = padding * 2 + cols * cellSize;
  const rows = Math.ceil(payload.rooms.length / cols);
  const height = padding * 2 + rows * cellSize;
  const totalArea = layoutRooms.reduce(
    (sum, r) => sum + (r.width * r.height) / 100,
    0,
  );

  const rects = layoutRooms
    .map(
      (r) =>
        `<g><rect x="${r.x}" y="${r.y}" width="${r.width}" height="${r.height}" fill="${typeColor(r.type)}" stroke="#222" stroke-width="2"/><text x="${r.x + r.width / 2}" y="${r.y + r.height / 2}" text-anchor="middle" dominant-baseline="middle" font-family="Inter,sans-serif" font-size="11" fill="#111">${escapeXml(r.name)}</text></g>`,
    )
    .join('');

  const svgContent =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">` +
    `<rect width="100%" height="100%" fill="#f8fafc"/>` +
    rects +
    `</svg>`;

  return {
    svgContent,
    estimatedAreaSqm: Math.round(totalArea),
    rooms: layoutRooms,
  };
}

function typicalWidth(type: string): number {
  if (type === 'LIVING_ROOM' || type === 'DINING_ROOM') return 90;
  if (type === 'KITCHEN') return 70;
  if (type === 'BATHROOM' || type === 'BALCONY') return 50;
  return 70;
}

function typicalHeight(type: string): number {
  if (type === 'LIVING_ROOM') return 80;
  if (type === 'BATHROOM') return 50;
  if (type === 'BALCONY' || type === 'HALLWAY') return 40;
  return 70;
}

function typeColor(type: string): string {
  const colors: Record<string, string> = {
    LIVING_ROOM: '#c7e8d0',
    KITCHEN: '#fde2c5',
    BEDROOM: '#cfe6ff',
    BATHROOM: '#e3d6f6',
    DINING_ROOM: '#f7d9d4',
    HALLWAY: '#e9eaee',
    BALCONY: '#c9efe2',
    OFFICE: '#fff1b3',
    OTHER: '#e6e6e6',
  };
  return colors[type] ?? '#e6e6e6';
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
