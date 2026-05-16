import {
  Body,
  Controller,
  Delete,
  Param,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { memoryStorage } from 'multer';

import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ConfirmMediaDto } from './dto/confirm-media.dto';
import { PresignMediaDto } from './dto/presign-media.dto';
import { MediaService } from './media.service';

const imageUploadOptions = {
  storage: memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
};

@ApiTags('media')
@Controller('rooms/:roomId/media')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Post('upload')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', imageUploadOptions))
  upload(
    @CurrentUser() user: { userId: string },
    @Param('roomId') roomId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body() body: { mediaType?: string },
  ) {
    const requested = (body?.mediaType ?? '').toUpperCase();
    const hint =
      requested === 'PANORAMA' || requested === 'VIDEO' || requested === 'IMAGE'
        ? (requested as 'PANORAMA' | 'VIDEO' | 'IMAGE')
        : undefined;
    return this.mediaService.uploadFile(user.userId, roomId, file, hint);
  }

  @Post('presign')
  presign(
    @CurrentUser() user: { userId: string },
    @Param('roomId') roomId: string,
    @Body() dto: PresignMediaDto,
  ) {
    return this.mediaService.presign(user.userId, roomId, dto);
  }

  @Post('confirm')
  confirm(
    @CurrentUser() user: { userId: string },
    @Param('roomId') roomId: string,
    @Body() dto: ConfirmMediaDto,
  ) {
    return this.mediaService.confirm(user.userId, roomId, dto);
  }

  @Delete(':mediaId')
  remove(
    @CurrentUser() user: { userId: string },
    @Param('roomId') roomId: string,
    @Param('mediaId') mediaId: string,
  ) {
    return this.mediaService.remove(user.userId, roomId, mediaId);
  }
}
