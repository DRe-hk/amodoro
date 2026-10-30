export type LinkPreviewData = {
  url: string;
  title: string;
  thumbnail: string | null;
  platform: "YouTube" | "Spotify" | "Instagram" | "Web";
};

const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

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
  if (/^https?:\/\//i.test(trimmed)) {
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
    "i"
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
    return new URL(thumbnail, baseUrl).href;
  } catch {
    return thumbnail.startsWith("http://") || thumbnail.startsWith("https://")
      ? thumbnail
      : null;
  }
}

export async function fetchLinkPreview(rawUrl: string): Promise<LinkPreviewData> {
  const url = normalizeUrl(rawUrl || "");
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
        }
      );

      if (res.ok) {
        const data = (await res.json()) as {
          title?: string;
          thumbnail_url?: string;
        };

        return {
          url,
          title: data.title ? unescapeHtml(data.title) : "Video de YouTube",
          thumbnail: data.thumbnail_url || fallbackThumbnail,
          platform: "YouTube",
        };
      }
    } catch {
      // Fallback on timeout or network error
    }

    return {
      url,
      title: "Video de YouTube",
      thumbnail: fallbackThumbnail,
      platform: "YouTube",
    };
  }

  // 2. Spotify
  if (platform === "Spotify") {
    try {
      const res = await fetch(
        `https://open.spotify.com/oembed?url=${encodeURIComponent(url)}`,
        {
          signal: AbortSignal.timeout(3500),
          headers: { "User-Agent": BROWSER_USER_AGENT },
        }
      );

      if (res.ok) {
        const data = (await res.json()) as {
          title?: string;
          thumbnail_url?: string;
        };

        return {
          url,
          title: data.title ? unescapeHtml(data.title) : "Canción en Spotify",
          thumbnail: data.thumbnail_url || null,
          platform: "Spotify",
        };
      }
    } catch {
      // Fallback on timeout or network error
    }

    return {
      url,
      title: "Canción en Spotify",
      thumbnail: null,
      platform: "Spotify",
    };
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
      redirect: "follow",
    });

    if (res.ok) {
      const html = await res.text();
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

      return {
        url,
        title: resolvedTitle || fallbackTitle,
        thumbnail: resolvedThumb,
        platform,
      };
    }
  } catch {
    // Fallback on timeout or network error
  }

  return {
    url,
    title: fallbackTitle,
    thumbnail: null,
    platform,
  };
}
