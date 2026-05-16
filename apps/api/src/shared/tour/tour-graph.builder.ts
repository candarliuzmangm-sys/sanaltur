import type {
  TourGraphDto,
  TourGraphNodeDto,
  TourHotspotDto,
} from './tour-graph.types';

export interface RoomForTourGraph {
  id: string;
  name: string;
  type: string;
  order: number;
  media: Array<{ url: string; type?: string | null }>;
}

/** Sıralı oda zinciri + geri dönüş kenarları; panoramada gezinme hotspotları üretir. */
export function buildTourGraph(rooms: RoomForTourGraph[]): TourGraphDto {
  const sorted = [...rooms].sort((a, b) => a.order - b.order);
  const edges: Array<{ from: string; to: string }> = [];

  for (let i = 0; i < sorted.length - 1; i++) {
    const a = sorted[i]!;
    const b = sorted[i + 1]!;
    edges.push({ from: a.id, to: b.id });
    edges.push({ from: b.id, to: a.id });
  }

  const nameById = new Map(sorted.map((r) => [r.id, r.name]));
  const outgoing = new Map<string, string[]>();
  for (const edge of edges) {
    outgoing.set(edge.from, [...(outgoing.get(edge.from) ?? []), edge.to]);
  }

  const nodes: TourGraphNodeDto[] = sorted.map((room) => {
    const allMedia = (room.media || []).map((m) => ({
      url: m.url,
      type: ((m.type || '').toUpperCase() === 'PANORAMA'
        ? 'PANORAMA'
        : 'IMAGE') as 'PANORAMA' | 'IMAGE',
    }));
    // Panorama varsa ilk panoramayı, yoksa ilk fotoğrafı kullan.
    const primary = allMedia.find((m) => m.type === 'PANORAMA') ?? allMedia[0];
    const panoramaUrl = primary?.url;
    const mediaType = primary?.type;
    const targets = outgoing.get(room.id) ?? [];
    const hotspots = buildHotspots(room.id, targets, nameById);

    return {
      id: room.id,
      name: room.name,
      type: room.type,
      order: room.order,
      thumbnailUrl: panoramaUrl,
      panoramaUrl,
      mediaType,
      media: allMedia,
      hotspots,
    };
  });

  return {
    nodes,
    edges,
    startRoomId: sorted[0]?.id ?? '',
  };
}

function buildHotspots(
  roomId: string,
  targetIds: string[],
  nameById: Map<string, string>,
): TourHotspotDto[] {
  const n = targetIds.length;
  if (n === 0) return [];

  return targetIds.map((targetRoomId, i) => {
    const yaw = -Math.PI / 2 + (2 * Math.PI * i) / n;
    return {
      id: `${roomId}->${targetRoomId}`,
      targetRoomId,
      label: nameById.get(targetRoomId) ?? 'Oda',
      yaw,
      pitch: -0.12,
    };
  });
}
