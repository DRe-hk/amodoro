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
  if (existingUsers.length === 0) {
    const now = new Date();
    const yesterday = new Date(now.getTime() - 86_400_000);
    const twoDaysAgo = new Date(now.getTime() - 2 * 86_400_000);

    // Pre-computed argon2 hash or deterministic initial password hash
    const defaultHash = "$argon2id$v=19$m=19456,t=2,p=1$amodoroSalt123456$5T6K4R8vN3mP9qL2wX7zB1cV4nM8kH5jG2fD9sA3eW0";

    const userA = db
      .insert(users)
      .values({
        username: "drehk",
        passwordHash: defaultHash,
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
        nicknameByPartner: "Cielo",
        themeMode: "light",
        accentPalette: "fig-sage",
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    // Seed the 3 system boards: Actividades (Pendientes), Música, Pelis
    const actBoard = db
      .insert(boards)
      .values({
        slug: "actividades",
        title: "Actividades",
        icon: "clock",
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
        title: "Música",
        icon: "disc",
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
        title: "Pelis",
        icon: "film",
        isSystem: true,
        createdBy: userA.id,
        createdAt: twoDaysAgo,
      })
      .returning()
      .get();

    // Seed initial items matching the sketch ("VER SNOOPY", "JUGAR MINECRAFT 😊😐", "JUGAR POKEMON", "VER WANDAVISION")
    db.insert(boardItems)
      .values([
        {
          boardId: actBoard.id,
          categoryTag: "PELÍCULAS",
          title: "Ver Snoopy 🐾",
          notes: "Con mantita y palomitas esta noche",
          emoji: "🐶",
          addedBy: userB.id,
          createdAt: twoDaysAgo,
        },
        {
          boardId: actBoard.id,
          categoryTag: "JUEGO",
          title: "Jugar Minecraft 😊 😐",
          notes: "Terminar nuestra cabaña junto al lago",
          emoji: "⛏️",
          addedBy: userA.id,
          createdAt: twoDaysAgo,
        },
        {
          boardId: actBoard.id,
          categoryTag: "JUEGO",
          title: "Jugar Pokémon 🎮",
          notes: "Combate amistoso o ruta cooperativa",
          emoji: "⚡",
          addedBy: userA.id,
          createdAt: yesterday,
        },
        {
          boardId: actBoard.id,
          categoryTag: "SERIE",
          title: "Ver WandaVision 📺",
          notes: "Dos episodios seguidos en llamada",
          emoji: "✨",
          addedBy: userB.id,
          createdAt: yesterday,
        },
        {
          boardId: actBoard.id,
          categoryTag: "ACTIVIDAD",
          title: "Cocinar algo rico por videollamada 🍝",
          notes: "Hacer la misma receta a la vez",
          emoji: "🍷",
          addedBy: userB.id,
          createdAt: now,
        },
        {
          boardId: musicBoard.id,
          categoryTag: "CANCIÓN",
          title: "Lover, You Should've Come Over 🎵",
          notes: "Escúchala antes de dormir",
          url: "https://open.spotify.com",
          emoji: "🎧",
          addedBy: userB.id,
          createdAt: yesterday,
        },
        {
          boardId: musicBoard.id,
          categoryTag: "ÁLBUM",
          title: "In Rainbows — Radiohead 🌈",
          notes: "Para escuchar juntos el domingo",
          emoji: "💿",
          addedBy: userA.id,
          createdAt: now,
        },
        {
          boardId: moviesBoard.id,
          categoryTag: "PELÍCULA",
          title: "Before Sunrise (Antes del amanecer) 🌅",
          notes: "Clásico pendiente para el finde",
          emoji: "🎬",
          addedBy: userB.id,
          createdAt: yesterday,
        },
        {
          boardId: moviesBoard.id,
          categoryTag: "ANIME",
          title: "El viaje de Chihiro 🐉",
          notes: "Maratón Studio Ghibli",
          emoji: "🍵",
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
        body: "Estuve pensando en nuestra próxima cita y en las ganas que tengo de abrazarte fuerte. Que tengas un domingo precioso 🌿✨",
        bgColor: "#D8F3DC",
        fontFamily: "serif",
        fontSize: "md",
        createdAt: yesterday,
      })
      .returning()
      .get();

    db.insert(homeCardReactions)
      .values({
        cardId: cardYesterday.id,
        userId: userA.id,
        emoji: "❤️",
        presetText: "Me alegraste el día ✨",
        createdAt: yesterday,
      })
      .run();

    db.insert(homeCards)
      .values({
        authorId: userB.id,
        body: "Buenos días mi vida ☀️ Hoy va a ser un gran día, acuérdate de tomar un respiro y que aquí te espero esta noche para decidir qué vemos juntos ❤️",
        bgColor: "#FADADD",
        fontFamily: "sans",
        fontSize: "lg",
        createdAt: now,
      })
      .run();

    const sentByA = db
      .insert(homeCards)
      .values({
        authorId: userA.id,
        body: "Te dejé anotadas un par de ideas nuevas en el tablero para esta noche 🎮🍿 ¡Te quiero muchísimo!",
        bgColor: "#FFF1CC",
        fontFamily: "hand",
        fontSize: "lg",
        createdAt: yesterday,
      })
      .returning()
      .get();

    db.insert(homeCardReactions)
      .values({
        cardId: sentByA.id,
        userId: userB.id,
        emoji: "🥰",
        presetText: "Te amo ❤️",
        createdAt: yesterday,
      })
      .run();
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

  // Keep up to 3 most recent sessions per user so phone + laptop work together
  const existing = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userId))
    .orderBy(desc(sessions.lastSeenAt))
    .all();

  if (existing.length >= 3) {
    for (const old of existing.slice(2)) {
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

  const store = await cookies();
  store.set(SESSION_COOKIE, id, {
    httpOnly: true,
    sameSite: "lax",
    secure: cookieIsSecure(),
    path: "/",
    expires,
  });

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

  // Sliding session renewal in DB
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
  return all.find((u) => u.id !== myUserId) ?? null;
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
}): number | null {
  ensureInitialSeed();
  const now = new Date();

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
    if (!row) return null;
    db.update(inviteTokens)
      .set({ usedAt: now })
      .where(eq(inviteTokens.id, row.id))
      .run();
    return row.userId;
  }

  if (input.code) {
    const clean = normalizeShortCode(input.code);
    if (!clean) return null;
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
    if (!row) return null;
    db.update(inviteTokens)
      .set({ usedAt: now })
      .where(eq(inviteTokens.id, row.id))
      .run();
    return row.userId;
  }

  return null;
}

export function updateUserSettings(input: {
  userId: number;
  partnerNickname?: string;
  themeMode?: ThemeMode;
  accentPalette?: AccentPalette;
  quickReplies?: string[];
}) {
  const partner = getPartnerUser(input.userId);
  if (partner && typeof input.partnerNickname === "string") {
    const cleanNick = input.partnerNickname.trim();
    if (cleanNick.length > 0 && cleanNick.length <= 40) {
      db.update(users)
        .set({ nicknameByPartner: cleanNick })
        .where(eq(users.id, partner.id))
        .run();
    }
  }

  const updates: Partial<typeof users.$inferInsert> = {};
  if (input.themeMode) updates.themeMode = input.themeMode;
  if (input.accentPalette) updates.accentPalette = input.accentPalette;
  if (input.quickReplies) {
    const filtered = input.quickReplies
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && s.length <= 80)
      .slice(0, 12);
    if (filtered.length > 0) {
      updates.quickRepliesJson = JSON.stringify(filtered);
    }
  }

  if (Object.keys(updates).length > 0) {
    db.update(users).set(updates).where(eq(users.id, input.userId)).run();
  }
}
