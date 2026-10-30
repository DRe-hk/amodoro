import { getAllUsers, getPartnerUser } from "@/lib/auth";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { listBoardsWithItems } from "@/lib/boards";
import { getCurrentDecisionState } from "@/lib/decision";
import {
  getReceivedHomeCards,
  getSentHomeCards,
  type HydratedHomeCard,
} from "@/lib/home-cards";
import { formatAuthorLabel, formatSpanishDateHeader } from "@/lib/identity";

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: CORS_HEADERS });
}

export async function GET(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  const allUsers = getAllUsers();
  const userById = new Map(allUsers.map((u) => [u.id, u]));
  const partner = getPartnerUser(user.id);
  const isPaired = Boolean(partner && user.partnerId);

  const { latest, history } = getReceivedHomeCards(user.id);
  const sentRaw = getSentHomeCards(user.id);
  const { boards, itemsByBoardId, actividadesBoardId } = listBoardsWithItems();
  const decision = getCurrentDecisionState(user.id);

  let quickReplies: string[] = [
    "Te amo",
    "Me alegraste el día",
    "Qué bonito",
    "Te extraño mucho",
    "Me sacaste una sonrisa",
  ];
  try {
    const parsed = JSON.parse(user.quickRepliesJson);
    if (Array.isArray(parsed)) {
      quickReplies = parsed;
    }
  } catch {
    // keep default
  }

  let reactionEmojis: string[] = ["❤️", "🥰", "🥺", "✨", "🔥", "🫶"];
  try {
    const parsedEmojis = JSON.parse(user.reactionEmojisJson || '["❤️","🥰","🥺","✨","🔥","🫶"]');
    if (Array.isArray(parsedEmojis) && parsedEmojis.length > 0) {
      reactionEmojis = parsedEmojis;
    }
  } catch {
    // keep default
  }

  const serializeCard = (c: HydratedHomeCard) => {
    const authorLabel = formatAuthorLabel({
      authorId: c.authorId,
      viewerId: user.id,
      authorNicknameGivenByPartner: c.authorNicknameByPartner,
      authorDisplayName: c.authorDisplayName,
      authorUsername: c.authorUsername,
    });
    const mediaUrl = c.mediaId ? `/api/media/${c.mediaId}` : null;
    const resolvedType =
      c.linkUrl
        ? "link"
        : c.mediaId
          ? c.mediaType === "drawing"
            ? "drawing"
            : "photo"
          : "none";

    return {
      id: String(c.id),
      senderId: c.authorId,
      authorLabel,
      authorAvatarId: c.authorAvatarId || "cat",
      isMine: c.authorId === user.id,
      dayKey: c.createdAt.toISOString().slice(0, 10),
      dateHeader: formatSpanishDateHeader(c.createdAt),
      mediaType: resolvedType,
      mediaUrl,
      linkUrl: c.linkUrl ?? null,
      linkTitle: c.linkTitle ?? null,
      linkThumbnail: c.linkThumbnail ?? null,
      linkPlatform: c.linkPlatform ?? null,
      textContent: c.body,
      body: c.body,
      bgColor: c.bgColor,
      fontFamily: c.fontFamily,
      fontSize: c.fontSize,
      fontSizePx: c.fontSizePx || 18,
      createdAt: c.createdAt.toISOString(),
      reactions: c.reactions.map((r) => {
        const rxAuthor = userById.get(r.userId);
        return {
          id: String(r.id),
          userId: r.userId,
          authorLabel: formatAuthorLabel({
            authorId: r.userId,
            viewerId: user.id,
            authorNicknameGivenByPartner: rxAuthor?.nicknameByPartner,
            authorDisplayName: rxAuthor?.displayName,
            authorUsername: rxAuthor?.username,
          }),
          authorAvatarId: rxAuthor?.avatarId || "cat",
          emoji: r.emoji,
          presetText: r.presetText,
          createdAt: r.createdAt.toISOString(),
        };
      }),
    };
  };

  const allReceived = [
    ...(latest ? [serializeCard(latest)] : []),
    ...history.map(serializeCard),
  ];
  const sentSerialized = sentRaw.map(serializeCard);

  const hydratedBoards = boards.map((b) => {
    const rawItems = itemsByBoardId[b.id] ?? [];
    return {
      id: String(b.id),
      slug: b.slug,
      title: b.title,
      icon: b.icon,
      bgColor: b.bgColor || "#F4EFE8",
      isSystem: b.isSystem,
      items: rawItems.map((item) => ({
        id: String(item.id),
        boardId: String(item.boardId),
        creatorId: item.addedBy,
        authorLabel: formatAuthorLabel({
          authorId: item.addedBy,
          viewerId: user.id,
          authorNicknameGivenByPartner: item.addedByNickname,
          authorDisplayName: item.addedByDisplayName,
          authorUsername: item.addedByUsername,
        }),
        authorAvatarId: item.addedByAvatarId || "cat",
        isMine: item.addedBy === user.id,
        categoryTag: item.categoryTag || "PENDIENTE",
        title: item.title,
        notes: item.notes ?? "",
        url: item.url ?? null,
        linkTitle: item.linkTitle ?? null,
        linkThumbnail: item.linkThumbnail ?? null,
        linkPlatform: item.linkPlatform ?? null,
        mediaUrl: item.mediaId ? `/api/media/${item.mediaId}` : null,
        emoji: item.emoji ?? "",
        bgColor: item.bgColor || "#FFDAD6",
        status: item.completedAt ? "completed" : "active",
        createdAt: item.createdAt.toISOString(),
      })),
    };
  });

  const partnerGivenNickname =
    partner?.nicknameByPartner?.trim() ||
    partner?.displayName?.trim() ||
    partner?.username ||
    "Pareja";

  const myDisplayName = user.displayName?.trim() || user.username;
  const myNicknameByPartner =
    user.nicknameByPartner?.trim() || myDisplayName;

  return jsonResponse({
    ok: true,
    me: {
      id: user.id,
      username: user.username,
      displayName: myDisplayName,
      avatarId: user.avatarId || "cat",
      isPaired,
      nicknameByPartner: myNicknameByPartner,
      partnerNicknameGiven: partner?.nicknameByPartner?.trim() ?? "",
      themeMode: user.themeMode,
      accentPalette: user.accentPalette,
      quickReplies,
      reactionEmojis,
    },
    partner: partner
      ? {
          id: partner.id,
          username: partner.username,
          displayName: partner.displayName?.trim() || partner.username,
          avatarId: partner.avatarId || "rabbit",
          myGivenNickname: partnerGivenNickname,
        }
      : null,
    home: {
      latestPartnerCard: allReceived[0] ?? null,
      receivedHistory: allReceived,
      sentHistory: sentSerialized,
      quickReplies,
      reactionEmojis,
    },
    boards: hydratedBoards,
    actividadesBoardId: String(actividadesBoardId),
    decision: {
      activeVoting:
        decision && decision.status === "voting"
          ? {
              sessionId: String(decision.id),
              roundNumber: decision.roundNumber,
              candidateIds: decision.candidates.map((c) => String(c.id)),
              candidates: decision.candidates.map((c) => ({
                id: String(c.id),
                title: c.title,
                notes: c.notes ?? "",
                emoji: c.emoji ?? "",
                bgColor: "#FFDAD6",
                authorLabel: "PENDIENTE",
                authorAvatarId: "cat",
              })),
              myVoteSubmitted: decision.mySubmittedVotes !== null,
              partnerVoteSubmitted: decision.partnerHasVoted,
              totalVotesInRound:
                (decision.mySubmittedVotes !== null ? 1 : 0) +
                (decision.partnerHasVoted ? 1 : 0),
            }
          : null,
      latestResolved:
        decision && decision.status === "resolved"
          ? {
              sessionId: String(decision.id),
              mode: decision.mode,
              roundNumber: decision.roundNumber,
              winnerItemId: decision.winner
                ? String(decision.winner.id)
                : null,
              resolvedAt: new Date().toISOString(),
              winner: decision.winner
                ? {
                    id: String(decision.winner.id),
                    title: decision.winner.title,
                    notes: decision.winner.notes ?? "",
                    emoji: decision.winner.emoji ?? "",
                    bgColor: "#FFDAD6",
                    authorLabel: "PENDIENTE",
                    authorAvatarId: "cat",
                  }
                : null,
            }
          : null,
    },
  });
}
