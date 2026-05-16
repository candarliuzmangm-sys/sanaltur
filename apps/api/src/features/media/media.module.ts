import { Module } from '@nestjs/common';

import { AiJobsModule } from '../ai-jobs/ai-jobs.module';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

@Module({
  imports: [AiJobsModule],
  controllers: [MediaController],
  providers: [MediaService],
})
export class MediaModule {}
