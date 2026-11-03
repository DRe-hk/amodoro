import { createHash } from "node:crypto";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { linkPreviewCache } from "@/db/schema";

export type LinkPreviewData = {
  url: string;
  title: string;
  thumbnail: string | null;
  platform: "YouTube" | "Spotify" | "Instagram" | "Web";
};

const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

const CACHE_TTL_MS = 7 * 86_400_000; // 7 days
const MAX_HTML_BYTES = 512 * 1024; // 512 KB

function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

export function isPrivateOrReservedIp(ipRaw: string): boolean {
  const ip = ipRaw.trim().toLowerCase().replace(/^\[|\]$/g, "");

  if (ip === "::1" || ip === "::" || ip === "0:0:0:0:0:0:0:1" || ip === "0:0:0:0:0:0:0:0") {
    return true;
  }

  if (ip.startsWith("::ffff:")) {
    const mapped = ip.slice(7);
    if (isIP(mapped) === 4) {
      return isPrivateOrReservedIp(mapped);
    }
    return true;
  }

  const version = isIP(ip);
  if (version === 4) {
    const parts = ip.split(".").map((p) => Number(p));
    if (parts.length !== 4 || parts.some((n) => Number.isNaN(n) || n < 0 || n > 255)) {
      return true;
    }
    const [a, b] = parts as [number, number, number, number];
    if (a === 0) return true; // 0.0.0.0/8
    if (a === 10) return true; // 10.0.0.0/8
    if (a === 127) return true; // 127.0.0.0/8
    if (a === 169 && b === 254) return true; // 169.254.0.0/16
    if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
    if (a === 192 && b === 168) return true; // 192.168.0.0/16
    if (a === 100 && b >= 64 && b <= 127) return true; // 100.64.0.0/10
    if (a >= 224) return true; // Multicast & reserved
    return false;
  }

  if (version === 6) {
    if (
      ip.startsWith("fc") ||
      ip.startsWith("fd") ||
      ip.startsWith("fe8") ||
      ip.startsWith("fe9") ||
      ip.startsWith("fea") ||
      ip.startsWith("feb") ||
      ip.startsWith("ff")
    ) {
      return true;
    }
    return false;
  }

  return true;
}

export async function assertSafeExternalUrl(rawUrl: string): Promise<URL> {
  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new Error("URL inválida.");
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error("Solo se permiten enlaces HTTP o HTTPS.");
  }

  const host = parsed.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (
    !host ||
    host === "localhost" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local") ||
    host.endsWith(".internal")
  ) {
    throw new Error("URL local o privada no permitida.");
  }

  if (isIP(host)) {
    if (isPrivateOrReservedIp(host)) {
      throw new Error("URL local o privada no permitida.");
    }
    return parsed;
  }

  try {
    const records = await lookup(host, { all: true });
    if (!records || records.length === 0) {
      throw new Error("No se pudo resolver el dominio.");
    }
    for (const rec of records) {
      if (isPrivateOrReservedIp(rec.address)) {
        throw new Error("URL local o privada no permitida.");
      }
    }
  } catch (err) {
    if (err instanceof Error && err.message.includes("no permitida")) {
      throw err;
    }
    // If DNS fails in offline environment for public domain, allow fallback metadata handling unless it's numeric/local
  }

  return parsed;
}

export function detectPlatform(url: string): "YouTube" | "Spotify" | "Instagram" | "Web" {
  try {
    const normalized = url.trim().match(/^https?:\/\//i) ? url.trim() : `https://${url.trim()}`;
    const parsed = new URL(normalized);
    const host = parsed.hostname.toLowerCase();

    if (
      host === "youtube.com" ||
      host.endsWith(".youtube.com") ||
      host === "youtu.be" ||
      host.endsWith(".youtu.be")
    ) {
      return "YouTube";
    }

    if (host === "spotify.com" || host.endsWith(".spotify.com")) {
      return "Spotify";
    }

    if (host === "instagram.com" || host.endsWith(".instagram.com")) {
      return "Instagram";
    }

    return "Web";
  } catch {
    return "Web";
  }
}

function normalizeUrl(rawUrl: string): string {
  const trimmed = rawUrl.trim();
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(trimmed)) {
    return trimmed;
  }
  return `https://${trimmed}`;
}

function extractYouTubeVideoId(url: string): string | null {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase();

    if (host === "youtu.be" || host.endsWith(".youtu.be")) {
      const id = parsed.pathname.slice(1).split("/")[0]?.split("?")[0];
      return id || null;
    }

    if (host === "youtube.com" || host.endsWith(".youtube.com")) {
      const v = parsed.searchParams.get("v");
      if (v) return v;

      const match = parsed.pathname.match(/\/(?:embed|shorts|live|v)\/([a-zA-Z0-9_-]+)/);
      if (match?.[1]) return match[1];
    }
  } catch {
    // Ignore URL parse failure
  }
  return null;
}

function extractMetaTag(html: string, propertyName: string): string | null {
  const escaped = propertyName.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
  const regex = new RegExp(
    `<meta(?=[^>]*(?:property|name)=["']${escaped}["'])[^>]*content=(["'])(.*?)\\1`,
    "i",
  );
  const match = html.match(regex);
  return match?.[2]?.trim() || null;
}

function extractTitleTag(html: string): string | null {
  const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
  return match?.[1]?.trim() || null;
}

function unescapeHtml(text: string): string {
  return text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .trim();
}

function resolveThumbnailUrl(thumbnail: string, baseUrl: string): string | null {
  try {
    const resolved = new URL(thumbnail, baseUrl);
    if (resolved.protocol !== "http:" && resolved.protocol !== "https:") {
      return null;
    }
    return resolved.href;
  } catch {
    return thumbnail.startsWith("http://") || thumbnail.startsWith("https://")
      ? thumbnail
      : null;
  }
}

async function readLimitedText(res: Response, maxBytes: number): Promise<string> {
  if (!res.body) {
    const text = await res.text();
    return text.slice(0, maxBytes);
  }
  const reader = res.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value) {
      total += value.byteLength;
      if (total > maxBytes) {
        chunks.push(value.subarray(0, Math.max(0, value.byteLength - (total - maxBytes))));
        try {
          await reader.cancel();
        } catch {
          // ignore
        }
        break;
      }
      chunks.push(value);
    }
  }

  return Buffer.concat(chunks).toString("utf8");
}

function savePreviewCache(data: LinkPreviewData) {
  try {
    const urlHash = sha256(data.url);
    const now = new Date();
    db.insert(linkPreviewCache)
      .values({
        urlHash,
        url: data.url,
        title: data.title,
        thumbnail: data.thumbnail,
        platform: data.platform,
        updatedAt: now,
      })
      .onConflictDoUpdate({
        target: linkPreviewCache.urlHash,
        set: {
          title: data.title,
          thumbnail: data.thumbnail,
          platform: data.platform,
          updatedAt: now,
        },
      })
      .run();
  } catch {
    // ignore cache write failure
  }
}

export async function fetchLinkPreview(rawUrl: string): Promise<LinkPreviewData> {
  const url = normalizeUrl(rawUrl || "");
  await assertSafeExternalUrl(url);

  const urlHash = sha256(url);
  try {
    const cached = db
      .select()
      .from(linkPreviewCache)
      .where(eq(linkPreviewCache.urlHash, urlHash))
      .get();
    if (cached && Date.now() - cached.updatedAt.getTime() < CACHE_TTL_MS) {
      return {
        url: cached.url,
        title: cached.title,
        thumbnail: cached.thumbnail ?? null,
        platform: (cached.platform as LinkPreviewData["platform"]) || "Web",
      };
    }
  } catch {
    // ignore cache read error
  }

  const platform = detectPlatform(url);

  // 1. YouTube
  if (platform === "YouTube") {
    const videoId = extractYouTubeVideoId(url);
    const fallbackThumbnail = videoId
      ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
      : null;

    try {
      const res = await fetch(
        `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`,
        {
          signal: AbortSignal.timeout(3500),
          headers: { "User-Agent": BROWSER_USER_AGENT },
        },
      );

      if (res.ok) {
        const data = (await res.json()) as {
          title?: string;
          thumbnail_url?: string;
        };

        const result: LinkPreviewData = {
          url,
          title: data.title ? unescapeHtml(data.title) : "Video de YouTube",
          thumbnail: data.thumbnail_url || fallbackThumbnail,
          platform: "YouTube",
        };
        savePreviewCache(result);
        return result;
      }
    } catch {
      // Fallback on timeout or network error
    }

    const fallback: LinkPreviewData = {
      url,
      title: "Video de YouTube",
      thumbnail: fallbackThumbnail,
      platform: "YouTube",
    };
    savePreviewCache(fallback);
    return fallback;
  }

  // 2. Spotify
  if (platform === "Spotify") {
    try {
      const res = await fetch(
        `https://open.spotify.com/oembed?url=${encodeURIComponent(url)}`,
        {
          signal: AbortSignal.timeout(3500),
          headers: { "User-Agent": BROWSER_USER_AGENT },
        },
      );

      if (res.ok) {
        const data = (await res.json()) as {
          title?: string;
          thumbnail_url?: string;
        };

        const result: LinkPreviewData = {
          url,
          title: data.title ? unescapeHtml(data.title) : "Canción en Spotify",
          thumbnail: data.thumbnail_url || null,
          platform: "Spotify",
        };
        savePreviewCache(result);
        return result;
      }
    } catch {
      // Fallback on timeout or network error
    }

    const fallback: LinkPreviewData = {
      url,
      title: "Canción en Spotify",
      thumbnail: null,
      platform: "Spotify",
    };
    savePreviewCache(fallback);
    return fallback;
  }

  // 3. Instagram & Web (OpenGraph HTML scraping)
  const fallbackTitle =
    platform === "Instagram"
      ? "Publicación de Instagram"
      : url.replace(/^https?:\/\//i, "").replace(/\/$/, "") || "Enlace web";

  try {
    const res = await fetch(url, {
      signal: AbortSignal.timeout(3500),
      headers: {
        "User-Agent": BROWSER_USER_AGENT,
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "es-ES,es;q=0.9,en;q=0.8",
      },
      redirect: "manual",
    });

    if (res.ok) {
      const html = await readLimitedText(res, MAX_HTML_BYTES);
      const ogTitle =
        extractMetaTag(html, "og:title") ||
        extractMetaTag(html, "twitter:title");
      const titleTag = extractTitleTag(html);
      const rawTitle = ogTitle || titleTag;

      const ogImage =
        extractMetaTag(html, "og:image") ||
        extractMetaTag(html, "twitter:image") ||
        extractMetaTag(html, "og:image:url");

      const resolvedTitle = rawTitle ? unescapeHtml(rawTitle) : fallbackTitle;
      const resolvedThumb = ogImage ? resolveThumbnailUrl(ogImage, url) : null;

      const result: LinkPreviewData = {
        url,
        title: resolvedTitle || fallbackTitle,
        thumbnail: resolvedThumb,
        platform,
      };
      savePreviewCache(result);
      return result;
    }
  } catch {
    // Fallback on timeout or network error
  }

  const fallback: LinkPreviewData = {
    url,
    title: fallbackTitle,
    thumbnail: null,
    platform,
  };
  savePreviewCache(fallback);
  return fallback;
}
