import type { PublicTourResponse, TourGraphDto } from './tour-graph.types';

type MediaResolver = (url: string | null | undefined) => string | undefined;

export function mapTourGraphToPublic(
  graph: TourGraphDto,
  meta: {
    slug: string;
    title: string;
    description?: string | null;
    coverImageUrl?: string | null;
    floorplanUrl?: string | null;
    shareUrl?: string;
  },
  resolveMedia: MediaResolver,
): PublicTourResponse {
  const connectionMap = new Map<string, string[]>();
  for (const edge of graph.edges) {
    connectionMap.set(edge.from, [
      ...(connectionMap.get(edge.from) ?? []),
      edge.to,
    ]);
  }

  return {
    slug: meta.slug,
    title: meta.title,
    description: meta.description,
    coverImageUrl: resolveMedia(meta.coverImageUrl),
    floorplanUrl: resolveMedia(meta.floorplanUrl ?? undefined),
    startRoomId: graph.startRoomId,
    shareUrl: meta.shareUrl,
    rooms: graph.nodes.map((node) => ({
      id: node.id,
      name: node.name,
      type: node.type,
      order: node.order,
      thumbnailUrl: resolveMedia(node.thumbnailUrl),
      panoramaUrl: resolveMedia(node.panoramaUrl),
      connections: connectionMap.get(node.id) ?? [],
      hotspots: node.hotspots.map((h) => ({
        ...h,
        label: h.label,
      })),
    })),
  };
}

/** Eski graphJson (hotspots yok) için geriye dönük uyumluluk. */
export function normalizeStoredGraph(raw: unknown): TourGraphDto | null {
  if (!raw || typeof raw !== 'object') return null;
  const g = raw as {
    nodes?: Array<{
      id: string;
      name: string;
      type: string;
      order: number;
      thumbnailUrl?: string;
      panoramaUrl?: string;
      hotspots?: TourGraphDto['nodes'][0]['hotspots'];
    }>;
    edges?: Array<{ from: string; to: string }>;
    startRoomId?: string;
  };
  if (!g.nodes?.length) return null;

  const edges = g.edges ?? [];
  const nameById = new Map(g.nodes.map((n) => [n.id, n.name]));
  const outgoing = new Map<string, string[]>();
  for (const edge of edges) {
    outgoing.set(edge.from, [...(outgoing.get(edge.from) ?? []), edge.to]);
  }

  const nodes = g.nodes.map((node) => {
    let hotspots = node.hotspots ?? [];
    if (hotspots.length === 0) {
      const targets = outgoing.get(node.id) ?? [];
      const n = targets.length;
      hotspots = targets.map((targetRoomId, i) => ({
        id: `${node.id}->${targetRoomId}`,
        targetRoomId,
        label: nameById.get(targetRoomId) ?? 'Oda',
        yaw: -Math.PI / 2 + (2 * Math.PI * i) / Math.max(n, 1),
        pitch: -0.12,
      }));
    }
    return { ...node, hotspots };
  });

  return {
    nodes,
    edges,
    startRoomId: g.startRoomId ?? nodes[0]?.id ?? '',
  };
}
