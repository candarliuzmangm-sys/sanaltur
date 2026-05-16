import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mkdir, unlink, writeFile } from 'fs/promises';
import { dirname, join } from 'path';
import { v4 as uuid } from 'uuid';

export type StorageMode = 'local' | 'r2';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicUrl: string;
  private readonly apiPublicUrl: string;
  readonly mode: StorageMode;
  private readonly uploadsDir: string;

  constructor(private readonly config: ConfigService) {
    this.mode =
      config.get<StorageMode>('STORAGE_MODE', 'local') === 'r2' ? 'r2' : 'local';
    const accountId = config.get('R2_ACCOUNT_ID', '');
    this.bucket = config.get('R2_BUCKET_NAME', 'sanaltur-media');
    this.publicUrl = config.get('R2_PUBLIC_URL', '');
    this.apiPublicUrl = config.get(
      'API_PUBLIC_URL',
      `http://localhost:${config.get('PORT', 3001)}`,
    );
    this.uploadsDir = join(process.cwd(), 'uploads');

    this.client = new S3Client({
      region: 'auto',
      endpoint: accountId
        ? `https://${accountId}.r2.cloudflarestorage.com`
        : undefined,
      credentials: {
        accessKeyId: config.get('R2_ACCESS_KEY_ID', 'dev'),
        secretAccessKey: config.get('R2_SECRET_ACCESS_KEY', 'dev'),
      },
      forcePathStyle: true,
    });

    if (this.mode === 'local') {
      this.logger.log(`Storage: local (${this.uploadsDir})`);
    }
  }

  buildKey(folder: string, fileName: string): string {
    const ext = fileName.includes('.') ? fileName.split('.').pop() : 'jpg';
    return `${folder}/${uuid()}.${ext}`;
  }

  getPublicUrl(key: string): string {
    if (this.mode === 'local') {
      return `${this.apiPublicUrl}/uploads/${key}`;
    }
    return `${this.publicUrl}/${key}`;
  }

  async saveLocal(buffer: Buffer, key: string): Promise<string> {
    const fullPath = join(this.uploadsDir, key);
    await mkdir(dirname(fullPath), { recursive: true });
    await writeFile(fullPath, buffer);
    return this.getPublicUrl(key);
  }

  async getPresignedUploadUrl(key: string, mimeType: string): Promise<string> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: mimeType,
    });
    return getSignedUrl(this.client, command, { expiresIn: 900 });
  }

  async deleteObject(key: string): Promise<void> {
    if (!key) return;
    try {
      if (this.mode === 'local') {
        const fullPath = join(this.uploadsDir, key);
        await unlink(fullPath);
      } else {
        await this.client.send(
          new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
        );
      }
    } catch (err) {
      this.logger.warn(`Failed to delete object ${key}: ${(err as Error).message}`);
    }
  }
}
