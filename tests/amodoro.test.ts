import test from "node:test";
import assert from "node:assert/strict";
import { db } from "../src/db";
import { users } from "../src/db/schema";
import { formatAuthorLabel } from "../src/lib/identity";
import {
  ACCENT_PALETTES,
  getContrastingInk,
  getRelativeLuminance,
  interpolatePillColor,
} from "../src/lib/contrast";
import {
  changeUserPin,
  createInviteForUser,
  ensureInitialSeed,
  getAllUsers,
  recoverUserPin,
  redeemInviteByTokenOrCode,
  registerNewUser,
  verifyUserPin,
} from "../src/lib/auth";
import {
  addBoardItem,
  completeBoardItem,
  listBoardsWithItems,
  listCompletedBoardItems,
  reactToBoardItem,
} from "../src/lib/boards";
import {
  spinRouletteDecision,
  startVotingDecision,
  submitVotingRoundChoices,
  getCurrentDecisionState,
} from "../src/lib/decision";
import { assertSafeExternalUrl } from "../src/lib/link-preview";
import { detectImageMimeFromMagicBytes } from "../src/lib/media";

test("Regla de apodos: el propio usuario siempre ve YO y la otra persona ve el apodo", () => {
  assert.equal(
    formatAuthorLabel({
      authorId: 1,
      viewerId: 1,
      authorNicknameGivenByPartner: "Rey",
      authorUsername: "drehk",
    }),
    "YO",
  );

  assert.equal(
    formatAuthorLabel({
      authorId: 1,
      viewerId: 2,
      authorNicknameGivenByPartner: "Rey",
      authorUsername: "drehk",
    }),
    "Rey",
  );
});

test("Auto-contraste de fondos pastel M3 e interpolación de la píldora deslizante", () => {
  const lightPastelLuminance = getRelativeLuminance("#FADADD");
  assert.ok(lightPastelLuminance > 0.5);

  const inkOnPastel = getContrastingInk("#FADADD");
  assert.ok(
    inkOnPastel.text.startsWith("rgb(") || inkOnPastel.text.startsWith("#"),
  );

  const inkOnDark = getContrastingInk("#692323");
  assert.equal(inkOnDark.text, "#FDF8F5");

  const pills = ACCENT_PALETTES["fig-sage"].light.pills;
  const atHome = interpolatePillColor(0, pills);
  const atBoards = interpolatePillColor(1, pills);
  const atSettings = interpolatePillColor(2, pills);
  assert.equal(atHome.bg.toUpperCase(), pills.home.bg.toUpperCase());
  assert.equal(atBoards.bg.toUpperCase(), pills.boards.bg.toUpperCase());
  assert.equal(atSettings.bg.toUpperCase(), pills.settings.bg.toUpperCase());
});

test("Seguridad V1.5: Límite estricto de 2 cuentas, PIN de 4 dígitos, vinculación y recuperación", async () => {
  ensureInitialSeed();
  db.delete(users).run();

  const userA = await registerNewUser({
    displayName: "UsuarioUno",
    pin: "1234",
    avatarId: "cat",
  });
  assert.ok(userA.id);
  assert.ok(userA.recoveryCode);
  assert.equal(await verifyUserPin(userA.id, "1234"), true);
  assert.equal(await verifyUserPin(userA.id, "9999"), false);

  const invite = createInviteForUser(userA.id);
  const userB = await registerNewUser({
    displayName: "UsuarioDos",
    pin: "5678",
    avatarId: "rabbit",
    code: invite.code,
  });
  assert.ok(userB.id);
  assert.equal(userB.partnerId, userA.id);

  // 3rd user registration must be rejected
  await assert.rejects(
    () =>
      registerNewUser({
        displayName: "Intruso",
        pin: "0000",
      }),
    /2 cuentas registradas/,
  );

  // Change PIN and verify
  const changed = await changeUserPin({
    userId: userA.id,
    currentPin: "1234",
    newPin: "4321",
  });
  assert.equal(await verifyUserPin(userA.id, "4321"), true);

  // Recover PIN using personal recovery code
  await recoverUserPin({
    userId: userA.id,
    recoveryCode: changed.recoveryCode,
    newPin: "2468",
  });
  assert.equal(await verifyUserPin(userA.id, "2468"), true);

  // Recover PIN using partner-generated reset code
  const partnerReset = createInviteForUser(userB.id);
  await recoverUserPin({
    userId: userA.id,
    recoveryCode: partnerReset.code,
    newPin: "1357",
  });
  assert.equal(await verifyUserPin(userA.id, "1357"), true);

  // Re-ensure paired if needed
  if (!getAllUsers().find((u) => u.id === userA.id)?.partnerId) {
    const pairInvite = createInviteForUser(userA.id);
    redeemInviteByTokenOrCode({
      code: pairInvite.code,
      redeemingUserId: userB.id,
    });
  }
});

test("Historial de Actividades Completadas: exige foto o mensaje y conserva reacciones", async () => {
  ensureInitialSeed();
  const [userA, userB] = getAllUsers();
  assert.ok(userA && userB);

  const { actividadesBoardId } = listBoardsWithItems(userA.id);
  const item = addBoardItem({
    boardId: actividadesBoardId,
    title: "Cita de café y postre",
    userId: userA.id,
    dueDate: "2026-12-01",
  });

  // Attempting to complete without photo or message must fail
  assert.throws(
    () =>
      completeBoardItem({
        itemId: item.id,
        userId: userA.id,
      }),
    /Añade una foto, imagen o mensaje/,
  );

  // Completing with a message moves it to completedHistory
  const completed = completeBoardItem({
    itemId: item.id,
    userId: userB.id,
    completionText: "¡Estuvo delicioso el cheesecake!",
  });
  assert.ok(completed.completedAt);
  assert.equal(completed.completedBy, userB.id);

  // React to the completed item and toggle reaction off
  reactToBoardItem({
    itemId: item.id,
    userId: userA.id,
    emoji: "❤️",
  });
  let history = listCompletedBoardItems(userA.id);
  const found = history.find((h) => h.id === item.id);
  assert.ok(found);
  assert.equal(found.completionText, "¡Estuvo delicioso el cheesecake!");
  assert.equal(found.reactions.length, 1);

  // Tapping the same emoji removes the reaction
  reactToBoardItem({
    itemId: item.id,
    userId: userA.id,
    emoji: "❤️",
  });
  history = listCompletedBoardItems(userA.id);
  assert.equal(history.find((h) => h.id === item.id)?.reactions.length, 0);
});

test("Seguridad SSRF y Validación de Magic Bytes en Imágenes", async () => {
  await assert.rejects(
    () => assertSafeExternalUrl("http://127.0.0.1:3050/api/v1/sync"),
    /no permitida/,
  );
  await assert.rejects(
    () => assertSafeExternalUrl("http://169.254.169.254/latest/meta-data/"),
    /no permitida/,
  );
  await assert.rejects(
    () => assertSafeExternalUrl("file:///etc/passwd"),
    /HTTP/,
  );

  // Fake SVG/HTML buffer disguised as image must be rejected
  const fakeSvg = Buffer.from("<svg onload=alert(1)></svg>", "utf8");
  assert.equal(detectImageMimeFromMagicBytes(fakeSvg), null);

  // Valid PNG magic bytes must be detected as image/png
  const validPngHeader = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
  ]);
  assert.deepEqual(detectImageMimeFromMagicBytes(validPngHeader), {
    mime: "image/png",
    ext: "png",
  });
});

test("Motor de Decisión: Ruleta y Votación ciega de 4-5 actividades con acuerdo y desempate", async () => {
  ensureInitialSeed();
  const [userA, userB] = getAllUsers();
  assert.ok(userA && userB);

  const { actividadesBoardId, itemsByBoardId } = listBoardsWithItems(userA.id);
  if ((itemsByBoardId[actividadesBoardId]?.length ?? 0) < 5) {
    for (let i = 1; i <= 5; i++) {
      addBoardItem({
        boardId: actividadesBoardId,
        title: `Actividad ${i}`,
        userId: userA.id,
      });
    }
  }

  // 1. Roulette picks a single random activity and resolves immediately
  const roulette = spinRouletteDecision();
  assert.ok(roulette);
  assert.equal(roulette.mode, "roulette");
  assert.equal(roulette.status, "resolved");
  assert.ok(roulette.winner);

  // 2. Voting round selects 4-5 random candidates
  const voting = startVotingDecision(5);
  assert.ok(voting);
  assert.equal(voting.status, "voting");
  assert.equal(voting.roundNumber, 1);
  assert.ok(voting.candidates.length >= 4 && voting.candidates.length <= 5);

  const [c1, c2] = voting.candidates;
  assert.ok(c1 && c2);

  // User A votes for c1 and c2; partner hasn't voted yet -> remains in round 1
  submitVotingRoundChoices({
    sessionId: voting.id,
    userId: userA.id,
    wantedItemIds: [c1.id, c2.id],
  });
  let state = getCurrentDecisionState(userA.id);
  assert.equal(state?.status, "voting");
  assert.equal(state?.roundNumber, 1);

  // User B votes for c1 and c2 -> Tie (2 matches)! Advances automatically to round 2 with only [c1, c2]
  submitVotingRoundChoices({
    sessionId: voting.id,
    userId: userB.id,
    wantedItemIds: [c1.id, c2.id],
  });
  state = getCurrentDecisionState(userA.id);
  assert.equal(state?.status, "voting");
  assert.equal(state?.roundNumber, 2);
  assert.equal(state?.candidates.length, 2);

  // In Round 2, both vote ONLY for c1 -> Single match! Winner resolved!
  submitVotingRoundChoices({
    sessionId: voting.id,
    userId: userA.id,
    wantedItemIds: [c1.id],
  });
  submitVotingRoundChoices({
    sessionId: voting.id,
    userId: userB.id,
    wantedItemIds: [c1.id],
  });
  state = getCurrentDecisionState(userA.id);
  assert.equal(state?.status, "resolved");
  assert.equal(state?.winner?.id, c1.id);
});
