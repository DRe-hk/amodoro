import { CORS_HEADERS, jsonResponse } from "@/lib/api-auth";
import { fetchLinkPreview } from "@/lib/link-preview";

export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: CORS_HEADERS,
  });
}

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const url = searchParams.get("url");

    if (!url || typeof url !== "string" || !url.trim()) {
      return jsonResponse(
        { ok: false, error: "Missing or invalid 'url' parameter" },
        400
      );
    }

    const preview = await fetchLinkPreview(url.trim());
    return jsonResponse({ ok: true, preview });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Internal error",
      },
      500
    );
  }
}

export async function POST(request: Request) {
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
        400
      );
    }

    const preview = await fetchLinkPreview(rawUrl.trim());
    return jsonResponse({ ok: true, preview });
  } catch (error) {
    return jsonResponse(
      {
        ok: false,
        error: error instanceof Error ? error.message : "Internal error",
      },
      500
    );
  }
}
