import test from 'node:test';
import assert from 'node:assert/strict';
import { contributionsForGame, compareCursors } from './aggregate.mjs';

function game() {
  return {
    schemaVersion: 1, gameId: 'game_test_0001', winnerTeam: 'evil',
    totalDurationMs: 100000, playerCount: 3,
    script: {
      scriptId: 'standard:test', name: 'Test Script', isCustom: false,
      contentHash: 'a'.repeat(64), roleIds: ['imp', 'monk'],
    },
    players: [
      { actualStartRoleId: 'imp', endRoleId: 'imp', endTeam: 'evil' },
      { actualStartRoleId: 'monk', endRoleId: 'imp', endTeam: 'evil' },
      { actualStartRoleId: 'monk', endRoleId: 'monk', endTeam: 'good' },
    ],
    phases: [
      { type: 'night', round: 1, durationMs: 20000 },
      { type: 'day', round: 1, durationMs: 40000 },
      { type: 'night', round: 2, durationMs: 40000 },
    ],
    chronicleEvents: [
      { type: 'lifeStatusChanged', data: { flags: { alive: false } } },
      { type: 'lifeStatusChanged', data: { flags: { alive: true } } },
    ],
  };
}

test('counts winning team and player roles after team/role changes', () => {
  const value = contributionsForGame(game());
  assert.equal(value.global.games, 1);
  assert.equal(value.global.goodWins, 0);
  assert.equal(value.global.evilWins, 1);
  assert.equal(value.global.totalDays, 1);
  assert.equal(value.global.totalNights, 2);
  assert.equal(value.global.totalNightDurationMs, 60000);
  assert.equal(value.global.deaths, 1);
  assert.equal(value.global.revivals, 1);
  assert.deepEqual({ ...value.roles.imp }, {
    appearances: 1, wins: 1, losses: 0, totalDurationMs: 100000, roleChanges: 0, demoAppearances: 0,
  });
  assert.deepEqual({ ...value.roles.monk }, {
    appearances: 2, wins: 1, losses: 1, totalDurationMs: 200000, roleChanges: 1, demoAppearances: 0,
  });
  assert.equal(value.scriptHash, 'a'.repeat(64));
  assert.equal(value.scriptMetadata.name, 'Test Script');
  assert.equal(JSON.stringify(value).includes('anonymizedPlayerId'), false);
});

test('rejects malicious or incomplete nested public records', () => {
  const malicious = game();
  malicious.players[0].actualStartRoleId = 'some.role';
  assert.throws(() => contributionsForGame(malicious), /invalid actual starting role/);
  const incomplete = game();
  delete incomplete.players[0].endTeam;
  assert.throws(() => contributionsForGame(incomplete), /invalid ending team/);
});

test('compares same-millisecond Firestore cursors by nanoseconds then game ID', () => {
  function time(nanoseconds) {
    return { seconds: 100, nanoseconds, toMillis() { return 100000; } };
  }
  const a = { uploadedAt: time(100), gameId: 'aaa' };
  const b = { uploadedAt: time(101), gameId: 'bbb' };
  assert.equal(compareCursors(a, b), -1);
  assert.equal(compareCursors(b, a), 1);
  assert.equal(compareCursors(a, { ...a, gameId: 'aab' }), -1);
  assert.equal(compareCursors(a, a), 0);
});

test('counts clearly marked demo records separately from real games', () => {
  const demo = game();
  demo.demo = true;
  const demoTotals = contributionsForGame(demo);
  assert.equal(demoTotals.global.games, 1);
  assert.equal(demoTotals.global.demoGames, 1);
  assert.equal(demoTotals.roles.monk.demoAppearances, 2);
  assert.equal(demoTotals.scriptCounters.demoGames, 1);
  const realTotals = contributionsForGame(game());
  assert.equal(realTotals.global.demoGames, 0);
  assert.equal(realTotals.roles.monk.demoAppearances, 0);
});
