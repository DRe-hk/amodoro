"use client";

import React, { useCallback, useEffect, useRef, useState } from "react";

export interface DrawCanvasProps {
  onChangeDataUrl: (dataUrl: string | null) => void;
  backgroundColor?: string;
}

export interface BrushColor {
  value: string;
  name: string;
}

export interface BrushSize {
  label: string;
  size: number;
}

export const BRUSH_COLORS: readonly BrushColor[] = [
  { value: "#2B2119", name: "Tinta" },
  { value: "#C94A4A", name: "Rojo higo" },
  { value: "#3B7A57", name: "Verde salvia" },
  { value: "#D9822B", name: "Ámbar" },
  { value: "#4A6FA5", name: "Azul" },
  { value: "#8E5EA2", name: "Malva" },
  { value: "#FFFFFF", name: "Borrador / Blanco" },
] as const;

export const BRUSH_SIZES: readonly BrushSize[] = [
  { label: "Fino", size: 4 },
  { label: "Medio", size: 8 },
  { label: "Grueso", size: 16 },
] as const;

const CANVAS_WIDTH = 640;
const CANVAS_HEIGHT = 480;
const MAX_UNDO_SNAPSHOTS = 10;

export function DrawCanvas({
  onChangeDataUrl,
  backgroundColor,
}: DrawCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const isDrawingRef = useRef(false);
  const lastPointRef = useRef<{ x: number; y: number } | null>(null);
  const activePointerIdRef = useRef<number | null>(null);
  const initializedRef = useRef(false);

  const [activeColor, setActiveColor] = useState<string>(BRUSH_COLORS[0].value);
  const [activeSize, setActiveSize] = useState<number>(BRUSH_SIZES[0].size);
  const [undoStack, setUndoStack] = useState<ImageData[]>([]);

  const defaultBg = backgroundColor ?? "#FFFFFF";

  // Fill canvas initially with background color
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;

    if (!initializedRef.current) {
      initializedRef.current = true;
      ctx.fillStyle = defaultBg;
      ctx.fillRect(0, 0, CANVAS_WIDTH, CANVAS_HEIGHT);
    }
  }, [defaultBg]);

  // Translate client coordinates to canvas internal pixel coordinates
  const getCanvasCoords = useCallback(
    (e: React.PointerEvent<HTMLCanvasElement>): { x: number; y: number } | null => {
      const canvas = canvasRef.current;
      if (!canvas) return null;
      const rect = canvas.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return null;

      const scaleX = canvas.width / rect.width;
      const scaleY = canvas.height / rect.height;

      return {
        x: (e.clientX - rect.left) * scaleX,
        y: (e.clientY - rect.top) * scaleY,
      };
    },
    [],
  );

  const handlePointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!e.isPrimary && activePointerIdRef.current !== null) return;
    activePointerIdRef.current = e.pointerId;

    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;

    const coords = getCanvasCoords(e);
    if (!coords) return;

    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // Ignore if pointer capture is not supported
    }

    // Capture snapshot for undo stack (up to 10 snapshots)
    const snapshot = ctx.getImageData(0, 0, canvas.width, canvas.height);
    setUndoStack((prev) => {
      const next = [...prev, snapshot];
      if (next.length > MAX_UNDO_SNAPSHOTS) {
        return next.slice(next.length - MAX_UNDO_SNAPSHOTS);
      }
      return next;
    });

    isDrawingRef.current = true;
    lastPointRef.current = coords;

    // Draw an initial point for tap/click
    ctx.fillStyle = activeColor;
    ctx.beginPath();
    ctx.arc(coords.x, coords.y, activeSize / 2, 0, Math.PI * 2);
    ctx.fill();

    ctx.strokeStyle = activeColor;
    ctx.lineWidth = activeSize;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(coords.x, coords.y);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDrawingRef.current) return;
    if (activePointerIdRef.current !== null && e.pointerId !== activePointerIdRef.current) return;

    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;

    const coords = getCanvasCoords(e);
    if (!coords) return;

    ctx.strokeStyle = activeColor;
    ctx.lineWidth = activeSize;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    const last = lastPointRef.current;
    if (last) {
      ctx.beginPath();
      ctx.moveTo(last.x, last.y);
      ctx.lineTo(coords.x, coords.y);
      ctx.stroke();
    }

    lastPointRef.current = coords;
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!isDrawingRef.current) return;
    if (activePointerIdRef.current !== null && e.pointerId !== activePointerIdRef.current) return;

    isDrawingRef.current = false;
    lastPointRef.current = null;
    activePointerIdRef.current = null;

    try {
      if (e.currentTarget.hasPointerCapture(e.pointerId)) {
        e.currentTarget.releasePointerCapture(e.pointerId);
      }
    } catch {
      // Ignore
    }

    const canvas = canvasRef.current;
    if (canvas) {
      onChangeDataUrl(canvas.toDataURL("image/png"));
    }
  };

  const handleUndo = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx || undoStack.length === 0) return;

    const nextStack = [...undoStack];
    const previousSnapshot = nextStack.pop();
    if (previousSnapshot) {
      ctx.putImageData(previousSnapshot, 0, 0);
    }
    setUndoStack(nextStack);
    onChangeDataUrl(canvas.toDataURL("image/png"));
  };

  const handleClear = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;

    ctx.fillStyle = defaultBg;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    setUndoStack([]);
    onChangeDataUrl(null);
  };

  return (
    <div className="w-full flex flex-col gap-2">
      <canvas
        ref={canvasRef}
        width={CANVAS_WIDTH}
        height={CANVAS_HEIGHT}
        className="aspect-[4/3] w-full rounded-2xl touch-none border border-black/10 block shadow-xs"
        style={{ backgroundColor: defaultBg }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
      />

      {/* Compact toolbar right below the canvas */}
      <div className="flex flex-wrap items-center justify-between gap-2 p-2 bg-stone-50/90 rounded-2xl border border-black/5 text-stone-800">
        {/* 7 Brush colors */}
        <div
          className="flex items-center gap-1.5 flex-wrap"
          role="toolbar"
          aria-label="Colores de pincel"
        >
          {BRUSH_COLORS.map((c) => {
            const isSelected = activeColor === c.value;
            const isWhite = c.value.toLowerCase() === "#ffffff";
            return (
              <button
                key={c.value}
                type="button"
                onClick={() => setActiveColor(c.value)}
                title={c.name}
                aria-label={c.name}
                aria-pressed={isSelected}
                className={`w-7 h-7 sm:w-8 sm:h-8 rounded-full transition-transform flex items-center justify-center cursor-pointer select-none ${
                  isWhite ? "border border-black/20" : "border border-black/10"
                } ${
                  isSelected
                    ? "ring-2 ring-black ring-offset-2 scale-110 shadow-xs"
                    : "hover:scale-105 active:scale-95"
                }`}
                style={{ backgroundColor: c.value }}
              >
                {isWhite && (
                  <span className="text-[10px] font-bold text-stone-500 leading-none">
                    ✕
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {/* 3 Brush sizes and Undo / Clear action buttons */}
        <div className="flex items-center gap-2 flex-wrap">
          {/* Brush sizes */}
          <div
            className="flex items-center bg-stone-200/70 p-0.5 rounded-xl"
            role="toolbar"
            aria-label="Grosor de pincel"
          >
            {BRUSH_SIZES.map((b) => {
              const isSelected = activeSize === b.size;
              return (
                <button
                  key={b.size}
                  type="button"
                  onClick={() => setActiveSize(b.size)}
                  aria-label={`${b.label} (${b.size}px)`}
                  aria-pressed={isSelected}
                  className={`px-2.5 py-1 text-xs font-medium rounded-lg transition-all flex items-center gap-1.5 cursor-pointer select-none ${
                    isSelected
                      ? "bg-white text-stone-900 shadow-xs font-semibold"
                      : "text-stone-600 hover:text-stone-900"
                  }`}
                >
                  <span
                    className="rounded-full bg-current inline-block"
                    style={{
                      width: b.size === 4 ? 4 : b.size === 8 ? 6 : 9,
                      height: b.size === 4 ? 4 : b.size === 8 ? 6 : 9,
                    }}
                  />
                  <span>{b.label}</span>
                </button>
              );
            })}
          </div>

          {/* Action buttons: Deshacer and Limpiar */}
          <div className="flex items-center gap-1.5">
            <button
              type="button"
              onClick={handleUndo}
              disabled={undoStack.length === 0}
              title="Deshacer último trazo"
              className="px-2.5 py-1 text-xs font-medium rounded-xl border border-black/10 bg-white hover:bg-stone-100 active:scale-95 disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100 transition-all flex items-center gap-1 cursor-pointer select-none"
            >
              <svg
                className="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d="M3 7v6h6" />
                <path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" />
              </svg>
              <span>Deshacer</span>
            </button>

            <button
              type="button"
              onClick={handleClear}
              title="Limpiar lienzo"
              className="px-2.5 py-1 text-xs font-medium rounded-xl border border-black/10 bg-white hover:bg-red-50 text-stone-700 hover:text-red-600 active:scale-95 transition-all flex items-center gap-1 cursor-pointer select-none"
            >
              <svg
                className="w-3.5 h-3.5"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d="M3 6h18" />
                <path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
                <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
              </svg>
              <span>Limpiar</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default DrawCanvas;
