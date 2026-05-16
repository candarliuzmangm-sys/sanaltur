import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { JobStatus, JobType, PropertyStatus, RoomType } from '@prisma/client';
import { Job } from 'bullmq';
import { randomBytes } from 'crypto';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { StorageService } from '../../shared/storage/storage.service';
import { buildTourGraph } from '../../shared/tour/tour-graph.builder';
import { AI_QUEUE } from './ai-queue.constants';
import { AiClientService } from './ai-client.service';

@Processor(AI_QUEUE)
export class AiJobsProcessor extends WorkerHost {
  private readonly logger = new Logger(AiJobsProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly aiClient: AiClientService,
    private readonly storage: StorageService,
  ) {
    super();
  }

  async process(job: Job<{ jobId: string; propertyId: string; type: JobType }>) {
    const { jobId, propertyId, type } = job.data;

    await this.prisma.aiJob.update({
      where: { id: jobId },
      data: { status: JobStatus.PROCESSING },
    });

    try {
      const property = await this.prisma.property.findUnique({
        where: { id: propertyId },
        include: {
          rooms: { include: { media: true }, orderBy: { order: 'asc' } },
        },
      });
      if (!property) throw new Error('Property not found');

      let result: unknown;

      switch (type) {
        case JobType.ROOM_CLASSIFY:
          result = await this.handleClassify(property);
          break;
        case JobType.FLOORPLAN_GENERATE:
          result = await this.handleFloorplan(property);
          break;
        case JobType.TOUR_GENERATE:
          result = await this.handleTour(property);
          break;
        default:
          throw new Error(`Unknown job type: ${type}`);
      }

      await this.prisma.aiJob.update({
        where: { id: jobId },
        data: { status: JobStatus.COMPLETED, result: result as object },
      });

      await this.prisma.property.update({
        where: { id: propertyId },
        data: { status: PropertyStatus.READY },
      });
    } catch (error) {
      this.logger.error(error);
      await this.prisma.aiJob.update({
        where: { id: jobId },
        data: {
          status: JobStatus.FAILED,
          error: error instanceof Error ? error.message : 'Unknown error',
        },
      });
      throw error;
    }
  }

  private async handleClassify(property: any) {
    const payload = {
      propertyId: property.id,
      rooms: property.rooms.map((r: any) => ({
        id: r.id,
        imageUrls: r.media.map((m: any) => m.url),
        userType: r.userSelectedType ?? r.type,
      })),
    };

    const result = await this.aiClient.classifyRooms(payload);

    for (const item of result.classifications ?? []) {
      await this.prisma.room.update({
        where: { id: item.roomId },
        data: {
          aiDetectedType: item.predictedType as RoomType,
          aiConfidence: item.confidence,
          type: item.predictedType as RoomType,
        },
      });
    }

    const orderResult = await this.aiClient.orderRooms({
      propertyId: property.id,
      rooms: property.rooms.map((r: any) => ({
        id: r.id,
        type: r.userSelectedType ?? r.type,
      })),
    });

    const orderedIds: string[] = orderResult.roomIds ?? [];
    for (let i = 0; i < orderedIds.length; i++) {
      await this.prisma.room.update({
        where: { id: orderedIds[i] },
        data: { order: i },
      });
    }

    return { classifications: result, order: orderResult };
  }

  private async handleFloorplan(property: any) {
    const result = await this.aiClient.generateFloorplan({
      propertyId: property.id,
      rooms: property.rooms.map((r: any) => ({
        id: r.id,
        name: r.name,
        type: r.aiDetectedType ?? r.type,
        imageUrls: r.media.map((m: any) => m.url),
      })),
    });

    let svgUrl = result.svgUrl as string;
    if (result.svgContent) {
      const key = `floorplans/${property.id}.svg`;
      svgUrl = await this.storage.saveLocal(
        Buffer.from(result.svgContent as string, 'utf-8'),
        key,
      );
    }

    await this.prisma.floorplan.upsert({
      where: { propertyId: property.id },
      create: {
        propertyId: property.id,
        svgUrl,
        pngUrl: result.pngUrl,
        estimatedAreaSqm: result.estimatedAreaSqm,
        layoutJson: result.rooms,
      },
      update: {
        svgUrl,
        pngUrl: result.pngUrl,
        estimatedAreaSqm: result.estimatedAreaSqm,
        layoutJson: result.rooms,
      },
    });

    return { ...result, svgUrl };
  }

  private async handleTour(property: any) {
    const slug = property.publicSlug ?? randomBytes(6).toString('hex');
    const graph = buildTourGraph(
      property.rooms.map((r: any, i: number) => ({
        id: r.id,
        name: r.name,
        type: String(r.aiDetectedType ?? r.type),
        order: r.order ?? i,
        media: r.media.map((m: any) => ({ url: m.url, type: String(m.type) })),
      })),
    );

    if (!property.publicSlug) {
      await this.prisma.property.update({
        where: { id: property.id },
        data: { publicSlug: slug },
      });
    }

    await this.prisma.tour.upsert({
      where: { propertyId: property.id },
      create: { propertyId: property.id, slug, graphJson: graph as object },
      update: { slug, graphJson: graph as object },
    });

    return { slug, graph };
  }
}
