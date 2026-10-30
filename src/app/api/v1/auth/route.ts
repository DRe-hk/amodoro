import { getAllUsers, getPartnerUser } from "@/lib/auth";
import {
  CORS_HEADERS,
  getApiUser,
  jsonResponse,
  loginApiUser,
} from "@/lib/api-auth";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(request: Request) {
  const me = getApiUser(request);
  const profiles = getAllUsers().map((u) => ({
    id: u.id,
    username: u.username,
    nicknameByPartner: u.nicknameByPartner,
  }));

  return jsonResponse({
    ok: true,
    authenticatedUser: me
      ? {
          id: me.id,
          username: me.username,
          nicknameByPartner: me.nicknameByPartner,
        }
      : null,
    profiles,
  });
}

export async function POST(request: Request) {
  try {
    const body = (await request.json()) as {
      mode?: "password" | "code" | "quick";
      username?: string;
      password?: string;
      code?: string;
      userId?: number;
    };

    const result = await loginApiUser({
      mode: body.mode ?? "password",
      username: body.username,
      password: body.password,
      code: body.code,
      userId: body.userId,
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

    return jsonResponse({
      ok: true,
      token: result.token,
      user: {
        id: result.user.id,
        username: result.user.username,
        nicknameByPartner: result.user.nicknameByPartner,
        themeMode: result.user.themeMode,
        accentPalette: result.user.accentPalette,
      },
      partner: partner
        ? {
            id: partner.id,
            username: partner.username,
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
