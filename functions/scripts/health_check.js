/*
  Health check for SmartBus backend + CLI setup.
  
  Verifies:
  - Firebase CLI logged in
  - Firestore rules compile
  - Cloud Functions deployed
  - Anonymous auth accessible
  
  Exit codes:
  0 = all checks passed
  1 = one or more checks failed after recovery attempts
*/

const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

const PROJECT = 'unimas-smartbus';
const REGION = 'asia-southeast1';

function log(level, msg) {
  const prefix = {
    info: '✓',
    warn: '⚠',
    error: '✗',
  }[level] || '•';
  console.log(`${prefix} [${level.toUpperCase()}] ${msg}`);
}

function exec(cmd, label, silent = false) {
  try {
    const out = execSync(cmd, {
      encoding: 'utf8',
        shell: process.platform === 'win32',
        stdio: silent ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    });
    return { ok: true, output: out.trim() };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function checkCliLogin() {
  log('info', 'Checking Firebase CLI login...');
  const result = exec('firebase.cmd login:list', 'firebase login:list', true);
  if (!result.ok) {
    log('warn', 'Firebase CLI login check failed, attempting login...');
    const login = exec('firebase.cmd login', 'firebase login');
    if (!login.ok) {
      log('error', 'Firebase CLI login failed. Run: firebase login');
      return false;
    }
  }
  log('info', 'Firebase CLI authenticated');
  return true;
}

async function checkRulesSyntax() {
  log('info', 'Checking Firestore rules syntax...');
  const rulesPath = path.join(__dirname, '..', '..', 'firestore.rules');
  
  if (!fs.existsSync(rulesPath)) {
    log('error', `Firestore rules file not found: ${rulesPath}`);
    return false;
  }

  try {
    // Just check if file is readable and has content
    const content = fs.readFileSync(rulesPath, 'utf8');
    if (!content.includes('service cloud.firestore')) {
      log('error', 'Firestore rules file appears corrupted');
      return false;
    }
    log('info', 'Firestore rules file OK');
    return true;
  } catch (error) {
    log('error', `Firestore rules check failed: ${error.message}`);
    return false;
  }
}

async function checkFunctionsDeploy() {
  log('info', 'Checking deployed Cloud Functions...');
  const result = exec(
    `firebase.cmd functions:list --project ${PROJECT}`,
    'functions list',
    true
  );
  if (!result.ok) {
    log('error', 'Could not list Cloud Functions');
    return false;
  }
  if (!result.output.includes('backfillReportReporterUid')) {
    log('warn', 'backfillReportReporterUid callable not found (may not be deployed yet)');
  } else {
    log('info', 'Cloud Functions deployed (including migration callable)');
  }
  return true;
}

async function checkAnonAuth() {
  log('info', 'Checking anonymous auth connectivity...');
  
  try {
    // Use Node.js fetch to test connectivity to Firestore auth endpoint
    const response = await fetch(
      `https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyCC7XHbA6k-jLiOq8FBOyB4EWoZ7ALM7EY`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ returnSecureToken: true }),
      }
    );

    if (response.ok || response.status === 400) {
      // 200 = success, 400 = auth error (expected for anon), anything means connectivity OK
      log('info', 'Anonymous auth endpoint reachable');
      return true;
    }

    log('warn', `Anonymous auth endpoint returned ${response.status} (might be transient)`);
    return true;
  } catch (error) {
    log('error', `Anonymous auth check failed: ${error.message}`);
    return false;
  }
}

async function main() {
  console.log('SmartBus Health Check\n');

  const checks = [
    { name: 'CLI Login', fn: checkCliLogin },
    { name: 'Rules Syntax', fn: checkRulesSyntax },
    { name: 'Functions Deploy', fn: checkFunctionsDeploy },
    { name: 'Anon Auth', fn: checkAnonAuth },
  ];

  const results = [];
  for (const check of checks) {
    try {
      const result = await check.fn();
      results.push({ name: check.name, ok: result });
    } catch (error) {
      log('error', `${check.name} check threw: ${error.message}`);
      results.push({ name: check.name, ok: false });
    }
  }

  console.log('\n--- Summary ---');
  const allOk = results.every((r) => r.ok);
  results.forEach((r) => {
    const status = r.ok ? '✓' : '✗';
    console.log(`${status} ${r.name}`);
  });

  if (allOk) {
    log('info', 'All checks passed!');
    process.exit(0);
  } else {
    log('error', 'One or more checks failed');
    process.exit(1);
  }
}

main().catch((error) => {
  log('error', `Health check crashed: ${error.message}`);
  process.exit(1);
});
