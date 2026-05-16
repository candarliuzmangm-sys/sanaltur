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

export const PROPERTY_CATEGORIES = [
  'APARTMENT',
  'VILLA',
  'OFFICE',
  'STORE',
  'SHOP',
  'OTHER',
] as const;

export type PropertyCategoryDto = (typeof PROPERTY_CATEGORIES)[number];

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

  @IsOptional()
  @IsIn(PROPERTY_CATEGORIES)
  category?: PropertyCategoryDto;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  floorCount?: number;

  /** Oda tipi -> sayı (örn: {"LIVING_ROOM":1,"BEDROOM":3}) */
  @IsOptional()
  @IsObject()
  roomCounts?: Record<string, number>;
}
