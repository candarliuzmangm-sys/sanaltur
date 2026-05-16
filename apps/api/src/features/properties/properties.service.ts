import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PropertyStatus } from '@prisma/client';
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
    return this.prisma.property.create({
      data: {
        title: dto.title,
        address: dto.address,
        description: dto.description,
        status: PropertyStatus.CAPTURING,
        userId,
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
          media: r.media.map((m) => ({ url: m.url })),
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
