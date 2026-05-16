import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { JobType } from '@prisma/client';
import { Queue } from 'bullmq';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { AI_QUEUE } from './ai-queue.constants';

@Injectable()
export class AiJobsService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(AI_QUEUE) private readonly queue: Queue,
  ) {}

  async enqueueRoomClassify(propertyId: string) {
    return this.enqueue(JobType.ROOM_CLASSIFY, propertyId);
  }

  async enqueueFloorplan(propertyId: string) {
    return this.enqueue(JobType.FLOORPLAN_GENERATE, propertyId);
  }

  async enqueueTourGenerate(propertyId: string) {
    return this.enqueue(JobType.TOUR_GENERATE, propertyId);
  }

  private async enqueue(type: JobType, propertyId: string) {
    const job = await this.prisma.aiJob.create({
      data: { type, propertyId, payload: { propertyId } },
    });

    await this.queue.add(type, { jobId: job.id, propertyId, type });

    return { jobId: job.id, status: job.status };
  }
}
