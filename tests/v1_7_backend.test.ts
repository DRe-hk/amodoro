import "./setup-v1-7-db";
import test from "node:test";
import assert from "node:assert/strict";
import { db } from "../src/db";
import { sessions, users } from "../src/db/schema";
import {
  changeUserPin,
  createInviteForUser,
  createSessionForUser,
  ensureInitialSeed,
  registerNewUser,
} from "../src/lib/auth";
import { loginApiUser } from "../src/lib/api-auth";
import {
  adminResetUserPin,
  adminPruneOldSessions,
} from "../src/lib/admin-service";
import { GET as syncGET } from "../src/app/api/v1/sync/route";
import {
  createSticker,
  deleteSticker,
  listStickers,
} from "../src/lib/stickers";
import {
  createHomeCard,
  getSentHomeCards,
  replyToHomeCard,
} from "../src/lib/home-cards";
import { eq } from "drizzle-orm";

// Minimal valid PNG buffer
const VALID_PNG_BUFFER = Buffer.from(
  "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082",
  "hex",
);

async function getOrCreateTestCouple() {
  ensureInitialSeed();
  db.delete(users).run();
  const u1 = await registerNewUser({
    displayName: "UserA",
    pin: "1111",
    avatarId: "cat",
  });
  const inv = createInviteForUser(u1.id);
  const u2 = await registerNewUser({
    displayName: "UserB",
    pin: "2222",
    avatarId: "rabbit",
    code: inv.code,
  });
  return [u1, u2] as const;
}

test("Backend v1.7.0: Reutilización de token en verify_pin / pin_login no duplica sesiones", async () => {
  const [userA] = await getOrCreateTestCouple();

  adminResetUserPin(userA.id, "1234");

  // Create an initial session
  const initialSession = await createSessionForUser(userA.id, {
    userAgent: "AmodoroTest/1.0",
  });
  const token = initialSession.id;

  const countBefore = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userA.id))
    .all().length;

  // Verify PIN passing the existing rawToken and currentUserId
  const res = await loginApiUser({
    mode: "verify_pin",
    currentUserId: userA.id,
    rawToken: token,
    pin: "1234",
    userAgent: "AmodoroTest/1.0",
  });

  assert.ok(res, "Login debe ser exitoso");
  assert.equal(res.token, token, "Debe reutilizar el mismo token");
  assert.equal(res.reused, true, "reused debe ser true");

  const countAfter = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userA.id))
    .all().length;

  assert.equal(
    countAfter,
    countBefore,
    "La cantidad de sesiones no debe aumentar al reutilizar token",
  );
});

test("Backend v1.7.0: Upsert por deviceId (1 sesión por dispositivo)", async () => {
  const [userA] = await getOrCreateTestCouple();
  const testDeviceId = "phone-xyz-987";

  // Create first session for this device
  const s1 = await createSessionForUser(userA.id, {
    deviceId: testDeviceId,
    deviceName: "Pixel 8 Pro",
    userAgent: "MobileApp/1.0",
  });

  const matchingSessions1 = db
    .select()
    .from(sessions)
    .where(eq(sessions.deviceId, testDeviceId))
    .all();
  assert.equal(matchingSessions1.length, 1);
  assert.equal(matchingSessions1[0]?.deviceName, "Pixel 8 Pro");

  // Create second session with the same deviceId
  const s2 = await createSessionForUser(userA.id, {
    deviceId: testDeviceId,
    deviceName: "Pixel 8 Pro - Updated",
    userAgent: "MobileApp/1.1",
  });

  assert.notEqual(s1.id, s2.id, "Debe generar un nuevo token al rotar");

  const matchingSessions2 = db
    .select()
    .from(sessions)
    .where(eq(sessions.deviceId, testDeviceId))
    .all();

  assert.equal(
    matchingSessions2.length,
    1,
    "Debe existir exactamente 1 sesión para este deviceId (upsert/rotación)",
  );
  assert.equal(matchingSessions2[0]?.deviceName, "Pixel 8 Pro - Updated");
});

test("Backend v1.7.0: Modo check_pin valida PIN sin crear sesión", async () => {
  const [userA] = await getOrCreateTestCouple();

  adminResetUserPin(userA.id, "4321");

  const sessionsBefore = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userA.id))
    .all().length;

  // Correct PIN
  const validRes = await loginApiUser({
    mode: "check_pin",
    userId: userA.id,
    pin: "4321",
  });

  assert.ok(validRes && "checkedPin" in validRes);
  assert.equal(validRes.valid, true);
  assert.equal(validRes.user.id, userA.id);

  // Wrong PIN
  const invalidRes = await loginApiUser({
    mode: "check_pin",
    userId: userA.id,
    pin: "0000",
  });

  assert.ok(invalidRes && "checkedPin" in invalidRes);
  assert.equal(invalidRes.valid, false);

  const sessionsAfter = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userA.id))
    .all().length;

  assert.equal(
    sessionsAfter,
    sessionsBefore,
    "check_pin jamás debe crear filas en sessions",
  );
});

test("Backend v1.7.0: Incremento de pinVersion al cambiar PIN y al reset de admin", async () => {
  const [userA] = await getOrCreateTestCouple();

  adminResetUserPin(userA.id, "1234");
  const freshUser = db
    .select()
    .from(users)
    .where(eq(users.id, userA.id))
    .get();
  const initialVersion = freshUser?.pinVersion ?? 1;

  // Change PIN via user action
  await changeUserPin({
    userId: userA.id,
    currentPin: "1234",
    newPin: "5555",
  });

  const afterChange = db
    .select()
    .from(users)
    .where(eq(users.id, userA.id))
    .get();
  assert.equal(
    afterChange?.pinVersion,
    initialVersion + 1,
    "pinVersion debe incrementarse en 1 tras cambiar PIN",
  );

  // Reset PIN via admin
  adminResetUserPin(userA.id, "6666");

  const afterAdmin = db
    .select()
    .from(users)
    .where(eq(users.id, userA.id))
    .get();
  assert.equal(
    afterAdmin?.pinVersion,
    initialVersion + 2,
    "pinVersion debe incrementarse tras admin reset",
  );
});

test("Backend v1.7.0: Sincronización con ETag y respuesta 304 Not Modified", async () => {
  const [userA] = await getOrCreateTestCouple();
  const session = await createSessionForUser(userA.id);

  // First request: status 200 with ETag header and pinVersion in payload
  const req1 = new Request("http://localhost:3000/api/v1/sync", {
    headers: {
      Authorization: `Bearer ${session.id}`,
    },
  });

  const res1 = await syncGET(req1);
  assert.equal(res1.status, 200);

  const etag = res1.headers.get("etag");
  assert.ok(etag, "La respuesta 200 debe incluir cabecera ETag");

  const body1 = (await res1.json()) as {
    ok: boolean;
    currentUser: { pinVersion: number };
    me: { pinVersion: number };
  };
  assert.equal(body1.ok, true);
  assert.ok(typeof body1.currentUser.pinVersion === "number");
  assert.equal(body1.currentUser.pinVersion, body1.me.pinVersion);

  // Second request: If-None-Match with same ETag => 304 Not Modified
  const req2 = new Request("http://localhost:3000/api/v1/sync", {
    headers: {
      Authorization: `Bearer ${session.id}`,
      "If-None-Match": etag,
    },
  });

  const res2 = await syncGET(req2);
  assert.equal(res2.status, 304, "Debe responder 304 Not Modified");
  assert.equal(res2.headers.get("etag"), etag);
  const text2 = await res2.text();
  assert.equal(text2, "", "El cuerpo de 304 debe estar vacío");
});

test("Backend v1.7.0: Módulo de stickers, cuotas, listado y respuesta a tarjetas", async () => {
  const [userA, userB] = await getOrCreateTestCouple();

  // Test create sticker
  const sticker = await createSticker(userA.id, VALID_PNG_BUFFER);
  assert.ok(sticker.id);
  assert.equal(sticker.ownerId, userA.id);
  assert.equal(sticker.isMine, true);
  assert.ok(sticker.mediaUrl.startsWith("/api/media/"));

  // List stickers as owner
  const listA = listStickers(userA.id);
  const foundA = listA.find((s) => s.id === sticker.id);
  assert.ok(foundA);
  assert.equal(foundA.isMine, true);

  // List stickers as partner
  const listB = listStickers(userB.id);
  const foundB = listB.find((s) => s.id === sticker.id);
  assert.ok(foundB);
  assert.equal(foundB.isMine, false, "Para la pareja isMine debe ser false");

  // Create home card from userA
  const card = createHomeCard({
    authorId: userA.id,
    body: "Mensaje de prueba con sticker",
    bgColor: "#FFDAD6",
    fontFamily: "sans",
    fontSize: "md",
  });

  // Reply to home card using the sticker
  const reply = replyToHomeCard(userB.id, {
    cardId: card.id,
    stickerId: sticker.id,
    textContent: "¡Me encanta!",
  });

  assert.equal(reply.mediaType, "sticker");
  assert.equal(reply.mediaUrl, sticker.mediaUrl);

  // Verify card author (userA) sees the reply in sent cards
  const sentCards = getSentHomeCards(userA.id);
  const targetCard = sentCards.find((c) => c.id === card.id);
  assert.ok(targetCard);
  const stickerReply = targetCard.replies.find((r) => r.id === reply.id);
  assert.ok(stickerReply);
  assert.equal(stickerReply.mediaType, "sticker");
  assert.equal(stickerReply.mediaUrl, sticker.mediaUrl);

  // User B cannot delete User A's sticker
  assert.throws(
    () => deleteSticker(sticker.id, userB.id),
    /No tienes permiso para eliminar este sticker/,
  );

  // User A can delete their sticker
  const delRes = deleteSticker(sticker.id, userA.id);
  assert.equal(delRes.deleted, true);

  const listAfter = listStickers(userA.id);
  assert.ok(!listAfter.some((s) => s.id === sticker.id));

  // Validation: non-png/webp
  await assert.rejects(
    () => createSticker(userA.id, Buffer.from("not-an-image-file")),
    /Formato no permitido/,
  );
});

test("Backend v1.7.0: Admin podado de sesiones acumuladas", async () => {
  const [userA] = await getOrCreateTestCouple();

  // Create 4 sessions for userA without deviceId
  await createSessionForUser(userA.id, { userAgent: "PruneTest1" });
  await createSessionForUser(userA.id, { userAgent: "PruneTest2" });
  await createSessionForUser(userA.id, { userAgent: "PruneTest3" });
  await createSessionForUser(userA.id, { userAgent: "PruneTest4" });

  const sessionsCountBefore = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userA.id))
    .all().length;
  assert.ok(sessionsCountBefore >= 4);

  // Prune down to 2
  const { prunedCount } = adminPruneOldSessions(2);
  assert.ok(prunedCount >= 2);

  const sessionsCountAfter = db
    .select()
    .from(sessions)
    .where(eq(sessions.userId, userA.id))
    .all().length;
  assert.equal(sessionsCountAfter, 2);
});
