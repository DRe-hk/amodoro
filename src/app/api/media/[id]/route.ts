import { readFile } from "node:fs/promises";
import { getPartnerUser } from "@/lib/auth";
import { getApiUserFromRequestOrQuery } from "@/lib/api-auth";
import {
  ALLOWED_IMAGE_TYPES,
  absoluteUploadPath,
  getMediaById,
  type AllowedImageType,
} from "@/lib/media";

export async function GET(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const user = getApiUserFromRequestOrQuery(request);
  if (!user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const { id: rawId } = await context.params;
  const id = Number(rawId);
  if (!Number.isInteger(id) || id <= 0) {
    return new Response("Not Found", { status: 404 });
  }

  const row = getMediaById(id);
  if (!row) {
    return new Response("Not Found", { status: 404 });
  }

  const partner = getPartnerUser(user.id);
  if (row.ownerId !== user.id && row.ownerId !== partner?.id) {
    return new Response("Forbidden", { status: 403 });
  }

  const absPath = absoluteUploadPath(row.path);
  if (!absPath) {
    return new Response("Not Found", { status: 404 });
  }

  const safeMime = ALLOWED_IMAGE_TYPES.includes(row.mime as AllowedImageType)
    ? row.mime
    : "image/png";

  try {
    const bytes = await readFile(absPath);
    return new Response(bytes, {
      status: 200,
      headers: {
        "Content-Type": safeMime,
        "X-Content-Type-Options": "nosniff",
        "Content-Disposition": "inline",
        "Content-Security-Policy":
          "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'",
        "Cache-Control": "private, max-age=31536000, immutable",
      },
    });
  } catch {
    return new Response("Not Found", { status: 404 });
  }
}
