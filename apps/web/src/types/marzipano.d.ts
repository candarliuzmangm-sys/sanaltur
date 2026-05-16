declare module 'marzipano' {
  export class Viewer {
    constructor(element: HTMLElement, opts?: Record<string, unknown>);
    createScene(opts: Record<string, unknown>): Scene;
    destroy(): void;
  }
  export class Scene {
    switchTo(opts?: Record<string, unknown>): void;
    hotspotContainer(): HotspotContainer;
    view(): RectilinearView;
  }
  export class HotspotContainer {
    createHotspot(
      element: HTMLElement,
      position: { yaw: number; pitch: number },
      opts?: Record<string, unknown>,
    ): { destroy(): void };
  }
  export class RectilinearView {
    constructor(params: Record<string, number>, limiter?: unknown);
    static limit: { traditional: (w: number, maxFov: number) => unknown };
  }
  export class ImageUrlSource {
    static fromString(url: string): unknown;
  }
  export class EquirectGeometry {
    constructor(levels: Array<{ width: number }>);
  }
}
