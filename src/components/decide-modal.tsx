"use client";

import React, { useState } from "react";
import {
  spinRouletteAction,
  startVotingRoundAction,
  submitVotingRoundAction,
} from "@/app/actions";
import type { ActiveDecisionState } from "@/lib/decision";

export function DecideModal({
  isOpen,
  onClose,
  decision,
  partnerNickname,
  totalActivitiesCount,
}: {
  isOpen: boolean;
  onClose: () => void;
  decision: ActiveDecisionState | null;
  partnerNickname: string;
  totalActivitiesCount: number;
}) {
  const [selectedIds, setSelectedIds] = useState<number[]>(() => {
    if (!decision?.mySubmittedVotes) return [];
    return Object.entries(decision.mySubmittedVotes)
      .filter(([, want]) => want)
      .map(([id]) => Number(id));
  });
  const [spinning, setSpinning] = useState(false);

  if (!isOpen) return null;

  function toggleChoice(itemId: number) {
    setSelectedIds((prev) =>
      prev.includes(itemId)
        ? prev.filter((id) => id !== itemId)
        : [...prev, itemId],
    );
  }

  async function handleRoulette() {
    setSpinning(true);
    await spinRouletteAction();
    setTimeout(() => setSpinning(false), 450);
  }

  async function handleStartVoting() {
    setSelectedIds([]);
    await startVotingRoundAction();
  }

  return (
    <div
      data-no-pager-swipe="true"
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-3"
    >
      <div className="w-full max-w-md rounded-[28px] border border-black/10 dark:border-white/10 bg-[var(--amodoro-bg)] p-5 text-[var(--amodoro-text)] shadow-2xl max-h-[88dvh] overflow-y-auto">
        <div className="flex items-center justify-between border-b border-black/10 dark:border-white/10 pb-3">
          <div>
            <h3 className="text-base font-bold tracking-tight">
              Decidir actividad
            </h3>
            <p className="text-xs text-[var(--amodoro-muted)]">
              Elige por Ruleta al azar o Votación secreta de 4–5 opciones
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-black/5 dark:bg-white/10 text-sm font-bold"
          >
            ✕
          </button>
        </div>

        {/* Mode selector buttons: Ruleta vs Votación */}
        <div className="mt-4 grid grid-cols-2 gap-2.5">
          <button
            type="button"
            disabled={totalActivitiesCount === 0 || spinning}
            onClick={handleRoulette}
            className="flex flex-col items-start gap-1 rounded-2xl border border-[#410E0B]/15 bg-[#F2B8B5] p-3.5 text-left text-[#410E0B] shadow-xs active:scale-[0.98] transition-transform disabled:opacity-50"
          >
            <span className="text-lg">🎲</span>
            <span className="text-xs font-bold uppercase tracking-wider">
              {spinning ? "Girando..." : "Ruleta al azar"}
            </span>
            <span className="text-[11px] opacity-80">
              Elige 1 actividad directamente
            </span>
          </button>

          <button
            type="button"
            disabled={totalActivitiesCount === 0}
            onClick={handleStartVoting}
            className="flex flex-col items-start gap-1 rounded-2xl border border-[#0B3822]/15 bg-[#B8E0C8] p-3.5 text-left text-[#0B3822] shadow-xs active:scale-[0.98] transition-transform disabled:opacity-50"
          >
            <span className="text-lg">🗳️</span>
            <span className="text-xs font-bold uppercase tracking-wider">
              Votación (4–5)
            </span>
            <span className="text-[11px] opacity-80">
              Ronda ciega hasta coincidir
            </span>
          </button>
        </div>

        {/* Active or resolved decision area */}
        {decision ? (
          <div className="mt-5">
            {decision.status === "resolved" && decision.winner ? (
              <div className="rounded-3xl border border-[#0B3822]/20 bg-[#D8F3DC] p-5 text-[#102E1A] text-center space-y-2">
                <span className="inline-block rounded-full bg-[#102E1A]/10 px-3 py-0.5 text-[10px] font-bold uppercase tracking-widest">
                  {decision.mode === "roulette"
                    ? "Elegido por Ruleta 🎲"
                    : `¡Hay acuerdo en la ronda ${decision.roundNumber}! 🤝`}
                </span>
                <p className="text-2xl font-bold pt-1">
                  {decision.winner.emoji ? `${decision.winner.emoji} ` : ""}
                  {decision.winner.title}
                </p>
                {decision.winner.notes ? (
                  <p className="text-sm opacity-85">{decision.winner.notes}</p>
                ) : null}
                <p className="text-[11px] font-semibold uppercase tracking-wider opacity-70 pt-1">
                  {decision.winner.categoryTag}
                </p>
              </div>
            ) : decision.status === "voting" ? (
              <div className="space-y-3">
                <div className="flex items-center justify-between rounded-2xl bg-[var(--amodoro-surface)] px-3.5 py-2.5">
                  <div>
                    <p className="text-xs font-bold uppercase tracking-wider">
                      Ronda {decision.roundNumber} · {decision.candidates.length}{" "}
                      opciones al azar
                    </p>
                    <p className="text-[11px] text-[var(--amodoro-muted)]">
                      {decision.roundNumber > 1
                        ? "Hubo empate en la ronda anterior. ¡Votad de nuevo para desempatar!"
                        : `Marca cuáles te apetece hacer hoy. Los votos son secretos hasta que ${partnerNickname} y tú votéis.`}
                    </p>
                  </div>
                </div>

                <form action={submitVotingRoundAction} className="space-y-2.5">
                  <input type="hidden" name="sessionId" value={decision.id} />
                  <ul className="space-y-2">
                    {decision.candidates.map((cand) => {
                      const checked = selectedIds.includes(cand.id);
                      return (
                        <li key={cand.id}>
                          <label
                            onClick={() => toggleChoice(cand.id)}
                            className={[
                              "flex cursor-pointer items-center justify-between gap-3 rounded-2xl border p-3.5 transition-colors",
                              checked
                                ? "border-[#2E6244] bg-[#D8F3DC] text-[#102E1A]"
                                : "border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)]",
                            ].join(" ")}
                          >
                            <input
                              type="checkbox"
                              name="wantedItemId"
                              value={cand.id}
                              checked={checked}
                              onChange={() => {}}
                              className="sr-only"
                            />
                            <div className="min-w-0 flex-1">
                              <span className="block text-[10px] font-bold uppercase tracking-widest opacity-65">
                                {cand.categoryTag}
                              </span>
                              <span className="block text-sm font-bold">
                                {cand.emoji ? `${cand.emoji} ` : ""}
                                {cand.title}
                              </span>
                              {cand.notes ? (
                                <span className="block text-xs opacity-80 truncate">
                                  {cand.notes}
                                </span>
                              ) : null}
                            </div>
                            <span
                              className={[
                                "shrink-0 rounded-full px-3 py-1 text-xs font-bold",
                                checked
                                  ? "bg-[#102E1A] text-[#D8F3DC]"
                                  : "bg-black/10 dark:bg-white/10 text-[var(--amodoro-muted)]",
                              ].join(" ")}
                            >
                              {checked ? "¡Sí quiero! ✓" : "Hoy no"}
                            </span>
                          </label>
                        </li>
                      );
                    })}
                  </ul>

                  <div className="pt-2 flex flex-col gap-2">
                    <button
                      type="submit"
                      className="w-full rounded-2xl bg-[#B8E0C8] py-3 text-xs font-bold uppercase tracking-widest text-[#0B3822] shadow-sm active:scale-[0.99]"
                    >
                      {decision.mySubmittedVotes
                        ? "Actualizar mi voto secreto"
                        : "Enviar mi voto secreto"}
                    </button>

                    {decision.mySubmittedVotes && !decision.partnerHasVoted ? (
                      <p className="text-center text-xs font-medium text-[var(--amodoro-muted)]">
                        Ya votaste en esta ronda · Esperando el voto de{" "}
                        <strong>{partnerNickname}</strong> (sin mostrar
                        resultados parciales).
                      </p>
                    ) : null}
                  </div>
                </form>
              </div>
            ) : null}
          </div>
        ) : null}
      </div>
    </div>
  );
}
