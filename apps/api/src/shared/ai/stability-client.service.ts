import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type StabilityOp =
  | 'erase'
  | 'inpaint'
  | 'search-and-replace'
  | 'search-and-recolor'
  | 'outpaint'
  | 'remove-background';

export interface StabilityResult {
  /** Image binary (jpeg/png) */
  buffer: Buffer;
  mimeType: string;
}

/**
 * Stability AI client — Stable Image v2beta edit endpoints.
 * Docs: https://platform.stability.ai/docs/api-reference#tag/Edit
 *
 * Maliyet: ~3 credit / işlem (≈ $0.03), outpaint 4 credit (≈ $0.04).
 *
 * Env:
 *   STABILITY_API_KEY=sk-...
 *   STABILITY_MOCK=true  (key yokken mock buffer döner)
 */
@Injectable()
export class StabilityClientService {
  private readonly logger = new Logger(StabilityClientService.name);
  private readonly apiKey: string | undefined;
  private readonly mock: boolean;
  private readonly baseUrl = 'https://api.stability.ai/v2beta/stable-image/edit';

  constructor(private readonly config: ConfigService) {
    this.apiKey = config.get<string>('STABILITY_API_KEY');
    const mockFlag = (config.get<string>('STABILITY_MOCK') ?? '').toLowerCase();
    this.mock = mockFlag === '1' || mockFlag === 'true' || mockFlag === 'yes';

    if (!this.apiKey && !this.mock) {
      this.logger.warn(
        'STABILITY_API_KEY missing — set STABILITY_MOCK=true to enable mock responses',
      );
    } else if (this.mock) {
      this.logger.log('Stability AI running in MOCK mode (no external calls)');
    } else {
      this.logger.log('Stability AI client ready');
    }
  }

  get available(): boolean {
    return this.mock || !!this.apiKey;
  }

  // ===================================================================
  // ERASE — eşya kaldır (boş oda yap)
  // ===================================================================
  async erase(opts: {
    image: Buffer;
    prompt?: string;
    growMask?: number;
  }): Promise<StabilityResult> {
    if (this.mock) return this.mockResult(opts.image);
    if (!this.apiKey) throw this.noKey();

    const form = new FormData();
    form.append('image', new Blob([new Uint8Array(opts.image)]), 'image.jpg');
    if (opts.prompt) form.append('prompt', opts.prompt);
    if (opts.growMask) form.append('grow_mask', String(opts.growMask));
    form.append('output_format', 'jpeg');

    return this.post('erase', form);
  }

  // ===================================================================
  // INPAINT — bir bölgeye yeni içerik üret (mask gerekir veya prompt)
  // ===================================================================
  async inpaint(opts: {
    image: Buffer;
    prompt: string;
    mask?: Buffer;
    growMask?: number;
  }): Promise<StabilityResult> {
    if (this.mock) return this.mockResult(opts.image);
    if (!this.apiKey) throw this.noKey();

    const form = new FormData();
    form.append('image', new Blob([new Uint8Array(opts.image)]), 'image.jpg');
    form.append('prompt', opts.prompt);
    if (opts.mask) {
      form.append('mask', new Blob([new Uint8Array(opts.mask)]), 'mask.png');
    }
    if (opts.growMask) form.append('grow_mask', String(opts.growMask));
    form.append('output_format', 'jpeg');

    return this.post('inpaint', form);
  }

  // ===================================================================
  // SEARCH-AND-REPLACE — "kanepe" yerine "mavi kanepe" gibi
  // ===================================================================
  async searchAndReplace(opts: {
    image: Buffer;
    /** Bulunacak nesne (örn: "couch") */
    searchPrompt: string;
    /** Yerine konacak (örn: "modern blue velvet sofa") */
    prompt: string;
  }): Promise<StabilityResult> {
    if (this.mock) return this.mockResult(opts.image);
    if (!this.apiKey) throw this.noKey();

    const form = new FormData();
    form.append('image', new Blob([new Uint8Array(opts.image)]), 'image.jpg');
    form.append('search_prompt', opts.searchPrompt);
    form.append('prompt', opts.prompt);
    form.append('output_format', 'jpeg');

    return this.post('search-and-replace', form);
  }

  // ===================================================================
  // SEARCH-AND-RECOLOR — "duvar" rengini "bej" yap
  // ===================================================================
  async searchAndRecolor(opts: {
    image: Buffer;
    /** Renklenecek nesne (örn: "wall", "floor") */
    selectPrompt: string;
    /** Hedef renk açıklama (örn: "warm beige") */
    prompt: string;
  }): Promise<StabilityResult> {
    if (this.mock) return this.mockResult(opts.image);
    if (!this.apiKey) throw this.noKey();

    const form = new FormData();
    form.append('image', new Blob([new Uint8Array(opts.image)]), 'image.jpg');
    form.append('select_prompt', opts.selectPrompt);
    form.append('prompt', opts.prompt);
    form.append('output_format', 'jpeg');

    return this.post('search-and-recolor', form);
  }

  // ===================================================================
  // OUTPAINT — görüntüyü genişlet (panorama için ileride)
  // ===================================================================
  async outpaint(opts: {
    image: Buffer;
    left?: number;
    right?: number;
    up?: number;
    down?: number;
    prompt?: string;
  }): Promise<StabilityResult> {
    if (this.mock) return this.mockResult(opts.image);
    if (!this.apiKey) throw this.noKey();

    const form = new FormData();
    form.append('image', new Blob([new Uint8Array(opts.image)]), 'image.jpg');
    if (opts.left) form.append('left', String(opts.left));
    if (opts.right) form.append('right', String(opts.right));
    if (opts.up) form.append('up', String(opts.up));
    if (opts.down) form.append('down', String(opts.down));
    if (opts.prompt) form.append('prompt', opts.prompt);
    form.append('output_format', 'jpeg');

    return this.post('outpaint', form);
  }

  // ===================================================================
  // REMOVE BACKGROUND
  // ===================================================================
  async removeBackground(image: Buffer): Promise<StabilityResult> {
    if (this.mock) return this.mockResult(image);
    if (!this.apiKey) throw this.noKey();

    const form = new FormData();
    form.append('image', new Blob([new Uint8Array(image)]), 'image.jpg');
    form.append('output_format', 'png');

    return this.post('remove-background', form);
  }

  // ===================================================================
  // INTERNAL
  // ===================================================================
  private async post(op: StabilityOp, form: FormData): Promise<StabilityResult> {
    const url = `${this.baseUrl}/${op}`;
    const start = Date.now();
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          Accept: 'image/*',
        },
        body: form,
      });
    } catch (e) {
      this.logger.error(`stability ${op} network error: ${(e as Error).message}`);
      throw new ServiceUnavailableException(
        'Stability AI servisine ulaşılamadı',
      );
    }

    if (!res.ok) {
      const text = await res.text();
      this.logger.error(`stability ${op} HTTP ${res.status}: ${text}`);
      throw new ServiceUnavailableException(
        `Stability AI hatası (${res.status}): ${truncate(text, 200)}`,
      );
    }

    const buffer = Buffer.from(await res.arrayBuffer());
    const mimeType = res.headers.get('content-type') ?? 'image/jpeg';
    const ms = Date.now() - start;
    this.logger.log(
      `stability ${op} ok in ${ms}ms (${(buffer.length / 1024).toFixed(0)} KB)`,
    );
    return { buffer, mimeType };
  }

  private noKey() {
    return new ServiceUnavailableException(
      'STABILITY_API_KEY ayarlanmadı — Railway env\'e ekleyin',
    );
  }

  /** Mock: aynı görüntüyü döner (gerçek edit olmadan UI test için) */
  private async mockResult(image: Buffer): Promise<StabilityResult> {
    await new Promise((r) => setTimeout(r, 600)); // sahte gecikme
    return { buffer: image, mimeType: 'image/jpeg' };
  }
}

function truncate(s: string, n: number): string {
  if (s.length <= n) return s;
  return s.slice(0, n) + '…';
}
