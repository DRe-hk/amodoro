import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  addBoardItem,
  copyItemToActividades,
  createCustomBoard,
  deleteOrCompleteBoardItem,
} from "@/lib/boards";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function POST(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  try {
    const payload = (await request.json()) as {
      action:
        | "create_board"
        | "add_item"
        | "copy_to_actividades"
        | "complete_item";
      title?: string;
      icon?: string;
      boardId?: number;
      categoryTag?: string;
      notes?: string;
      url?: string;
      emoji?: string;
      itemId?: number;
    };

    if (payload.action === "create_board") {
      const board = createCustomBoard({
        title: payload.title ?? "",
        icon: payload.icon ?? "sparkles",
        userId: user.id,
      });
      return jsonResponse({ ok: true, board });
    }

    if (payload.action === "add_item") {
      const item = addBoardItem({
        boardId: Number(payload.boardId),
        categoryTag: payload.categoryTag ?? "ACTIVIDAD",
        title: payload.title ?? "",
        notes: payload.notes,
        url: payload.url,
        emoji: payload.emoji,
        userId: user.id,
      });
      return jsonResponse({ ok: true, item });
    }

    if (payload.action === "copy_to_actividades") {
      const copied = copyItemToActividades(Number(payload.itemId), user.id);
      return jsonResponse({ ok: true, item: copied });
    }

    if (payload.action === "complete_item") {
      deleteOrCompleteBoardItem(Number(payload.itemId));
      return jsonResponse({ ok: true });
    }

    return jsonResponse({ ok: false, error: "Acción desconocida" }, 400);
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error en Boards API",
      },
      400,
    );
  }
}
