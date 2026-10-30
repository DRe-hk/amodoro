import React from "react";
import Link from "next/link";
import { getPartnerUser, requirePageUser } from "@/lib/auth";
import { getSentHomeCards } from "@/lib/home-cards";
import { FloatingHomeCard } from "@/components/home-view";

export const dynamic = "force-dynamic";

export default async function EnviadosPage() {
  const user = await requirePageUser();
  const partner = getPartnerUser(user.id);
  const partnerNickname =
    partner?.nicknameByPartner?.trim() || partner?.username || "Amor";
  const sentCards = getSentHomeCards(user.id);

  return (
    <div className="min-h-dvh bg-[var(--amodoro-bg)] text-[var(--amodoro-text)] px-4 py-5 pb-20">
      <div className="mx-auto w-full max-w-md space-y-6">
        <header className="flex items-center justify-between border-b border-black/10 pb-3">
          <div>
            <h1 className="text-base font-extrabold uppercase tracking-wider">
              🕒 Historial de enviados (YO)
            </h1>
            <p className="text-xs text-[var(--amodoro-muted)]">
              Tarjetas que le has enviado a {partnerNickname} y sus reacciones
            </p>
          </div>
          <Link
            href="/"
            className="rounded-full bg-[var(--amodoro-surface)] px-3.5 py-1.5 text-xs font-bold uppercase tracking-wider"
          >
            Volver a Home
          </Link>
        </header>

        {sentCards.length === 0 ? (
          <div className="rounded-[26px] border border-black/10 bg-[var(--amodoro-surface)] p-6 text-center space-y-3">
            <p className="text-sm font-semibold">
              Todavía no has enviado ninguna tarjeta.
            </p>
            <Link
              href="/crear"
              className="inline-block rounded-2xl bg-[#F2B8B5] px-5 py-2.5 text-xs font-bold uppercase tracking-wider text-[#410E0B]"
            >
              + Crear la primera
            </Link>
          </div>
        ) : (
          <div className="flex flex-col gap-6">
            {sentCards.map((card) => (
              <FloatingHomeCard
                key={card.id}
                card={card}
                viewerId={user.id}
                quickReplies={[]}
                allowReact={false}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
