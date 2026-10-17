// Create *only* deterministic, clearly marked synthetic games.
// Never alters, deletes or overwrites existing game records.
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { demoGame, MAX_DEMO_GAMES, DEMO_SET } from './demo-data.mjs';

const PROJECT = 'b-o-t-c';
const confirmation = process.argv[2];
const isApply = process.argv.includes('--apply');
const projectId = process.env.GOOGLE_CLOUD_PROJECT ?? '';

if (projectId !== PROJECT) {
  throw new Error('Refusing to seed: GOOGLE_CLOUD_PROJECT must be b-o-t-c');
}
if (!isApply) {
  console.log(JSON.stringify({
    dryRun: true, projectId, demoSet: DEMO_SET,
    games: MAX_DEMO_GAMES,
    examples: [demoGame(1), demoGame(MAX_DEMO_GAMES)].map(
      ({ gameId, playerCount, winnerTeam, script }) =>
        ({ gameId, playerCount, winnerTeam, script: script.name })),
    hint: 'Use --apply and the workflow confirmation to insert demo records.',
  }, null, 2));
  process.exit(0);
}
if (confirmation !== 'SEED_120_DEMO_GAMES') {
  throw new Error('Explicit confirmation SEED_120_DEMO_GAMES required');
}
if (!process.env.FIRESTORE_EMULATOR_HOST &&
    !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error('Service-account credentials required outside emulator');
}

initializeApp({
  projectId,
  ...(process.env.FIRESTORE_EMULATOR_HOST
    ? {} : { credential: applicationDefault() }),
});
const database = getFirestore();
const games = Array.from({ length: MAX_DEMO_GAMES }, (_, i) => demoGame(i+1));
const references = games.map(({ gameId }) => database.doc('games/' + gameId));
const existing = await database.getAll(...references);
const pending = [];
for (let i=0; i<games.length; i++) {
  if (!existing[i].exists) {
    pending.push([references[i], games[i]]);
    continue;
  }
  const previous = existing[i].data();
  if (previous.demo !== true || previous.demoSet !== DEMO_SET) {
    throw new Error('Refusing to overwrite unrelated existing game ' + games[i].gameId);
  }
}

// Firestore create preconditions also protect against changes after preflight.
// Committing small batches means a partially interrupted seed can be rerun.
for (let i=0; i<pending.length; i+=20) {
  const batch = database.batch();
  for (const [reference, game] of pending.slice(i,i+20)) {
    batch.create(reference, {
      ...game,
      uploadedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log('Created demo games:', Math.min(i+20,pending.length),
    'of', pending.length);
}
console.log(JSON.stringify({
  projectId, demoSet: DEMO_SET, expectedTotal: MAX_DEMO_GAMES,
  created: pending.length, previouslySeeded: games.length - pending.length,
}));
