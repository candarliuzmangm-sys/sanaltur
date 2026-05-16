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
    connections: string[];
    hotspots: TourHotspotDto[];
  }>;
}
