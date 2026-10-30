export interface AuthorLabelInput {
  authorId: number;
  viewerId: number;
  authorNicknameGivenByPartner?: string | null;
  authorDisplayName?: string | null;
  authorUsername?: string;
}

/**
 * Returns the display label for an author relative to the current viewer:
 * - When the author is the viewer themselves, always returns "YO".
 * - Otherwise returns the nickname given by partner; if not defined, falls back to the author's displayName, then username.
 */
export function formatAuthorLabel(input: AuthorLabelInput): string {
  if (input.authorId === input.viewerId) {
    return "YO";
  }

  return (
    input.authorNicknameGivenByPartner?.trim() ||
    input.authorDisplayName?.trim() ||
    input.authorUsername ||
    "Pareja"
  );
}

const SPANISH_WEEKDAYS = [
  "DOMINGO",
  "LUNES",
  "MARTES",
  "MIÉRCOLES",
  "JUEVES",
  "VIERNES",
  "SÁBADO",
] as const;

const SPANISH_MONTHS = [
  "ENERO",
  "FEBRERO",
  "MARZO",
  "ABRIL",
  "MAYO",
  "JUNIO",
  "JULIO",
  "AGOSTO",
  "SEPTIEMBRE",
  "OCTUBRE",
  "NOVIEMBRE",
  "DICIEMBRE",
] as const;

/**
 * Formats a Date in Spanish uppercase format:
 * e.g. "LUNES · 12 DE OCTUBRE" (weekday + " · " + day + " DE " + month).
 */
export function formatSpanishDateHeader(date: Date): string {
  const d = date instanceof Date ? date : new Date(date);
  if (Number.isNaN(d.getTime())) {
    return "";
  }

  const weekday = SPANISH_WEEKDAYS[d.getDay()];
  const day = d.getDate();
  const month = SPANISH_MONTHS[d.getMonth()];

  return `${weekday} · ${day} DE ${month}`;
}
