import { IsIn, IsOptional, IsString } from 'class-validator';

export class ConfirmMediaDto {
  @IsString()
  key!: string;

  @IsString()
  mimeType!: string;

  @IsOptional()
  @IsString()
  fileName?: string;

  @IsOptional()
  @IsIn(['IMAGE', 'PANORAMA', 'VIDEO'])
  mediaType?: 'IMAGE' | 'PANORAMA' | 'VIDEO';
}
