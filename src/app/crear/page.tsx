import React from "react";
import Link from "next/link";
import { getPartnerUser, requirePageUser } from "@/lib/auth";
import { CardComposer } from "@/components/card-composer";

export const dynamic = "force-dynamic";

export default async function CrearTarjetaPage() {
  const user = await requirePageUser();
  const partner = getPartnerUser(user.id);
  const partnerNickname =
    partner?.nicknameByPartner?.trim() || partner?.username || "Amor";

  return (
    <div className="min-h-dvh bg-[var(--amodoro-bg)] text-[var(--amodoro-text)] px-4 py-5">
      <div className="mx-auto w-full max-w-md space-y-5">
        <header className="flex items-center justify-between border-b border-black/10 pb-3">
          <div>
            <h1 className="text-base font-extrabold uppercase tracking-wider">
              Crear mensaje para {partnerNickname}
            </h1>
            <p className="text-xs text-[var(--amodoro-muted)]">
              Elige texto, foto o dibujo y personaliza los colores pastel
            </p>
          </div>
          <Link
            href="/"
            className="rounded-full bg-[var(--amodoro-surface)] px-3.5 py-1.5 text-xs font-bold uppercase tracking-wider"
          >
            Volver
          </Link>
        </header>

        <CardComposer partnerNickname={partnerNickname} />
      </div>
    </div>
  );
}
