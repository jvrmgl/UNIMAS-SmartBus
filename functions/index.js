const admin = require('firebase-admin');
const functions = require('firebase-functions');

if (!admin.apps.length) {
  admin.initializeApp();
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
