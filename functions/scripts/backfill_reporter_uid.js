/*
  One-time migration runner for backfillReportReporterUid callable.
  Usage (PowerShell):
  1) cd functions
  2) npm install firebase
  3) $env:FIREBASE_EMAIL="admin@email.com"
  4) $env:FIREBASE_PASSWORD="your-password"
  5) node scripts/backfill_reporter_uid.js --project unimas-smartbus --dryRun true --limit 200
     node scripts/backfill_reporter_uid.js --project unimas-smartbus --dryRun false --limit 200
*/

const { initializeApp } = require('firebase/app');
const {
  getAuth,
  signInWithEmailAndPassword,
} = require('firebase/auth');
const { getFunctions, httpsCallable } = require('firebase/functions');

function parseArg(name, fallback) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= process.argv.length) return fallback;
  return process.argv[idx + 1];
}

function toBool(v, fallback = false) {
  if (v === undefined || v === null) return fallback;
  return String(v).toLowerCase() === 'true';
}

async function main() {
  const projectId = parseArg('project', 'unimas-smartbus');
  const apiKey = parseArg('apiKey', process.env.FIREBASE_API_KEY || '');
  const email = parseArg('email', process.env.FIREBASE_EMAIL || '');
  const password = parseArg('password', process.env.FIREBASE_PASSWORD || '');
  const dryRun = toBool(parseArg('dryRun', 'true'), true);
  const limit = Number(parseArg('limit', '200'));

  if (!apiKey || !email || !password) {
    console.error('Missing required credentials. Provide --apiKey, --email, --password (or env vars FIREBASE_API_KEY, FIREBASE_EMAIL, FIREBASE_PASSWORD).');
    process.exit(1);
  }

  const app = initializeApp({
    apiKey,
    authDomain: `${projectId}.firebaseapp.com`,
    projectId,
  });

  const auth = getAuth(app);
  await signInWithEmailAndPassword(auth, email, password);

  const functions = getFunctions(app, 'asia-southeast1');
  const call = httpsCallable(functions, 'backfillReportReporterUid');

  let cursor = null;
  let page = 0;
  let totals = {
    processed: 0,
    updated: 0,
    skippedNoDeviceId: 0,
    skippedNoMapping: 0,
    skippedAlreadyOwned: 0,
  };

  while (true) {
    page += 1;
    const res = await call({ limit, dryRun, cursor });
    const d = res.data || {};

    totals.processed += d.processed || 0;
    totals.updated += d.updated || 0;
    totals.skippedNoDeviceId += d.skippedNoDeviceId || 0;
    totals.skippedNoMapping += d.skippedNoMapping || 0;
    totals.skippedAlreadyOwned += d.skippedAlreadyOwned || 0;

    console.log(`page=${page} processed=${d.processed} updated=${d.updated} noDevice=${d.skippedNoDeviceId} noMapping=${d.skippedNoMapping} owned=${d.skippedAlreadyOwned} dryRun=${d.dryRun}`);

    if (d.done || !d.nextCursor) break;
    cursor = d.nextCursor;
  }

  console.log('Migration complete:', totals);
}

main().catch((err) => {
  console.error('Migration failed:', err?.message || err);
  process.exit(1);
});
