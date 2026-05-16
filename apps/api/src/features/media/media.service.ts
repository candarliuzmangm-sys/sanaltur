import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MediaType } from '@prisma/client';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { mapRoom, roomInclude } from '../../shared/mappers/room.mapper';
import { StorageService } from '../../shared/storage/storage.service';
import { RoomClassificationService } from '../ai-jobs/room-classification.service';
import { ConfirmMediaDto } from './dto/confirm-media.dto';
import { PresignMediaDto } from './dto/presign-media.dto';

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly roomClassification: RoomClassificationService,
  ) {}

  async uploadFile(
    userId: string,
    roomId: string,
    file: Express.Multer.File,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('File is required');
    }

    const room = await this.ensureRoomOwner(userId, roomId);
    const mimeType = file.mimetype || 'image/jpeg';
    const fileName = file.originalname || 'photo.jpg';
    const key = this.storage.buildKey(`rooms/${roomId}`, fileName);

    let url: string;
    if (this.storage.mode === 'local') {
      url = await this.storage.saveLocal(file.buffer, key);
    } else {
      const uploadUrl = await this.storage.getPresignedUploadUrl(key, mimeType);
      const response = await fetch(uploadUrl, {
        method: 'PUT',
        headers: { 'Content-Type': mimeType },
        body: new Uint8Array(file.buffer),
      });
      if (!response.ok) {
        throw new BadRequestException('Failed to upload to object storage');
      }
      url = this.storage.getPublicUrl(key);
    }

    const mediaType = mimeType.startsWith('video/')
      ? MediaType.VIDEO
      : MediaType.IMAGE;

    const media = await this.prisma.media.create({
      data: {
        key,
        url,
        mimeType,
        type: mediaType,
        fileName,
        roomId,
      },
    });

    if (mediaType === MediaType.IMAGE) {
      const roomUpdates: { coverPhotoUrl?: string } = {};
      if (!room.coverPhotoUrl) roomUpdates.coverPhotoUrl = url;
      if (Object.keys(roomUpdates).length) {
        await this.prisma.room.update({
          where: { id: roomId },
          data: roomUpdates,
        });
      }
      if (!room.property.coverImageUrl) {
        await this.prisma.property.update({
          where: { id: room.propertyId },
          data: { coverImageUrl: url },
        });
      }
    }

    await this.roomClassification.classifyAndUpdateRoom(roomId);
    const mappedRoom = await this.getMappedRoom(roomId);

    return {
      media: {
        id: media.id,
        url: media.url,
        mimeType: media.mimeType,
        type: media.type,
        fileName: media.fileName,
        createdAt: media.createdAt,
      },
      room: mappedRoom,
    };
  }

  async presign(userId: string, roomId: string, dto: PresignMediaDto) {
    if (this.storage.mode === 'local') {
      return {
        mode: 'local' as const,
        uploadUrl: null,
        key: null,
      };
    }

    await this.ensureRoomOwner(userId, roomId);
    const key = this.storage.buildKey(`rooms/${roomId}`, dto.fileName);
    const uploadUrl = await this.storage.getPresignedUploadUrl(
      key,
      dto.mimeType,
    );
    return { mode: 'r2' as const, uploadUrl, key };
  }

  async confirm(userId: string, roomId: string, dto: ConfirmMediaDto) {
    const room = await this.ensureRoomOwner(userId, roomId);
    const url = this.storage.getPublicUrl(dto.key);
    const mediaType = dto.mimeType.startsWith('video/')
      ? MediaType.VIDEO
      : MediaType.IMAGE;

    const media = await this.prisma.media.create({
      data: {
        key: dto.key,
        url,
        mimeType: dto.mimeType,
        type: mediaType,
        fileName: dto.fileName,
        roomId,
      },
    });

    if (mediaType === MediaType.IMAGE) {
      if (!room.coverPhotoUrl) {
        await this.prisma.room.update({
          where: { id: roomId },
          data: { coverPhotoUrl: url },
        });
      }
      if (!room.property.coverImageUrl) {
        await this.prisma.property.update({
          where: { id: room.propertyId },
          data: { coverImageUrl: url },
        });
      }
    }

    await this.roomClassification.classifyAndUpdateRoom(roomId);
    const mappedRoom = await this.getMappedRoom(roomId);

    return {
      media: {
        id: media.id,
        url: media.url,
        mimeType: media.mimeType,
        type: media.type,
        fileName: media.fileName,
        createdAt: media.createdAt,
      },
      room: mappedRoom,
    };
  }

  async remove(userId: string, roomId: string, mediaId: string) {
    await this.ensureRoomOwner(userId, roomId);
    const media = await this.prisma.media.findFirst({
      where: { id: mediaId, roomId },
    });
    if (!media) throw new NotFoundException('Media not found');

    await this.prisma.media.delete({ where: { id: mediaId } });
    await this.storage.deleteObject(media.key);

    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      include: { property: true, media: { orderBy: { createdAt: 'desc' } } },
    });

    if (room) {
      if (room.coverPhotoUrl === media.url) {
        const nextRoomCover = room.media[0]?.url ?? null;
        await this.prisma.room.update({
          where: { id: roomId },
          data: { coverPhotoUrl: nextRoomCover },
        });
      }
      if (room.property.coverImageUrl === media.url) {
        const nextCover = room.media[0]?.url ?? null;
        await this.prisma.property.update({
          where: { id: room.propertyId },
          data: { coverImageUrl: nextCover },
        });
      }
    }

    return { success: true };
  }

  private async getMappedRoom(roomId: string) {
    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      include: roomInclude,
    });
    if (!room) throw new NotFoundException('Room not found');
    return mapRoom(room);
  }

  private async ensureRoomOwner(userId: string, roomId: string) {
    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      include: { property: true },
    });
    if (!room) throw new NotFoundException('Room not found');
    if (room.property.userId !== userId) throw new ForbiddenException();
    return room;
  }
}
