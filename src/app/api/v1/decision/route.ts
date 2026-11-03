import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  getCurrentDecisionState,
  spinRouletteDecision,
  startVotingDecision,
  submitVotingRoundChoices,
} from "@/lib/decision";
import { sendPushToPartner } from "@/lib/push";

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
      sessionId?: number | string;
      wantedItemIds?: (number | string)[];
      votes?: Record<string, boolean>;
    };

    if (payload.action === "roulette") {
      const decision = spinRouletteDecision();
      if (decision?.winner) {
        void sendPushToPartner(user.id, {
          title: "¡La Ruleta decidió! 🎲",
          body: decision.winner.title,
          data: { type: "decision_resolved", sessionId: String(decision.id) },
        });
      }
      return jsonResponse({
        ok: true,
        decision,
        result: { status: "resolved", decision },
      });
    }

    if (payload.action === "start_voting") {
      const decision = startVotingDecision(5);
      if (decision) {
        void sendPushToPartner(user.id, {
          title: "¡Votación secreta activa! 🗳️",
          body: "Elige tus actividades favoritas para hoy.",
          data: { type: "decision_voting", sessionId: String(decision.id) },
        });
      }
      return jsonResponse({
        ok: true,
        decision,
        result: { status: "voting", decision },
      });
    }

    if (payload.action === "submit_votes") {
      let wantedIds: number[] = [];
      if (Array.isArray(payload.wantedItemIds)) {
        wantedIds = payload.wantedItemIds.map(Number);
      } else if (payload.votes && typeof payload.votes === "object") {
        wantedIds = Object.entries(payload.votes)
          .filter(([, want]) => Boolean(want))
          .map(([id]) => Number(id));
      }

      const prevState = getCurrentDecisionState(user.id);
      const prevRound = prevState?.roundNumber ?? 1;

      submitVotingRoundChoices({
        sessionId: Number(payload.sessionId),
        userId: user.id,
        wantedItemIds: wantedIds,
      });

      const decision = getCurrentDecisionState(user.id);
      const status =
        decision?.status === "resolved"
          ? "resolved"
          : (decision?.roundNumber ?? 1) > prevRound
            ? "tie_next_round"
            : "waiting_partner";

      if (status === "resolved" && decision?.winner) {
        void sendPushToPartner(user.id, {
          title: "¡Hay acuerdo! 🎉",
          body: decision.winner.title,
          data: { type: "decision_resolved", sessionId: String(decision.id) },
        });
      }

      return jsonResponse({
        ok: true,
        decision,
        result: { status, decision },
      });
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
