import { and, asc, desc, eq, inArray, isNotNull, isNull } from "drizzle-orm";
import { db } from "@/db";
import {
  boardItemReactions,
  boardItems,
  boards,
  users,
} from "@/db/schema";
import { getPartnerUser } from "./auth";

export type BoardRow = typeof boards.$inferSelect;

export type BoardItemReactionRow = {
  id: number;
  itemId: number;
  userId: number;
  emoji: string | null;
  presetText: string | null;
  createdAt: Date;
};

export type HydratedBoardItem = {
  id: number;
  boardId: number;
  categoryTag: string;
  title: string;
  notes: string | null;
  url: string | null;
  linkTitle: string | null;
  linkThumbnail: string | null;
  linkPlatform: string | null;
  emoji: string | null;
  bgColor: string;
  mediaId: number | null;
  sortOrder: number;
  dueDate: string | null;
  addedBy: number;
  addedByUsername: string;
  addedByDisplayName: string;
  addedByAvatarId: string;
  addedByNickname: string;
  completedAt: Date | null;
  completedBy: number | null;
  completionText: string | null;
  completionMediaId: number | null;
  createdAt: Date;
  reactions: BoardItemReactionRow[];
};

function attachItemReactions(
  rows: Omit<HydratedBoardItem, "reactions">[],
): HydratedBoardItem[] {
  if (rows.length === 0) return [];
  const itemIds = rows.map((r) => r.id);
  const allReactions = db
    .select()
    .from(boardItemReactions)
    .where(inArray(boardItemReactions.itemId, itemIds))
    .orderBy(desc(boardItemReactions.createdAt))
    .all();

  const byItem = new Map<number, BoardItemReactionRow[]>();
  for (const rx of allReactions) {
    const list = byItem.get(rx.itemId) ?? [];
    list.push(rx);
    byItem.set(rx.itemId, list);
  }

  return rows.map((r) => ({
    ...r,
    reactions: byItem.get(r.id) ?? [],
  }));
}

export function listBoardsWithItems(viewerId?: number): {
  boards: BoardRow[];
  itemsByBoardId: Record<number, HydratedBoardItem[]>;
  actividadesBoardId: number;
} {
  const allBoards = db
    .select()
    .from(boards)
    .orderBy(asc(boards.sortOrder), desc(boards.isSystem), asc(boards.id))
    .all();

  let allowedUserIds: number[] | null = null;
  if (viewerId !== undefined) {
    const partner = getPartnerUser(viewerId);
    allowedUserIds = partner ? [viewerId, partner.id] : [viewerId];
  }

  const rawRows = db
    .select({
      id: boardItems.id,
      boardId: boardItems.boardId,
      categoryTag: boardItems.categoryTag,
      title: boardItems.title,
      notes: boardItems.notes,
      url: boardItems.url,
      linkTitle: boardItems.linkTitle,
      linkThumbnail: boardItems.linkThumbnail,
      linkPlatform: boardItems.linkPlatform,
      emoji: boardItems.emoji,
      bgColor: boardItems.bgColor,
      mediaId: boardItems.mediaId,
      sortOrder: boardItems.sortOrder,
      dueDate: boardItems.dueDate,
      addedBy: boardItems.addedBy,
      addedByUsername: users.username,
      addedByDisplayName: users.displayName,
      addedByAvatarId: users.avatarId,
      addedByNickname: users.nicknameByPartner,
      completedAt: boardItems.completedAt,
      completedBy: boardItems.completedBy,
      completionText: boardItems.completionText,
      completionMediaId: boardItems.completionMediaId,
      createdAt: boardItems.createdAt,
    })
    .from(boardItems)
    .innerJoin(users, eq(boardItems.addedBy, users.id))
    .where(
      allowedUserIds
        ? and(
            isNull(boardItems.completedAt),
            inArray(boardItems.addedBy, allowedUserIds),
          )
        : isNull(boardItems.completedAt),
    )
    .orderBy(asc(boardItems.sortOrder), desc(boardItems.id))
    .all();

  const rows = attachItemReactions(rawRows);

  const itemsByBoardId: Record<number, HydratedBoardItem[]> = {};
  for (const b of allBoards) {
    itemsByBoardId[b.id] = [];
  }
  for (const item of rows) {
    if (!itemsByBoardId[item.boardId]) {
      itemsByBoardId[item.boardId] = [];
    }
    itemsByBoardId[item.boardId]!.push(item);
  }

  const actBoard =
    allBoards.find((b) => b.slug === "actividades") ?? allBoards[0];

  return {
    boards: allBoards,
    itemsByBoardId,
    actividadesBoardId: actBoard?.id ?? 1,
  };
}

export function listCompletedBoardItems(viewerId?: number): HydratedBoardItem[] {
  let allowedUserIds: number[] | null = null;
  if (viewerId !== undefined) {
    const partner = getPartnerUser(viewerId);
    allowedUserIds = partner ? [viewerId, partner.id] : [viewerId];
  }

  const rawRows = db
    .select({
      id: boardItems.id,
      boardId: boardItems.boardId,
      categoryTag: boardItems.categoryTag,
      title: boardItems.title,
      notes: boardItems.notes,
      url: boardItems.url,
      linkTitle: boardItems.linkTitle,
      linkThumbnail: boardItems.linkThumbnail,
      linkPlatform: boardItems.linkPlatform,
      emoji: boardItems.emoji,
      bgColor: boardItems.bgColor,
      mediaId: boardItems.mediaId,
      sortOrder: boardItems.sortOrder,
      dueDate: boardItems.dueDate,
      addedBy: boardItems.addedBy,
      addedByUsername: users.username,
      addedByDisplayName: users.displayName,
      addedByAvatarId: users.avatarId,
      addedByNickname: users.nicknameByPartner,
      completedAt: boardItems.completedAt,
      completedBy: boardItems.completedBy,
      completionText: boardItems.completionText,
      completionMediaId: boardItems.completionMediaId,
      createdAt: boardItems.createdAt,
    })
    .from(boardItems)
    .innerJoin(users, eq(boardItems.addedBy, users.id))
    .where(
      allowedUserIds
        ? and(
            isNotNull(boardItems.completedAt),
            inArray(boardItems.addedBy, allowedUserIds),
          )
        : isNotNull(boardItems.completedAt),
    )
    .orderBy(desc(boardItems.completedAt), desc(boardItems.id))
    .all();

  return attachItemReactions(rawRows);
}

export function createCustomBoard(input: {
  title: string;
  icon?: string;
  bgColor?: string;
  userId: number;
}) {
  const cleanTitle = input.title.trim().toUpperCase();
  if (!cleanTitle) throw new Error("El tablero necesita un nombre.");

  const baseSlug = cleanTitle
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
  const slug = `${baseSlug || "tablero"}-${Date.now().toString(36)}`;

  const existingBoards = db.select().from(boards).all();
  const maxOrder = existingBoards.reduce(
    (max, b) => Math.max(max, b.sortOrder ?? 0),
    0,
  );

  return db
    .insert(boards)
    .values({
      slug,
      title: cleanTitle,
      icon: input.icon?.trim() || "bookmark",
      bgColor: input.bgColor?.trim() || "#F27166",
      sortOrder: maxOrder + 1,
      isSystem: false,
      createdBy: input.userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function updateBoard(input: {
  boardId: number;
  title?: string;
  icon?: string;
  bgColor?: string;
}) {
  const updates: Partial<typeof boards.$inferInsert> = {};
  if (input.title && input.title.trim()) {
    updates.title = input.title.trim().toUpperCase();
  }
  if (input.icon && input.icon.trim()) {
    updates.icon = input.icon.trim();
  }
  if (input.bgColor && input.bgColor.trim()) {
    updates.bgColor = input.bgColor.trim();
  }
  if (Object.keys(updates).length > 0) {
    db.update(boards)
      .set(updates)
      .where(eq(boards.id, input.boardId))
      .run();
  }
}

export function deleteBoard(boardId: number) {
  const target = db.select().from(boards).where(eq(boards.id, boardId)).get();
  if (!target) return;
  if (target.slug === "actividades") {
    throw new Error("El tablero principal PENDIENTES no se puede eliminar.");
  }
  db.delete(boards).where(eq(boards.id, boardId)).run();
}

export function reorderBoards(boardIds: (number | string)[]) {
  boardIds.forEach((rawId, idx) => {
    const id = Number(rawId);
    if (Number.isInteger(id) && id > 0) {
      db.update(boards)
        .set({ sortOrder: idx })
        .where(eq(boards.id, id))
        .run();
    }
  });
}

export function reorderBoardItems(itemIds: (number | string)[]) {
  itemIds.forEach((rawId, idx) => {
    const id = Number(rawId);
    if (Number.isInteger(id) && id > 0) {
      db.update(boardItems)
        .set({ sortOrder: idx })
        .where(eq(boardItems.id, id))
        .run();
    }
  });
}

export function addBoardItem(input: {
  boardId: number;
  categoryTag?: string;
  title: string;
  notes?: string;
  url?: string;
  linkTitle?: string | null;
  linkThumbnail?: string | null;
  linkPlatform?: string | null;
  emoji?: string;
  bgColor?: string;
  mediaId?: number | null;
  dueDate?: string | null;
  userId: number;
}) {
  const cleanTitle = input.title.trim();
  if (!cleanTitle) throw new Error("Escribe un título.");

  const parentBoard = db
    .select()
    .from(boards)
    .where(eq(boards.id, input.boardId))
    .get();

  const resolvedCategory =
    input.categoryTag?.trim().toUpperCase() ||
    (parentBoard && parentBoard.slug !== "actividades"
      ? parentBoard.title.toUpperCase()
      : "PENDIENTE");

  return db
    .insert(boardItems)
    .values({
      boardId: input.boardId,
      categoryTag: resolvedCategory,
      title: cleanTitle,
      notes: input.notes?.trim() || null,
      url: input.url?.trim() || null,
      linkTitle: input.linkTitle?.trim() || null,
      linkThumbnail: input.linkThumbnail?.trim() || null,
      linkPlatform: input.linkPlatform?.trim() || null,
      emoji: input.emoji?.trim() || null,
      bgColor: input.bgColor?.trim() || parentBoard?.bgColor || "#FFDAD6",
      mediaId: input.mediaId ?? null,
      dueDate: input.dueDate?.trim() || null,
      addedBy: input.userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function updateBoardItem(input: {
  itemId: number;
  title?: string;
  notes?: string;
  categoryTag?: string;
  bgColor?: string;
  emoji?: string;
  url?: string;
  dueDate?: string | null;
}) {
  const updates: Partial<typeof boardItems.$inferInsert> = {};
  if (typeof input.title === "string" && input.title.trim()) {
    updates.title = input.title.trim();
  }
  if (typeof input.notes === "string") {
    updates.notes = input.notes.trim() || null;
  }
  if (typeof input.categoryTag === "string" && input.categoryTag.trim()) {
    updates.categoryTag = input.categoryTag.trim().toUpperCase();
  }
  if (typeof input.bgColor === "string" && input.bgColor.trim()) {
    updates.bgColor = input.bgColor.trim();
  }
  if (typeof input.emoji === "string") {
    updates.emoji = input.emoji.trim() || null;
  }
  if (typeof input.url === "string") {
    updates.url = input.url.trim() || null;
  }
  if (input.dueDate !== undefined) {
    updates.dueDate = input.dueDate?.trim() || null;
  }
  if (Object.keys(updates).length > 0) {
    db.update(boardItems)
      .set(updates)
      .where(eq(boardItems.id, input.itemId))
      .run();
  }
}

export function copyItemToActividades(itemId: number, userId: number) {
  const source = db
    .select()
    .from(boardItems)
    .where(eq(boardItems.id, itemId))
    .get();
  if (!source) return null;

  const sourceBoard = db
    .select()
    .from(boards)
    .where(eq(boards.id, source.boardId))
    .get();

  const actBoard = db
    .select()
    .from(boards)
    .where(eq(boards.slug, "actividades"))
    .get();
  if (!actBoard) return null;

  const tag =
    sourceBoard && sourceBoard.slug !== "actividades"
      ? sourceBoard.title.toUpperCase()
      : source.categoryTag;

  return db
    .insert(boardItems)
    .values({
      boardId: actBoard.id,
      categoryTag: tag,
      title: source.title,
      notes: source.notes,
      url: source.url,
      linkTitle: source.linkTitle,
      linkThumbnail: source.linkThumbnail,
      linkPlatform: source.linkPlatform,
      emoji: source.emoji,
      bgColor: source.bgColor,
      mediaId: source.mediaId,
      dueDate: source.dueDate,
      addedBy: userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function completeBoardItem(input: {
  itemId: number;
  userId: number;
  completionText?: string | null;
  completionMediaId?: number | null;
}) {
  const existing = db
    .select()
    .from(boardItems)
    .where(eq(boardItems.id, input.itemId))
    .get();

  if (!existing) {
    throw new Error("Elemento no encontrado.");
  }

  const cleanText = input.completionText?.trim() || "";
  const mediaId = input.completionMediaId ?? null;

  if (!cleanText && !mediaId) {
    throw new Error(
      "Añade una foto, imagen o mensaje para guardar este recuerdo en el historial.",
    );
  }

  return db
    .update(boardItems)
    .set({
      completedAt: new Date(),
      completedBy: input.userId,
      completionText: cleanText || null,
      completionMediaId: mediaId,
    })
    .where(eq(boardItems.id, input.itemId))
    .returning()
    .get();
}

export function deleteBoardItem(itemId: number) {
  db.delete(boardItems).where(eq(boardItems.id, itemId)).run();
}

export function deleteOrCompleteBoardItem(itemId: number) {
  deleteBoardItem(itemId);
}

export function reactToBoardItem(input: {
  itemId: number;
  userId: number;
  emoji?: string | null;
  presetText?: string | null;
}) {
  const item = db
    .select()
    .from(boardItems)
    .where(eq(boardItems.id, input.itemId))
    .get();
  if (!item) {
    throw new Error("Elemento no encontrado.");
  }

  const emoji = input.emoji?.trim() || null;
  const presetText = input.presetText?.trim() || null;

  const existing = db
    .select()
    .from(boardItemReactions)
    .where(eq(boardItemReactions.itemId, input.itemId))
    .all()
    .find((r) => r.userId === input.userId);

  if (
    (!emoji && !presetText) ||
    (existing &&
      emoji &&
      !presetText &&
      existing.emoji === emoji &&
      !existing.presetText) ||
    (existing &&
      presetText &&
      !emoji &&
      existing.presetText === presetText &&
      !existing.emoji)
  ) {
    if (existing) {
      db.delete(boardItemReactions)
        .where(eq(boardItemReactions.id, existing.id))
        .run();
    }
    return { removed: true };
  }

  if (existing) {
    db.update(boardItemReactions)
      .set({
        emoji: emoji ?? existing.emoji,
        presetText: presetText ?? existing.presetText,
        createdAt: new Date(),
      })
      .where(eq(boardItemReactions.id, existing.id))
      .run();
  } else {
    db.insert(boardItemReactions)
      .values({
        itemId: input.itemId,
        userId: input.userId,
        emoji,
        presetText,
        createdAt: new Date(),
      })
      .run();
  }
  return { removed: false };
}
