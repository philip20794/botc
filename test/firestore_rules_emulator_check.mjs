// Run with:
// npx --yes firebase-tools@latest emulators:exec --only firestore --project b-o-t-c "node test/firestore_rules_emulator_check.mjs"
//
// This uses the Emulator REST API only, so no Firebase account, credentials or
// extra JavaScript dependencies are needed to test public Firestore rules.

const projectId = process.env.GCLOUD_PROJECT ?? 'b-o-t-c';
const baseUrl =
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;

const field = (value) => {
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: `${value}` };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(field) } };
  return {
    mapValue: {
      fields: Object.fromEntries(
        Object.entries(value).map(([key, nestedValue]) => [key, field(nestedValue)]),
      ),
    },
  };
};

const documentBody = (data) => ({
  fields: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, field(value)])),
});

const expectStatus = async (response, expected, label) => {
  if (response.status !== expected) {
    throw new Error(`${label}: expected HTTP ${expected}, got ${response.status}: ${await response.text()}`);
  }
};

const gameId = `game_rules_${Date.now()}`;
const validRecord = {
  schemaVersion: 1,
  gameId,
  startedAt: '2026-10-13T20:00:00.000Z',
  endedAt: '2026-10-13T20:10:00.000Z',
  totalDurationMs: 600000,
  playerCount: 1,
  winnerTeam: 'good',
  script: {
    scriptId: 'script_0123456789',
    name: 'Test script',
    isCustom: false,
    roleIds: ['monk'],
    contentHash: '0'.repeat(64),
  },
  players: [
    {
      anonymizedPlayerId: 'player_0123456789',
      position: 0,
      actualStartRoleId: 'monk',
      displayedStartRoleId: 'monk',
      startTeam: 'good',
      endRoleId: 'monk',
      endTeam: 'good',
    },
  ],
  phases: [{}],
  chronicleEvents: [],
};

const post = (id, data) =>
  fetch(`${baseUrl}/games?documentId=${encodeURIComponent(id)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(documentBody(data)),
  });

const incomplete = { ...validRecord };
delete incomplete.winnerTeam;
await expectStatus(await post(`${gameId}_incomplete`, incomplete), 403, 'missing required field');

const missingPlayerField = structuredClone(validRecord);
delete missingPlayerField.players[0].endTeam;
missingPlayerField.gameId = `${gameId}_player`;
await expectStatus(await post(missingPlayerField.gameId, missingPlayerField), 403, 'incomplete player');


// Reproduce the *actual production transport*: Flutter Web sends a Firestore
// commit with a create precondition, and real games contain >1 player.
const fivePlayerRecord = structuredClone(validRecord);
fivePlayerRecord.gameId = `${gameId}_five_players`;
fivePlayerRecord.playerCount = 5;
fivePlayerRecord.script.scriptId = 'standard:trouble_brewing';
fivePlayerRecord.script.name = 'Trouble Brewing';
fivePlayerRecord.script.roleIds = [
  'washerwoman', 'librarian', 'investigator', 'chef', 'empath',
  'fortuneteller', 'mayor', 'monk', 'ravenkeeper', 'slayer',
  'soldier', 'undertaker', 'virgin', 'butler', 'drunk',
  'recluse', 'saint', 'baron', 'poisoner', 'scarletwoman',
  'spy', 'imp', 'scapegoat', 'gunslinger', 'beggar', 'bureaucrat', 'thief',
];
fivePlayerRecord.players = [
  ['imp', 'evil'], ['scarletwoman', 'evil'], ['soldier', 'good'],
  ['slayer', 'good'], ['washerwoman', 'good'],
].map(([roleId, team], index) => ({
  anonymizedPlayerId: `player_test_${index}_abcdefgh`,
  position: index,
  actualStartRoleId: roleId,
  displayedStartRoleId: roleId,
  startTeam: team,
  endRoleId: index === 1 ? 'imp' : roleId,
  endTeam: team,
}));
fivePlayerRecord.phases = [
  { phaseId: 'phase_aabbccdd0', type: 'night', round: 1,
    startedAt: '2026-10-13T20:00:00.000', endedAt: '2026-10-13T20:01:00.000', durationMs: 60000 },
  { phaseId: 'phase_aabbccdd1', type: 'day', round: 1,
    startedAt: '2026-10-13T20:01:00.000', endedAt: '2026-10-13T20:03:00.000', durationMs: 120000 },
  { phaseId: 'phase_aabbccdd2', type: 'night', round: 2,
    startedAt: '2026-10-13T20:03:00.000', endedAt: '2026-10-13T20:04:00.000', durationMs: 60000 },
  { phaseId: 'phase_aabbccdd3', type: 'day', round: 2,
    startedAt: '2026-10-13T20:04:00.000', endedAt: '2026-10-13T20:10:00.000', durationMs: 360000 },
];
fivePlayerRecord.chronicleEvents = Array.from({ length: 16 }, (_, i) => ({
  eventId: `event_test_${i}`,
  occurredAt: '2026-10-13T20:04:00.000',
  type: i % 2 ? 'lifeStatusChanged' : 'nightActionVisited',
  phase: i % 2 ? 'day' : 'night',
  round: 2,
  actorPlayerId: fivePlayerRecord.players[i % 5].anonymizedPlayerId,
  targetPlayerIds: [],
  data: {
    roleIds: { actorRoles: [fivePlayerRecord.players[i % 5].endRoleId] },
    flags: { alive: false },
  },
}));
const commitUrl =
  `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents:commit`;
const productionWrite = (record) => fetch(commitUrl, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    writes: [{
      update: {
        name: `projects/${projectId}/databases/(default)/documents/games/${record.gameId}`,
        ...documentBody(record),
      },
      currentDocument: { exists: false },
    }],
  }),
});
// The production Flutter writer does more than a bare commit: it begins a
// read-write transaction and reads the missing document before creating it.
// Exercise that complete sequence so the emulator cannot miss permission
// checks triggered by transaction reads or its transaction token.
const fullTransactionWrite = async (record) => {
  const documentName =
    `projects/${projectId}/databases/(default)/documents/games/${record.gameId}`;
  const begin = await fetch(`${baseUrl}:beginTransaction`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ options: { readWrite: {} } }),
  });
  await expectStatus(begin, 200, 'begin Firestore transaction');
  const { transaction } = await begin.json();
  const read = await fetch(`${baseUrl}:batchGet`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ documents: [documentName], transaction }),
  });
  await expectStatus(read, 200, 'transactional read of missing game');
  const readBody = await read.text();
  if (!readBody.includes('missing')) {
    throw new Error(`Expected missing document before create: ${readBody}`);
  }
  return fetch(commitUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      transaction,
      writes: [{
        update: { name: documentName, ...documentBody(record) },
        currentDocument: { exists: false },
      }],
    }),
  });
};
const transactionalRecord = structuredClone(fivePlayerRecord);
transactionalRecord.gameId += '_transaction';
await expectStatus(await fullTransactionWrite(transactionalRecord), 200,
  'full 5-player transaction read and create');

const invalidProductionWrite = structuredClone(fivePlayerRecord);
invalidProductionWrite.gameId += '_invalid';
delete invalidProductionWrite.players[0].endTeam;
await expectStatus(await productionWrite(invalidProductionWrite), 403,
  'transaction create must reject missing player endTeam');
await expectStatus(await productionWrite(fivePlayerRecord), 200,
  'production-like 5-player game transaction create');

// Rule evaluation is not necessarily linear in the player count. In
// particular, the 20-seat validation contains many nested expressions;
// verify every representative real-game size, not just five players.
for (const playerCount of [6, 10, 15, 20]) {
  const record = structuredClone(fivePlayerRecord);
  record.gameId = `${gameId}_${playerCount}_players`;
  record.playerCount = playerCount;
  record.players = Array.from({ length: playerCount }, (_, index) => {
    const [roleId, team] = index === 0 ? ['imp', 'evil'] : ['monk', 'good'];
    return {
      anonymizedPlayerId: `player_test_${index}_abcdefgh`,
      position: index,
      actualStartRoleId: roleId,
      displayedStartRoleId: roleId,
      startTeam: team,
      endRoleId: roleId,
      endTeam: team,
    };
  });
  record.chronicleEvents = [];
  await expectStatus(await productionWrite(record), 200,
    `production-like ${playerCount}-player transaction create`);
}

// Keep negative coverage at the last seat; optimizing the rules must not
// silently make player 19 unvalidated in a 20-seat game.
const lastSeatRecord = structuredClone(fivePlayerRecord);
lastSeatRecord.gameId = `${gameId}_last_seat_invalid`;
lastSeatRecord.playerCount = 20;
lastSeatRecord.players = Array.from({ length: 20 }, (_, i) => ({
  ...fivePlayerRecord.players[0],
  anonymizedPlayerId: `player_test_${i}_abcdefgh`,
  position: i,
}));
lastSeatRecord.players[19].playerName = 'not allowed in public statistics';
await expectStatus(await productionWrite(lastSeatRecord), 403,
  'twentieth player must not include an extra field');

const extraGameField = structuredClone(validRecord);
extraGameField.gameId += '_extra_game';
extraGameField.privateNotes = 'must not be uploaded';
await expectStatus(await post(extraGameField.gameId, extraGameField), 403,
  'top-level fields outside the public schema must be rejected');

const extraScriptField = structuredClone(validRecord);
extraScriptField.gameId += '_extra_script';
extraScriptField.script.privateDetails = 'must not be uploaded';
await expectStatus(await post(extraScriptField.gameId, extraScriptField), 403,
  'script fields outside the public schema must be rejected');

await expectStatus(await post(gameId, validRecord), 200, 'valid create');
await expectStatus(await fetch(`${baseUrl}/games/${gameId}`), 200, 'public read');
await expectStatus(
  await fetch(`${baseUrl}/games/${gameId}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(documentBody({ winnerTeam: 'evil' })),
  }),
  403,
  'update denied',
);
await expectStatus(
  await fetch(`${baseUrl}/games/${gameId}`, { method: 'DELETE' }),
  403,
  'delete denied',
);

// New versions attach uploadedAt using a SERVER transform. The time cannot
// be chosen by the client: it is trusted as the incremental index cursor.
for (const playerCount of [5, 20]) {
  const timestampedRecord = structuredClone(fivePlayerRecord);
  timestampedRecord.gameId = `${gameId}_stamp_${playerCount}`;
  timestampedRecord.playerCount = playerCount;
  timestampedRecord.players = Array.from({ length: playerCount }, (_, i) => ({
    ...fivePlayerRecord.players[0],
    anonymizedPlayerId: `player_stamp_${i}_abcdefgh`,
    position: i,
  }));
  const docName =
    `projects/${projectId}/databases/(default)/documents/games/${timestampedRecord.gameId}`;
  await expectStatus(await fetch(commitUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      writes: [{
        update: { name: docName, ...documentBody(timestampedRecord) },
        updateTransforms: [{
          fieldPath: 'uploadedAt', setToServerValue: 'REQUEST_TIME',
        }],
        currentDocument: { exists: false },
      }],
    }),
  }), 200, `server-timestamped ${playerCount}-player create`);
}

const forgedTimestamp = structuredClone(validRecord);
forgedTimestamp.gameId += '_forged_stamp';
const forgedDocument = documentBody(forgedTimestamp);
forgedDocument.fields.uploadedAt = {
  timestampValue: '2020-01-01T00:00:00Z',
};
await expectStatus(await fetch(`${baseUrl}/games?documentId=${forgedTimestamp.gameId}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(forgedDocument),
}), 403, 'client-supplied fake timestamp denied');

await expectStatus(await fetch(`${baseUrl}/statistics/global`),
  404, 'global statistic is publicly readable but not yet created');
await expectStatus(await fetch(`${baseUrl}/statistics?documentId=global`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(documentBody({ games: 1000 })),
  }), 403, 'client cannot forge global statistics');
await expectStatus(await fetch(`${baseUrl}/statistics_private/progress`), 403,
  'aggregation checkpoint remains private');
await expectStatus(await fetch(`${baseUrl}/statistics_processed/test_game`), 403,
  'processed-game receipts remain private');

console.log('Firestore rules emulator checks passed.');
