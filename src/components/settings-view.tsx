"use client";

import React, { useState } from "react";
import {
  generateInviteAction,
  logoutAction,
  saveSettingsAction,
} from "@/app/actions";
import { ACCENT_PALETTES, type AccentPaletteId } from "@/lib/contrast";
import type { ThemeMode } from "@/db/schema";

const PALETTE_OPTIONS: {
  id: AccentPaletteId;
  title: string;
  subtitle: string;
}[] = [
  {
    id: "fig-sage",
    title: "Higuera y Salvia (Propuesta 1)",
    subtitle: "Rojo higo pastel · Verde salvia · Ámbar higo",
  },
  {
    id: "cherry-eucalyptus",
    title: "Cereza y Eucalipto (Propuesta 2)",
    subtitle: "Rojo cereza · Verde eucalipto · Malva tierra",
  },
  {
    id: "camellia-olive",
    title: "Camelia y Olivo (Propuesta 3)",
    subtitle: "Rojo camelia · Verde olivo · Pino suave",
  },
];

export function SettingsView({
  myUsername,
  myNicknameGivenByPartner,
  partnerUsername,
  partnerNicknameGivenByMe,
  themeMode,
  accentPalette,
  quickReplies,
}: {
  myUsername: string;
  myNicknameGivenByPartner: string;
  partnerUsername: string;
  partnerNicknameGivenByMe: string;
  themeMode: ThemeMode;
  accentPalette: AccentPaletteId;
  quickReplies: string[];
}) {
  const [savedBanner, setSavedBanner] = useState(false);
  const [inviteData, setInviteData] = useState<{
    code: string;
    token: string;
  } | null>(null);

  return (
    <div className="flex flex-col gap-5">
      {/* Section 1: Crossed Nicknames (Apodo que me puso mi pareja + Apodo que le pongo yo + Regla YO) */}
      <section className="rounded-[26px] border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] p-5 space-y-4">
        <div>
          <h2 className="text-sm font-bold uppercase tracking-wider">
            Apodos en Amodoro
          </h2>
          <p className="mt-0.5 text-xs text-[var(--amodoro-muted)]">
            Cada uno elige el apodo de la otra persona. Para ti mismo, tus
            mensajes siempre muestran <strong>YO</strong>.
          </p>
        </div>

        {/* Display the nickname your partner gave YOU */}
        <div className="rounded-2xl border border-[#410E0B]/15 bg-[#F2B8B5]/45 p-3.5">
          <span className="block text-[10px] font-bold uppercase tracking-widest opacity-75">
            El apodo que te puso tu pareja (@{partnerUsername})
          </span>
          <div className="mt-1 flex items-baseline justify-between">
            <span className="text-xl font-extrabold tracking-tight">
              {myNicknameGivenByPartner}
            </span>
            <span className="text-[11px] font-medium opacity-75">
              Para ti aparece como: <strong>YO</strong>
            </span>
          </div>
        </div>

        <form
          action={async (fd) => {
            await saveSettingsAction(fd);
            setSavedBanner(true);
            setTimeout(() => setSavedBanner(false), 2000);
          }}
          className="space-y-4"
        >
          <div>
            <label className="block text-xs font-bold uppercase tracking-wider mb-1.5">
              Apodo que tú le pones a tu pareja (@{partnerUsername})
            </label>
            <input
              type="text"
              name="partnerNickname"
              defaultValue={partnerNicknameGivenByMe}
              maxLength={40}
              className="w-full rounded-2xl border border-black/15 dark:border-white/15 bg-[var(--amodoro-bg)] px-4 py-2.5 text-sm font-bold"
            />
          </div>

          {/* Section 2: Theme Mode (Claro / Oscuro / Sistema) */}
          <div className="pt-2 border-t border-black/10 dark:border-white/10">
            <label className="block text-xs font-bold uppercase tracking-wider mb-2">
              Tema de la aplicación
            </label>
            <div className="grid grid-cols-3 gap-2">
              {(
                [
                  { id: "light", label: "☀️ Claro" },
                  { id: "dark", label: "🌙 Oscuro" },
                  { id: "system", label: "⚙️ Auto" },
                ] as const
              ).map((t) => (
                <label
                  key={t.id}
                  className="flex cursor-pointer items-center justify-center gap-1.5 rounded-2xl border border-black/12 dark:border-white/12 bg-[var(--amodoro-bg)] py-2.5 px-3 text-xs font-bold has-[:checked]:border-2 has-[:checked]:border-[var(--amodoro-text)]"
                >
                  <input
                    type="radio"
                    name="themeMode"
                    value={t.id}
                    defaultChecked={themeMode === t.id}
                    className="sr-only"
                  />
                  <span>{t.label}</span>
                </label>
              ))}
            </div>
          </div>

          {/* Section 3: Accent Palette (Red + Green M3 harmonies) */}
          <div className="pt-2 border-t border-black/10 dark:border-white/10">
            <label className="block text-xs font-bold uppercase tracking-wider mb-2">
              Color de acento (Indicadores Rojo + Verde)
            </label>
            <div className="space-y-2">
              {PALETTE_OPTIONS.map((opt) => {
                const pal = ACCENT_PALETTES[opt.id].light.pills;
                return (
                  <label
                    key={opt.id}
                    className="flex cursor-pointer items-center justify-between gap-3 rounded-2xl border border-black/12 dark:border-white/12 bg-[var(--amodoro-bg)] p-3 has-[:checked]:border-2 has-[:checked]:border-[var(--amodoro-text)]"
                  >
                    <input
                      type="radio"
                      name="accentPalette"
                      value={opt.id}
                      defaultChecked={accentPalette === opt.id}
                      className="sr-only"
                    />
                    <div className="min-w-0">
                      <span className="block text-xs font-bold">
                        {opt.title}
                      </span>
                      <span className="block text-[11px] text-[var(--amodoro-muted)]">
                        {opt.subtitle}
                      </span>
                    </div>
                    <div className="flex items-center gap-1 shrink-0">
                      <span
                        style={{ backgroundColor: pal.home.bg }}
                        className="h-4 w-6 rounded-full border border-black/10"
                      />
                      <span
                        style={{ backgroundColor: pal.boards.bg }}
                        className="h-4 w-6 rounded-full border border-black/10"
                      />
                      <span
                        style={{ backgroundColor: pal.settings.bg }}
                        className="h-4 w-6 rounded-full border border-black/10"
                      />
                    </div>
                  </label>
                );
              })}
            </div>
          </div>

          {/* Section 4: Predefined Quick Replies for Home cards */}
          <div className="pt-2 border-t border-black/10 dark:border-white/10">
            <label className="block text-xs font-bold uppercase tracking-wider mb-1">
              Textos predefinidos de reacción en Home
            </label>
            <p className="text-[11px] text-[var(--amodoro-muted)] mb-2">
              Uno por línea (soportan emojis). Aparecen debajo de cada tarjeta
              recibida.
            </p>
            <textarea
              name="quickReplies"
              rows={4}
              defaultValue={quickReplies.join("\n")}
              className="w-full rounded-2xl border border-black/15 dark:border-white/15 bg-[var(--amodoro-bg)] p-3 text-xs font-medium"
            />
          </div>

          <button
            type="submit"
            className="w-full rounded-2xl bg-[#E6CBA8] py-3.5 text-xs font-bold uppercase tracking-widest text-[#3B260B] shadow-sm active:scale-[0.99] transition-transform"
          >
            {savedBanner ? "✓ Ajustes guardados" : "Guardar ajustes"}
          </button>
        </form>
      </section>

      {/* Section 5: Distance Invite Link & Code Generator + Account */}
      <section className="rounded-[26px] border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] p-5 space-y-3">
        <div>
          <h3 className="text-xs font-bold uppercase tracking-wider">
            Acceso a distancia (Código o Enlace directo)
          </h3>
          <p className="text-[11px] text-[var(--amodoro-muted)]">
            Genera un código corto o link para abrir tu cuenta (@{myUsername})
            en el móvil sin escribir contraseñas.
          </p>
        </div>

        <button
          type="button"
          onClick={async () => {
            const res = await generateInviteAction();
            setInviteData(res);
          }}
          className="w-full rounded-2xl border border-black/15 dark:border-white/15 bg-[var(--amodoro-bg)] py-2.5 text-xs font-bold uppercase tracking-wider"
        >
          Generar código y enlace de acceso
        </button>

        {inviteData ? (
          <div className="rounded-2xl bg-[var(--amodoro-bg)] p-3.5 space-y-1.5 border border-black/10">
            <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)]">
              Código corto (válido 7 días):
            </p>
            <p className="font-mono text-lg font-bold tracking-widest">
              {inviteData.code}
            </p>
            <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)] pt-1">
              Enlace directo:
            </p>
            <p className="font-mono text-xs break-all select-all">
              /entrar/{inviteData.token}
            </p>
          </div>
        ) : null}

        <form action={logoutAction} className="pt-2">
          <button
            type="submit"
            className="w-full rounded-2xl border border-red-800/20 py-2.5 text-xs font-bold uppercase tracking-wider text-red-700 dark:text-red-300"
          >
            Cambiar de usuario / Cerrar sesión (@{myUsername})
          </button>
        </form>
      </section>
    </div>
  );
}
