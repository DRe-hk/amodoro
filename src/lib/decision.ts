import { and, desc, eq, inArray, isNull } from "drizzle-orm";
import { db } from "@/db";
import {
  boardItems,
  boards,
  decisionSessions,
  decisionVotes,
  users,
} from "@/db/schema";
import { getPartnerUser } from "./auth";

export type CandidateItem = {
  id: number;
  categoryTag: string;
  title: string;
  notes: string | null;
  emoji: string | null;
};

export type ActiveDecisionState = {
  id: number;
  mode: "roulette" | "voting";
  status: "voting" | "resolved";
  roundNumber: number;
  candidates: CandidateItem[];
  mySubmittedVotes: Record<number, boolean> | null;
  partnerHasVoted: boolean;
  winner: CandidateItem | null;
  resolvedAt?: Date | null;
};

function pickRandomSubset<T>(items: T[], count: number): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = copy[i]!;
    copy[i] = copy[j]!;
    copy[j] = tmp;
  }
  return copy.slice(0, Math.min(count, copy.length));
}

export function getActividadesCandidates(viewerId?: number): CandidateItem[] {
  const actBoard = db
    .select()
    .from(boards)
    .where(eq(boards.slug, "actividades"))
    .get();
  if (!actBoard) return [];

  let allowedUserIds: number[] | null = null;
  if (viewerId !== undefined) {
    const partner = getPartnerUser(viewerId);
    allowedUserIds = partner ? [viewerId, partner.id] : [viewerId];
  }

  return db
    .select({
      id: boardItems.id,
      categoryTag: boardItems.categoryTag,
      title: boardItems.title,
      notes: boardItems.notes,
      emoji: boardItems.emoji,
    })
    .from(boardItems)
    .where(
      allowedUserIds
        ? and(
            eq(boardItems.boardId, actBoard.id),
            isNull(boardItems.completedAt),
            inArray(boardItems.addedBy, allowedUserIds),
          )
        : and(
            eq(boardItems.boardId, actBoard.id),
            isNull(boardItems.completedAt),
          ),
    )
    .all();
}

function hydrateCandidatesByIds(ids: number[]): CandidateItem[] {
  if (ids.length === 0) return [];
  const rows = db
    .select({
      id: boardItems.id,
      categoryTag: boardItems.categoryTag,
      title: boardItems.title,
      notes: boardItems.notes,
      emoji: boardItems.emoji,
    })
    .from(boardItems)
    .where(inArray(boardItems.id, ids))
    .all();

  const map = new Map(rows.map((r) => [r.id, r]));
  return ids.map((id) => map.get(id)).filter((x): x is CandidateItem => !!x);
}

export function getCurrentDecisionState(
  viewerId: number,
): ActiveDecisionState | null {
  const latest = db
    .select()
    .from(decisionSessions)
    .orderBy(desc(decisionSessions.id))
    .get();

  if (!latest) return null;

  const candidateIds: number[] = JSON.parse(
    latest.candidateItemIdsJson || "[]",
  );
  const candidates = hydrateCandidatesByIds(candidateIds);

  const roundVotes = db
    .select()
    .from(decisionVotes)
    .where(
      and(
        eq(decisionVotes.sessionId, latest.id),
        eq(decisionVotes.roundNumber, latest.roundNumber),
      ),
    )
    .all();

  const myVotes = roundVotes.filter((v) => v.userId === viewerId);
  const partnerVotes = roundVotes.filter((v) => v.userId !== viewerId);

  let mySubmittedVotes: Record<number, boolean> | null = null;
  if (myVotes.length > 0) {
    mySubmittedVotes = {};
    for (const v of myVotes) {
      mySubmittedVotes[v.itemId] = v.want;
    }
  }

  let winner: CandidateItem | null = null;
  if (latest.winnerItemId) {
    winner = hydrateCandidatesByIds([latest.winnerItemId])[0] ?? null;
  }

  return {
    id: latest.id,
    mode: latest.mode,
    status: latest.status,
    roundNumber: latest.roundNumber,
    candidates,
    mySubmittedVotes,
    partnerHasVoted: partnerVotes.length > 0,
    winner,
    resolvedAt: latest.resolvedAt,
  };
}

/**
 * Mode 1: Roulette — randomly picks 1 activity from Actividades/Pendientes
 */
export function spinRouletteDecision(): ActiveDecisionState | null {
  const pool = getActividadesCandidates();
  if (pool.length === 0) return null;

  const winner = pickRandomSubset(pool, 1)[0]!;
  const now = new Date();

  const session = db
    .insert(decisionSessions)
    .values({
      mode: "roulette",
      status: "resolved",
      roundNumber: 1,
      candidateItemIdsJson: JSON.stringify(pool.map((p) => p.id)),
      winnerItemId: winner.id,
      createdAt: now,
      resolvedAt: now,
    })
    .returning()
    .get();

  return {
    id: session.id,
    mode: "roulette",
    status: "resolved",
    roundNumber: 1,
    candidates: pool,
    mySubmittedVotes: null,
    partnerHasVoted: false,
    winner,
    resolvedAt: session.resolvedAt,
  };
}

/**
 * Mode 2: Voting — selects 4 or 5 random activities from Actividades/Pendientes.
 */
export function startVotingDecision(batchSize = 5): ActiveDecisionState | null {
  const pool = getActividadesCandidates();
  if (pool.length === 0) return null;

  const count = Math.min(Math.max(batchSize, 4), 5, pool.length);
  const subset = pickRandomSubset(pool, count);
  const now = new Date();

  const session = db
    .insert(decisionSessions)
    .values({
      mode: "voting",
      status: "voting",
      roundNumber: 1,
      candidateItemIdsJson: JSON.stringify(subset.map((s) => s.id)),
      winnerItemId: null,
      createdAt: now,
    })
    .returning()
    .get();

  return {
    id: session.id,
    mode: "voting",
    status: "voting",
    roundNumber: 1,
    candidates: subset,
    mySubmittedVotes: null,
    partnerHasVoted: false,
    winner: null,
  };
}

export function submitVotingRoundChoices(input: {
  sessionId: number;
  userId: number;
  wantedItemIds: number[];
}) {
  const session = db
    .select()
    .from(decisionSessions)
    .where(eq(decisionSessions.id, input.sessionId))
    .get();

  if (!session || session.status !== "voting") return;

  const candidateIds: number[] = JSON.parse(
    session.candidateItemIdsJson || "[]",
  );
  const wantedSet = new Set(input.wantedItemIds);
  const now = new Date();

  // Remove any previous votes by this user in this round
  const existing = db
    .select()
    .from(decisionVotes)
    .where(
      and(
        eq(decisionVotes.sessionId, session.id),
        eq(decisionVotes.roundNumber, session.roundNumber),
      ),
    )
    .all();

  for (const row of existing) {
    if (row.userId === input.userId) {
      db.delete(decisionVotes).where(eq(decisionVotes.id, row.id)).run();
    }
  }

  for (const itemId of candidateIds) {
    db.insert(decisionVotes)
      .values({
        sessionId: session.id,
        roundNumber: session.roundNumber,
        itemId,
        userId: input.userId,
        want: wantedSet.has(itemId),
        createdAt: now,
      })
      .run();
  }

  const allUsersList = db.select().from(users).all();
  const allRoundVotes = db
    .select()
    .from(decisionVotes)
    .where(
      and(
        eq(decisionVotes.sessionId, session.id),
        eq(decisionVotes.roundNumber, session.roundNumber),
      ),
    )
    .all();

  const distinctVoterIds = new Set(allRoundVotes.map((v) => v.userId));
  const requiredVoters = Math.min(2, Math.max(1, allUsersList.length));

  if (distinctVoterIds.size < requiredVoters) {
    return;
  }

  const agreedIds = candidateIds.filter((itemId) => {
    const votesForItem = allRoundVotes.filter((v) => v.itemId === itemId);
    return (
      votesForItem.length >= requiredVoters &&
      votesForItem.every((v) => v.want === true)
    );
  });

  if (agreedIds.length === 1) {
    db.update(decisionSessions)
      .set({
        status: "resolved",
        winnerItemId: agreedIds[0]!,
        resolvedAt: now,
      })
      .where(eq(decisionSessions.id, session.id))
      .run();
    return;
  }

  if (agreedIds.length > 1) {
    db.update(decisionSessions)
      .set({
        roundNumber: session.roundNumber + 1,
        candidateItemIdsJson: JSON.stringify(agreedIds),
      })
      .where(eq(decisionSessions.id, session.id))
      .run();
    return;
  }

  const pool = getActividadesCandidates();
  const nextSubset = pickRandomSubset(
    pool,
    Math.min(5, Math.max(4, pool.length)),
  );
  db.update(decisionSessions)
    .set({
      roundNumber: session.roundNumber + 1,
      candidateItemIdsJson: JSON.stringify(nextSubset.map((i) => i.id)),
    })
    .where(eq(decisionSessions.id, session.id))
    .run();
}
