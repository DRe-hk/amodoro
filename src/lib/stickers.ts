import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { desc, eq, inArray, sql } from "drizzle-orm";
import { db } from "@/db";
import { media, stickers } from "@/db/schema";
import { getPartnerUser } from "./auth";
import {
  UPLOADS_PATH,
  checkMediaQuota,
  detectImageMimeFromMagicBytes,
} from "./media";

export const MAX_STICKER_BYTES = 1024 * 1024; // 1 MB
export const MAX_STICKERS_PER_USER = 60;

export type StickerDto = {
  id: number;
  ownerId: number;
  isMine: boolean;
  mediaId: number;
  mediaUrl: string;
  createdAt: string;
};

export function listStickers(userId: number): StickerDto[] {
  const partner = getPartnerUser(userId);
  const ownerIds = partner ? [userId, partner.id] : [userId];

  const rows = db
    .select()
    .from(stickers)
    .where(inArray(stickers.ownerId, ownerIds))
    .orderBy(desc(stickers.createdAt), desc(stickers.id))
    .all();

  return rows.map((s) => ({
    id: s.id,
    ownerId: s.ownerId,
    isMine: s.ownerId === userId,
    mediaId: s.mediaId,
    mediaUrl: `/api/media/${s.mediaId}`,
    createdAt:
      s.createdAt instanceof Date
        ? s.createdAt.toISOString()
        : new Date(Number(s.createdAt) * 1000).toISOString(),
  }));
}

export async function createSticker(
  userId: number,
  fileBuffer: Buffer,
  _mime?: string,
): Promise<StickerDto> {
  void _mime;
  const countRow = db
    .select({ count: sql<number>`count(*)` })
    .from(stickers)
    .where(eq(stickers.ownerId, userId))
    .get();

  if ((countRow?.count ?? 0) >= MAX_STICKERS_PER_USER) {
    throw new Error(
      `Has alcanzado el límite máximo de ${MAX_STICKERS_PER_USER} stickers.`,
    );
  }

  if (!fileBuffer || fileBuffer.byteLength === 0) {
    throw new Error("El archivo de sticker no puede estar vacío.");
  }

  if (fileBuffer.byteLength > MAX_STICKER_BYTES) {
    throw new Error("El sticker excede el tamaño máximo permitido de 1 MB.");
  }

  const detected = detectImageMimeFromMagicBytes(fileBuffer);
  if (
    !detected ||
    (detected.mime !== "image/png" && detected.mime !== "image/webp")
  ) {
    throw new Error(
      "Formato no permitido. Solo se aceptan stickers en formato PNG o WebP.",
    );
  }

  checkMediaQuota(fileBuffer.byteLength);

  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.${detected.ext}`;
  const targetDir = join(/*turbopackIgnore: true*/ UPLOADS_PATH, id.slice(0, 2));
  const fullPath = join(/*turbopackIgnore: true*/ targetDir, `${id}.${detected.ext}`);

  await mkdir(targetDir, { recursive: true });
  await writeFile(fullPath, fileBuffer);

  const mediaRow = db
    .insert(media)
    .values({
      ownerId: userId,
      kind: "sticker",
      path: relPath,
      mime: detected.mime,
      bytes: fileBuffer.byteLength,
      altText: "Sticker",
      createdAt: new Date(),
    })
    .returning()
    .get();

  const stickerRow = db
    .insert(stickers)
    .values({
      ownerId: userId,
      mediaId: mediaRow.id,
      createdAt: new Date(),
    })
    .returning()
    .get();

  return {
    id: stickerRow.id,
    ownerId: stickerRow.ownerId,
    isMine: true,
    mediaId: stickerRow.mediaId,
    mediaUrl: `/api/media/${stickerRow.mediaId}`,
    createdAt:
      stickerRow.createdAt instanceof Date
        ? stickerRow.createdAt.toISOString()
        : new Date(Number(stickerRow.createdAt) * 1000).toISOString(),
  };
}

export function deleteSticker(
  stickerId: number,
  userId: number,
  isAdmin = false,
): { deleted: boolean; id: number } {
  const sticker = db
    .select()
    .from(stickers)
    .where(eq(stickers.id, stickerId))
    .get();

  if (!sticker) {
    throw new Error("Sticker no encontrado.");
  }

  if (!isAdmin && sticker.ownerId !== userId) {
    throw new Error("No tienes permiso para eliminar este sticker.");
  }

  db.delete(stickers).where(eq(stickers.id, stickerId)).run();
  return { deleted: true, id: stickerId };
}
