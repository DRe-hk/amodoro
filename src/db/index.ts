import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import Database from "better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import * as schema from "./schema";

const DB_PATH = resolve(
  /*turbopackIgnore: true*/ (process.env.DB_PATH ?? "./data/amodoro.db"),
);

declare global {
  var __amodoroDb: { sqlite: Database.Database } | undefined;
}

function safeAddColumn(
  sqlite: Database.Database,
  table: string,
  columnDef: string,
) {
  try {
    sqlite.exec(`ALTER TABLE ${table} ADD COLUMN ${columnDef};`);
  } catch {
    // Column already exists
  }
}

function safeExec(sqlite: Database.Database, sqlStr: string) {
  try {
    sqlite.exec(sqlStr);
  } catch {
    // Ignore already exists / index error
  }
}

function bootstrapSchema(sqlite: Database.Database) {
  sqlite.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      pin_hash TEXT NOT NULL DEFAULT '',
      recovery_code_hash TEXT NOT NULL DEFAULT '',
      fcm_token TEXT,
      display_name TEXT NOT NULL DEFAULT '',
      avatar_id TEXT NOT NULL DEFAULT 'cat',
      partner_id INTEGER,
      nickname_by_partner TEXT NOT NULL DEFAULT '',
      theme_mode TEXT NOT NULL DEFAULT 'system',
      accent_palette TEXT NOT NULL DEFAULT 'fig-sage',
      quick_replies_json TEXT NOT NULL DEFAULT '["Te amo","Me alegraste el día","Qué bonito","Te extraño mucho","Me sacaste una sonrisa"]',
      reaction_emojis_json TEXT NOT NULL DEFAULT '["❤️","🥰","🥺","✨","🔥","🫶"]',
      pin_version INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS users_username_idx ON users(username);

    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      last_seen_at INTEGER NOT NULL,
      user_agent TEXT,
      device_id TEXT,
      device_name TEXT
    );

    CREATE TABLE IF NOT EXISTS invite_tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash TEXT NOT NULL,
      code_hash TEXT NOT NULL,
      code_display TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      used_at INTEGER,
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS invite_token_hash_idx ON invite_tokens(token_hash);
    CREATE UNIQUE INDEX IF NOT EXISTS invite_code_hash_idx ON invite_tokens(code_hash);

    CREATE TABLE IF NOT EXISTS media (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      path TEXT NOT NULL,
      mime TEXT NOT NULL,
      bytes INTEGER NOT NULL,
      width INTEGER,
      height INTEGER,
      alt_text TEXT,
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS media_path_idx ON media(path);

    CREATE TABLE IF NOT EXISTS stickers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS stickers_owner_idx ON stickers(owner_id);

    CREATE TABLE IF NOT EXISTS home_cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
      media_type TEXT NOT NULL DEFAULT 'none',
      alt_text TEXT,
      link_url TEXT,
      link_title TEXT,
      link_thumbnail TEXT,
      link_platform TEXT,
      body TEXT NOT NULL,
      bg_color TEXT NOT NULL DEFAULT '#FFDAD6',
      font_family TEXT NOT NULL DEFAULT 'sans',
      font_size TEXT NOT NULL DEFAULT 'md',
      font_size_px INTEGER NOT NULL DEFAULT 18,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS home_cards_author_idx ON home_cards(author_id, created_at);

    CREATE TABLE IF NOT EXISTS home_card_reactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      card_id INTEGER NOT NULL REFERENCES home_cards(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      emoji TEXT,
      preset_text TEXT,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS home_card_reactions_card_idx ON home_card_reactions(card_id);

    CREATE TABLE IF NOT EXISTS home_card_replies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      card_id INTEGER NOT NULL REFERENCES home_cards(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      text_content TEXT NOT NULL DEFAULT '',
      media_type TEXT NOT NULL DEFAULT 'none',
      media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_home_card_replies_card_id ON home_card_replies(card_id);

    CREATE TABLE IF NOT EXISTS boards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      slug TEXT NOT NULL,
      title TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'sparkles',
      bg_color TEXT NOT NULL DEFAULT '#F4EFE8',
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_system INTEGER NOT NULL DEFAULT 0,
      created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS boards_slug_idx ON boards(slug);

    CREATE TABLE IF NOT EXISTS board_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      board_id INTEGER NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
      category_tag TEXT NOT NULL DEFAULT 'PENDIENTE',
      title TEXT NOT NULL,
      notes TEXT,
      url TEXT,
      link_title TEXT,
      link_thumbnail TEXT,
      link_platform TEXT,
      emoji TEXT,
      bg_color TEXT NOT NULL DEFAULT '#FFDAD6',
      media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      due_date TEXT,
      added_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      completed_at INTEGER,
      completed_by INTEGER,
      completion_text TEXT,
      completion_media_id INTEGER,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS board_items_board_idx ON board_items(board_id);

    CREATE TABLE IF NOT EXISTS board_item_reactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL REFERENCES board_items(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      emoji TEXT,
      preset_text TEXT,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS board_item_reactions_item_idx ON board_item_reactions(item_id);

    CREATE TABLE IF NOT EXISTS link_preview_cache (
      url_hash TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT NOT NULL,
      thumbnail TEXT,
      platform TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS decision_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      mode TEXT NOT NULL,
      status TEXT NOT NULL,
      round_number INTEGER NOT NULL DEFAULT 1,
      candidate_item_ids_json TEXT NOT NULL,
      winner_item_id INTEGER REFERENCES board_items(id) ON DELETE SET NULL,
      created_at INTEGER NOT NULL,
      resolved_at INTEGER
    );

    CREATE TABLE IF NOT EXISTS decision_votes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NOT NULL REFERENCES decision_sessions(id) ON DELETE CASCADE,
      round_number INTEGER NOT NULL,
      item_id INTEGER NOT NULL REFERENCES board_items(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      want INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS decision_votes_session_round_idx ON decision_votes(session_id, round_number);
  `);

  // Non-destructive migrations for existing SQLite databases
  safeAddColumn(sqlite, "users", "display_name TEXT NOT NULL DEFAULT ''");
  safeAddColumn(sqlite, "users", "avatar_id TEXT NOT NULL DEFAULT 'cat'");
  safeAddColumn(sqlite, "users", "partner_id INTEGER");
  safeAddColumn(sqlite, "users", "pin_hash TEXT NOT NULL DEFAULT ''");
  safeAddColumn(sqlite, "users", "recovery_code_hash TEXT NOT NULL DEFAULT ''");
  safeAddColumn(sqlite, "users", "fcm_token TEXT");
  safeAddColumn(
    sqlite,
    "users",
    `reaction_emojis_json TEXT NOT NULL DEFAULT '["❤️","🥰","🥺","✨","🔥","🫶"]'`,
  );
  safeAddColumn(sqlite, "media", "alt_text TEXT");
  safeAddColumn(
    sqlite,
    "home_cards",
    "media_type TEXT NOT NULL DEFAULT 'none'",
  );
  safeAddColumn(sqlite, "home_cards", "alt_text TEXT");
  safeAddColumn(sqlite, "home_cards", "link_url TEXT");
  safeAddColumn(sqlite, "home_cards", "link_title TEXT");
  safeAddColumn(sqlite, "home_cards", "link_thumbnail TEXT");
  safeAddColumn(sqlite, "home_cards", "link_platform TEXT");
  safeAddColumn(
    sqlite,
    "home_cards",
    "font_size_px INTEGER NOT NULL DEFAULT 18",
  );
  safeAddColumn(
    sqlite,
    "boards",
    "bg_color TEXT NOT NULL DEFAULT '#F4EFE8'",
  );
  safeAddColumn(sqlite, "boards", "sort_order INTEGER NOT NULL DEFAULT 0");
  safeAddColumn(sqlite, "board_items", "link_title TEXT");
  safeAddColumn(sqlite, "board_items", "link_thumbnail TEXT");
  safeAddColumn(sqlite, "board_items", "link_platform TEXT");
  safeAddColumn(
    sqlite,
    "board_items",
    "bg_color TEXT NOT NULL DEFAULT '#FFDAD6'",
  );
  safeAddColumn(sqlite, "board_items", "sort_order INTEGER NOT NULL DEFAULT 0");
  safeAddColumn(sqlite, "board_items", "due_date TEXT");
  safeAddColumn(sqlite, "board_items", "completed_by INTEGER");
  safeAddColumn(sqlite, "board_items", "completion_text TEXT");
  safeAddColumn(sqlite, "board_items", "completion_media_id INTEGER");
  safeAddColumn(sqlite, "users", "pin_version INTEGER NOT NULL DEFAULT 1");
  safeAddColumn(sqlite, "sessions", "device_id TEXT");
  safeAddColumn(sqlite, "sessions", "device_name TEXT");
  safeExec(
    sqlite,
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_user_device ON sessions(user_id, device_id) WHERE device_id IS NOT NULL;",
  );
  safeExec(
    sqlite,
    `CREATE TABLE IF NOT EXISTS stickers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL
    );`,
  );
  safeExec(
    sqlite,
    "CREATE INDEX IF NOT EXISTS stickers_owner_idx ON stickers(owner_id);",
  );
}

function open(): Database.Database {
  mkdirSync(dirname(DB_PATH), { recursive: true });
  const sqlite = new Database(DB_PATH);
  sqlite.pragma("journal_mode = WAL");
  sqlite.pragma("foreign_keys = ON");
  sqlite.pragma("busy_timeout = 5000");
  sqlite.pragma("synchronous = NORMAL");
  bootstrapSchema(sqlite);
  return sqlite;
}

const handle = (globalThis.__amodoroDb ??= { sqlite: open() });

export const db = drizzle(handle.sqlite, { schema });
export const rawSqlite = handle.sqlite;
export { schema };
