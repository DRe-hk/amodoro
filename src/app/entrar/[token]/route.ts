import { redirect } from "next/navigation";
import { createSessionForUser, redeemInviteByTokenOrCode } from "@/lib/auth";

export async function GET(
  request: Request,
  context: { params: Promise<{ token: string }> },
) {
  const { token } = await context.params;
  const userId = redeemInviteByTokenOrCode({ token });
  if (!userId) {
    redirect("/entrar?error=expirado");
  }
  await createSessionForUser(userId, request.headers.get("user-agent"));
  redirect("/");
}
