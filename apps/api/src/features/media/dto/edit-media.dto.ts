import { IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export const EDIT_OPS = [
  'erase',
  'inpaint',
  'replace',
  'recolor',
  'outpaint',
] as const;
export type EditOp = (typeof EDIT_OPS)[number];

export class EditMediaDto {
  @IsIn(EDIT_OPS)
  op!: EditOp;

  /** inpaint/replace/recolor/outpaint için hedef metin */
  @IsOptional()
  @IsString()
  @MaxLength(400)
  prompt?: string;

  /** replace/recolor için bulunacak nesne (örn: "couch", "wall") */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  target?: string;

  /** Sonucu yeni medya olarak ekle (default true) — false ise sadece preview döner */
  @IsOptional()
  asNewMedia?: boolean;
}
