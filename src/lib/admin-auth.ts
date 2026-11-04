import { createHmac, timingSafeEqual } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { hashSync, verifySync } from "@node-rs/argon2";

const DEFAULT_ADMIN_PASSWORD_HASH =
  "$argon2id$v=19$m=19456,t=2,p=1$uEATsOgQv3cvEn/aaZskVQ$OjnfVpi7l/MOp4fiqr6IRwlWffqla/nCEwWlb1fyP40";

export const ADMIN_COOKIE_NAME = "amodoro_admin_session";

interface AdminConfigFile {
  passwordHash?: string;
  updatedAt?: string;
}

function getAdminConfigPath(): string {
  return join(
    /*turbopackIgnore: true*/ process.cwd(),
    "data",
    "admin-config.json",
  );
}

function readAdminConfig(): AdminConfigFile {
  const filePath = getAdminConfigPath();
  try {
    if (existsSync(filePath)) {
      const raw = readFileSync(filePath, "utf8");
      const parsed = JSON.parse(raw) as AdminConfigFile;
      if (parsed && typeof parsed === "object") {
        return parsed;
      }
    }
  } catch {
    // Fall back to default
  }
  return {};
}

function getActiveAdminPasswordHash(): string {
  const cfg = readAdminConfig();
  if (cfg.passwordHash && cfg.passwordHash.trim()) {
    return cfg.passwordHash.trim();
  }
  if (
    process.env.AMODORO_ADMIN_PASSWORD_HASH &&
    process.env.AMODORO_ADMIN_PASSWORD_HASH.trim()
  ) {
    return process.env.AMODORO_ADMIN_PASSWORD_HASH.trim();
  }
  return DEFAULT_ADMIN_PASSWORD_HASH;
}

export function verifyAdminPassword(password: string): boolean {
  if (!password || typeof password !== "string") {
    return false;
  }
  try {
    const activeHash = getActiveAdminPasswordHash();
    return verifySync(activeHash, password);
  } catch {
    return false;
  }
}

export function updateAdminPassword(
  currentPassword: string,
  newPassword: string,
): void {
  if (!verifyAdminPassword(currentPassword)) {
    throw new Error("La contraseña de administrador actual es incorrecta.");
  }
  if (typeof newPassword !== "string" || newPassword.length < 8) {
    throw new Error(
      "La nueva contraseña debe tener al menos 8 caracteres.",
    );
  }

  const hashed = hashSync(newPassword);
  const filePath = getAdminConfigPath();
  mkdirSync(dirname(filePath), { recursive: true });
  const payload: AdminConfigFile = {
    passwordHash: hashed,
    updatedAt: new Date().toISOString(),
  };
  writeFileSync(filePath, JSON.stringify(payload, null, 2), "utf8");
}

function getAdminSigningSecret(): string {
  const envSecret = process.env.AMODORO_ADMIN_SECRET || "amodoro-admin-v1.6";
  return `${DEFAULT_ADMIN_PASSWORD_HASH}:${envSecret}`;
}

export function createAdminSessionToken(): string {
  const payload = {
    exp: Date.now() + 12 * 3600 * 1000,
    role: "admin",
  };
  const payloadB64 = Buffer.from(JSON.stringify(payload), "utf8").toString(
    "base64url",
  );
  const sig = createHmac("sha256", getAdminSigningSecret())
    .update(payloadB64)
    .digest("base64url");
  return `${payloadB64}.${sig}`;
}

export function verifyAdminSessionToken(
  token: string | undefined | null,
): boolean {
  if (!token || typeof token !== "string") {
    return false;
  }
  const parts = token.trim().split(".");
  if (parts.length !== 2) {
    return false;
  }
  const [payloadB64, providedSig] = parts;
  if (!payloadB64 || !providedSig) {
    return false;
  }

  try {
    const expectedSig = createHmac("sha256", getAdminSigningSecret())
      .update(payloadB64)
      .digest("base64url");

    const a = Buffer.from(providedSig, "utf8");
    const b = Buffer.from(expectedSig, "utf8");
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      return false;
    }

    const decoded = JSON.parse(
      Buffer.from(payloadB64, "base64url").toString("utf8"),
    ) as { exp?: number; role?: string };

    if (decoded.role !== "admin" || typeof decoded.exp !== "number") {
      return false;
    }
    if (Date.now() > decoded.exp) {
      return false;
    }
    return true;
  } catch {
    return false;
  }
}

export function isAdminRequestAuthenticated(req: Request): boolean {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.toLowerCase().startsWith("bearer ")) {
    const bearerToken = authHeader.slice(7).trim();
    if (verifyAdminSessionToken(bearerToken)) {
      return true;
    }
  }

  const cookieHeader = req.headers.get("cookie") || "";
  const cookies = cookieHeader.split(";");
  for (const part of cookies) {
    const [rawName, ...rawValParts] = part.trim().split("=");
    if (rawName === ADMIN_COOKIE_NAME) {
      const val = decodeURIComponent(rawValParts.join("="));
      if (verifyAdminSessionToken(val)) {
        return true;
      }
    }
  }

  return false;
}
