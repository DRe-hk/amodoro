"use client";

import React, { useRef, useState, useSyncExternalStore } from "react";
import {
  ACCENT_PALETTES,
  type AccentPaletteId,
} from "@/lib/contrast";
import type { ThemeMode } from "@/db/schema";

const TABS = [
  { id: "home", label: "HOME" },
  { id: "boards", label: "BOARDS" },
  { id: "settings", label: "SETTINGS" },
] as const;

export function AmodoroShell({
  themeMode,
  accentPalette,
  homeContent,
  boardsContent,
  settingsContent,
  hasActiveVoting,
}: {
  themeMode: ThemeMode;
  accentPalette: AccentPaletteId;
  homeContent: React.ReactNode;
  boardsContent: React.ReactNode;
  settingsContent: React.ReactNode;
  hasActiveVoting?: boolean;
}) {
  const [activeIndex, setActiveIndex] = useState<number>(0);
  // Continuous progress in [0, 2] that tracks finger swipe in real time
  const [progress, setProgress] = useState<number>(0);
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const systemDark = useSyncExternalStore(
    (onStoreChange) => {
      const mq = window.matchMedia("(prefers-color-scheme: dark)");
      mq.addEventListener("change", onStoreChange);
      return () => mq.removeEventListener("change", onStoreChange);
    },
    () => window.matchMedia("(prefers-color-scheme: dark)").matches,
    () => false,
  );

  const containerRef = useRef<HTMLDivElement | null>(null);
  const touchState = useRef<{
    startX: number;
    startY: number;
    startProgress: number;
    lockedAxis: "x" | "y" | null;
    active: boolean;
  }>({
    startX: 0,
    startY: 0,
    startProgress: 0,
    lockedAxis: null,
    active: false,
  });

  const isDark =
    themeMode === "dark" || (themeMode === "system" && systemDark);
  const paletteDef = ACCENT_PALETTES[accentPalette] ?? ACCENT_PALETTES["fig-sage"];
  const tokens = isDark ? paletteDef.dark : paletteDef.light;

  // Single uniform Coral indicator pill across all tabs
  const pillColor = isDark
    ? { bg: "#D96B62", fg: "#FFF5F4" }
    : { bg: "#F08076", fg: "#3B0D09" };

  function goToTab(idx: number) {
    const clamped = Math.max(0, Math.min(2, idx));
    setIsDragging(false);
    setActiveIndex(clamped);
    setProgress(clamped);
  }

  function handleTouchStart(e: React.TouchEvent<HTMLDivElement>) {
    // Do not hijack touches inside horizontal scrollers or canvas pads
    const target = e.target as HTMLElement | null;
    if (
      target?.closest("[data-no-pager-swipe='true']") ||
      target?.tagName === "CANVAS" ||
      target?.tagName === "INPUT" ||
      target?.tagName === "TEXTAREA"
    ) {
      return;
    }

    const touch = e.touches[0];
    if (!touch) return;
    touchState.current = {
      startX: touch.clientX,
      startY: touch.clientY,
      startProgress: activeIndex,
      lockedAxis: null,
      active: true,
    };
  }

  function handleTouchMove(e: React.TouchEvent<HTMLDivElement>) {
    if (!touchState.current.active) return;
    const touch = e.touches[0];
    if (!touch) return;

    const dx = touch.clientX - touchState.current.startX;
    const dy = touch.clientY - touchState.current.startY;

    if (!touchState.current.lockedAxis) {
      if (Math.abs(dx) < 8 && Math.abs(dy) < 8) return;
      touchState.current.lockedAxis =
        Math.abs(dx) > Math.abs(dy) * 1.15 ? "x" : "y";
    }

    if (touchState.current.lockedAxis !== "x") {
      return;
    }

    const width = containerRef.current?.clientWidth || window.innerWidth || 380;
    const deltaProgress = -dx / width;
    const nextProgress = Math.max(
      0,
      Math.min(2, touchState.current.startProgress + deltaProgress),
    );
    setIsDragging(true);
    setProgress(nextProgress);
  }

  function handleTouchEnd() {
    if (!touchState.current.active) return;
    const wasHorizontal = touchState.current.lockedAxis === "x";
    touchState.current.active = false;
    touchState.current.lockedAxis = null;

    if (!wasHorizontal) return;

    const diff = progress - activeIndex;
    let targetIndex = activeIndex;
    if (diff > 0.22) {
      targetIndex = Math.min(2, activeIndex + 1);
    } else if (diff < -0.22) {
      targetIndex = Math.max(0, activeIndex - 1);
    } else {
      targetIndex = Math.round(progress);
    }
    goToTab(targetIndex);
  }

  return (
    <div
      style={
        {
          "--amodoro-bg": tokens.bg,
          "--amodoro-surface": tokens.surface,
          "--amodoro-text": tokens.text,
          "--amodoro-muted": tokens.muted,
          backgroundColor: tokens.bg,
          color: tokens.text,
        } as React.CSSProperties
      }
      className="min-h-dvh flex flex-col select-none transition-colors duration-300"
    >
      {/* Top Bar: 3 equal sections with side margins, rounded pill of 1/3 inner width & minimum vertical height */}
      <header className="sticky top-0 z-40 w-full backdrop-blur-md bg-[var(--amodoro-bg)]/90 border-b border-black/[0.06] dark:border-white/[0.07]">
        <div className="mx-auto w-full max-w-md px-4 pt-2.5 pb-2">
          <nav
            aria-label="Secciones principales de Amodoro"
            className="relative grid grid-cols-3 items-center"
          >
            {/* Gliding 1/3 Active Pill Indicator (with subtle side inset so it has breathing room and rounded edges) */}
            <div
              aria-hidden="true"
              style={{
                width: "calc(100% / 3)",
                transform: `translate3d(${progress * 100}%, 0, 0)`,
                transition: isDragging
                  ? "none"
                  : "transform 280ms cubic-bezier(0.22, 1, 0.36, 1)",
              }}
              className="pointer-events-none absolute inset-y-0 left-0 flex items-center px-1.5"
            >
              <div
                style={{
                  backgroundColor: pillColor.bg,
                }}
                className="h-[22px] w-full rounded-full shadow-xs transition-colors duration-150"
              />
            </div>

            {TABS.map((tab, idx) => {
              const distance = Math.abs(progress - idx);
              const isSelected = distance < 0.5;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => goToTab(idx)}
                  aria-current={activeIndex === idx ? "page" : undefined}
                  style={{
                    color: isSelected ? pillColor.fg : tokens.muted,
                  }}
                  className="relative z-10 flex h-[26px] w-full items-center justify-center px-2 text-[11px] font-bold tracking-[0.11em] uppercase transition-colors focus:outline-none"
                >
                  <span className="leading-none">{tab.label}</span>
                  {tab.id === "boards" && hasActiveVoting ? (
                    <span
                      title="Votación activa"
                      className="ml-1.5 h-1.5 w-1.5 rounded-full bg-current animate-pulse"
                    />
                  ) : null}
                </button>
              );
            })}
          </nav>
        </div>
      </header>

      {/* Swipeable 3-panel viewport */}
      <div
        ref={containerRef}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
        onTouchCancel={handleTouchEnd}
        className="relative flex-1 w-full overflow-x-hidden"
      >
        <div
          style={{
            width: "300%",
            transform: `translate3d(-${(progress * 100) / 3}%, 0, 0)`,
            transition: isDragging
              ? "none"
              : "transform 300ms cubic-bezier(0.22, 1, 0.36, 1)",
          }}
          className="flex min-h-[calc(100dvh-46px)] items-start"
        >
          {/* Panel 0: HOME */}
          <section
            aria-label="Home"
            className="w-1/3 shrink-0 px-4 pt-3 pb-28 mx-auto"
          >
            <div className="mx-auto w-full max-w-md">{homeContent}</div>
          </section>

          {/* Panel 1: BOARDS */}
          <section
            aria-label="Boards"
            className="w-1/3 shrink-0 px-4 pt-3 pb-24 mx-auto"
          >
            <div className="mx-auto w-full max-w-md">{boardsContent}</div>
          </section>

          {/* Panel 2: SETTINGS */}
          <section
            aria-label="Settings"
            className="w-1/3 shrink-0 px-4 pt-3 pb-24 mx-auto"
          >
            <div className="mx-auto w-full max-w-md">{settingsContent}</div>
          </section>
        </div>
      </div>
    </div>
  );
}
