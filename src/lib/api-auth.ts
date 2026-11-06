import { and, eq, gt, or, sql } from "drizzle-orm";
import { db } from "@/db";
import { sessions, users, type AvatarId } from "@/db/schema";
import {
  SESSION_DAYS,
  changeUserPin,
  createSessionForUser,
  deleteSessionByToken,
  ensureInitialSeed,
  getAllUsers,
  recoverUserPin,
  redeemInviteByTokenOrCode,
  registerNewUser,
  sha256,
  verifyPassword,
  verifyUserPin,
} from "./auth";
import { checkRateLimit, logSecurityEvent, resetRateLimit } from "./rate-limit";

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, If-None-Match, x-device-id, x-device-name",
  "Access-Control-Expose-Headers": "ETag",
};

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...CORS_HEADERS,
    },
  });
}

export function extractRawTokenFromRequest(request: Request): string {
  const authHeader = request.headers.get("authorization") ?? "";
  if (authHeader.toLowerCase().startsWith("bearer ")) {
    const token = authHeader.slice(7).trim();
    if (token) return token;
  }

  const cookieHeader = request.headers.get("cookie") ?? "";
  const match = /amodoro_session=([^;]+)/.exec(cookieHeader);
  if (match?.[1]) {
    return decodeURIComponent(match[1]);
  }

  return "";
}

function validateSessionToken(rawToken: string) {
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

  if (!row) return null;

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
}

export function getApiUser(request: Request) {
  ensureInitialSeed();
  const token = extractRawTokenFromRequest(request);
  return validateSessionToken(token);
}

export function getApiUserFromRequestOrQuery(request: Request) {
  ensureInitialSeed();
  const fromHeader = getApiUser(request);
  if (fromHeader) return fromHeader;

  try {
    const url = new URL(request.url);
    const queryToken = url.searchParams.get("t")?.trim() ?? "";
    if (queryToken) {
      return validateSessionToken(queryToken);
    }
  } catch {
    // ignore URL parse error
  }
  return null;
}

export type AuthMode =
  | "register"
  | "pair"
  | "code"
  | "verify_pin"
  | "pin_login"
  | "check_pin"
  | "password"
  | "change_pin"
  | "recover_pin"
  | "logout";

export async function loginApiUser(input: {
  mode: AuthMode;
  username?: string;
  displayName?: string;
  avatarId?: AvatarId;
  pin?: string;
  currentPin?: string;
  newPin?: string;
  recoveryCode?: string;
  password?: string;
  code?: string;
  userId?: number;
  currentUserId?: number;
  rawToken?: string;
  clientIp?: string;
  userAgent?: string | null;
  deviceId?: string | null;
  deviceName?: string | null;
}) {
  ensureInitialSeed();
  const all = getAllUsers();
  const ip = input.clientIp || "local";

  if (input.mode === "logout") {
    if (input.rawToken) {
      deleteSessionByToken(input.rawToken);
    }
    return { loggedOut: true as const };
  }

  if (input.mode === "check_pin") {
    const cleanPin = (input.pin ?? input.password ?? "").trim();
    const candidateUser =
      (input.currentUserId
        ? all.find((u) => u.id === input.currentUserId)
        : undefined) ??
      (input.userId ? all.find((u) => u.id === Number(input.userId)) : undefined) ??
      (input.username
        ? all.find(
            (u) =>
              u.username.toLowerCase() === input.username!.toLowerCase().trim() ||
              u.displayName.toLowerCase() === input.username!.toLowerCase().trim(),
          )
        : undefined);

    if (!candidateUser) {
      return null;
    }

    const rateKey = `check_pin:${candidateUser.id}`;
    const rl = checkRateLimit(rateKey, 5, 15 * 60_000);
    if (!rl.allowed) {
      logSecurityEvent("pin_lockout", { userId: candidateUser.id, ip });
      throw new Error(
        `Demasiados intentos de PIN fallidos. Intenta de nuevo en ${Math.ceil(rl.retryAfterSec / 60)} min.`,
      );
    }

    const isValid = await verifyUserPin(candidateUser.id, cleanPin);
    if (!isValid) {
      logSecurityEvent("pin_failed", { userId: candidateUser.id, ip });
      return { checkedPin: true as const, valid: false, user: candidateUser };
    }
    resetRateLimit(rateKey);
    return { checkedPin: true as const, valid: true, user: candidateUser };
  }

  let targetUser: (typeof users.$inferSelect) | undefined;
  let recoveryCodeIssued: string | undefined;

  if (input.mode === "register") {
    const rl = checkRateLimit(`register:${ip}`, 10, 15 * 60_000);
    if (!rl.allowed) {
      logSecurityEvent("register_rate_limited", { ip });
      throw new Error("Demasiados intentos. Espera unos minutos.");
    }
    const created = await registerNewUser({
      username: input.username,
      displayName: input.displayName || input.username || "",
      pin: input.pin,
      password: input.password,
      avatarId: input.avatarId || "cat",
      code: input.code,
    });
    targetUser = created;
    recoveryCodeIssued = created.recoveryCode;
  } else if (input.mode === "pair" || input.mode === "code") {
    const rl = checkRateLimit(`pair:${ip}`, 10, 15 * 60_000);
    if (!rl.allowed) {
      logSecurityEvent("pair_rate_limited", { ip });
      throw new Error("Demasiados intentos de vinculación. Espera unos minutos.");
    }
    const redeemingId = input.currentUserId ?? input.userId;
    if (!redeemingId) {
      throw new Error("Inicia sesión o regístrate antes de vincular el código.");
    }
    const redeemedId = redeemInviteByTokenOrCode({
      code: input.code,
      redeemingUserId: redeemingId,
    });
    if (redeemedId) {
      const updatedAll = getAllUsers();
      targetUser = updatedAll.find((u) => u.id === redeemedId);
    }
  } else if (input.mode === "verify_pin" || input.mode === "pin_login") {
    const cleanPin = (input.pin ?? input.password ?? "").trim();
    const candidateUser =
      (input.currentUserId
        ? all.find((u) => u.id === input.currentUserId)
        : undefined) ??
      (input.userId ? all.find((u) => u.id === Number(input.userId)) : undefined) ??
      (input.username
        ? all.find(
            (u) =>
              u.username.toLowerCase() === input.username!.toLowerCase().trim() ||
              u.displayName.toLowerCase() === input.username!.toLowerCase().trim(),
          )
        : undefined);

    const rateKey = `pin:${candidateUser?.id ?? ip}`;
    const rl = checkRateLimit(rateKey, 5, 15 * 60_000);
    if (!rl.allowed) {
      logSecurityEvent("pin_lockout", { userId: candidateUser?.id, ip });
      throw new Error(
        `Demasiados intentos de PIN fallidos. Intenta de nuevo en ${Math.ceil(rl.retryAfterSec / 60)} min.`,
      );
    }

    if (candidateUser && (await verifyUserPin(candidateUser.id, cleanPin))) {
      resetRateLimit(rateKey);
      targetUser = candidateUser;

      if (
        input.currentUserId === candidateUser.id &&
        input.rawToken &&
        input.rawToken.trim()
      ) {
        const rawTokenTrimmed = input.rawToken.trim();
        const tokenHash = sha256(rawTokenTrimmed);
        const sessionRow = db
          .select()
          .from(sessions)
          .where(
            and(
              or(eq(sessions.id, tokenHash), eq(sessions.id, rawTokenTrimmed)),
              eq(sessions.userId, candidateUser.id),
              gt(sessions.expiresAt, sql`unixepoch('now')`),
            ),
          )
          .get();

        if (sessionRow) {
          const nowSec = Math.floor(Date.now() / 1000);
          const newExpiresSec = nowSec + SESSION_DAYS * 86_400;
          const sessionUpdates: Partial<typeof sessions.$inferInsert> = {
            lastSeenAt: new Date(nowSec * 1000),
            expiresAt: new Date(newExpiresSec * 1000),
          };
          if (input.deviceId) sessionUpdates.deviceId = input.deviceId;
          if (input.deviceName) sessionUpdates.deviceName = input.deviceName;
          if (input.userAgent) sessionUpdates.userAgent = input.userAgent;

          db.update(sessions)
            .set(sessionUpdates)
            .where(eq(sessions.id, sessionRow.id))
            .run();

          return {
            token: rawTokenTrimmed,
            expiresAt: new Date(newExpiresSec * 1000),
            user: targetUser,
            recoveryCode: undefined,
            reused: true as const,
          };
        }
      }
    } else {
      logSecurityEvent("pin_failed", { userId: candidateUser?.id, ip });
      return null;
    }
  } else if (input.mode === "change_pin") {
    if (!input.currentUserId) {
      throw new Error("No autorizado para cambiar el PIN.");
    }
    const rateKey = `change_pin:${input.currentUserId}`;
    const rl = checkRateLimit(rateKey, 5, 15 * 60_000);
    if (!rl.allowed) {
      throw new Error("Demasiados intentos. Espera unos minutos.");
    }
    const res = await changeUserPin({
      userId: input.currentUserId,
      currentPin: input.currentPin,
      newPin: input.newPin ?? "",
    });
    resetRateLimit(rateKey);
    recoveryCodeIssued = res.recoveryCode;
    targetUser = getAllUsers().find((u) => u.id === input.currentUserId);
  } else if (input.mode === "recover_pin") {
    const candidateUser =
      (input.currentUserId
        ? all.find((u) => u.id === input.currentUserId)
        : undefined) ??
      (input.userId ? all.find((u) => u.id === Number(input.userId)) : undefined) ??
      (input.username
        ? all.find(
            (u) =>
              u.username.toLowerCase() === input.username!.toLowerCase().trim() ||
              u.displayName.toLowerCase() === input.username!.toLowerCase().trim(),
          )
        : undefined);

    const rateKey = `recover_pin:${candidateUser?.id ?? ip}`;
    const rl = checkRateLimit(rateKey, 5, 15 * 60_000);
    if (!rl.allowed) {
      logSecurityEvent("recover_pin_rate_limited", {
        userId: candidateUser?.id,
        ip,
      });
      throw new Error("Demasiados intentos de recuperación. Espera 15 minutos.");
    }

    if (!candidateUser) {
      throw new Error("Cuenta no encontrada.");
    }

    const res = await recoverUserPin({
      userId: candidateUser.id,
      recoveryCode: input.recoveryCode ?? "",
      newPin: input.newPin ?? "",
    });
    resetRateLimit(rateKey);
    recoveryCodeIssued = res.recoveryCode;
    targetUser = getAllUsers().find((u) => u.id === candidateUser.id);
  } else if (input.mode === "password") {
    const clean = (input.username ?? "").toLowerCase().trim();
    const found = all.find(
      (u) =>
        u.username.toLowerCase() === clean ||
        (u.displayName && u.displayName.toLowerCase() === clean),
    );
    const rateKey = `pwd:${found?.id ?? ip}`;
    const rl = checkRateLimit(rateKey, 5, 15 * 60_000);
    if (!rl.allowed) {
      logSecurityEvent("password_rate_limited", { userId: found?.id, ip });
      throw new Error("Demasiados intentos fallidos. Espera 15 minutos.");
    }
    if (found) {
      const pass = (input.password ?? input.pin ?? "").trim();
      const validHash =
        (found.pinHash && (await verifyPassword(found.pinHash, pass))) ||
        (await verifyPassword(found.passwordHash, pass));
      if (validHash) {
        resetRateLimit(rateKey);
        targetUser = found;
      } else {
        logSecurityEvent("password_failed", { userId: found.id, ip });
      }
    }
  } else {
    throw new Error("Modo de autenticación no soportado.");
  }

  if (!targetUser) return null;

  const session = await createSessionForUser(targetUser.id, {
    userAgent: input.userAgent ?? null,
    deviceId: input.deviceId ?? null,
    deviceName: input.deviceName ?? null,
  });
  return {
    token: session.id,
    expiresAt: session.expires,
    user: targetUser,
    recoveryCode: recoveryCodeIssued,
    reused: false as const,
  };
}
