const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.checkExpiringMemberships = functions.pubsub.schedule('0 13 * * *').timeZone('America/New_York').onRun(async (context) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const getBounds = (daysFromNow) => {
      const start = new Date(today);
      start.setDate(today.getDate() + daysFromNow);
      const end = new Date(start);
      end.setDate(start.getDate() + 1);
      return { start, end };
    };

    const targetDays = [7, 3, 1, 0];
    
    // Structure to group members: { [tenantId]: { 7: count, 3: count, 1: count, 0: count } }
    const tenantExpirations = {};

    // Query for each target day
    for (const days of targetDays) {
      const { start, end } = getBounds(days);
      
      const membersSnapshot = await db.collectionGroup('members')
        .where('expiryDate', '>=', admin.firestore.Timestamp.fromDate(start))
        .where('expiryDate', '<', admin.firestore.Timestamp.fromDate(end))
        .where('isActive', '==', true)
        .where('isLifetimeFree', '==', false)
        .get();

      membersSnapshot.forEach(doc => {
        const member = doc.data();
        const tenantId = member.tenantId;
        if (tenantId) {
          if (!tenantExpirations[tenantId]) {
            tenantExpirations[tenantId] = { 7: 0, 3: 0, 1: 0, 0: 0 };
          }
          tenantExpirations[tenantId][days]++;
        }
      });
    }

    // Send notifications
    for (const [tenantId, counts] of Object.entries(tenantExpirations)) {
      let messageBody = [];
      if (counts[7] > 0) messageBody.push(`${counts[7]} member(s) expiring in one week`);
      if (counts[3] > 0) messageBody.push(`${counts[3]} member(s) expiring in 3 days`);
      if (counts[1] > 0) messageBody.push(`${counts[1]} member(s) expiring in 1 day`);
      if (counts[0] > 0) messageBody.push(`${counts[0]} member(s) expiring today`);

      if (messageBody.length === 0) continue;

      const bodyText = messageBody.join(', ');

      // Find admins for this tenant
      const adminsSnapshot = await db.collection('users')
        .where('tenantId', '==', tenantId)
        .where('role', '==', 'gymOwner')
        .get();

      const tokens = [];
      adminsSnapshot.forEach(doc => {
        const user = doc.data();
        if (user.fcmToken) {
          tokens.push(user.fcmToken);
        }
      });

      if (tokens.length > 0) {
        const payload = {
          notification: {
            title: 'Membership Expirations',
            body: bodyText,
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'notification',
              channelId: 'gcrm_notifications',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
            },
            payload: {
              aps: {
                sound: 'notification.mp3',
              },
            },
          },
          tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(`Sent notifications for tenant ${tenantId}. Success: ${response.successCount}, Failures: ${response.failureCount}`);
      }
    }

    return null;
  } catch (error) {
    console.error('Error checking expiring memberships:', error);
    return null;
  }
});

/**
 * Helper to resolve recipient user ids and their FCM tokens.
 */
async function getTargetRecipients({ targetAudience, targetTenantId }) {
  const tokenSet = new Set();
  const userIds = new Set();

  const addUserDoc = (doc) => {
    if (!doc || !doc.exists && !doc.id) return;
    if (doc.id) userIds.add(doc.id);
    const data = doc.data ? doc.data() : null;
    if (!data) return;
    const token = data.fcmToken;
    if (typeof token === 'string' && token.trim().length > 0) {
      tokenSet.add(token.trim());
    }
  };

  if (targetAudience === 'specific_gym' && targetTenantId) {
    const snapshot = await db.collection('users')
      .where('tenantId', '==', targetTenantId)
      .get();
    snapshot.forEach(addUserDoc);

    try {
      const tenantDoc = await db.collection('tenants').doc(targetTenantId).get();
      if (tenantDoc.exists) {
        const tenantData = tenantDoc.data() || {};
        const uidsToCheck = [tenantData.ownerId, tenantData.adminId].filter(Boolean);
        for (const uid of uidsToCheck) {
          const userDoc = await db.collection('users').doc(uid).get();
          if (userDoc.exists) addUserDoc(userDoc);
        }
      }
    } catch (e) {
      console.warn('Error reading tenant doc for admin tokens:', e);
    }

    return { userIds: Array.from(userIds), tokens: Array.from(tokenSet) };
  }

  let query = db.collection('users');
  if (targetAudience === 'gym_owners') {
    query = query.where('role', 'in', [
      'gymOwner',
      'gym_owner',
      'gym_admin',
      'owner',
      'admin',
      'gymAdmin',
    ]);
  }

  const snapshot = await query.get();
  snapshot.forEach(addUserDoc);

  if (targetAudience === 'gym_owners') {
    try {
      const tenantsSnap = await db.collection('tenants').get();
      const extraIds = [];
      tenantsSnap.forEach((tenantDoc) => {
        const tenantData = tenantDoc.data() || {};
        if (tenantData.adminId) extraIds.push(tenantData.adminId);
        if (tenantData.ownerId) extraIds.push(tenantData.ownerId);
      });
      for (const uid of extraIds) {
        if (!uid || userIds.has(uid)) continue;
        const userDoc = await db.collection('users').doc(uid).get();
        if (userDoc.exists) addUserDoc(userDoc);
      }
    } catch (e) {
      console.warn('Error resolving gym owner ids from tenants:', e);
    }
  }

  return { userIds: Array.from(userIds), tokens: Array.from(tokenSet) };
}

/**
 * Copies the broadcast onto each recipient user so the gym admin notification page can list it.
 */
async function fanOutInboxEntries(userIds, entry) {
  if (!entry || !userIds || userIds.length === 0) return;
  const chunkSize = 400;
  for (let i = 0; i < userIds.length; i += chunkSize) {
    const chunk = userIds.slice(i, i + chunkSize);
    const batch = db.batch();
    chunk.forEach((uid) => {
      batch.set(db.collection('users').doc(uid), {
        platformNotifications: admin.firestore.FieldValue.arrayUnion(entry),
      }, { merge: true });
    });
    await batch.commit();
  }
}

function inboxEntryFromDoc(docId, docData) {
  if (docData.inboxEntry && typeof docData.inboxEntry === 'object') {
    return docData.inboxEntry;
  }
  return {
    id: docId,
    title: docData.title || 'Platform Notification',
    body: docData.body || '',
    createdAt: new Date().toISOString(),
    targetAudience: docData.targetAudience || 'all',
    targetTenantId: docData.targetTenantId || '',
    sound: docData.sound || 'notification.mp3',
  };
}

/**
 * Sends notification payload in chunks of up to 500 tokens (FCM multicast limit).
 */
async function sendMulticastInBatches({ title, body, sound = 'notification.mp3', data = {}, tokens }) {
  if (!tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  let totalSuccess = 0;
  let totalFailure = 0;
  const chunkSize = 500;

  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    const payload = {
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: 'high',
          notification: {
            title: title,
            body: body,
            channelId: 'gcrm_notifications',
            priority: 'max',
            defaultVibrateTimings: true,
            defaultSound: true,
          },
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
                  sound: 'default',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      data: {
        ...data,
        title: title,
        body: body,
        sound: sound || 'default',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: chunk,
    };

    const response = await admin.messaging().sendEachForMulticast(payload);
    totalSuccess += response.successCount;
    totalFailure += response.failureCount;
  }

  return { successCount: totalSuccess, failureCount: totalFailure };
}

/**
 * Firestore trigger: processes queued push notifications created by Super Admin.
 */
exports.processNotificationQueue = functions.firestore
  .document('notifications_queue/{docId}')
  .onCreate(async (snap, context) => {
    const docData = snap.data();
    const docId = context.params.docId;

    if (docData.status === 'completed' || docData.status === 'processing') {
      return null;
    }

    await snap.ref.update({
      status: 'processing',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const { userIds, tokens } = await getTargetRecipients({
        targetAudience: docData.targetAudience,
        targetTenantId: docData.targetTenantId,
      });

      try {
        await fanOutInboxEntries(userIds, inboxEntryFromDoc(docId, docData));
      } catch (inboxErr) {
        console.warn(`Inbox fan-out note for ${docId}:`, inboxErr);
      }

      const { successCount, failureCount } = await sendMulticastInBatches({
        title: docData.title || 'Platform Notification',
        body: docData.body || '',
        sound: docData.sound || 'notification.mp3',
        data: {
          notificationId: docId,
          title: docData.title || 'Platform Notification',
          body: docData.body || '',
          targetAudience: docData.targetAudience || 'all',
          targetTenantId: docData.targetTenantId || '',
        },
        tokens: tokens,
      });

      // Resilient Topic Broadcast: deliver to all subscribed devices on the topic
      let topic = null;
      if (docData.targetAudience === 'all') topic = 'all';
      else if (docData.targetAudience === 'gym_owners') topic = 'gym_owners';
      else if (docData.targetAudience === 'specific_gym' && docData.targetTenantId) {
        topic = `gym_${docData.targetTenantId}`;
      }

      if (topic && successCount === 0) {
        try {
          await admin.messaging().send({
            topic: topic,
            notification: {
              title: docData.title || 'Platform Notification',
              body: docData.body || '',
            },
            android: {
              priority: 'high',
              notification: {
                title: docData.title || 'Platform Notification',
                body: docData.body || '',
                channelId: 'gcrm_notifications',
                priority: 'max',
                defaultSound: true,
              },
            },
            apns: {
              headers: {
                'apns-priority': '10',
                'apns-push-type': 'alert',
              },
              payload: {
                aps: {
                  alert: {
                    title: docData.title || 'Platform Notification',
                    body: docData.body || '',
                  },
                  sound: 'default',
                  badge: 1,
                },
              },
            },
            data: {
              notificationId: docId,
              title: docData.title || 'Platform Notification',
              body: docData.body || '',
              targetAudience: docData.targetAudience || 'all',
              targetTenantId: docData.targetTenantId || '',
            },
          });
          console.log(`Topic broadcast successfully dispatched to: ${topic}`);
        } catch (topicErr) {
          console.warn(`Topic send note for ${topic}:`, topicErr);
        }
      }

      await snap.ref.update({
        status: 'completed',
        recipientsCount: userIds.length,
        successCount: successCount,
        failureCount: failureCount,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Notification ${docId} processed. Recipients: ${tokens.length}, Success: ${successCount}, Failures: ${failureCount}`);
    } catch (error) {
      console.error(`Error processing notification ${docId}:`, error);
      await snap.ref.update({
        status: 'failed',
        error: error.message || String(error),
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return null;

  });

/**
 * Callable function for direct Super Admin push notification dispatch.
 */
exports.sendSuperAdminPushNotification = functions.https.onCall(async (data, context) => {
  const { title, body, targetAudience, targetTenantId, sound } = data || {};

  if (!title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'Title and body are required.');
  }

  try {
    const { userIds, tokens } = await getTargetRecipients({ targetAudience, targetTenantId });
    const notificationRef = db.collection('notifications_queue').doc();
    const inboxEntry = {
      id: notificationRef.id,
      title,
      body,
      createdAt: new Date().toISOString(),
      targetAudience: targetAudience || 'all',
      targetTenantId: targetTenantId || '',
      sound: sound || 'notification.mp3',
    };
    try {
      await fanOutInboxEntries(userIds, inboxEntry);
    } catch (inboxErr) {
      console.warn('Inbox fan-out note:', inboxErr);
    }
    const { successCount, failureCount } = await sendMulticastInBatches({
      title,
      body,
      sound: sound || 'notification.mp3',
      data: {
        notificationId: notificationRef.id,
        title,
        body,
        targetAudience: targetAudience || 'all',
        targetTenantId: targetTenantId || '',
      },
      tokens,
    });

    const recordRef = notificationRef;
    await recordRef.set({
      title,
      body,
      targetAudience: targetAudience || 'all',
      targetTenantId: targetTenantId || null,
      sound: sound || 'notification.mp3',
      inboxEntry,
      status: 'completed',
      recipientsCount: userIds.length,
      successCount,
      failureCount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      sentBy: context.auth ? context.auth.uid : 'superadmin',
    });

    return {
      success: true,
      notificationId: recordRef.id,
      recipientsCount: tokens.length,
      successCount,
      failureCount,
    };
  } catch (err) {
    console.error('Error in sendSuperAdminPushNotification:', err);
    throw new functions.https.HttpsError('internal', err.message || 'Notification sending failed.');
  }
});

