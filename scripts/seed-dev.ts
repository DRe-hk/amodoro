import { ensureInitialSeed, getAllUsers } from "../src/lib/auth";
import { listBoardsWithItems } from "../src/lib/boards";

ensureInitialSeed();
const users = getAllUsers();
const { boards } = listBoardsWithItems();

console.log(
  `Amodoro inicializado con ${users.length} usuarios (${users.map((u) => `@${u.username} [${u.nicknameByPartner}]`).join(", ")}) y ${boards.length} tableros (${boards.map((b) => b.title).join(", ")}).`,
);
