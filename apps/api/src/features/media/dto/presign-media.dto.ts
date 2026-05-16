import { IsString } from 'class-validator';

export class PresignMediaDto {
  @IsString()
  fileName!: string;

  @IsString()
  mimeType!: string;
}
