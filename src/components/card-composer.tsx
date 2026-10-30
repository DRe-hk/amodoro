"use client";

import React, { useState } from "react";
import Link from "next/link";
import { createHomeCardAction } from "@/app/actions";
import { DrawCanvas } from "./draw-canvas";
import { EmojiBar } from "./emoji-bar";
import { getContrastingInk, HOME_CARD_PASTELS } from "@/lib/contrast";
import type { CardFont, CardFontSize } from "@/db/schema";

const FONT_OPTIONS: { id: CardFont; label: string; className: string }[] = [
  { id: "sans", label: "Sans", className: "font-card-sans" },
  { id: "serif", label: "Editorial", className: "font-card-serif" },
  { id: "hand", label: "Manuscrita", className: "font-card-hand" },
  { id: "mono", label: "Máquina", className: "font-card-mono" },
];

const SIZE_OPTIONS: { id: CardFontSize; label: string; className: string }[] = [
  { id: "sm", label: "S", className: "text-[15px] leading-relaxed" },
  { id: "md", label: "M", className: "text-[17px] leading-relaxed" },
  { id: "lg", label: "L", className: "text-[20px] leading-snug" },
  { id: "xl", label: "XL", className: "text-[24px] leading-snug font-medium" },
];

export function CardComposer({ partnerNickname }: { partnerNickname: string }) {
  const [mediaMode, setMediaMode] = useState<"none" | "photo" | "drawing">(
    "none",
  );
  const [bgColor, setBgColor] = useState<string>(HOME_CARD_PASTELS[0]!.lightBg);
  const [fontFamily, setFontFamily] = useState<CardFont>("sans");
  const [fontSize, setFontSize] = useState<CardFontSize>("lg");
  const [body, setBody] = useState<string>("");
  const [drawingDataUrl, setDrawingDataUrl] = useState<string | null>(null);
  const [photoPreviewUrl, setPhotoPreviewUrl] = useState<string | null>(null);

  const ink = getContrastingInk(bgColor);
  const fontClass =
    FONT_OPTIONS.find((f) => f.id === fontFamily)?.className ??
    "font-card-sans";
  const sizeClass =
    SIZE_OPTIONS.find((s) => s.id === fontSize)?.className ?? "text-[17px]";

  function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) {
      setPhotoPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPhotoPreviewUrl(url);
  }

  return (
    <form action={createHomeCardAction} className="space-y-6">
      <input type="hidden" name="mediaMode" value={mediaMode} />
      <input type="hidden" name="bgColor" value={bgColor} />
      <input type="hidden" name="fontFamily" value={fontFamily} />
      <input type="hidden" name="fontSize" value={fontSize} />
      <input
        type="hidden"
        name="drawingDataUrl"
        value={drawingDataUrl ?? ""}
      />

      {/* Top Mode Switcher: Solo texto | Foto | Dibujo */}
      <div className="grid grid-cols-3 gap-2 rounded-2xl bg-[var(--amodoro-surface)] p-1.5">
        {(
          [
            { id: "none", label: "Solo texto" },
            { id: "photo", label: "📷 Foto" },
            { id: "drawing", label: "🎨 Dibujo" },
          ] as const
        ).map((m) => {
          const active = mediaMode === m.id;
          return (
            <button
              key={m.id}
              type="button"
              onClick={() => setMediaMode(m.id)}
              className={[
                "rounded-xl py-2 text-xs font-bold uppercase tracking-wider transition-all",
                active
                  ? "bg-[#F2B8B5] text-[#410E0B] shadow-xs"
                  : "text-[var(--amodoro-muted)] hover:text-[var(--amodoro-text)]",
              ].join(" ")}
            >
              {m.label}
            </button>
          );
        })}
      </div>

      {/* Live Floating Card Preview (matches the 3rd screen of the sketch) */}
      <div className="space-y-2">
        <div className="flex items-baseline justify-between px-1">
          <span className="text-xs font-bold uppercase tracking-wider text-[var(--amodoro-muted)]">
            Vista previa · Para {partnerNickname} (Tú ves: YO)
          </span>
          <span className="text-[11px] text-[var(--amodoro-muted)]">
            Contraste automático
          </span>
        </div>

        <div
          style={{
            backgroundColor: bgColor,
            color: ink.text,
            borderColor: ink.border,
          }}
          className="m3-floating-card rounded-[28px] border p-5 transition-colors duration-200 space-y-4"
        >
          {/* Optional Top Media Area */}
          {mediaMode === "photo" ? (
            <div
              style={{ borderColor: ink.border }}
              className="overflow-hidden rounded-[20px] border bg-white/50 p-3 text-center"
            >
              {photoPreviewUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={photoPreviewUrl}
                  alt="Vista previa"
                  className="mx-auto max-h-[280px] w-full rounded-2xl object-cover mb-2"
                />
              ) : null}
              <label
                style={{
                  backgroundColor: ink.chipBg,
                  color: ink.text,
                  borderColor: ink.border,
                }}
                className="inline-flex cursor-pointer items-center gap-2 rounded-full border px-4 py-2 text-xs font-bold uppercase tracking-wider"
              >
                <span>
                  {photoPreviewUrl ? "Cambiar foto" : "Seleccionar foto"}
                </span>
                <input
                  type="file"
                  name="photo"
                  accept="image/jpeg,image/png,image/webp,image/gif"
                  onChange={handlePhotoChange}
                  className="sr-only"
                />
              </label>
            </div>
          ) : null}

          {mediaMode === "drawing" ? (
            <div className="rounded-[20px] bg-white/80 p-2.5 text-[#1F1B18]">
              <DrawCanvas onChangeDataUrl={setDrawingDataUrl} />
            </div>
          ) : null}

          {/* Message text area directly on the pastel card with auto-contrasting ink */}
          <textarea
            name="body"
            rows={mediaMode === "none" ? 5 : 3}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder="Escribe tu mensaje de bienvenida para hoy... (puedes usar emojis ✨❤️)"
            style={{
              color: ink.text,
            }}
            className={[
              fontClass,
              sizeClass,
              "w-full resize-none bg-transparent placeholder:opacity-50 focus:outline-none",
            ].join(" ")}
          />
        </div>
      </div>

      {/* Quick Emoji insertion bar */}
      <div className="rounded-2xl bg-[var(--amodoro-surface)] p-3">
        <EmojiBar
          label="Añadir emoji al mensaje"
          onSelect={(emoji) => setBody((prev) => `${prev}${emoji}`)}
        />
      </div>

      {/* Material Design 3 Pastel Background Color Picker */}
      <div className="rounded-2xl bg-[var(--amodoro-surface)] p-4 space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-xs font-bold uppercase tracking-wider">
            Color de fondo (Pastel M3)
          </span>
          <input
            type="color"
            value={bgColor}
            onChange={(e) => setBgColor(e.target.value)}
            title="Color personalizado"
            className="h-6 w-8 cursor-pointer rounded border-0 bg-transparent"
          />
        </div>
        <div className="grid grid-cols-4 gap-2.5">
          {HOME_CARD_PASTELS.map((swatch) => {
            const selected =
              bgColor.toLowerCase() === swatch.lightBg.toLowerCase();
            const swatchInk = getContrastingInk(swatch.lightBg);
            return (
              <button
                key={swatch.id}
                type="button"
                onClick={() => setBgColor(swatch.lightBg)}
                style={{
                  backgroundColor: swatch.lightBg,
                  color: swatchInk.text,
                }}
                className={[
                  "flex flex-col items-center justify-center rounded-2xl py-2.5 px-2 text-[10px] font-bold transition-transform active:scale-95",
                  selected ? "ring-2 ring-[var(--amodoro-text)] scale-[1.03]" : "",
                ].join(" ")}
              >
                <span>{swatch.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Font Family & Font Size Pickers */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div className="rounded-2xl bg-[var(--amodoro-surface)] p-4 space-y-2">
          <span className="block text-xs font-bold uppercase tracking-wider">
            Fuente del texto
          </span>
          <div className="grid grid-cols-2 gap-2">
            {FONT_OPTIONS.map((f) => (
              <button
                key={f.id}
                type="button"
                onClick={() => setFontFamily(f.id)}
                className={[
                  f.className,
                  "rounded-xl border py-2 px-3 text-sm transition-all",
                  fontFamily === f.id
                    ? "border-2 border-[var(--amodoro-text)] bg-[var(--amodoro-bg)] font-bold"
                    : "border-black/10 dark:border-white/10 bg-[var(--amodoro-bg)]/50",
                ].join(" ")}
              >
                {f.label}
              </button>
            ))}
          </div>
        </div>

        <div className="rounded-2xl bg-[var(--amodoro-surface)] p-4 space-y-2">
          <span className="block text-xs font-bold uppercase tracking-wider">
            Tamaño del texto
          </span>
          <div className="grid grid-cols-4 gap-2">
            {SIZE_OPTIONS.map((s) => (
              <button
                key={s.id}
                type="button"
                onClick={() => setFontSize(s.id)}
                className={[
                  "rounded-xl border py-2.5 text-xs font-bold transition-all",
                  fontSize === s.id
                    ? "border-2 border-[var(--amodoro-text)] bg-[var(--amodoro-bg)]"
                    : "border-black/10 dark:border-white/10 bg-[var(--amodoro-bg)]/50",
                ].join(" ")}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex items-center gap-3 pt-2">
        <Link
          href="/"
          className="flex-1 rounded-2xl border border-black/15 dark:border-white/15 py-3.5 text-center text-xs font-bold uppercase tracking-widest"
        >
          Cancelar
        </Link>
        <button
          type="submit"
          className="flex-[2] rounded-2xl bg-[#F2B8B5] py-3.5 text-xs font-bold uppercase tracking-widest text-[#410E0B] shadow-md active:scale-[0.99]"
        >
          Enviar a {partnerNickname}
        </button>
      </div>
    </form>
  );
}
