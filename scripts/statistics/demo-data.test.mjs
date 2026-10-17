import test from 'node:test';
import assert from 'node:assert/strict';
import { demoGame, DEMO_PREFIX, DEMO_SET, DEMO_SCRIPTS, MAX_DEMO_GAMES } from './demo-data.mjs';
import { contributionsForGame } from './aggregate.mjs';

test('all 120 simulated games are deterministic, varied and valid for aggregation', () => {
  const ids = new Set();
  const usedScripts = new Set();
  const winners = new Set();
  const sizes = new Set();
  const roles = new Set();
  for (let index=1;index<=MAX_DEMO_GAMES;index++) {
    const game = demoGame(index);
    assert.deepEqual(game, demoGame(index));
    assert.equal(game.demo, true);
    assert.equal(game.demoSet, DEMO_SET);
    assert.ok(game.gameId.startsWith(DEMO_PREFIX));
    assert.ok(!ids.has(game.gameId));
    ids.add(game.gameId);
    usedScripts.add(game.script.scriptId);
    winners.add(game.winnerTeam);
    sizes.add(game.playerCount);
    for (const player of game.players) {
      roles.add(player.actualStartRoleId);
      assert.ok(game.script.roleIds.includes(player.actualStartRoleId));
      assert.equal(player.position, game.players.indexOf(player));
    }
    const result = contributionsForGame(game);
    assert.equal(result.global.demoGames, 1);
    assert.equal(result.global.games, 1);
    assert.equal(result.global.totalDurationMs, game.totalDurationMs);
    assert.equal(result.global.totalPlayers, game.playerCount);
    assert.ok(game.phases.length >= 3);
    assert.ok(game.chronicleEvents.length > 0);
    assert.equal(new Date(game.endedAt) - new Date(game.startedAt), game.totalDurationMs);
    assert.equal(game.phases.reduce((sum, p) => sum+p.durationMs,0), game.totalDurationMs);
  }
  assert.equal(ids.size, MAX_DEMO_GAMES);
  assert.equal(usedScripts.size, 4);
  assert.deepEqual([...winners].sort(), ['evil', 'good']);
  assert.ok(sizes.size >= 8);
  assert.ok(roles.size >= 30);
});
test('canonical standard scripts preserve role ordering and stable content hashes', () => {
  for (const script of DEMO_SCRIPTS) {
    assert.equal(script.roleIds.length, new Set(script.roleIds).size);
    assert.match(script.contentHash, /^[a-f0-9]{64}$/);
  }
});
test('rejects out-of-bounds requests to generate demo records', () => {
  assert.throws(() => demoGame(0), RangeError);
  assert.throws(() => demoGame(121), RangeError);
  assert.throws(() => demoGame(1.25), RangeError);
});
