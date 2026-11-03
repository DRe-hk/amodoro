import { createSign } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { getPartnerUser } from "./auth";

interface ServiceAccountJson {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

let cachedServiceAccount: ServiceAccountJson | null | undefined;
let cachedAccessToken: { token: string; expiresAtMs: number } | null = null;

function loadServiceAccount(): ServiceAccountJson | null {
  if (cachedServiceAccount !== undefined) {
    return cachedServiceAccount;
  }

  const candidatePaths = [
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH,
    "/home/azureuser/amodoro-server/data/firebase-admin.json",
    "/home/drehk/Projects/algrthmlvu-d2fd6-firebase-adminsdk-fbsvc-234b21afa6.json",
  ].filter((p): p is string => Boolean(p && p.trim()));

  for (const path of candidatePaths) {
    try {
      if (existsSync(path)) {
        const raw = readFileSync(path, "utf8");
        const parsed = JSON.parse(raw) as ServiceAccountJson;
        if (parsed.project_id && parsed.client_email && parsed.private_key) {
          cachedServiceAccount = parsed;
          return parsed;
        }
      }
    } catch {
      // Try next candidate
    }
  }

  cachedServiceAccount = null;
  return null;
}

function base64UrlEncode(input: string | Buffer): string {
  const buf = typeof input === "string" ? Buffer.from(input, "utf8") : input;
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

async function getFirebaseAccessToken(
  sa: ServiceAccountJson,
): Promise<string | null> {
  const nowMs = Date.now();
  if (cachedAccessToken && cachedAccessToken.expiresAtMs > nowMs + 60_000) {
    return cachedAccessToken.token;
  }

  const nowSec = Math.floor(nowMs / 1000);
  const tokenUri = sa.token_uri || "https://oauth2.googleapis.com/token";
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: tokenUri,
    iat: nowSec,
    exp: nowSec + 3600,
  };

  const unsignedJwt = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsignedJwt);
  signer.end();
  const signature = signer.sign(sa.private_key);
  const assertion = `${unsignedJwt}.${base64UrlEncode(signature)}`;

  const res = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }).toString(),
    signal: AbortSignal.timeout(5000),
  });

  if (!res.ok) return null;
  const data = (await res.json()) as {
    access_token?: string;
    expires_in?: number;
  };
  if (!data.access_token) return null;

  cachedAccessToken = {
    token: data.access_token,
    expiresAtMs: nowMs + 50 * 60 * 1000, // 50 minutes
  };
  return data.access_token;
}

export async function sendPushToPartner(
  senderUserId: number,
  notification: {
    title: string;
    body: string;
    data?: Record<string, string>;
  },
): Promise<boolean> {
  try {
    const partner = getPartnerUser(senderUserId);
    const fcmToken = partner?.fcmToken?.trim();
    if (!fcmToken) return false;

    const sa = loadServiceAccount();
    if (!sa) return false;

    const accessToken = await getFirebaseAccessToken(sa);
    if (!accessToken) return false;

    const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const res = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data ?? {},
          android: {
            priority: "HIGH",
            notification: {
              sound: "default",
              defaultVibrateTimings: true,
            },
          },
        },
      }),
      signal: AbortSignal.timeout(5000),
    });

    return res.ok;
  } catch {
    return false;
  }
}
