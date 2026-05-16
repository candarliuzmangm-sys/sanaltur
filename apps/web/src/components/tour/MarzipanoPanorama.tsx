'use client';

import React, { useCallback, useEffect, useRef } from 'react';
import * as Marzipano from 'marzipano';

import type { TourHotspot } from '@/lib/api';

export interface MarzipanoPanoramaProps {
  imageUrl: string;
  hotspots: TourHotspot[];
  initialYaw?: number;
  onHotspotClick: (targetRoomId: string) => void;
}

export function MarzipanoPanorama({
  imageUrl,
  hotspots,
  initialYaw = 0,
  onHotspotClick,
}: MarzipanoPanoramaProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const onHotspotClickRef = useRef(onHotspotClick);
  onHotspotClickRef.current = onHotspotClick;

  const stableHotspotClick = useCallback((id: string) => {
    onHotspotClickRef.current(id);
  }, []);

  useEffect(() => {
    const el = containerRef.current;
    if (!el || !imageUrl) return;

    const viewer = new Marzipano.Viewer(el, {
      controls: { mouseViewMode: 'drag' },
    });
    const source = Marzipano.ImageUrlSource.fromString(imageUrl);
    const geometry = new Marzipano.EquirectGeometry([{ width: 4096 }]);
    const limiter = Marzipano.RectilinearView.limit.traditional(
      4096,
      (120 * Math.PI) / 180,
    );
    const view = new Marzipano.RectilinearView(
      { yaw: initialYaw, pitch: 0, fov: Math.PI / 2 },
      limiter,
    );
    const scene = viewer.createScene({ source, geometry, view });
    scene.switchTo();

    const hotspotHandles: Array<{ destroy(): void }> = [];
    const container = scene.hotspotContainer();

    for (const spot of hotspots) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'tour-hotspot';
      btn.innerHTML = `<span class="tour-hotspot__dot"></span><span class="tour-hotspot__label">${escapeHtml(spot.label)}</span>`;
      const targetId = spot.targetRoomId;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        stableHotspotClick(targetId);
      });
      hotspotHandles.push(
        container.createHotspot(btn, { yaw: spot.yaw, pitch: spot.pitch }),
      );
    }

    return () => {
      for (const h of hotspotHandles) h.destroy();
      viewer.destroy();
    };
  }, [imageUrl, hotspots, initialYaw, stableHotspotClick]);

  return React.createElement(['d', 'i', 'v'].join('') as 'div', {
    className: 'tour-panorama',
    ref: containerRef,
  });
}

function escapeHtml(text: string) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
