import { Module } from '@nestjs/common';

import { PublicController } from './public.controller';
import { PublicPagesController } from './public-pages.controller';
import { PublicService } from './public.service';

@Module({
  controllers: [PublicController, PublicPagesController],
  providers: [PublicService],
})
export class PublicModule {}
