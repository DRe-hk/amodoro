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
  final String nicknameByPartner;
  final String partnerNicknameGiven;
  final String themeMode;
  final String accentPalette;
  final List<String> quickReplies;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarId,
    required this.isPaired,
    required this.nicknameByPartner,
    required this.partnerNicknameGiven,
    required this.themeMode,
    required this.accentPalette,
    required this.quickReplies,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['quickReplies'];
    final uname = (json['username'] ?? '').toString();
    final dname = (json['displayName'] ?? '').toString().trim();
    final nickByPartner = (json['nicknameByPartner'] ?? '').toString().trim();
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: uname,
      displayName: dname.isNotEmpty ? dname : uname,
      avatarId: (json['avatarId'] ?? 'cat').toString(),
      isPaired: json['isPaired'] == true,
      nicknameByPartner: nickByPartner.isNotEmpty
          ? nickByPartner
          : (dname.isNotEmpty ? dname : uname),
      partnerNicknameGiven: (json['partnerNicknameGiven'] ?? '').toString(),
      themeMode: (json['themeMode'] ?? 'light').toString(),
      accentPalette: (json['accentPalette'] ?? 'fig-sage').toString(),
      quickReplies: rawReplies is List
          ? rawReplies.map((e) => e.toString()).toList()
          : const ['Te amo', 'Me alegraste el día', 'Qué bonito'],
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
  });

  factory HomeCardItem.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
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
      reactions: rawReactions is List
          ? rawReactions
              .whereType<Map<String, dynamic>>()
              .map(ReactionItem.fromJson)
              .toList()
          : const [],
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
  final String emoji;
  final String bgColor;
  final String status;
  final String createdAt;

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
    required this.emoji,
    required this.bgColor,
    required this.status,
    required this.createdAt,
  });

  factory BoardCardItem.fromJson(Map<String, dynamic> json) {
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
      emoji: (json['emoji'] ?? '').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      status: (json['status'] ?? 'active').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
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
  final List<BoardCardItem> items;

  const BoardModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.icon,
    required this.bgColor,
    required this.isSystem,
    required this.items,
  });

  factory BoardModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return BoardModel(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      icon: (json['icon'] ?? 'schedule').toString(),
      bgColor: (json['bgColor'] ?? '#F4EFE8').toString(),
      isSystem: json['isSystem'] == true,
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
  final List<BoardModel> boards;
  final String actividadesBoardId;
  final ActiveVotingState? activeVoting;
  final LatestResolvedState? latestResolved;

  const SyncPayload({
    required this.me,
    this.partner,
    this.latestPartnerCard,
    required this.receivedHistory,
    required this.sentHistory,
    required this.quickReplies,
    required this.boards,
    required this.actividadesBoardId,
    this.activeVoting,
    this.latestResolved,
  });

  factory SyncPayload.fromJson(Map<String, dynamic> json) {
    final meMap = (json['me'] as Map<String, dynamic>?) ?? {};
    final partnerMap = json['partner'] as Map<String, dynamic>?;
    final homeMap = (json['home'] as Map<String, dynamic>?) ?? {};
    final decisionMap = (json['decision'] as Map<String, dynamic>?) ?? {};
    final rawBoards = json['boards'];
    final rawReceived = homeMap['receivedHistory'];
    final rawSent = homeMap['sentHistory'];
    final rawReplies = homeMap['quickReplies'];
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
      boards: rawBoards is List
          ? rawBoards
              .whereType<Map<String, dynamic>>()
              .map(BoardModel.fromJson)
              .toList()
          : const [],
      actividadesBoardId: (json['actividadesBoardId'] ?? '1').toString(),
      activeVoting: activeVotingMap is Map<String, dynamic>
          ? ActiveVotingState.fromJson(activeVotingMap)
          : null,
      latestResolved: latestResolvedMap is Map<String, dynamic>
          ? LatestResolvedState.fromJson(latestResolvedMap)
          : null,
    );
  }
}
