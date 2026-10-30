import { getPartnerUser } from "@/lib/auth";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { listBoardsWithItems } from "@/lib/boards";
import { getCurrentDecisionState } from "@/lib/decision";
import { getReceivedHomeCards, getSentHomeCards } from "@/lib/home-cards";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  const partner = getPartnerUser(user.id);
  const { latest, history } = getReceivedHomeCards(user.id);
  const sentHistory = getSentHomeCards(user.id);
  const { boards, itemsByBoardId, actividadesBoardId } = listBoardsWithItems();
  const decision = getCurrentDecisionState(user.id);

  let quickReplies: string[] = [
    "Te amo ❤️",
    "Me alegraste el día ✨",
    "Qué bonito 🥺",
    "Te extraño mucho 💌",
    "Me sacaste una sonrisa 🥰",
  ];
  try {
    const parsed = JSON.parse(user.quickRepliesJson);
    if (Array.isArray(parsed) && parsed.length > 0) {
      quickReplies = parsed;
    }
  } catch {
    // keep default
  }

  return jsonResponse({
    ok: true,
    me: {
      id: user.id,
      username: user.username,
      nicknameByPartner: user.nicknameByPartner,
      themeMode: user.themeMode,
      accentPalette: user.accentPalette,
      quickReplies,
    },
    partner: partner
      ? {
          id: partner.id,
          username: partner.username,
          nicknameByPartner: partner.nicknameByPartner,
        }
      : {
          id: -1,
          username: "pareja",
          nicknameByPartner: "Amor",
        },
    home: {
      latestReceived: latest,
      historyReceived: history,
      sentHistory,
    },
    boards: {
      boards,
      itemsByBoardId,
      actividadesBoardId,
    },
    decision,
  });
}
