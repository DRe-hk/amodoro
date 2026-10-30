import { createInviteForUser, ensureInitialSeed, getAllUsers } from "../src/lib/auth";

ensureInitialSeed();
const usernameArg = process.argv[2]?.toLowerCase().trim();
const all = getAllUsers();
const target = usernameArg
  ? all.find((u) => u.username.toLowerCase() === usernameArg)
  : all[0];

if (!target) {
  console.error(
    `Usuario no encontrado. Usuarios disponibles: ${all.map((u) => u.username).join(", ")}`,
  );
  process.exit(1);
}

const invite = createInviteForUser(target.id);
const baseUrl = process.env.PUBLIC_URL ?? "http://localhost:3000";

console.log(`=== Invitación de Amodoro para @${target.username} ===`);
console.log(`Código corto (8 caracteres): ${invite.code}`);
console.log(`Enlace directo: ${baseUrl}/entrar/${invite.token}`);
console.log(`Expira: ${invite.expiresAt.toISOString()}`);
