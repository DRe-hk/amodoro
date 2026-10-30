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
  emoji: string | null;
  mediaId: number | null;
  addedBy: number;
  addedByUsername: string;
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
      emoji: boardItems.emoji,
      mediaId: boardItems.mediaId,
      addedBy: boardItems.addedBy,
      addedByUsername: users.username,
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
  userId: number;
}) {
  const cleanTitle = input.title.trim();
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
      icon: input.icon?.trim() || "sparkles",
      isSystem: false,
      createdBy: input.userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function addBoardItem(input: {
  boardId: number;
  categoryTag: string;
  title: string;
  notes?: string;
  url?: string;
  emoji?: string;
  mediaId?: number | null;
  userId: number;
}) {
  const cleanTitle = input.title.trim();
  if (!cleanTitle) throw new Error("Escribe un título.");

  return db
    .insert(boardItems)
    .values({
      boardId: input.boardId,
      categoryTag: input.categoryTag.trim().toUpperCase() || "ACTIVIDAD",
      title: cleanTitle,
      notes: input.notes?.trim() || null,
      url: input.url?.trim() || null,
      emoji: input.emoji?.trim() || null,
      mediaId: input.mediaId ?? null,
      addedBy: input.userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function copyItemToActividades(itemId: number, userId: number) {
  const source = db
    .select()
    .from(boardItems)
    .where(eq(boardItems.id, itemId))
    .get();
  if (!source) return null;

  const actBoard = db
    .select()
    .from(boards)
    .where(eq(boards.slug, "actividades"))
    .get();
  if (!actBoard) return null;

  return db
    .insert(boardItems)
    .values({
      boardId: actBoard.id,
      categoryTag: source.categoryTag,
      title: source.title,
      notes: source.notes,
      url: source.url,
      emoji: source.emoji,
      mediaId: source.mediaId,
      addedBy: userId,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function deleteOrCompleteBoardItem(itemId: number) {
  db.update(boardItems)
    .set({ completedAt: new Date() })
    .where(eq(boardItems.id, itemId))
    .run();
}
