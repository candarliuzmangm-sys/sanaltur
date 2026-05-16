import {
  Body,
  Controller,
  Delete,
  Param,
  Post,
  UploadedFile,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import {
  FileFieldsInterceptor,
  FileInterceptor,
  FilesInterceptor,
} from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { memoryStorage } from 'multer';

import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ConfirmMediaDto } from './dto/confirm-media.dto';
import { EditMediaDto } from './dto/edit-media.dto';
import { PresignMediaDto } from './dto/presign-media.dto';
import { MediaService } from './media.service';

const imageUploadOptions = {
  storage: memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
};

const panoramaUploadOptions = {
  storage: memoryStorage(),
  // 12 foto × 10MB = 120MB üst sınır
  limits: { fileSize: 15 * 1024 * 1024 },
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

  /**
   * AI ile fotoğrafı düzenle: eşya kaldır / koy / değiştir / renk değiştir.
   * `asNewMedia=false` ise sadece base64 önizleme döner (yeni medya oluşturmaz).
   */
  @Post(':mediaId/edit')
  editMedia(
    @CurrentUser() user: { userId: string },
    @Param('roomId') roomId: string,
    @Param('mediaId') mediaId: string,
    @Body() dto: EditMediaDto,
  ) {
    return this.mediaService.editMedia(user.userId, roomId, mediaId, dto);
  }

  /**
   * Birden çok fotoyu AI ile birleştirir (panorama).
   * Form alanı: `files` (multi-file, 2-12 adet, sıralı sağa dönüş).
   * Sonuç: yeni PANORAMA medya olarak kaydedilir.
   */
  @Post('panorama-stitch')
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FilesInterceptor('files', 12, panoramaUploadOptions))
  stitchPanorama(
    @CurrentUser() user: { userId: string },
    @Param('roomId') roomId: string,
    @UploadedFiles() files: Express.Multer.File[],
  ) {
    return this.mediaService.stitchPanorama(user.userId, roomId, files);
  }
}
