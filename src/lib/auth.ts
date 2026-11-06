import { createHash, randomBytes } from "node:crypto";
import { hash, verify } from "@node-rs/argon2";
import { and, desc, eq, gt, isNull, ne, or, sql } from "drizzle-orm";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { db, rawSqlite } from "@/db";
import {
  boards,
  inviteTokens,
  sessions,
  users,
  type AccentPalette,
  type AvatarId,
  type ThemeMode,
} from "@/db/schema";

const SESSION_COOKIE = "amodoro_session";
export const SESSION_DAYS = 90;

export function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function normalizeShortCode(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

export function generateReadableShortCode(): string {
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  const bytes = randomBytes(8);
  let chars = "";
  for (let i = 0; i < 8; i++) {
    chars += alphabet[bytes[i]! % alphabet.length];
  }
  return `${chars.slice(0, 4)}-${chars.slice(4, 8)}`;
}

let seededChecked = false;

const SYSTEM_BOARD_DEFS = [
  {
    slug: "actividades",
    title: "PENDIENTES",
    icon: "schedule",
    bgColor: "#F27166",
    oldColors: ["#F08076", "#FFDAD6", "#F4EFE8"],
    sortOrder: 0,
  },
  {
    slug: "musica",
    title: "MÚSICA",
    icon: "album",
    bgColor: "#A855F7",
    oldColors: ["#E8DEF8", "#F4EFE8"],
    sortOrder: 1,
  },
  {
    slug: "pelis",
    title: "PELIS",
    icon: "movie",
    bgColor: "#F97316",
    oldColors: ["#FFDAD6", "#F4EFE8"],
    sortOrder: 2,
  },
  {
    slug: "series",
    title: "SERIES",
    icon: "tv",
    bgColor: "#3B82F6",
    oldColors: ["#D3E4FF", "#F4EFE8"],
    sortOrder: 3,
  },
  {
    slug: "juegos",
    title: "JUEGOS",
    icon: "sports_esports",
    bgColor: "#10B981",
    oldColors: ["#C8E6C9", "#F4EFE8"],
    sortOrder: 4,
  },
] as const;

export function ensureInitialSeed() {
  if (seededChecked) return;
  const now = new Date();
  const existingUsers = db.select().from(users).all();
  const allBoards = db.select().from(boards).all();

  for (const def of SYSTEM_BOARD_DEFS) {
    const existing = allBoards.find((b) => b.slug === def.slug);
    if (!existing) {
      db.insert(boards)
        .values({
          slug: def.slug,
          title: def.title,
          icon: def.icon,
          bgColor: def.bgColor,
          sortOrder: def.sortOrder,
          isSystem: true,
          createdBy: existingUsers[0]?.id ?? null,
          createdAt: now,
        })
        .run();
    } else {
      const updates: Partial<typeof boards.$inferInsert> = {};
      if (def.slug === "actividades" && existing.title !== "PENDIENTES") {
        updates.title = "PENDIENTES";
        updates.icon = "schedule";
      }
      if (
        existing.isSystem &&
        (def.oldColors as readonly string[]).includes(
          (existing.bgColor || "").toUpperCase(),
        )
      ) {
        updates.bgColor = def.bgColor;
      }
      if (existing.sortOrder === 0 && def.sortOrder !== 0) {
        updates.sortOrder = def.sortOrder;
      }
      if (Object.keys(updates).length > 0) {
        db.update(boards)
          .set(updates)
          .where(eq(boards.id, existing.id))
          .run();
      }
    }
  }

  seededChecked = true;
}

export async function hashPassword(password: string) {
  return hash(password);
}

export async function verifyPassword(hashStr: string, password: string) {
  if (!hashStr || !password) return false;
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

export type CreateSessionOptions = {
  userAgent?: string | null;
  deviceId?: string | null;
  deviceName?: string | null;
};

export async function createSessionForUser(
  userId: number,
  optionsOrUserAgent?: string | null | CreateSessionOptions,
  legacyDeviceId?: string | null,
  legacyDeviceName?: string | null,
) {
  let userAgent: string | null = null;
  let deviceId: string | null = null;
  let deviceName: string | null = null;

  if (
    optionsOrUserAgent &&
    typeof optionsOrUserAgent === "object" &&
    !("toLowerCase" in optionsOrUserAgent)
  ) {
    userAgent = optionsOrUserAgent.userAgent ?? null;
    deviceId = optionsOrUserAgent.deviceId?.trim() || null;
    deviceName = optionsOrUserAgent.deviceName?.trim() || null;
  } else if (typeof optionsOrUserAgent === "string") {
    userAgent = optionsOrUserAgent;
    deviceId = legacyDeviceId?.trim() || null;
    deviceName = legacyDeviceName?.trim() || null;
  }

  const now = new Date();
  const expires = new Date(now.getTime() + SESSION_DAYS * 86_400_000);

  if (deviceId) {
    db.delete(sessions)
      .where(and(eq(sessions.userId, userId), eq(sessions.deviceId, deviceId)))
      .run();
  }

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

  const rawToken = randomBytes(32).toString("base64url");
  const tokenHash = sha256(rawToken);

  db.insert(sessions)
    .values({
      id: tokenHash,
      userId,
      createdAt: now,
      expiresAt: expires,
      lastSeenAt: now,
      userAgent,
      deviceId,
      deviceName,
    })
    .run();

  try {
    const store = await cookies();
    store.set(SESSION_COOKIE, rawToken, {
      httpOnly: true,
      sameSite: "lax",
      secure: cookieIsSecure(),
      path: "/",
      expires,
    });
  } catch {
    // Ignore when called outside Next.js cookie context
  }

  return { id: rawToken, tokenHash, expires };
}

export function deleteSessionByToken(rawToken: string) {
  if (!rawToken) return;
  const tokenHash = sha256(rawToken);
  db.delete(sessions)
    .where(or(eq(sessions.id, tokenHash), eq(sessions.id, rawToken)))
    .run();
}

export async function clearCurrentSession() {
  const store = await cookies();
  const id = store.get(SESSION_COOKIE)?.value;
  if (id) {
    deleteSessionByToken(id);
  }
  store.delete(SESSION_COOKIE);
}

export const currentUser = cache(async () => {
  ensureInitialSeed();
  const store = await cookies();
  const rawToken = store.get(SESSION_COOKIE)?.value;
  if (!rawToken) return null;

  const tokenHash = sha256(rawToken);
  const row = db
    .select({ user: users, session: sessions })
    .from(sessions)
    .innerJoin(users, eq(sessions.userId, users.id))
    .where(
      and(
        or(eq(sessions.id, tokenHash), eq(sessions.id, rawToken)),
        gt(sessions.expiresAt, sql`unixepoch('now')`),
      ),
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
    .where(eq(sessions.id, row.session.id))
    .run();

  return row.user;
});

export async function requirePageUser() {
  const user = await currentUser();
  if (!user) {
    redirect("/");
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
  pin?: string;
  password?: string;
  avatarId?: AvatarId;
  code?: string;
}) {
  ensureInitialSeed();
  const existing = getAllUsers();
  if (existing.length >= 2) {
    throw new Error("Este espacio privado ya tiene sus 2 cuentas registradas.");
  }

  const cleanName = input.displayName.trim();
  if (!cleanName || cleanName.length > 40) {
    throw new Error("Elige un nombre válido (1 a 40 caracteres).");
  }

  const rawPin = input.pin?.trim();
  const rawPassword = input.password?.trim();

  if (rawPin !== undefined) {
    if (!/^\d{4}$/.test(rawPin)) {
      throw new Error("El PIN debe tener exactamente 4 dígitos numéricos.");
    }
  } else if (!rawPassword) {
    throw new Error("El PIN debe tener exactamente 4 dígitos numéricos.");
  }

  const pinToHash =
    rawPin ?? (rawPassword && /^\d{4}$/.test(rawPassword) ? rawPassword : "");
  const secretToHash = rawPin || rawPassword!;
  const hashedSecret = await hashPassword(secretToHash);
  const pinHash = pinToHash ? hashedSecret : "";

  const recoveryCode = generateReadableShortCode();
  const recoveryCodeHash = sha256(normalizeShortCode(recoveryCode));

  const rawUsername = (input.username?.trim() || cleanName)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9_]/g, "");

  const baseUsername = rawUsername || `user_${Date.now().toString(36)}`;
  let finalUsername = baseUsername;
  if (existing.some((u) => u.username.toLowerCase() === finalUsername)) {
    finalUsername = `${baseUsername}_${Math.floor(100 + Math.random() * 900)}`;
  }

  const created = db
    .insert(users)
    .values({
      username: finalUsername,
      passwordHash: hashedSecret,
      pinHash,
      recoveryCodeHash,
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

  if (input.code && input.code.trim()) {
    redeemInviteByTokenOrCode({
      code: input.code.trim(),
      redeemingUserId: created.id,
    });
  }

  const refreshed =
    db.select().from(users).where(eq(users.id, created.id)).get() ?? created;

  return {
    ...refreshed,
    recoveryCode,
  };
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
  if (!input.redeemingUserId) {
    throw new Error("Debes iniciar sesión o registrarte antes de vincular un código.");
  }

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
  if (input.redeemingUserId === inviterUserId) {
    throw new Error("No puedes usar tu propio código de invitación.");
  }

  const all = getAllUsers();
  const inviter = all.find((u) => u.id === inviterUserId);
  const redeemer = all.find((u) => u.id === input.redeemingUserId);
  if (!inviter || !redeemer) return null;

  if (inviter.partnerId && inviter.partnerId !== redeemer.id) {
    throw new Error("Esta cuenta ya está vinculada con otra persona.");
  }
  if (redeemer.partnerId && redeemer.partnerId !== inviter.id) {
    throw new Error("Tu cuenta ya está vinculada con otra persona.");
  }

  const runPairTx = rawSqlite.transaction(() => {
    db.update(inviteTokens)
      .set({ usedAt: now })
      .where(eq(inviteTokens.id, tokenId!))
      .run();

    db.update(users)
      .set({ partnerId: inviterUserId! })
      .where(eq(users.id, redeemer.id))
      .run();

    db.update(users)
      .set({ partnerId: redeemer.id })
      .where(eq(users.id, inviterUserId!))
      .run();
  });

  runPairTx();
  return redeemer.id;
}

export async function verifyUserPin(userId: number, pin: string): Promise<boolean> {
  if (!/^\d{4}$/.test(pin.trim())) return false;
  const user = db.select().from(users).where(eq(users.id, userId)).get();
  if (!user) return false;
  if (user.pinHash) {
    return verifyPassword(user.pinHash, pin.trim());
  }
  return verifyPassword(user.passwordHash, pin.trim());
}

export async function changeUserPin(input: {
  userId: number;
  currentPin?: string;
  newPin: string;
  keepSessionHash?: string;
}): Promise<{ recoveryCode: string }> {
  const cleanNewPin = input.newPin.trim();
  if (!/^\d{4}$/.test(cleanNewPin)) {
    throw new Error("El nuevo PIN debe tener exactamente 4 dígitos numéricos.");
  }

  const user = db.select().from(users).where(eq(users.id, input.userId)).get();
  if (!user) {
    throw new Error("Usuario no encontrado.");
  }

  if (user.pinHash) {
    if (!input.currentPin) {
      throw new Error("Ingresa tu PIN actual para cambiarlo.");
    }
    const valid = await verifyPassword(user.pinHash, input.currentPin.trim());
    if (!valid) {
      throw new Error("El PIN actual es incorrecto.");
    }
  }

  const newPinHash = await hashPassword(cleanNewPin);
  const recoveryCode = generateReadableShortCode();
  const recoveryCodeHash = sha256(normalizeShortCode(recoveryCode));
  const newPinVersion = (user.pinVersion ?? 1) + 1;

  db.update(users)
    .set({
      pinHash: newPinHash,
      passwordHash: newPinHash,
      recoveryCodeHash,
      pinVersion: newPinVersion,
    })
    .where(eq(users.id, user.id))
    .run();

  if (input.keepSessionHash) {
    db.delete(sessions)
      .where(
        and(
          eq(sessions.userId, user.id),
          ne(sessions.id, input.keepSessionHash),
        ),
      )
      .run();
  } else {
    db.delete(sessions).where(eq(sessions.userId, user.id)).run();
  }

  return { recoveryCode };
}

export async function recoverUserPin(input: {
  userId: number;
  recoveryCode: string;
  newPin: string;
}): Promise<{ recoveryCode: string }> {
  const cleanNewPin = input.newPin.trim();
  if (!/^\d{4}$/.test(cleanNewPin)) {
    throw new Error("El nuevo PIN debe tener exactamente 4 dígitos numéricos.");
  }

  const normalizedCode = normalizeShortCode(input.recoveryCode);
  if (!normalizedCode) {
    throw new Error("Código de recuperación inválido.");
  }

  const user = db.select().from(users).where(eq(users.id, input.userId)).get();
  if (!user) {
    throw new Error("Usuario no encontrado.");
  }

  const codeHash = sha256(normalizedCode);
  let validRecovery = false;

  if (user.recoveryCodeHash && user.recoveryCodeHash === codeHash) {
    validRecovery = true;
  } else {
    // Also check if partner generated an active invite/reset code
    const now = new Date();
    const partner = getPartnerUser(user.id);
    if (partner) {
      const partnerToken = db
        .select()
        .from(inviteTokens)
        .where(
          and(
            eq(inviteTokens.userId, partner.id),
            eq(inviteTokens.codeHash, codeHash),
            isNull(inviteTokens.usedAt),
            gt(inviteTokens.expiresAt, now),
          ),
        )
        .get();
      if (partnerToken) {
        validRecovery = true;
        db.update(inviteTokens)
          .set({ usedAt: now })
          .where(eq(inviteTokens.id, partnerToken.id))
          .run();
      }
    }
  }

  if (!validRecovery) {
    throw new Error("Código de recuperación incorrecto o expirado.");
  }

  const newPinHash = await hashPassword(cleanNewPin);
  const newRecoveryCode = generateReadableShortCode();
  const newRecoveryCodeHash = sha256(normalizeShortCode(newRecoveryCode));
  const newPinVersion = (user.pinVersion ?? 1) + 1;

  db.update(users)
    .set({
      pinHash: newPinHash,
      passwordHash: newPinHash,
      recoveryCodeHash: newRecoveryCodeHash,
      pinVersion: newPinVersion,
    })
    .where(eq(users.id, user.id))
    .run();

  db.delete(sessions).where(eq(sessions.userId, user.id)).run();

  return { recoveryCode: newRecoveryCode };
}

export function updateUserFcmToken(userId: number, fcmToken: string | null) {
  const clean = fcmToken?.trim() || null;
  db.update(users)
    .set({ fcmToken: clean })
    .where(eq(users.id, userId))
    .run();
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
