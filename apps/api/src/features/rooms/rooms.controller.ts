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
import { CreateRoomDto } from './dto/create-room.dto';
import { ReorderRoomsDto } from './dto/reorder-rooms.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { RoomsService } from './rooms.service';

@ApiTags('rooms')
@Controller('properties/:propertyId/rooms')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class RoomsController {
  constructor(private readonly roomsService: RoomsService) {}

  @Get()
  list(
    @CurrentUser() user: { userId: string },
    @Param('propertyId') propertyId: string,
  ) {
    return this.roomsService.listByProperty(user.userId, propertyId);
  }

  @Get(':roomId')
  findOne(
    @CurrentUser() user: { userId: string },
    @Param('propertyId') propertyId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomsService.findOne(user.userId, propertyId, roomId);
  }

  @Post('reorder')
  reorder(
    @CurrentUser() user: { userId: string },
    @Param('propertyId') propertyId: string,
    @Body() dto: ReorderRoomsDto,
  ) {
    return this.roomsService.reorder(user.userId, propertyId, dto.roomIds);
  }

  @Post()
  create(
    @CurrentUser() user: { userId: string },
    @Param('propertyId') propertyId: string,
    @Body() dto: CreateRoomDto,
  ) {
    return this.roomsService.create(user.userId, propertyId, dto);
  }

  @Patch(':roomId')
  update(
    @CurrentUser() user: { userId: string },
    @Param('propertyId') propertyId: string,
    @Param('roomId') roomId: string,
    @Body() dto: UpdateRoomDto,
  ) {
    return this.roomsService.update(user.userId, propertyId, roomId, dto);
  }

  @Delete(':roomId')
  remove(
    @CurrentUser() user: { userId: string },
    @Param('propertyId') propertyId: string,
    @Param('roomId') roomId: string,
  ) {
    return this.roomsService.remove(user.userId, propertyId, roomId);
  }
}
