"use client";

import React, { useState } from "react";
import {
  addBoardItemAction,
  completeBoardItemAction,
  copyToActividadesAction,
  createBoardAction,
} from "@/app/actions";
import { DecideModal } from "./decide-modal";
import { EmojiBar } from "./emoji-bar";
import { formatAuthorLabel } from "@/lib/identity";
import type { BoardRow, HydratedBoardItem } from "@/lib/boards";
import type { ActiveDecisionState } from "@/lib/decision";

function BoardIcon({ icon }: { icon: string }) {
  if (icon === "clock") {
    return (
      <svg
        className="h-4 w-4"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
      >
        <circle cx="12" cy="12" r="9" />
        <polyline points="12 7 12 12 15 15" />
      </svg>
    );
  }
  if (icon === "disc") {
    return (
      <svg
        className="h-4 w-4"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
      >
        <circle cx="12" cy="12" r="9" />
        <circle cx="12" cy="12" r="2.5" />
      </svg>
    );
  }
  if (icon === "film") {
    return (
      <svg
        className="h-4 w-4"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
      >
        <rect x="3" y="4" width="18" height="16" rx="2" />
        <line x1="3" y1="9" x2="21" y2="9" />
        <line x1="8" y1="4" x2="10" y2="9" />
        <line x1="14" y1="4" x2="16" y2="9" />
      </svg>
    );
  }
  return (
    <svg
      className="h-4 w-4"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
    >
      <path d="M12 3l2.4 5.2L20 9.3l-4 4 0.9 5.7-4.9-2.6L7.1 19l0.9-5.7-4-4 5.6-1.1L12 3z" />
    </svg>
  );
}

export function BoardsView({
  viewerId,
  partnerNickname,
  boards,
  itemsByBoardId,
  actividadesBoardId,
  decision,
}: {
  viewerId: number;
  partnerNickname: string;
  boards: BoardRow[];
  itemsByBoardId: Record<number, HydratedBoardItem[]>;
  actividadesBoardId: number;
  decision: ActiveDecisionState | null;
}) {
  const [selectedBoardId, setSelectedBoardId] =
    useState<number>(actividadesBoardId);
  const [decideOpen, setDecideOpen] = useState<boolean>(false);
  const [newBoardOpen, setNewBoardOpen] = useState<boolean>(false);
  const [newItemOpen, setNewItemOpen] = useState<boolean>(false);
  const [draftTitle, setDraftTitle] = useState<string>("");
  const [copiedId, setCopiedId] = useState<number | null>(null);

  const activeBoard =
    boards.find((b) => b.id === selectedBoardId) ?? boards[0];
  const isActividades = activeBoard?.slug === "actividades";
  const currentItems = activeBoard
    ? (itemsByBoardId[activeBoard.id] ?? [])
    : [];

  // Split items into 2 columns matching the asymmetrical bento sketch:
  // In Actividades, the left column starts with the compact DECIDIR button!
  const leftColumnItems: HydratedBoardItem[] = [];
  const rightColumnItems: HydratedBoardItem[] = [];

  currentItems.forEach((item, index) => {
    if (isActividades) {
      // First item goes to right column so it sits next to the DECIDIR button + first left card
      if (index % 2 === 0) leftColumnItems.push(item);
      else rightColumnItems.push(item);
    } else {
      if (index % 2 === 0) leftColumnItems.push(item);
      else rightColumnItems.push(item);
    }
  });

  function renderBoardCard(item: HydratedBoardItem) {
    const authorLabel = formatAuthorLabel({
      authorId: item.addedBy,
      viewerId,
      authorNicknameGivenByPartner: item.addedByNickname,
      authorUsername: item.addedByUsername,
    });

    return (
      <div
        key={item.id}
        className="group relative flex flex-col justify-between rounded-[22px] border border-black/12 dark:border-white/12 bg-[var(--amodoro-surface)] p-3.5 shadow-xs transition-all hover:shadow-md"
      >
        <div>
          <div className="flex items-center justify-between gap-1">
            <span className="text-[10px] font-bold uppercase tracking-[0.11em] text-[var(--amodoro-muted)]">
              {item.categoryTag}
            </span>
            <span className="rounded-full bg-black/5 dark:bg-white/10 px-2 py-0.5 text-[10px] font-semibold text-[var(--amodoro-muted)]">
              {authorLabel}
            </span>
          </div>

          <h4 className="mt-1.5 text-[15px] font-bold leading-snug text-[var(--amodoro-text)] break-words">
            {item.emoji ? `${item.emoji} ` : ""}
            {item.title}
          </h4>

          {item.notes ? (
            <p className="mt-1 text-xs leading-relaxed text-[var(--amodoro-muted)] break-words">
              {item.notes}
            </p>
          ) : null}

          {item.url ? (
            <a
              href={item.url}
              target="_blank"
              rel="noreferrer"
              className="mt-2 inline-flex items-center gap-1 text-[11px] font-semibold underline opacity-80 hover:opacity-100"
            >
              Abrir enlace ↗
            </a>
          ) : null}
        </div>

        {/* Card footer actions: copy to Actividades (if in another board) or mark completed */}
        <div className="mt-3 flex items-center justify-between gap-1.5 border-t border-black/6 dark:border-white/8 pt-2">
          {!isActividades ? (
            <form
              action={async (fd) => {
                await copyToActividadesAction(fd);
                setCopiedId(item.id);
                setTimeout(() => setCopiedId(null), 1600);
              }}
            >
              <input type="hidden" name="itemId" value={item.id} />
              <button
                type="submit"
                className="inline-flex items-center gap-1 rounded-full bg-[#B8E0C8] px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-[#0B3822] active:scale-95 transition-transform"
              >
                {copiedId === item.id
                  ? "✓ En Actividades"
                  : "+ A Actividades"}
              </button>
            </form>
          ) : (
            <span className="text-[10px] font-medium text-[var(--amodoro-muted)]">
              Pendiente
            </span>
          )}

          <form action={completeBoardItemAction}>
            <input type="hidden" name="itemId" value={item.id} />
            <button
              type="submit"
              title="Archivar / Completar"
              className="rounded-full p-1 text-xs text-[var(--amodoro-muted)] hover:text-[var(--amodoro-text)]"
            >
              ✓
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      {/* Top Horizontal Row of Boards matching sketch: [🕒 Actividades] [💿 Música] [🎬 Pelis] [+ Nuevo] */}
      <div
        data-no-pager-swipe="true"
        className="flex items-stretch gap-2.5 overflow-x-auto no-scrollbar pb-1"
      >
        {boards.map((board) => {
          const isSelected = board.id === activeBoard?.id;
          return (
            <button
              key={board.id}
              type="button"
              onClick={() => setSelectedBoardId(board.id)}
              className={[
                "flex min-w-[92px] shrink-0 flex-col items-center justify-center gap-1 rounded-2xl px-3.5 py-2.5 text-center transition-all",
                isSelected
                  ? "border-2 border-[var(--amodoro-text)] bg-[var(--amodoro-surface)] font-bold shadow-xs"
                  : "border border-black/12 dark:border-white/12 bg-[var(--amodoro-surface)]/60 opacity-80 hover:opacity-100",
              ].join(" ")}
            >
              <BoardIcon icon={board.icon} />
              <span className="text-[11px] uppercase tracking-wider leading-tight">
                {board.slug === "actividades" ? "Actividades" : board.title}
              </span>
            </button>
          );
        })}

        {/* + Create new custom board button */}
        <button
          type="button"
          onClick={() => setNewBoardOpen((v) => !v)}
          title="Crear nuevo tablero"
          className="flex min-w-[54px] shrink-0 flex-col items-center justify-center gap-1 rounded-2xl border border-dashed border-black/25 dark:border-white/25 px-3 py-2.5 text-xs font-bold text-[var(--amodoro-muted)] hover:text-[var(--amodoro-text)]"
        >
          <span className="text-base leading-none">+</span>
          <span className="text-[10px] uppercase tracking-wider">Tablero</span>
        </button>
      </div>

      {/* Inline drawer to create a custom board */}
      {newBoardOpen ? (
        <form
          action={async (fd) => {
            await createBoardAction(fd);
            setNewBoardOpen(false);
          }}
          className="flex items-center gap-2 rounded-2xl border border-black/15 dark:border-white/15 bg-[var(--amodoro-surface)] p-3"
        >
          <input
            type="text"
            name="title"
            required
            placeholder="Nombre del tablero (ej. Lugares, Personajes...)"
            className="flex-1 rounded-xl bg-[var(--amodoro-bg)] px-3 py-2 text-xs font-medium focus:outline-none"
          />
          <button
            type="submit"
            className="rounded-xl bg-[#B8E0C8] px-3.5 py-2 text-xs font-bold uppercase tracking-wider text-[#0B3822]"
          >
            Crear
          </button>
        </form>
      ) : null}

      {/* Active decision banner if a winner or voting session is live */}
      {isActividades && decision ? (
        <button
          type="button"
          onClick={() => setDecideOpen(true)}
          className="flex w-full items-center justify-between rounded-2xl border border-[#0B3822]/20 bg-[#D8F3DC] px-4 py-2.5 text-left text-[#102E1A] shadow-xs"
        >
          <div className="min-w-0">
            <span className="block text-[10px] font-bold uppercase tracking-widest opacity-75">
              {decision.status === "resolved"
                ? "Última decisión ganadora"
                : `Votación activa · Ronda ${decision.roundNumber}`}
            </span>
            <span className="block truncate text-sm font-bold">
              {decision.status === "resolved" && decision.winner
                ? `${decision.winner.emoji ?? "✨"} ${decision.winner.title}`
                : "Toca aquí para votar las 4–5 actividades"}
            </span>
          </div>
          <span className="ml-2 shrink-0 rounded-full bg-[#102E1A] px-3 py-1 text-[10px] font-bold uppercase tracking-wider text-[#D8F3DC]">
            Ver
          </span>
        </button>
      ) : null}

      {/* 2-Column Bento / Masonry Grid matching the sketch */}
      <div className="grid grid-cols-2 gap-3 items-start">
        {/* Left Column */}
        <div className="flex flex-col gap-3">
          {/* In Actividades (Pendientes), the top-left slot is the compact DECIDIR button from the sketch */}
          {isActividades ? (
            <button
              type="button"
              onClick={() => setDecideOpen(true)}
              className="flex h-[54px] w-full items-center justify-between rounded-[20px] border-2 border-[#0B3822]/25 bg-[#B8E0C8] px-4 text-[#0B3822] shadow-sm active:scale-[0.98] transition-transform"
            >
              <span className="text-xs font-extrabold uppercase tracking-[0.12em]">
                Decidir
              </span>
              <span className="text-base">🎲</span>
            </button>
          ) : null}

          {leftColumnItems.map((item) => renderBoardCard(item))}
        </div>

        {/* Right Column */}
        <div className="flex flex-col gap-3">
          {rightColumnItems.map((item) => renderBoardCard(item))}

          {/* Add new card to current board */}
          <button
            type="button"
            onClick={() => setNewItemOpen((v) => !v)}
            className="flex min-h-[76px] w-full flex-col items-center justify-center gap-1 rounded-[22px] border border-dashed border-black/25 dark:border-white/25 bg-[var(--amodoro-surface)]/40 p-3 text-center text-xs font-bold text-[var(--amodoro-muted)] hover:text-[var(--amodoro-text)]"
          >
            <span className="text-lg leading-none">+</span>
            <span className="uppercase tracking-wider text-[11px]">
              Añadir a {activeBoard?.title}
            </span>
          </button>
        </div>
      </div>

      {/* Modal/Sheet to add a new item with full Emoji support */}
      {newItemOpen && activeBoard ? (
        <div
          data-no-pager-swipe="true"
          className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-xs p-3"
        >
          <div className="w-full max-w-md rounded-[28px] border border-black/10 dark:border-white/10 bg-[var(--amodoro-bg)] p-5 text-[var(--amodoro-text)] shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-bold uppercase tracking-wider">
                Nueva ficha en {activeBoard.title}
              </h3>
              <button
                type="button"
                onClick={() => setNewItemOpen(false)}
                className="flex h-7 w-7 items-center justify-center rounded-full bg-black/5 dark:bg-white/10 text-xs font-bold"
              >
                ✕
              </button>
            </div>

            <form
              action={async (fd) => {
                await addBoardItemAction(fd);
                setDraftTitle("");
                setNewItemOpen(false);
              }}
              className="space-y-3"
            >
              <input type="hidden" name="boardId" value={activeBoard.id} />

              <div className="grid grid-cols-3 gap-2">
                <div className="col-span-2">
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)] mb-1">
                    Categoría
                  </label>
                  <input
                    type="text"
                    name="categoryTag"
                    defaultValue={
                      activeBoard.slug === "musica"
                        ? "CANCIÓN"
                        : activeBoard.slug === "pelis"
                          ? "PELÍCULA"
                          : "ACTIVIDAD"
                    }
                    className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] px-3 py-2 text-xs font-semibold uppercase"
                  />
                </div>
                <div>
                  <label className="block text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)] mb-1">
                    Icono / Emoji
                  </label>
                  <input
                    type="text"
                    name="emoji"
                    placeholder="🎮 🍿 🎵"
                    className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] px-3 py-2 text-xs text-center"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)] mb-1">
                  Título (soporta emojis)
                </label>
                <input
                  type="text"
                  name="title"
                  required
                  value={draftTitle}
                  onChange={(e) => setDraftTitle(e.target.value)}
                  placeholder="Ej. Jugar Minecraft 😊 😐 o Ver Snoopy"
                  className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] px-3 py-2.5 text-sm font-semibold"
                />
              </div>

              <EmojiBar
                label="Insertar emoji en el título"
                onSelect={(emoji) => setDraftTitle((prev) => `${prev}${emoji}`)}
              />

              <div>
                <label className="block text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)] mb-1">
                  Notas o idea (opcional)
                </label>
                <textarea
                  name="notes"
                  rows={2}
                  placeholder="Detalles, de qué trata o por qué te gustaría..."
                  className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] px-3 py-2 text-xs"
                />
              </div>

              <div>
                <label className="block text-[10px] font-bold uppercase tracking-wider text-[var(--amodoro-muted)] mb-1">
                  Enlace (opcional: Spotify, Letterboxd, YouTube...)
                </label>
                <input
                  type="url"
                  name="url"
                  placeholder="https://..."
                  className="w-full rounded-xl border border-black/10 dark:border-white/10 bg-[var(--amodoro-surface)] px-3 py-2 text-xs"
                />
              </div>

              <button
                type="submit"
                className="w-full rounded-2xl bg-[#B8E0C8] py-3 text-xs font-bold uppercase tracking-widest text-[#0B3822] shadow-sm"
              >
                Guardar en {activeBoard.title}
              </button>
            </form>
          </div>
        </div>
      ) : null}

      <DecideModal
        isOpen={decideOpen}
        onClose={() => setDecideOpen(false)}
        decision={decision}
        partnerNickname={partnerNickname}
        totalActivitiesCount={
          (itemsByBoardId[actividadesBoardId] ?? []).length
        }
      />
    </div>
  );
}
