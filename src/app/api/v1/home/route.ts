import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { db } from "@/db";
import { media, type CardFont, type CardFontSize } from "@/db/schema";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { createHomeCard, reactToHomeCard } from "@/lib/home-cards";
import { UPLOADS_PATH } from "@/lib/media";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

async function storeBase64Media(input: {
  base64: string;
  mime?: string;
  kind?: "image" | "drawing";
  ownerId: number;
}): Promise<number> {
  const cleaned = input.base64.replace(/^data:[^;]+;base64,/, "").trim();
  const bytes = Buffer.from(cleaned, "base64");
  if (bytes.byteLength === 0 || bytes.byteLength > 25 * 1024 * 1024) {
    throw new Error("Tamaño de imagen no válido.");
  }

  const mime = input.mime || "image/png";
  const ext =
    mime === "image/jpeg"
      ? "jpg"
      : mime === "image/webp"
        ? "webp"
        : mime === "image/gif"
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
      mime,
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
      bgColor?: string;
      fontFamily?: CardFont;
      fontSize?: CardFontSize;
      imageBase64?: string | null;
      imageMime?: string;
      mediaKind?: "image" | "drawing";
      cardId?: number;
      emoji?: string | null;
      presetText?: string | null;
    };

    if (payload.action === "create_card") {
      let mediaId: number | null = null;
      if (payload.imageBase64) {
        mediaId = await storeBase64Media({
          base64: payload.imageBase64,
          mime: payload.imageMime,
          kind: payload.mediaKind ?? "image",
          ownerId: user.id,
        });
      }

      const card = createHomeCard({
        authorId: user.id,
        mediaId,
        body: payload.body ?? "",
        bgColor: payload.bgColor ?? "#FADADD",
        fontFamily: payload.fontFamily ?? "sans",
        fontSize: payload.fontSize ?? "lg",
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
