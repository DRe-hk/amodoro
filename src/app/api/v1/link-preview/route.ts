import { CORS_HEADERS, getApiUser, jsonResponse } from "@/lib/api-auth";
import { fetchLinkPreview } from "@/lib/link-preview";
import { checkRateLimit, getClientIp } from "@/lib/rate-limit";

export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: CORS_HEADERS,
  });
}

export async function GET(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  const rl = checkRateLimit(
    `link_preview:${user.id}:${getClientIp(request)}`,
    30,
    60_000,
  );
  if (!rl.allowed) {
    return jsonResponse({ ok: false, error: "Demasiadas solicitudes" }, 429);
  }

  try {
    const { searchParams } = new URL(request.url);
    const url = searchParams.get("url");

    if (!url || typeof url !== "string" || !url.trim()) {
      return jsonResponse(
        { ok: false, error: "Missing or invalid 'url' parameter" },
        400,
      );
    }

    const preview = await fetchLinkPreview(url.trim());
    return jsonResponse({ ok: true, preview });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Invalid URL",
      },
      400,
    );
  }
}

export async function POST(request: Request) {
  const user = getApiUser(request);
  if (!user) {
    return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
  }

  const rl = checkRateLimit(
    `link_preview:${user.id}:${getClientIp(request)}`,
    30,
    60_000,
  );
  if (!rl.allowed) {
    return jsonResponse({ ok: false, error: "Demasiadas solicitudes" }, 429);
  }

  try {
    let body: { url?: unknown };
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ ok: false, error: "Invalid JSON body" }, 400);
    }

    const rawUrl = body?.url;
    if (!rawUrl || typeof rawUrl !== "string" || !rawUrl.trim()) {
      return jsonResponse(
        { ok: false, error: "Missing or invalid 'url' in request body" },
        400,
      );
    }

    const preview = await fetchLinkPreview(rawUrl.trim());
    return jsonResponse({ ok: true, preview });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Invalid URL",
      },
      400,
    );
  }
}
