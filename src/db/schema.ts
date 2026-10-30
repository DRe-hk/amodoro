import {
  sqliteTable,
  text,
  integer,
  index,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";

export const THEME_MODES = ["light", "dark", "system"] as const;
export type ThemeMode = (typeof THEME_MODES)[number];

export const ACCENT_PALETTE_IDS = [
  "fig-sage",
  "cherry-eucalyptus",
  "camellia-olive",
] as const;
export type AccentPalette = (typeof ACCENT_PALETTE_IDS)[number];

export const CARD_FONTS = ["sans", "serif", "hand", "mono"] as const;
export type CardFont = (typeof CARD_FONTS)[number];

export const CARD_FONT_SIZES = ["sm", "md", "lg", "xl"] as const;
export type CardFontSize = (typeof CARD_FONT_SIZES)[number];

export const AVATAR_IDS = [
  "cat",
  "hippo",
  "dog",
  "rabbit",
  "gray_kitten",
] as const;
export type AvatarId = (typeof AVATAR_IDS)[number];

export const users = sqliteTable(
  "users",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    username: text("username").notNull(),
    passwordHash: text("password_hash").notNull(),
    displayName: text("display_name").notNull().default(""),
    avatarId: text("avatar_id").notNull().default("cat"),
    partnerId: integer("partner_id"),
    /**
     * The nickname that the OTHER person gave to this user.
     * If empty, falls back to displayName or username.
     */
    nicknameByPartner: text("nickname_by_partner").notNull().default(""),
    themeMode: text("theme_mode", { enum: THEME_MODES })
      .notNull()
      .default("system"),
    accentPalette: text("accent_palette", { enum: ACCENT_PALETTE_IDS })
      .notNull()
      .default("fig-sage"),
    quickRepliesJson: text("quick_replies_json")
      .notNull()
      .default(
        JSON.stringify([
          "Te amo",
          "Me alegraste el día",
          "Qué bonito",
          "Te extraño mucho",
          "Me sacaste una sonrisa",
        ]),
      ),
    reactionEmojisJson: text("reaction_emojis_json")
      .notNull()
      .default(
        JSON.stringify(["❤️", "🥰", "🥺", "✨", "🔥", "🫶"]),
      ),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [uniqueIndex("users_username_idx").on(t.username)],
);

export const sessions = sqliteTable("sessions", {
  id: text("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp" }).notNull(),
  lastSeenAt: integer("last_seen_at", { mode: "timestamp" }).notNull(),
  userAgent: text("user_agent"),
});

export const inviteTokens = sqliteTable(
  "invite_tokens",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    userId: integer("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    tokenHash: text("token_hash").notNull(),
    codeHash: text("code_hash").notNull(),
    codeDisplay: text("code_display").notNull(),
    expiresAt: integer("expires_at", { mode: "timestamp" }).notNull(),
    usedAt: integer("used_at", { mode: "timestamp" }),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [
    uniqueIndex("invite_token_hash_idx").on(t.tokenHash),
    uniqueIndex("invite_code_hash_idx").on(t.codeHash),
  ],
);

export const MEDIA_KINDS = ["image", "drawing"] as const;
export type MediaKind = (typeof MEDIA_KINDS)[number];

export const media = sqliteTable(
  "media",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    ownerId: integer("owner_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    kind: text("kind", { enum: MEDIA_KINDS }).notNull(),
    path: text("path").notNull(),
    mime: text("mime").notNull(),
    bytes: integer("bytes").notNull(),
    width: integer("width"),
    height: integer("height"),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [uniqueIndex("media_path_idx").on(t.path)],
);

export const homeCards = sqliteTable(
  "home_cards",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    authorId: integer("author_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    mediaId: integer("media_id").references(() => media.id, {
      onDelete: "set null",
    }),
    mediaType: text("media_type").notNull().default("none"),
    linkUrl: text("link_url"),
    linkTitle: text("link_title"),
    linkThumbnail: text("link_thumbnail"),
    linkPlatform: text("link_platform"),
    body: text("body").notNull(),
    bgColor: text("bg_color").notNull().default("#FFDAD6"),
    fontFamily: text("font_family", { enum: CARD_FONTS })
      .notNull()
      .default("sans"),
    fontSize: text("font_size", { enum: CARD_FONT_SIZES })
      .notNull()
      .default("md"),
    fontSizePx: integer("font_size_px").notNull().default(18),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [index("home_cards_author_idx").on(t.authorId, t.createdAt)],
);

export const homeCardReactions = sqliteTable(
  "home_card_reactions",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    cardId: integer("card_id")
      .notNull()
      .references(() => homeCards.id, { onDelete: "cascade" }),
    userId: integer("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    emoji: text("emoji"),
    presetText: text("preset_text"),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [index("home_card_reactions_card_idx").on(t.cardId)],
);

export const boards = sqliteTable(
  "boards",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    slug: text("slug").notNull(),
    title: text("title").notNull(),
    icon: text("icon").notNull().default("sparkles"),
    bgColor: text("bg_color").notNull().default("#F4EFE8"),
    isSystem: integer("is_system", { mode: "boolean" }).notNull().default(false),
    createdBy: integer("created_by").references(() => users.id, {
      onDelete: "set null",
    }),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [uniqueIndex("boards_slug_idx").on(t.slug)],
);

export const boardItems = sqliteTable(
  "board_items",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    boardId: integer("board_id")
      .notNull()
      .references(() => boards.id, { onDelete: "cascade" }),
    categoryTag: text("category_tag").notNull().default("PENDIENTE"),
    title: text("title").notNull(),
    notes: text("notes"),
    url: text("url"),
    linkTitle: text("link_title"),
    linkThumbnail: text("link_thumbnail"),
    linkPlatform: text("link_platform"),
    emoji: text("emoji"),
    bgColor: text("bg_color").notNull().default("#FFDAD6"),
    mediaId: integer("media_id").references(() => media.id, {
      onDelete: "set null",
    }),
    addedBy: integer("added_by")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    completedAt: integer("completed_at", { mode: "timestamp" }),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [index("board_items_board_idx").on(t.boardId)],
);

export const DECISION_MODES = ["roulette", "voting"] as const;
export type DecisionMode = (typeof DECISION_MODES)[number];

export const DECISION_STATUSES = ["voting", "resolved"] as const;
export type DecisionStatus = (typeof DECISION_STATUSES)[number];

export const decisionSessions = sqliteTable("decision_sessions", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  mode: text("mode", { enum: DECISION_MODES }).notNull(),
  status: text("status", { enum: DECISION_STATUSES }).notNull(),
  roundNumber: integer("round_number").notNull().default(1),
  candidateItemIdsJson: text("candidate_item_ids_json").notNull(),
  winnerItemId: integer("winner_item_id").references(() => boardItems.id, {
    onDelete: "set null",
  }),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  resolvedAt: integer("resolved_at", { mode: "timestamp" }),
});

export const decisionVotes = sqliteTable(
  "decision_votes",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    sessionId: integer("session_id")
      .notNull()
      .references(() => decisionSessions.id, { onDelete: "cascade" }),
    roundNumber: integer("round_number").notNull(),
    itemId: integer("item_id")
      .notNull()
      .references(() => boardItems.id, { onDelete: "cascade" }),
    userId: integer("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    want: integer("want", { mode: "boolean" }).notNull(),
    createdAt: integer("created_at", { mode: "timestamp" }).notNull(),
  },
  (t) => [
    index("decision_votes_session_round_idx").on(t.sessionId, t.roundNumber),
  ],
);
