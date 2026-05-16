import { IsEnum, IsOptional, IsString, MinLength } from 'class-validator';

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

export class CreateRoomDto {
  @IsString()
  @MinLength(1)
  name!: string;

  @IsEnum(RoomTypeDto)
  type!: RoomTypeDto;

  @IsOptional()
  @IsEnum(RoomTypeDto)
  userSelectedType?: RoomTypeDto;
}
