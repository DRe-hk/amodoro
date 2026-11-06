import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { createSticker, deleteSticker, listStickers } from "@/lib/stickers";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  const stickers = listStickers(user.id);
  return jsonResponse({ ok: true, stickers });
}

export async function POST(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  try {
    const contentType = request.headers.get("content-type") ?? "";
    let buffer: Buffer;

    if (contentType.includes("multipart/form-data")) {
      const formData = await request.formData();
      const file = (formData.get("file") ||
        formData.get("image") ||
        formData.get("sticker")) as File | null;
      if (!file) {
        return jsonResponse(
          { ok: false, error: "No se proporcionó ningún archivo de sticker." },
          400,
        );
      }
      buffer = Buffer.from(await file.arrayBuffer());
    } else {
      const body = (await request.json()) as {
        dataUrl?: string;
        imageBase64?: string;
        base64?: string;
        image?: string;
      };
      const rawB64 = (
        body.dataUrl ||
        body.imageBase64 ||
        body.base64 ||
        body.image ||
        ""
      ).trim();

      if (!rawB64) {
        return jsonResponse(
          { ok: false, error: "No se proporcionó imagen para el sticker." },
          400,
        );
      }

      const cleaned = rawB64.replace(/^data:[^;]+;base64,/, "").trim();
      buffer = Buffer.from(cleaned, "base64");
    }

    const sticker = await createSticker(user.id, buffer);
    return jsonResponse({ ok: true, sticker }, 201);
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error:
          err instanceof Error ? err.message : "Error al crear el sticker.",
      },
      400,
    );
  }
}

export async function DELETE(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  try {
    let id: number | null = null;
    const url = new URL(request.url);
    const queryId = url.searchParams.get("id");
    if (queryId) {
      id = Number(queryId);
    } else {
      try {
        const body = (await request.json()) as { id?: number | string };
        if (body.id != null) {
          id = Number(body.id);
        }
      } catch {
        // ignore
      }
    }

    if (!id || !Number.isInteger(id)) {
      return jsonResponse({ ok: false, error: "ID de sticker inválido." }, 400);
    }

    const result = deleteSticker(id, user.id);
    return jsonResponse({ ok: true, ...result });
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error:
          err instanceof Error ? err.message : "Error al eliminar el sticker.",
      },
      400,
    );
  }
}
