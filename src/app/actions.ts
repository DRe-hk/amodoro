"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  clearCurrentSession,
  createInviteForUser,
  requirePageUser,
  updateUserSettings,
} from "@/lib/auth";
import {
  addBoardItem,
  copyItemToActividades,
  createCustomBoard,
  deleteOrCompleteBoardItem,
} from "@/lib/boards";
import {
  spinRouletteDecision,
  startVotingDecision,
  submitVotingRoundChoices,
} from "@/lib/decision";
import { createHomeCard, reactToHomeCard } from "@/lib/home-cards";
import { storeDrawingDataUrl, storeImageUpload } from "@/lib/media";
import type {
  AccentPalette,
  CardFont,
  CardFontSize,
  ThemeMode,
} from "@/db/schema";

export async function createHomeCardAction(formData: FormData) {
  const user = await requirePageUser();
  const body = String(formData.get("body") ?? "").trim();
  const bgColor = String(formData.get("bgColor") ?? "#FADADD").trim();
  const fontFamily = (formData.get("fontFamily") ?? "sans") as CardFont;
  const fontSize = (formData.get("fontSize") ?? "md") as CardFontSize;
  const mediaMode = String(formData.get("mediaMode") ?? "none");

  let mediaId: number | null = null;

  if (mediaMode === "photo") {
    const file = formData.get("photo");
    if (file instanceof File && file.size > 0) {
      const stored = await storeImageUpload(file, user.id);
      mediaId = stored.mediaId;
    }
  } else if (mediaMode === "drawing") {
    const drawingDataUrl = String(formData.get("drawingDataUrl") ?? "");
    if (drawingDataUrl.startsWith("data:image/png;base64,")) {
      const stored = await storeDrawingDataUrl(drawingDataUrl, user.id);
      mediaId = stored.mediaId;
    }
  }

  createHomeCard({
    authorId: user.id,
    mediaId,
    body,
    bgColor,
    fontFamily,
    fontSize,
  });

  revalidatePath("/");
  revalidatePath("/enviados");
  redirect("/");
}

export async function reactToCardAction(formData: FormData) {
  const user = await requirePageUser();
  const cardId = Number(formData.get("cardId"));
  if (!Number.isInteger(cardId)) return;

  const emoji = formData.get("emoji") ? String(formData.get("emoji")) : null;
  const presetText = formData.get("presetText")
    ? String(formData.get("presetText"))
    : null;

  reactToHomeCard({
    cardId,
    userId: user.id,
    emoji,
    presetText,
  });

  revalidatePath("/");
  revalidatePath("/enviados");
}

export async function createBoardAction(formData: FormData) {
  const user = await requirePageUser();
  const title = String(formData.get("title") ?? "").trim();
  const icon = String(formData.get("icon") ?? "sparkles").trim();
  if (!title) return;

  createCustomBoard({ title, icon, userId: user.id });
  revalidatePath("/");
}

export async function addBoardItemAction(formData: FormData) {
  const user = await requirePageUser();
  const boardId = Number(formData.get("boardId"));
  const categoryTag = String(formData.get("categoryTag") ?? "ACTIVIDAD").trim();
  const title = String(formData.get("title") ?? "").trim();
  const notes = String(formData.get("notes") ?? "").trim();
  const url = String(formData.get("url") ?? "").trim();
  const emoji = String(formData.get("emoji") ?? "").trim();

  if (!Number.isInteger(boardId) || !title) return;

  addBoardItem({
    boardId,
    categoryTag,
    title,
    notes: notes || undefined,
    url: url || undefined,
    emoji: emoji || undefined,
    userId: user.id,
  });

  revalidatePath("/");
}

export async function copyToActividadesAction(formData: FormData) {
  const user = await requirePageUser();
  const itemId = Number(formData.get("itemId"));
  if (!Number.isInteger(itemId)) return;

  copyItemToActividades(itemId, user.id);
  revalidatePath("/");
}

export async function completeBoardItemAction(formData: FormData) {
  await requirePageUser();
  const itemId = Number(formData.get("itemId"));
  if (!Number.isInteger(itemId)) return;

  deleteOrCompleteBoardItem(itemId);
  revalidatePath("/");
}

export async function spinRouletteAction() {
  await requirePageUser();
  spinRouletteDecision();
  revalidatePath("/");
}

export async function startVotingRoundAction() {
  await requirePageUser();
  startVotingDecision(5);
  revalidatePath("/");
}

export async function submitVotingRoundAction(formData: FormData) {
  const user = await requirePageUser();
  const sessionId = Number(formData.get("sessionId"));
  if (!Number.isInteger(sessionId)) return;

  const wantedRaw = formData.getAll("wantedItemId");
  const wantedItemIds = wantedRaw
    .map((v) => Number(v))
    .filter((n) => Number.isInteger(n));

  submitVotingRoundChoices({
    sessionId,
    userId: user.id,
    wantedItemIds,
  });

  revalidatePath("/");
}

export async function saveSettingsAction(formData: FormData) {
  const user = await requirePageUser();
  const partnerNickname = formData.get("partnerNickname")
    ? String(formData.get("partnerNickname"))
    : undefined;
  const themeMode = formData.get("themeMode")
    ? (String(formData.get("themeMode")) as ThemeMode)
    : undefined;
  const accentPalette = formData.get("accentPalette")
    ? (String(formData.get("accentPalette")) as AccentPalette)
    : undefined;

  const quickRepliesRaw = formData.get("quickReplies");
  let quickReplies: string[] | undefined;
  if (typeof quickRepliesRaw === "string") {
    quickReplies = quickRepliesRaw
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean);
  }

  updateUserSettings({
    userId: user.id,
    partnerNickname,
    themeMode,
    accentPalette,
    quickReplies,
  });

  revalidatePath("/");
  revalidatePath("/enviados");
  revalidatePath("/crear");
}

export async function generateInviteAction(): Promise<{
  code: string;
  token: string;
}> {
  const user = await requirePageUser();
  const res = createInviteForUser(user.id);
  revalidatePath("/");
  return { code: res.code, token: res.token };
}

export async function logoutAction() {
  await clearCurrentSession();
  redirect("/entrar");
}
