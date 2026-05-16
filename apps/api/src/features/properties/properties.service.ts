import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PropertyCategory, PropertyStatus, RoomType } from '@prisma/client';
import { randomBytes } from 'crypto';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { StorageService } from '../../shared/storage/storage.service';
import { mapRoom, roomInclude } from '../../shared/mappers/room.mapper';
import { buildTourGraph } from '../../shared/tour/tour-graph.builder';
import {
  mapTourGraphToPublic,
  normalizeStoredGraph,
} from '../../shared/tour/tour-mapper';
import {
  buildShareUrls,
  resolvePublicMediaUrl,
} from '../../shared/utils/public-url.util';
import { AiClientService } from '../ai-jobs/ai-client.service';
import { AiJobsService } from '../ai-jobs/ai-jobs.service';
import { CreatePropertyDto } from './dto/create-property.dto';
import { UpdatePropertyDto } from './dto/update-property.dto';

@Injectable()
export class PropertiesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly aiJobs: AiJobsService,
    private readonly storage: StorageService,
    private readonly aiClient: AiClientService,
    private readonly config: ConfigService,
  ) {}

  async create(userId: string, dto: CreatePropertyDto) {
    const category = (dto.category ?? 'APARTMENT') as PropertyCategory;
    const roomCounts = sanitizeRoomCounts(dto.roomCounts);
    const rooms = buildInitialRooms(roomCounts);

    return this.prisma.property.create({
      data: {
        title: dto.title,
        address: dto.address,
        description: dto.description,
        status: PropertyStatus.CAPTURING,
        category,
        floorCount: dto.floorCount,
        roomCounts: roomCounts as object,
        userId,
        rooms: rooms.length
          ? {
              create: rooms.map((r, i) => ({
                name: r.name,
                type: r.type,
                userSelectedType: r.type,
                order: i,
              })),
            }
          : undefined,
      },
      include: { rooms: { include: roomInclude, orderBy: { order: 'asc' } } },
    });
  }

  async findAll(userId: string) {
    const properties = await this.prisma.property.findMany({
      where: { userId },
      include: {
        rooms: {
          include: roomInclude,
          orderBy: { order: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return properties.map((p) => this.mapPropertyResponse(p));
  }

  async findOne(userId: string, id: string) {
    const property = await this.prisma.property.findUnique({
      where: { id },
      include: {
        rooms: {
          include: roomInclude,
          orderBy: { order: 'asc' },
        },
        floorplan: true,
        tour: true,
      },
    });
    if (!property) throw new NotFoundException('Property not found');
    if (property.userId !== userId) throw new ForbiddenException();
    return this.mapPropertyResponse(property);
  }

  async update(userId: string, id: string, dto: UpdatePropertyDto) {
    await this.ensureOwner(userId, id);
    const updated = await this.prisma.property.update({
      where: { id },
      data: {
        title: dto.title,
        address: dto.address,
        description: dto.description,
        coverImageUrl: dto.coverImageUrl,
        category: dto.category as PropertyCategory | undefined,
        floorCount: dto.floorCount,
        roomCounts:
          dto.roomCounts !== undefined
            ? (sanitizeRoomCounts(dto.roomCounts) as object)
            : undefined,
      },
      include: {
        rooms: {
          include: roomInclude,
          orderBy: { order: 'asc' },
        },
      },
    });
    return this.mapPropertyResponse(updated);
  }

  async remove(userId: string, id: string) {
    await this.ensureOwner(userId, id);
    const property = await this.prisma.property.findUnique({
      where: { id },
      include: { rooms: { include: roomInclude, orderBy: { order: 'asc' } } },
    });
    if (!property) throw new NotFoundException();

    const keys = property.rooms.flatMap((r) => r.media.map((m) => m.key));
    await this.prisma.property.delete({ where: { id } });
    await Promise.all(keys.map((k) => this.storage.deleteObject(k)));
    return { success: true };
  }

  async analyze(userId: string, propertyId: string) {
    await this.ensureOwner(userId, propertyId);
    await this.prisma.property.update({
      where: { id: propertyId },
      data: { status: PropertyStatus.PROCESSING },
    });
    return this.aiJobs.enqueueRoomClassify(propertyId);
  }

  async generateFloorplan(userId: string, propertyId: string) {
    await this.ensureOwner(userId, propertyId);
    return this.aiJobs.enqueueFloorplan(propertyId);
  }

  async generateTour(userId: string, propertyId: string) {
    await this.ensureOwner(userId, propertyId);
    return this.aiJobs.enqueueTourGenerate(propertyId);
  }

  async generateDescription(userId: string, propertyId: string) {
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: { rooms: { include: roomInclude, orderBy: { order: 'asc' } } },
    });
    if (!property) throw new NotFoundException();
    if (property.userId !== userId) throw new ForbiddenException();

    const result = await this.aiClient.generateDescription({
      title: property.title,
      address: property.address ?? undefined,
      rooms: property.rooms.map((r) => ({
        name: r.name,
        type: r.aiDetectedType ?? r.type,
        mediaCount: r.media.length,
      })),
    });

    return this.prisma.property.update({
      where: { id: propertyId },
      data: { description: result.description },
      include: {
        rooms: {
          include: roomInclude,
          orderBy: { order: 'asc' },
        },
        floorplan: true,
        tour: true,
      },
    }).then((p) => this.mapPropertyResponse(p));
  }

  async getLatestAiJob(userId: string, propertyId: string) {
    await this.ensureOwner(userId, propertyId);
    const job = await this.prisma.aiJob.findFirst({
      where: { propertyId },
      orderBy: { createdAt: 'desc' },
    });
    return job ?? null;
  }

  async getTour(userId: string, propertyId: string) {
    await this.ensureOwner(userId, propertyId);
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: {
        tour: true,
        floorplan: true,
        rooms: {
          include: { media: { orderBy: { createdAt: 'asc' } } },
          orderBy: { order: 'asc' },
        },
      },
    });
    if (!property) throw new NotFoundException();

    const apiPublicUrl = this.config.get(
      'API_PUBLIC_URL',
      'http://localhost:3001',
    );
    const publicWebUrl = this.config.get(
      'PUBLIC_WEB_URL',
      'http://localhost:3000',
    );
    const resolveMedia = (url: string | null | undefined) =>
      resolvePublicMediaUrl(url, apiPublicUrl);

    let graph =
      property.tour?.graphJson != null
        ? normalizeStoredGraph(property.tour.graphJson)
        : null;

    if (!graph) {
      const withMedia = property.rooms.filter((r) => r.media.length > 0);
      if (withMedia.length === 0) {
        throw new NotFoundException(
          'Tur için en az bir odada fotoğraf gerekli. AI Stüdyo → Sanal tur.',
        );
      }
      graph = buildTourGraph(
        withMedia.map((r) => ({
          id: r.id,
          name: r.name,
          type: String(r.aiDetectedType ?? r.type),
          order: r.order,
          media: r.media.map((m) => ({ url: m.url, type: String(m.type) })),
        })),
      );
    }

    const slug = property.tour?.slug ?? property.publicSlug ?? property.id;
    const publicSlug = property.publicSlug ?? slug;
    const share = buildShareUrls(publicWebUrl, publicSlug, slug);
    const fpUrl =
      property.floorplan?.svgUrl ?? property.floorplan?.pngUrl ?? undefined;

    return mapTourGraphToPublic(
      graph,
      {
        slug,
        title: property.title,
        description: property.description,
        coverImageUrl: property.coverImageUrl,
        floorplanUrl: fpUrl,
        shareUrl: share.tour ?? undefined,
      },
      resolveMedia,
    );
  }

  async duplicate(userId: string, propertyId: string) {
    const original = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: {
        rooms: { orderBy: { order: 'asc' } },
      },
    });
    if (!original) throw new NotFoundException();
    if (original.userId !== userId) throw new ForbiddenException();

    const copy = await this.prisma.property.create({
      data: {
        title: `${original.title} (kopya)`,
        address: original.address,
        description: original.description,
        status: PropertyStatus.CAPTURING,
        userId,
        rooms: {
          create: original.rooms.map((room, index) => ({
            name: room.name,
            type: room.type,
            userSelectedType: room.userSelectedType ?? room.type,
            aiDetectedType: room.aiDetectedType,
            aiConfidence: room.aiConfidence,
            order: index,
          })),
        },
      },
      include: {
        rooms: {
          include: { media: true },
          orderBy: { order: 'asc' },
        },
      },
    });

    return this.mapPropertyResponse(copy);
  }

  async publish(userId: string, propertyId: string) {
    await this.ensureOwner(userId, propertyId);
    const existing = await this.prisma.property.findUnique({
      where: { id: propertyId },
      include: { tour: true },
    });
    if (!existing) throw new NotFoundException();

    const slug = existing.publicSlug ?? this.generateSlug();

    await this.prisma.$transaction([
      this.prisma.property.update({
        where: { id: propertyId },
        data: {
          status: PropertyStatus.PUBLISHED,
          publicSlug: slug,
        },
      }),
      ...(existing.tour
        ? [
            this.prisma.tour.update({
              where: { propertyId },
              data: { slug },
            }),
          ]
        : []),
    ]);

    const publicWebUrl = this.config.get(
      'PUBLIC_WEB_URL',
      'http://localhost:3000',
    );
    const shareUrls = buildShareUrls(publicWebUrl, slug, slug);

    return {
      publicSlug: slug,
      tourSlug: slug,
      shareUrls,
    };
  }

  private async ensureOwner(userId: string, propertyId: string) {
    const property = await this.prisma.property.findUnique({
      where: { id: propertyId },
    });
    if (!property) throw new NotFoundException();
    if (property.userId !== userId) throw new ForbiddenException();
    return property;
  }

  private generateSlug(): string {
    return randomBytes(6).toString('hex');
  }

  private mapPropertyResponse(property: any) {
    return {
      ...property,
      category: property.category ?? 'APARTMENT',
      floorCount: property.floorCount ?? null,
      roomCounts: property.roomCounts ?? null,
      floorplan: property.floorplan
        ? {
            estimatedAreaSqm: property.floorplan.estimatedAreaSqm,
            svgUrl: property.floorplan.svgUrl,
            layoutJson: property.floorplan.layoutJson,
          }
        : null,
      tourSlug: property.tour?.slug ?? null,
      rooms: property.rooms.map((room: any) => mapRoom(room)),
    };
  }
}

// ---------- helpers ----------

const VALID_ROOM_TYPES = new Set<string>([
  'LIVING_ROOM',
  'BEDROOM',
  'KITCHEN',
  'BATHROOM',
  'DINING_ROOM',
  'OFFICE',
  'HALLWAY',
  'BALCONY',
  'GARAGE',
  'LAUNDRY',
  'CLOSET',
  'OTHER',
]);

/** Yalnızca bilinen oda tiplerini, 0-20 arası sayılarla tutar. */
function sanitizeRoomCounts(
  input?: Record<string, unknown>,
): Record<string, number> {
  if (!input || typeof input !== 'object') return {};
  const out: Record<string, number> = {};
  for (const [k, v] of Object.entries(input)) {
    const key = String(k).toUpperCase();
    if (!VALID_ROOM_TYPES.has(key)) continue;
    const n = typeof v === 'number' ? v : Number(v);
    if (!Number.isFinite(n) || n <= 0) continue;
    out[key] = Math.min(20, Math.floor(n));
  }
  return out;
}

const ROOM_LABELS: Record<string, string> = {
  LIVING_ROOM: 'Salon',
  BEDROOM: 'Yatak Odası',
  KITCHEN: 'Mutfak',
  BATHROOM: 'Banyo',
  DINING_ROOM: 'Yemek Odası',
  OFFICE: 'Çalışma Odası',
  HALLWAY: 'Antre',
  BALCONY: 'Balkon',
  GARAGE: 'Garaj',
  LAUNDRY: 'Çamaşırlık',
  CLOSET: 'Giyinme Odası',
  OTHER: 'Oda',
};

const ROOM_ORDER = [
  'LIVING_ROOM',
  'KITCHEN',
  'DINING_ROOM',
  'BEDROOM',
  'BATHROOM',
  'OFFICE',
  'BALCONY',
  'HALLWAY',
  'CLOSET',
  'LAUNDRY',
  'GARAGE',
  'OTHER',
];

/** Sayım haritasından sıralı oda listesi üretir. Salon → Mutfak → Yatak → Banyo ... */
function buildInitialRooms(
  counts: Record<string, number>,
): Array<{ name: string; type: RoomType }> {
  const out: Array<{ name: string; type: RoomType }> = [];
  for (const key of ROOM_ORDER) {
    const n = counts[key] ?? 0;
    if (n <= 0) continue;
    const label = ROOM_LABELS[key] ?? 'Oda';
    if (n === 1) {
      out.push({ name: label, type: key as RoomType });
    } else {
      for (let i = 1; i <= n; i++) {
        out.push({ name: `${label} ${i}`, type: key as RoomType });
      }
    }
  }
  return out;
}
