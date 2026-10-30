import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve, sep } from "node:path";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { media } from "@/db/schema";

export const UPLOADS_PATH = resolve(
  /*turbopackIgnore: true*/ (process.env.UPLOADS_PATH ?? "./data/uploads"),
);

const ALLOWED_IMAGE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;

type AllowedImageType = (typeof ALLOWED_IMAGE_TYPES)[number];

const MAX_IMAGE_BYTES = 25 * 1024 * 1024; // 25 MB

const MIME_EXT_MAP: Record<AllowedImageType, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
};

function getFileExtension(file: File): string {
  if (file.name) {
    const match = /\.([a-zA-Z0-9]+)$/.exec(file.name);
    if (match) {
      const ext = match[1].toLowerCase();
      if (file.type === "image/jpeg" && (ext === "jpg" || ext === "jpeg")) {
        return ext;
      }
      if (file.type === "image/png" && ext === "png") return "png";
      if (file.type === "image/webp" && ext === "webp") return "webp";
      if (file.type === "image/gif" && ext === "gif") return "gif";
    }
  }
  return MIME_EXT_MAP[file.type as AllowedImageType] ?? "jpg";
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
): Promise<{ mediaId: number; path: string }> {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type as AllowedImageType)) {
    throw new Error(`Unsupported image type: ${file.type}`);
  }

  if (
    typeof file.size !== "number" ||
    file.size <= 0 ||
    file.size > MAX_IMAGE_BYTES
  ) {
    throw new Error(`Invalid file size: ${file.size}`);
  }

  const ext = getFileExtension(file);
  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.${ext}`;
  const targetDir = join(/*turbopackIgnore: true*/ UPLOADS_PATH, id.slice(0, 2));
  const fullPath = join(/*turbopackIgnore: true*/ targetDir, `${id}.${ext}`);

  await mkdir(targetDir, { recursive: true });

  const bytes = Buffer.from(await file.arrayBuffer());
  await writeFile(fullPath, bytes);

  const row = db
    .insert(media)
    .values({
      ownerId,
      kind: "image",
      path: relPath,
      mime: file.type,
      bytes: bytes.byteLength,
      createdAt: new Date(),
    })
    .returning({ mediaId: media.id, path: media.path })
    .get();

  return { mediaId: row.mediaId, path: row.path };
}

export async function storeDrawingDataUrl(
  dataUrl: string,
  ownerId: number,
): Promise<{ mediaId: number; path: string }> {
  const match = /^data:image\/png;base64,([A-Za-z0-9+/=]+)$/.exec(
    dataUrl.trim(),
  );
  if (!match) {
    throw new Error("Invalid PNG data URL");
  }

  const bytes = Buffer.from(match[1], "base64");
  if (bytes.byteLength === 0) {
    throw new Error("Drawing data cannot be empty");
  }
  if (bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new Error("Drawing exceeds maximum size");
  }

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
      createdAt: new Date(),
    })
    .returning({ mediaId: media.id, path: media.path })
    .get();

  return { mediaId: row.mediaId, path: row.path };
}
