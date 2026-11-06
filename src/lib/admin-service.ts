import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import {
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, relative, resolve } from "node:path";
import { hashSync } from "@node-rs/argon2";
import Database from "better-sqlite3";
import { desc, eq } from "drizzle-orm";
import { db, rawSqlite } from "@/db";
import {
  boardItemReactions,
  boardItems,
  boards,
  decisionSessions,
  decisionVotes,
  homeCardReactions,
  homeCardReplies,
  homeCards,
  inviteTokens,
  linkPreviewCache,
  media,
  sessions,
  stickers,
  users,
  type AvatarId,
  AVATAR_IDS,
} from "@/db/schema";
import {
  ensureInitialSeed,
  generateReadableShortCode,
  normalizeShortCode,
  sha256,
} from "./auth";
import { UPLOADS_PATH, absoluteUploadPath } from "./media";
import { isFirebaseAdminConfigured } from "./push";

export const BACKUPS_PATH = resolve(
  /*turbopackIgnore: true*/ (process.env.BACKUPS_PATH ?? "./data/backups"),
);

const DB_FILE_PATH = resolve(
  /*turbopackIgnore: true*/ (process.env.DB_PATH ?? "./data/amodoro.db"),
);

export interface SecurityAuditEvent {
  id: number;
  event: string;
  details: string;
  ip: string;
  createdAt: string;
}

const memorySecurityEvents: SecurityAuditEvent[] = [];

function ensureAuditTable() {
  try {
    rawSqlite.exec(`
      CREATE TABLE IF NOT EXISTS admin_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        ip TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL
      );
    `);
  } catch {
    // ignore if readonly or locked
  }
}

export function recordAdminSecurityEvent(
  event: string,
  details?: Record<string, unknown> | string,
  ip = "local",
) {
  ensureAuditTable();
  const createdAt = new Date().toISOString();
  const detailsStr =
    typeof details === "string"
      ? details
      : details
        ? JSON.stringify(details)
        : "";

  let insertedId = Date.now();
  try {
    const info = rawSqlite
      .prepare(
        "INSERT INTO admin_audit_logs (event, details, ip, created_at) VALUES (?, ?, ?, ?)",
      )
      .run(event, detailsStr, ip, createdAt);
    insertedId = Number(info.lastInsertRowid) || insertedId;
  } catch {
    // fallback to memory ring buffer only
  }

  memorySecurityEvents.unshift({
    id: insertedId,
    event,
    details: detailsStr,
    ip,
    createdAt,
  });
  if (memorySecurityEvents.length > 100) {
    memorySecurityEvents.length = 100;
  }
}

export function getRecentSecurityEvents(limit = 50): SecurityAuditEvent[] {
  ensureAuditTable();
  try {
    const rows = rawSqlite
      .prepare(
        "SELECT id, event, details, ip, created_at as createdAt FROM admin_audit_logs ORDER BY id DESC LIMIT ?",
      )
      .all(limit) as SecurityAuditEvent[];
    if (rows.length > 0) {
      return rows;
    }
  } catch {
    // fallback to memory
  }
  return memorySecurityEvents.slice(0, limit);
}

function walkDirectoryStats(dirPath: string): {
  sizeBytes: number;
  fileCount: number;
  files: { fullPath: string; relPath: string; sizeBytes: number; mtime: Date }[];
} {
  if (!existsSync(dirPath)) {
    return { sizeBytes: 0, fileCount: 0, files: [] };
  }
  let sizeBytes = 0;
  let fileCount = 0;
  const files: {
    fullPath: string;
    relPath: string;
    sizeBytes: number;
    mtime: Date;
  }[] = [];

  function walk(current: string) {
    let entries;
    try {
      entries = readdirSync(current, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      const full = join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile()) {
        try {
          const st = statSync(full);
          sizeBytes += st.size;
          fileCount += 1;
          files.push({
            fullPath: full,
            relPath: relative(dirPath, full).replace(/\\/g, "/"),
            sizeBytes: st.size,
            mtime: st.mtime,
          });
        } catch {
          // ignore race condition
        }
      }
    }
  }

  walk(dirPath);
  return { sizeBytes, fileCount, files };
}

function getDatabaseDiskSizeBytes(): number {
  let total = 0;
  for (const suffix of ["", "-wal", "-shm"]) {
    const candidate = `${DB_FILE_PATH}${suffix}`;
    try {
      if (existsSync(/*turbopackIgnore: true*/ candidate)) {
        total += statSync(/*turbopackIgnore: true*/ candidate).size;
      }
    } catch {
      // ignore
    }
  }
  return total;
}

export function listServerSnapshots(): {
  filename: string;
  sizeBytes: number;
  createdAt: string;
}[] {
  mkdirSync(BACKUPS_PATH, { recursive: true });
  let entries;
  try {
    entries = readdirSync(BACKUPS_PATH, { withFileTypes: true });
  } catch {
    return [];
  }

  const snapshots: {
    filename: string;
    sizeBytes: number;
    createdAt: string;
    mtimeMs: number;
  }[] = [];

  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (
      !entry.name.endsWith(".tar.gz") &&
      !entry.name.endsWith(".db")
    ) {
      continue;
    }
    try {
      const full = join(BACKUPS_PATH, entry.name);
      const st = statSync(full);
      snapshots.push({
        filename: entry.name,
        sizeBytes: st.size,
        createdAt: st.mtime.toISOString(),
        mtimeMs: st.mtimeMs,
      });
    } catch {
      // ignore
    }
  }

  snapshots.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return snapshots.map(({ filename, sizeBytes, createdAt }) => ({
    filename,
    sizeBytes,
    createdAt,
  }));
}

function toIsoDate(val: Date | number | string | null | undefined): string {
  if (!val) return new Date(0).toISOString();
  if (val instanceof Date) return val.toISOString();
  if (typeof val === "number") {
    const ms = val < 10_000_000_000 ? val * 1000 : val;
    return new Date(ms).toISOString();
  }
  const parsed = new Date(val);
  return Number.isNaN(parsed.getTime()) ? String(val) : parsed.toISOString();
}

export function getAdminOverview() {
  ensureInitialSeed();
  ensureAuditTable();

  const allUsers = db.select().from(users).orderBy(users.id).all();
  const userById = new Map(allUsers.map((u) => [u.id, u]));
  const allSessions = db.select().from(sessions).all();
  const nowMs = Date.now();

  const activeSessionsByUser = new Map<number, number>();
  for (const s of allSessions) {
    const expMs =
      s.expiresAt instanceof Date
        ? s.expiresAt.getTime()
        : Number(s.expiresAt) * 1000;
    if (expMs > nowMs) {
      activeSessionsByUser.set(
        s.userId,
        (activeSessionsByUser.get(s.userId) ?? 0) + 1,
      );
    }
  }

  const mappedUsers = allUsers.map((u) => {
    const partner = u.partnerId ? userById.get(u.partnerId) : undefined;
    return {
      id: u.id,
      username: u.username,
      displayName: u.displayName || u.username,
      avatarId: u.avatarId,
      hasPin: Boolean(u.pinHash || u.passwordHash),
      hasFcmToken: Boolean(u.fcmToken && u.fcmToken.trim()),
      fcmTokenPreview: u.fcmToken ? `${u.fcmToken.slice(0, 16)}…` : null,
      activeSessionsCount: activeSessionsByUser.get(u.id) ?? 0,
      partnerId: u.partnerId ?? null,
      partnerName: partner ? partner.displayName || partner.username : null,
      partnerNicknameGiven: u.nicknameByPartner || "",
      nicknameByPartner: u.nicknameByPartner || "",
      themeMode: u.themeMode,
      accentPalette: u.accentPalette,
      createdAt: toIsoDate(u.createdAt),
    };
  });

  const dbSizeBytes = getDatabaseDiskSizeBytes();
  const uploadsStats = walkDirectoryStats(UPLOADS_PATH);
  const snapshots = listServerSnapshots();
  const backupsSizeBytes = snapshots.reduce((sum, s) => sum + s.sizeBytes, 0);
  const backupsCount = snapshots.length;
  const firebaseConfigured = isFirebaseAdminConfigured();

  const allCards = db
    .select()
    .from(homeCards)
    .orderBy(desc(homeCards.createdAt), desc(homeCards.id))
    .all();
  const allReplies = db
    .select()
    .from(homeCardReplies)
    .orderBy(desc(homeCardReplies.id))
    .all();
  const allCardReactions = db.select().from(homeCardReactions).all();
  const allBoards = db.select().from(boards).all();
  const boardById = new Map(allBoards.map((b) => [b.id, b]));
  const allBoardItems = db
    .select()
    .from(boardItems)
    .orderBy(desc(boardItems.id))
    .all();
  const allBoardReactions = db.select().from(boardItemReactions).all();
  const allMedia = db
    .select()
    .from(media)
    .orderBy(desc(media.id))
    .all();
  const allLinkCache = db.select().from(linkPreviewCache).all();

  const reactionsByCardId = new Map<number, string[]>();
  for (const r of allCardReactions) {
    if (r.emoji) {
      const list = reactionsByCardId.get(r.cardId) ?? [];
      list.push(r.emoji);
      reactionsByCardId.set(r.cardId, list);
    }
  }

  const repliesCountByCardId = new Map<number, number>();
  for (const rep of allReplies) {
    repliesCountByCardId.set(
      rep.cardId,
      (repliesCountByCardId.get(rep.cardId) ?? 0) + 1,
    );
  }

  const recentHomeCards = allCards.slice(0, 50).map((c) => {
    const sender = userById.get(c.authorId);
    const partner = sender?.partnerId
      ? userById.get(sender.partnerId)
      : allUsers.find((u) => u.id !== c.authorId);
    const createdIso = toIsoDate(c.createdAt);
    const emojis = reactionsByCardId.get(c.id) ?? [];
    return {
      id: c.id,
      authorId: c.authorId,
      senderId: c.authorId,
      senderName: sender ? sender.displayName || sender.username : `User #${c.authorId}`,
      authorName: sender ? sender.displayName || sender.username : `User #${c.authorId}`,
      recipientName: partner
        ? partner.displayName || partner.username
        : "Pareja",
      textContent: c.body,
      body: c.body,
      mediaType: c.mediaType,
      mediaId: c.mediaId ?? null,
      bgColor: c.bgColor,
      dayKey: createdIso.slice(0, 10),
      createdAt: createdIso,
      reactions: emojis,
      emojiReactions: emojis,
      repliesCount: repliesCountByCardId.get(c.id) ?? 0,
    };
  });

  const recentReplies = allReplies.slice(0, 50).map((r) => {
    const author = userById.get(r.userId);
    return {
      id: r.id,
      cardId: r.cardId,
      userId: r.userId,
      authorName: author ? author.displayName || author.username : `User #${r.userId}`,
      textContent: r.textContent,
      mediaType: r.mediaType,
      mediaId: r.mediaId ?? null,
      createdAt: toIsoDate(r.createdAt),
    };
  });

  const mappedBoardItems = allBoardItems.map((item) => {
    const board = boardById.get(item.boardId);
    const creator = userById.get(item.addedBy);
    return {
      id: item.id,
      boardId: item.boardId,
      boardTitle: board?.title ?? "TABLERO",
      creatorId: item.addedBy,
      creatorName: creator
        ? creator.displayName || creator.username
        : `User #${item.addedBy}`,
      title: item.title,
      notes: item.notes ?? null,
      categoryTag: item.categoryTag,
      status: item.completedAt ? ("completed" as const) : ("pending" as const),
      mediaId: item.mediaId ?? null,
      completionText: item.completionText ?? null,
      completionMediaId: item.completionMediaId ?? null,
      completedAt: item.completedAt ? toIsoDate(item.completedAt) : null,
      createdAt: toIsoDate(item.createdAt),
    };
  });

  const referencedMediaIds = new Set<number>();
  for (const c of allCards) {
    if (c.mediaId != null) referencedMediaIds.add(c.mediaId);
  }
  for (const r of allReplies) {
    if (r.mediaId != null) referencedMediaIds.add(r.mediaId);
  }
  for (const bi of allBoardItems) {
    if (bi.mediaId != null) referencedMediaIds.add(bi.mediaId);
    if (bi.completionMediaId != null) {
      referencedMediaIds.add(bi.completionMediaId);
    }
  }

  const mediaItems = allMedia.map((m) => {
    const owner = userById.get(m.ownerId);
    const abs = absoluteUploadPath(m.path);
    let diskBytes = m.bytes;
    let existsOnDisk = false;
    if (abs && existsSync(abs)) {
      try {
        diskBytes = statSync(abs).size;
        existsOnDisk = true;
      } catch {
        existsOnDisk = false;
      }
    }
    return {
      id: m.id,
      ownerId: m.ownerId,
      ownerName: owner ? owner.displayName || owner.username : `User #${m.ownerId}`,
      kind: m.kind,
      mimeType: m.mime,
      mime: m.mime,
      filePath: m.path,
      path: m.path,
      sizeBytes: diskBytes,
      existsOnDisk,
      createdAt: toIsoDate(m.createdAt),
      isReferenced: referencedMediaIds.has(m.id),
    };
  });

  const pendingItemsCount = allBoardItems.filter((i) => !i.completedAt).length;
  const completedItemsCount = allBoardItems.filter((i) => Boolean(i.completedAt)).length;
  const usersCount = allUsers.length;
  const sessionsCount = allSessions.length;
  const homeCardsCount = allCards.length;
  const repliesCount = allReplies.length;
  const reactionsCount = allCardReactions.length + allBoardReactions.length;
  const boardsCount = allBoards.length;
  const mediaCount = allMedia.length;
  const linkCacheCount = allLinkCache.length;

  const recentSessions = allSessions
    .sort((a, b) => {
      const aTime =
        a.lastSeenAt instanceof Date
          ? a.lastSeenAt.getTime()
          : Number(a.lastSeenAt);
      const bTime =
        b.lastSeenAt instanceof Date
          ? b.lastSeenAt.getTime()
          : Number(b.lastSeenAt);
      return bTime - aTime;
    })
    .slice(0, 50)
    .map((s) => ({
      id: s.id,
      userId: s.userId,
      username: userById.get(s.userId)?.username ?? `User #${s.userId}`,
      userAgent: s.userAgent,
      deviceId: s.deviceId,
      deviceName: s.deviceName,
      createdAt: toIsoDate(s.createdAt),
      expiresAt: toIsoDate(s.expiresAt),
      lastSeenAt: toIsoDate(s.lastSeenAt),
    }));

  return {
    users: mappedUsers,
    storage: {
      dbSizeBytes,
      uploadsSizeBytes: uploadsStats.sizeBytes,
      uploadsFileCount: uploadsStats.fileCount,
      backupsSizeBytes,
      backupsCount,
      firebaseConfigured,
    },
    dbSizeBytes,
    uploadsSizeBytes: uploadsStats.sizeBytes,
    uploadsFileCount: uploadsStats.fileCount,
    backupsSizeBytes,
    backupsCount,
    firebaseConfigured,
    counts: {
      usersCount,
      sessionsCount,
      homeCardsCount,
      repliesCount,
      reactionsCount,
      boardsCount,
      pendingItemsCount,
      completedItemsCount,
      mediaCount,
      linkCacheCount,
    },
    usersCount,
    sessionsCount,
    homeCardsCount,
    repliesCount,
    reactionsCount,
    boardsCount,
    pendingItemsCount,
    completedItemsCount,
    mediaCount,
    linkCacheCount,
    recentHomeCards,
    recentReplies,
    recentSessions,
    boardItems: mappedBoardItems,
    mediaItems,
    snapshots,
    securityEvents: getRecentSecurityEvents(50),
  };
}

export function adminResetUserPin(
  userId: number,
  newPin: string,
): { recoveryCode: string } {
  const cleanPin = String(newPin ?? "").trim();
  if (!/^\d{4}$/.test(cleanPin)) {
    throw new Error("El nuevo PIN debe tener exactamente 4 dígitos numéricos.");
  }

  const user = db.select().from(users).where(eq(users.id, userId)).get();
  if (!user) {
    throw new Error("Usuario no encontrado.");
  }

  const newPinHash = hashSync(cleanPin);
  const recoveryCode = generateReadableShortCode();
  const recoveryCodeHash = sha256(normalizeShortCode(recoveryCode));
  const newPinVersion = (user.pinVersion ?? 1) + 1;

  db.update(users)
    .set({
      pinHash: newPinHash,
      passwordHash: newPinHash,
      recoveryCodeHash,
      pinVersion: newPinVersion,
    })
    .where(eq(users.id, userId))
    .run();

  db.delete(sessions).where(eq(sessions.userId, userId)).run();
  recordAdminSecurityEvent("ADMIN_RESET_USER_PIN", { userId });

  return { recoveryCode };
}

export function adminRegenerateRecoveryCode(userId: number): {
  recoveryCode: string;
} {
  const user = db.select().from(users).where(eq(users.id, userId)).get();
  if (!user) {
    throw new Error("Usuario no encontrado.");
  }

  const recoveryCode = generateReadableShortCode();
  const recoveryCodeHash = sha256(normalizeShortCode(recoveryCode));

  db.update(users)
    .set({ recoveryCodeHash })
    .where(eq(users.id, userId))
    .run();

  recordAdminSecurityEvent("ADMIN_REGENERATE_RECOVERY_CODE", { userId });
  return { recoveryCode };
}

export function adminUpdateUser(
  userId: number,
  input: {
    displayName?: string;
    avatarId?: string;
    partnerNicknameGiven?: string;
  },
): void {
  const user = db.select().from(users).where(eq(users.id, userId)).get();
  if (!user) {
    throw new Error("Usuario no encontrado.");
  }

  const updates: Partial<typeof users.$inferInsert> = {};
  if (typeof input.displayName === "string") {
    const clean = input.displayName.trim();
    if (!clean || clean.length > 40) {
      throw new Error("El nombre debe tener entre 1 y 40 caracteres.");
    }
    updates.displayName = clean;
  }

  if (typeof input.avatarId === "string" && input.avatarId.trim()) {
    const candidate = input.avatarId.trim() as AvatarId;
    if ((AVATAR_IDS as readonly string[]).includes(candidate)) {
      updates.avatarId = candidate;
    }
  }

  if (typeof input.partnerNicknameGiven === "string") {
    updates.nicknameByPartner = input.partnerNicknameGiven.trim().slice(0, 40);
  }

  if (Object.keys(updates).length > 0) {
    db.update(users).set(updates).where(eq(users.id, userId)).run();
    recordAdminSecurityEvent("ADMIN_UPDATE_USER", { userId, ...updates });
  }
}

export function adminRevokeSessions(userId: number): number {
  const res = db.delete(sessions).where(eq(sessions.userId, userId)).run();
  recordAdminSecurityEvent("ADMIN_REVOKE_SESSIONS", {
    userId,
    revoked: res.changes,
  });
  return res.changes;
}

export function adminDeleteUser(userId: number): void {
  const tx = rawSqlite.transaction(() => {
    rawSqlite
      .prepare("UPDATE users SET partner_id = NULL WHERE partner_id = ?")
      .run(userId);
    db.delete(sessions).where(eq(sessions.userId, userId)).run();
    db.delete(inviteTokens).where(eq(inviteTokens.userId, userId)).run();
    db.delete(users).where(eq(users.id, userId)).run();
  });
  tx();
  recordAdminSecurityEvent("ADMIN_DELETE_USER", { userId });
}

export function adminPairAllUsers(): boolean {
  const all = db.select().from(users).orderBy(users.id).all();
  if (all.length < 2) {
    return false;
  }
  const [u1, u2] = all;
  if (!u1 || !u2) return false;

  const tx = rawSqlite.transaction(() => {
    db.update(users).set({ partnerId: u2.id }).where(eq(users.id, u1.id)).run();
    db.update(users).set({ partnerId: u1.id }).where(eq(users.id, u2.id)).run();
  });
  tx();
  recordAdminSecurityEvent("ADMIN_PAIR_USERS", {
    userA: u1.id,
    userB: u2.id,
  });
  return true;
}

export function adminUnpairUsers(): void {
  rawSqlite.prepare("UPDATE users SET partner_id = NULL").run();
  recordAdminSecurityEvent("ADMIN_UNPAIR_USERS");
}

export function adminDeleteHomeCard(cardId: number): void {
  const tx = rawSqlite.transaction(() => {
    db.delete(homeCardReplies).where(eq(homeCardReplies.cardId, cardId)).run();
    db.delete(homeCardReactions)
      .where(eq(homeCardReactions.cardId, cardId))
      .run();
    db.delete(homeCards).where(eq(homeCards.id, cardId)).run();
  });
  tx();
  recordAdminSecurityEvent("ADMIN_DELETE_HOME_CARD", { cardId });
}

export function adminDeleteCardReply(replyId: number): void {
  db.delete(homeCardReplies).where(eq(homeCardReplies.id, replyId)).run();
  recordAdminSecurityEvent("ADMIN_DELETE_CARD_REPLY", { replyId });
}

export function adminDeleteBoardItem(itemId: number): void {
  const tx = rawSqlite.transaction(() => {
    db.delete(boardItemReactions)
      .where(eq(boardItemReactions.itemId, itemId))
      .run();
    db.delete(boardItems).where(eq(boardItems.id, itemId)).run();
  });
  tx();
  recordAdminSecurityEvent("ADMIN_DELETE_BOARD_ITEM", { itemId });
}

export function adminDeleteMediaItem(mediaId: number): void {
  const row = db.select().from(media).where(eq(media.id, mediaId)).get();
  const tx = rawSqlite.transaction(() => {
    rawSqlite
      .prepare("UPDATE home_cards SET media_id = NULL WHERE media_id = ?")
      .run(mediaId);
    rawSqlite
      .prepare(
        "UPDATE home_card_replies SET media_id = NULL WHERE media_id = ?",
      )
      .run(mediaId);
    rawSqlite
      .prepare("UPDATE board_items SET media_id = NULL WHERE media_id = ?")
      .run(mediaId);
    rawSqlite
      .prepare(
        "UPDATE board_items SET completion_media_id = NULL WHERE completion_media_id = ?",
      )
      .run(mediaId);
    db.delete(media).where(eq(media.id, mediaId)).run();
  });
  tx();

  if (row) {
    const abs = absoluteUploadPath(row.path);
    if (abs && existsSync(abs)) {
      try {
        unlinkSync(abs);
      } catch {
        // ignore unlink error
      }
    }
  }
  recordAdminSecurityEvent("ADMIN_DELETE_MEDIA", { mediaId });
}

export function adminCleanOrphanMedia(): {
  deletedMediaRows: number;
  deletedDiskFiles: number;
  freedBytes: number;
} {
  const allCards = db.select({ mediaId: homeCards.mediaId }).from(homeCards).all();
  const allReplies = db
    .select({ mediaId: homeCardReplies.mediaId })
    .from(homeCardReplies)
    .all();
  const allBoardItems = db
    .select({
      mediaId: boardItems.mediaId,
      completionMediaId: boardItems.completionMediaId,
    })
    .from(boardItems)
    .all();
  const allStickers = db
    .select({
      mediaId: stickers.mediaId,
    })
    .from(stickers)
    .all();

  const referencedIds = new Set<number>();
  for (const c of allCards) {
    if (c.mediaId != null) referencedIds.add(c.mediaId);
  }
  for (const r of allReplies) {
    if (r.mediaId != null) referencedIds.add(r.mediaId);
  }
  for (const b of allBoardItems) {
    if (b.mediaId != null) referencedIds.add(b.mediaId);
    if (b.completionMediaId != null) referencedIds.add(b.completionMediaId);
  }
  for (const s of allStickers) {
    if (s.mediaId != null) referencedIds.add(s.mediaId);
  }

  const allMedia = db.select().from(media).all();
  let deletedMediaRows = 0;
  let deletedDiskFiles = 0;
  let freedBytes = 0;

  const activeRelativePaths = new Set<string>();

  for (const m of allMedia) {
    if (!referencedIds.has(m.id)) {
      const abs = absoluteUploadPath(m.path);
      if (abs && existsSync(abs)) {
        try {
          const st = statSync(abs);
          unlinkSync(abs);
          freedBytes += st.size;
          deletedDiskFiles += 1;
        } catch {
          // ignore
        }
      }
      db.delete(media).where(eq(media.id, m.id)).run();
      deletedMediaRows += 1;
    } else {
      activeRelativePaths.add(m.path.replace(/\\/g, "/"));
    }
  }

  const diskWalk = walkDirectoryStats(UPLOADS_PATH);
  for (const diskFile of diskWalk.files) {
    if (!activeRelativePaths.has(diskFile.relPath)) {
      try {
        unlinkSync(diskFile.fullPath);
        freedBytes += diskFile.sizeBytes;
        deletedDiskFiles += 1;
      } catch {
        // ignore
      }
    }
  }

  recordAdminSecurityEvent("ADMIN_CLEAN_ORPHANS", {
    deletedMediaRows,
    deletedDiskFiles,
    freedBytes,
  });

  return { deletedMediaRows, deletedDiskFiles, freedBytes };
}

export const cleanOrphanedMedia = adminCleanOrphanMedia;

export function adminClearLinkPreviewCache(): number {
  const res = db.delete(linkPreviewCache).run();
  recordAdminSecurityEvent("ADMIN_CLEAR_LINK_CACHE", {
    cleared: res.changes,
  });
  return res.changes;
}

export function adminExecuteReadOnlySql(sqlQuery: string): {
  columns: string[];
  rows: Record<string, unknown>[];
} {
  if (typeof sqlQuery !== "string" || !sqlQuery.trim()) {
    throw new Error("Escribe una consulta SQL válida.");
  }

  const cleaned = sqlQuery.trim().replace(/;+\s*$/, "").trim();
  if (cleaned.includes(";")) {
    throw new Error(
      "Solo se permite una sentencia de lectura por consulta (sin punto y coma intermedio).",
    );
  }

  if (!/^(SELECT|PRAGMA\s+table_info|EXPLAIN)\b/i.test(cleaned)) {
    throw new Error(
      "Solo se permiten consultas de lectura (SELECT, PRAGMA table_info, EXPLAIN).",
    );
  }

  if (
    /\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE|TRUNCATE|ATTACH|DETACH|VACUUM|REINDEX|ANALYZE|BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|writable_schema)\b/i.test(
      cleaned,
    )
  ) {
    throw new Error(
      "Consulta bloqueada: contiene palabras clave de modificación o administración no permitidas.",
    );
  }

  const stmt = rawSqlite.prepare(cleaned);
  const rawRows = stmt.all() as Record<string, unknown>[];
  const rows = rawRows.slice(0, 200);
  const stmtCols = stmt.columns().map((c) => c.name);
  const columns =
    stmtCols.length > 0
      ? stmtCols
      : rows[0]
        ? Object.keys(rows[0])
        : [];

  return { columns, rows };
}

export async function createHotSqliteBackupBuffer(): Promise<Buffer> {
  const tempFile = join(
    tmpdir(),
    `amodoro-hot-backup-${Date.now()}-${randomUUID()}.db`,
  );
  try {
    await rawSqlite.backup(tempFile);
    return readFileSync(tempFile);
  } finally {
    try {
      if (existsSync(tempFile)) {
        unlinkSync(tempFile);
      }
    } catch {
      // ignore
    }
  }
}

export function exportFullDatabaseJson(): Record<string, unknown> {
  const allUsers = db.select().from(users).all();
  const safeUsers = allUsers.map((u) => {
    const copy = { ...u } as Record<string, unknown>;
    delete copy.passwordHash;
    delete copy.pinHash;
    delete copy.recoveryCodeHash;
    return copy;
  });
  const parejas = allUsers
    .filter((u) => u.partnerId != null && u.id < u.partnerId)
    .map((u) => ({
      userAId: u.id,
      userBId: u.partnerId,
    }));

  return {
    exportedAt: new Date().toISOString(),
    users: safeUsers,
    parejas,
    inviteTokens: db.select().from(inviteTokens).all(),
    boards: db.select().from(boards).all(),
    boardItems: db.select().from(boardItems).all(),
    boardItemReactions: db.select().from(boardItemReactions).all(),
    homeCards: db.select().from(homeCards).all(),
    homeCardReplies: db.select().from(homeCardReplies).all(),
    reactions: db.select().from(homeCardReactions).all(),
    stickers: db.select().from(stickers).all(),
    media: db.select().from(media).all(),
    decisionSessions: db.select().from(decisionSessions).all(),
    decisionVotes: db.select().from(decisionVotes).all(),
  };
}

function formatTimestampForFilename(d = new Date()): string {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}-${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}`;
}

function rotateBackupsDirectory(maxCount = 10) {
  const snapshots = listServerSnapshots();
  if (snapshots.length <= maxCount) return;
  for (const old of snapshots.slice(maxCount)) {
    try {
      const full = join(BACKUPS_PATH, basename(old.filename));
      if (existsSync(full)) {
        unlinkSync(full);
      }
    } catch {
      // ignore
    }
  }
}

export async function createServerSnapshot(): Promise<{
  filename: string;
  sizeBytes: number;
  createdAt: string;
}> {
  mkdirSync(BACKUPS_PATH, { recursive: true });
  const tempDir = mkdtempSync(join(tmpdir(), "amodoro-snap-"));

  try {
    const dbBackupPath = join(tempDir, "amodoro.db");
    await rawSqlite.backup(dbBackupPath);

    if (existsSync(UPLOADS_PATH)) {
      cpSync(UPLOADS_PATH, join(tempDir, "uploads"), { recursive: true });
    }

    const filename = `amodoro-backup-${formatTimestampForFilename()}.tar.gz`;
    const archivePath = join(BACKUPS_PATH, filename);

    execFileSync("tar", ["-czf", archivePath, "-C", tempDir, "."]);
    rotateBackupsDirectory(10);

    const st = statSync(archivePath);
    const meta = {
      filename,
      sizeBytes: st.size,
      createdAt: st.mtime.toISOString(),
    };
    recordAdminSecurityEvent("ADMIN_CREATE_SNAPSHOT", meta);
    return meta;
  } finally {
    try {
      rmSync(tempDir, { recursive: true, force: true });
    } catch {
      // ignore
    }
  }
}

export async function createFullTarGzBuffer(): Promise<Buffer> {
  const snap = await createServerSnapshot();
  const fullPath = join(BACKUPS_PATH, basename(snap.filename));
  return readFileSync(fullPath);
}

export function deleteServerSnapshot(filename: string): void {
  const safe = basename(filename);
  if (
    !safe ||
    safe !== filename ||
    (!safe.endsWith(".tar.gz") && !safe.endsWith(".db"))
  ) {
    throw new Error("Nombre de archivo de respaldo inválido.");
  }
  const full = join(BACKUPS_PATH, safe);
  if (!existsSync(full)) {
    throw new Error("El respaldo solicitado no existe.");
  }
  unlinkSync(full);
  recordAdminSecurityEvent("ADMIN_DELETE_SNAPSHOT", { filename: safe });
}

export function getSnapshotFileBuffer(filename: string): {
  buffer: Buffer;
  safeName: string;
} {
  const safe = basename(filename);
  if (
    !safe ||
    safe !== filename ||
    (!safe.endsWith(".tar.gz") && !safe.endsWith(".db"))
  ) {
    throw new Error("Nombre de archivo de respaldo inválido.");
  }
  const full = join(BACKUPS_PATH, safe);
  if (!existsSync(full)) {
    throw new Error("El respaldo solicitado no existe.");
  }
  return {
    buffer: readFileSync(full),
    safeName: safe,
  };
}

function assertValidSqliteMagicBytes(buf: Buffer) {
  const magic = "SQLite format 3\0";
  if (
    buf.byteLength < 100 ||
    buf.subarray(0, 16).toString("utf8") !== magic
  ) {
    throw new Error(
      "El archivo no es una base de datos SQLite 3 válida (cabecera incorrecta).",
    );
  }
}

function restoreSqliteFromFileIntoLiveDb(sourceDbPath: string) {
  const buf = readFileSync(sourceDbPath);
  assertValidSqliteMagicBytes(buf);

  mkdirSync(BACKUPS_PATH, { recursive: true });
  const safetyPath = join(
    BACKUPS_PATH,
    `pre-restore-${formatTimestampForFilename()}.db`,
  );
  try {
    if (existsSync(DB_FILE_PATH)) {
      cpSync(DB_FILE_PATH, safetyPath);
      rotateBackupsDirectory(10);
    }
  } catch {
    // ignore safety copy failure
  }

  const srcDb = new Database(sourceDbPath, { readonly: true });
  try {
    const tablesToSync = [
      "users",
      "sessions",
      "invite_tokens",
      "media",
      "stickers",
      "home_cards",
      "home_card_reactions",
      "home_card_replies",
      "boards",
      "board_items",
      "board_item_reactions",
      "link_preview_cache",
      "decision_sessions",
      "decision_votes",
    ];

    rawSqlite.pragma("foreign_keys = OFF");
    try {
      const tx = rawSqlite.transaction(() => {
        for (const tableName of tablesToSync) {
          const tableExistsInSrc = srcDb
            .prepare(
              "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
            )
            .get(tableName);
          if (!tableExistsInSrc) continue;

          const targetCols = (
            rawSqlite.prepare(`PRAGMA table_info(${tableName})`).all() as {
              name: string;
            }[]
          ).map((c) => c.name);
          const srcCols = (
            srcDb.prepare(`PRAGMA table_info(${tableName})`).all() as {
              name: string;
            }[]
          ).map((c) => c.name);

          const commonCols = targetCols.filter((c) => srcCols.includes(c));
          if (commonCols.length === 0) continue;

          rawSqlite.prepare(`DELETE FROM ${tableName}`).run();

          const rows = srcDb
            .prepare(
              `SELECT ${commonCols.map((c) => `"${c}"`).join(", ")} FROM ${tableName}`,
            )
            .all() as Record<string, unknown>[];

          if (rows.length > 0) {
            const placeholders = commonCols.map(() => "?").join(", ");
            const insertStmt = rawSqlite.prepare(
              `INSERT INTO ${tableName} (${commonCols.map((c) => `"${c}"`).join(", ")}) VALUES (${placeholders})`,
            );
            for (const row of rows) {
              insertStmt.run(...commonCols.map((c) => row[c]));
            }
          }
        }
      });
      tx();
    } finally {
      rawSqlite.pragma("foreign_keys = ON");
    }

    try {
      rawSqlite.pragma("wal_checkpoint(TRUNCATE)");
    } catch {
      // ignore checkpoint error
    }
  } finally {
    srcDb.close();
  }
}

export function restoreFromUploadedBuffer(
  buffer: Buffer,
  filename: string,
): void {
  const safeName = basename(filename || "upload.db");
  const tempDir = mkdtempSync(join(tmpdir(), "amodoro-restore-"));

  try {
    if (safeName.endsWith(".tar.gz") || safeName.endsWith(".tgz")) {
      const archivePath = join(tempDir, "upload.tar.gz");
      writeFileSync(archivePath, buffer);
      const extractDir = join(tempDir, "extracted");
      mkdirSync(extractDir, { recursive: true });
      execFileSync("tar", ["-xzf", archivePath, "-C", extractDir]);

      const extractedDbPath = join(extractDir, "amodoro.db");
      if (!existsSync(extractedDbPath)) {
        throw new Error(
          "El archivo .tar.gz no contiene amodoro.db en la raíz.",
        );
      }

      restoreSqliteFromFileIntoLiveDb(extractedDbPath);

      const extractedUploads = join(extractDir, "uploads");
      if (existsSync(extractedUploads)) {
        mkdirSync(UPLOADS_PATH, { recursive: true });
        cpSync(extractedUploads, UPLOADS_PATH, {
          recursive: true,
          force: true,
        });
      }
      recordAdminSecurityEvent("ADMIN_RESTORE_TAR_GZ", { filename: safeName });
      return;
    }

    // Default: treat as raw SQLite .db file
    assertValidSqliteMagicBytes(buffer);
    const tempDbPath = join(tempDir, "restore.db");
    writeFileSync(tempDbPath, buffer);
    restoreSqliteFromFileIntoLiveDb(tempDbPath);
    recordAdminSecurityEvent("ADMIN_RESTORE_SQLITE_DB", { filename: safeName });
  } finally {
    try {
      rmSync(tempDir, { recursive: true, force: true });
    } catch {
      // ignore
    }
  }
}

export function restoreFromSnapshot(filename: string): void {
  const { buffer, safeName } = getSnapshotFileBuffer(filename);
  restoreFromUploadedBuffer(buffer, safeName);
}

export function adminListSessions(userId?: number) {
  const allUsers = db.select().from(users).all();
  const userById = new Map(allUsers.map((u) => [u.id, u]));

  const query = db
    .select({
      id: sessions.id,
      userId: sessions.userId,
      createdAt: sessions.createdAt,
      expiresAt: sessions.expiresAt,
      lastSeenAt: sessions.lastSeenAt,
      userAgent: sessions.userAgent,
      deviceId: sessions.deviceId,
      deviceName: sessions.deviceName,
    })
    .from(sessions);

  const rows = userId
    ? query
        .where(eq(sessions.userId, userId))
        .orderBy(desc(sessions.lastSeenAt))
        .all()
    : query.orderBy(desc(sessions.lastSeenAt)).all();

  return rows.map((s) => ({
    id: s.id,
    userId: s.userId,
    username: userById.get(s.userId)?.username ?? `User #${s.userId}`,
    userAgent: s.userAgent,
    deviceId: s.deviceId,
    deviceName: s.deviceName,
    createdAt: toIsoDate(s.createdAt),
    expiresAt: toIsoDate(s.expiresAt),
    lastSeenAt: toIsoDate(s.lastSeenAt),
  }));
}

export function adminPruneOldSessions(keepCount = 2): { prunedCount: number } {
  const allSessions = db
    .select()
    .from(sessions)
    .orderBy(desc(sessions.lastSeenAt))
    .all();

  const byUser = new Map<number, typeof allSessions>();
  for (const s of allSessions) {
    const list = byUser.get(s.userId) ?? [];
    list.push(s);
    byUser.set(s.userId, list);
  }

  let prunedCount = 0;
  for (const [, userSessions] of byUser.entries()) {
    if (userSessions.length > keepCount) {
      const toDelete = userSessions.slice(keepCount);
      for (const s of toDelete) {
        db.delete(sessions).where(eq(sessions.id, s.id)).run();
        prunedCount++;
      }
    }
  }

  recordAdminSecurityEvent("ADMIN_PRUNE_SESSIONS", {
    prunedCount,
    keepCount,
  });
  return { prunedCount };
}

export const pruneOldUserSessions = adminPruneOldSessions;
