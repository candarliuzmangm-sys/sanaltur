import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AiClientService {
  private readonly logger = new Logger(AiClientService.name);
  private readonly baseUrl: string;

  constructor(config: ConfigService) {
    this.baseUrl = config.get('AI_SERVICE_URL', 'http://localhost:8000');
  }

  async classifyRoom(payload: {
    roomId: string;
    imageUrls: string[];
    userType?: string;
  }): Promise<{ predictedType: string; confidence: number }> {
    return this.post('/ai/classify-room', payload);
  }

  async classifyRooms(payload: {
    propertyId: string;
    rooms: Array<{ id: string; imageUrls: string[]; userType?: string }>;
  }) {
    return this.post('/ai/classify-rooms', payload);
  }

  async orderRooms(payload: {
    propertyId: string;
    rooms: Array<{ id: string; type: string }>;
  }) {
    return this.post('/ai/order-rooms', payload);
  }

  async generateFloorplan(payload: {
    propertyId: string;
    rooms: Array<{ id: string; name?: string; type: string; imageUrls: string[] }>;
  }) {
    return this.post('/ai/generate-floorplan', payload);
  }

  async generateDescription(payload: {
    title: string;
    address?: string;
    rooms: Array<{ name: string; type: string; mediaCount: number }>;
  }): Promise<{ description: string }> {
    return this.post('/ai/generate-description', payload);
  }

  private async post(path: string, body: unknown) {
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
  }
}
