import { ArrayMinSize, IsArray, IsUUID } from 'class-validator';

export class ReorderRoomsDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsUUID('4', { each: true })
  roomIds!: string[];
}
