import {
  createInviteForUser,
  getPartnerUser,
  updateUserFcmToken,
  updateUserSettings,
} from "@/lib/auth";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { listBoardsWithItems, listCompletedBoardItems } from "@/lib/boards";
import { getReceivedHomeCards, getSentHomeCards } from "@/lib/home-cards";
import type { AccentPalette, AvatarId, ThemeMode } from "@/db/schema";

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
      action:
        | "update_settings"
        | "create_invite"
        | "register_fcm_token"
        | "generate_partner_pin_reset"
        | "export_data";
      displayName?: string;
      avatarId?: AvatarId;
      partnerNickname?: string;
      themeMode?: ThemeMode;
      accentPalette?: AccentPalette;
      quickReplies?: string[];
      reactionEmojis?: string[];
      fcmToken?: string | null;
    };

    if (payload.action === "update_settings") {
      updateUserSettings({
        userId: user.id,
        displayName: payload.displayName,
        avatarId: payload.avatarId,
        partnerNickname: payload.partnerNickname,
        themeMode: payload.themeMode,
        accentPalette: payload.accentPalette,
        quickReplies: payload.quickReplies,
        reactionEmojis: payload.reactionEmojis,
      });
      return jsonResponse({ ok: true });
    }

    if (
      payload.action === "create_invite" ||
      payload.action === "generate_partner_pin_reset"
    ) {
      const invite = createInviteForUser(user.id);
      return jsonResponse({
        ok: true,
        code: invite.code,
        token: invite.token,
        expiresAt: invite.expiresAt,
      });
    }

    if (payload.action === "register_fcm_token") {
      updateUserFcmToken(user.id, payload.fcmToken ?? null);
      return jsonResponse({ ok: true });
    }

    if (payload.action === "export_data") {
      const partner = getPartnerUser(user.id);
      const { latest, history } = getReceivedHomeCards(user.id, { limit: 200 });
      const sentCards = getSentHomeCards(user.id, { limit: 200 });
      const { boards, itemsByBoardId } = listBoardsWithItems(user.id);
      const completedHistory = listCompletedBoardItems(user.id);

      return jsonResponse({
        ok: true,
        exportedAt: new Date().toISOString(),
        exportData: {
          profile: {
            id: user.id,
            username: user.username,
            displayName: user.displayName,
            avatarId: user.avatarId,
            nicknameByPartner: user.nicknameByPartner,
            partnerDisplayName: partner?.displayName ?? null,
          },
          receivedCards: [...(latest ? [latest] : []), ...history],
          sentCards,
          boards,
          itemsByBoardId,
          completedHistory,
        },
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
