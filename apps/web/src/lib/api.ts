const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001/api/v1';

/** Geliştirmede 10.0.2.2 / localhost medya URL'lerini tarayıcıdan erişilebilir hale getirir. */
export function resolvePublicMediaUrl(url: string | null | undefined): string | undefined {
  if (!url) return undefined;
  try {
    const apiBase = new URL(API_URL);
    const parsed = new URL(url);
    if (
      parsed.hostname === '10.0.2.2' ||
      parsed.hostname === '127.0.0.1' ||
      parsed.hostname === 'localhost'
    ) {
      parsed.protocol = apiBase.protocol;
      parsed.hostname = apiBase.hostname;
      parsed.port = apiBase.port;
      return parsed.toString();
    }
  } catch {
    return url;
  }
  return url;
}

export interface TourHotspot {
  id: string;
  targetRoomId: string;
  label: string;
  yaw: number;
  pitch: number;
}

export interface PublicTourRoom {
  id: string;
  name: string;
  type: string;
  order: number;
  panoramaUrl?: string;
  thumbnailUrl?: string;
  connections: string[];
  hotspots: TourHotspot[];
}

export interface PublicTour {
  slug: string;
  title: string;
  description?: string;
  coverImageUrl?: string;
  floorplanUrl?: string;
  startRoomId: string;
  shareUrl?: string;
  rooms: PublicTourRoom[];
}

export async function fetchPublicTour(slug: string): Promise<PublicTour> {
  const res = await fetch(`${API_URL}/public/tours/${slug}`, {
    next: { revalidate: 60 },
  });
  if (!res.ok) throw new Error('Tur bulunamadı');
  return res.json();
}

export interface PublicMedia {
  id: string;
  url: string;
  mimeType: string;
}

export interface PublicRoom {
  id: string;
  name: string;
  type: string;
  order: number;
  media: PublicMedia[];
}

export interface PublicProperty {
  slug: string;
  tourSlug?: string;
  title: string;
  address?: string | null;
  description?: string | null;
  coverImageUrl?: string | null;
  rooms: PublicRoom[];
}

export async function fetchPublicProperty(slug: string): Promise<PublicProperty> {
  const res = await fetch(`${API_URL}/public/properties/${slug}`, {
    next: { revalidate: 60 },
  });
  if (!res.ok) throw new Error('Mülk bulunamadı veya yayında değil');
  return res.json();
}

const ROOM_TYPE_LABELS: Record<string, string> = {
  LIVING_ROOM: 'Salon',
  BEDROOM: 'Yatak Odası',
  KITCHEN: 'Mutfak',
  BATHROOM: 'Banyo',
  DINING_ROOM: 'Yemek Odası',
  OFFICE: 'Çalışma Odası',
  HALLWAY: 'Hol',
  BALCONY: 'Balkon',
  GARAGE: 'Garaj',
  LAUNDRY: 'Çamaşırlık',
  CLOSET: 'Dolap',
  OTHER: 'Diğer',
};

export function roomTypeLabel(type: string): string {
  return ROOM_TYPE_LABELS[type] ?? type;
}
