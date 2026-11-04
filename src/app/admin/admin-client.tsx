/* eslint-disable @next/next/no-img-element */
"use client";

import React, { useCallback, useEffect, useState } from "react";

export interface AdminUserSummary {
  id: number;
  username: string;
  displayName: string;
  avatarId: string;
  hasPin: boolean;
  hasFcmToken: boolean;
  activeSessionsCount: number;
  partnerId: number | null;
  partnerName: string | null;
  partnerNicknameGiven: string;
  createdAt: string;
}

export interface AdminOverview {
  users: AdminUserSummary[];
  storage: {
    dbSizeBytes: number;
    uploadsSizeBytes: number;
    uploadsFileCount: number;
    backupsSizeBytes: number;
    backupsCount: number;
    firebaseConfigured: boolean;
  };
  counts: {
    usersCount: number;
    sessionsCount: number;
    homeCardsCount: number;
    repliesCount: number;
    reactionsCount: number;
    boardsCount: number;
    pendingItemsCount: number;
    completedItemsCount: number;
    mediaCount: number;
    linkCacheCount: number;
  };
  recentHomeCards: Array<{
    id: number;
    senderId: number;
    senderName: string;
    recipientId: number;
    recipientName: string;
    dayKey: string;
    mediaType: string;
    mediaId: number | null;
    textContent: string;
    bgColor: string;
    reactionsCount: number;
    repliesCount: number;
    createdAt: string;
  }>;
  recentReplies: Array<{
    id: number;
    cardId: number;
    userId: number;
    authorName: string;
    textContent: string;
    mediaType: string;
    mediaId: number | null;
    createdAt: string;
  }>;
  boardItems: Array<{
    id: number;
    boardId: number;
    boardTitle: string;
    creatorId: number;
    creatorName: string;
    categoryTag: string;
    title: string;
    notes: string;
    status: string;
    mediaId: number | null;
    completionText: string | null;
    completionMediaId: number | null;
    completedAt: string | null;
    createdAt: string;
  }>;
  mediaItems: Array<{
    id: number;
    ownerId: number | null;
    ownerName: string;
    kind: string;
    mimeType: string;
    filePath: string;
    sizeBytes: number;
    isReferenced: boolean;
    createdAt: string;
  }>;
  snapshots: Array<{
    filename: string;
    sizeBytes: number;
    createdAt: string;
  }>;
  securityEvents: Array<{
    timestamp: string;
    event: string;
    ip?: string;
    detail?: string;
  }>;
}

type MainTab = "overview" | "backups" | "content" | "sql";
type ContentSubTab = "cards" | "replies" | "boards" | "media";

const AVATAR_OPTIONS: Array<{ id: string; label: string; emoji: string }> = [
  { id: "cat", label: "Gatito Naranja", emoji: "🐱" },
  { id: "dog", label: "Perrito", emoji: "🐶" },
  { id: "rabbit", label: "Conejito", emoji: "🐰" },
  { id: "bear", label: "Osito", emoji: "🐻" },
  { id: "fox", label: "Zorrito", emoji: "🦊" },
  { id: "panda", label: "Panda", emoji: "🐼" },
  { id: "chick", label: "Pollito", emoji: "🐥" },
  { id: "gray_kitten", label: "Gatito Gris", emoji: "🐈‍⬛" },
];

const SQL_PRESETS: Array<{ label: string; sql: string }> = [
  {
    label: "Usuarios",
    sql: "SELECT id, username, display_name, avatar_id, partner_id, created_at FROM users ORDER BY id ASC;",
  },
  {
    label: "Sesiones",
    sql: "SELECT id, user_id, expires_at, created_at FROM sessions ORDER BY created_at DESC LIMIT 25;",
  },
  {
    label: "Tarjetas",
    sql: "SELECT id, sender_id, recipient_id, day_key, media_type, media_id, substr(text_content, 1, 80) AS text_preview, created_at FROM home_cards ORDER BY id DESC LIMIT 30;",
  },
  {
    label: "Respuestas",
    sql: "SELECT id, card_id, user_id, media_type, media_id, substr(text_content, 1, 80) AS text_preview, created_at FROM card_replies ORDER BY id DESC LIMIT 30;",
  },
  {
    label: "Tableros",
    sql: "SELECT id, board_id, creator_id, category_tag, title, status, completed_at, created_at FROM board_items ORDER BY id DESC LIMIT 40;",
  },
  {
    label: "Conteo de Tablas",
    sql: "SELECT 'users' AS tabla, COUNT(*) AS total FROM users UNION ALL SELECT 'sessions', COUNT(*) FROM sessions UNION ALL SELECT 'home_cards', COUNT(*) FROM home_cards UNION ALL SELECT 'card_replies', COUNT(*) FROM card_replies UNION ALL SELECT 'board_items', COUNT(*) FROM board_items UNION ALL SELECT 'media', COUNT(*) FROM media;",
  },
];

function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const idx = Math.min(
    Math.floor(Math.log(bytes) / Math.log(1024)),
    units.length - 1
  );
  const val = bytes / Math.pow(1024, idx);
  return `${val.toFixed(idx === 0 ? 0 : 1)} ${units[idx]}`;
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("es-ES", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function getAvatarEmoji(avatarId: string): string {
  return AVATAR_OPTIONS.find((a) => a.id === avatarId)?.emoji ?? "🐾";
}

export default function AdminDashboardClient() {
  const [loading, setLoading] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [overview, setOverview] = useState<AdminOverview | null>(null);

  // Login form
  const [loginPassword, setLoginPassword] = useState("");
  const [busyAction, setBusyAction] = useState<string | null>(null);

  // Feedback banner
  const [banner, setBanner] = useState<{
    type: "success" | "error" | "info";
    text: string;
    recoveryCode?: string;
  } | null>(null);

  // Navigation tabs
  const [activeTab, setActiveTab] = useState<MainTab>("overview");
  const [contentSubTab, setContentSubTab] = useState<ContentSubTab>("cards");

  // User inline forms state
  const [editingUser, setEditingUser] = useState<{
    userId: number;
    displayName: string;
    avatarId: string;
  } | null>(null);
  const [pinResetUser, setPinResetUser] = useState<{
    userId: number;
    username: string;
    newPin: string;
  } | null>(null);
  const [pushTestUser, setPushTestUser] = useState<{
    userId: number;
    username: string;
    title: string;
    body: string;
  } | null>(null);

  // Upload restore state
  const [restoreFile, setRestoreFile] = useState<File | null>(null);

  // SQL Explorer state
  const [sqlQuery, setSqlQuery] = useState<string>(SQL_PRESETS[0].sql);
  const [sqlResult, setSqlResult] = useState<{
    columns: string[];
    rows: Record<string, unknown>[];
  } | null>(null);

  // Change admin password state
  const [currentAdminPassword, setCurrentAdminPassword] = useState("");
  const [newAdminPassword, setNewAdminPassword] = useState("");

  // Image lightbox state
  const [lightboxMediaId, setLightboxMediaId] = useState<number | null>(null);

  const fetchOverview = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch("/api/admin", {
        method: "GET",
        cache: "no-store",
      });
      const data = await res.json().catch(() => null);
      if (res.ok && data?.authenticated && data?.overview) {
        setAuthenticated(true);
        setOverview(data.overview as AdminOverview);
      } else {
        setAuthenticated(false);
        setOverview(null);
      }
    } catch {
      setBanner({
        type: "error",
        text: "No se pudo conectar con /api/admin.",
      });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const res = await fetch("/api/admin", {
          method: "GET",
          cache: "no-store",
        });
        const data = await res.json().catch(() => null);
        if (cancelled) return;
        if (res.ok && data?.authenticated && data?.overview) {
          setAuthenticated(true);
          setOverview(data.overview as AdminOverview);
        } else {
          setAuthenticated(false);
          setOverview(null);
        }
      } catch {
        if (!cancelled) {
          setBanner({
            type: "error",
            text: "No se pudo conectar con /api/admin.",
          });
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function runAction(
    actionKey: string,
    payload: Record<string, unknown>,
    successMsg?: string
  ) {
    setBusyAction(actionKey);
    setBanner(null);
    try {
      const res = await fetch("/api/admin", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data?.ok) {
        if (res.status === 401 && payload.action !== "login") {
          setAuthenticated(false);
          setOverview(null);
        }
        setBanner({
          type: "error",
          text:
            data?.error ||
            data?.message ||
            `Error al ejecutar ${String(payload.action)} (${res.status})`,
        });
        return null;
      }

      if (data.overview) {
        setOverview(data.overview as AdminOverview);
      }
      if (successMsg) {
        setBanner({
          type: "success",
          text: successMsg,
          recoveryCode:
            typeof data.recoveryCode === "string"
              ? data.recoveryCode
              : undefined,
        });
      }
      return data;
    } catch {
      setBanner({
        type: "error",
        text: "Error de red al comunicarse con el servidor.",
      });
      return null;
    } finally {
      setBusyAction(null);
    }
  }

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault();
    if (!loginPassword.trim()) return;
    const data = await runAction("login", {
      action: "login",
      password: loginPassword,
    });
    if (data?.ok) {
      setAuthenticated(true);
      setLoginPassword("");
      setBanner({
        type: "success",
        text: "Sesión de administrador iniciada.",
      });
    }
  }

  async function handleLogout() {
    await runAction("logout", { action: "logout" });
    setAuthenticated(false);
    setOverview(null);
  }

  async function handleRestoreUpload(e: React.FormEvent) {
    e.preventDefault();
    if (!restoreFile) return;
    const confirmed = window.confirm(
      `¿Seguro que deseas restaurar el archivo "${restoreFile.name}"? Esto reemplazará los datos actuales del servidor.`
    );
    if (!confirmed) return;

    setBusyAction("restore_upload");
    try {
      const arrayBuffer = await restoreFile.arrayBuffer();
      const bytes = new Uint8Array(arrayBuffer);
      let binary = "";
      const chunkSize = 0x8000;
      for (let i = 0; i < bytes.length; i += chunkSize) {
        binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
      }
      const base64Data = window.btoa(binary);

      const data = await runAction(
        "restore_upload",
        {
          action: "restore_upload",
          filename: restoreFile.name,
          base64Data,
        },
        `Backup "${restoreFile.name}" restaurado correctamente.`
      );
      if (data?.ok) {
        setRestoreFile(null);
      }
    } catch {
      setBanner({
        type: "error",
        text: "No se pudo leer o subir el archivo de backup.",
      });
      setBusyAction(null);
    }
  }

  async function handleRunSql(e?: React.FormEvent, customSql?: string) {
    if (e) e.preventDefault();
    const queryToRun = (customSql ?? sqlQuery).trim();
    if (!queryToRun) return;
    const data = await runAction("run_sql", {
      action: "run_sql",
      sql: queryToRun,
    });
    if (data?.result) {
      setSqlResult(data.result);
    }
  }

  async function handleChangeAdminPassword(e: React.FormEvent) {
    e.preventDefault();
    if (!currentAdminPassword || !newAdminPassword) return;
    const data = await runAction(
      "change_admin_password",
      {
        action: "change_admin_password",
        currentPassword: currentAdminPassword,
        newPassword: newAdminPassword,
      },
      "Contraseña de administrador actualizada correctamente."
    );
    if (data?.ok) {
      setCurrentAdminPassword("");
      setNewAdminPassword("");
    }
  }

  const salmonPrimaryBtn =
    "inline-flex items-center justify-center gap-2 rounded-full bg-[#F27166] px-5 py-2.5 text-sm font-bold text-white border-[2px] border-[#473A3A] shadow-[0_3.5px_0_0_#D6574D] transition-all hover:brightness-105 active:translate-y-[2px] active:shadow-[0_1.5px_0_0_#D6574D] disabled:opacity-50 disabled:pointer-events-none cursor-pointer";

  const creamSecondaryBtn =
    "inline-flex items-center justify-center gap-1.5 rounded-full bg-[#FAF8F5] px-4 py-2 text-xs font-bold text-[#473A3A] border-[2px] border-[#473A3A] shadow-[0_3px_0_0_#D8CFC6] transition-all hover:bg-[#F3EDE4] active:translate-y-[2px] active:shadow-[0_1px_0_0_#D8CFC6] disabled:opacity-50 disabled:pointer-events-none cursor-pointer";

  const dangerPillBtn =
    "inline-flex items-center justify-center gap-1.5 rounded-full bg-[#FFE5E2] px-3.5 py-1.5 text-xs font-bold text-[#A8201A] border-[2px] border-[#E07A72] shadow-[0_2.5px_0_0_#E07A72] transition-all hover:bg-[#FFD4CF] active:translate-y-[1.5px] active:shadow-none disabled:opacity-50 cursor-pointer";

  const neoCard =
    "rounded-3xl bg-white border-[2.5px] border-[#E6DDD4] shadow-[0_4px_0_0_#E6DDD4] p-5 sm:p-6";

  if (loading && !overview) {
    return (
      <div className="min-h-screen bg-[#FAF8F5] text-[#473A3A] flex items-center justify-center p-6">
        <div className={`${neoCard} max-w-md w-full text-center py-10`}>
          <div className="inline-flex h-14 w-14 items-center justify-center rounded-full bg-[#FFE3DE] border-[2.5px] border-[#473A3A] text-2xl mb-4 animate-bounce">
            🐾
          </div>
          <h1 className="text-xl font-extrabold tracking-tight">
            Cargando amodoro Admin…
          </h1>
          <p className="text-sm text-[#7A6B6B] mt-1">
            Verificando sesión y estado del servidor
          </p>
        </div>
      </div>
    );
  }

  if (!authenticated || !overview) {
    return (
      <div className="min-h-screen bg-[#FAF8F5] text-[#473A3A] flex items-center justify-center p-6">
        <div className={`${neoCard} max-w-md w-full`}>
          <div className="flex items-center gap-3 mb-5">
            <div className="h-12 w-12 rounded-2xl bg-[#F27166] border-[2.5px] border-[#473A3A] shadow-[0_3px_0_0_#D6574D] flex items-center justify-center text-white text-xl font-black">
              ♥
            </div>
            <div>
              <span className="inline-block rounded-full bg-[#FFF0ED] border border-[#F27166] px-2.5 py-0.5 text-[11px] font-extrabold uppercase tracking-wider text-[#C84B40]">
                Acceso Privado
              </span>
              <h1 className="text-2xl font-extrabold tracking-tight text-[#473A3A]">
                amodoro · Admin
              </h1>
            </div>
          </div>

          <p className="text-sm text-[#6E5E5E] mb-6 leading-relaxed">
            Ingresa la contraseña maestra (`ADMIN_PASSWORD`) para administrar
            usuarios, backups SQLite, fotos y diagnósticos del servidor.
          </p>

          {banner && (
            <div
              className={`mb-5 rounded-2xl border-[2px] p-3.5 text-xs font-bold ${
                banner.type === "error"
                  ? "bg-[#FFE8E5] border-[#E06D64] text-[#9E241B]"
                  : "bg-[#E6F7ED] border-[#68B888] text-[#165B33]"
              }`}
            >
              {banner.text}
            </div>
          )}

          <form onSubmit={handleLogin} className="space-y-4">
            <div>
              <label className="block text-xs font-extrabold uppercase tracking-wider text-[#6E5E5E] mb-1.5">
                Contraseña de Administrador
              </label>
              <input
                type="password"
                required
                autoFocus
                value={loginPassword}
                onChange={(e) => setLoginPassword(e.target.value)}
                placeholder="••••••••••••"
                className="w-full rounded-2xl bg-[#FAF8F5] border-[2.5px] border-[#473A3A] px-4 py-3 text-sm font-semibold text-[#473A3A] placeholder:text-[#A89B9B] focus:outline-none focus:ring-2 focus:ring-[#F27166]"
              />
            </div>

            <button
              type="submit"
              disabled={busyAction === "login"}
              className={`${salmonPrimaryBtn} w-full py-3 text-base`}
            >
              {busyAction === "login"
                ? "Verificando…"
                : "Entrar al Panel de Control"}
            </button>
          </form>
        </div>
      </div>
    );
  }

  const usersPaired =
    overview.users.length === 2 &&
    overview.users[0].partnerId === overview.users[1].id &&
    overview.users[1].partnerId === overview.users[0].id;

  return (
    <div className="min-h-screen bg-[#FAF8F5] text-[#473A3A] pb-20">
      {/* Top Header */}
      <header className="sticky top-0 z-30 bg-[#FAF8F5]/95 backdrop-blur border-b-[2.5px] border-[#E6DDD4]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3.5 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-2xl bg-[#F27166] border-[2px] border-[#473A3A] shadow-[0_2.5px_0_0_#D6574D] flex items-center justify-center text-white text-lg font-black">
              ♥
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-lg sm:text-xl font-extrabold tracking-tight">
                  amodoro · Admin Dashboard
                </h1>
                <span className="hidden sm:inline-block rounded-full bg-[#E5F6EC] border border-[#68B888] px-2.5 py-0.5 text-[11px] font-extrabold text-[#196036]">
                  ONLINE
                </span>
              </div>
              <p className="text-xs text-[#7A6B6B]">
                Gestión integral de cuentas, tarjetas, backups y base de datos
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <button
              type="button"
              onClick={() => void fetchOverview()}
              disabled={loading || busyAction !== null}
              className={creamSecondaryBtn}
            >
              🔄 Actualizar
            </button>
            <button
              type="button"
              onClick={() => void handleLogout()}
              disabled={busyAction === "logout"}
              className={dangerPillBtn}
            >
              🚪 Salir
            </button>
          </div>
        </div>

        {/* Navigation Pill Tabs */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 pb-3 flex items-center gap-2 overflow-x-auto no-scrollbar">
          {(
            [
              { id: "overview", label: "📊 Resumen y Usuarios" },
              { id: "backups", label: "💾 Backups y Base de Datos" },
              { id: "content", label: "🗂️ Actividad y Contenido" },
              { id: "sql", label: "🔍 Consola SQL y Seguridad" },
            ] as Array<{ id: MainTab; label: string }>
          ).map((tab) => {
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={
                  active
                    ? `${salmonPrimaryBtn} !py-2 !px-4 !text-xs sm:!text-sm shrink-0`
                    : `${creamSecondaryBtn} !py-2 !px-4 !text-xs sm:!text-sm shrink-0`
                }
              >
                {tab.label}
              </button>
            );
          })}
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 pt-6 space-y-6">
        {/* Global Status / Alert Banner */}
        {banner && (
          <div
            className={`rounded-3xl border-[2.5px] p-4 flex flex-wrap items-center justify-between gap-3 ${
              banner.type === "error"
                ? "bg-[#FFE8E5] border-[#D9534F] text-[#8C1D18]"
                : banner.type === "info"
                  ? "bg-[#FFF8E6] border-[#E0A82E] text-[#664600]"
                  : "bg-[#E6F7ED] border-[#52A874] text-[#14532D]"
            }`}
          >
            <div className="space-y-1">
              <p className="text-sm font-extrabold">{banner.text}</p>
              {banner.recoveryCode && (
                <div className="flex flex-wrap items-center gap-2 pt-1">
                  <span className="text-xs font-bold">
                    Código de recuperación de 8 caracteres:
                  </span>
                  <code className="rounded-xl bg-white border-[2px] border-[#473A3A] px-3 py-1 font-mono text-sm font-black tracking-widest text-[#473A3A]">
                    {banner.recoveryCode}
                  </code>
                  <button
                    type="button"
                    onClick={() => {
                      void navigator.clipboard?.writeText(
                        banner.recoveryCode || ""
                      );
                    }}
                    className={creamSecondaryBtn}
                  >
                    📋 Copiar Código
                  </button>
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={() => setBanner(null)}
              className="rounded-full px-3 py-1 text-xs font-extrabold hover:bg-black/5 cursor-pointer"
            >
              ✕ Cerrar
            </button>
          </div>
        )}

        {/* TAB 1: RESUMEN Y USUARIOS */}
        {activeTab === "overview" && (
          <div className="space-y-6">
            {/* KPI Grid: Storage & Activity */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className={neoCard}>
                <span className="text-xs font-extrabold uppercase tracking-wider text-[#8C7B7B]">
                  🗄️ Base de datos SQLite
                </span>
                <p className="text-2xl font-black mt-1">
                  {formatBytes(overview.storage.dbSizeBytes)}
                </p>
                <p className="text-xs text-[#7A6B6B] mt-1">
                  Modo WAL activo · {overview.counts.sessionsCount} sesiones
                </p>
              </div>

              <div className={neoCard}>
                <span className="text-xs font-extrabold uppercase tracking-wider text-[#8C7B7B]">
                  🖼️ Fotos y Dibujos en Disco
                </span>
                <p className="text-2xl font-black mt-1">
                  {formatBytes(overview.storage.uploadsSizeBytes)}
                </p>
                <p className="text-xs text-[#7A6B6B] mt-1">
                  {overview.storage.uploadsFileCount} archivos en{" "}
                  <code>data/uploads/</code>
                </p>
              </div>

              <div className={neoCard}>
                <span className="text-xs font-extrabold uppercase tracking-wider text-[#8C7B7B]">
                  📦 Snapshots de Backup
                </span>
                <p className="text-2xl font-black mt-1">
                  {overview.storage.backupsCount} snapshots
                </p>
                <p className="text-xs text-[#7A6B6B] mt-1">
                  {formatBytes(overview.storage.backupsSizeBytes)} en{" "}
                  <code>data/backups/</code>
                </p>
              </div>

              <div className={neoCard}>
                <span className="text-xs font-extrabold uppercase tracking-wider text-[#8C7B7B]">
                  🔔 Estado FCM Push
                </span>
                <div className="mt-1.5 flex items-center gap-2">
                  <span
                    className={`inline-block rounded-full px-3 py-1 text-xs font-extrabold border-[2px] ${
                      overview.storage.firebaseConfigured
                        ? "bg-[#E5F6EC] border-[#52A874] text-[#14532D]"
                        : "bg-[#FFF3CD] border-[#D9A441] text-[#664600]"
                    }`}
                  >
                    {overview.storage.firebaseConfigured
                      ? "Firebase Configurado"
                      : "Sin Credenciales FCM"}
                  </span>
                </div>
                <p className="text-xs text-[#7A6B6B] mt-2">
                  {overview.users.filter((u) => u.hasFcmToken).length}/
                  {overview.users.length} dispositivos con token
                </p>
              </div>
            </div>

            {/* Activity KPIs */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
              <div className={`${neoCard} !p-4 bg-[#FFF7F5]`}>
                <span className="text-xs font-extrabold text-[#8C7B7B]">
                  👫 Usuarios
                </span>
                <p className="text-xl font-black mt-0.5">
                  {overview.counts.usersCount} / 2
                </p>
              </div>
              <div className={`${neoCard} !p-4 bg-[#FFF7F5]`}>
                <span className="text-xs font-extrabold text-[#8C7B7B]">
                  💌 Tarjetas HOME
                </span>
                <p className="text-xl font-black mt-0.5">
                  {overview.counts.homeCardsCount}{" "}
                  <span className="text-xs font-semibold text-[#7A6B6B]">
                    ({overview.counts.reactionsCount} reacciones)
                  </span>
                </p>
              </div>
              <div className={`${neoCard} !p-4 bg-[#FFF7F5]`}>
                <span className="text-xs font-extrabold text-[#8C7B7B]">
                  💬 Respuestas
                </span>
                <p className="text-xl font-black mt-0.5">
                  {overview.counts.repliesCount}
                </p>
              </div>
              <div className={`${neoCard} !p-4 bg-[#FFF7F5]`}>
                <span className="text-xs font-extrabold text-[#8C7B7B]">
                  📌 Pendientes / Historial
                </span>
                <p className="text-xl font-black mt-0.5">
                  {overview.counts.pendingItemsCount} /{" "}
                  {overview.counts.completedItemsCount}
                </p>
              </div>
            </div>

            {/* Couple Pairing Card */}
            <div className={`${neoCard} flex flex-wrap items-center justify-between gap-4`}>
              <div className="flex items-center gap-3.5">
                <div className="h-12 w-12 rounded-2xl bg-[#FFE3DE] border-[2px] border-[#473A3A] flex items-center justify-center text-2xl">
                  💞
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-base font-extrabold">
                      Vínculo de Pareja (2 Cuentas)
                    </h2>
                    <span
                      className={`rounded-full px-2.5 py-0.5 text-xs font-extrabold border ${
                        usersPaired
                          ? "bg-[#E5F6EC] border-[#52A874] text-[#14532D]"
                          : "bg-[#FFF3CD] border-[#D9A441] text-[#664600]"
                      }`}
                    >
                      {usersPaired ? "Vinculados" : "Sin vincular"}
                    </span>
                  </div>
                  <p className="text-xs text-[#7A6B6B] mt-0.5">
                    {overview.users.length === 2
                      ? `${overview.users[0].displayName} (@${overview.users[0].username}) ↔ ${overview.users[1].displayName} (@${overview.users[1].username})`
                      : `Actualmente hay ${overview.users.length} cuenta(s) registrada(s). Se requieren 2 cuentas para vincular pareja.`}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2">
                {overview.users.length === 2 && !usersPaired && (
                  <button
                    type="button"
                    disabled={busyAction === "pair_users"}
                    onClick={() =>
                      void runAction(
                        "pair_users",
                        { action: "pair_users" },
                        "Las 2 cuentas han sido vinculadas como pareja."
                      )
                    }
                    className={salmonPrimaryBtn}
                  >
                    🔗 Vincular Pareja
                  </button>
                )}
                {usersPaired && (
                  <button
                    type="button"
                    disabled={busyAction === "unpair_users"}
                    onClick={() =>
                      void runAction(
                        "unpair_users",
                        { action: "unpair_users" },
                        "Las cuentas fueron desvinculadas."
                      )
                    }
                    className={creamSecondaryBtn}
                  >
                    ✂️ Desvincular
                  </button>
                )}
              </div>
            </div>

            {/* User Management Cards */}
            <div className="space-y-3">
              <h2 className="text-lg font-extrabold tracking-tight">
                👥 Gestión de Usuarios ({overview.users.length}/2 Cuentas)
              </h2>

              {overview.users.length === 0 ? (
                <div className={`${neoCard} text-center py-8 text-sm text-[#7A6B6B]`}>
                  Aún no hay usuarios registrados en la base de datos.
                </div>
              ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
                  {overview.users.map((u) => {
                    const isEditing = editingUser?.userId === u.id;
                    const isResettingPin = pinResetUser?.userId === u.id;
                    const isTestingPush = pushTestUser?.userId === u.id;

                    return (
                      <div key={u.id} className={`${neoCard} space-y-4`}>
                        <div className="flex items-start justify-between gap-3">
                          <div className="flex items-center gap-3">
                            <div className="h-14 w-14 rounded-2xl bg-[#FFF0ED] border-[2.5px] border-[#473A3A] flex items-center justify-center text-3xl">
                              {getAvatarEmoji(u.avatarId)}
                            </div>
                            <div>
                              <div className="flex items-center gap-2 flex-wrap">
                                <h3 className="text-lg font-extrabold">
                                  {u.displayName}
                                </h3>
                                <span className="rounded-full bg-[#F3EDE4] px-2.5 py-0.5 text-xs font-bold text-[#6E5E5E]">
                                  @{u.username} · ID #{u.id}
                                </span>
                              </div>
                              <p className="text-xs text-[#7A6B6B] mt-0.5">
                                Pareja:{" "}
                                <strong>{u.partnerName ?? "Ninguna"}</strong> ·
                                Apodo dado:{" "}
                                <strong>
                                  {u.partnerNicknameGiven || "—"}
                                </strong>
                              </p>
                              <div className="flex flex-wrap items-center gap-1.5 mt-2">
                                <span
                                  className={`rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
                                    u.hasPin
                                      ? "bg-[#E5F6EC] text-[#14532D]"
                                      : "bg-[#FFE8E5] text-[#8C1D18]"
                                  }`}
                                >
                                  {u.hasPin ? "🔒 PIN Activo" : "⚠️ Sin PIN"}
                                </span>
                                <span
                                  className={`rounded-full px-2.5 py-0.5 text-[11px] font-bold ${
                                    u.hasFcmToken
                                      ? "bg-[#E5F6EC] text-[#14532D]"
                                      : "bg-[#F3EDE4] text-[#6E5E5E]"
                                  }`}
                                >
                                  {u.hasFcmToken
                                    ? "📲 Push Token OK"
                                    : "🔕 Sin Push Token"}
                                </span>
                                <span className="rounded-full bg-[#F3EDE4] px-2.5 py-0.5 text-[11px] font-bold text-[#473A3A]">
                                  🔑 {u.activeSessionsCount} sesiones activas
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* Action Buttons Row */}
                        <div className="flex flex-wrap gap-2 pt-2 border-t border-[#EFE8E0]">
                          <button
                            type="button"
                            onClick={() =>
                              setEditingUser(
                                isEditing
                                  ? null
                                  : {
                                      userId: u.id,
                                      displayName: u.displayName,
                                      avatarId: u.avatarId,
                                    }
                              )
                            }
                            className={creamSecondaryBtn}
                          >
                            ✏️ Editar Perfil y Avatar
                          </button>

                          <button
                            type="button"
                            onClick={() =>
                              setPinResetUser(
                                isResettingPin
                                  ? null
                                  : {
                                      userId: u.id,
                                      username: u.username,
                                      newPin: "",
                                    }
                              )
                            }
                            className={creamSecondaryBtn}
                          >
                            🔢 Cambiar PIN (4 dígitos)
                          </button>

                          <button
                            type="button"
                            disabled={
                              busyAction === `regen_code_${u.id}`
                            }
                            onClick={() =>
                              void runAction(
                                `regen_code_${u.id}`,
                                {
                                  action: "regenerate_recovery_code",
                                  userId: u.id,
                                },
                                `Nuevo código de recuperación generado para @${u.username}.`
                              )
                            }
                            className={creamSecondaryBtn}
                          >
                            🎟️ Generar Código Recuperación
                          </button>

                          <button
                            type="button"
                            onClick={() =>
                              setPushTestUser(
                                isTestingPush
                                  ? null
                                  : {
                                      userId: u.id,
                                      username: u.username,
                                      title: "💌 Prueba desde amodoro Admin",
                                      body: "¡Hola! Las notificaciones Push funcionan de maravilla.",
                                    }
                              )
                            }
                            className={creamSecondaryBtn}
                          >
                            🔔 Probar Push FCM
                          </button>

                          <button
                            type="button"
                            disabled={busyAction === `revoke_${u.id}`}
                            onClick={() =>
                              void runAction(
                                `revoke_${u.id}`,
                                { action: "revoke_sessions", userId: u.id },
                                `Sesiones revocadas para @${u.username}.`
                              )
                            }
                            className={creamSecondaryBtn}
                          >
                            🚪 Revocar Sesiones ({u.activeSessionsCount})
                          </button>

                          <button
                            type="button"
                            disabled={busyAction === `delete_user_${u.id}`}
                            onClick={() => {
                              if (
                                window.confirm(
                                  `¿Eliminar permanentemente la cuenta de @${u.username}? Esta acción borrará sus sesiones y datos asociados.`
                                )
                              ) {
                                void runAction(
                                  `delete_user_${u.id}`,
                                  { action: "delete_user", userId: u.id },
                                  `Usuario @${u.username} eliminado.`
                                );
                              }
                            }}
                            className={dangerPillBtn}
                          >
                            🗑️ Eliminar Usuario
                          </button>
                        </div>

                        {/* Inline Drawer: Edit Display Name & Avatar */}
                        {isEditing && editingUser && (
                          <form
                            onSubmit={(e) => {
                              e.preventDefault();
                              void runAction(
                                `update_user_${u.id}`,
                                {
                                  action: "update_user",
                                  userId: u.id,
                                  displayName: editingUser.displayName,
                                  avatarId: editingUser.avatarId,
                                },
                                `Perfil de @${u.username} actualizado.`
                              ).then((res) => {
                                if (res?.ok) setEditingUser(null);
                              });
                            }}
                            className="rounded-2xl bg-[#FAF8F5] border-[2px] border-[#E6DDD4] p-4 space-y-3"
                          >
                            <h4 className="text-xs font-extrabold uppercase tracking-wider">
                              Editar Nombre y Mascota de @{u.username}
                            </h4>
                            <div>
                              <label className="block text-xs font-bold mb-1">
                                Nombre visible
                              </label>
                              <input
                                type="text"
                                required
                                value={editingUser.displayName}
                                onChange={(e) =>
                                  setEditingUser({
                                    ...editingUser,
                                    displayName: e.target.value,
                                  })
                                }
                                className="w-full rounded-xl bg-white border-[2px] border-[#473A3A] px-3 py-2 text-sm font-semibold"
                              />
                            </div>
                            <div>
                              <label className="block text-xs font-bold mb-1.5">
                                Avatar (8 mascotas)
                              </label>
                              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                                {AVATAR_OPTIONS.map((av) => {
                                  const selected =
                                    editingUser.avatarId === av.id;
                                  return (
                                    <button
                                      key={av.id}
                                      type="button"
                                      onClick={() =>
                                        setEditingUser({
                                          ...editingUser,
                                          avatarId: av.id,
                                        })
                                      }
                                      className={`rounded-xl border-[2px] px-2.5 py-2 text-xs font-bold flex items-center gap-1.5 cursor-pointer ${
                                        selected
                                          ? "bg-[#FFE3DE] border-[#F27166] text-[#473A3A]"
                                          : "bg-white border-[#E6DDD4] text-[#6E5E5E]"
                                      }`}
                                    >
                                      <span>{av.emoji}</span>
                                      <span className="truncate">
                                        {av.label}
                                      </span>
                                    </button>
                                  );
                                })}
                              </div>
                            </div>
                            <div className="flex items-center gap-2 pt-1">
                              <button
                                type="submit"
                                disabled={busyAction === `update_user_${u.id}`}
                                className={salmonPrimaryBtn}
                              >
                                Guardar Cambios
                              </button>
                              <button
                                type="button"
                                onClick={() => setEditingUser(null)}
                                className={creamSecondaryBtn}
                              >
                                Cancelar
                              </button>
                            </div>
                          </form>
                        )}

                        {/* Inline Drawer: Reset 4-Digit PIN */}
                        {isResettingPin && pinResetUser && (
                          <form
                            onSubmit={(e) => {
                              e.preventDefault();
                              void runAction(
                                `reset_pin_${u.id}`,
                                {
                                  action: "reset_user_pin",
                                  userId: u.id,
                                  newPin: pinResetUser.newPin,
                                },
                                `PIN de 4 dígitos actualizado para @${u.username}.`
                              ).then((res) => {
                                if (res?.ok) setPinResetUser(null);
                              });
                            }}
                            className="rounded-2xl bg-[#FAF8F5] border-[2px] border-[#E6DDD4] p-4 space-y-3"
                          >
                            <h4 className="text-xs font-extrabold uppercase tracking-wider">
                              Nuevo PIN de 4 dígitos para @{u.username}
                            </h4>
                            <div className="flex flex-wrap items-center gap-2">
                              <input
                                type="text"
                                inputMode="numeric"
                                pattern="\d{4}"
                                maxLength={4}
                                required
                                placeholder="Ej: 1234"
                                value={pinResetUser.newPin}
                                onChange={(e) =>
                                  setPinResetUser({
                                    ...pinResetUser,
                                    newPin: e.target.value.replace(/\D/g, ""),
                                  })
                                }
                                className="w-36 rounded-xl bg-white border-[2px] border-[#473A3A] px-3 py-2 text-center font-mono text-base font-black tracking-widest"
                              />
                              <button
                                type="submit"
                                disabled={
                                  pinResetUser.newPin.length !== 4 ||
                                  busyAction === `reset_pin_${u.id}`
                                }
                                className={salmonPrimaryBtn}
                              >
                                Guardar PIN
                              </button>
                              <button
                                type="button"
                                onClick={() => setPinResetUser(null)}
                                className={creamSecondaryBtn}
                              >
                                Cancelar
                              </button>
                            </div>
                          </form>
                        )}

                        {/* Inline Drawer: Send Test FCM Push */}
                        {isTestingPush && pushTestUser && (
                          <form
                            onSubmit={(e) => {
                              e.preventDefault();
                              void runAction(`test_push_${u.id}`, {
                                action: "test_push",
                                userId: u.id,
                                title: pushTestUser.title,
                                body: pushTestUser.body,
                              }).then((res) => {
                                if (res?.pushResult) {
                                  setBanner({
                                    type: res.pushResult.ok
                                      ? "success"
                                      : "error",
                                    text: res.pushResult.ok
                                      ? `Push enviado a @${u.username} correctamente.`
                                      : `No se pudo entregar el Push: ${res.pushResult.reason || "Error desconocido"}`,
                                  });
                                }
                              });
                            }}
                            className="rounded-2xl bg-[#FAF8F5] border-[2px] border-[#E6DDD4] p-4 space-y-3"
                          >
                            <h4 className="text-xs font-extrabold uppercase tracking-wider">
                              Enviar Notificación Push de Prueba a @{u.username}
                            </h4>
                            <div className="space-y-2">
                              <input
                                type="text"
                                required
                                value={pushTestUser.title}
                                onChange={(e) =>
                                  setPushTestUser({
                                    ...pushTestUser,
                                    title: e.target.value,
                                  })
                                }
                                placeholder="Título de la notificación"
                                className="w-full rounded-xl bg-white border-[2px] border-[#473A3A] px-3 py-2 text-xs font-bold"
                              />
                              <input
                                type="text"
                                required
                                value={pushTestUser.body}
                                onChange={(e) =>
                                  setPushTestUser({
                                    ...pushTestUser,
                                    body: e.target.value,
                                  })
                                }
                                placeholder="Cuerpo del mensaje"
                                className="w-full rounded-xl bg-white border-[2px] border-[#473A3A] px-3 py-2 text-xs font-semibold"
                              />
                            </div>
                            <div className="flex items-center gap-2">
                              <button
                                type="submit"
                                disabled={busyAction === `test_push_${u.id}`}
                                className={salmonPrimaryBtn}
                              >
                                🚀 Enviar Push Ahora
                              </button>
                              <button
                                type="button"
                                onClick={() => setPushTestUser(null)}
                                className={creamSecondaryBtn}
                              >
                                Cerrar
                              </button>
                            </div>
                          </form>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        )}

        {/* TAB 2: BACKUPS Y BASE DE DATOS */}
        {activeTab === "backups" && (
          <div className="space-y-6">
            {/* Direct Exports */}
            <div className={neoCard}>
              <h2 className="text-lg font-extrabold">
                📥 Exportación Directa a tu Dispositivo
              </h2>
              <p className="text-xs text-[#7A6B6B] mt-1 mb-4">
                Descarga una copia en caliente sin detener el servidor. El
                paquete <code>.tar.gz</code> incluye tanto la base de datos
                SQLite consistente como todas las fotos y dibujos en{" "}
                <code>data/uploads/</code>.
              </p>

              <div className="flex flex-wrap gap-3">
                <a
                  href="/api/admin?download=tar"
                  download
                  className={salmonPrimaryBtn}
                >
                  📦 Descargar Backup Completo (.tar.gz — DB + Imágenes)
                </a>
                <a
                  href="/api/admin?download=db"
                  download
                  className={creamSecondaryBtn}
                >
                  🗄️ Descargar Base de Datos SQLite (.db)
                </a>
                <a
                  href="/api/admin?download=json"
                  download
                  className={creamSecondaryBtn}
                >
                  📄 Exportar Todo en JSON (.json)
                </a>
              </div>
            </div>

            {/* Server Snapshots */}
            <div className={neoCard}>
              <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
                <div>
                  <h2 className="text-lg font-extrabold">
                    🕰️ Snapshots en el Servidor (<code>/data/backups/</code>)
                  </h2>
                  <p className="text-xs text-[#7A6B6B]">
                    Puntos de restauración guardados localmente en el volumen
                    persistente del contenedor.
                  </p>
                </div>

                <button
                  type="button"
                  disabled={busyAction === "create_snapshot"}
                  onClick={() =>
                    void runAction(
                      "create_snapshot",
                      { action: "create_snapshot" },
                      "Snapshot creado correctamente en /data/backups/."
                    )
                  }
                  className={salmonPrimaryBtn}
                >
                  + Crear Snapshot en el Servidor Ahora
                </button>
              </div>

              {overview.snapshots.length === 0 ? (
                <div className="rounded-2xl bg-[#FAF8F5] border-[2px] border-dashed border-[#D8CFC6] p-6 text-center text-xs text-[#7A6B6B]">
                  No hay snapshots guardados en <code>/data/backups/</code>.
                  Pulsa el botón superior para crear el primero.
                </div>
              ) : (
                <div className="space-y-2.5">
                  {overview.snapshots.map((snap) => (
                    <div
                      key={snap.filename}
                      className="rounded-2xl bg-[#FAF8F5] border-[2px] border-[#E6DDD4] p-3.5 flex flex-wrap items-center justify-between gap-3"
                    >
                      <div>
                        <p className="font-mono text-xs sm:text-sm font-extrabold text-[#473A3A]">
                          {snap.filename}
                        </p>
                        <p className="text-xs text-[#7A6B6B]">
                          {formatBytes(snap.sizeBytes)} · Creado:{" "}
                          {formatDate(snap.createdAt)}
                        </p>
                      </div>

                      <div className="flex flex-wrap items-center gap-2">
                        <a
                          href={`/api/admin?download=snapshot&file=${encodeURIComponent(
                            snap.filename
                          )}`}
                          download
                          className={creamSecondaryBtn}
                        >
                          ⬇️ Descargar
                        </a>
                        <button
                          type="button"
                          disabled={
                            busyAction === `restore_snap_${snap.filename}`
                          }
                          onClick={() => {
                            if (
                              window.confirm(
                                `¿Restaurar el servidor al estado del snapshot "${snap.filename}"?`
                              )
                            ) {
                              void runAction(
                                `restore_snap_${snap.filename}`,
                                {
                                  action: "restore_snapshot",
                                  filename: snap.filename,
                                },
                                `Snapshot "${snap.filename}" restaurado con éxito.`
                              );
                            }
                          }}
                          className={creamSecondaryBtn}
                        >
                          ♻️ Restaurar
                        </button>
                        <button
                          type="button"
                          disabled={busyAction === `del_snap_${snap.filename}`}
                          onClick={() => {
                            if (
                              window.confirm(
                                `¿Eliminar el archivo de snapshot "${snap.filename}"?`
                              )
                            ) {
                              void runAction(
                                `del_snap_${snap.filename}`,
                                {
                                  action: "delete_snapshot",
                                  filename: snap.filename,
                                },
                                `Snapshot "${snap.filename}" eliminado.`
                              );
                            }
                          }}
                          className={dangerPillBtn}
                        >
                          🗑️ Eliminar
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Restore from uploaded file & Maintenance */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className={neoCard}>
                <h2 className="text-lg font-extrabold">
                  📤 Restaurar desde Archivo (<code>.db</code> o{" "}
                  <code>.tar.gz</code>)
                </h2>
                <p className="text-xs text-[#7A6B6B] mt-1 mb-4">
                  Sube un backup descargado previamente para restaurar la base
                  de datos SQLite (y la carpeta <code>uploads/</code> si subes
                  un <code>.tar.gz</code>).
                </p>

                <form onSubmit={handleRestoreUpload} className="space-y-3">
                  <input
                    type="file"
                    accept=".db,.sqlite,.sqlite3,.tar.gz,.tgz"
                    onChange={(e) =>
                      setRestoreFile(e.target.files?.[0] ?? null)
                    }
                    className="block w-full text-xs text-[#473A3A] file:mr-3 file:rounded-full file:border-[2px] file:border-[#473A3A] file:bg-[#FFF0ED] file:px-4 file:py-1.5 file:text-xs file:font-extrabold file:text-[#473A3A] hover:file:bg-[#FFE3DE]"
                  />
                  <button
                    type="submit"
                    disabled={!restoreFile || busyAction === "restore_upload"}
                    className={salmonPrimaryBtn}
                  >
                    {busyAction === "restore_upload"
                      ? "Restaurando archivo…"
                      : "♻️ Subir y Restaurar Backup"}
                  </button>
                </form>
              </div>

              <div className={neoCard}>
                <h2 className="text-lg font-extrabold">
                  🧹 Mantenimiento y Limpieza
                </h2>
                <p className="text-xs text-[#7A6B6B] mt-1 mb-4">
                  Libera espacio eliminando imágenes que ya no están asociadas a
                  ninguna tarjeta, respuesta o actividad, o vacía la caché de
                  metadatos OpenGraph.
                </p>

                <div className="flex flex-col sm:flex-row flex-wrap gap-3">
                  <button
                    type="button"
                    disabled={busyAction === "clean_orphans"}
                    onClick={() =>
                      void runAction("clean_orphans", {
                        action: "clean_orphans",
                      }).then((res) => {
                        if (res?.cleanup) {
                          setBanner({
                            type: "success",
                            text: `Limpieza completada: ${res.cleanup.deletedMediaRows} registros huérfanos y ${res.cleanup.deletedDiskFiles} archivos en disco eliminados (${formatBytes(res.cleanup.freedBytes)} liberados).`,
                          });
                        }
                      })
                    }
                    className={creamSecondaryBtn}
                  >
                    🧹 Limpiar Imágenes Huérfanas (Garbage Collector)
                  </button>

                  <button
                    type="button"
                    disabled={busyAction === "clear_link_cache"}
                    onClick={() =>
                      void runAction("clear_link_cache", {
                        action: "clear_link_cache",
                      }).then((res) => {
                        if (res?.ok) {
                          setBanner({
                            type: "success",
                            text: `Caché de links vaciada (${res.clearedCount ?? 0} entradas eliminadas).`,
                          });
                        }
                      })
                    }
                    className={creamSecondaryBtn}
                  >
                    🔗 Vaciar Caché de Vistas Previas de Links (
                    {overview.counts.linkCacheCount})
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: ACTIVIDAD Y CONTENIDO */}
        {activeTab === "content" && (
          <div className="space-y-5">
            {/* Sub-tabs */}
            <div className="flex flex-wrap items-center gap-2">
              {(
                [
                  {
                    id: "cards",
                    label: `💌 Tarjetas de HOME (${overview.recentHomeCards.length})`,
                  },
                  {
                    id: "replies",
                    label: `💬 Respuestas a Tarjetas (${overview.recentReplies.length})`,
                  },
                  {
                    id: "boards",
                    label: `📌 Tableros e Historial (${overview.boardItems.length})`,
                  },
                  {
                    id: "media",
                    label: `🖼️ Galería de Archivos Media (${overview.mediaItems.length})`,
                  },
                ] as Array<{ id: ContentSubTab; label: string }>
              ).map((st) => (
                <button
                  key={st.id}
                  type="button"
                  onClick={() => setContentSubTab(st.id)}
                  className={
                    contentSubTab === st.id
                      ? salmonPrimaryBtn
                      : creamSecondaryBtn
                  }
                >
                  {st.label}
                </button>
              ))}
            </div>

            {/* Sub-tab 1: Tarjetas de HOME */}
            {contentSubTab === "cards" && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {overview.recentHomeCards.length === 0 ? (
                  <div className={`${neoCard} col-span-full text-center py-8 text-sm text-[#7A6B6B]`}>
                    No hay tarjetas enviadas en HOME todavía.
                  </div>
                ) : (
                  overview.recentHomeCards.map((card) => (
                    <div
                      key={card.id}
                      className={`${neoCard} flex flex-col justify-between gap-4`}
                    >
                      <div className="flex items-start gap-3.5">
                        {card.mediaId && (
                          <button
                            type="button"
                            onClick={() => setLightboxMediaId(card.mediaId)}
                            className="shrink-0 h-20 w-20 rounded-2xl overflow-hidden border-[2px] border-[#473A3A] bg-[#FAF8F5] cursor-pointer"
                          >
                            <img
                              src={`/api/admin?download=media&id=${card.mediaId}`}
                              alt={`Media #${card.mediaId}`}
                              className="h-full w-full object-cover"
                            />
                          </button>
                        )}
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-1.5">
                            <span className="rounded-full bg-[#FFE3DE] px-2.5 py-0.5 text-[11px] font-extrabold text-[#473A3A]">
                              #{card.id} · {card.dayKey}
                            </span>
                            <span className="text-xs font-bold text-[#6E5E5E]">
                              {card.senderName} → {card.recipientName}
                            </span>
                          </div>
                          <p className="text-sm font-semibold text-[#473A3A] mt-2 break-words">
                            {card.textContent || (
                              <em className="text-[#8C7B7B]">Sin texto</em>
                            )}
                          </p>
                          <p className="text-[11px] text-[#7A6B6B] mt-2">
                            ❤️ {card.reactionsCount} reacciones · 💬{" "}
                            {card.repliesCount} respuestas ·{" "}
                            {formatDate(card.createdAt)}
                          </p>
                        </div>
                      </div>

                      <div className="flex items-center justify-end gap-2 pt-2 border-t border-[#EFE8E0]">
                        <button
                          type="button"
                          disabled={busyAction === `del_card_${card.id}`}
                          onClick={() => {
                            if (
                              window.confirm(
                                `¿Eliminar la tarjeta #${card.id} de ${card.senderName}?`
                              )
                            ) {
                              void runAction(
                                `del_card_${card.id}`,
                                {
                                  action: "delete_home_card",
                                  cardId: card.id,
                                },
                                `Tarjeta #${card.id} eliminada.`
                              );
                            }
                          }}
                          className={dangerPillBtn}
                        >
                          🗑️ Eliminar
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* Sub-tab 2: Respuestas a Tarjetas */}
            {contentSubTab === "replies" && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {overview.recentReplies.length === 0 ? (
                  <div className={`${neoCard} col-span-full text-center py-8 text-sm text-[#7A6B6B]`}>
                    No hay respuestas registradas en tarjetas todavía.
                  </div>
                ) : (
                  overview.recentReplies.map((reply) => (
                    <div
                      key={reply.id}
                      className={`${neoCard} flex items-start justify-between gap-4`}
                    >
                      <div className="flex items-start gap-3">
                        {reply.mediaId && (
                          <button
                            type="button"
                            onClick={() => setLightboxMediaId(reply.mediaId)}
                            className="shrink-0 h-16 w-16 rounded-2xl overflow-hidden border-[2px] border-[#473A3A] bg-[#FAF8F5] cursor-pointer"
                          >
                            <img
                              src={`/api/admin?download=media&id=${reply.mediaId}`}
                              alt={`Reply Media #${reply.mediaId}`}
                              className="h-full w-full object-cover"
                            />
                          </button>
                        )}
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="rounded-full bg-[#F3EDE4] px-2.5 py-0.5 text-[11px] font-extrabold">
                              Respuesta #{reply.id} (Tarjeta #{reply.cardId})
                            </span>
                            <span className="text-xs font-bold">
                              por {reply.authorName}
                            </span>
                          </div>
                          <p className="text-sm font-semibold mt-1.5">
                            {reply.textContent || (
                              <em className="text-[#8C7B7B]">
                                Solo imagen / dibujo ({reply.mediaType})
                              </em>
                            )}
                          </p>
                          <p className="text-[11px] text-[#7A6B6B] mt-1">
                            {formatDate(reply.createdAt)}
                          </p>
                        </div>
                      </div>

                      <button
                        type="button"
                        disabled={busyAction === `del_reply_${reply.id}`}
                        onClick={() => {
                          if (
                            window.confirm(
                              `¿Eliminar la respuesta #${reply.id} de ${reply.authorName}?`
                            )
                          ) {
                            void runAction(
                              `del_reply_${reply.id}`,
                              {
                                action: "delete_card_reply",
                                replyId: reply.id,
                              },
                              `Respuesta #${reply.id} eliminada.`
                            );
                          }
                        }}
                        className={dangerPillBtn}
                      >
                        🗑️ Eliminar
                      </button>
                    </div>
                  ))
                )}
              </div>
            )}

            {/* Sub-tab 3: Tableros e Historial */}
            {contentSubTab === "boards" && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {overview.boardItems.length === 0 ? (
                  <div className={`${neoCard} col-span-full text-center py-8 text-sm text-[#7A6B6B]`}>
                    No hay elementos en los tableros todavía.
                  </div>
                ) : (
                  overview.boardItems.map((item) => {
                    const isCompleted =
                      item.status.toLowerCase() === "completed" ||
                      item.status.toLowerCase() === "done" ||
                      Boolean(item.completedAt);
                    const previewId = item.completionMediaId ?? item.mediaId;

                    return (
                      <div
                        key={item.id}
                        className={`${neoCard} flex flex-col justify-between gap-3`}
                      >
                        <div className="flex items-start gap-3">
                          {previewId && (
                            <button
                              type="button"
                              onClick={() => setLightboxMediaId(previewId)}
                              className="shrink-0 h-16 w-16 rounded-2xl overflow-hidden border-[2px] border-[#473A3A] bg-[#FAF8F5] cursor-pointer"
                            >
                              <img
                                src={`/api/admin?download=media&id=${previewId}`}
                                alt={item.title}
                                className="h-full w-full object-cover"
                              />
                            </button>
                          )}
                          <div className="flex-1 min-w-0">
                            <div className="flex flex-wrap items-center gap-1.5">
                              <span
                                className={`rounded-full px-2.5 py-0.5 text-[10px] font-black uppercase ${
                                  isCompleted
                                    ? "bg-[#E5F6EC] text-[#14532D] border border-[#52A874]"
                                    : "bg-[#FFF3CD] text-[#664600] border border-[#D9A441]"
                                }`}
                              >
                                {isCompleted ? "HISTORIAL" : "PENDIENTE"}
                              </span>
                              <span className="rounded-full bg-[#F3EDE4] px-2.5 py-0.5 text-[11px] font-bold">
                                {item.boardTitle || item.categoryTag}
                              </span>
                            </div>
                            <h3 className="text-sm font-extrabold mt-1.5">
                              {item.title}
                            </h3>
                            {item.notes && (
                              <p className="text-xs text-[#6E5E5E] mt-0.5">
                                {item.notes}
                              </p>
                            )}
                            {item.completionText && (
                              <p className="text-xs font-semibold text-[#14532D] bg-[#E5F6EC] rounded-xl px-2.5 py-1.5 mt-2">
                                ✨ Recuerdo: {item.completionText}
                              </p>
                            )}
                            <p className="text-[11px] text-[#7A6B6B] mt-1.5">
                              Por {item.creatorName} ·{" "}
                              {formatDate(item.completedAt ?? item.createdAt)}
                            </p>
                          </div>
                        </div>

                        <div className="flex justify-end pt-2 border-t border-[#EFE8E0]">
                          <button
                            type="button"
                            disabled={busyAction === `del_board_${item.id}`}
                            onClick={() => {
                              if (
                                window.confirm(
                                  `¿Eliminar "${item.title}" del tablero?`
                                )
                              ) {
                                void runAction(
                                  `del_board_${item.id}`,
                                  {
                                    action: "delete_board_item",
                                    itemId: item.id,
                                  },
                                  `Elemento "${item.title}" eliminado.`
                                );
                              }
                            }}
                            className={dangerPillBtn}
                          >
                            🗑️ Eliminar
                          </button>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            )}

            {/* Sub-tab 4: Galería de Archivos Media */}
            {contentSubTab === "media" && (
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
                {overview.mediaItems.length === 0 ? (
                  <div className={`${neoCard} col-span-full text-center py-8 text-sm text-[#7A6B6B]`}>
                    No hay archivos multimedia en <code>data/uploads/</code>.
                  </div>
                ) : (
                  overview.mediaItems.map((m) => (
                    <div
                      key={m.id}
                      className={`${neoCard} !p-3.5 flex flex-col justify-between gap-2.5`}
                    >
                      <div>
                        <button
                          type="button"
                          onClick={() => setLightboxMediaId(m.id)}
                          className="w-full aspect-square rounded-2xl overflow-hidden border-[2px] border-[#473A3A] bg-[#FAF8F5] mb-2 cursor-pointer"
                        >
                          <img
                            src={`/api/admin?download=media&id=${m.id}`}
                            alt={`Media #${m.id}`}
                            className="h-full w-full object-cover"
                          />
                        </button>
                        <div className="flex items-center justify-between gap-1">
                          <span className="text-xs font-extrabold">
                            #{m.id} · {m.kind}
                          </span>
                          <span
                            className={`rounded-full px-2 py-0.5 text-[10px] font-extrabold ${
                              m.isReferenced
                                ? "bg-[#E5F6EC] text-[#14532D]"
                                : "bg-[#FFE8E5] text-[#8C1D18]"
                            }`}
                          >
                            {m.isReferenced ? "En uso" : "Huérfano"}
                          </span>
                        </div>
                        <p className="text-[11px] text-[#7A6B6B] mt-0.5">
                          {(m.sizeBytes / 1024).toFixed(1)} KB · {m.ownerName}
                        </p>
                      </div>

                      <button
                        type="button"
                        disabled={busyAction === `del_media_${m.id}`}
                        onClick={() => {
                          if (
                            window.confirm(
                              `¿Eliminar archivo multimedia #${m.id} (${m.filePath})?`
                            )
                          ) {
                            void runAction(
                              `del_media_${m.id}`,
                              { action: "delete_media", mediaId: m.id },
                              `Archivo #${m.id} eliminado.`
                            );
                          }
                        }}
                        className={`${dangerPillBtn} w-full`}
                      >
                        🗑️ Eliminar
                      </button>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>
        )}

        {/* TAB 4: CONSOLA SQL Y SEGURIDAD */}
        {activeTab === "sql" && (
          <div className="space-y-6">
            {/* Read-Only SQL Explorer */}
            <div className={neoCard}>
              <h2 className="text-lg font-extrabold">
                🔍 Consola SQL de Solo Lectura (<code>SELECT</code> /{" "}
                <code>PRAGMA</code>)
              </h2>
              <p className="text-xs text-[#7A6B6B] mt-1 mb-3">
                Ejecuta consultas de inspección directamente sobre{" "}
                <code>amodoro.db</code>. Las sentencias destructivas están
                bloqueadas por seguridad.
              </p>

              {/* Preset Pills */}
              <div className="flex flex-wrap gap-2 mb-3">
                {SQL_PRESETS.map((preset) => (
                  <button
                    key={preset.label}
                    type="button"
                    onClick={() => {
                      setSqlQuery(preset.sql);
                      void handleRunSql(undefined, preset.sql);
                    }}
                    className={creamSecondaryBtn}
                  >
                    ⚡ {preset.label}
                  </button>
                ))}
              </div>

              <form onSubmit={(e) => void handleRunSql(e)} className="space-y-3">
                <textarea
                  rows={3}
                  value={sqlQuery}
                  onChange={(e) => setSqlQuery(e.target.value)}
                  className="w-full rounded-2xl bg-[#FAF8F5] border-[2px] border-[#473A3A] p-3.5 font-mono text-xs sm:text-sm font-semibold text-[#473A3A] focus:outline-none focus:ring-2 focus:ring-[#F27166]"
                />
                <button
                  type="submit"
                  disabled={busyAction === "run_sql"}
                  className={salmonPrimaryBtn}
                >
                  {busyAction === "run_sql"
                    ? "Ejecutando…"
                    : "▶️ Ejecutar Consulta SQL"}
                </button>
              </form>

              {sqlResult && (
                <div className="mt-5 overflow-x-auto rounded-2xl border-[2px] border-[#E6DDD4]">
                  {sqlResult.rows.length === 0 ? (
                    <div className="p-4 text-center text-xs text-[#7A6B6B]">
                      La consulta no devolvió filas.
                    </div>
                  ) : (
                    <table className="min-w-full text-left text-xs">
                      <thead className="bg-[#F3EDE4] text-[#473A3A] font-extrabold uppercase">
                        <tr>
                          {sqlResult.columns.map((col) => (
                            <th key={col} className="px-3.5 py-2.5 border-b border-[#E6DDD4]">
                              {col}
                            </th>
                          ))}
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-[#EFE8E0] bg-white font-mono">
                        {sqlResult.rows.map((row, rIdx) => (
                          <tr key={rIdx} className="hover:bg-[#FAF8F5]">
                            {sqlResult.columns.map((col) => (
                              <td
                                key={col}
                                className="px-3.5 py-2 whitespace-nowrap max-w-xs truncate"
                              >
                                {row[col] === null || row[col] === undefined
                                  ? "NULL"
                                  : String(row[col])}
                              </td>
                            ))}
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              )}
            </div>

            {/* Security Log & Change Admin Password */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className={neoCard}>
                <h2 className="text-lg font-extrabold mb-3">
                  🛡️ Registro de Seguridad y Auditoría
                </h2>
                {overview.securityEvents.length === 0 ? (
                  <p className="text-xs text-[#7A6B6B]">
                    No hay eventos recientes registrados.
                  </p>
                ) : (
                  <div className="space-y-2 max-h-80 overflow-y-auto pr-1">
                    {overview.securityEvents.map((ev, idx) => (
                      <div
                        key={idx}
                        className="rounded-2xl bg-[#FAF8F5] border border-[#E6DDD4] px-3.5 py-2.5 text-xs"
                      >
                        <div className="flex items-center justify-between font-bold">
                          <span>{ev.event}</span>
                          <span className="text-[11px] text-[#7A6B6B]">
                            {formatDate(ev.timestamp)}
                          </span>
                        </div>
                        {(ev.detail || ev.ip) && (
                          <p className="text-[11px] text-[#6E5E5E] mt-0.5 font-mono">
                            {ev.ip ? `IP: ${ev.ip} ` : ""}
                            {ev.detail ?? ""}
                          </p>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className={neoCard}>
                <h2 className="text-lg font-extrabold">
                  🔑 Cambiar Contraseña de Administrador
                </h2>
                <p className="text-xs text-[#7A6B6B] mt-1 mb-4">
                  Actualiza la contraseña maestra del panel <code>/admin</code>{" "}
                  (se guarda con hash Argon2id en la configuración del
                  servidor).
                </p>

                <form
                  onSubmit={handleChangeAdminPassword}
                  className="space-y-3"
                >
                  <div>
                    <label className="block text-xs font-bold mb-1">
                      Contraseña Actual
                    </label>
                    <input
                      type="password"
                      required
                      value={currentAdminPassword}
                      onChange={(e) => setCurrentAdminPassword(e.target.value)}
                      className="w-full rounded-xl bg-[#FAF8F5] border-[2px] border-[#473A3A] px-3.5 py-2 text-sm font-semibold"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold mb-1">
                      Nueva Contraseña (mín. 8 caracteres)
                    </label>
                    <input
                      type="password"
                      required
                      minLength={8}
                      value={newAdminPassword}
                      onChange={(e) => setNewAdminPassword(e.target.value)}
                      className="w-full rounded-xl bg-[#FAF8F5] border-[2px] border-[#473A3A] px-3.5 py-2 text-sm font-semibold"
                    />
                  </div>
                  <button
                    type="submit"
                    disabled={busyAction === "change_admin_password"}
                    className={salmonPrimaryBtn}
                  >
                    Guardar Nueva Contraseña
                  </button>
                </form>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Media Preview Lightbox Modal */}
      {lightboxMediaId !== null && (
        <div
          onClick={() => setLightboxMediaId(null)}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="max-w-lg w-full rounded-3xl bg-[#FAF8F5] border-[2.5px] border-[#473A3A] p-4 space-y-3"
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-extrabold">
                Vista previa de archivo #{lightboxMediaId}
              </span>
              <button
                type="button"
                onClick={() => setLightboxMediaId(null)}
                className={creamSecondaryBtn}
              >
                ✕ Cerrar
              </button>
            </div>
            <div className="rounded-2xl overflow-hidden border-[2px] border-[#E6DDD4] bg-white flex items-center justify-center max-h-[70vh]">
              <img
                src={`/api/admin?download=media&id=${lightboxMediaId}`}
                alt={`Media #${lightboxMediaId}`}
                className="max-h-[68vh] w-auto object-contain"
              />
            </div>
            <div className="flex justify-end">
              <a
                href={`/api/admin?download=media&id=${lightboxMediaId}`}
                download
                className={salmonPrimaryBtn}
              >
                ⬇️ Descargar Imagen Original
              </a>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
