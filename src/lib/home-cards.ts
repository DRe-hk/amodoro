import { randomUUID } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { asc, desc, eq, inArray } from "drizzle-orm";
import { db } from "@/db";
import {
  homeCardReactions,
  homeCardReplies,
  homeCards,
  media,
  users,
  type CardFont,
  type CardFontSize,
} from "@/db/schema";
import { getAllUsers, getPartnerUser } from "./auth";
import {
  MAX_IMAGE_BYTES,
  UPLOADS_PATH,
  checkMediaQuota,
  detectImageMimeFromMagicBytes,
} from "./media";

export type AuthUser = {
  id: number;
  username?: string;
  displayName?: string;
  avatarId?: string;
  partnerId?: number | null;
  nicknameByPartner?: string;
};

export type ReactionItem = {
  id: number;
  cardId: number;
  userId: number;
  emoji: string | null;
  presetText: string | null;
  createdAt: Date;
};

export interface HomeCardReplyDto {
  id: string;
  cardId: string;
  userId: number;
  authorLabel: string;
  authorAvatarId: string;
  isMine: boolean;
  textContent: string;
  mediaType: "none" | "image" | "drawing";
  mediaUrl: string | null;
  createdAt: string;
}

export type HydratedHomeCard = {
  id: number;
  authorId: number;
  authorUsername: string;
  authorDisplayName: string;
  authorAvatarId: string;
  authorNicknameByPartner: string;
  mediaId: number | null;
  mediaType: string;
  altText: string | null;
  linkUrl: string | null;
  linkTitle: string | null;
  linkThumbnail: string | null;
  linkPlatform: string | null;
  body: string;
  bgColor: string;
  fontFamily: CardFont;
  fontSize: CardFontSize;
  fontSizePx: number;
  createdAt: Date;
  reactions: ReactionItem[];
  replies: HomeCardReplyDto[];
};

export type HomeCardDto = HydratedHomeCard;

export function getCoupleUserIds(userId: number): number[] {
  const partner = getPartnerUser(userId);
  return partner ? [userId, partner.id] : [userId];
}

export function resolveAuthorLabel(
  authorUserId: number,
  viewer: { id: number } | number,
  partnerOrAuthor?: {
    nicknameByPartner?: string | null;
    displayName?: string | null;
    username?: string | null;
  } | null,
): string {
  const viewerId = typeof viewer === "number" ? viewer : viewer.id;
  if (authorUserId === viewerId) {
    return "Yo";
  }
  const author =
    partnerOrAuthor ??
    db.select().from(users).where(eq(users.id, authorUserId)).get();
  return (
    author?.nicknameByPartner?.trim() ||
    author?.displayName?.trim() ||
    author?.username?.trim() ||
    "Pareja"
  );
}

export function saveBase64Media(input: {
  dataUrl: string;
  kind?: "image" | "drawing";
  altText?: string | null;
  ownerId: number;
}): number {
  const raw = input.dataUrl.trim();
  const cleaned = raw.replace(/^data:[^;]+;base64,/, "").trim();
  const bytes = Buffer.from(cleaned, "base64");
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new Error("Tamaño de imagen no válido.");
  }

  let detected = detectImageMimeFromMagicBytes(bytes);
  if (!detected) {
    const headerMatch = /^data:image\/(png|jpeg|jpg|webp|gif);base64,/i.exec(raw);
    const headAscii = bytes.toString("utf8", 0, Math.min(bytes.byteLength, 32));
    if (headerMatch && !headAscii.includes("<")) {
      const sub = headerMatch[1]!.toLowerCase();
      detected =
        sub === "png"
          ? { mime: "image/png", ext: "png" }
          : sub === "webp"
            ? { mime: "image/webp", ext: "webp" }
            : sub === "gif"
              ? { mime: "image/gif", ext: "gif" }
              : { mime: "image/jpeg", ext: "jpg" };
    } else {
      throw new Error("Formato de imagen no permitido.");
    }
  }

  checkMediaQuota(bytes.byteLength);

  const id = randomUUID();
  const relPath = `${id.slice(0, 2)}/${id}.${detected.ext}`;
  const targetDir = join(
    /*turbopackIgnore: true*/ UPLOADS_PATH,
    id.slice(0, 2),
  );
  const fullPath = join(
    /*turbopackIgnore: true*/ targetDir,
    `${id}.${detected.ext}`,
  );

  mkdirSync(targetDir, { recursive: true });
  writeFileSync(fullPath, bytes);

  const row = db
    .insert(media)
    .values({
      ownerId: input.ownerId,
      kind: input.kind ?? "image",
      path: relPath,
      mime: detected.mime,
      bytes: bytes.byteLength,
      altText: input.altText?.trim() || null,
      createdAt: new Date(),
    })
    .returning({ id: media.id })
    .get();

  return row.id;
}

function attachReactionsAndReplies(
  rows: Omit<HydratedHomeCard, "reactions" | "replies">[],
  viewerId: number,
): HydratedHomeCard[] {
  if (rows.length === 0) return [];
  const cardIds = rows.map((r) => r.id);
  const allUsers = getAllUsers();
  const userById = new Map(allUsers.map((u) => [u.id, u]));
  const viewer = userById.get(viewerId) ?? { id: viewerId };
  const partner = getPartnerUser(viewerId);

  const allReactions = db
    .select()
    .from(homeCardReactions)
    .where(inArray(homeCardReactions.cardId, cardIds))
    .orderBy(asc(homeCardReactions.id))
    .all();

  const allReplies = db
    .select()
    .from(homeCardReplies)
    .where(inArray(homeCardReplies.cardId, cardIds))
    .orderBy(asc(homeCardReplies.id))
    .all();

  const reactionsByCard = new Map<number, ReactionItem[]>();
  const repliesByCard = new Map<number, HomeCardReplyDto[]>();

  for (const rx of allReactions) {
    const cleanPreset = rx.presetText?.trim() || "";
    if (cleanPreset.length > 0) {
      const rxAuthor = userById.get(rx.userId) ?? partner;
      const replyList = repliesByCard.get(rx.cardId) ?? [];
      replyList.push({
        id: `legacy-${rx.id}`,
        cardId: String(rx.cardId),
        userId: rx.userId,
        authorLabel:
          rx.userId === viewerId
            ? "Yo"
            : resolveAuthorLabel(rx.userId, viewer, rxAuthor),
        authorAvatarId: rxAuthor?.avatarId || "cat",
        isMine: rx.userId === viewerId,
        textContent: cleanPreset,
        mediaType: "none",
        mediaUrl: null,
        createdAt: rx.createdAt.toISOString(),
      });
      repliesByCard.set(rx.cardId, replyList);
    }

    const cleanEmoji = rx.emoji?.trim() || "";
    if (cleanEmoji.length > 0) {
      const rxList = reactionsByCard.get(rx.cardId) ?? [];
      rxList.push({
        ...rx,
        emoji: cleanEmoji,
      });
      reactionsByCard.set(rx.cardId, rxList);
    }
  }

  for (const rep of allReplies) {
    const repAuthor = userById.get(rep.userId) ?? partner;
    const replyList = repliesByCard.get(rep.cardId) ?? [];
    const normalizedMediaType: "none" | "image" | "drawing" =
      rep.mediaType === "drawing"
        ? "drawing"
        : rep.mediaType === "image" ||
            rep.mediaType === "photo" ||
            rep.mediaId != null
          ? "image"
          : "none";

    replyList.push({
      id: String(rep.id),
      cardId: String(rep.cardId),
      userId: rep.userId,
      authorLabel:
        rep.userId === viewerId
          ? "Yo"
          : resolveAuthorLabel(rep.userId, viewer, repAuthor),
      authorAvatarId: repAuthor?.avatarId || "cat",
      isMine: rep.userId === viewerId,
      textContent: rep.textContent,
      mediaType: normalizedMediaType,
      mediaUrl: rep.mediaId ? `/api/media/${rep.mediaId}` : null,
      createdAt: rep.createdAt,
    });
    repliesByCard.set(rep.cardId, replyList);
  }

  return rows.map((r) => ({
    ...r,
    reactions: reactionsByCard.get(r.id) ?? [],
    replies: repliesByCard.get(r.id) ?? [],
  }));
}

export function getReceivedHomeCards(
  viewerId: number,
  options?: { limit?: number; offset?: number },
): {
  latest: HydratedHomeCard | null;
  history: HydratedHomeCard[];
} {
  const partner = getPartnerUser(viewerId);
  if (!partner) {
    return { latest: null, history: [] };
  }

  const limit = Math.min(Math.max(options?.limit ?? 100, 1), 200);
  const offset = Math.max(options?.offset ?? 0, 0);

  const rows = db
    .select({
      id: homeCards.id,
      authorId: homeCards.authorId,
      authorUsername: users.username,
      authorDisplayName: users.displayName,
      authorAvatarId: users.avatarId,
      authorNicknameByPartner: users.nicknameByPartner,
      mediaId: homeCards.mediaId,
      mediaType: homeCards.mediaType,
      altText: homeCards.altText,
      linkUrl: homeCards.linkUrl,
      linkTitle: homeCards.linkTitle,
      linkThumbnail: homeCards.linkThumbnail,
      linkPlatform: homeCards.linkPlatform,
      body: homeCards.body,
      bgColor: homeCards.bgColor,
      fontFamily: homeCards.fontFamily,
      fontSize: homeCards.fontSize,
      fontSizePx: homeCards.fontSizePx,
      createdAt: homeCards.createdAt,
    })
    .from(homeCards)
    .innerJoin(users, eq(homeCards.authorId, users.id))
    .where(eq(homeCards.authorId, partner.id))
    .orderBy(desc(homeCards.createdAt), desc(homeCards.id))
    .limit(limit)
    .offset(offset)
    .all();

  const hydrated = attachReactionsAndReplies(rows, viewerId);
  return {
    latest: hydrated[0] ?? null,
    history: hydrated.slice(1),
  };
}

export function getSentHomeCards(
  viewerId: number,
  options?: { limit?: number; offset?: number },
): HydratedHomeCard[] {
  const limit = Math.min(Math.max(options?.limit ?? 100, 1), 200);
  const offset = Math.max(options?.offset ?? 0, 0);

  const rows = db
    .select({
      id: homeCards.id,
      authorId: homeCards.authorId,
      authorUsername: users.username,
      authorDisplayName: users.displayName,
      authorAvatarId: users.avatarId,
      authorNicknameByPartner: users.nicknameByPartner,
      mediaId: homeCards.mediaId,
      mediaType: homeCards.mediaType,
      altText: homeCards.altText,
      linkUrl: homeCards.linkUrl,
      linkTitle: homeCards.linkTitle,
      linkThumbnail: homeCards.linkThumbnail,
      linkPlatform: homeCards.linkPlatform,
      body: homeCards.body,
      bgColor: homeCards.bgColor,
      fontFamily: homeCards.fontFamily,
      fontSize: homeCards.fontSize,
      fontSizePx: homeCards.fontSizePx,
      createdAt: homeCards.createdAt,
    })
    .from(homeCards)
    .innerJoin(users, eq(homeCards.authorId, users.id))
    .where(eq(homeCards.authorId, viewerId))
    .orderBy(desc(homeCards.createdAt), desc(homeCards.id))
    .limit(limit)
    .offset(offset)
    .all();

  return attachReactionsAndReplies(rows, viewerId);
}

export function createHomeCard(input: {
  authorId: number;
  mediaId?: number | null;
  mediaType?: string;
  altText?: string | null;
  linkUrl?: string | null;
  linkTitle?: string | null;
  linkThumbnail?: string | null;
  linkPlatform?: string | null;
  body: string;
  bgColor: string;
  fontFamily: CardFont;
  fontSize: CardFontSize;
  fontSizePx?: number;
}) {
  const cleanBody = input.body.trim();
  const cleanLink = input.linkUrl?.trim() || null;

  if (!cleanBody && !input.mediaId && !cleanLink) {
    throw new Error("Escribe un mensaje o añade una imagen, dibujo o link.");
  }

  let resolvedMediaType = input.mediaType || "none";
  if (input.mediaId && resolvedMediaType === "none") {
    resolvedMediaType = "photo";
  } else if (cleanLink) {
    resolvedMediaType = "link";
  } else if (!input.mediaId && !cleanLink) {
    resolvedMediaType = "none";
  }

  const sizePx =
    input.fontSizePx ??
    (input.fontSize === "sm"
      ? 14
      : input.fontSize === "lg"
        ? 22
        : input.fontSize === "xl"
          ? 28
          : 18);

  return db
    .insert(homeCards)
    .values({
      authorId: input.authorId,
      mediaId: input.mediaId ?? null,
      mediaType: resolvedMediaType,
      altText: input.altText?.trim() || null,
      linkUrl: cleanLink,
      linkTitle: input.linkTitle?.trim() || null,
      linkThumbnail: input.linkThumbnail?.trim() || null,
      linkPlatform: input.linkPlatform?.trim() || null,
      body: cleanBody,
      bgColor: input.bgColor || "#FFDAD6",
      fontFamily: input.fontFamily || "sans",
      fontSize: input.fontSize || "md",
      fontSizePx: sizePx,
      createdAt: new Date(),
    })
    .returning()
    .get();
}

export function updateHomeCard(input: {
  cardId: number;
  authorId: number;
  newMediaId?: number | null;
  keepExistingMedia?: boolean;
  mediaType?: string;
  altText?: string | null;
  linkUrl?: string | null;
  linkTitle?: string | null;
  linkThumbnail?: string | null;
  linkPlatform?: string | null;
  body: string;
  bgColor: string;
  fontFamily: CardFont;
  fontSize: CardFontSize;
  fontSizePx?: number;
}) {
  const existing = db
    .select()
    .from(homeCards)
    .where(eq(homeCards.id, input.cardId))
    .get();

  if (!existing) {
    throw new Error("Tarjeta no encontrada.");
  }
  if (existing.authorId !== input.authorId) {
    throw new Error("Solo puedes editar las tarjetas que tú enviaste.");
  }

  const cleanBody = input.body.trim();
  const cleanLink = input.linkUrl?.trim() || null;

  let finalMediaId: number | null = null;
  let finalMediaType = "none";
  let finalLinkUrl: string | null = null;
  let finalLinkTitle: string | null = null;
  let finalLinkThumbnail: string | null = null;
  let finalLinkPlatform: string | null = null;

  if (input.newMediaId != null) {
    finalMediaId = input.newMediaId;
    finalMediaType = input.mediaType === "drawing" ? "drawing" : "photo";
  } else if (input.mediaType === "link" && cleanLink) {
    finalMediaType = "link";
    finalLinkUrl = cleanLink;
    finalLinkTitle = input.linkTitle?.trim() || null;
    finalLinkThumbnail = input.linkThumbnail?.trim() || null;
    finalLinkPlatform = input.linkPlatform?.trim() || null;
  } else if (input.keepExistingMedia && existing.mediaId != null) {
    finalMediaId = existing.mediaId;
    finalMediaType =
      existing.mediaType && existing.mediaType !== "none"
        ? existing.mediaType
        : "photo";
  } else {
    finalMediaId = null;
    finalMediaType = "none";
  }

  if (!cleanBody && !finalMediaId && !finalLinkUrl) {
    throw new Error("Escribe un mensaje o añade una imagen, dibujo o link.");
  }

  const sizePx =
    input.fontSizePx ??
    (input.fontSize === "sm"
      ? 14
      : input.fontSize === "lg"
        ? 22
        : input.fontSize === "xl"
          ? 28
          : 18);

  return db
    .update(homeCards)
    .set({
      mediaId: finalMediaId,
      mediaType: finalMediaType,
      altText:
        input.altText !== undefined
          ? input.altText?.trim() || null
          : existing.altText,
      linkUrl: finalLinkUrl,
      linkTitle: finalLinkTitle,
      linkThumbnail: finalLinkThumbnail,
      linkPlatform: finalLinkPlatform,
      body: cleanBody,
      bgColor: input.bgColor || existing.bgColor || "#FFDAD6",
      fontFamily: input.fontFamily || existing.fontFamily || "sans",
      fontSize: input.fontSize || existing.fontSize || "md",
      fontSizePx: sizePx,
    })
    .where(eq(homeCards.id, input.cardId))
    .returning()
    .get();
}

export function deleteHomeCard(input: { cardId: number; authorId: number }) {
  const existing = db
    .select()
    .from(homeCards)
    .where(eq(homeCards.id, input.cardId))
    .get();

  if (!existing) {
    throw new Error("Tarjeta no encontrada.");
  }
  if (existing.authorId !== input.authorId) {
    throw new Error("Solo puedes eliminar las tarjetas que tú enviaste.");
  }

  db.delete(homeCardReplies)
    .where(eq(homeCardReplies.cardId, input.cardId))
    .run();

  db.delete(homeCardReactions)
    .where(eq(homeCardReactions.cardId, input.cardId))
    .run();

  db.delete(homeCards).where(eq(homeCards.id, input.cardId)).run();
}

export function replyToHomeCard(
  user: AuthUser | number,
  input: {
    cardId?: string | number;
    textContent?: string | null;
    body?: string | null;
    presetText?: string | null;
    mediaType?: string | null;
    mediaKind?: string | null;
    mediaDataUrl?: string | null;
    imageBase64?: string | null;
    mediaId?: number | null;
  },
): HomeCardReplyDto {
  const userObj: AuthUser =
    typeof user === "number" ? { id: user } : user;

  const numericCardId = Number(input.cardId);
  if (!Number.isInteger(numericCardId) || numericCardId <= 0) {
    throw new Error("Tarjeta no encontrada.");
  }

  const card = db
    .select()
    .from(homeCards)
    .where(eq(homeCards.id, numericCardId))
    .get();
  if (!card) {
    throw new Error("Tarjeta no encontrada.");
  }

  const coupleIds = getCoupleUserIds(userObj.id);
  if (!coupleIds.includes(card.authorId)) {
    throw new Error("No tienes permiso para responder a esta tarjeta.");
  }

  const rawDataUrl = (input.mediaDataUrl ?? input.imageBase64 ?? "").trim();
  const requestedKind: "image" | "drawing" =
    input.mediaType === "drawing" || input.mediaKind === "drawing"
      ? "drawing"
      : "image";

  let mediaId: number | null = input.mediaId ?? null;
  if (mediaId == null && rawDataUrl) {
    mediaId = saveBase64Media({
      dataUrl: rawDataUrl,
      kind: requestedKind,
      ownerId: userObj.id,
    });
  }

  const cleanText = (
    input.textContent ??
    input.body ??
    input.presetText ??
    ""
  ).trim();

  if (cleanText.length === 0 && mediaId == null) {
    throw new Error("Escribe una respuesta o adjunta una imagen o dibujo.");
  }

  const resolvedMediaType: "none" | "image" | "drawing" =
    mediaId != null ? requestedKind : "none";

  const nowIso = new Date().toISOString();
  const inserted = db
    .insert(homeCardReplies)
    .values({
      cardId: numericCardId,
      userId: userObj.id,
      textContent: cleanText,
      mediaType: resolvedMediaType,
      mediaId,
      createdAt: nowIso,
    })
    .returning()
    .get();

  const dbUser = db
    .select()
    .from(users)
    .where(eq(users.id, userObj.id))
    .get();

  return {
    id: String(inserted.id),
    cardId: String(inserted.cardId),
    userId: inserted.userId,
    authorLabel: "Yo",
    authorAvatarId: dbUser?.avatarId || userObj.avatarId || "cat",
    isMine: true,
    textContent: inserted.textContent,
    mediaType: resolvedMediaType,
    mediaUrl: inserted.mediaId ? `/api/media/${inserted.mediaId}` : null,
    createdAt: inserted.createdAt,
  };
}

export function reactToHomeCard(
  arg1:
    | {
        cardId: number | string;
        userId: number;
        emoji?: string | null;
        presetText?: string | null;
      }
    | AuthUser
    | number,
  arg2?: {
    cardId: number | string;
    emoji?: string | null;
    presetText?: string | null;
  },
): { removed: boolean; reply?: HomeCardReplyDto } {
  const userId =
    arg2 !== undefined
      ? typeof arg1 === "number"
        ? arg1
        : (arg1 as AuthUser).id
      : (arg1 as { userId: number }).userId;
  const rawCardId =
    arg2 !== undefined
      ? arg2.cardId
      : (arg1 as { cardId: number | string }).cardId;
  const cardId = Number(rawCardId);
  const emoji =
    (arg2 !== undefined
      ? arg2.emoji
      : (arg1 as { emoji?: string | null }).emoji
    )?.trim() || null;
  const presetText =
    (arg2 !== undefined
      ? arg2.presetText
      : (arg1 as { presetText?: string | null }).presetText
    )?.trim() || null;

  if (presetText && !emoji) {
    const reply = replyToHomeCard(
      { id: userId },
      { cardId, textContent: presetText },
    );
    return { removed: false, reply };
  }

  const card = db
    .select()
    .from(homeCards)
    .where(eq(homeCards.id, cardId))
    .get();
  if (!card) {
    throw new Error("Tarjeta no encontrada.");
  }

  const coupleIds = getCoupleUserIds(userId);
  if (!coupleIds.includes(card.authorId)) {
    throw new Error("No tienes permiso para reaccionar a esta tarjeta.");
  }

  const existingEmojiReactions = db
    .select()
    .from(homeCardReactions)
    .where(eq(homeCardReactions.cardId, cardId))
    .all()
    .filter((r) => r.userId === userId && Boolean(r.emoji));

  const existing = existingEmojiReactions[0];

  if (!emoji || (existing && existing.emoji === emoji)) {
    for (const row of existingEmojiReactions) {
      db.delete(homeCardReactions)
        .where(eq(homeCardReactions.id, row.id))
        .run();
    }
    return { removed: true };
  }

  if (existing) {
    db.update(homeCardReactions)
      .set({
        emoji,
        createdAt: new Date(),
      })
      .where(eq(homeCardReactions.id, existing.id))
      .run();
    for (const extra of existingEmojiReactions.slice(1)) {
      db.delete(homeCardReactions)
        .where(eq(homeCardReactions.id, extra.id))
        .run();
    }
  } else {
    db.insert(homeCardReactions)
      .values({
        cardId,
        userId,
        emoji,
        presetText: null,
        createdAt: new Date(),
      })
      .run();
  }
  return { removed: false };
}
