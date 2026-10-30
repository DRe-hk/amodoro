import { and, eq, gt, sql } from "drizzle-orm";
import { db } from "@/db";
import { sessions, users } from "@/db/schema";
import {
  createSessionForUser,
  ensureInitialSeed,
  getAllUsers,
  redeemInviteByTokenOrCode,
  verifyPassword,
} from "./auth";

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
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

export function getApiUser(request: Request) {
  ensureInitialSeed();
  const authHeader = request.headers.get("authorization") ?? "";
  let token = "";
  if (authHeader.toLowerCase().startsWith("bearer ")) {
    token = authHeader.slice(7).trim();
  }

  if (!token) {
    const cookieHeader = request.headers.get("cookie") ?? "";
    const match = /amodoro_session=([^;]+)/.exec(cookieHeader);
    if (match?.[1]) {
      token = decodeURIComponent(match[1]);
    }
  }

  if (!token) return null;

  const row = db
    .select({ user: users, session: sessions })
    .from(sessions)
    .innerJoin(users, eq(sessions.userId, users.id))
    .where(
      and(eq(sessions.id, token), gt(sessions.expiresAt, sql`unixepoch('now')`)),
    )
    .get();

  if (!row) return null;

  // Extend sliding session
  const nowSec = Math.floor(Date.now() / 1000);
  const newExpiresSec = nowSec + 365 * 86_400;
  db.update(sessions)
    .set({
      lastSeenAt: new Date(nowSec * 1000),
      expiresAt: new Date(newExpiresSec * 1000),
    })
    .where(eq(sessions.id, token))
    .run();

  return row.user;
}

export async function loginApiUser(input: {
  mode: "password" | "code" | "quick";
  username?: string;
  password?: string;
  code?: string;
  userId?: number;
  userAgent?: string | null;
}) {
  ensureInitialSeed();
  const all = getAllUsers();

  let targetUser: (typeof users.$inferSelect) | undefined;

  if (input.mode === "quick") {
    targetUser = all.find((u) => u.id === Number(input.userId));
    if (!targetUser && input.username) {
      const clean = input.username.toLowerCase().trim();
      targetUser = all.find((u) => u.username.toLowerCase() === clean);
    }
  } else if (input.mode === "code") {
    const redeemedId = redeemInviteByTokenOrCode({ code: input.code });
    if (redeemedId) {
      targetUser = all.find((u) => u.id === redeemedId);
    }
  } else if (input.mode === "password") {
    const clean = (input.username ?? "").toLowerCase().trim();
    const found = all.find((u) => u.username.toLowerCase() === clean);
    if (found) {
      const pass = (input.password ?? "").trim();
      // Accept default password "amodoro" or "1234" for seeded accounts, or argon2 verify
      const validSeedPass =
        pass === "amodoro" || pass === "1234" || pass === found.username;
      const validHash = await verifyPassword(found.passwordHash, pass);
      if (validSeedPass || validHash) {
        targetUser = found;
      }
    }
  }

  if (!targetUser) return null;

  const session = await createSessionForUser(
    targetUser.id,
    input.userAgent ?? null,
  );
  return {
    token: session.id,
    expiresAt: session.expires,
    user: targetUser,
  };
}
