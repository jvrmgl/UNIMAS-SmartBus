const admin = require('firebase-admin');
const functions = require('firebase-functions/v1');

if (!admin.apps.length) {
  admin.initializeApp();
}

// ── Per-instance in-memory rate limiter ───────────────────────────────────────
// Prevents abuse of callable functions. Resets per window per UID.
// Per-instance only — sufficient for a campus-scale app.
const _rateLimitMap = new Map();
function enforceRateLimit(uid, { maxCalls = 10, windowMs = 60_000 } = {}) {
  const now = Date.now();
  const entry = _rateLimitMap.get(uid) ?? { count: 0, windowStart: now };
  if (now - entry.windowStart > windowMs) {
    entry.count = 1;
    entry.windowStart = now;
  } else {
    entry.count += 1;
  }
  _rateLimitMap.set(uid, entry);
  if (entry.count > maxCalls) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many requests. Please try again later.'
    );
  }
}

exports.deleteAuthUserByUid = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required.'
      );
    }
    // Rate limit: max 5 calls per minute per admin UID
    enforceRateLimit(context.auth.uid, { maxCalls: 5, windowMs: 60_000 });

    const requesterDoc = await admin
      .firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!requesterDoc.exists || requesterDoc.data()?.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can delete auth users.'
      );
    }

    const uid = data?.uid;
    if (!uid || typeof uid !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A valid uid is required.'
      );
    }

    if (uid === context.auth.uid) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Admin cannot delete their own auth account from this action.'
      );
    }

    await admin.auth().deleteUser(uid);
    return { success: true };
  });

// Send push notification when a new announcement is created
exports.sendAnnouncementNotification = functions
  .region('asia-southeast1')
  .firestore.document('announcements/{announcementId}')
  .onCreate(async (snap, context) => {
    const announcement = snap.data();

    try {
      // Use FCM v1 API with proper Android config
      const message = {
        notification: {
          title: announcement.title || 'New Announcement',
          body: announcement.description || 'Tap to view details',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'announcements',
          },
        },
        data: {
          type: 'announcement',
          announcementId: context.params.announcementId,
          announcementType: announcement.type || 'service',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        topic: 'announcements',
      };
      
      const response = await admin.messaging().send(message);
      console.log('Successfully sent announcement notification:', response);
      return { success: true, messageId: response };
    } catch (error) {
      console.error('Error sending announcement notification:', error);
      console.error('Error details:', error.code, error.message);
      throw new functions.https.HttpsError('internal', 'Failed to send notification: ' + error.message);
    }
  });

// Manually trigger push notification (for resend feature)
exports.resendAnnouncementNotification = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required.'
      );
    }
    // Rate limit: max 10 calls per minute per admin UID
    enforceRateLimit(context.auth.uid, { maxCalls: 10, windowMs: 60_000 });

    // Verify admin role
    const requesterDoc = await admin
      .firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!requesterDoc.exists || requesterDoc.data()?.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can resend notifications.'
      );
    }

    const announcementId = data?.announcementId;
    if (!announcementId || typeof announcementId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A valid announcementId is required.'
      );
    }

    // Fetch the announcement
    const announcementDoc = await admin
      .firestore()
      .collection('announcements')
      .doc(announcementId)
      .get();

    if (!announcementDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Announcement not found.'
      );
    }

    const announcement = announcementDoc.data();

    try {
      // Use FCM v1 API with proper Android config
      const message = {
        notification: {
          title: announcement.title || 'Announcement Reminder',
          body: announcement.description || 'Tap to view details',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'announcements',
          },
        },
        data: {
          type: 'announcement',
          announcementId: announcementId,
          announcementType: announcement.type || 'service',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        topic: 'announcements',
      };
      
      const response = await admin.messaging().send(message);
      console.log('Successfully resent announcement notification:', response);
      return { success: true, messageId: response };
    } catch (error) {
      console.error('Error resending announcement notification:', error);
      console.error('Error details:', error.code, error.message);
      throw new functions.https.HttpsError('internal', 'Failed to resend notification: ' + error.message);
    }
  });

// ─────────────────────────────────────────────────────────────────────────────
// SMART NOTIFICATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/** Haversine distance in kilometres between two lat/lon points. */
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const toRad = (v) => (v * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Send an FCM message to a single device token. Returns true on success. */
async function sendToToken(fcmToken, title, body, data = {}) {
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: { channelId: 'bus_updates', sound: 'default' },
      },
      data: { click_action: 'FLUTTER_NOTIFICATION_CLICK', ...data },
    });
    return true;
  } catch (err) {
    console.error('sendToToken error:', err.message);
    return false;
  }
}

/** Read notification template from Firestore; returns defaults on failure. */
async function getTemplate(type, defaultTitle, defaultBody) {
  try {
    const doc = await admin.firestore()
      .collection('notification_templates')
      .doc(type)
      .get();
    if (doc.exists) {
      const d = doc.data();
      return { title: d.title || defaultTitle, body: d.body || defaultBody };
    }
  } catch (e) {
    console.warn('getTemplate error:', e.message);
  }
  return { title: defaultTitle, body: defaultBody };
}

/** Replace {key} placeholders in a template string with values from vars. */
function fillTemplate(template, vars) {
  return template.replace(/\{(\w+)\}/g, (_, key) =>
    vars[key] !== undefined ? String(vars[key]) : `{${key}}`
  );
}

// ── 1. Approaching-bus notifications ─────────────────────────────────────────
// Runs every 2 minutes. For each student waiting at a stop, checks if any
// active bus is within 500 m. If so, sends an FCM push and marks the
// waiting_students record as 'notified' to avoid repeated alerts.
exports.checkApproachingBuses = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 2 minutes')
  .timeZone('Asia/Kuching')
  .onRun(async (_context) => {
    const [busesSnap, waitingSnap] = await Promise.all([
      admin.firestore().collection('buses').where('isActive', '==', true).get(),
      admin.firestore()
        .collection('waiting_students')
        .where('status', '==', 'waiting')
        .get(),
    ]);

    if (waitingSnap.empty || busesSnap.empty) return null;

    const buses = busesSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000);
    // Load template once outside the loop to avoid per-student DB reads.
    const approachingTmpl = await getTemplate(
      'bus_approaching',
      '\uD83D\uDE8C Bus is approaching!',
      'Bus {busNumber} ({regNumber}) is approaching {stopName}'
    );

    for (const waitDoc of waitingSnap.docs) {
      const w = waitDoc.data();
      if (!w.fcmToken) continue;

      // Don't spam – only notify once per 10 minutes per student
      if (w.notifiedAt && w.notifiedAt.toDate() > tenMinAgo) continue;

      for (const bus of buses) {
        if (!bus.latitude || !bus.longitude) continue;
        const dist = haversineKm(w.latitude, w.longitude, bus.latitude, bus.longitude);
        if (dist <= 0.5) {
          const ok = await sendToToken(
            w.fcmToken,
            fillTemplate(approachingTmpl.title, {}),
            fillTemplate(approachingTmpl.body, {
              busNumber: bus.busNumber,
              regNumber: bus.registrationNumber,
              stopName: w.stopName,
            }),
            { type: 'bus_approaching', busId: bus.id }
          );
          if (ok) {
            await waitDoc.ref.update({
              status: 'notified',
              notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
          break; // Only first matching bus per student per cycle
        }
      }
    }
    return null;
  });

// ── 2. Tap-out reminders ──────────────────────────────────────────────────────
// Runs every 5 minutes. Finds active device_bus_sessions that started more
// than 30 minutes ago and sends a reminder FCM. Rate-limited to once per
// 10 minutes per session.
exports.sendTapOutReminders = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 5 minutes')
  .timeZone('Asia/Kuching')
  .onRun(async (_context) => {
    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);
    const tenMinAgo   = new Date(Date.now() - 10 * 60 * 1000);

    const snap = await admin.firestore()
      .collection('device_bus_sessions')
      .where('status', '==', 'active')
      .where('tappedInAt', '<=', thirtyMinAgo)
      .get();

    // Load template once before the loop.
    const tapOutTmpl = await getTemplate(
      'tap_out_reminder',
      '\u23F0 Still on the bus?',
      "You've been on the bus for {elapsedMin} minutes. Tap out when you arrive!"
    );

    for (const doc of snap.docs) {
      const session = doc.data();

      // Don't spam
      if (session.lastReminderSentAt &&
          session.lastReminderSentAt.toDate() > tenMinAgo) continue;

      // Fetch device token
      const tokenDoc = await admin.firestore()
        .collection('device_tokens')
        .doc(session.deviceId)
        .get();
      if (!tokenDoc.exists || !tokenDoc.data().fcmToken) continue;

      const elapsedMin = Math.round(
        (Date.now() - session.tappedInAt.toMillis()) / 60000
      );
      const ok = await sendToToken(
        tokenDoc.data().fcmToken,
        fillTemplate(tapOutTmpl.title, {}),
        fillTemplate(tapOutTmpl.body, { elapsedMin }),
        { type: 'tap_out_reminder', busId: session.busId }
      );
      if (ok) {
        await doc.ref.update({
          lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    return null;
  });

// ── 3. Driver shift-end reminders ─────────────────────────────────────────────
// Runs every 10 minutes. If an active bus has had no GPS update for > 1 hour,
// sends a reminder to the assigned driver to end their shift.
// Rate-limited to once per 30 minutes per bus.
exports.sendDriverShiftReminders = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 10 minutes')
  .timeZone('Asia/Kuching')
  .onRun(async (_context) => {
    const oneHourAgo    = new Date(Date.now() - 60 * 60 * 1000);
    const thirtyMinAgo  = new Date(Date.now() - 30 * 60 * 1000);

    const snap = await admin.firestore()
      .collection('buses')
      .where('isActive', '==', true)
      .get();

    // Load template once before the loop.
    const shiftReminderTmpl = await getTemplate(
      'shift_reminder',
      '\uD83D\uDE8C Did you forget to end your shift?',
      'Bus {busNumber} has been active with no GPS update for over an hour. Please end your shift if you are done.'
    );

    for (const doc of snap.docs) {
      const bus = doc.data();
      if (!bus.driverId) continue;

      // Parse lastUpdated (stored as ISO string or Timestamp)
      let lastUpdated;
      if (bus.lastUpdated && typeof bus.lastUpdated.toDate === 'function') {
        lastUpdated = bus.lastUpdated.toDate();
      } else if (bus.lastUpdated) {
        lastUpdated = new Date(bus.lastUpdated);
      } else {
        continue;
      }
      if (lastUpdated > oneHourAgo) continue; // Updated recently – ok

      // Rate-limit
      if (bus.lastShiftReminderAt) {
        const last = typeof bus.lastShiftReminderAt.toDate === 'function'
          ? bus.lastShiftReminderAt.toDate()
          : new Date(bus.lastShiftReminderAt);
        if (last > thirtyMinAgo) continue;
      }

      // Fetch driver FCM token (saved under their userId in device_tokens)
      const tokenDoc = await admin.firestore()
        .collection('device_tokens')
        .doc(bus.driverId)
        .get();
      if (!tokenDoc.exists || !tokenDoc.data().fcmToken) continue;

      const ok = await sendToToken(
        tokenDoc.data().fcmToken,
        fillTemplate(shiftReminderTmpl.title, {}),
        fillTemplate(shiftReminderTmpl.body, { busNumber: bus.busNumber }),
        { type: 'shift_reminder', busId: doc.id }
      );
      if (ok) {
        await doc.ref.update({
          lastShiftReminderAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
    return null;
  });

// ── 4. Bus activated by admin → notify assigned driver ────────────────────────
// Triggers whenever a bus document is updated. When isActive flips false → true
// and a driver is assigned, sends an FCM push so the driver knows their shift
// has been started remotely — even if the app is closed.
exports.onBusActivated = functions
  .region('asia-southeast1')
  .firestore.document('buses/{busId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Only act when isActive flips false → true
    if (before.isActive === after.isActive) return null;
    if (!after.isActive) return null;

    // Only notify when the activation was explicitly performed by an admin.
    // Driver self-starts should not receive "Admin has activated..." pushes.
    const adminName = typeof after.activatedByAdminName === 'string'
      ? after.activatedByAdminName.trim()
      : '';
    if (!adminName) return null;

    const driverId = after.driverId;
    if (!driverId) return null;

    // Look up the driver FCM token (saved under their userId)
    const tokenDoc = await admin.firestore()
      .collection('device_tokens')
      .doc(driverId)
      .get();
    if (!tokenDoc.exists || !tokenDoc.data().fcmToken) return null;

    const busNumber = after.busNumber || 'your bus';
    const shiftStartedTmpl = await getTemplate(
      'shift_started',
      '\uD83D\uDE8C Your shift has started!',
      '{adminName} has activated Bus {busNumber}. Tap to begin driving.'
    );

    await sendToToken(
      tokenDoc.data().fcmToken,
      fillTemplate(shiftStartedTmpl.title, {}),
      fillTemplate(shiftStartedTmpl.body, { adminName, busNumber }),
      {
        type: 'shift_started',
        busId: context.params.busId,
        adminName: adminName,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      }
    );
    return null;
  });

// ── 5. One-time migration: backfill reporterUid on legacy reports ───────────
// Maps old report.deviceId/studentId -> device_tokens/{deviceId}.userId.
// Only fills records where reporterUid is missing, and only when a mapping
// exists. Run repeatedly with nextCursor until exhausted.
exports.backfillReportReporterUid = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required.'
      );
    }

    // Rate limit: max 2 calls per minute per admin UID
    enforceRateLimit(context.auth.uid, { maxCalls: 2, windowMs: 60_000 });

    const requesterDoc = await admin
      .firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!requesterDoc.exists || requesterDoc.data()?.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can run this migration.'
      );
    }

    const limit = Math.min(Math.max(Number(data?.limit || 200), 1), 1000);
    const dryRun = Boolean(data?.dryRun ?? true);
    const cursor = typeof data?.cursor === 'string' && data.cursor.trim()
      ? data.cursor.trim()
      : null;

    let query = admin
      .firestore()
      .collection('reports')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(limit);
    if (cursor) {
      query = query.startAfter(cursor);
    }

    const snap = await query.get();
    if (snap.empty) {
      return {
        processed: 0,
        updated: 0,
        skippedNoDeviceId: 0,
        skippedNoMapping: 0,
        skippedAlreadyOwned: 0,
        dryRun,
        done: true,
        nextCursor: null,
      };
    }

    let processed = 0;
    let updated = 0;
    let skippedNoDeviceId = 0;
    let skippedNoMapping = 0;
    let skippedAlreadyOwned = 0;

    const batch = admin.firestore().batch();

    for (const doc of snap.docs) {
      processed += 1;
      const report = doc.data();

      if (report.reporterUid) {
        skippedAlreadyOwned += 1;
        continue;
      }

      const deviceId = report.deviceId || report.studentId;
      if (!deviceId || typeof deviceId !== 'string') {
        skippedNoDeviceId += 1;
        continue;
      }

      const tokenDoc = await admin
        .firestore()
        .collection('device_tokens')
        .doc(deviceId)
        .get();

      const mappedUid = tokenDoc.exists ? tokenDoc.data()?.userId : null;
      if (!mappedUid || typeof mappedUid !== 'string') {
        skippedNoMapping += 1;
        continue;
      }

      updated += 1;
      if (!dryRun) {
        batch.update(doc.ref, { reporterUid: mappedUid });
      }
    }

    if (!dryRun && updated > 0) {
      await batch.commit();
    }

    const lastDoc = snap.docs[snap.docs.length - 1];
    const nextCursor = lastDoc.id;

    return {
      processed,
      updated,
      skippedNoDeviceId,
      skippedNoMapping,
      skippedAlreadyOwned,
      dryRun,
      done: snap.docs.length < limit,
      nextCursor,
    };
  });

// ── 6. Route leg distance precompute for ETA cost control ────────────────────

function _sameStopIds(a = [], b = []) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) {
    return false;
  }
  for (let i = 0; i < a.length; i += 1) {
    if (String(a[i]) !== String(b[i])) return false;
  }
  return true;
}

function _fallbackLegMeters(orderedStops) {
  const meters = [];
  for (let i = 0; i < orderedStops.length - 1; i += 1) {
    const km = haversineKm(
      orderedStops[i].latitude,
      orderedStops[i].longitude,
      orderedStops[i + 1].latitude,
      orderedStops[i + 1].longitude
    );
    meters.push(Math.round(km * 1000));
  }
  return meters;
}

async function _fetchDirectionsLegMeters(orderedStops) {
  const key = process.env.GOOGLE_MAPS_API_KEY || '';
  if (!key || orderedStops.length < 2) {
    return null;
  }

  const origin = `${orderedStops[0].latitude},${orderedStops[0].longitude}`;
  const destination =
    `${orderedStops[orderedStops.length - 1].latitude},${orderedStops[orderedStops.length - 1].longitude}`;
  const waypointList = orderedStops.length > 2
    ? orderedStops
        .slice(1, orderedStops.length - 1)
        .map((s) => `${s.latitude},${s.longitude}`)
        .join('|')
    : null;

  const url = new URL('https://maps.googleapis.com/maps/api/directions/json');
  url.searchParams.set('origin', origin);
  url.searchParams.set('destination', destination);
  url.searchParams.set('mode', 'driving');
  url.searchParams.set('key', key);
  if (waypointList) {
    url.searchParams.set('waypoints', `optimize:false|${waypointList}`);
  }

  const res = await fetch(url, { method: 'GET' });
  if (!res.ok) return null;

  const data = await res.json();
  if (data.status !== 'OK' || !Array.isArray(data.routes) || data.routes.length === 0) {
    return null;
  }

  const legs = data.routes[0]?.legs;
  if (!Array.isArray(legs) || legs.length !== orderedStops.length - 1) {
    return null;
  }

  return legs.map((leg) => Number(leg?.distance?.value || 0));
}

async function recomputeRouteLegDistances(routeId) {
  const routeRef = admin.firestore().collection('routes').doc(routeId);
  const routeDoc = await routeRef.get();
  if (!routeDoc.exists) return;

  const route = routeDoc.data();
  const stopIds = Array.isArray(route?.stopIds) ? route.stopIds : [];

  if (stopIds.length < 2) {
    await routeRef.update({
      legDistancesMeters: [],
      legDistanceSource: 'none',
      legDistanceUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      legDistanceStopIds: stopIds,
    });
    return;
  }

  const stopDocs = await Promise.all(
    stopIds.map((stopId) => admin.firestore().collection('bus_stops').doc(String(stopId)).get())
  );

  const orderedStops = [];
  for (let i = 0; i < stopDocs.length; i += 1) {
    const doc = stopDocs[i];
    if (!doc.exists) continue;
    const s = doc.data();
    const lat = Number(s?.latitude);
    const lng = Number(s?.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    orderedStops.push({
      stopId: stopIds[i],
      latitude: lat,
      longitude: lng,
    });
  }

  if (orderedStops.length < 2) {
    await routeRef.update({
      legDistancesMeters: [],
      legDistanceSource: 'none',
      legDistanceUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      legDistanceStopIds: stopIds,
    });
    return;
  }

  let legDistancesMeters = null;
  let source = 'haversine';
  try {
    legDistancesMeters = await _fetchDirectionsLegMeters(orderedStops);
    if (Array.isArray(legDistancesMeters) && legDistancesMeters.length > 0) {
      source = 'directions';
    }
  } catch (_) {
    legDistancesMeters = null;
  }

  if (!Array.isArray(legDistancesMeters) || legDistancesMeters.length === 0) {
    legDistancesMeters = _fallbackLegMeters(orderedStops);
    source = 'haversine';
  }

  await routeRef.update({
    legDistancesMeters,
    legDistanceSource: source,
    legDistanceUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    legDistanceStopIds: orderedStops.map((s) => s.stopId),
  });
}

exports.onRouteStopsChangedRecomputeLegs = functions
  .region('asia-southeast1')
  .firestore.document('routes/{routeId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return null;

    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.data();
    const beforeStopIds = Array.isArray(before?.stopIds) ? before.stopIds : [];
    const afterStopIds = Array.isArray(after?.stopIds) ? after.stopIds : [];

    if (change.before.exists && _sameStopIds(beforeStopIds, afterStopIds)) {
      return null;
    }

    await recomputeRouteLegDistances(context.params.routeId);
    return null;
  });

exports.onBusStopChangedRecomputeLegs = functions
  .region('asia-southeast1')
  .firestore.document('bus_stops/{stopId}')
  .onWrite(async (change, context) => {
    const stopId = context.params.stopId;
    if (!stopId) return null;

    const routesSnap = await admin
      .firestore()
      .collection('routes')
      .where('stopIds', 'array-contains', stopId)
      .get();

    if (routesSnap.empty) return null;

    for (const doc of routesSnap.docs) {
      await recomputeRouteLegDistances(doc.id);
    }

    return null;
  });

exports.recomputeAllRouteLegDistances = functions
  .region('asia-southeast1')
  .https.onCall(async (_data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required.'
      );
    }
    enforceRateLimit(context.auth.uid, { maxCalls: 2, windowMs: 60_000 });

    const requesterDoc = await admin
      .firestore()
      .collection('users')
      .doc(context.auth.uid)
      .get();

    if (!requesterDoc.exists || requesterDoc.data()?.role !== 'admin') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can recompute route legs.'
      );
    }

    const routesSnap = await admin.firestore().collection('routes').get();
    let processed = 0;
    for (const doc of routesSnap.docs) {
      await recomputeRouteLegDistances(doc.id);
      processed += 1;
    }

    return { success: true, processed };
  });


