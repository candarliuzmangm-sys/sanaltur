import { IsEnum, IsOptional, IsString } from 'class-validator';

enum RoomTypeDto {
  LIVING_ROOM = 'LIVING_ROOM',
  BEDROOM = 'BEDROOM',
  KITCHEN = 'KITCHEN',
  BATHROOM = 'BATHROOM',
  DINING_ROOM = 'DINING_ROOM',
  OFFICE = 'OFFICE',
  HALLWAY = 'HALLWAY',
  BALCONY = 'BALCONY',
  GARAGE = 'GARAGE',
  LAUNDRY = 'LAUNDRY',
  CLOSET = 'CLOSET',
  OTHER = 'OTHER',
}

export class UpdateRoomDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsEnum(RoomTypeDto)
  type?: RoomTypeDto;

  @IsOptional()
  @IsEnum(RoomTypeDto)
  userSelectedType?: RoomTypeDto;

  @IsOptional()
  @IsString()
  coverPhotoUrl?: string;
}
