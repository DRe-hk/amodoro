"use client";

import React from "react";
import Link from "next/link";
import { reactToCardAction } from "@/app/actions";
import { getContrastingInk } from "@/lib/contrast";
import { formatAuthorLabel, formatSpanishDateHeader } from "@/lib/identity";
import type { HydratedHomeCard } from "@/lib/home-cards";
import type { CardFont, CardFontSize } from "@/db/schema";

const QUICK_EMOJIS = ["❤️", "🥹", "✨", "🥰", "😂", "🔥"];

const FONT_CLASS: Record<CardFont, string> = {
  sans: "font-card-sans",
  serif: "font-card-serif",
  hand: "font-card-hand",
  mono: "font-card-mono",
};

const SIZE_CLASS: Record<CardFontSize, string> = {
  sm: "text-[15px] leading-relaxed",
  md: "text-[17px] leading-relaxed",
  lg: "text-[20px] leading-snug",
  xl: "text-[24px] leading-snug font-medium",
};

export function FloatingHomeCard({
  card,
  viewerId,
  quickReplies,
  allowReact = true,
}: {
  card: HydratedHomeCard;
  viewerId: number;
  quickReplies: string[];
  allowReact?: boolean;
}) {
  const ink = getContrastingInk(card.bgColor);
  const authorLabel = formatAuthorLabel({
    authorId: card.authorId,
    viewerId,
    authorNicknameGivenByPartner: card.authorNicknameByPartner,
    authorUsername: card.authorUsername,
  });
  const dateHeader = formatSpanishDateHeader(new Date(card.createdAt));

  return (
    <article className="flex flex-col gap-2.5">
      {/* Header matching the sketch: APODO on the left, date underneath */}
      <div className="flex items-baseline justify-between px-1">
        <div>
          <h2 className="text-lg font-bold tracking-tight text-[var(--amodoro-text)]">
            {authorLabel}
          </h2>
          <p className="text-[11px] font-semibold tracking-[0.08em] uppercase text-[var(--amodoro-muted)]">
            {dateHeader}
          </p>
        </div>
        <span className="text-xs font-medium text-[var(--amodoro-muted)]">
          @{card.authorUsername}
        </span>
      </div>

      {/* Rounded floating card with pastel background & auto-contrasting text */}
      <div
        style={{
          backgroundColor: card.bgColor,
          color: ink.text,
          borderColor: ink.border,
        }}
        className="m3-floating-card rounded-[28px] border p-4 sm:p-5 transition-all"
      >
        {/* Optional top photo/drawing area — omitted cleanly when text-only */}
        {card.mediaId ? (
          <div
            style={{ borderColor: ink.border }}
            className="mb-4 overflow-hidden rounded-[20px] border bg-white/60"
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={`/api/media/${card.mediaId}`}
              alt="Imagen o dibujo del mensaje"
              className="max-h-[340px] w-full object-cover"
              loading="lazy"
            />
          </div>
        ) : null}

        {/* Card message text */}
        {card.body ? (
          <p
            className={[
              FONT_CLASS[card.fontFamily] ?? "font-card-sans",
              SIZE_CLASS[card.fontSize] ?? "text-[17px]",
              "whitespace-pre-wrap break-words py-1",
            ].join(" ")}
          >
            {card.body}
          </p>
        ) : null}

        {/* Existing reactions badge strip */}
        {card.reactions.length > 0 ? (
          <div
            style={{ borderColor: ink.border }}
            className="mt-4 flex flex-wrap items-center gap-1.5 border-t pt-3"
          >
            {card.reactions.map((rx) => (
              <span
                key={rx.id}
                style={{
                  backgroundColor: ink.chipBg,
                  color: ink.text,
                  borderColor: ink.border,
                }}
                className="inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-semibold"
              >
                {rx.emoji ? <span className="text-sm">{rx.emoji}</span> : null}
                {rx.presetText ? <span>{rx.presetText}</span> : null}
              </span>
            ))}
          </div>
        ) : null}

        {/* Reaction controls (emojis + predefined text replies) */}
        {allowReact ? (
          <div
            style={{ borderColor: ink.border }}
            className="mt-4 border-t pt-3 space-y-2.5"
          >
            {/* Quick emoji reactions */}
            <div className="flex items-center justify-between gap-1">
              <span
                style={{ color: ink.muted }}
                className="text-[11px] font-semibold uppercase tracking-wider"
              >
                Reaccionar
              </span>
              <div className="flex items-center gap-1">
                {QUICK_EMOJIS.map((emoji) => (
                  <form key={emoji} action={reactToCardAction}>
                    <input type="hidden" name="cardId" value={card.id} />
                    <input type="hidden" name="emoji" value={emoji} />
                    <button
                      type="submit"
                      style={{ backgroundColor: ink.chipBg }}
                      className="flex h-8 w-8 items-center justify-center rounded-full text-base active:scale-90 transition-transform hover:opacity-90"
                      title={`Reaccionar con ${emoji}`}
                    >
                      {emoji}
                    </button>
                  </form>
                ))}
              </div>
            </div>

            {/* Predefined text replies */}
            <div
              data-no-pager-swipe="true"
              className="flex items-center gap-1.5 overflow-x-auto no-scrollbar pb-0.5"
            >
              {quickReplies.map((replyText) => (
                <form key={replyText} action={reactToCardAction} className="shrink-0">
                  <input type="hidden" name="cardId" value={card.id} />
                  <input type="hidden" name="presetText" value={replyText} />
                  <button
                    type="submit"
                    style={{
                      backgroundColor: ink.chipBg,
                      color: ink.text,
                      borderColor: ink.border,
                    }}
                    className="rounded-full border px-3 py-1 text-xs font-medium whitespace-nowrap active:scale-95 transition-transform"
                  >
                    {replyText}
                  </button>
                </form>
              ))}
            </div>
          </div>
        ) : null}
      </div>
    </article>
  );
}

export function HomeView({
  viewerId,
  partnerNickname,
  latestReceived,
  historyReceived,
  quickReplies,
}: {
  viewerId: number;
  partnerNickname: string;
  latestReceived: HydratedHomeCard | null;
  historyReceived: HydratedHomeCard[];
  quickReplies: string[];
}) {
  return (
    <div className="flex flex-col gap-7">
      {/* Main section: Latest welcome / daily card from partner */}
      {latestReceived ? (
        <FloatingHomeCard
          card={latestReceived}
          viewerId={viewerId}
          quickReplies={quickReplies}
          allowReact
        />
      ) : (
        <div className="m3-floating-card rounded-[28px] border border-black/10 bg-[#FADADD] p-6 text-[#3B1219]">
          <p className="text-xs font-bold uppercase tracking-widest opacity-75">
            Bienvenida de {partnerNickname}
          </p>
          <p className="mt-2 font-card-serif text-xl">
            Todavía no hay tarjetas recibidas hoy. ¡Envíale una sorpresa con el
            botón + CREAR! ✨
          </p>
        </div>
      )}

      {/* History of received messages on previous days */}
      {historyReceived.length > 0 ? (
        <section className="border-t border-black/10 dark:border-white/10 pt-5 space-y-6">
          <div className="flex items-center justify-between px-1">
            <h3 className="text-xs font-bold uppercase tracking-[0.12em] text-[var(--amodoro-muted)]">
              Días anteriores
            </h3>
            <span className="text-xs text-[var(--amodoro-muted)]">
              {historyReceived.length}{" "}
              {historyReceived.length === 1 ? "mensaje" : "mensajes"}
            </span>
          </div>

          <div className="flex flex-col gap-6">
            {historyReceived.map((card) => (
              <FloatingHomeCard
                key={card.id}
                card={card}
                viewerId={viewerId}
                quickReplies={quickReplies}
                allowReact
              />
            ))}
          </div>
        </section>
      ) : null}

      {/* Bottom Sticky Action Row in Home: [🕒 ENVIADOS] and [+ CREAR] matching sketch */}
      <div className="fixed bottom-4 inset-x-0 z-30 pointer-events-none px-4">
        <div className="mx-auto flex w-full max-w-md items-center gap-3 pointer-events-auto">
          <Link
            href="/enviados"
            className="flex-1 flex items-center justify-center gap-2 rounded-2xl border border-black/15 dark:border-white/15 bg-[var(--amodoro-surface)]/95 backdrop-blur-md py-3.5 px-4 text-xs font-bold uppercase tracking-[0.1em] text-[var(--amodoro-text)] shadow-md active:scale-[0.98] transition-transform"
          >
            <svg
              className="h-4 w-4 shrink-0"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <circle cx="12" cy="12" r="9" />
              <polyline points="12 7 12 12 15 15" />
            </svg>
            <span>Enviados</span>
          </Link>

          <Link
            href="/crear"
            className="flex-1 flex items-center justify-center gap-1.5 rounded-2xl bg-[#F2B8B5] text-[#410E0B] border border-[#410E0B]/15 py-3.5 px-4 text-xs font-bold uppercase tracking-[0.1em] shadow-md active:scale-[0.98] transition-transform"
          >
            <span className="text-base leading-none">+</span>
            <span>Crear</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
