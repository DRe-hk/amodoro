import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { db } from "@/db";
import { media, type CardFont, type CardFontSize } from "@/db/schema";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { createHomeCard, reactToHomeCard } from "@/lib/home-cards";
import { fetchLinkPreview } from "@/lib/link-preview";
import { UPLOADS_PATH } from "@/lib/media";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function storeBase64Media(input: {
  base64: string;
  mime?: string;
  kind?: "image" | "drawing";
  ownerId: number;
}): Promise<number> {
  const matchMime = /^data:([^;]+);base64,/.exec(input.base64);
  const detectedMime = matchMime?.[1] || input.mime || "image/png";
  const cleaned = input.base64.replace(/^data:[^;]+;base64,/, "").trim();
  const bytes = Buffer.from(cleaned, "base64");
  if (bytes.byteLength === 0 || bytes.byteLength > 25 * 1024 * 1024) {
    throw new Error("Tamaño de imagen no válido.");
  }

  const ext =
    detectedMime === "image/jpeg" || detectedMime === "image/jpg"
      ? "jpg"
      : detectedMime === "image/webp"
        ? "webp"
        : detectedMime === "image/gif"
          ? "gif"
          : "png";

  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.${ext}`;
  const targetDir = join(
    /*turbopackIgnore: true*/ UPLOADS_PATH,
    id.slice(0, 2),
  );
  const fullPath = join(/*turbopackIgnore: true*/ targetDir, `${id}.${ext}`);

  await mkdir(targetDir, { recursive: true });
  await writeFile(fullPath, bytes);

  const row = db
    .insert(media)
    .values({
      ownerId: input.ownerId,
      kind: input.kind ?? "image",
      path: relPath,
      mime: detectedMime,
      bytes: bytes.byteLength,
      createdAt: new Date(),
    })
    .returning({ id: media.id })
    .get();

  return row.id;
}

export async function POST(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  try {
    const payload = (await request.json()) as {
      action: "create_card" | "react";
      body?: string;
      textContent?: string;
      bgColor?: string;
      fontFamily?: CardFont;
      fontSize?: CardFontSize;
      fontSizePx?: number;
      mediaType?: string;
      imageBase64?: string | null;
      mediaDataUrl?: string | null;
      imageMime?: string;
      mediaKind?: "image" | "drawing";
      linkUrl?: string | null;
      linkTitle?: string | null;
      linkThumbnail?: string | null;
      linkPlatform?: string | null;
      cardId?: number | string;
      emoji?: string | null;
      presetText?: string | null;
    };

    if (payload.action === "create_card") {
      const rawBase64 =
        payload.imageBase64?.trim() || payload.mediaDataUrl?.trim() || "";
      let mediaId: number | null = null;
      if (rawBase64) {
        mediaId = await storeBase64Media({
          base64: rawBase64,
          mime: payload.imageMime,
          kind:
            payload.mediaKind ??
            (payload.mediaType === "drawing" ? "drawing" : "image"),
          ownerId: user.id,
        });
      }

      const rawLink = payload.linkUrl?.trim() || "";
      let linkTitle = payload.linkTitle?.trim() || null;
      let linkThumbnail = payload.linkThumbnail?.trim() || null;
      let linkPlatform = payload.linkPlatform?.trim() || null;

      if (rawLink && !linkTitle) {
        const preview = await fetchLinkPreview(rawLink);
        linkTitle = preview.title;
        linkThumbnail = preview.thumbnail;
        linkPlatform = preview.platform;
      }

      const textBody = (payload.body ?? payload.textContent ?? "").trim();

      const card = createHomeCard({
        authorId: user.id,
        mediaId,
        mediaType: payload.mediaType,
        linkUrl: rawLink || null,
        linkTitle,
        linkThumbnail,
        linkPlatform,
        body: textBody,
        bgColor: payload.bgColor ?? "#FFDAD6",
        fontFamily: payload.fontFamily ?? "sans",
        fontSize: payload.fontSize ?? "md",
        fontSizePx: payload.fontSizePx,
      });

      return jsonResponse({ ok: true, card });
    }

    if (payload.action === "react") {
      const cardId = Number(payload.cardId);
      if (!Number.isInteger(cardId)) {
        return jsonResponse({ ok: false, error: "cardId inválido" }, 400);
      }
      reactToHomeCard({
        cardId,
        userId: user.id,
        emoji: payload.emoji ?? null,
        presetText: payload.presetText ?? null,
      });
      return jsonResponse({ ok: true });
    }

    return jsonResponse({ ok: false, error: "Acción desconocida" }, 400);
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error en Home API",
      },
      400,
    );
  }
}
