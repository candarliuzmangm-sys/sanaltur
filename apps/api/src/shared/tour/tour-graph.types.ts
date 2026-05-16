export interface TourHotspotDto {
  id: string;
  targetRoomId: string;
  label: string;
  /** Radyan (Marzipano uyumlu) */
  yaw: number;
  pitch: number;
}

export interface TourGraphNodeDto {
  id: string;
  name: string;
  type: string;
  order: number;
  thumbnailUrl?: string;
  panoramaUrl?: string;
  /** Birincil görselin türü: gerçek 360° (PANORAMA) ya da düz foto (IMAGE) */
  mediaType?: 'PANORAMA' | 'IMAGE';
  /** Tüm medyalar — flat moddaki galeri kaydırması için */
  media?: Array<{ url: string; type: 'PANORAMA' | 'IMAGE' }>;
  hotspots: TourHotspotDto[];
}

export interface TourGraphDto {
  nodes: TourGraphNodeDto[];
  edges: Array<{ from: string; to: string }>;
  startRoomId: string;
}

export interface PublicTourResponse {
  slug: string;
  title: string;
  description?: string | null;
  coverImageUrl?: string;
  floorplanUrl?: string;
  startRoomId: string;
  shareUrl?: string;
  rooms: Array<{
    id: string;
    name: string;
    type: string;
    order: number;
    thumbnailUrl?: string;
    panoramaUrl?: string;
    mediaType?: 'PANORAMA' | 'IMAGE';
    media?: Array<{ url: string; type: 'PANORAMA' | 'IMAGE' }>;
    connections: string[];
    hotspots: TourHotspotDto[];
  }>;
}
