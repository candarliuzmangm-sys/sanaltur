import {
  IsIn,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';

import {
  PROPERTY_CATEGORIES,
  PropertyCategoryDto,
} from './create-property.dto';

export class UpdatePropertyDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  title?: string;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  coverImageUrl?: string;

  @IsOptional()
  @IsIn(PROPERTY_CATEGORIES)
  category?: PropertyCategoryDto;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  floorCount?: number;

  @IsOptional()
  @IsObject()
  roomCounts?: Record<string, number>;
}
