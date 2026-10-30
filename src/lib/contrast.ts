export type AccentPaletteId = "fig-sage" | "cherry-eucalyptus" | "camellia-olive";

export interface PillColor {
  bg: string;
  fg: string;
}

export interface PaletteTokens {
  bg: string;
  surface: string;
  text: string;
  muted: string;
  pills: {
    home: PillColor;
    boards: PillColor;
    settings: PillColor;
  };
}

export interface AccentPaletteDefinition {
  id: AccentPaletteId;
  label: string;
  light: PaletteTokens;
  dark: PaletteTokens;
}

export const ACCENT_PALETTES: Record<AccentPaletteId, AccentPaletteDefinition> = {
  "fig-sage": {
    id: "fig-sage",
    label: "Higuera y Salvia",
    light: {
      bg: "#FCF9F5",
      surface: "#F4EFE8",
      text: "#1F1B18",
      muted: "#6E655F",
      pills: {
        home: { bg: "#F2B8B5", fg: "#410E0B" },
        boards: { bg: "#B8E0C8", fg: "#0B3822" },
        settings: { bg: "#E6CBA8", fg: "#3B260B" },
      },
    },
    dark: {
      bg: "#151816",
      surface: "#1E221F",
      text: "#F2EDE7",
      muted: "#A39B93",
      pills: {
        home: { bg: "#8C3A36", fg: "#FFDAD6" },
        boards: { bg: "#2E6244", fg: "#D4F7E2" },
        settings: { bg: "#6E5232", fg: "#FDE2C0" },
      },
    },
  },
  "cherry-eucalyptus": {
    id: "cherry-eucalyptus",
    label: "Cereza y Eucalipto",
    light: {
      bg: "#FFF8F7",
      surface: "#F7ECEB",
      text: "#22191A",
      muted: "#736567",
      pills: {
        home: { bg: "#FFD9DC", fg: "#3F0011" },
        boards: { bg: "#C2ECD8", fg: "#002114" },
        settings: { bg: "#E4D7DF", fg: "#2B1F28" },
      },
    },
    dark: {
      bg: "#181415",
      surface: "#241E20",
      text: "#F7ECEE",
      muted: "#AA9B9E",
      pills: {
        home: { bg: "#7D2938", fg: "#FFD9DC" },
        boards: { bg: "#22513E", fg: "#C2ECD8" },
        settings: { bg: "#56434F", fg: "#F7E8F1" },
      },
    },
  },
  "camellia-olive": {
    id: "camellia-olive",
    label: "Camelia y Olivo",
    light: {
      bg: "#FAF8F2",
      surface: "#EFECE3",
      text: "#1E1F1A",
      muted: "#686A60",
      pills: {
        home: { bg: "#F6C6BD", fg: "#3E130D" },
        boards: { bg: "#D3E6B5", fg: "#1B2B07" },
        settings: { bg: "#CBE4DE", fg: "#0D2B25" },
      },
    },
    dark: {
      bg: "#171814",
      surface: "#21231D",
      text: "#F0EFE8",
      muted: "#9FA296",
      pills: {
        home: { bg: "#7A362C", fg: "#FFDAD4" },
        boards: { bg: "#435926", fg: "#E6F8C8" },
        settings: { bg: "#2C544B", fg: "#BCECE0" },
      },
    },
  },
} as const;

export interface HomeCardPastel {
  id: string;
  label: string;
  lightBg: string;
  darkBg: string;
}

export const HOME_CARD_PASTELS: readonly HomeCardPastel[] = [
  { id: "petal", label: "Rosa Pétalo", lightBg: "#FADADD", darkBg: "#E5B8BD" },
  { id: "peach", label: "Rojo Melocotón", lightBg: "#FCD5CE", darkBg: "#E6B5AC" },
  { id: "sage", label: "Verde Salvia", lightBg: "#D8F3DC", darkBg: "#B5DEC0" },
  { id: "matcha", label: "Verde Matcha", lightBg: "#E2EDC2", darkBg: "#C4D49E" },
  { id: "vanilla", label: "Crema Vainilla", lightBg: "#FFF1CC", darkBg: "#E6D4A7" },
  { id: "lavender", label: "Lavanda Suave", lightBg: "#E8DEF8", darkBg: "#C9BFE0" },
  { id: "mist", label: "Bruma Menta", lightBg: "#D6EADF", darkBg: "#B3CFC2" },
  { id: "berry", label: "Cereza Tierra", lightBg: "#7D2E2E", darkBg: "#692323" },
] as const;

export type HomeCardPastelId = (typeof HOME_CARD_PASTELS)[number]["id"];

/**
 * Parses a hex color string into [R, G, B] values in 0..255.
 * Supports "#RRGGBB", "RRGGBB", "#RGB", "RGB".
 * Returns null if invalid.
 */
function parseHex(hex: string): [number, number, number] | null {
  if (typeof hex !== "string") return null;
  let clean = hex.trim();
  if (clean.startsWith("#")) {
    clean = clean.slice(1);
  }
  if (clean.length === 3) {
    clean = clean[0] + clean[0] + clean[1] + clean[1] + clean[2] + clean[2];
  }
  if (clean.length !== 6) {
    return null;
  }
  const num = parseInt(clean, 16);
  if (Number.isNaN(num)) return null;
  const r = (num >> 16) & 255;
  const g = (num >> 8) & 255;
  const b = num & 255;
  return [r, g, b];
}

function rgbToHex(r: number, g: number, b: number): string {
  const toHex = (c: number) =>
    Math.max(0, Math.min(255, Math.round(c)))
      .toString(16)
      .padStart(2, "0")
      .toUpperCase();
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

/**
 * Calculates standard WCAG sRGB relative luminance (0..1).
 * Falls back to #FADADD if the input hex is invalid.
 */
export function getRelativeLuminance(hex: string): number {
  const rgb = parseHex(hex) ?? parseHex("#FADADD")!;
  const [r, g, b] = rgb.map((c) => {
    const s = c / 255;
    return s <= 0.04045 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function rgbToHsl(r: number, g: number, b: number): [number, number, number] {
  const rNorm = r / 255;
  const gNorm = g / 255;
  const bNorm = b / 255;
  const max = Math.max(rNorm, gNorm, bNorm);
  const min = Math.min(rNorm, gNorm, bNorm);
  const delta = max - min;

  let h = 0;
  let s = 0;
  const l = (max + min) / 2;

  if (delta !== 0) {
    s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);
    switch (max) {
      case rNorm:
        h = (gNorm - bNorm) / delta + (gNorm < bNorm ? 6 : 0);
        break;
      case gNorm:
        h = (bNorm - rNorm) / delta + 2;
        break;
      case bNorm:
        h = (rNorm - gNorm) / delta + 4;
        break;
    }
    h *= 60;
  }

  return [h, s, l];
}

function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;

  let rPrime = 0;
  let gPrime = 0;
  let bPrime = 0;

  if (0 <= h && h < 60) {
    rPrime = c;
    gPrime = x;
    bPrime = 0;
  } else if (60 <= h && h < 120) {
    rPrime = x;
    gPrime = c;
    bPrime = 0;
  } else if (120 <= h && h < 180) {
    rPrime = 0;
    gPrime = c;
    bPrime = x;
  } else if (180 <= h && h < 240) {
    rPrime = 0;
    gPrime = x;
    bPrime = c;
  } else if (240 <= h && h < 300) {
    rPrime = x;
    gPrime = 0;
    bPrime = c;
  } else {
    rPrime = c;
    gPrime = 0;
    bPrime = x;
  }

  const r = Math.round((rPrime + m) * 255);
  const g = Math.round((gPrime + m) * 255);
  const b = Math.round((bPrime + m) * 255);

  return [r, g, b];
}

export interface ContrastingInk {
  text: string;
  muted: string;
  chipBg: string;
  border: string;
}

/**
 * Returns contrasting ink colors based on the luminance of the given background hex.
 * - Parses 6-digit hex (fallback #FADADD).
 * - If luminance > 0.42, returns a rich dark ink tinted slightly toward the background hue.
 * - If luminance <= 0.42, returns warm light ink.
 */
export function getContrastingInk(bgHex: string): ContrastingInk {
  const rgb = parseHex(bgHex) ?? parseHex("#FADADD")!;
  const luminance = getRelativeLuminance(rgbToHex(rgb[0], rgb[1], rgb[2]));

  if (luminance > 0.42) {
    const [h, s] = rgbToHsl(rgb[0], rgb[1], rgb[2]);
    const tintS = Math.min(s, 0.28);
    const [tr, tg, tb] = hslToRgb(h, tintS, 0.15);
    const [mr, mg, mb] = hslToRgb(h, tintS, 0.32);
    return {
      text: `rgb(${tr}, ${tg}, ${tb})`,
      muted: `rgb(${mr}, ${mg}, ${mb})`,
      chipBg: "rgba(0,0,0,0.08)",
      border: "rgba(0,0,0,0.12)",
    };
  }

  return {
    text: "#FDF8F5",
    muted: "rgba(253,248,245,0.78)",
    chipBg: "rgba(255,255,255,0.14)",
    border: "rgba(255,255,255,0.22)",
  };
}

/**
 * Linearly interpolates between two hex colors for t clamped in [0, 1].
 */
export function interpolateHex(hexA: string, hexB: string, t: number): string {
  const rgbA = parseHex(hexA) ?? [0, 0, 0];
  const rgbB = parseHex(hexB) ?? [0, 0, 0];
  const clampedT = Number.isNaN(t) ? 0 : Math.max(0, Math.min(1, t));

  const r = Math.round(rgbA[0] + (rgbB[0] - rgbA[0]) * clampedT);
  const g = Math.round(rgbA[1] + (rgbB[1] - rgbA[1]) * clampedT);
  const b = Math.round(rgbA[2] + (rgbB[2] - rgbA[2]) * clampedT);

  return rgbToHex(r, g, b);
}

/**
 * Interpolates top bar indicator pill color across progress in [0, 2]:
 * 0 = home, 1 = boards, 2 = settings.
 */
export function interpolatePillColor(
  progress: number,
  pills: {
    home: PillColor;
    boards: PillColor;
    settings: PillColor;
  }
): PillColor {
  const p = Number.isNaN(progress) ? 0 : Math.max(0, Math.min(2, progress));

  if (p <= 1) {
    return {
      bg: interpolateHex(pills.home.bg, pills.boards.bg, p),
      fg: interpolateHex(pills.home.fg, pills.boards.fg, p),
    };
  }

  return {
    bg: interpolateHex(pills.boards.bg, pills.settings.bg, p - 1),
    fg: interpolateHex(pills.boards.fg, pills.settings.fg, p - 1),
  };
}
