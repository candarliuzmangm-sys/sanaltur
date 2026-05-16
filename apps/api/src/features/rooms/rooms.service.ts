import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { RoomType } from '@prisma/client';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { StorageService } from '../../shared/storage/storage.service';
import { mapRoom, roomInclude } from '../../shared/mappers/room.mapper';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';

@Injectable()
export class RoomsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async listByProperty(userId: string, propertyId: string) {
    await this.ensurePropertyOwner(userId, propertyId);
    const rooms = await this.prisma.room.findMany({
      where: { propertyId },
      include: roomInclude,
      orderBy: { order: 'asc' },
    });
    return rooms.map(mapRoom);
  }

  async findOne(userId: string, propertyId: string, roomId: string) {
    await this.ensurePropertyOwner(userId, propertyId);
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, propertyId },
      include: roomInclude,
    });
    if (!room) throw new NotFoundException('Room not found');
    return mapRoom(room);
  }

  async create(userId: string, propertyId: string, dto: CreateRoomDto) {
    await this.ensurePropertyOwner(userId, propertyId);
    const count = await this.prisma.room.count({ where: { propertyId } });

    const room = await this.prisma.room.create({
      data: {
        name: dto.name,
        type: dto.type as RoomType,
        userSelectedType: (dto.userSelectedType ?? dto.type) as RoomType,
        propertyId,
        order: count,
      },
      include: roomInclude,
    });
    return mapRoom(room);
  }

  async update(
    userId: string,
    propertyId: string,
    roomId: string,
    dto: UpdateRoomDto,
  ) {
    await this.ensurePropertyOwner(userId, propertyId);
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, propertyId },
    });
    if (!room) throw new NotFoundException('Room not found');

    const updated = await this.prisma.room.update({
      where: { id: roomId },
      data: {
        type: dto.type as RoomType | undefined,
        userSelectedType: dto.userSelectedType as RoomType | undefined,
        name: dto.name,
        coverPhotoUrl: dto.coverPhotoUrl,
      },
      include: roomInclude,
    });
    return mapRoom(updated);
  }

  async reorder(userId: string, propertyId: string, roomIds: string[]) {
    await this.ensurePropertyOwner(userId, propertyId);
    const rooms = await this.prisma.room.findMany({
      where: { propertyId },
    });
    const validIds = new Set(rooms.map((r) => r.id));
    for (const id of roomIds) {
      if (!validIds.has(id)) {
        throw new NotFoundException(`Room ${id} not found`);
      }
    }
    await this.prisma.$transaction(
      roomIds.map((id, index) =>
        this.prisma.room.update({
          where: { id },
          data: { order: index },
        }),
      ),
    );
    return this.listByProperty(userId, propertyId);
  }

  async remove(userId: string, propertyId: string, roomId: string) {
    await this.ensurePropertyOwner(userId, propertyId);
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, propertyId },
      include: { media: true },
    });
    if (!room) throw new NotFoundException('Room not found');

    const keys = room.media.map((m) => m.key);
    await this.prisma.room.delete({ where: { id: roomId } });
    await Promise.all(keys.map((k) => this.storage.deleteObject(k)));
    return { success: true };
  }

  private async ensurePropertyOwner(userId: string, propertyId: string) {
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
    });
    if (!property) throw new NotFoundException('Property not found');
    if (property.userId !== userId) throw new ForbiddenException();
  }
}
