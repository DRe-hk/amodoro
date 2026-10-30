import { getAllUsers, getPartnerUser } from "@/lib/auth";
import {
  CORS_HEADERS,
  getApiUser,
  jsonResponse,
  loginApiUser,
} from "@/lib/api-auth";
import type { AvatarId } from "@/db/schema";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(request: Request) {
  const me = getApiUser(request);
  const profiles = getAllUsers().map((u) => ({
    id: u.id,
    username: u.username,
    displayName: u.displayName || u.username,
    avatarId: u.avatarId || "cat",
    nicknameByPartner: u.nicknameByPartner || u.displayName || u.username,
  }));

  return jsonResponse({
    ok: true,
    authenticatedUser: me
      ? {
          id: me.id,
          username: me.username,
          displayName: me.displayName || me.username,
          avatarId: me.avatarId || "cat",
          isPaired: Boolean(getPartnerUser(me.id)),
          nicknameByPartner: me.nicknameByPartner,
        }
      : null,
    profiles,
  });
}

export async function POST(request: Request) {
  try {
    const currentUser = getApiUser(request);
    const body = (await request.json()) as {
      mode?: "password" | "code" | "quick" | "register" | "pair";
      username?: string;
      displayName?: string;
      avatarId?: AvatarId;
      password?: string;
      code?: string;
      userId?: number;
    };

    const result = await loginApiUser({
      mode: body.mode ?? "password",
      username: body.username,
      displayName: body.displayName,
      avatarId: body.avatarId,
      password: body.password,
      code: body.code,
      userId: body.userId,
      currentUserId: currentUser?.id,
      userAgent: request.headers.get("user-agent"),
    });

    if (!result) {
      return jsonResponse(
        {
          ok: false,
          error: "Credenciales o código no válidos.",
        },
        401,
      );
    }

    const partner = getPartnerUser(result.user.id);
    const isPaired = Boolean(partner && result.user.partnerId);

    return jsonResponse({
      ok: true,
      token: result.token,
      isPaired,
      user: {
        id: result.user.id,
        username: result.user.username,
        displayName: result.user.displayName || result.user.username,
        avatarId: result.user.avatarId || "cat",
        isPaired,
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
