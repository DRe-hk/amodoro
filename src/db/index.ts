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

function bootstrapSchema(sqlite: Database.Database) {
  sqlite.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      display_name TEXT NOT NULL DEFAULT '',
      avatar_id TEXT NOT NULL DEFAULT 'cat',
      partner_id INTEGER,
      nickname_by_partner TEXT NOT NULL DEFAULT '',
      theme_mode TEXT NOT NULL DEFAULT 'light',
      accent_palette TEXT NOT NULL DEFAULT 'fig-sage',
      quick_replies_json TEXT NOT NULL DEFAULT '["Te amo","Me alegraste el día","Qué bonito","Te extraño mucho","Me sacaste una sonrisa"]',
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS users_username_idx ON users(username);

    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      last_seen_at INTEGER NOT NULL,
      user_agent TEXT
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
      created_at INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS media_path_idx ON media(path);

    CREATE TABLE IF NOT EXISTS home_cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      media_id INTEGER REFERENCES media(id) ON DELETE SET NULL,
      media_type TEXT NOT NULL DEFAULT 'none',
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

    CREATE TABLE IF NOT EXISTS boards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      slug TEXT NOT NULL,
      title TEXT NOT NULL,
      icon TEXT NOT NULL DEFAULT 'sparkles',
      bg_color TEXT NOT NULL DEFAULT '#F4EFE8',
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
      added_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      completed_at INTEGER,
      created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS board_items_board_idx ON board_items(board_id);

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
  safeAddColumn(
    sqlite,
    "home_cards",
    "media_type TEXT NOT NULL DEFAULT 'none'",
  );
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
  safeAddColumn(sqlite, "board_items", "link_title TEXT");
  safeAddColumn(sqlite, "board_items", "link_thumbnail TEXT");
  safeAddColumn(sqlite, "board_items", "link_platform TEXT");
  safeAddColumn(
    sqlite,
    "board_items",
    "bg_color TEXT NOT NULL DEFAULT '#FFDAD6'",
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
