import { asc, desc, eq, isNull } from "drizzle-orm";
import { db } from "@/db";
import { boardItems, boards, users } from "@/db/schema";

export type BoardRow = typeof boards.$inferSelect;

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
  addedBy: number;
  addedByUsername: string;
  addedByDisplayName: string;
  addedByAvatarId: string;
  addedByNickname: string;
  completedAt: Date | null;
  createdAt: Date;
};

export function listBoardsWithItems(): {
  boards: BoardRow[];
  itemsByBoardId: Record<number, HydratedBoardItem[]>;
  actividadesBoardId: number;
} {
  const allBoards = db
    .select()
    .from(boards)
    .orderBy(desc(boards.isSystem), asc(boards.id))
    .all();

  const rows = db
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
      addedBy: boardItems.addedBy,
      addedByUsername: users.username,
      addedByDisplayName: users.displayName,
      addedByAvatarId: users.avatarId,
      addedByNickname: users.nicknameByPartner,
      completedAt: boardItems.completedAt,
      createdAt: boardItems.createdAt,
    })
    .from(boardItems)
    .innerJoin(users, eq(boardItems.addedBy, users.id))
    .where(isNull(boardItems.completedAt))
    .orderBy(desc(boardItems.id))
    .all();

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

  return db
    .insert(boards)
    .values({
      slug,
      title: cleanTitle,
      icon: input.icon?.trim() || "bookmark",
      bgColor: input.bgColor?.trim() || "#F4EFE8",
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
      bgColor: input.bgColor?.trim() || "#FFDAD6",
      mediaId: input.mediaId ?? null,
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
      addedBy: userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function deleteOrCompleteBoardItem(itemId: number) {
  db.delete(boardItems).where(eq(boardItems.id, itemId)).run();
}
