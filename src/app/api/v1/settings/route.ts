import { createInviteForUser, updateUserSettings } from "@/lib/auth";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import type { AccentPalette, ThemeMode } from "@/db/schema";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function POST(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  try {
    const payload = (await request.json()) as {
      action: "update_settings" | "create_invite";
      partnerNickname?: string;
      themeMode?: ThemeMode;
      accentPalette?: AccentPalette;
      quickReplies?: string[];
    };

    if (payload.action === "update_settings") {
      updateUserSettings({
        userId: user.id,
        partnerNickname: payload.partnerNickname,
        themeMode: payload.themeMode,
        accentPalette: payload.accentPalette,
        quickReplies: payload.quickReplies,
      });
      return jsonResponse({ ok: true });
    }

    if (payload.action === "create_invite") {
      const invite = createInviteForUser(user.id);
      return jsonResponse({
        ok: true,
        code: invite.code,
        token: invite.token,
        expiresAt: invite.expiresAt,
      });
    }

    return jsonResponse({ ok: false, error: "Acción desconocida" }, 400);
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error en Settings API",
      },
      400,
    );
  }
}
