import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { deleteSticker } from "@/lib/stickers";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function DELETE(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  const { id: rawId } = await context.params;
  const id = Number(rawId);
  if (!Number.isInteger(id) || id <= 0) {
    return jsonResponse({ ok: false, error: "ID de sticker inválido." }, 400);
  }

  try {
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
