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
      if (error.errorInfo) {
        console.error('Error info:', JSON.stringify(error.errorInfo));
      }
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
      if (error.errorInfo) {
        console.error('Error info:', JSON.stringify(error.errorInfo));
      }
      throw new functions.https.HttpsError('internal', 'Failed to resend notification: ' + error.message);
    }
  });
