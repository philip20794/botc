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

console.log('Firestore rules emulator checks passed.');
