import test from "node:test";
import assert from "node:assert/strict";
import { formatAuthorLabel } from "../src/lib/identity";
import {
  ACCENT_PALETTES,
  getContrastingInk,
  getRelativeLuminance,
  interpolatePillColor,
} from "../src/lib/contrast";
import { ensureInitialSeed, getAllUsers } from "../src/lib/auth";
import {
  spinRouletteDecision,
  startVotingDecision,
  submitVotingRoundChoices,
  getCurrentDecisionState,
} from "../src/lib/decision";

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

test("Motor de Decisión: Ruleta y Votación ciega de 4-5 actividades con acuerdo y desempate", () => {
  ensureInitialSeed();
  const [userA, userB] = getAllUsers();
  assert.ok(userA && userB);

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
