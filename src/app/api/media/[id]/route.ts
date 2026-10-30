import { readFile } from "node:fs/promises";
import { absoluteUploadPath, getMediaById } from "@/lib/media";

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const { id: rawId } = await context.params;
  const id = Number(rawId);
  if (!Number.isInteger(id) || id <= 0) {
    return new Response("Not Found", { status: 404 });
  }

  const row = getMediaById(id);
  if (!row) {
    return new Response("Not Found", { status: 404 });
  }

  const absPath = absoluteUploadPath(row.path);
  if (!absPath) {
    return new Response("Not Found", { status: 404 });
  }

  try {
    const bytes = await readFile(absPath);
    return new Response(bytes, {
      status: 200,
      headers: {
        "Content-Type": row.mime,
        "Cache-Control": "private, max-age=31536000, immutable",
      },
    });
  } catch {
    return new Response("Not Found", { status: 404 });
  }
}
