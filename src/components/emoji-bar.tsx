"use client";

import React from "react";

export interface EmojiBarProps {
  onSelect: (emoji: string) => void;
  emojis?: string[];
  label?: string;
}

export const DEFAULT_EMOJIS: readonly string[] = [
  "❤️",
  "🥹",
  "✨",
  "🥰",
  "😂",
  "🔥",
  "🌿",
  "🍒",
  "🎬",
  "🎵",
  "🎮",
  "🍿",
  "🌙",
  "💌",
  "🤝",
  "🎉",
] as const;

export function EmojiBar({
  onSelect,
  emojis = DEFAULT_EMOJIS as string[],
  label,
}: EmojiBarProps) {
  return (
    <div className="w-full flex flex-col gap-1.5">
      {label ? (
        <span className="text-xs font-medium text-stone-600 select-none">
          {label}
        </span>
      ) : null}
      <div
        className="flex items-center gap-1.5 overflow-x-auto py-1 scroll-smooth [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        role="toolbar"
        aria-label={label ?? "Selector de emojis"}
      >
        {emojis.map((emoji, index) => (
          <button
            key={`${emoji}-${index}`}
            type="button"
            onClick={() => onSelect(emoji)}
            aria-label={emoji}
            className="shrink-0 px-3 py-1.5 rounded-full bg-stone-100 hover:bg-stone-200/80 border border-black/5 text-lg sm:text-xl active:scale-90 transition-transform cursor-pointer select-none focus:outline-none focus-visible:ring-2 focus-visible:ring-black/30"
          >
            {emoji}
          </button>
        ))}
      </div>
    </div>
  );
}

export default EmojiBar;
