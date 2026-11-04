import { readFile } from "node:fs/promises";
import { NextResponse } from "next/server";
import {
  ADMIN_COOKIE_NAME,
  createAdminSessionToken,
  isAdminRequestAuthenticated,
  updateAdminPassword,
  verifyAdminPassword,
} from "@/lib/admin-auth";
import {
  adminCleanOrphanMedia,
  adminClearLinkPreviewCache,
  adminDeleteBoardItem,
  adminDeleteCardReply,
  adminDeleteHomeCard,
  adminDeleteMediaItem,
  adminDeleteUser,
  adminExecuteReadOnlySql,
  adminPairAllUsers,
  adminRegenerateRecoveryCode,
  adminResetUserPin,
  adminRevokeSessions,
  adminUnpairUsers,
  adminUpdateUser,
  createFullTarGzBuffer,
  createHotSqliteBackupBuffer,
  createServerSnapshot,
  deleteServerSnapshot,
  exportFullDatabaseJson,
  getAdminOverview,
  getSnapshotFileBuffer,
  recordAdminSecurityEvent,
  restoreFromSnapshot,
  restoreFromUploadedBuffer,
} from "@/lib/admin-service";
import {
  ALLOWED_IMAGE_TYPES,
  absoluteUploadPath,
  getMediaById,
  type AllowedImageType,
} from "@/lib/media";
import { sendPushToUser } from "@/lib/push";
import { checkRateLimit, getClientIp, resetRateLimit } from "@/lib/rate-limit";

const ROBOTS_HEADERS = {
  "X-Robots-Tag": "noindex, nofollow",
  "Cache-Control": "no-store, max-age=0",
};

function adminJson(
  data: Record<string, unknown>,
  status = 200,
  extraHeaders?: Record<string, string>,
) {
  return NextResponse.json(data, {
    status,
    headers: {
      ...ROBOTS_HEADERS,
      ...extraHeaders,
    },
  });
}

function cookieIsSecure(): boolean {
  if (process.env.COOKIE_SECURE === "false") return false;
  return process.env.NODE_ENV === "production";
}

function todayDateStamp(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function GET(request: Request) {
  if (!isAdminRequestAuthenticated(request)) {
    return adminJson({ ok: false, authenticated: false }, 401);
  }

  const url = new URL(request.url);
  const download = url.searchParams.get("download");

  try {
    if (download === "db") {
      const buf = await createHotSqliteBackupBuffer();
      const filename = `amodoro-backup-${todayDateStamp()}.db`;
      return new Response(new Uint8Array(buf), {
        status: 200,
        headers: {
          ...ROBOTS_HEADERS,
          "Content-Type": "application/x-sqlite3",
          "Content-Disposition": `attachment; filename="${filename}"`,
        },
      });
    }

    if (download === "tar") {
      const buf = await createFullTarGzBuffer();
      const filename = `amodoro-full-backup-${todayDateStamp()}.tar.gz`;
      return new Response(new Uint8Array(buf), {
        status: 200,
        headers: {
          ...ROBOTS_HEADERS,
          "Content-Type": "application/gzip",
          "Content-Disposition": `attachment; filename="${filename}"`,
        },
      });
    }

    if (download === "json") {
      const jsonStr = JSON.stringify(exportFullDatabaseJson(), null, 2);
      const filename = `amodoro-export-${todayDateStamp()}.json`;
      return new Response(jsonStr, {
        status: 200,
        headers: {
          ...ROBOTS_HEADERS,
          "Content-Type": "application/json; charset=utf-8",
          "Content-Disposition": `attachment; filename="${filename}"`,
        },
      });
    }

    if (download === "snapshot") {
      const fileParam =
        url.searchParams.get("file") ?? url.searchParams.get("filename") ?? "";
      const { buffer, safeName } = getSnapshotFileBuffer(fileParam);
      const contentType = safeName.endsWith(".db")
        ? "application/x-sqlite3"
        : "application/gzip";
      return new Response(new Uint8Array(buffer), {
        status: 200,
        headers: {
          ...ROBOTS_HEADERS,
          "Content-Type": contentType,
          "Content-Disposition": `attachment; filename="${safeName}"`,
        },
      });
    }

    if (download === "media") {
      const rawId = url.searchParams.get("id");
      const id = Number(rawId);
      if (!Number.isInteger(id) || id <= 0) {
        return new Response("Not Found", {
          status: 404,
          headers: ROBOTS_HEADERS,
        });
      }
      const row = getMediaById(id);
      if (!row) {
        return new Response("Not Found", {
          status: 404,
          headers: ROBOTS_HEADERS,
        });
      }
      const absPath = absoluteUploadPath(row.path);
      if (!absPath) {
        return new Response("Not Found", {
          status: 404,
          headers: ROBOTS_HEADERS,
        });
      }
      const safeMime = ALLOWED_IMAGE_TYPES.includes(
        row.mime as AllowedImageType,
      )
        ? row.mime
        : "image/png";
      const bytes = await readFile(absPath);
      return new Response(new Uint8Array(bytes), {
        status: 200,
        headers: {
          ...ROBOTS_HEADERS,
          "Content-Type": safeMime,
          "X-Content-Type-Options": "nosniff",
          "Content-Disposition": "inline",
        },
      });
    }

    return adminJson({
      ok: true,
      authenticated: true,
      overview: getAdminOverview(),
    });
  } catch (err) {
    return adminJson(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error en el servidor admin.",
      },
      400,
    );
  }
}

export async function POST(request: Request) {
  const ip = getClientIp(request);
  let body: Record<string, unknown> = {};
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return adminJson({ ok: false, error: "JSON inválido." }, 400);
  }

  const action = String(body.action ?? "").trim();

  if (action === "login") {
    const rateKey = `admin_login:${ip}`;
    const limit = checkRateLimit(rateKey, 5, 15 * 60 * 1000);
    if (!limit.allowed) {
      recordAdminSecurityEvent(
        "ADMIN_LOGIN_RATE_LIMITED",
        { retryAfterSec: limit.retryAfterSec },
        ip,
      );
      return adminJson(
        {
          ok: false,
          error: `Demasiados intentos. Intenta de nuevo en ${limit.retryAfterSec}s.`,
        },
        429,
      );
    }

    const password = typeof body.password === "string" ? body.password : "";
    if (!verifyAdminPassword(password)) {
      recordAdminSecurityEvent("ADMIN_LOGIN_FAILED", {}, ip);
      return adminJson(
        { ok: false, error: "Contraseña de administrador incorrecta." },
        401,
      );
    }

    resetRateLimit(rateKey);
    recordAdminSecurityEvent("ADMIN_LOGIN_SUCCESS", {}, ip);

    const token = createAdminSessionToken();
    const res = adminJson({
      ok: true,
      authenticated: true,
      overview: getAdminOverview(),
    });
    res.cookies.set(ADMIN_COOKIE_NAME, token, {
      httpOnly: true,
      path: "/",
      maxAge: 43200,
      sameSite: "strict",
      secure: cookieIsSecure(),
    });
    return res;
  }

  if (action === "logout") {
    recordAdminSecurityEvent("ADMIN_LOGOUT", {}, ip);
    const res = adminJson({ ok: true, authenticated: false });
    res.cookies.set(ADMIN_COOKIE_NAME, "", {
      httpOnly: true,
      path: "/",
      maxAge: 0,
      sameSite: "strict",
      secure: cookieIsSecure(),
    });
    return res;
  }

  if (!isAdminRequestAuthenticated(request)) {
    return adminJson(
      { ok: false, authenticated: false, error: "Sesión expirada o no autorizada." },
      401,
    );
  }

  try {
    switch (action) {
      case "change_admin_password": {
        const currentPassword = String(body.currentPassword ?? "");
        const newPassword = String(body.newPassword ?? "");
        updateAdminPassword(currentPassword, newPassword);
        recordAdminSecurityEvent("ADMIN_PASSWORD_CHANGED", {}, ip);
        return adminJson({
          ok: true,
          message: "Contraseña de administrador actualizada.",
          overview: getAdminOverview(),
        });
      }

      case "reset_user_pin": {
        const userId = Number(body.userId);
        const newPin = String(body.newPin ?? "");
        const { recoveryCode } = adminResetUserPin(userId, newPin);
        return adminJson({
          ok: true,
          recoveryCode,
          overview: getAdminOverview(),
        });
      }

      case "regenerate_recovery_code": {
        const userId = Number(body.userId);
        const { recoveryCode } = adminRegenerateRecoveryCode(userId);
        return adminJson({
          ok: true,
          recoveryCode,
          overview: getAdminOverview(),
        });
      }

      case "update_user": {
        const userId = Number(body.userId);
        adminUpdateUser(userId, {
          displayName:
            typeof body.displayName === "string" ? body.displayName : undefined,
          avatarId:
            typeof body.avatarId === "string" ? body.avatarId : undefined,
          partnerNicknameGiven:
            typeof body.partnerNicknameGiven === "string"
              ? body.partnerNicknameGiven
              : undefined,
        });
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "revoke_sessions": {
        const userId = Number(body.userId);
        const revokedCount = adminRevokeSessions(userId);
        return adminJson({
          ok: true,
          revokedCount,
          overview: getAdminOverview(),
        });
      }

      case "delete_user": {
        const userId = Number(body.userId);
        adminDeleteUser(userId);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "pair_users": {
        const paired = adminPairAllUsers();
        return adminJson({
          ok: true,
          paired,
          overview: getAdminOverview(),
        });
      }

      case "unpair_users": {
        adminUnpairUsers();
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "test_push": {
        const userId = Number(body.userId);
        const title =
          typeof body.title === "string" && body.title.trim()
            ? body.title.trim()
            : "Amodoro Admin ✨";
        const msgBody =
          typeof body.body === "string" && body.body.trim()
            ? body.body.trim()
            : "Notificación de prueba desde el panel de administración.";
        const pushRes = await sendPushToUser(userId, {
          title,
          body: msgBody,
          data: { type: "admin_test" },
        });
        recordAdminSecurityEvent(
          "ADMIN_TEST_PUSH",
          { userId, ok: pushRes.ok, reason: pushRes.reason },
          ip,
        );
        if (!pushRes.ok) {
          return adminJson(
            {
              ok: false,
              reason: pushRes.reason,
              error: pushRes.reason || "No se pudo enviar la notificación push.",
              overview: getAdminOverview(),
            },
            400,
          );
        }
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "delete_home_card": {
        const cardId = Number(body.cardId ?? body.id);
        adminDeleteHomeCard(cardId);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "delete_card_reply": {
        const replyId = Number(body.replyId ?? body.id);
        adminDeleteCardReply(replyId);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "delete_board_item": {
        const itemId = Number(body.itemId ?? body.id);
        adminDeleteBoardItem(itemId);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "delete_media": {
        const mediaId = Number(body.mediaId ?? body.id);
        adminDeleteMediaItem(mediaId);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "clean_orphans": {
        const result = adminCleanOrphanMedia();
        return adminJson({
          ok: true,
          ...result,
          result,
          overview: getAdminOverview(),
        });
      }

      case "clear_link_cache": {
        const clearedCount = adminClearLinkPreviewCache();
        return adminJson({
          ok: true,
          clearedCount,
          overview: getAdminOverview(),
        });
      }

      case "create_snapshot": {
        const snapshot = await createServerSnapshot();
        return adminJson({
          ok: true,
          snapshot,
          overview: getAdminOverview(),
        });
      }

      case "delete_snapshot": {
        const filename = String(body.filename ?? body.file ?? "");
        deleteServerSnapshot(filename);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "restore_snapshot": {
        const filename = String(body.filename ?? body.file ?? "");
        restoreFromSnapshot(filename);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "restore_upload": {
        const rawBase64 = String(
          body.base64 ?? body.dataBase64 ?? body.fileBase64 ?? "",
        ).trim();
        const filename = String(body.filename ?? "upload.db");
        if (!rawBase64) {
          return adminJson(
            { ok: false, error: "Archivo vacío o no proporcionado." },
            400,
          );
        }
        const cleanedBase64 = rawBase64.replace(/^data:[^;]+;base64,/, "");
        const buf = Buffer.from(cleanedBase64, "base64");
        restoreFromUploadedBuffer(buf, filename);
        return adminJson({
          ok: true,
          overview: getAdminOverview(),
        });
      }

      case "run_sql": {
        const sqlQuery = String(body.sql ?? body.query ?? "");
        const { columns, rows } = adminExecuteReadOnlySql(sqlQuery);
        return adminJson({
          ok: true,
          columns,
          rows,
          result: { columns, rows },
        });
      }

      default:
        return adminJson(
          { ok: false, error: `Acción desconocida: ${action}` },
          400,
        );
    }
  } catch (err) {
    return adminJson(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error ejecutando acción.",
      },
      400,
    );
  }
}
