import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve, sep } from "node:path";
import { eq, sql } from "drizzle-orm";
import { db } from "@/db";
import { media } from "@/db/schema";

export const UPLOADS_PATH = resolve(
  /*turbopackIgnore: true*/ (process.env.UPLOADS_PATH ?? "./data/uploads"),
);

export const ALLOWED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;

export type AllowedImageType = (typeof ALLOWED_IMAGE_TYPES)[number];

export const MAX_IMAGE_BYTES = 25 * 1024 * 1024; // 25 MB
export const MAX_TOTAL_STORAGE_BYTES = 2 * 1024 * 1024 * 1024; // 2 GB

export function detectImageMimeFromMagicBytes(
  bytes: Buffer,
): { mime: AllowedImageType; ext: string } | null {
  if (bytes.byteLength < 4) return null;

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    bytes.byteLength >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return { mime: "image/png", ext: "png" };
  }

  // JPEG: FF D8 FF
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }

  // GIF: 47 49 46 38 ("GIF8")
  if (
    bytes[0] === 0x47 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x38
  ) {
    return { mime: "image/gif", ext: "gif" };
  }

  // WebP: "RIFF" (52 49 46 46) at 0..3 and "WEBP" (57 45 42 50) at 8..11
  if (
    bytes.byteLength >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return { mime: "image/webp", ext: "webp" };
  }

  return null;
}

export function checkMediaQuota(additionalBytes: number) {
  const row = db
    .select({
      total: sql<number>`COALESCE(SUM(${media.bytes}), 0)`,
    })
    .from(media)
    .get();
  const currentTotal = Number(row?.total ?? 0);
  if (currentTotal + additionalBytes > MAX_TOTAL_STORAGE_BYTES) {
    throw new Error("Espacio de almacenamiento lleno (límite de 2 GB alcanzado).");
  }
}

export function absoluteUploadPath(rel: string): string | null {
  if (!rel || typeof rel !== "string" || rel.includes("\0")) {
    return null;
  }
  const abs = resolve(/*turbopackIgnore: true*/ UPLOADS_PATH, rel);
  if (!abs.startsWith(UPLOADS_PATH + sep)) {
    return null;
  }
  return abs;
}

export function getMediaById(id: number) {
  if (typeof id !== "number" || !Number.isInteger(id) || id <= 0) {
    return null;
  }
  const row = db.select().from(media).where(eq(media.id, id)).get();
  return row ?? null;
}

export async function storeImageUpload(
  file: File,
  ownerId: number,
  altText?: string | null,
): Promise<{ mediaId: number; path: string }> {
  if (
    typeof file.size !== "number" ||
    file.size <= 0 ||
    file.size > MAX_IMAGE_BYTES
  ) {
    throw new Error(`Invalid file size: ${file.size}`);
  }

  const bytes = Buffer.from(await file.arrayBuffer());
  const detected = detectImageMimeFromMagicBytes(bytes);
  if (!detected) {
    throw new Error("Formato de imagen no permitido.");
  }

  checkMediaQuota(bytes.byteLength);

  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.${detected.ext}`;
  const targetDir = join(/*turbopackIgnore: true*/ UPLOADS_PATH, id.slice(0, 2));
  const fullPath = join(/*turbopackIgnore: true*/ targetDir, `${id}.${detected.ext}`);

  await mkdir(targetDir, { recursive: true });
  await writeFile(fullPath, bytes);

  const row = db
    .insert(media)
    .values({
      ownerId,
      kind: "image",
      path: relPath,
      mime: detected.mime,
      bytes: bytes.byteLength,
      altText: altText?.trim() || null,
      createdAt: new Date(),
    })
    .returning({ mediaId: media.id, path: media.path })
    .get();

  return { mediaId: row.mediaId, path: row.path };
}

export async function storeDrawingDataUrl(
  dataUrl: string,
  ownerId: number,
  altText?: string | null,
): Promise<{ mediaId: number; path: string }> {
  const match = /^data:image\/png;base64,([A-Za-z0-9+/=]+)$/.exec(
    dataUrl.trim(),
  );
  if (!match) {
    throw new Error("Invalid PNG data URL");
  }

  const bytes = Buffer.from(match[1]!, "base64");
  if (bytes.byteLength === 0) {
    throw new Error("Drawing data cannot be empty");
  }
  if (bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new Error("Drawing exceeds maximum size");
  }

  const detected = detectImageMimeFromMagicBytes(bytes);
  if (!detected || detected.mime !== "image/png") {
    throw new Error("Formato de imagen no permitido.");
  }

  checkMediaQuota(bytes.byteLength);

  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.png`;
  const targetDir = join(/*turbopackIgnore: true*/ UPLOADS_PATH, id.slice(0, 2));
  const fullPath = join(/*turbopackIgnore: true*/ targetDir, `${id}.png`);

  await mkdir(targetDir, { recursive: true });
  await writeFile(fullPath, bytes);

  const row = db
    .insert(media)
    .values({
      ownerId,
      kind: "drawing",
      path: relPath,
      mime: "image/png",
      bytes: bytes.byteLength,
      altText: altText?.trim() || null,
      createdAt: new Date(),
    })
    .returning({ mediaId: media.id, path: media.path })
    .get();

  return { mediaId: row.mediaId, path: row.path };
}
