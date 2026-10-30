import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  addBoardItem,
  copyItemToActividades,
  createCustomBoard,
  deleteBoard,
  deleteOrCompleteBoardItem,
  updateBoard,
  updateBoardItem,
} from "@/lib/boards";
import { fetchLinkPreview } from "@/lib/link-preview";
import { storeBase64Media } from "../home/route";

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
        | "update_board"
        | "delete_board"
        | "add_item"
        | "update_item"
        | "delete_item"
        | "copy_to_actividades"
        | "complete_item";
      title?: string;
      icon?: string;
      bgColor?: string;
      boardId?: number | string;
      categoryTag?: string;
      notes?: string;
      url?: string;
      linkUrl?: string;
      emoji?: string;
      imageBase64?: string;
      mediaDataUrl?: string;
      itemId?: number | string;
    };

    if (payload.action === "create_board") {
      const board = createCustomBoard({
        title: payload.title ?? "",
        icon: payload.icon ?? "bookmark",
        bgColor: payload.bgColor ?? "#F4EFE8",
        userId: user.id,
      });
      return jsonResponse({ ok: true, board });
    }

    if (payload.action === "update_board") {
      updateBoard({
        boardId: Number(payload.boardId),
        title: payload.title,
        icon: payload.icon,
        bgColor: payload.bgColor,
      });
      return jsonResponse({ ok: true });
    }

    if (payload.action === "delete_board") {
      deleteBoard(Number(payload.boardId));
      return jsonResponse({ ok: true });
    }

    if (payload.action === "add_item") {
      const rawBase64 =
        payload.imageBase64?.trim() || payload.mediaDataUrl?.trim() || "";
      let mediaId: number | null = null;
      if (rawBase64) {
        mediaId = await storeBase64Media({
          base64: rawBase64,
          kind: "image",
          ownerId: user.id,
        });
      }

      const rawUrl = (payload.url ?? payload.linkUrl ?? "").trim();
      let linkTitle: string | null = null;
      let linkThumbnail: string | null = null;
      let linkPlatform: string | null = null;

      if (rawUrl) {
        const preview = await fetchLinkPreview(rawUrl);
        linkTitle = preview.title;
        linkThumbnail = preview.thumbnail;
        linkPlatform = preview.platform;
      }

      const item = addBoardItem({
        boardId: Number(payload.boardId),
        categoryTag: payload.categoryTag,
        title: payload.title || linkTitle || "Elemento",
        notes: payload.notes,
        url: rawUrl || undefined,
        linkTitle,
        linkThumbnail,
        linkPlatform,
        emoji: payload.emoji,
        bgColor: payload.bgColor ?? "#FFDAD6",
        mediaId,
        userId: user.id,
      });
      return jsonResponse({ ok: true, item });
    }

    if (payload.action === "update_item") {
      updateBoardItem({
        itemId: Number(payload.itemId),
        title: payload.title,
        notes: payload.notes,
        categoryTag: payload.categoryTag,
        bgColor: payload.bgColor,
        emoji: payload.emoji,
        url: payload.url ?? payload.linkUrl,
      });
      return jsonResponse({ ok: true });
    }

    if (payload.action === "copy_to_actividades") {
      const copied = copyItemToActividades(Number(payload.itemId), user.id);
      return jsonResponse({ ok: true, item: copied });
    }

    if (
      payload.action === "complete_item" ||
      payload.action === "delete_item"
    ) {
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
