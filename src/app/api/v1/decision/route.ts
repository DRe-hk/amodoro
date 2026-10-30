import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  getCurrentDecisionState,
  spinRouletteDecision,
  startVotingDecision,
  submitVotingRoundChoices,
} from "@/lib/decision";

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
      action: "roulette" | "start_voting" | "submit_votes";
      sessionId?: number;
      wantedItemIds?: number[];
    };

    if (payload.action === "roulette") {
      const decision = spinRouletteDecision();
      return jsonResponse({ ok: true, decision });
    }

    if (payload.action === "start_voting") {
      const decision = startVotingDecision(5);
      return jsonResponse({ ok: true, decision });
    }

    if (payload.action === "submit_votes") {
      submitVotingRoundChoices({
        sessionId: Number(payload.sessionId),
        userId: user.id,
        wantedItemIds: Array.isArray(payload.wantedItemIds)
          ? payload.wantedItemIds.map(Number)
          : [],
      });
      const decision = getCurrentDecisionState(user.id);
      return jsonResponse({ ok: true, decision });
    }

    return jsonResponse({ ok: false, error: "Acción desconocida" }, 400);
  } catch (err) {
    return jsonResponse(
      {
        ok: false,
        error: err instanceof Error ? err.message : "Error en Decision API",
      },
      400,
    );
  }
}
