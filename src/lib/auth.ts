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
  const now = new Date();
  const existingUsers = db.select().from(users).all();
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

  ensureBoard("actividades", "PENDIENTES", "schedule", "#F08076");
  ensureBoard("musica", "MÚSICA", "album", "#E8DEF8");
  ensureBoard("pelis", "PELIS", "movie", "#FFDAD6");
  ensureBoard("series", "SERIES", "tv", "#D3E4FF");
  ensureBoard("juegos", "JUEGOS", "sports_esports", "#C8E6C9");

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
      themeMode: "system",
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
  reactionEmojis?: string[];
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
  if (input.reactionEmojis) {
    const filteredEmojis = input.reactionEmojis
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && s.length <= 16)
      .slice(0, 20);
    if (filteredEmojis.length > 0) {
      updates.reactionEmojisJson = JSON.stringify(filteredEmojis);
    }
  }

  if (Object.keys(updates).length > 0) {
    db.update(users).set(updates).where(eq(users.id, input.userId)).run();
  }
}
