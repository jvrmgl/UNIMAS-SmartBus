/*
  Backfill legacy reports.reporterUid using Firebase CLI login (no email/password auth).

  Requirements:
  - You are logged into Firebase CLI: firebase login

  Usage (PowerShell):
  1) cd functions
  2) node scripts/backfill_reporter_uid_cli.js --project unimas-smartbus --dryRun true --limit 200
  3) node scripts/backfill_reporter_uid_cli.js --project unimas-smartbus --dryRun false --limit 200

  Optional:
  - --pageToken <token>   Resume from a specific Firestore REST page token.
*/

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

function parseArg(name, fallback) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1 || idx + 1 >= process.argv.length) return fallback;
  return process.argv[idx + 1];
}

function toBool(v, fallback = false) {
  if (v === undefined || v === null) return fallback;
  return String(v).toLowerCase() === 'true';
}

function getFirebaseCliCommand() {
  if (process.platform === 'win32') {
    const candidates = [
      process.env.FIREBASE_CMD,
      process.env.APPDATA ? `${process.env.APPDATA}\\npm\\firebase.cmd` : null,
      'firebase.cmd',
    ].filter(Boolean);

    for (const candidate of candidates) {
      if (candidate.includes('\\')) {
        if (fs.existsSync(candidate)) {
          return candidate;
        }
        continue;
      }
      return candidate;
    }

    return 'firebase.cmd';
  }

  return 'firebase';
}

function readAccessTokenFromConfigStore() {
  const candidatePaths = [
    process.env.FIREBASE_TOOLS_CONFIG,
    process.env.APPDATA ? path.join(process.env.APPDATA, 'configstore', 'firebase-tools.json') : null,
    process.env.USERPROFILE ? path.join(process.env.USERPROFILE, '.config', 'configstore', 'firebase-tools.json') : null,
  ].filter(Boolean);

  for (const p of candidatePaths) {
    if (!fs.existsSync(p)) continue;

    try {
      const raw = fs.readFileSync(p, 'utf8');
      const data = JSON.parse(raw);
      const token = data?.tokens?.access_token;
      const expiresAt = Number(data?.tokens?.expires_at || 0);

      if (!token || typeof token !== 'string') {
        continue;
      }

      if (expiresAt && expiresAt <= Date.now() + 60_000) {
        throw new Error('Stored Firebase CLI access token is expired. Run firebase login --reauth and retry.');
      }

      return token;
    } catch (error) {
      if (String(error.message).includes('expired')) {
        throw error;
      }
      // Try next path.
    }
  }

  throw new Error('Could not find a valid Firebase CLI access token in local config store.');
}

function getAccessToken() {
  const cmd = getFirebaseCliCommand();

  try {
    let token = '';

    try {
      if (process.platform === 'win32') {
        // Execute firebase.cmd via shell=true for reliable .cmd invocation.
        token = execFileSync(cmd, ['login:print-access-token'], {
          encoding: 'utf8',
          stdio: ['ignore', 'pipe', 'pipe'],
          shell: true,
        }).trim();
      } else {
        token = execFileSync(cmd, ['login:print-access-token'], {
          encoding: 'utf8',
          stdio: ['ignore', 'pipe', 'pipe'],
        }).trim();
      }
    } catch (_) {
      // Some CLI versions do not support login:print-access-token.
      token = '';
    }

    if (!token) {
      token = readAccessTokenFromConfigStore();
    }

    if (!token) {
      throw new Error('Empty access token received from Firebase CLI.');
    }

    return token;
  } catch (error) {
    const stderr = error?.stderr ? String(error.stderr).trim() : '';
    const detail = stderr ? `${error.message} | ${stderr}` : error.message;

    throw new Error(
      `Unable to get Firebase CLI access token. Ensure you ran "${cmd} login". Details: ${detail}`
    );
  }
}

async function requestJson(url, options = {}, retries = 3) {
  let attempt = 0;
  while (true) {
    attempt += 1;
    const res = await fetch(url, options);

    if (res.ok) {
      return await res.json();
    }

    const text = await res.text();
    const retryable = res.status === 429 || res.status >= 500;

    if (retryable && attempt <= retries) {
      await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
      continue;
    }

    throw new Error(`HTTP ${res.status} ${res.statusText}: ${text}`);
  }
}

function readString(fields, key) {
  return fields?.[key]?.stringValue || null;
}

function docIdFromName(name) {
  const parts = String(name || '').split('/');
  return parts[parts.length - 1] || null;
}

async function fetchDeviceMappedUid(baseUrl, token, deviceId, cache) {
  if (cache.has(deviceId)) {
    return cache.get(deviceId);
  }

  const encoded = encodeURIComponent(deviceId);
  const url = `${baseUrl}/device_tokens/${encoded}`;

  try {
    const doc = await requestJson(url, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    const mappedUid = readString(doc.fields, 'userId');
    cache.set(deviceId, mappedUid);
    return mappedUid;
  } catch (error) {
    // Treat missing mapping documents as null mapping.
    if (String(error.message).includes('HTTP 404')) {
      cache.set(deviceId, null);
      return null;
    }
    throw error;
  }
}

async function patchReporterUid(token, docName, reporterUid) {
  const url = `https://firestore.googleapis.com/v1/${docName}?updateMask.fieldPaths=reporterUid`;
  await requestJson(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      fields: {
        reporterUid: {
          stringValue: reporterUid,
        },
      },
    }),
  });
}

async function processPage({ baseUrl, token, limit, pageToken, dryRun, deviceMapCache }) {
  const q = new URLSearchParams({ pageSize: String(limit) });
  if (pageToken) q.set('pageToken', pageToken);

  const listUrl = `${baseUrl}/reports?${q.toString()}`;
  const data = await requestJson(listUrl, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const docs = Array.isArray(data.documents) ? data.documents : [];

  const stats = {
    processed: 0,
    updated: 0,
    skippedNoDeviceId: 0,
    skippedNoMapping: 0,
    skippedAlreadyOwned: 0,
  };

  for (const doc of docs) {
    stats.processed += 1;

    const reporterUid = readString(doc.fields, 'reporterUid');
    if (reporterUid) {
      stats.skippedAlreadyOwned += 1;
      continue;
    }

    const deviceId = readString(doc.fields, 'deviceId') || readString(doc.fields, 'studentId');
    if (!deviceId) {
      stats.skippedNoDeviceId += 1;
      continue;
    }

    const mappedUid = await fetchDeviceMappedUid(baseUrl, token, deviceId, deviceMapCache);
    if (!mappedUid) {
      stats.skippedNoMapping += 1;
      continue;
    }

    if (!dryRun) {
      await patchReporterUid(token, doc.name, mappedUid);
    }
    stats.updated += 1;
  }

  return {
    stats,
    nextPageToken: data.nextPageToken || null,
    done: !data.nextPageToken,
  };
}

async function main() {
  const projectId = parseArg('project', 'unimas-smartbus');
  const dryRun = toBool(parseArg('dryRun', 'true'), true);
  const limit = Math.min(Math.max(Number(parseArg('limit', '200')), 1), 1000);
  let pageToken = parseArg('pageToken', null);

  const token = getAccessToken();
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const deviceMapCache = new Map();

  let page = 0;
  const totals = {
    processed: 0,
    updated: 0,
    skippedNoDeviceId: 0,
    skippedNoMapping: 0,
    skippedAlreadyOwned: 0,
  };

  while (true) {
    page += 1;

    const result = await processPage({
      baseUrl,
      token,
      limit,
      pageToken,
      dryRun,
      deviceMapCache,
    });

    totals.processed += result.stats.processed;
    totals.updated += result.stats.updated;
    totals.skippedNoDeviceId += result.stats.skippedNoDeviceId;
    totals.skippedNoMapping += result.stats.skippedNoMapping;
    totals.skippedAlreadyOwned += result.stats.skippedAlreadyOwned;

    console.log(
      `page=${page} processed=${result.stats.processed} updated=${result.stats.updated} noDevice=${result.stats.skippedNoDeviceId} noMapping=${result.stats.skippedNoMapping} owned=${result.stats.skippedAlreadyOwned} dryRun=${dryRun}`
    );

    if (result.done) {
      console.log('Migration complete:', totals);
      break;
    }

    pageToken = result.nextPageToken;
    console.log(`nextPageToken=${pageToken}`);
  }
}

main().catch((error) => {
  console.error('Migration failed:', error.message || error);
  process.exit(1);
});
