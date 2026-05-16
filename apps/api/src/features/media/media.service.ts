import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MediaType } from '@prisma/client';

import { StabilityClientService } from '../../shared/ai/stability-client.service';
import { PrismaService } from '../../shared/prisma/prisma.service';
import { mapRoom, roomInclude } from '../../shared/mappers/room.mapper';
import { StorageService } from '../../shared/storage/storage.service';
import { RoomClassificationService } from '../ai-jobs/room-classification.service';
import { ConfirmMediaDto } from './dto/confirm-media.dto';
import { EditMediaDto } from './dto/edit-media.dto';
import { PresignMediaDto } from './dto/presign-media.dto';

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);
  private readonly aiServiceUrl: string;
  private readonly aiMock: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
    private readonly roomClassification: RoomClassificationService,
    private readonly stability: StabilityClientService,
    config: ConfigService,
  ) {
    this.aiServiceUrl = config.get<string>(
      'AI_SERVICE_URL',
      'http://localhost:8000',
    );
    const flag = (config.get<string>('AI_MOCK') ?? '').toLowerCase();
    this.aiMock = flag === '1' || flag === 'true' || flag === 'yes';
  }

  async uploadFile(
    userId: string,
    roomId: string,
    file: Express.Multer.File,
    typeHint?: 'IMAGE' | 'PANORAMA' | 'VIDEO',
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

    const mediaType = resolveMediaType(mimeType, typeHint);

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

    if (mediaType !== MediaType.VIDEO) {
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
    const mediaType = resolveMediaType(dto.mimeType, dto.mediaType);

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

    if (mediaType !== MediaType.VIDEO) {
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

  /**
   * Mevcut bir foto üzerinde AI edit yapar (Stability AI).
   * `asNewMedia=false` ise yalnız preview döner (yeni medya oluşturmaz).
   */
  async editMedia(
    userId: string,
    roomId: string,
    mediaId: string,
    dto: EditMediaDto,
  ) {
    const room = await this.ensureRoomOwner(userId, roomId);
    const media = await this.prisma.media.findFirst({
      where: { id: mediaId, roomId },
    });
    if (!media) throw new NotFoundException('Media not found');
    if (media.type === MediaType.VIDEO) {
      throw new BadRequestException('Video düzenleme desteklenmiyor');
    }

    // Orijinal binary'i çek (storage'tan)
    const original = await this.storage.readObject(media.key);
    if (!original) {
      throw new BadRequestException('Orijinal dosya okunamadı');
    }

    let result;
    switch (dto.op) {
      case 'erase':
        // Stability'nin /erase endpoint'i alpha-channel mask gerektirir.
        // Mobil/web'de mask çizimi yok — bu yüzden search-and-replace ile
        // "tüm eşyalar -> boş oda" yaparak pratik boşaltma sağlıyoruz.
        result = await this.stability.searchAndReplace({
          image: original,
          searchPrompt:
            dto.target ??
            'furniture, sofa, couch, chairs, table, bed, lamps, rug, decoration, plants, frames',
          prompt:
            dto.prompt ??
            'empty clean room, polished wooden floor, white walls, natural soft daylight, professional real estate photo, no objects',
        });
        break;
      case 'inpaint':
        if (!dto.prompt) {
          throw new BadRequestException('inpaint için prompt zorunlu');
        }
        // Mask yoksa: search-and-replace ile boş yere ekleme yap.
        // search="empty floor / empty space" -> replace=prompt
        result = await this.stability.searchAndReplace({
          image: original,
          searchPrompt:
            dto.target ?? 'empty floor, empty space, blank area in center',
          prompt: dto.prompt,
        });
        break;
      case 'replace':
        if (!dto.target || !dto.prompt) {
          throw new BadRequestException(
            'replace için target ve prompt zorunlu',
          );
        }
        result = await this.stability.searchAndReplace({
          image: original,
          searchPrompt: dto.target,
          prompt: dto.prompt,
        });
        break;
      case 'recolor':
        if (!dto.target || !dto.prompt) {
          throw new BadRequestException(
            'recolor için target ve prompt zorunlu',
          );
        }
        result = await this.stability.searchAndRecolor({
          image: original,
          selectPrompt: dto.target,
          prompt: dto.prompt,
        });
        break;
      case 'outpaint':
        result = await this.stability.outpaint({
          image: original,
          left: 256,
          right: 256,
          prompt: dto.prompt,
        });
        break;
      default:
        throw new BadRequestException('Bilinmeyen op');
    }

    // Eğer kullanıcı önizleme istiyorsa yeni medya oluşturma
    if (dto.asNewMedia === false) {
      const dataUrl = `data:${result.mimeType};base64,${result.buffer.toString('base64')}`;
      return { previewDataUrl: dataUrl };
    }

    // Yeni medya olarak kaydet
    const ext = result.mimeType.includes('png') ? 'png' : 'jpg';
    const newName = `${media.fileName?.split('.')[0] ?? 'edit'}-${dto.op}.${ext}`;
    const key = this.storage.buildKey(`rooms/${roomId}`, newName);

    let url: string;
    if (this.storage.mode === 'local') {
      url = await this.storage.saveLocal(result.buffer, key);
    } else {
      const uploadUrl = await this.storage.getPresignedUploadUrl(
        key,
        result.mimeType,
      );
      const resp = await fetch(uploadUrl, {
        method: 'PUT',
        headers: { 'Content-Type': result.mimeType },
        body: new Uint8Array(result.buffer),
      });
      if (!resp.ok) {
        throw new BadRequestException('AI sonucu storage\'a yüklenemedi');
      }
      url = this.storage.getPublicUrl(key);
    }

    const newMedia = await this.prisma.media.create({
      data: {
        key,
        url,
        mimeType: result.mimeType,
        type: media.type, // aynı tip (PANORAMA ise PANORAMA)
        fileName: newName,
        roomId,
      },
    });

    const mappedRoom = await this.getMappedRoom(roomId);
    return {
      media: {
        id: newMedia.id,
        url: newMedia.url,
        mimeType: newMedia.mimeType,
        type: newMedia.type,
        fileName: newMedia.fileName,
        createdAt: newMedia.createdAt,
      },
      room: mappedRoom,
      source: { id: media.id, url: media.url },
      op: dto.op,
    };
  }

  /**
   * Birden çok fotoyu birleştirip PANORAMA medya olarak kaydeder.
   * - AI_MOCK=true veya ai-service erişilemez ise: ilk fotoyu PANORAMA olarak kaydet.
   * - Aksi halde ai-service /ai/panorama/stitch'e POST eder, sonucu kaydeder.
   */
  async stitchPanorama(
    userId: string,
    roomId: string,
    files: Express.Multer.File[],
  ) {
    if (!files || files.length < 2) {
      throw new BadRequestException('En az 2 fotoğraf gerekli');
    }
    if (files.length > 12) {
      throw new BadRequestException('En fazla 12 fotoğraf');
    }
    const room = await this.ensureRoomOwner(userId, roomId);

    let panoBuffer: Buffer;
    let mimeType = 'image/jpeg';
    let mode: 'real' | 'mock-first-photo' = 'real';

    if (this.aiMock) {
      // Mock mode: ilk fotoyu döndür (panorama gibi)
      panoBuffer = files[0]!.buffer;
      mimeType = files[0]!.mimetype || 'image/jpeg';
      mode = 'mock-first-photo';
      this.logger.warn(
        'AI_MOCK=true — panorama stitching mock (ilk foto kaydedildi)',
      );
    } else {
      try {
        const form = new FormData();
        for (const f of files) {
          form.append(
            'files',
            new Blob([new Uint8Array(f.buffer)], { type: f.mimetype }),
            f.originalname,
          );
        }
        const resp = await fetch(`${this.aiServiceUrl}/ai/panorama/stitch`, {
          method: 'POST',
          body: form,
        });
        if (!resp.ok) {
          const text = await resp.text();
          this.logger.error(
            `ai-service panorama HTTP ${resp.status}: ${text.slice(0, 200)}`,
          );
          // Stitch başarısız → fallback: ilk fotoyu PANORAMA olarak kullan
          panoBuffer = files[0]!.buffer;
          mimeType = files[0]!.mimetype || 'image/jpeg';
          mode = 'mock-first-photo';
        } else {
          panoBuffer = Buffer.from(await resp.arrayBuffer());
          mimeType = resp.headers.get('content-type') ?? 'image/jpeg';
        }
      } catch (err) {
        this.logger.error(
          `ai-service unreachable: ${(err as Error).message} — fallback to first photo`,
        );
        panoBuffer = files[0]!.buffer;
        mimeType = files[0]!.mimetype || 'image/jpeg';
        mode = 'mock-first-photo';
      }
    }

    // Storage'a yaz
    const ext = mimeType.includes('png') ? 'png' : 'jpg';
    const key = this.storage.buildKey(`rooms/${roomId}`, `panorama.${ext}`);
    let url: string;
    if (this.storage.mode === 'local') {
      url = await this.storage.saveLocal(panoBuffer, key);
    } else {
      const uploadUrl = await this.storage.getPresignedUploadUrl(
        key,
        mimeType,
      );
      const resp = await fetch(uploadUrl, {
        method: 'PUT',
        headers: { 'Content-Type': mimeType },
        body: new Uint8Array(panoBuffer),
      });
      if (!resp.ok) {
        throw new ServiceUnavailableException(
          'Panorama storage\'a yüklenemedi',
        );
      }
      url = this.storage.getPublicUrl(key);
    }

    const media = await this.prisma.media.create({
      data: {
        key,
        url,
        mimeType,
        type: MediaType.PANORAMA,
        fileName: `panorama.${ext}`,
        roomId,
      },
    });

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
      mode,
      sourcePhotos: files.length,
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

function resolveMediaType(
  mimeType: string,
  hint?: 'IMAGE' | 'PANORAMA' | 'VIDEO',
): MediaType {
  if (hint === 'PANORAMA') return MediaType.PANORAMA;
  if (hint === 'VIDEO' || mimeType.startsWith('video/')) return MediaType.VIDEO;
  if (hint === 'IMAGE') return MediaType.IMAGE;
  return MediaType.IMAGE;
}
