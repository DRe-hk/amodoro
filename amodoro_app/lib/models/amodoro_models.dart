class AuthProfileOption {
  final int id;
  final String username;
  final String partnerNickname;

  const AuthProfileOption({
    required this.id,
    required this.username,
    required this.partnerNickname,
  });

  factory AuthProfileOption.fromJson(Map<String, dynamic> json) {
    return AuthProfileOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      partnerNickname:
          (json['partnerNickname'] ?? json['nicknameByPartner'] ?? '')
              .toString(),
    );
  }
}

class UserProfile {
  final int id;
  final String username;
  final String nicknameByPartner;
  final String partnerNicknameGiven;
  final String themeMode;
  final String accentPalette;
  final List<String> quickReplies;

  const UserProfile({
    required this.id,
    required this.username,
    required this.nicknameByPartner,
    required this.partnerNicknameGiven,
    required this.themeMode,
    required this.accentPalette,
    required this.quickReplies,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['quickReplies'];
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      nicknameByPartner: (json['nicknameByPartner'] ?? 'Amor').toString(),
      partnerNicknameGiven:
          (json['partnerNicknameGiven'] ?? 'Mi Persona').toString(),
      themeMode: (json['themeMode'] ?? 'light').toString(),
      accentPalette: (json['accentPalette'] ?? 'sage_fig').toString(),
      quickReplies: rawReplies is List
          ? rawReplies.map((e) => e.toString()).toList()
          : const ['Te amo ❤️', '¡Qué lindo! 🥰', '¡Sí, hagámoslo! ✨'],
    );
  }
}

class PartnerProfile {
  final int id;
  final String username;
  final String myGivenNickname;

  const PartnerProfile({
    required this.id,
    required this.username,
    required this.myGivenNickname,
  });

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    return PartnerProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      username: (json['username'] ?? '').toString(),
      myGivenNickname: (json['myGivenNickname'] ?? 'Tu Pareja').toString(),
    );
  }
}

class ReactionItem {
  final String id;
  final int userId;
  final String authorLabel;
  final String? emoji;
  final String? presetText;
  final String createdAt;

  const ReactionItem({
    required this.id,
    required this.userId,
    required this.authorLabel,
    this.emoji,
    this.presetText,
    required this.createdAt,
  });

  factory ReactionItem.fromJson(Map<String, dynamic> json) {
    return ReactionItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
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
  final bool isMine;
  final String dayKey;
  final String dateHeader;
  final String mediaType;
  final String? mediaUrl;
  final String textContent;
  final String bgColor;
  final String fontFamily;
  final String fontSize;
  final String createdAt;
  final List<ReactionItem> reactions;

  const HomeCardItem({
    required this.id,
    required this.senderId,
    required this.authorLabel,
    required this.isMine,
    required this.dayKey,
    required this.dateHeader,
    required this.mediaType,
    this.mediaUrl,
    required this.textContent,
    required this.bgColor,
    required this.fontFamily,
    required this.fontSize,
    required this.createdAt,
    required this.reactions,
  });

  factory HomeCardItem.fromJson(Map<String, dynamic> json) {
    final rawReactions = json['reactions'];
    return HomeCardItem(
      id: (json['id'] ?? '').toString(),
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
      isMine: json['isMine'] == true,
      dayKey: (json['dayKey'] ?? '').toString(),
      dateHeader: (json['dateHeader'] ?? 'HOY').toString(),
      mediaType: (json['mediaType'] ?? 'none').toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      textContent: (json['textContent'] ?? '').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      fontFamily: (json['fontFamily'] ?? 'sans').toString(),
      fontSize: (json['fontSize'] ?? 'md').toString(),
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
  final bool isMine;
  final String title;
  final String notes;
  final String emoji;
  final String bgColor;
  final String status;
  final String createdAt;

  const BoardCardItem({
    required this.id,
    required this.boardId,
    required this.creatorId,
    required this.authorLabel,
    required this.isMine,
    required this.title,
    required this.notes,
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
      isMine: json['isMine'] == true,
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      emoji: (json['emoji'] ?? '✨').toString(),
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
  final bool isSystem;
  final List<BoardCardItem> items;

  const BoardModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.icon,
    required this.isSystem,
    required this.items,
  });

  factory BoardModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return BoardModel(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      icon: (json['icon'] ?? '📌').toString(),
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

  const DecisionCandidate({
    required this.id,
    required this.title,
    required this.notes,
    required this.emoji,
    required this.bgColor,
    required this.authorLabel,
  });

  factory DecisionCandidate.fromJson(Map<String, dynamic> json) {
    return DecisionCandidate(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      emoji: (json['emoji'] ?? '🎲').toString(),
      bgColor: (json['bgColor'] ?? '#FFDAD6').toString(),
      authorLabel: (json['authorLabel'] ?? 'YO').toString(),
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
          : const ['Te amo ❤️', '¡Qué lindo! 🥰', '¡Sí, hagámoslo! ✨'],
      boards: rawBoards is List
          ? rawBoards
              .whereType<Map<String, dynamic>>()
              .map(BoardModel.fromJson)
              .toList()
          : const [],
      actividadesBoardId: (json['actividadesBoardId'] ?? '').toString(),
      activeVoting: activeVotingMap is Map<String, dynamic>
          ? ActiveVotingState.fromJson(activeVotingMap)
          : null,
      latestResolved: latestResolvedMap is Map<String, dynamic>
          ? LatestResolvedState.fromJson(latestResolvedMap)
          : null,
    );
  }
}
