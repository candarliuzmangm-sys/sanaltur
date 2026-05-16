import { IsOptional, IsString, MinLength } from 'class-validator';

export class CreatePropertyDto {
  @IsString()
  @MinLength(2)
  title!: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  description?: string;
}
