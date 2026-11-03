import { getAllUsers, getPartnerUser } from "@/lib/auth";
import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import {
  listBoardsWithItems,
  listCompletedBoardItems,
  type BoardItemReactionRow,
} from "@/lib/boards";
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

  let limit = 100;
  let offset = 0;
  try {
    const { searchParams } = new URL(request.url);
    const l = Number(searchParams.get("limit"));
    const o = Number(searchParams.get("offset"));
    if (Number.isInteger(l) && l > 0 && l <= 200) limit = l;
    if (Number.isInteger(o) && o >= 0) offset = o;
  } catch {
    // keep defaults
  }

  const allUsers = getAllUsers();
  const userById = new Map(allUsers.map((u) => [u.id, u]));
  const partner = getPartnerUser(user.id);
  const isPaired = Boolean(partner && user.partnerId);

  const { latest, history } = getReceivedHomeCards(user.id, { limit, offset });
  const sentRaw = getSentHomeCards(user.id, { limit, offset });
  const { boards, itemsByBoardId, actividadesBoardId } = listBoardsWithItems(
    user.id,
  );
  const completedRaw = listCompletedBoardItems(user.id);
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
    const parsedEmojis = JSON.parse(
      user.reactionEmojisJson || '["❤️","🥰","🥺","✨","🔥","🫶"]',
    );
    if (Array.isArray(parsedEmojis) && parsedEmojis.length > 0) {
      reactionEmojis = parsedEmojis;
    }
  } catch {
    // keep default
  }

  const serializeReaction = (r: {
    id: number;
    userId: number;
    emoji: string | null;
    presetText: string | null;
    createdAt: Date;
  }) => {
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
  };

  const serializeCard = (c: HydratedHomeCard) => {
    const authorLabel = formatAuthorLabel({
      authorId: c.authorId,
      viewerId: user.id,
      authorNicknameGivenByPartner: c.authorNicknameByPartner,
      authorDisplayName: c.authorDisplayName,
      authorUsername: c.authorUsername,
    });
    const mediaUrl = c.mediaId ? `/api/media/${c.mediaId}` : null;
    const resolvedType = c.linkUrl
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
      altText: c.altText ?? null,
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
      reactions: c.reactions.map(serializeReaction),
      replies: c.replies ?? [],
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
      bgColor: b.bgColor || "#F27166",
      sortOrder: b.sortOrder ?? 0,
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
        sortOrder: item.sortOrder ?? 0,
        dueDate: item.dueDate ?? null,
        status: item.completedAt ? "completed" : "active",
        createdAt: item.createdAt.toISOString(),
        reactions: item.reactions.map((r: BoardItemReactionRow) =>
          serializeReaction(r),
        ),
      })),
    };
  });

  const completedHistory = completedRaw.map((item) => {
    const completer = item.completedBy
      ? userById.get(item.completedBy)
      : undefined;
    const completedDate = item.completedAt ?? item.createdAt;
    const completionMediaUrl = item.completionMediaId
      ? `/api/media/${item.completionMediaId}`
      : item.mediaId
        ? `/api/media/${item.mediaId}`
        : null;

    return {
      id: String(item.id),
      boardId: String(item.boardId),
      categoryTag: item.categoryTag || "PENDIENTE",
      title: item.title,
      notes: item.notes ?? "",
      emoji: item.emoji ?? "",
      bgColor: item.bgColor || "#FFDAD6",
      mediaUrl: item.mediaId ? `/api/media/${item.mediaId}` : null,
      completionText: item.completionText ?? item.notes ?? "",
      completionMediaUrl,
      completedAt: completedDate.toISOString(),
      completedDateHeader: formatSpanishDateHeader(completedDate),
      completedByLabel: completer
        ? formatAuthorLabel({
            authorId: completer.id,
            viewerId: user.id,
            authorNicknameGivenByPartner: completer.nicknameByPartner,
            authorDisplayName: completer.displayName,
            authorUsername: completer.username,
          })
        : "YO",
      completedByAvatarId: completer?.avatarId || "cat",
      authorLabel: formatAuthorLabel({
        authorId: item.addedBy,
        viewerId: user.id,
        authorNicknameGivenByPartner: item.addedByNickname,
        authorDisplayName: item.addedByDisplayName,
        authorUsername: item.addedByUsername,
      }),
      authorAvatarId: item.addedByAvatarId || "cat",
      reactions: item.reactions.map((r: BoardItemReactionRow) =>
        serializeReaction(r),
      ),
    };
  });

  const todayKey = new Date().toISOString().slice(0, 10);
  const pendingItems = itemsByBoardId[actividadesBoardId] ?? [];
  const upcomingDueItems = Object.values(itemsByBoardId)
    .flat()
    .filter((i) => Boolean(i.dueDate))
    .slice(0, 5)
    .map((i) => ({
      id: String(i.id),
      title: i.title,
      dueDate: i.dueDate,
      categoryTag: i.categoryTag,
    }));

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
      hasPin: Boolean(user.pinHash && user.pinHash.length > 0),
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
    completedHistory,
    dailySummary: {
      pendingCount: pendingItems.length,
      completedTogetherCount: completedHistory.length,
      receivedTodayCount: allReceived.filter((c) => c.dayKey === todayKey)
        .length,
      upcomingDueItems,
    },
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
