import { getAllUsers, getPartnerUser } from "@/lib/auth";
import {
  CORS_HEADERS,
  extractRawTokenFromRequest,
  getApiUser,
  jsonResponse,
  loginApiUser,
  type AuthMode,
} from "@/lib/api-auth";
import { getClientIp } from "@/lib/rate-limit";
import type { AvatarId } from "@/db/schema";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(request: Request) {
  const me = getApiUser(request);
  const all = getAllUsers();

  return jsonResponse({
    ok: true,
    serverUserCount: all.length,
    maxUsersReached: all.length >= 2,
    authenticatedUser: me
      ? {
          id: me.id,
          username: me.username,
          displayName: me.displayName || me.username,
          avatarId: me.avatarId || "cat",
          isPaired: Boolean(getPartnerUser(me.id)),
          hasPin: Boolean(me.pinHash && me.pinHash.length > 0),
          pinVersion: me.pinVersion ?? 1,
          nicknameByPartner: me.nicknameByPartner,
        }
      : null,
  });
}

export async function POST(request: Request) {
  try {
    const currentUser = getApiUser(request);
    const rawToken = extractRawTokenFromRequest(request);
    const clientIp = getClientIp(request);

    const body = (await request.json()) as {
      mode?: AuthMode;
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
      deviceId?: string;
      deviceName?: string;
    };

    const deviceId =
      request.headers.get("x-device-id")?.trim() ||
      body.deviceId?.trim() ||
      null;
    const deviceName =
      request.headers.get("x-device-name")?.trim() ||
      body.deviceName?.trim() ||
      null;

    const result = await loginApiUser({
      mode: body.mode ?? "pin_login",
      username: body.username,
      displayName: body.displayName,
      avatarId: body.avatarId,
      pin: body.pin,
      currentPin: body.currentPin,
      newPin: body.newPin,
      recoveryCode: body.recoveryCode,
      password: body.password,
      code: body.code,
      userId: body.userId,
      currentUserId: currentUser?.id,
      rawToken,
      clientIp,
      userAgent: request.headers.get("user-agent"),
      deviceId,
      deviceName,
    });

    if (!result) {
      return jsonResponse(
        {
          ok: false,
          error: "Credenciales, PIN o código no válidos.",
        },
        401,
      );
    }

    if ("loggedOut" in result) {
      return jsonResponse({ ok: true });
    }

    if ("checkedPin" in result) {
      if (!result.valid) {
        return jsonResponse(
          {
            ok: false,
            valid: false,
            error: "PIN incorrecto.",
          },
          401,
        );
      }
      return jsonResponse({
        ok: true,
        valid: true,
        pinVersion: result.user.pinVersion ?? 1,
        user: {
          id: result.user.id,
          username: result.user.username,
          displayName: result.user.displayName || result.user.username,
          pinVersion: result.user.pinVersion ?? 1,
        },
      });
    }

    const partner = getPartnerUser(result.user.id);
    const isPaired = Boolean(partner && result.user.partnerId);

    return jsonResponse({
      ok: true,
      token: result.token,
      reused: "reused" in result ? result.reused : false,
      recoveryCode: result.recoveryCode ?? null,
      isPaired,
      user: {
        id: result.user.id,
        username: result.user.username,
        displayName: result.user.displayName || result.user.username,
        avatarId: result.user.avatarId || "cat",
        isPaired,
        hasPin: Boolean(result.user.pinHash && result.user.pinHash.length > 0),
        pinVersion: result.user.pinVersion ?? 1,
        nicknameByPartner: result.user.nicknameByPartner,
        themeMode: result.user.themeMode,
        accentPalette: result.user.accentPalette,
      },
      partner: partner
        ? {
            id: partner.id,
            username: partner.username,
            displayName: partner.displayName || partner.username,
            avatarId: partner.avatarId || "rabbit",
            nicknameByPartner: partner.nicknameByPartner,
          }
        : null,
    });
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error de autenticación",
      },
      400,
    );
  }
}
