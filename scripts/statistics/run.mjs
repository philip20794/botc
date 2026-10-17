import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { updateStatistics } from './worker.mjs';

const projectId = process.env.GOOGLE_CLOUD_PROJECT ?? 'b-o-t-c';
const mode = process.argv[2] ?? 'incremental';
const maxGames = Number.parseInt(process.env.STATS_MAX_GAMES ?? '200', 10);

if (!process.env.FIRESTORE_EMULATOR_HOST && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error('Google application credentials are required outside the emulator');
}

initializeApp({
  projectId,
  ...(process.env.FIRESTORE_EMULATOR_HOST ? {} : { credential: applicationDefault() }),
});
const result = await updateStatistics(getFirestore(), { mode, maxGames });
console.log(JSON.stringify(result));
// A partial bootstrap or catch-up is expected when more than 200 games are
// queued; the next scheduled run continues at the durable checkpoint.
