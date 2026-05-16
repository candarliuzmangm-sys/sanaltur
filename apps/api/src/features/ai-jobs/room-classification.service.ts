import { Injectable, Logger } from '@nestjs/common';
import { RoomType } from '@prisma/client';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { AiClientService } from './ai-client.service';

@Injectable()
export class RoomClassificationService {
  private readonly logger = new Logger(RoomClassificationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiClient: AiClientService,
  ) {}

  async classifyAndUpdateRoom(roomId: string) {
    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      include: { media: { orderBy: { createdAt: 'desc' }, take: 5 } },
    });

    if (!room || room.media.length === 0) {
      return null;
    }

    try {
      const result = await this.aiClient.classifyRoom({
        roomId: room.id,
        imageUrls: room.media.map((m) => m.url),
        userType: room.userSelectedType ?? room.type,
      });

      const updated = await this.prisma.room.update({
        where: { id: roomId },
        data: {
          aiDetectedType: result.predictedType as RoomType,
          aiConfidence: result.confidence,
          type: result.predictedType as RoomType,
        },
      });

      return updated;
    } catch (error) {
      this.logger.warn(
        `AI classify failed for room ${roomId}, using user type fallback`,
        error,
      );

      const fallbackType = (room.userSelectedType ?? room.type) as RoomType;
      return this.prisma.room.update({
        where: { id: roomId },
        data: {
          aiDetectedType: fallbackType,
          aiConfidence: 0.5,
        },
      });
    }
  }
}
