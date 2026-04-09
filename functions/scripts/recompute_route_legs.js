/*
  One-time runner for recomputeAllRouteLegDistances callable.

  Usage (PowerShell):
  1) cd functions
  2) npm install firebase
  3) $env:FIREBASE_API_KEY="<web-api-key>"
  4) $env:FIREBASE_EMAIL="admin@unimas.my"
  5) $env:FIREBASE_PASSWORD="<password>"
  6) node scripts/recompute_route_legs.js --project unimas-smartbus
*/

const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFunctions, httpsCallable } = require('firebase/functions');

function parseArg(name, fallback) {
  const key = `--${name}`;
  const idx = process.argv.indexOf(key);
  if (idx !== -1 && process.argv[idx + 1]) return process.argv[idx + 1];
  return fallback;
}

async function main() {
  const projectId = parseArg('project', 'unimas-smartbus');
  const apiKey = parseArg('apiKey', process.env.FIREBASE_API_KEY || '');
  const email = parseArg('email', process.env.FIREBASE_EMAIL || '');
  const password = parseArg('password', process.env.FIREBASE_PASSWORD || '');

  if (!apiKey || !email || !password) {
    console.error(
      'Missing credentials. Provide --apiKey, --email, --password (or env vars FIREBASE_API_KEY, FIREBASE_EMAIL, FIREBASE_PASSWORD).'
    );
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
  const call = httpsCallable(functions, 'recomputeAllRouteLegDistances');
  const res = await call({});

  console.log('Callable result:', res.data);
}

main().catch((err) => {
  console.error('Route leg recompute failed:', err?.message || err);
  process.exit(1);
});
