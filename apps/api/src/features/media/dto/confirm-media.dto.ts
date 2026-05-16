import { IsOptional, IsString } from 'class-validator';

export class ConfirmMediaDto {
  @IsString()
  key!: string;

  @IsString()
  mimeType!: string;

  @IsOptional()
  @IsString()
  fileName?: string;
}
