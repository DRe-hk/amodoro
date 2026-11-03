import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  addBoardItem,
  completeBoardItem,
  copyItemToActividades,
  createCustomBoard,
  deleteBoard,
  deleteBoardItem,
  reactToBoardItem,
  reorderBoardItems,
  reorderBoards,
  updateBoard,
  updateBoardItem,
} from "@/lib/boards";
import { fetchLinkPreview } from "@/lib/link-preview";
import { sendPushToPartner } from "@/lib/push";
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
        | "complete_item"
        | "react_item"
        | "reorder_boards"
        | "reorder_items";
      title?: string;
      icon?: string;
      bgColor?: string;
      boardId?: number | string;
      boardIds?: (number | string)[];
      itemIds?: (number | string)[];
      categoryTag?: string;
      notes?: string;
      dueDate?: string | null;
      url?: string;
      linkUrl?: string;
      emoji?: string | null;
      presetText?: string | null;
      imageBase64?: string | null;
      mediaDataUrl?: string | null;
      mediaKind?: "image" | "drawing";
      mediaId?: number | null;
      completionText?: string | null;
      message?: string | null;
      itemId?: number | string;
    };

    if (payload.action === "create_board") {
      const board = createCustomBoard({
        title: payload.title ?? "",
        icon: payload.icon ?? "bookmark",
        bgColor: payload.bgColor ?? "#F27166",
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

    if (payload.action === "reorder_boards") {
      reorderBoards(payload.boardIds ?? []);
      return jsonResponse({ ok: true });
    }

    if (payload.action === "reorder_items") {
      reorderBoardItems(payload.itemIds ?? []);
      return jsonResponse({ ok: true });
    }

    if (payload.action === "add_item") {
      const rawBase64 =
        payload.imageBase64?.trim() || payload.mediaDataUrl?.trim() || "";
      let mediaId: number | null = null;
      if (rawBase64) {
        mediaId = await storeBase64Media({
          base64: rawBase64,
          kind: payload.mediaKind ?? "image",
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
        emoji: payload.emoji ?? undefined,
        bgColor: payload.bgColor ?? "#FFDAD6",
        mediaId,
        dueDate: payload.dueDate,
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
        emoji: payload.emoji ?? undefined,
        url: payload.url ?? payload.linkUrl,
        dueDate: payload.dueDate,
      });
      return jsonResponse({ ok: true });
    }

    if (payload.action === "copy_to_actividades") {
      const copied = copyItemToActividades(Number(payload.itemId), user.id);
      return jsonResponse({ ok: true, item: copied });
    }

    if (payload.action === "complete_item") {
      const rawBase64 =
        payload.imageBase64?.trim() || payload.mediaDataUrl?.trim() || "";
      let completionMediaId: number | null = payload.mediaId ?? null;
      if (rawBase64) {
        completionMediaId = await storeBase64Media({
          base64: rawBase64,
          kind: payload.mediaKind ?? "image",
          ownerId: user.id,
        });
      }

      const completionText =
        payload.completionText ?? payload.message ?? payload.notes ?? null;

      const completed = completeBoardItem({
        itemId: Number(payload.itemId),
        userId: user.id,
        completionText,
        completionMediaId,
      });

      void sendPushToPartner(user.id, {
        title: "¡Actividad completada! ✨",
        body: completed.title,
        data: { type: "completed_item", itemId: String(completed.id) },
      });

      return jsonResponse({ ok: true, item: completed });
    }

    if (payload.action === "delete_item") {
      deleteBoardItem(Number(payload.itemId));
      return jsonResponse({ ok: true });
    }

    if (payload.action === "react_item") {
      const res = reactToBoardItem({
        itemId: Number(payload.itemId),
        userId: user.id,
        emoji: payload.emoji ?? null,
        presetText: payload.presetText ?? null,
      });
      return jsonResponse({ ok: true, removed: res.removed });
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
