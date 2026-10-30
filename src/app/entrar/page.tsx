import React from "react";
import { redirect } from "next/navigation";
import {
  createSessionForUser,
  getAllUsers,
  redeemInviteByTokenOrCode,
} from "@/lib/auth";

export const dynamic = "force-dynamic";

async function redeemCodeAction(formData: FormData) {
  "use server";
  const code = String(formData.get("code") ?? "").trim();
  const userId = redeemInviteByTokenOrCode({ code });
  if (!userId) {
    redirect("/entrar?error=codigo");
  }
  await createSessionForUser(userId);
  redirect("/");
}

async function quickEnterAction(formData: FormData) {
  "use server";
  const userId = Number(formData.get("userId"));
  const all = getAllUsers();
  const target = all.find((u) => u.id === userId);
  if (!target) {
    redirect("/entrar");
  }
  await createSessionForUser(target.id);
  redirect("/");
}

export default async function EntrarPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const people = getAllUsers();

  return (
    <div className="min-h-dvh flex flex-col items-center justify-center bg-[#FCF9F5] text-[#1F1B18] px-4 py-10">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center space-y-1.5">
          <div className="mx-auto inline-flex items-center gap-1.5 rounded-full bg-[#F2B8B5] px-4 py-1 text-[11px] font-extrabold uppercase tracking-[0.15em] text-[#410E0B]">
            Amodoro
          </div>
          <h1 className="font-card-serif text-3xl font-semibold tracking-tight pt-1">
            Nuestro espacio diario
          </h1>
          <p className="text-xs text-[#6E655F]">
            Entra con un toque o canjea tu código a distancia
          </p>
        </div>

        {params.error ? (
          <div className="rounded-2xl border border-[#8C3A36]/25 bg-[#F2B8B5]/40 p-3 text-center text-xs font-semibold text-[#410E0B]">
            {params.error === "codigo"
              ? "Ese código no es válido o ya fue usado."
              : "El enlace de invitación ha caducado."}
          </div>
        ) : null}

        {/* Quick 1-Tap Profile Selection for Zero Friction */}
        <section className="rounded-[28px] border border-black/10 bg-[#F4EFE8] p-5 space-y-3 m3-floating-card">
          <h2 className="text-xs font-bold uppercase tracking-wider text-[#6E655F]">
            Entrar directo (1 toque)
          </h2>
          <div className="grid grid-cols-1 gap-2.5">
            {people.map((person, index) => (
              <form key={person.id} action={quickEnterAction}>
                <input type="hidden" name="userId" value={person.id} />
                <button
                  type="submit"
                  className={[
                    "flex w-full items-center justify-between rounded-2xl px-4 py-3.5 text-left shadow-xs active:scale-[0.98] transition-transform",
                    index === 0
                      ? "bg-[#F2B8B5] text-[#410E0B]"
                      : "bg-[#B8E0C8] text-[#0B3822]",
                  ].join(" ")}
                >
                  <div>
                    <span className="block text-sm font-extrabold">
                      @{person.username}
                    </span>
                    <span className="block text-[11px] opacity-80">
                      Apodo de tu pareja para ti: {person.nicknameByPartner}
                    </span>
                  </div>
                  <span className="text-xs font-bold uppercase tracking-wider">
                    Entrar →
                  </span>
                </button>
              </form>
            ))}
          </div>
        </section>

        {/* Short Invite Code Redemption */}
        <section className="rounded-[28px] border border-black/10 bg-[#F4EFE8] p-5 space-y-3">
          <h2 className="text-xs font-bold uppercase tracking-wider text-[#6E655F]">
            O pegar código de invitación a distancia
          </h2>
          <form action={redeemCodeAction} className="flex gap-2">
            <input
              type="text"
              name="code"
              required
              placeholder="K7M2-9QXP"
              className="flex-1 rounded-2xl border border-black/15 bg-[#FCF9F5] px-3.5 py-2.5 font-mono text-sm font-bold uppercase tracking-widest focus:outline-none"
            />
            <button
              type="submit"
              className="rounded-2xl bg-[#E6CBA8] px-4 py-2.5 text-xs font-bold uppercase tracking-wider text-[#3B260B]"
            >
              Canjear
            </button>
          </form>
        </section>
      </div>
    </div>
  );
}
