class LinkPreviewModel {
  final String url;
  final String title;
  final String? thumbnail;
  final String platform;

  const LinkPreviewModel({
    required this.url,
    required this.title,
    this.thumbnail,
    required this.platform,
  });

  factory LinkPreviewModel.fromJson(Map<String, dynamic> json) {
    return LinkPreviewModel(
      url: (json['url'] ?? '').toString(),
      title: (json['title'] ?? 'Enlace').toString(),
      thumbnail: json['thumbnail']?.toString(),
      platform: (json['platform'] ?? 'Web').toString(),
    );
  }
}

class UserProfile {
  final int id;
  final String username;
  final String displayName;
  final String avatarId;
  final bool isPaired;
  final bool hasPin;
  final String nicknameByPartner;
  final String partnerNicknameGiven;
  final String themeMode;
  final String accentPalette;
  final List<String> quickReplies;
  final List<String> reactionEmojis;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarId,
    required this.isPaired,
    this.hasPin = false,
    required this.nicknameByPartner,
    required this.partnerNicknameGiven,
    required this.themeMode,
    required this.accentPalette,
    required this.quickReplies,
    required this.reactionEmojis,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['quickReplies'];
    final rawEmojis = json['reactionEmojis'];
    final uname = (json['username'] ?? '').toString();
    final dname = (json['displayName'] ?? '').toString().trim();
    final nickByPartner = (json['nicknameByPartner'] ?? '').toString().trim();
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: uname,
      displayName: dname.isNotEmpty ? dname : uname,
      avatarId: (json['avatarId'] ?? 'cat').toString(),
      isPaired: json['isPaired'] == true,
      hasPin: json['hasPin'] == true,
      nicknameByPartner: nickByPartner.isNotEmpty
          ? nickByPartner
          : (dname.isNotEmpty ? dname : uname),
      partnerNicknameGiven: (json['partnerNicknameGiven'] ?? '').toString(),
      themeMode: (json['themeMode'] ?? 'system').toString(),
      accentPalette: (json['accentPalette'] ?? 'fig-sage').toString(),
      quickReplies: rawReplies is List
          ? rawReplies.map((e) => e.toString()).toList()
          : const ['Te amo', 'Me alegraste el día', 'Qué bonito'],
      reactionEmojis: rawEmojis is List && rawEmojis.isNotEmpty
          ? rawEmojis.map((e) => e.toString()).toList()
          : const ['❤️', '🥰', '🥺', '✨', '🔥', '🫶'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarId': avatarId,
      'isPaired': isPaired,
      'hasPin': hasPin,
      'nicknameByPartner': nicknameByPartner,
      'partnerNicknameGiven': partnerNicknameGiven,
      'themeMode': themeMode,
      'accentPalette': accentPalette,
      'quickReplies': quickReplies,
      'reactionEmojis': reactionEmojis,
    };
  }
}

class AuthStatusResponse {
  final int serverUserCount;
  final bool maxUsersReached;
  final UserProfile? authenticatedUser;

  const AuthStatusResponse({
    required this.serverUserCount,
    required this.maxUsersReached,
    this.authenticatedUser,
  });

  factory AuthStatusResponse.fromJson(Map<String, dynamic> json) {
    final rawAuthUser = json['authenticatedUser'];
    final rawProfiles = json['profiles'];
    final count = (json['serverUserCount'] as num?)?.toInt() ??
        (rawProfiles is List ? rawProfiles.length : 0);
    return AuthStatusResponse(
      serverUserCount: count,
      maxUsersReached: json['maxUsersReached'] == true || count >= 2,
      authenticatedUser: rawAuthUser is Map<String, dynamic>
          ? UserProfile.fromJson(rawAuthUser)
          : null,
    );
  }
}

class PartnerProfile {
  final int id;
  final String username;
  final String displayName;
  final String avatarId;
  final String myGivenNickname;

  const PartnerProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarId,
    required this.myGivenNickname,
  });

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    final uname = (json['username'] ?? '').toString();
    final dname = (json['displayName'] ?? '').toString().trim();
    final nick =
        (json['myGivenNickname'] ?? json['nicknameByPartner'] ?? '')
            .toString()
            .trim();
    return PartnerProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: uname,
      displayName: dname.isNotEmpty ? dname : uname,
      avatarId: (json['avatarId'] ?? 'rabbit').toString(),
      myGivenNickname:
          nick.isNotEmpty ? nick : (dname.isNotEmpty ? dname : uname),
    );
  }
}

class ReactionItem {
  final String id;
  final int userId;
  final String authorLabel;
  final String authorAvatarId;
  final String? emoji;
  final String? presetText;
  final String createdAt;

  const ReactionItem({
    required this.id,
    required this.userId,
    required this.authorLabel,
    required this.authorAvatarId,
    this.emoji,
    this.presetText,
    required this.createdAt,
  });

  factory ReactionItem.fromJson(Map<String, dynamic> json) {
    return ReactionItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
      authorAvatarId: (json['authorAvatarId'] ?? 'cat').toString(),
      emoji: json['emoji']?.toString(),
      presetText: json['presetText']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class CardReplyItem {
  final String id;
  final String cardId;
  final int userId;
  final String authorLabel;
  final String authorAvatarId;
  final bool isMine;
  final String textContent;
  final String mediaType;
  final String? mediaUrl;
  final String createdAt;

  const CardReplyItem({
    required this.id,
    required this.cardId,
    required this.userId,
    required this.authorLabel,
    required this.authorAvatarId,
    required this.isMine,
    required this.textContent,
    this.mediaType = 'none',
    this.mediaUrl,
    required this.createdAt,
  });

  factory CardReplyItem.fromJson(Map<String, dynamic> json) {
    return CardReplyItem(
      id: (json['id'] ?? '').toString(),
      cardId: (json['cardId'] ?? '').toString(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      authorLabel: (json['authorLabel'] ?? 'Yo').toString(),
      authorAvatarId: (json['authorAvatarId'] ?? 'cat').toString(),
      isMine: json['isMine'] == true,
      textContent: (json['textContent'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? 'none').toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class HomeCardItem {
  final String id;
  final int senderId;
  final String authorLabel;
  final String authorAvatarId;
  final bool isMine;
  final String dayKey;
  final String dateHeader;
  final String mediaType;
  final String? mediaUrl;
  final String? altText;
  final String? linkUrl;
  final String? linkTitle;
  final String? linkThumbnail;
  final String? linkPlatform;
  final String textContent;
  final String bgColor;
  final String fontFamily;
  final String fontSize;
  final int fontSizePx;
  final String createdAt;
  final List<ReactionItem> reactions;
  final List<CardReplyItem> replies;

  const HomeCardItem({
    required this.id,
    required this.senderId,
    required this.authorLabel,
    required this.authorAvatarId,
    required this.isMine,
    required this.dayKey,
    required this.dateHeader,
    required this.mediaType,
    this.mediaUrl,
    this.altText,
    this.linkUrl,
    this.linkTitle,
    this.linkThumbnail,
    this.linkPlatform,
    required this.textContent,
    required this.bgColor,
    required this.fontFamily,
    required this.fontSize,
    required this.fontSizePx,
    required this.createdAt,
    required this.reactions,
    this.replies = const [],
  });

  factory HomeCardItem.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    final rawReplies = json['replies'];

    final parsedReactions = rawReactions is List
        ? rawReactions
            .whereType<Map<String, dynamic>>()
            .where((r) => (r['emoji'] ?? '').toString().trim().isNotEmpty)
            .map(ReactionItem.fromJson)
            .toList()
        : const <ReactionItem>[];

    List<CardReplyItem> repliesList = [];
    if (rawReplies is List && rawReplies.isNotEmpty) {
      repliesList = rawReplies
          .whereType<Map<String, dynamic>>()
          .map(CardReplyItem.fromJson)
          .toList();
    } else if (rawReactions is List) {
      for (final r in rawReactions) {
        if (r is Map<String, dynamic>) {
          final pText = (r['presetText'] ?? '').toString().trim();
          if (pText.isNotEmpty) {
            repliesList.add(
              CardReplyItem(
                id: (r['id'] ?? '').toString(),
                cardId: (json['id'] ?? '').toString(),
                userId: (r['userId'] as num?)?.toInt() ?? 0,
                authorLabel: (r['authorLabel'] ?? 'Yo').toString(),
                authorAvatarId: (r['authorAvatarId'] ?? 'cat').toString(),
                isMine: r['isMine'] == true ||
                    (r['authorLabel']?.toString().toUpperCase() == 'YO'),
                textContent: pText,
                mediaType: 'none',
                mediaUrl: null,
                createdAt: (r['createdAt'] ?? '').toString(),
              ),
            );
          }
        }
      }
    }

    return HomeCardItem(
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
      authorAvatarId: (json['authorAvatarId'] ?? 'cat').toString(),
      isMine: json['isMine'] == true,
      dayKey: (json['dayKey'] ?? '').toString(),
      dateHeader: (json['dateHeader'] ?? 'HOY').toString(),
      mediaType: (json['mediaType'] ?? 'none').toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      altText: json['altText']?.toString(),
      linkUrl: json['linkUrl']?.toString(),
      linkTitle: json['linkTitle']?.toString(),
      linkThumbnail: json['linkThumbnail']?.toString(),
      linkPlatform: json['linkPlatform']?.toString(),
      textContent: (json['textContent'] ?? json['body'] ?? '').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      fontFamily: (json['fontFamily'] ?? 'sans').toString(),
      fontSize: (json['fontSize'] ?? 'md').toString(),
      fontSizePx: (json['fontSizePx'] as num?)?.toInt() ?? 18,
      createdAt: (json['createdAt'] ?? '').toString(),
      reactions: parsedReactions,
      replies: repliesList,
    );
  }
}

class BoardCardItem {
  final String id;
  final String boardId;
  final int creatorId;
  final String authorLabel;
  final String authorAvatarId;
  final bool isMine;
  final String categoryTag;
  final String title;
  final String notes;
  final String? url;
  final String? linkTitle;
  final String? linkThumbnail;
  final String? linkPlatform;
  final String? mediaUrl;
  final String? altText;
  final String? dueDate;
  final int sortOrder;
  final String emoji;
  final String bgColor;
  final String status;
  final String createdAt;
  final List<ReactionItem> reactions;

  const BoardCardItem({
    required this.id,
    required this.boardId,
    required this.creatorId,
    required this.authorLabel,
    required this.authorAvatarId,
    required this.isMine,
    required this.categoryTag,
    required this.title,
    required this.notes,
    this.url,
    this.linkTitle,
    this.linkThumbnail,
    this.linkPlatform,
    this.mediaUrl,
    this.altText,
    this.dueDate,
    this.sortOrder = 0,
    required this.emoji,
    required this.bgColor,
    required this.status,
    required this.createdAt,
    this.reactions = const [],
  });

  factory BoardCardItem.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    return BoardCardItem(
      id: (json['id'] ?? '').toString(),
      boardId: (json['boardId'] ?? '').toString(),
      creatorId: (json['creatorId'] as num?)?.toInt() ?? 0,
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
      authorAvatarId: (json['authorAvatarId'] ?? 'cat').toString(),
      isMine: json['isMine'] == true,
      categoryTag: (json['categoryTag'] ?? 'PENDIENTE').toString(),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      url: json['url']?.toString(),
      linkTitle: json['linkTitle']?.toString(),
      linkThumbnail: json['linkThumbnail']?.toString(),
      linkPlatform: json['linkPlatform']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      altText: json['altText']?.toString(),
      dueDate: json['dueDate']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      emoji: (json['emoji'] ?? '').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      status: (json['status'] ?? 'active').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      reactions: rawReactions is List
          ? rawReactions
              .whereType<Map<String, dynamic>>()
              .map(ReactionItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class CompletedActivityItem {
  final String id;
  final String boardId;
  final String categoryTag;
  final String title;
  final String notes;
  final String emoji;
  final String bgColor;
  final String? mediaUrl;
  final String? completionText;
  final String? completionMediaUrl;
  final String completedAt;
  final String completedDateHeader;
  final String completedByLabel;
  final String completedByAvatarId;
  final String authorLabel;
  final String authorAvatarId;
  final List<ReactionItem> reactions;

  const CompletedActivityItem({
    required this.id,
    required this.boardId,
    required this.categoryTag,
    required this.title,
    required this.notes,
    required this.emoji,
    required this.bgColor,
    this.mediaUrl,
    this.completionText,
    this.completionMediaUrl,
    required this.completedAt,
    required this.completedDateHeader,
    required this.completedByLabel,
    required this.completedByAvatarId,
    required this.authorLabel,
    required this.authorAvatarId,
    this.reactions = const [],
  });

  factory CompletedActivityItem.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    return CompletedActivityItem(
      id: (json['id'] ?? '').toString(),
      boardId: (json['boardId'] ?? '').toString(),
      categoryTag: (json['categoryTag'] ?? 'PENDIENTE').toString(),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      completionText: json['completionText']?.toString(),
      completionMediaUrl: json['completionMediaUrl']?.toString(),
      completedAt: (json['completedAt'] ?? '').toString(),
      completedDateHeader: (json['completedDateHeader'] ?? 'HOY').toString(),
      completedByLabel: (json['completedByLabel'] ?? 'YO').toString(),
      completedByAvatarId: (json['completedByAvatarId'] ?? 'cat').toString(),
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
      authorAvatarId: (json['authorAvatarId'] ?? 'cat').toString(),
      reactions: rawReactions is List
          ? rawReactions
              .whereType<Map<String, dynamic>>()
              .map(ReactionItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class DailySummaryModel {
  final int pendingCount;
  final int completedTogetherCount;
  final int receivedTodayCount;

  const DailySummaryModel({
    required this.pendingCount,
    required this.completedTogetherCount,
    required this.receivedTodayCount,
  });

  factory DailySummaryModel.fromJson(Map<String, dynamic> json) {
    return DailySummaryModel(
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      completedTogetherCount:
          (json['completedTogetherCount'] as num?)?.toInt() ?? 0,
      receivedTodayCount: (json['receivedTodayCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BoardModel {
  final String id;
  final String slug;
  final String title;
  final String icon;
  final String bgColor;
  final bool isSystem;
  final int sortOrder;
  final List<BoardCardItem> items;

  const BoardModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.icon,
    required this.bgColor,
    required this.isSystem,
    this.sortOrder = 0,
    required this.items,
  });

  factory BoardModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return BoardModel(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      icon: (json['icon'] ?? 'schedule').toString(),
      bgColor: (json['bgColor'] ?? '#F27166').toString(),
      isSystem: json['isSystem'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(BoardCardItem.fromJson)
              .toList()
          : const [],
    );
  }
}

class DecisionCandidate {
  final String id;
  final String title;
  final String notes;
  final String emoji;
  final String bgColor;
  final String authorLabel;
  final String authorAvatarId;

  const DecisionCandidate({
    required this.id,
    required this.title,
    required this.notes,
    required this.emoji,
    required this.bgColor,
    required this.authorLabel,
    required this.authorAvatarId,
  });

  factory DecisionCandidate.fromJson(Map<String, dynamic> json) {
    return DecisionCandidate(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
      authorAvatarId: (json['authorAvatarId'] ?? 'cat').toString(),
    );
  }
}

class ActiveVotingState {
  final String sessionId;
  final int roundNumber;
  final List<String> candidateIds;
  final List<DecisionCandidate> candidates;
  final bool myVoteSubmitted;
  final bool partnerVoteSubmitted;
  final int totalVotesInRound;

  const ActiveVotingState({
    required this.sessionId,
    required this.roundNumber,
    required this.candidateIds,
    required this.candidates,
    required this.myVoteSubmitted,
    required this.partnerVoteSubmitted,
    required this.totalVotesInRound,
  });

  factory ActiveVotingState.fromJson(Map<String, dynamic> json) {
    final rawIds = json['candidateIds'];
    final rawCandidates = json['candidates'];
    return ActiveVotingState(
      sessionId: (json['sessionId'] ?? '').toString(),
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      candidateIds: rawIds is List
          ? rawIds.map((e) => e.toString()).toList()
          : const [],
      candidates: rawCandidates is List
          ? rawCandidates
              .whereType<Map<String, dynamic>>()
              .map(DecisionCandidate.fromJson)
              .toList()
          : const [],
      myVoteSubmitted: json['myVoteSubmitted'] == true,
      partnerVoteSubmitted: json['partnerVoteSubmitted'] == true,
      totalVotesInRound: (json['totalVotesInRound'] as num?)?.toInt() ?? 0,
    );
  }
}

class LatestResolvedState {
  final String sessionId;
  final String mode;
  final int roundNumber;
  final String? winnerItemId;
  final String? resolvedAt;
  final DecisionCandidate? winner;

  const LatestResolvedState({
    required this.sessionId,
    required this.mode,
    required this.roundNumber,
    this.winnerItemId,
    this.resolvedAt,
    this.winner,
  });

  factory LatestResolvedState.fromJson(Map<String, dynamic> json) {
    final rawWinner = json['winner'];
    return LatestResolvedState(
      sessionId: (json['sessionId'] ?? '').toString(),
      mode: (json['mode'] ?? 'roulette').toString(),
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      winnerItemId: json['winnerItemId']?.toString(),
      resolvedAt: json['resolvedAt']?.toString(),
      winner: rawWinner is Map<String, dynamic>
          ? DecisionCandidate.fromJson(rawWinner)
          : null,
    );
  }
}

class SyncPayload {
  final UserProfile me;
  final PartnerProfile? partner;
  final HomeCardItem? latestPartnerCard;
  final List<HomeCardItem> receivedHistory;
  final List<HomeCardItem> sentHistory;
  final List<String> quickReplies;
  final List<String> reactionEmojis;
  final List<BoardModel> boards;
  final List<CompletedActivityItem> completedHistory;
  final DailySummaryModel? dailySummary;
  final String actividadesBoardId;
  final ActiveVotingState? activeVoting;
  final LatestResolvedState? latestResolved;
  final bool isOffline;

  const SyncPayload({
    required this.me,
    this.partner,
    this.latestPartnerCard,
    required this.receivedHistory,
    required this.sentHistory,
    required this.quickReplies,
    required this.reactionEmojis,
    required this.boards,
    this.completedHistory = const [],
    this.dailySummary,
    required this.actividadesBoardId,
    this.activeVoting,
    this.latestResolved,
    this.isOffline = false,
  });

  SyncPayload copyWith({bool? isOffline}) {
    return SyncPayload(
      me: me,
      partner: partner,
      latestPartnerCard: latestPartnerCard,
      receivedHistory: receivedHistory,
      sentHistory: sentHistory,
      quickReplies: quickReplies,
      reactionEmojis: reactionEmojis,
      boards: boards,
      completedHistory: completedHistory,
      dailySummary: dailySummary,
      actividadesBoardId: actividadesBoardId,
      activeVoting: activeVoting,
      latestResolved: latestResolved,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  factory SyncPayload.fromJson(
    Map<String, dynamic> json, {
    bool isOffline = false,
  }) {
    final meMap = (json['me'] as Map<String, dynamic>?) ?? {};
    final partnerMap = json['partner'] as Map<String, dynamic>?;
    final homeMap = (json['home'] as Map<String, dynamic>?) ?? {};
    final decisionMap = (json['decision'] as Map<String, dynamic>?) ?? {};
    final rawBoards = json['boards'];
    final rawCompleted = json['completedHistory'];
    final rawSummary = json['dailySummary'];
    final rawReceived = homeMap['receivedHistory'];
    final rawSent = homeMap['sentHistory'];
    final rawReplies = homeMap['quickReplies'];
    final rawEmojis = homeMap['reactionEmojis'] ?? meMap['reactionEmojis'];
    final latestCardMap = homeMap['latestPartnerCard'];
    final activeVotingMap = decisionMap['activeVoting'];
    final latestResolvedMap = decisionMap['latestResolved'];

    return SyncPayload(
      me: UserProfile.fromJson(meMap),
      partner:
          partnerMap != null ? PartnerProfile.fromJson(partnerMap) : null,
      latestPartnerCard: latestCardMap is Map<String, dynamic>
          ? HomeCardItem.fromJson(latestCardMap)
          : null,
      receivedHistory: rawReceived is List
          ? rawReceived
              .whereType<Map<String, dynamic>>()
              .map(HomeCardItem.fromJson)
              .toList()
          : const [],
      sentHistory: rawSent is List
          ? rawSent
              .whereType<Map<String, dynamic>>()
              .map(HomeCardItem.fromJson)
              .toList()
          : const [],
      quickReplies: rawReplies is List
          ? rawReplies.map((e) => e.toString()).toList()
          : const ['Te amo', 'Me alegraste el día', 'Qué bonito'],
      reactionEmojis: rawEmojis is List && rawEmojis.isNotEmpty
          ? rawEmojis.map((e) => e.toString()).toList()
          : const ['❤️', '🥰', '🥺', '✨', '🔥', '🫶'],
      boards: rawBoards is List
          ? rawBoards
              .whereType<Map<String, dynamic>>()
              .map(BoardModel.fromJson)
              .toList()
          : const [],
      completedHistory: rawCompleted is List
          ? rawCompleted
              .whereType<Map<String, dynamic>>()
              .map(CompletedActivityItem.fromJson)
              .toList()
          : const [],
      dailySummary: rawSummary is Map<String, dynamic>
          ? DailySummaryModel.fromJson(rawSummary)
          : null,
      actividadesBoardId: (json['actividadesBoardId'] ?? '1').toString(),
      activeVoting: activeVotingMap is Map<String, dynamic>
          ? ActiveVotingState.fromJson(activeVotingMap)
          : null,
      latestResolved: latestResolvedMap is Map<String, dynamic>
          ? LatestResolvedState.fromJson(latestResolvedMap)
          : null,
      isOffline: isOffline || json['isOffline'] == true,
    );
  }
}

class StickerModel {
  final int id;
  final int ownerId;
  final int mediaId;
  final String mediaUrl;
  final String? createdAt;
  final bool isMine;

  const StickerModel({
    required this.id,
    required this.ownerId,
    required this.mediaId,
    required this.mediaUrl,
    this.createdAt,
    this.isMine = false,
  });

  factory StickerModel.fromJson(Map<String, dynamic> json) {
    return StickerModel(
      id: (json['id'] as num?)?.toInt() ??
          int.tryParse(json['id']?.toString() ?? '0') ??
          0,
      ownerId: (json['ownerId'] as num?)?.toInt() ??
          int.tryParse(json['ownerId']?.toString() ?? '0') ??
          0,
      mediaId: (json['mediaId'] as num?)?.toInt() ??
          int.tryParse(json['mediaId']?.toString() ?? '0') ??
          0,
      mediaUrl: (json['mediaUrl'] ?? json['url'] ?? json['path'] ?? '').toString(),
      createdAt: json['createdAt']?.toString(),
      isMine: json['isMine'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'mediaId': mediaId,
      'mediaUrl': mediaUrl,
      'createdAt': createdAt,
      'isMine': isMine,
    };
  }
}
