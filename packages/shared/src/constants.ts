export const API_VERSION = 'v1';
export const PUBLIC_TOUR_PREFIX = '/tour';

export const ROOM_TYPE_LABELS: Record<string, string> = {
  LIVING_ROOM: 'Salon',
  BEDROOM: 'Yatak Odası',
  KITCHEN: 'Mutfak',
  BATHROOM: 'Banyo',
  DINING_ROOM: 'Yemek Odası',
  OFFICE: 'Ofis',
  HALLWAY: 'Koridor',
  BALCONY: 'Balkon',
  GARAGE: 'Garaj',
  LAUNDRY: 'Çamaşırhane',
  CLOSET: 'Dolap',
  OTHER: 'Diğer',
};

export const MAX_ROOMS_PER_PROPERTY = 30;
export const MAX_MEDIA_PER_ROOM = 20;
export const PRESIGN_URL_TTL_SECONDS = 900;
