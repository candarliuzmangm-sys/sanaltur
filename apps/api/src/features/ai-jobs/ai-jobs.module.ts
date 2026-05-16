import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';

import { AiClientService } from './ai-client.service';
import { AI_QUEUE } from './ai-queue.constants';
import { AiJobsProcessor } from './ai-jobs.processor';
import { AiJobsService } from './ai-jobs.service';
import { RoomClassificationService } from './room-classification.service';

@Module({
  imports: [BullModule.registerQueue({ name: AI_QUEUE })],
  providers: [
    AiJobsService,
    AiJobsProcessor,
    AiClientService,
    RoomClassificationService,
  ],
  exports: [AiJobsService, AiClientService, RoomClassificationService],
})
export class AiJobsModule {}
