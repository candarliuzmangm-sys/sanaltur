/** Standart oda API yanıtı — Property → Room → Photos */

export type RoomWithMedia = {
  id: string;
  name: string;
  type: string;
  coverPhotoUrl: string | null;
  order: number;
  userSelectedType: string | null;
  aiDetectedType: string | null;
  aiConfidence: number | null;
  createdAt: Date;
  updatedAt: Date;
  media: Array<{
    id: string;
    url: string;
    mimeType: string;
    type: string;
    fileName: string | null;
    createdAt: Date;
  }>;
};

export function mapPhoto(media: RoomWithMedia['media'][number]) {
  return {
    id: media.id,
    url: media.url,
    mimeType: media.mimeType,
    type: media.type,
    fileName: media.fileName,
    createdAt: media.createdAt,
  };
}

export function mapRoom(room: RoomWithMedia) {
  const photos = [...room.media].sort(
    (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
  );
  const cover =
    room.coverPhotoUrl ?? photos[photos.length - 1]?.url ?? photos[0]?.url ?? null;

  return {
    id: room.id,
    name: room.name,
    roomType: room.type,
    type: room.type,
    order: room.order,
    coverPhoto: cover,
    coverPhotoUrl: cover,
    userSelectedType: room.userSelectedType,
    aiDetectedType: room.aiDetectedType,
    aiConfidence: room.aiConfidence,
    createdAt: room.createdAt,
    updatedAt: room.updatedAt,
    mediaCount: photos.length,
    thumbnailUrl: cover,
    photos: photos.map(mapPhoto),
    media: photos.map(mapPhoto),
  };
}

export const roomInclude = {
  media: { orderBy: { createdAt: 'asc' as const } },
} as const;
