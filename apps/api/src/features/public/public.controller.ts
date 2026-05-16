import { Controller, Get, Param } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

import { PublicService } from './public.service';

@ApiTags('public')
@Controller('public')
export class PublicController {
  constructor(private readonly publicService: PublicService) {}

  @Get('tours/:slug')
  getTour(@Param('slug') slug: string) {
    return this.publicService.getTourBySlug(slug);
  }

  @Get('properties/:slug')
  getProperty(@Param('slug') slug: string) {
    return this.publicService.getPropertyBySlug(slug);
  }
}
