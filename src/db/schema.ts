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

export const users = sqliteTable(
  "users",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    username: text("username").notNull(),
    passwordHash: text("password_hash").notNull(),
    /**
     * The nickname that the OTHER person gave to this user.
     * - In Settings, this user can see: "El apodo que te puso tu pareja: <nicknameByPartner>".
     * - When this user's posts are shown to the partner, the partner sees `<nicknameByPartner>`.
     * - When this user views their own posts, they ALWAYS see "YO".
     */
    nicknameByPartner: text("nickname_by_partner").notNull().default("Amor"),
    themeMode: text("theme_mode", { enum: THEME_MODES }).notNull().default("light"),
    accentPalette: text("accent_palette", { enum: ACCENT_PALETTE_IDS })
      .notNull()
      .default("fig-sage"),
    quickRepliesJson: text("quick_replies_json")
      .notNull()
      .default(
        JSON.stringify([
          "Te amo ❤️",
          "Me alegraste el día ✨",
          "Qué bonito 🥺",
          "Te extraño mucho 💌",
          "Me sacaste una sonrisa 🥰",
        ]),
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
    body: text("body").notNull(),
    bgColor: text("bg_color").notNull().default("#FADADD"),
    fontFamily: text("font_family", { enum: CARD_FONTS })
      .notNull()
      .default("sans"),
    fontSize: text("font_size", { enum: CARD_FONT_SIZES })
      .notNull()
      .default("md"),
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
    categoryTag: text("category_tag").notNull().default("IDEA"),
    title: text("title").notNull(),
    notes: text("notes"),
    url: text("url"),
    emoji: text("emoji"),
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
  /** JSON array of 4 or 5 candidate item IDs in the current round */
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
