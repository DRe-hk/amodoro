import { createHash, randomBytes } from "node:crypto";
import { hash, verify } from "@node-rs/argon2";
import { and, desc, eq, gt, isNull, sql } from "drizzle-orm";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { db } from "@/db";
import {
  boardItems,
  boards,
  homeCardReactions,
  homeCards,
  inviteTokens,
  sessions,
  users,
  type AccentPalette,
  type AvatarId,
  type ThemeMode,
} from "@/db/schema";

const SESSION_COOKIE = "amodoro_session";
const SESSION_DAYS = 365;

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

function normalizeShortCode(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function generateReadableShortCode(): string {
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  const bytes = randomBytes(8);
  let chars = "";
  for (let i = 0; i < 8; i++) {
    chars += alphabet[bytes[i]! % alphabet.length];
  }
  return `${chars.slice(0, 4)}-${chars.slice(4, 8)}`;
}

let seededChecked = false;

export function ensureInitialSeed() {
  if (seededChecked) return;
  const existingUsers = db.select().from(users).all();
  const now = new Date();
  const yesterday = new Date(now.getTime() - 86_400_000);
  const twoDaysAgo = new Date(now.getTime() - 2 * 86_400_000);

  if (existingUsers.length === 0) {
    const defaultHash =
      "$argon2id$v=19$m=19456,t=2,p=1$amodoroSalt123456$5T6K4R8vN3mP9qL2wX7zB1cV4nM8kH5jG2fD9sA3eW0";

    const userA = db
      .insert(users)
      .values({
        username: "drehk",
        passwordHash: defaultHash,
        displayName: "Drehk",
        avatarId: "cat",
        nicknameByPartner: "Rey",
        themeMode: "light",
        accentPalette: "fig-sage",
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    const userB = db
      .insert(users)
      .values({
        username: "pareja",
        passwordHash: defaultHash,
        displayName: "Alina",
        avatarId: "rabbit",
        partnerId: userA.id,
        nicknameByPartner: "Cielo",
        themeMode: "light",
        accentPalette: "fig-sage",
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    db.update(users)
      .set({ partnerId: userB.id })
      .where(eq(users.id, userA.id))
      .run();

    // Seed the predefined system boards matching the sketch:
    // PENDIENTES (slug: actividades), MÚSICA, PELIS, SERIES, JUEGOS
    const actBoard = db
      .insert(boards)
      .values({
        slug: "actividades",
        title: "PENDIENTES",
        icon: "schedule",
        bgColor: "#F4EFE8",
        isSystem: true,
        createdBy: userA.id,
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    const musicBoard = db
      .insert(boards)
      .values({
        slug: "musica",
        title: "MÚSICA",
        icon: "album",
        bgColor: "#E8DEF8",
        isSystem: true,
        createdBy: userA.id,
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    const moviesBoard = db
      .insert(boards)
      .values({
        slug: "pelis",
        title: "PELIS",
        icon: "movie",
        bgColor: "#FFDAD6",
        isSystem: true,
        createdBy: userA.id,
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    const seriesBoard = db
      .insert(boards)
      .values({
        slug: "series",
        title: "SERIES",
        icon: "tv",
        bgColor: "#D3E4FF",
        isSystem: true,
        createdBy: userA.id,
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    const gamesBoard = db
      .insert(boards)
      .values({
        slug: "juegos",
        title: "JUEGOS",
        icon: "sports_esports",
        bgColor: "#C8E6C9",
        isSystem: true,
        createdBy: userA.id,
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    // Seed initial items matching the sketch ("VER SNOOPY", "JUGAR MINECRAFT", "JUGAR POKEMON", "VER WANDAVISION")
    db.insert(boardItems)
      .values([
        {
          boardId: actBoard.id,
          categoryTag: "PELÍCULAS",
          title: "VER SNOOPY",
          notes: "Con mantita y palomitas esta noche",
          bgColor: "#FFDAD6",
          addedBy: userB.id,
          createdAt: twoDaysAgo,
        },
        {
          boardId: actBoard.id,
          categoryTag: "JUEGO",
          title: "JUGAR MINECRAFT",
          notes: "Terminar nuestra cabaña junto al lago",
          bgColor: "#C8E6C9",
          addedBy: userA.id,
          createdAt: twoDaysAgo,
        },
        {
          boardId: actBoard.id,
          categoryTag: "JUEGO",
          title: "JUGAR POKÉMON",
          notes: "Combate amistoso o ruta cooperativa",
          bgColor: "#F5E0B5",
          addedBy: userA.id,
          createdAt: yesterday,
        },
        {
          boardId: actBoard.id,
          categoryTag: "SERIE",
          title: "VER WANDAVISION",
          notes: "Dos episodios seguidos juntos",
          bgColor: "#E8DEF8",
          addedBy: userB.id,
          createdAt: yesterday,
        },
        {
          boardId: musicBoard.id,
          categoryTag: "MÚSICA",
          title: "Lover, You Should've Come Over",
          notes: "Escúchala antes de dormir",
          url: "https://open.spotify.com/track/6Jv7kjGkhY2fT4yuBF3aTz",
          linkTitle: "Lover, You Should've Come Over — Jeff Buckley",
          linkPlatform: "Spotify",
          bgColor: "#E8DEF8",
          addedBy: userB.id,
          createdAt: yesterday,
        },
        {
          boardId: moviesBoard.id,
          categoryTag: "PELÍCULAS",
          title: "Before Sunrise",
          notes: "Clásico pendiente para el finde",
          bgColor: "#FFDAD6",
          addedBy: userB.id,
          createdAt: yesterday,
        },
        {
          boardId: seriesBoard.id,
          categoryTag: "SERIE",
          title: "The Bear",
          notes: "Empezar primera temporada",
          bgColor: "#D3E4FF",
          addedBy: userA.id,
          createdAt: now,
        },
        {
          boardId: gamesBoard.id,
          categoryTag: "JUEGO",
          title: "It Takes Two",
          notes: "Cooperativo en pareja",
          bgColor: "#C8E6C9",
          addedBy: userA.id,
          createdAt: now,
        },
      ])
      .run();

    // Seed sample Home daily cards
    const cardYesterday = db
      .insert(homeCards)
      .values({
        authorId: userB.id,
        mediaType: "none",
        body: "Estuve pensando en nuestra próxima cita y en las ganas que tengo de abrazarte fuerte. Que tengas un domingo precioso",
        bgColor: "#C8E6C9",
        fontFamily: "serif",
        fontSize: "md",
        fontSizePx: 18,
        createdAt: yesterday,
      })
      .returning()
      .get();

    db.insert(homeCardReactions)
      .values({
        cardId: cardYesterday.id,
        userId: userA.id,
        emoji: "❤️",
        presetText: "Me alegraste el día",
        createdAt: yesterday,
      })
      .run();

    db.insert(homeCards)
      .values({
        authorId: userB.id,
        mediaType: "none",
        body: "Buenos días mi vida. Hoy va a ser un gran día, acuérdate de tomar un respiro y que aquí te espero esta noche para decidir qué hacemos juntos",
        bgColor: "#FFDAD6",
        fontFamily: "sans",
        fontSize: "lg",
        fontSizePx: 22,
        createdAt: now,
      })
      .run();

    const sentByA = db
      .insert(homeCards)
      .values({
        authorId: userA.id,
        mediaType: "none",
        body: "Te dejé anotadas un par de ideas nuevas en el tablero de pendientes para esta noche",
        bgColor: "#F5E0B5",
        fontFamily: "hand",
        fontSize: "lg",
        fontSizePx: 22,
        createdAt: yesterday,
      })
      .returning()
      .get();

    db.insert(homeCardReactions)
      .values({
        cardId: sentByA.id,
        userId: userB.id,
        emoji: "🥰",
        presetText: "Te amo",
        createdAt: yesterday,
      })
      .run();
  } else {
    // Ensure existing DB has the 5 predefined boards and paired seed users
    const user1 = existingUsers.find((u) => u.id === 1);
    const user2 = existingUsers.find((u) => u.id === 2);
    if (user1 && user2 && (!user1.partnerId || !user2.partnerId)) {
      db.update(users)
        .set({
          partnerId: user2.id,
          displayName: user1.displayName || "Drehk",
          avatarId: user1.avatarId || "cat",
        })
        .where(eq(users.id, user1.id))
        .run();
      db.update(users)
        .set({
          partnerId: user1.id,
          displayName: user2.displayName || "Alina",
          avatarId: user2.avatarId || "rabbit",
        })
        .where(eq(users.id, user2.id))
        .run();
    }

    const allBoards = db.select().from(boards).all();
    const act = allBoards.find((b) => b.slug === "actividades");
    if (act && act.title !== "PENDIENTES") {
      db.update(boards)
        .set({ title: "PENDIENTES", icon: "schedule" })
        .where(eq(boards.id, act.id))
        .run();
    }
    const ensureBoard = (
      slug: string,
      title: string,
      icon: string,
      bgColor: string,
    ) => {
      if (!allBoards.some((b) => b.slug === slug)) {
        db.insert(boards)
          .values({
            slug,
            title,
            icon,
            bgColor,
            isSystem: true,
            createdBy: existingUsers[0]?.id ?? null,
            createdAt: now,
          })
          .run();
      }
    };
    ensureBoard("musica", "MÚSICA", "album", "#E8DEF8");
    ensureBoard("pelis", "PELIS", "movie", "#FFDAD6");
    ensureBoard("series", "SERIES", "tv", "#D3E4FF");
    ensureBoard("juegos", "JUEGOS", "sports_esports", "#C8E6C9");
  }

  seededChecked = true;
}

export async function hashPassword(password: string) {
  return hash(password);
}

export async function verifyPassword(hashStr: string, password: string) {
  try {
    return await verify(hashStr, password);
  } catch {
    return false;
  }
}

function cookieIsSecure() {
  if (process.env.COOKIE_SECURE === "false") return false;
  return process.env.NODE_ENV === "production";
}

export async function createSessionForUser(
  userId: number,
  userAgent: string | null = null,
) {
  const now = new Date();
  const expires = new Date(now.getTime() + SESSION_DAYS * 86_400_000);

  const existing = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userId))
    .orderBy(desc(sessions.lastSeenAt))
    .all();

  if (existing.length >= 5) {
    for (const old of existing.slice(4)) {
      db.delete(sessions).where(eq(sessions.id, old.id)).run();
    }
  }

  const id = randomBytes(32).toString("base64url");
  db.insert(sessions)
    .values({
      id,
      userId,
      createdAt: now,
      expiresAt: expires,
      lastSeenAt: now,
      userAgent,
    })
    .run();

  try {
    const store = await cookies();
    store.set(SESSION_COOKIE, id, {
      httpOnly: true,
      sameSite: "lax",
      secure: cookieIsSecure(),
      path: "/",
      expires,
    });
  } catch {
    // Ignore when called outside Next.js cookie context
  }

  return { id, expires };
}

export async function clearCurrentSession() {
  const store = await cookies();
  const id = store.get(SESSION_COOKIE)?.value;
  if (id) {
    db.delete(sessions).where(eq(sessions.id, id)).run();
  }
  store.delete(SESSION_COOKIE);
}

export const currentUser = cache(async () => {
  ensureInitialSeed();
  const store = await cookies();
  const id = store.get(SESSION_COOKIE)?.value;
  if (!id) return null;

  const row = db
    .select({ user: users, session: sessions })
    .from(sessions)
    .innerJoin(users, eq(sessions.userId, users.id))
    .where(
      and(eq(sessions.id, id), gt(sessions.expiresAt, sql`unixepoch('now')`)),
    )
    .get();

  if (!row) {
    return null;
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const newExpiresSec = nowSec + SESSION_DAYS * 86_400;
  db.update(sessions)
    .set({
      lastSeenAt: new Date(nowSec * 1000),
      expiresAt: new Date(newExpiresSec * 1000),
    })
    .where(eq(sessions.id, id))
    .run();

  return row.user;
});

export async function requirePageUser() {
  const user = await currentUser();
  if (!user) {
    redirect("/entrar");
  }
  return user;
}

export function getAllUsers() {
  ensureInitialSeed();
  return db.select().from(users).orderBy(users.id).all();
}

export function getPartnerUser(myUserId: number) {
  ensureInitialSeed();
  const all = getAllUsers();
  const me = all.find((u) => u.id === myUserId);
  if (me?.partnerId) {
    const linked = all.find((u) => u.id === me.partnerId);
    if (linked) return linked;
  }
  // Fallback for initial 2-user seed
  if (myUserId === 1 || myUserId === 2) {
    return all.find((u) => u.id !== myUserId && (u.id === 1 || u.id === 2)) ?? null;
  }
  return null;
}

export async function registerNewUser(input: {
  username?: string;
  displayName: string;
  password?: string;
  avatarId?: AvatarId;
}) {
  ensureInitialSeed();
  const cleanName = input.displayName.trim();
  if (!cleanName) {
    throw new Error("Elige un nombre para continuar.");
  }

  const rawUsername = (input.username?.trim() || cleanName)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9_]/g, "");

  const baseUsername = rawUsername || `user_${Date.now().toString(36)}`;
  let finalUsername = baseUsername;
  const existing = getAllUsers();
  if (existing.some((u) => u.username.toLowerCase() === finalUsername)) {
    finalUsername = `${baseUsername}_${Math.floor(100 + Math.random() * 900)}`;
  }

  const pwd = input.password?.trim() || "amodoro2025";
  const passwordHash = await hashPassword(pwd);

  const created = db
    .insert(users)
    .values({
      username: finalUsername,
      passwordHash,
      displayName: cleanName,
      avatarId: input.avatarId || "cat",
      partnerId: null,
      nicknameByPartner: "",
      themeMode: "light",
      accentPalette: "fig-sage",
      createdAt: new Date(),
    })
    .returning()
    .get();

  return created;
}

export function createInviteForUser(userId: number) {
  const now = new Date();
  const expires = new Date(now.getTime() + 7 * 86_400_000);
  const rawToken = randomBytes(24).toString("base64url");
  const codeDisplay = generateReadableShortCode();
  const codeNormalized = normalizeShortCode(codeDisplay);

  db.insert(inviteTokens)
    .values({
      userId,
      tokenHash: sha256(rawToken),
      codeHash: sha256(codeNormalized),
      codeDisplay,
      expiresAt: expires,
      createdAt: now,
    })
    .run();

  return {
    token: rawToken,
    code: codeDisplay,
    expiresAt: expires,
  };
}

export function redeemInviteByTokenOrCode(input: {
  token?: string;
  code?: string;
  redeemingUserId?: number;
}): number | null {
  ensureInitialSeed();
  const now = new Date();
  let inviterUserId: number | null = null;
  let tokenId: number | null = null;

  if (input.token) {
    const hashVal = sha256(input.token.trim());
    const row = db
      .select()
      .from(inviteTokens)
      .where(
        and(
          eq(inviteTokens.tokenHash, hashVal),
          isNull(inviteTokens.usedAt),
          gt(inviteTokens.expiresAt, now),
        ),
      )
      .get();
    if (row) {
      inviterUserId = row.userId;
      tokenId = row.id;
    }
  } else if (input.code) {
    const clean = normalizeShortCode(input.code);
    if (clean) {
      const hashVal = sha256(clean);
      const row = db
        .select()
        .from(inviteTokens)
        .where(
          and(
            eq(inviteTokens.codeHash, hashVal),
            isNull(inviteTokens.usedAt),
            gt(inviteTokens.expiresAt, now),
          ),
        )
        .get();
      if (row) {
        inviterUserId = row.userId;
        tokenId = row.id;
      }
    }
  }

  if (!inviterUserId || !tokenId) return null;

  db.update(inviteTokens)
    .set({ usedAt: now })
    .where(eq(inviteTokens.id, tokenId))
    .run();

  // If a logged-in/newly-registered user is redeeming their partner's code, pair both accounts!
  if (input.redeemingUserId && input.redeemingUserId !== inviterUserId) {
    db.update(users)
      .set({ partnerId: inviterUserId })
      .where(eq(users.id, input.redeemingUserId))
      .run();
    db.update(users)
      .set({ partnerId: input.redeemingUserId })
      .where(eq(users.id, inviterUserId))
      .run();
    return input.redeemingUserId;
  }

  const inviterPartner = getPartnerUser(inviterUserId);
  return inviterPartner?.id ?? inviterUserId;
}

export function updateUserSettings(input: {
  userId: number;
  displayName?: string;
  avatarId?: AvatarId;
  partnerNickname?: string;
  themeMode?: ThemeMode;
  accentPalette?: AccentPalette;
  quickReplies?: string[];
}) {
  const partner = getPartnerUser(input.userId);
  if (partner && typeof input.partnerNickname === "string") {
    const cleanNick = input.partnerNickname.trim();
    if (cleanNick.length <= 40) {
      db.update(users)
        .set({ nicknameByPartner: cleanNick })
        .where(eq(users.id, partner.id))
        .run();
    }
  }

  const updates: Partial<typeof users.$inferInsert> = {};
  if (typeof input.displayName === "string") {
    const cleanName = input.displayName.trim();
    if (cleanName.length > 0 && cleanName.length <= 40) {
      updates.displayName = cleanName;
    }
  }
  if (input.avatarId) {
    updates.avatarId = input.avatarId;
  }
  if (input.themeMode) updates.themeMode = input.themeMode;
  if (input.accentPalette) updates.accentPalette = input.accentPalette;
  if (input.quickReplies) {
    const filtered = input.quickReplies
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && s.length <= 80)
      .slice(0, 20);
    updates.quickRepliesJson = JSON.stringify(filtered);
  }

  if (Object.keys(updates).length > 0) {
    db.update(users).set(updates).where(eq(users.id, input.userId)).run();
  }
}
