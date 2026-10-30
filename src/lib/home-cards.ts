import { desc, eq, inArray, ne } from "drizzle-orm";
import { db } from "@/db";
import {
  homeCardReactions,
  homeCards,
  users,
  type CardFont,
  type CardFontSize,
} from "@/db/schema";

export type ReactionItem = {
  id: number;
  cardId: number;
  userId: number;
  emoji: string | null;
  presetText: string | null;
  createdAt: Date;
};

export type HydratedHomeCard = {
  id: number;
  authorId: number;
  authorUsername: string;
  authorNicknameByPartner: string;
  mediaId: number | null;
  body: string;
  bgColor: string;
  fontFamily: CardFont;
  fontSize: CardFontSize;
  createdAt: Date;
  reactions: ReactionItem[];
};

function attachReactions(
  rows: {
    id: number;
    authorId: number;
    authorUsername: string;
    authorNicknameByPartner: string;
    mediaId: number | null;
    body: string;
    bgColor: string;
    fontFamily: CardFont;
    fontSize: CardFontSize;
    createdAt: Date;
  }[],
): HydratedHomeCard[] {
  if (rows.length === 0) return [];
  const cardIds = rows.map((r) => r.id);
  const allReactions = db
    .select()
    .from(homeCardReactions)
    .where(inArray(homeCardReactions.cardId, cardIds))
    .orderBy(desc(homeCardReactions.createdAt))
    .all();

  const byCard = new Map<number, ReactionItem[]>();
  for (const rx of allReactions) {
    const list = byCard.get(rx.cardId) ?? [];
    list.push(rx);
    byCard.set(rx.cardId, list);
  }

  return rows.map((r) => ({
    ...r,
    reactions: byCard.get(r.id) ?? [],
  }));
}

export function getReceivedHomeCards(viewerId: number): {
  latest: HydratedHomeCard | null;
  history: HydratedHomeCard[];
} {
  const rows = db
    .select({
      id: homeCards.id,
      authorId: homeCards.authorId,
      authorUsername: users.username,
      authorNicknameByPartner: users.nicknameByPartner,
      mediaId: homeCards.mediaId,
      body: homeCards.body,
      bgColor: homeCards.bgColor,
      fontFamily: homeCards.fontFamily,
      fontSize: homeCards.fontSize,
      createdAt: homeCards.createdAt,
    })
    .from(homeCards)
    .innerJoin(users, eq(homeCards.authorId, users.id))
    .where(ne(homeCards.authorId, viewerId))
    .orderBy(desc(homeCards.createdAt), desc(homeCards.id))
    .all();

  const hydrated = attachReactions(rows);
  return {
    latest: hydrated[0] ?? null,
    history: hydrated.slice(1),
  };
}

export function getSentHomeCards(viewerId: number): HydratedHomeCard[] {
  const rows = db
    .select({
      id: homeCards.id,
      authorId: homeCards.authorId,
      authorUsername: users.username,
      authorNicknameByPartner: users.nicknameByPartner,
      mediaId: homeCards.mediaId,
      body: homeCards.body,
      bgColor: homeCards.bgColor,
      fontFamily: homeCards.fontFamily,
      fontSize: homeCards.fontSize,
      createdAt: homeCards.createdAt,
    })
    .from(homeCards)
    .innerJoin(users, eq(homeCards.authorId, users.id))
    .where(eq(homeCards.authorId, viewerId))
    .orderBy(desc(homeCards.createdAt), desc(homeCards.id))
    .all();

  return attachReactions(rows);
}

export function createHomeCard(input: {
  authorId: number;
  mediaId?: number | null;
  body: string;
  bgColor: string;
  fontFamily: CardFont;
  fontSize: CardFontSize;
}) {
  const cleanBody = input.body.trim();
  if (!cleanBody && !input.mediaId) {
    throw new Error("Escribe un mensaje o añade una imagen/dibujo.");
  }

  return db
    .insert(homeCards)
    .values({
      authorId: input.authorId,
      mediaId: input.mediaId ?? null,
      body: cleanBody,
      bgColor: input.bgColor || "#FADADD",
      fontFamily: input.fontFamily || "sans",
      fontSize: input.fontSize || "md",
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function reactToHomeCard(input: {
  cardId: number;
  userId: number;
  emoji?: string | null;
  presetText?: string | null;
}) {
  const emoji = input.emoji?.trim() || null;
  const presetText = input.presetText?.trim() || null;
  if (!emoji && !presetText) return;

  // Check if this user already reacted to this card; update or insert
  const existing = db
    .select()
    .from(homeCardReactions)
    .where(eq(homeCardReactions.cardId, input.cardId))
    .all()
    .find((r) => r.userId === input.userId);

  if (existing) {
    db.update(homeCardReactions)
      .set({
        emoji: emoji ?? existing.emoji,
        presetText: presetText ?? existing.presetText,
        createdAt: new Date(),
      })
      .where(eq(homeCardReactions.id, existing.id))
      .run();
  } else {
    db.insert(homeCardReactions)
      .values({
        cardId: input.cardId,
        userId: input.userId,
        emoji,
        presetText,
        createdAt: new Date(),
      })
      .run();
  }
}
