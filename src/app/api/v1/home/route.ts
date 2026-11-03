import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { db } from "@/db";
import { media, type CardFont, type CardFontSize } from "@/db/schema";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  createHomeCard,
  deleteHomeCard,
  reactToHomeCard,
  replyToHomeCard,
  updateHomeCard,
} from "@/lib/home-cards";
import { fetchLinkPreview } from "@/lib/link-preview";
import {
  MAX_IMAGE_BYTES,
  UPLOADS_PATH,
  checkMediaQuota,
  detectImageMimeFromMagicBytes,
} from "@/lib/media";
import { sendPushToPartner } from "@/lib/push";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function storeBase64Media(input: {
  base64: string;
  mime?: string;
  kind?: "image" | "drawing";
  altText?: string | null;
  ownerId: number;
}): Promise<number> {
  const cleaned = input.base64.replace(/^data:[^;]+;base64,/, "").trim();
  const bytes = Buffer.from(cleaned, "base64");
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new Error("Tamaño de imagen no válido.");
  }

  const detected = detectImageMimeFromMagicBytes(bytes);
  if (!detected) {
    throw new Error("Formato de imagen no permitido.");
  }

  checkMediaQuota(bytes.byteLength);

  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.${detected.ext}`;
  const targetDir = join(
    /*turbopackIgnore: true*/ UPLOADS_PATH,
    id.slice(0, 2),
  );
  const fullPath = join(
    /*turbopackIgnore: true*/ targetDir,
    `${id}.${detected.ext}`,
  );

  await mkdir(targetDir, { recursive: true });
  await writeFile(fullPath, bytes);

  const row = db
    .insert(media)
    .values({
      ownerId: input.ownerId,
      kind: input.kind ?? "image",
      path: relPath,
      mime: detected.mime,
      bytes: bytes.byteLength,
      altText: input.altText?.trim() || null,
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
      action:
        | "create_card"
        | "update_card"
        | "delete_card"
        | "react"
        | "reply_card"
        | "reply";
      body?: string;
      textContent?: string;
      altText?: string | null;
      bgColor?: string;
      fontFamily?: CardFont;
      fontSize?: CardFontSize;
      fontSizePx?: number;
      mediaType?: string;
      keepExistingMedia?: boolean;
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
          altText: payload.altText,
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
        altText: payload.altText,
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

      void sendPushToPartner(user.id, {
        title: "Nueva nota en Amodoro 💌",
        body: textBody ? textBody.slice(0, 80) : "Tu pareja te dejó una nueva tarjeta.",
        data: { type: "home_card", cardId: String(card.id) },
      });

      return jsonResponse({ ok: true, card });
    }

    if (payload.action === "update_card") {
      const cardId = Number(payload.cardId);
      if (!Number.isInteger(cardId)) {
        return jsonResponse({ ok: false, error: "cardId inválido" }, 400);
      }

      const rawBase64 =
        payload.imageBase64?.trim() || payload.mediaDataUrl?.trim() || "";
      let newMediaId: number | null = null;
      if (rawBase64) {
        newMediaId = await storeBase64Media({
          base64: rawBase64,
          mime: payload.imageMime,
          kind:
            payload.mediaKind ??
            (payload.mediaType === "drawing" ? "drawing" : "image"),
          altText: payload.altText,
          ownerId: user.id,
        });
      }

      const rawLink = payload.linkUrl?.trim() || "";
      let linkTitle = payload.linkTitle?.trim() || null;
      let linkThumbnail = payload.linkThumbnail?.trim() || null;
      let linkPlatform = payload.linkPlatform?.trim() || null;

      if (payload.mediaType === "link" && rawLink && !linkTitle) {
        const preview = await fetchLinkPreview(rawLink);
        linkTitle = preview.title;
        linkThumbnail = preview.thumbnail;
        linkPlatform = preview.platform;
      }

      const textBody = (payload.body ?? payload.textContent ?? "").trim();

      const card = updateHomeCard({
        cardId,
        authorId: user.id,
        newMediaId,
        keepExistingMedia: payload.keepExistingMedia === true,
        mediaType: payload.mediaType,
        altText: payload.altText,
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

    if (payload.action === "delete_card") {
      const cardId = Number(payload.cardId);
      if (!Number.isInteger(cardId)) {
        return jsonResponse({ ok: false, error: "cardId inválido" }, 400);
      }
      deleteHomeCard({
        cardId,
        authorId: user.id,
      });
      return jsonResponse({ ok: true });
    }

    if (payload.action === "reply_card" || payload.action === "reply") {
      const reply = replyToHomeCard(user, payload);
      void sendPushToPartner(user.id, {
        title: "Nueva respuesta en amodoro 💬",
        body: reply.textContent
          ? `${user.displayName}: "${reply.textContent}"`
          : `${user.displayName} respondió con una imagen`,
        data: {
          type: "reply",
          cardId: String(reply.cardId),
          replyId: String(reply.id),
        },
      });
      return jsonResponse({ ok: true, reply });
    }

    if (payload.action === "react") {
      const cardId = Number(payload.cardId);
      if (!Number.isInteger(cardId)) {
        return jsonResponse({ ok: false, error: "cardId inválido" }, 400);
      }
      const res = reactToHomeCard({
        cardId,
        userId: user.id,
        emoji: payload.emoji ?? null,
        presetText: payload.presetText ?? null,
      });

      if (!res.removed) {
        const summary = [payload.emoji, payload.presetText]
          .filter(Boolean)
          .join(" ");
        void sendPushToPartner(user.id, {
          title: "Nueva reacción ❤️",
          body: summary || "Tu pareja reaccionó a tu nota.",
          data: { type: "reaction", cardId: String(cardId) },
        });
      }

      return jsonResponse({ ok: true, removed: res.removed, reply: res.reply });
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
