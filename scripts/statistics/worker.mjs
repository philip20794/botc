import { FieldPath, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { compareCursors, contributionsForGame, incrementedCounters } from './aggregate.mjs';

const PROGRESS_PATH = 'statistics_private/progress';
const GAME_COLLECTION = 'games';
const RECEIPTS_COLLECTION = 'statistics_processed';
const PAGE_SIZE = 50;
const DEFAULT_MAX_GAMES = 200;

function countersWithIncrement(counters) {
  return incrementedCounters(counters, (number) => FieldValue.increment(number));
}

function applyContributions(transaction, database, values) {
  transaction.set(database.doc('statistics/global'), {
    schemaVersion: 1,
    ...countersWithIncrement(values.global),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  const byRole = {};
  for (const [roleId, counters] of Object.entries(values.roles)) {
    byRole[roleId] = countersWithIncrement(counters);
  }
  transaction.set(database.doc('statistics/roles'), {
    schemaVersion: 1,
    byRole,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  transaction.set(database.doc(`statistics_scripts/${values.scriptHash}`), {
    schemaVersion: 1,
    ...values.scriptMetadata,
    ...countersWithIncrement(values.scriptCounters),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function processGame(database, snapshot, mode) {
  const progressRef = database.doc(PROGRESS_PATH);
  const receiptRef = database.collection(RECEIPTS_COLLECTION).doc(snapshot.id);
  const game = snapshot.data();
  const uploadedAt = game.uploadedAt;
  const cursor = { uploadedAt, gameId: snapshot.id };

  let contribution;
  let validationError = null;
  try {
    if (game.gameId !== snapshot.id) throw new Error('game ID mismatch');
    contribution = contributionsForGame(game);
  } catch (_) {
    // Public clients can submit invalid values despite basic Rules checks.
    // Do not allow one such record to block all following valid games.
    validationError = 'invalid_game_record';
  }

  return database.runTransaction(async (tx) => {
    // All reads precede writes. A transaction serializes changes to the
    // global cursor, guaranteeing retry-safe at-most-once aggregation.
    const progressSnapshot = await tx.get(progressRef);
    const receiptSnapshot = await tx.get(receiptRef);
    const progress = progressSnapshot.data() ?? {};

    if (mode === 'bootstrap' && progress.bootstrapComplete) return 'already';
    if (mode === 'bootstrap' && progress.bootstrapCursor &&
      snapshot.id <= progress.bootstrapCursor) return 'already';
    if (mode === 'reconcile' && progress.reconcileCursor &&
      snapshot.id <= progress.reconcileCursor) return 'already';
    if (mode === 'live' && progress.liveCursor &&
      compareCursors(cursor, progress.liveCursor) <= 0) return 'already';

    if (!receiptSnapshot.exists) {
      if (contribution) applyContributions(tx, database, contribution);
      tx.create(receiptRef, {
        status: validationError ?? 'counted',
        processedAt: FieldValue.serverTimestamp(),
      });
    }

    const updates = { updatedAt: FieldValue.serverTimestamp() };
    if (mode === 'bootstrap') updates.bootstrapCursor = snapshot.id;
    if (mode === 'reconcile') updates.reconcileCursor = snapshot.id;
    if (mode === 'live') updates.liveCursor = cursor;
    if (!receiptSnapshot.exists) {
      updates.handledGames = FieldValue.increment(1);
      if (validationError) updates.invalidGames = FieldValue.increment(1);
    }
    tx.set(progressRef, updates, { merge: true });
    return receiptSnapshot.exists ? 'already' : (validationError ? 'invalid' : 'counted');
  });
}

async function completeScan(database, mode) {
  const progressRef = database.doc(PROGRESS_PATH);
  await database.runTransaction(async (tx) => {
    const snapshot = await tx.get(progressRef);
    if (mode === 'bootstrap' && !snapshot.get('bootstrapComplete')) {
      tx.set(progressRef, { bootstrapComplete: true,
        bootstrapCompletedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    if (mode === 'reconcile') {
      // A new manual reconciliation must start at the first document again.
      tx.set(progressRef, { reconcileCursor: FieldValue.delete(),
        lastReconciledAt: FieldValue.serverTimestamp() }, { merge: true });
    }
  });
}

async function scanById(database, mode, maxGames) {
  let visited = 0;
  let counted = 0;
  let invalid = 0;
  while (visited < maxGames) {
    const progress = (await database.doc(PROGRESS_PATH).get()).data() ?? {};
    if (mode === 'bootstrap' && progress.bootstrapComplete) {
      return { mode, visited, counted, invalid, complete: true };
    }

    let query = database.collection(GAME_COLLECTION)
      .orderBy(FieldPath.documentId())
      .limit(Math.min(PAGE_SIZE, maxGames - visited));
    const cursorId = mode === 'bootstrap'
      ? progress.bootstrapCursor : progress.reconcileCursor;
    if (cursorId) query = query.startAfter(cursorId);
    const batch = await query.get();
    for (const item of batch.docs) {
      const outcome = await processGame(database, item, mode);
      if (outcome === 'counted') counted++;
      if (outcome === 'invalid') invalid++;
      visited++;
    }
    if (batch.empty || batch.size < Math.min(PAGE_SIZE, maxGames - (visited - batch.size))) {
      await completeScan(database, mode);
      return { mode, visited, counted, invalid, complete: true };
    }
  }
  return { mode, visited, counted, invalid, complete: false };
}

async function scanNewUploads(database, maxGames) {
  let visited = 0;
  let counted = 0;
  let invalid = 0;
  while (visited < maxGames) {
    const progress = (await database.doc(PROGRESS_PATH).get()).data() ?? {};
    let query = database.collection(GAME_COLLECTION)
      .orderBy('uploadedAt')
      .orderBy(FieldPath.documentId())
      .limit(Math.min(PAGE_SIZE, maxGames - visited));
    if (progress.liveCursor) {
      const { uploadedAt, gameId } = progress.liveCursor;
      query = query.startAfter(uploadedAt, gameId);
    }
    const batch = await query.get();
    if (batch.empty) return { mode: 'live', visited, counted, invalid, complete: true };
    for (const doc of batch.docs) {
      if (!(doc.get('uploadedAt') instanceof Timestamp)) {
        throw new Error('Invalid uploadedAt type in ordered Firestore query');
      }
      const result = await processGame(database, doc, 'live');
      if (result === 'counted') counted++;
      if (result === 'invalid') invalid++;
      visited++;
    }
    if (batch.size < Math.min(PAGE_SIZE, maxGames - (visited - batch.size))) {
      return { mode: 'live', visited, counted, invalid, complete: true };
    }
  }
  return { mode: 'live', visited, counted, invalid, complete: false };
}

/** Process up to maxGames records with durable, transactional checkpoints.
 *  One-time bootstrapping imports existing, unstamped games exactly once.
 *  Subsequent runs use uploadedAt indexes, never re-read the entire history.
 *  Manual reconcile is available for older APKs missing uploadedAt.
 */
export async function updateStatistics(database, {
  mode = 'incremental',
  maxGames = DEFAULT_MAX_GAMES,
} = {}) {
  if (!Number.isSafeInteger(maxGames) || maxGames <= 0) {
    throw new Error('maxGames must be positive');
  }
  if (mode === 'reconcile') return scanById(database, 'reconcile', maxGames);
  if (mode !== 'incremental') throw new Error('Unknown statistics mode');
  const progress = (await database.doc(PROGRESS_PATH).get()).data() ?? {};
  if (!progress.bootstrapComplete) return scanById(database, 'bootstrap', maxGames);
  return scanNewUploads(database, maxGames);
}
