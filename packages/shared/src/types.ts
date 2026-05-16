import { JobStatus, JobType, MediaType, PropertyStatus, RoomType } from './enums';

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
  type: RoomType;
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
  rooms: PublicTourRoom[];
  floorplanUrl?: string;
  startRoomId: string;
  shareUrl?: string;
}

export interface AiClassifyResult {
  roomId: string;
  predictedType: RoomType;
  confidence: number;
}

export interface AiRoomOrderResult {
  roomIds: string[];
}

export interface AiFloorplanResult {
  svgUrl: string;
  pngUrl?: string;
  estimatedAreaSqm?: number;
  rooms: Array<{
    roomId: string;
    x: number;
    y: number;
    width: number;
    height: number;
  }>;
}

export interface AiJobPayload {
  jobId: string;
  type: JobType;
  propertyId: string;
  roomIds?: string[];
  mediaUrls?: string[];
}

export interface AiJobResponse {
  jobId: string;
  status: JobStatus;
  result?: unknown;
  error?: string;
}
