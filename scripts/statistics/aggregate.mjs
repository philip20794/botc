// Pure aggregation logic. Never send player identities, chronicle payloads,
// local names or timestamps back to public statistics documents.
const roleIdPattern = /^[a-z0-9][a-z0-9_-]{0,127}$/;
const hashPattern = /^[a-f0-9]{64}$/;
const teams = new Set(['good', 'evil']);

function assert(condition, explanation) {
  if (!condition) throw new Error(explanation);
}

export function contributionsForGame(game) {
  assert(game && typeof game === 'object', 'record is not an object');
  assert(game.schemaVersion === 1, 'unsupported game schema');
  assert(typeof game.gameId === 'string' && game.gameId.length >= 8, 'invalid game ID');
  assert(teams.has(game.winnerTeam), 'invalid winning team');
  assert(Number.isSafeInteger(game.totalDurationMs) && game.totalDurationMs > 0,
    'invalid total duration');
  assert(Array.isArray(game.players) && game.players.length === game.playerCount &&
    game.playerCount >= 1 && game.playerCount <= 20, 'invalid player count');
  assert(Array.isArray(game.phases) && game.phases.length > 0 && game.phases.length <= 512,
    'invalid phases');
  assert(Array.isArray(game.chronicleEvents) && game.chronicleEvents.length <= 4096,
    'invalid chronicle events');
  assert(game.script && typeof game.script === 'object' &&
    hashPattern.test(game.script.contentHash), 'invalid script hash');
  assert(typeof game.script.name === 'string' && game.script.name.length > 0 &&
    game.script.name.length <= 128, 'invalid script name');
  assert(typeof game.script.scriptId === 'string' && game.script.scriptId.length > 0,
    'invalid script ID');
  assert(typeof game.script.isCustom === 'boolean', 'invalid script type');
  assert(Array.isArray(game.script.roleIds), 'invalid script roles');

  const roles = Object.create(null);
  for (const player of game.players) {
    assert(player && roleIdPattern.test(player.actualStartRoleId),
      'invalid actual starting role');
    assert(teams.has(player.endTeam), 'invalid ending team');
    assert(typeof player.endRoleId === 'string', 'invalid ending role');
    const id = player.actualStartRoleId;
    if (!roles[id]) {
      roles[id] = {
        appearances: 0, wins: 0, losses: 0,
        totalDurationMs: 0, roleChanges: 0, demoAppearances: 0,
      };
    }
    roles[id].appearances++;
    if (game.demo === true) roles[id].demoAppearances++;
    roles[id][player.endTeam === game.winnerTeam ? 'wins' : 'losses']++;
    roles[id].totalDurationMs += game.totalDurationMs;
    if (player.endRoleId !== id) roles[id].roleChanges++;
  }

  const uniqueDays = new Set();
  const uniqueNights = new Set();
  let dayDurationMs = 0;
  let nightDurationMs = 0;
  for (const phase of game.phases) {
    assert(phase && ['day', 'night'].includes(phase.type) &&
      Number.isSafeInteger(phase.round) && phase.round >= 1 &&
      Number.isSafeInteger(phase.durationMs) && phase.durationMs >= 0,
    'invalid phase');
    if (phase.type === 'day') {
      uniqueDays.add(phase.round);
      dayDurationMs += phase.durationMs;
    } else {
      uniqueNights.add(phase.round);
      nightDurationMs += phase.durationMs;
    }
  }

  let deaths = 0;
  let revivals = 0;
  for (const event of game.chronicleEvents) {
    if (event?.type !== 'lifeStatusChanged') continue;
    if (event.data?.flags?.alive === false) deaths++;
    if (event.data?.flags?.alive === true) revivals++;
  }

  const summary = {
    games: 1,
    demoGames: game.demo === true ? 1 : 0,
    goodWins: game.winnerTeam === 'good' ? 1 : 0,
    evilWins: game.winnerTeam === 'evil' ? 1 : 0,
    totalDurationMs: game.totalDurationMs,
    totalPlayers: game.playerCount,
    totalDays: uniqueDays.size,
    totalNights: uniqueNights.size,
    totalDayDurationMs: dayDurationMs,
    totalNightDurationMs: nightDurationMs,
    deaths,
    revivals,
  };

  return {
    global: summary,
    roles,
    scriptHash: game.script.contentHash,
    scriptMetadata: {
      scriptId: game.script.scriptId,
      name: game.script.name,
      isCustom: game.script.isCustom,
      roleCount: game.script.roleIds.length,
    },
    scriptCounters: summary,
  };
}

export function incrementedCounters(values, increment) {
  return Object.fromEntries(
    Object.entries(values).map(([key, count]) => {
      assert(Number.isSafeInteger(count) && count >= 0,
        `invalid counter: ${key}`);
      return [key, increment(count)];
    }),
  );
}

export function compareCursors(a, b) {
  // A cursor is (server upload time, document ID); ties must never skip a game.
  const aMs = a.uploadedAt.toMillis();
  const bMs = b.uploadedAt.toMillis();
  if (aMs !== bMs) return aMs < bMs ? -1 : 1;
  // Timestamp.toMillis loses nanoseconds; Firestore timestamps support both.
  if (a.uploadedAt.seconds !== b.uploadedAt.seconds) {
    return a.uploadedAt.seconds < b.uploadedAt.seconds ? -1 : 1;
  }
  if (a.uploadedAt.nanoseconds !== b.uploadedAt.nanoseconds) {
    return a.uploadedAt.nanoseconds < b.uploadedAt.nanoseconds ? -1 : 1;
  }
  return a.gameId < b.gameId ? -1 : a.gameId > b.gameId ? 1 : 0;
}
