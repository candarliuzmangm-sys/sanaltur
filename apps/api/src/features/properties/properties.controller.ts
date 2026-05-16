import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreatePropertyDto } from './dto/create-property.dto';
import { UpdatePropertyDto } from './dto/update-property.dto';
import { PropertiesService } from './properties.service';

@ApiTags('properties')
@Controller('properties')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class PropertiesController {
  constructor(private readonly propertiesService: PropertiesService) {}

  @Post()
  create(
    @CurrentUser() user: { userId: string },
    @Body() dto: CreatePropertyDto,
  ) {
    return this.propertiesService.create(user.userId, dto);
  }

  @Get()
  findAll(@CurrentUser() user: { userId: string }) {
    return this.propertiesService.findAll(user.userId);
  }

  @Get(':id/tour')
  getTour(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.getTour(user.userId, id);
  }

  @Get(':id')
  findOne(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.findOne(user.userId, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
    @Body() dto: UpdatePropertyDto,
  ) {
    return this.propertiesService.update(user.userId, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.remove(user.userId, id);
  }

  @Post(':id/generate-description')
  generateDescription(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.generateDescription(user.userId, id);
  }

  @Get(':id/ai-jobs/latest')
  latestAiJob(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.getLatestAiJob(user.userId, id);
  }

  @Post(':id/analyze')
  analyze(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.analyze(user.userId, id);
  }

  @Post(':id/generate-floorplan')
  generateFloorplan(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.generateFloorplan(user.userId, id);
  }

  @Post(':id/generate-tour')
  generateTour(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.generateTour(user.userId, id);
  }

  @Post(':id/publish')
  publish(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.publish(user.userId, id);
  }

  @Post(':id/duplicate')
  duplicate(
    @CurrentUser() user: { userId: string },
    @Param('id') id: string,
  ) {
    return this.propertiesService.duplicate(user.userId, id);
  }
}
