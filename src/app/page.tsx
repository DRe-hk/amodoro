import React from "react";

export const dynamic = "force-dynamic";

export default function StatusPage() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-[#FCF9F5] text-[#2B1F1E] p-6">
      <div className="max-w-sm w-full rounded-3xl bg-[#F4EFE8] p-8 text-center shadow-sm">
        <div className="inline-flex h-12 w-12 items-center justify-center rounded-2xl bg-[#FFDAD6] text-[#410E0B] text-xl font-bold mb-4">
          ♥
        </div>
        <h1 className="text-xl font-bold tracking-tight">Amodoro API v1.5</h1>
        <p className="mt-2 text-sm opacity-75">
          Servicio privado activo para la aplicación nativa Android.
        </p>
      </div>
    </main>
  );
}
