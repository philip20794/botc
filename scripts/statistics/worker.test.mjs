import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { updateStatistics } from './worker.mjs';

function record(gameId, winnerTeam = 'good', uploadedAt) {
  return {
    schemaVersion: 1, gameId,
    startedAt: '2026-10-17T07:00:00.000Z',
    endedAt: '2026-10-17T08:00:00.000Z',
    totalDurationMs: 3600000,
    playerCount: 2, winnerTeam,
    script: {
      scriptId: 'standard:test', name: 'Test script', isCustom: false,
      contentHash: 'a'.repeat(64), roleIds: ['monk', 'imp'],
    },
    players: [
      { actualStartRoleId: 'monk', displayedStartRoleId: 'monk',
        startTeam: 'good', endRoleId: 'monk', endTeam: 'good',
        position: 0, anonymizedPlayerId: 'player_test0001' },
      { actualStartRoleId: 'imp', displayedStartRoleId: 'imp',
        startTeam: 'evil', endRoleId: 'imp', endTeam: 'evil',
        position: 1, anonymizedPlayerId: 'player_test0002' },
    ],
    phases: [{ type: 'night', round: 1, durationMs: 3600000 }],
    chronicleEvents: [],
    ...(uploadedAt ? { uploadedAt } : {}),
  };
}

test('emulator: bootstrap, incremental cursor, replay and legacy reconciliation', async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST,
    'Only run this integration test against a Firestore emulator');
  const app = initializeApp({ projectId: 'b-o-t-c' }, 'statistics-worker-tests');
  const db = getFirestore(app);
  try {
    for (const path of [
      'games', 'statistics', 'statistics_scripts',
      'statistics_private', 'statistics_processed',
    ]) await db.recursiveDelete(db.collection(path));

    await db.doc('games/game_legacy_test001').set(record('game_legacy_test001'));
    const first = await updateStatistics(db);
    assert.equal(first.mode, 'bootstrap');
    assert.equal(first.complete, true);
    assert.equal(first.counted, 1);
    assert.equal((await db.doc('statistics/global').get()).get('games'), 1);
    assert.equal((await updateStatistics(db)).visited, 0);

    const sameUploadTime = Timestamp.fromMillis(Date.now());
    await db.doc('games/game_new_test001').set(record(
      'game_new_test001', 'evil', sameUploadTime));
    await db.doc('games/game_new_test002').set(record(
      'game_new_test002', 'good', sameUploadTime));
    const second = await updateStatistics(db);
    assert.equal(second.mode, 'live');
    assert.equal(second.counted, 2);
    assert.equal((await updateStatistics(db)).visited, 0);

    let global = (await db.doc('statistics/global').get()).data();
    assert.equal(global.games, 3);
    assert.equal(global.goodWins, 2);
    assert.equal(global.evilWins, 1);
    assert.equal(global.totalPlayers, 6);
    assert.equal(global.totalDurationMs, 3 * 3600000);
    const roles = (await db.doc('statistics/roles').get()).data().byRole;
    assert.equal(roles.monk.appearances, 3);
    assert.equal(roles.imp.wins, 1);
    assert.equal((await db.doc('statistics_scripts/' + 'a'.repeat(64)).get())
      .get('games'), 3);

    // A crashed runner replaying an older cursor must not count again.
    await db.doc('statistics_private/progress').update({
      liveCursor: { uploadedAt: Timestamp.fromMillis(0), gameId: 'before' },
    });
    const replay = await updateStatistics(db);
    assert.equal(replay.counted, 0);
    assert.equal((await db.doc('statistics/global').get()).get('games'), 3);

    // Older Android clients still write unstamped records. A manually
    // triggered reconciliation imports these without affecting other totals.
    await db.doc('games/game_late_legacy001').set(
      record('game_late_legacy001', 'evil'));
    assert.equal((await updateStatistics(db)).counted, 0);
    assert.equal((await updateStatistics(db, { mode: 'reconcile' })).counted, 1);
    assert.equal((await updateStatistics(db, { mode: 'reconcile' })).counted, 0);
    global = (await db.doc('statistics/global').get()).data();
    assert.equal(global.games, 4);
    assert.equal(global.evilWins, 2);

    // Malformed public-shaped data cannot corrupt global totals or block
    // later records; only an internal, non-public invalid receipt is stored.
    const malformed = record('game_new_invalid01', 'good', Timestamp.now());
    malformed.players[0].actualStartRoleId = 'private.name';
    await db.doc('games/game_new_invalid01').set(malformed);
    const invalid = await updateStatistics(db);
    assert.equal(invalid.invalid, 1);
    assert.equal((await db.doc('statistics/global').get()).get('games'), 4);
    assert.equal((await db.doc('statistics_private/progress').get())
      .get('invalidGames'), 1);
    assert.equal((await db.doc('statistics_processed/game_new_invalid01').get())
      .get('status'), 'invalid_game_record');
  } finally {
    await deleteApp(app);
  }
});
