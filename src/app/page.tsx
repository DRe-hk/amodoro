import React from "react";
import { getPartnerUser, requirePageUser } from "@/lib/auth";
import { listBoardsWithItems } from "@/lib/boards";
import { getCurrentDecisionState } from "@/lib/decision";
import { getReceivedHomeCards } from "@/lib/home-cards";
import { AmodoroShell } from "@/components/amodoro-shell";
import { BoardsView } from "@/components/boards-view";
import { HomeView } from "@/components/home-view";
import { SettingsView } from "@/components/settings-view";
import type { AccentPaletteId } from "@/lib/contrast";

export const dynamic = "force-dynamic";

export default async function MainAmodoroPage() {
  const user = await requirePageUser();
  const partner = getPartnerUser(user.id);

  const { latest, history } = getReceivedHomeCards(user.id);
  const { boards, itemsByBoardId, actividadesBoardId } = listBoardsWithItems();
  const decision = getCurrentDecisionState(user.id);

  let quickReplies: string[] = [
    "Te amo ❤️",
    "Me alegraste el día ✨",
    "Qué bonito 🥺",
    "Te extraño mucho 💌",
    "Me sacaste una sonrisa 🥰",
  ];
  try {
    const parsed = JSON.parse(user.quickRepliesJson);
    if (Array.isArray(parsed) && parsed.length > 0) {
      quickReplies = parsed;
    }
  } catch {
    // keep default
  }

  const partnerNicknameGivenByMe =
    partner?.nicknameByPartner?.trim() || partner?.username || "Amor";
  const myNicknameGivenByPartner =
    user.nicknameByPartner?.trim() || user.username;

  return (
    <AmodoroShell
      themeMode={user.themeMode}
      accentPalette={user.accentPalette as AccentPaletteId}
      hasActiveVoting={decision?.status === "voting"}
      homeContent={
        <HomeView
          viewerId={user.id}
          partnerNickname={partnerNicknameGivenByMe}
          latestReceived={latest}
          historyReceived={history}
          quickReplies={quickReplies}
        />
      }
      boardsContent={
        <BoardsView
          viewerId={user.id}
          partnerNickname={partnerNicknameGivenByMe}
          boards={boards}
          itemsByBoardId={itemsByBoardId}
          actividadesBoardId={actividadesBoardId}
          decision={decision}
        />
      }
      settingsContent={
        <SettingsView
          myUsername={user.username}
          myNicknameGivenByPartner={myNicknameGivenByPartner}
          partnerUsername={partner?.username ?? "pareja"}
          partnerNicknameGivenByMe={partnerNicknameGivenByMe}
          themeMode={user.themeMode}
          accentPalette={user.accentPalette as AccentPaletteId}
          quickReplies={quickReplies}
        />
      }
    />
  );
}
