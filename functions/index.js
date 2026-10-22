const crypto = require('crypto');
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { runMembershipExpiryReminders } = require('./membership_reminders');
const {
  INBOX_PAGE_SIZE,
  normalizeInboxEntry,
  legacyNotificationDocs,
  inboxPageResult,
  isMembershipReminderNotification,
} = require('./notification_inbox');
const { purgeExpiredMessages } = require('./message_retention');

admin.initializeApp();
const db = admin.firestore();

/**
 * Every day at 1:00 PM Asia/Kolkata, WhatsApp-remind members
 * 7, 3, and 1 days before expiry, then 1, 3, and 7 days after expiry.
 * Each gym gets one summary push for every member reminded that day.
 */
exports.checkExpiringMemberships = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub.schedule('0 13 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const summary = await runMembershipExpiryReminders({
      db,
      deliverPush: deliverMembershipPush,
      deliverWhatsApp: deliverMembershipWhatsApp,
    });
    if (summary.pushFailed > 0 || summary.whatsappFailed > 0) {
      throw new Error(
        `Membership reminders had ${summary.pushFailed} push failure(s) and ${summary.whatsappFailed} WhatsApp failure(s).`,
      );
    }
    return null;
  });

/**
 * Every 20 days, delete saved push notifications and WhatsApp delivery
 * rows from before the Asia/Kolkata day that is five days ago.
 */
exports.purgeOldNotificationAndWhatsAppData = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub.schedule('every 20 days')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    const summary = await purgeExpiredMessages({ db, admin });
    console.log('Purged old notification and WhatsApp data', summary);
    return null;
  });

async function deliverMembershipPush({
  tenant,
  memberId,
  copy,
  logId,
  milestone,
  expiryKey,
  createdAt,
  userIds,
  tokens,
}) {
  if (!tokens || tokens.length === 0) {
    return { ok: false, skipped: true, error: 'No gym admin recipients' };
  }

  try {
    const response = await sendMulticastInBatches({
      title: copy.title,
      body: copy.body,
      tokens,
      data: Object.assign({
        type: memberId ? 'membership_expiry' : 'membership_digest',
        tenantId: tenant.id,
      }, memberId ? {
        memberId: String(memberId),
        milestone: milestone && milestone.id ? milestone.id : '',
        expiryDate: expiryKey || '',
      } : {
        openTab: 'members',
      }),
    });
    if (response.successCount === 0) {
      return { ok: false, error: `FCM rejected all ${response.failureCount} admin token(s).` };
    }
  } catch (error) {
    return { ok: false, error: error.message || 'FCM send failed' };
  }

  return { ok: true };
}

async function deliverMembershipWhatsApp({
  tenantId,
  phone,
  memberName,
  gymName,
  kind,
  dayCount,
  memberId,
}) {
  const to = normalizeWhatsAppRecipient(phone);
  if (!to) return { ok: false, skipped: true, error: 'Member does not have a valid mobile number.' };
  const result = await postWhatsAppTemplate({
    tenantId,
    to,
    memberName,
    gymName,
    kind,
    dayCount,
    memberId,
  });
  if (!result.ok && result.notConfigured) {
    return { ok: false, error: result.error };
  }
  return result;
}

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
 * Writes one notification document per recipient.
 * A page is 10 of these documents, so the app does not read an ever-growing array.
 */
async function fanOutInboxEntries(userIds, entry) {
  const normalized = normalizeInboxEntry(entry);
  if (!normalized || !userIds || userIds.length === 0) return;
  const chunkSize = 400;
  for (let i = 0; i < userIds.length; i += chunkSize) {
    const chunk = userIds.slice(i, i + chunkSize);
    const batch = db.batch();
    chunk.forEach((uid) => {
      if (!uid) return;
      batch.set(
        db.collection('users').doc(uid).collection('notifications').doc(normalized.id),
        normalized,
        { merge: true },
      );
    });
    await batch.commit();
  }
}

/**
 * Moves platformNotifications off the user document the first time that inbox is opened.
 * Later pages only read 10 notification documents.
 */
async function migrateLegacyInbox(uid) {
  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) return;
  const legacy = snap.get('platformNotifications');
  if (legacy == null) return;
  const docs = legacyNotificationDocs(legacy);
  const chunkSize = 400;
  for (let i = 0; i < docs.length; i += chunkSize) {
    const batch = db.batch();
    docs.slice(i, i + chunkSize).forEach((entry) => {
      batch.set(userRef.collection('notifications').doc(entry.id), entry, { merge: true });
    });
    await batch.commit();
  }
  await userRef.update({
    platformNotifications: admin.firestore.FieldValue.delete(),
  });
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
 * Returns one page of the signed-in user's notification inbox.
 * The page size is fixed at 10 so the client cannot read the whole history.
 */
exports.listNotificationInbox = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const uid = context.auth.uid;
  if (data && data.migrate === true) {
    try {
      await migrateLegacyInbox(uid);
    } catch (error) {
      console.warn(`Legacy notification inbox migration failed for ${uid}:`, error);
    }
  }

  const startAfter = data && typeof data.startAfter === 'string' ? data.startAfter.trim() : '';
  return listCustomInboxPage(uid, startAfter);
});

/**
 * Reads custom broadcasts only. Membership reminders are deleted if one was stored earlier.
 */
async function listCustomInboxPage(uid, startAfter) {
  const items = [];
  const staleRefs = [];
  let cursor = startAfter || '';
  let hasMore = false;

  for (let scan = 0; scan < 20 && items.length < INBOX_PAGE_SIZE; scan += 1) {
    const previousCursor = cursor;
    let query = db.collection('users').doc(uid).collection('notifications')
      .orderBy('createdAt', 'desc')
      .limit(INBOX_PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) {
      hasMore = false;
      break;
    }

    let pageFull = false;
    snap.forEach((doc) => {
      if (pageFull) return;
      const row = doc.data() || {};
      const createdAt = row.createdAt ? String(row.createdAt) : '';
      if (createdAt) cursor = createdAt;
      if (isMembershipReminderNotification(Object.assign({ id: doc.id }, row))) {
        staleRefs.push(doc.ref);
        return;
      }
      items.push({
        id: doc.id,
        title: row.title || '',
        body: row.body || '',
        createdAt,
        targetAudience: row.targetAudience || '',
        targetTenantId: row.targetTenantId || '',
        sound: row.sound || 'default',
        openTab: row.openTab || '',
      });
      if (items.length >= INBOX_PAGE_SIZE) pageFull = true;
    });

    if (snap.size < INBOX_PAGE_SIZE) {
      hasMore = false;
      break;
    }
    if (pageFull) {
      hasMore = true;
      break;
    }
    if (cursor === previousCursor) break;
  }

  if (staleRefs.length > 0) {
    try {
      const batch = db.batch();
      staleRefs.forEach((ref) => batch.delete(ref));
      await batch.commit();
    } catch (error) {
      console.warn(`Could not remove stored membership reminders for ${uid}:`, error);
    }
  }

  const page = inboxPageResult(items);
  page.hasMore = hasMore;
  page.nextCursor = hasMore ? (cursor || null) : page.nextCursor;
  return page;
}

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

/**
 * Normalizes a member phone number to WhatsApp international digits.
 * Defaults to India (91) when the stored number has no country code.
 */
function normalizeWhatsAppRecipient(rawPhone, countryCode = '91') {
  let digits = String(rawPhone || '').replace(/\D/g, '');
  if (!digits) return null;
  if (digits.startsWith('00')) digits = digits.slice(2);
  if (digits.startsWith('0') && digits.length === 11) digits = digits.slice(1);
  if (digits.length === 10) digits = `${countryCode}${digits}`;
  if (digits.length < 11 || digits.length > 15) return null;
  return digits;
}

/**
 * Approved WhatsApp templates. Body parameter order is fixed by Meta.
 * welcome: gym name, member name, gym name.
 * membership_expired: member name, gym name, gym name.
 * membership_expiry: member name, gym name, 7, gym name.
 */
function defaultWhatsAppTemplates() {
  return [
    process.env.WHATSAPP_TEMPLATE_NAME || 'welcome_member',
    process.env.WHATSAPP_EXPIRED_TEMPLATE_NAME || 'membership_expired_reminder',
    process.env.WHATSAPP_EXPIRY_TEMPLATE_NAME || 'membership_expiry_reminder',
  ];
}

function defaultWhatsAppLanguages() {
  return [
    process.env.WHATSAPP_TEMPLATE_LANGUAGE || 'en',
    process.env.WHATSAPP_EXPIRED_TEMPLATE_LANGUAGE || 'en',
    process.env.WHATSAPP_EXPIRY_TEMPLATE_LANGUAGE || 'en',
  ];
}

function parseWhatsAppTemplates(value) {
  const defaults = defaultWhatsAppTemplates();
  let names = [];
  if (Array.isArray(value)) {
    names = value.map((item) => String(item || '').trim()).filter(Boolean);
  } else if (typeof value === 'string') {
    names = value.split(',').map((item) => item.trim()).filter(Boolean);
  }
  if (!names.length) {
    const savedNames = [
      value && value.welcomeTemplateName,
      value && value.sessionTemplateName,
      value && value.expiredTemplateName,
    ].map((item) => String(item || '').trim()).filter(Boolean);
    if (savedNames.length) names = savedNames;
  }
  return [
    names[0] || defaults[0],
    names[1] || defaults[1],
    names[2] || defaults[2],
  ];
}

function publicWhatsAppSettings(saved) {
  const data = saved || {};
  const fromList = Array.isArray(data.templates) || typeof data.templates === 'string'
    ? data.templates
    : data;
  return {
    phoneNumberId: String(data.phoneNumberId || '').trim(),
    tokenSaved: Boolean(String(data.accessToken || '').trim()),
    templates: parseWhatsAppTemplates(fromList),
  };
}

async function loadTenantWhatsAppConfig(tenantId) {
  const empty = {
    phoneNumberId: '',
    accessToken: '',
    templates: defaultWhatsAppTemplates(),
    languages: defaultWhatsAppLanguages(),
  };
  if (!tenantId) return empty;
  const snap = await db.collection('whatsapp_secrets').doc(tenantId).get();
  if (!snap.exists) return empty;
  const saved = snap.data() || {};
  const phoneNumberId = String(saved.phoneNumberId || '').trim();
  const accessToken = String(saved.accessToken || '').trim();
  const pub = publicWhatsAppSettings(saved);
  if (!phoneNumberId || !accessToken) {
    return { ...empty, templates: pub.templates };
  }
  return {
    phoneNumberId,
    accessToken,
    templates: pub.templates,
    languages: defaultWhatsAppLanguages(),
  };
}

function whatsAppTemplate(kind, memberName, gymName, config, dayCount = '7') {
  const templates = config.templates || defaultWhatsAppTemplates();
  const languages = config.languages || defaultWhatsAppLanguages();
  const days = String(dayCount || '7');
  if (kind === 'membership_expired') {
    return {
      name: templates[1],
      language: languages[1],
      parameters: [memberName, gymName, gymName],
    };
  }
  if (kind === 'membership_expiry') {
    return {
      name: templates[2],
      language: languages[2],
      parameters: [memberName, gymName, days, gymName],
    };
  }
  return {
    name: templates[0],
    language: languages[0],
    parameters: [gymName, memberName, gymName],
  };
}

async function assertSuperAdmin(uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  const user = userDoc.exists ? userDoc.data() : {};
  const role = String(user.role || '');
  const isSuperAdmin = user.isSuperAdmin === true || role === 'super_admin' || role === 'superAdmin';
  if (isSuperAdmin) return;
  throw new functions.https.HttpsError('permission-denied', 'Only a super admin can change WhatsApp settings.');
}

/**
 * Posts one approved template and writes the delivery log.
 * dayCount fills membership_expiry_reminder variable 3. The daily job passes 7, 3, or 1.
 */
function isMemberCardUrl(url, tenantId) {
  let parsed;
  try {
    parsed = new URL(String(url || ''));
  } catch (error) {
    return false;
  }
  if (parsed.protocol !== 'https:') return false;
  const host = parsed.hostname;
  const storageHost = host === 'firebasestorage.googleapis.com'
    || host.endsWith('.firebasestorage.app')
    || host === 'storage.googleapis.com';
  if (!storageHost) return false;
  const path = decodeURIComponent(`${parsed.pathname}${parsed.search}`);
  return path.includes(`/tenants/${tenantId}/members/`) || path.includes(`tenants/${tenantId}/members/`);
}

async function postWhatsAppTemplate({
  tenantId,
  to,
  memberName,
  gymName,
  kind,
  dayCount = '7',
  memberId,
  documentUrl,
  documentFilename,
  config,
}) {
  const whatsAppConfig = config || await loadTenantWhatsAppConfig(tenantId);
  const phoneNumberId = whatsAppConfig.phoneNumberId;
  const accessToken = whatsAppConfig.accessToken;
  if (!phoneNumberId || !accessToken) {
    return {
      ok: false,
      notConfigured: true,
      error: 'Add this gym\'s production WhatsApp phone number ID and access token before sending.',
    };
  }

  const template = whatsAppTemplate(kind, memberName, gymName, whatsAppConfig, dayCount);
  const textParameter = (text) => ({
    type: 'text',
    text: String(text).replace(/[\r\n\t]+/g, ' ').trim() || '-',
  });
  const components = [];
  if (documentUrl) {
    components.push({
      type: 'header',
      parameters: [
        {
          type: 'document',
          document: {
            link: documentUrl,
            filename: String(documentFilename || 'ICard.pdf').replace(/[^\w.\- ]/g, '_').slice(0, 240) || 'ICard.pdf',
          },
        },
      ],
    });
  }
  components.push({
    type: 'body',
    parameters: template.parameters.map(textParameter),
  });
  const response = await fetch(`https://graph.facebook.com/v22.0/${phoneNumberId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to,
      type: 'template',
      template: {
        name: template.name,
        language: { code: template.language },
        components,
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  const messageId = payload.messages && payload.messages[0] ? payload.messages[0].id : null;
  if (!response.ok) {
    const graphError = payload.error || {};
    const message = graphError.message || 'WhatsApp could not send this template.';
    const details = graphError.error_data && graphError.error_data.details;
    console.error('WhatsApp template send failed:', message, details || '');
    await writeWhatsAppLog({
      messageId,
      tenantId,
      memberName,
      phone: to,
      templateName: template.name,
      kind,
      recipientId: memberId,
      status: 'failed',
      errorCode: graphError.code || null,
      errorTitle: graphError.type || null,
      errorMessage: message,
      errorDetails: details || null,
    });
    return {
      ok: false,
      error: details ? `${message} ${details}` : message,
    };
  }

  await writeWhatsAppLog({
    messageId,
    tenantId,
    memberName,
    phone: to,
    templateName: template.name,
    kind,
    recipientId: memberId,
    status: 'accepted',
  });
  return { ok: true, messageId };
}

/**
 * Sends welcome_member with the new member's I-Card PDF as the template file.
 */
exports.sendMemberWelcomeCard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in is required to send WhatsApp messages.');
  }

  const memberName = String((data && data.memberName) || '').trim();
  const gymName = String((data && data.gymName) || '').trim();
  const documentUrl = String((data && data.documentUrl) || '').trim();
  const filename = String((data && data.filename) || 'ICard.pdf').trim();
  const to = normalizeWhatsAppRecipient(data && data.phone);
  if (!to) {
    throw new functions.https.HttpsError('invalid-argument', 'This member does not have a valid mobile number.');
  }
  if (!memberName || !gymName) {
    throw new functions.https.HttpsError('invalid-argument', 'Member name and gym name are required.');
  }

  const tenantId = await resolveWhatsAppTenantId(context.auth.uid, data && data.tenantId);
  if (!tenantId) {
    throw new functions.https.HttpsError('failed-precondition', 'This gym could not be resolved.');
  }
  if (!isMemberCardUrl(documentUrl, tenantId)) {
    throw new functions.https.HttpsError('invalid-argument', 'The I-Card file link is not valid for this gym.');
  }

  const result = await postWhatsAppTemplate({
    tenantId,
    to,
    memberName,
    gymName,
    kind: 'welcome',
    memberId: data && data.memberId,
    documentUrl,
    documentFilename: filename,
  });
  if (!result.ok) {
    const code = result.notConfigured ? 'failed-precondition' : 'internal';
    throw new functions.https.HttpsError(code, result.error);
  }
  return { success: true, messageId: result.messageId };
});

const WHATSAPP_STATUS_RANK = {
  accepted: 0,
  sent: 1,
  delivered: 2,
  read: 3,
  failed: 4,
};

/**
 * Keeps a later delivery state from being overwritten by an older one.
 * A failure always replaces the current state.
 */
function shouldApplyWhatsAppStatus(currentStatus, nextStatus) {
  if (!currentStatus) return true;
  if (nextStatus === 'failed') return true;
  if (currentStatus === 'failed') return false;
  const currentRank = WHATSAPP_STATUS_RANK[currentStatus];
  const nextRank = WHATSAPP_STATUS_RANK[nextStatus];
  if (currentRank === undefined || nextRank === undefined) return true;
  return nextRank >= currentRank;
}

async function resolveWhatsAppTenantId(uid, requestedTenantId) {
  const requested = String(requestedTenantId || '').trim();
  try {
    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.exists ? userDoc.data() : {};
    const role = String(user.role || '');
    const isSuperAdmin = user.isSuperAdmin === true || role === 'super_admin' || role === 'superAdmin';
    if (isSuperAdmin && requested) return requested;
    const storedTenantId = user.tenantId;
    if (storedTenantId && String(storedTenantId).trim()) return String(storedTenantId).trim();
  } catch (error) {
    console.error('Could not resolve WhatsApp tenant:', error.message);
  }
  return requested || null;
}

/**
 * Creates or updates one WhatsApp delivery record.
 * Webhook updates keep the member name captured at send time.
 */
async function writeWhatsAppLog(entry) {
  const messageId = entry.messageId ? String(entry.messageId) : '';
  const ref = messageId
    ? db.collection('whatsapp_message_logs').doc(messageId)
    : db.collection('whatsapp_message_logs').doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const current = snap.exists ? snap.data() : {};
    if (!shouldApplyWhatsAppStatus(current.status, entry.status)) return;

    const next = {
      messageId: messageId || ref.id,
      status: entry.status,
      updatedAt: now,
      createdAt: current.createdAt || now,
    };
    if (entry.tenantId) next.tenantId = entry.tenantId;
    if (entry.memberName) next.memberName = entry.memberName;
    if (entry.phone) next.phone = entry.phone;
    if (entry.templateName) next.templateName = entry.templateName;
    if (entry.kind) next.kind = entry.kind;
    if (entry.recipientId) next.recipientId = entry.recipientId;
    if (entry.errorCode != null) next.errorCode = entry.errorCode;
    if (entry.errorTitle) next.errorTitle = entry.errorTitle;
    if (entry.errorMessage) next.errorMessage = entry.errorMessage;
    if (entry.errorDetails) next.errorDetails = entry.errorDetails;
    transaction.set(ref, next, { merge: true });
  });
}

function whatsAppSignatureMatches(req) {
  const appSecret = process.env.WHATSAPP_APP_SECRET;
  if (!appSecret) return true;
  const signature = req.get('x-hub-signature-256') || '';
  if (!req.rawBody || !signature.startsWith('sha256=')) return false;
  const expected = `sha256=${crypto.createHmac('sha256', appSecret).update(req.rawBody).digest('hex')}`;
  const actualBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  if (actualBuffer.length !== expectedBuffer.length) return false;
  return crypto.timingSafeEqual(actualBuffer, expectedBuffer);
}

function firstWhatsAppError(status) {
  const errors = status && Array.isArray(status.errors) ? status.errors : [];
  return errors.length ? errors[0] : null;
}

/**
 * Returns this gym's WhatsApp settings. The access token is never included.
 */
exports.getGymWhatsAppSettings = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in is required.');
  }
  const tenantId = await resolveWhatsAppTenantId(context.auth.uid, data && data.tenantId);
  if (!tenantId) {
    throw new functions.https.HttpsError('failed-precondition', 'This account is not linked to a gym.');
  }
  await assertSuperAdmin(context.auth.uid);
  const snap = await db.collection('whatsapp_secrets').doc(tenantId).get();
  return {
    tenantId,
    ...publicWhatsAppSettings(snap.exists ? snap.data() : {}),
  };
});

/**
 * Saves optional per-gym WhatsApp sender details. The token is stored server-side only.
 */
exports.saveGymWhatsAppSettings = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in is required.');
  }
  const tenantId = await resolveWhatsAppTenantId(context.auth.uid, data && data.tenantId);
  if (!tenantId) {
    throw new functions.https.HttpsError('failed-precondition', 'This account is not linked to a gym.');
  }
  await assertSuperAdmin(context.auth.uid);

  const ref = db.collection('whatsapp_secrets').doc(tenantId);
  const existingSnap = await ref.get();
  const existing = existingSnap.exists ? existingSnap.data() : {};
  const phoneNumberId = String((data && data.phoneNumberId) || '').replace(/\D/g, '');
  const incomingToken = String((data && data.accessToken) || '').trim();
  const accessToken = incomingToken || String(existing.accessToken || '').trim();

  if (phoneNumberId && !accessToken) {
    throw new functions.https.HttpsError('invalid-argument', 'Add the WhatsApp access token for this phone number.');
  }

  const templates = parseWhatsAppTemplates(data && data.templates);
  const next = {
    phoneNumberId,
    accessToken: phoneNumberId ? accessToken : '',
    templates,
    welcomeTemplateName: admin.firestore.FieldValue.delete(),
    welcomeTemplateLanguage: admin.firestore.FieldValue.delete(),
    sessionTemplateName: admin.firestore.FieldValue.delete(),
    sessionTemplateLanguage: admin.firestore.FieldValue.delete(),
    expiredTemplateName: admin.firestore.FieldValue.delete(),
    expiredTemplateLanguage: admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await ref.set(next, { merge: true });
  return {
    tenantId,
    ...publicWhatsAppSettings(next),
  };
});

/**
 * Meta webhook for WhatsApp delivery statuses and errors.
 * GET confirms the callback. POST stores sent, delivered, read, and failed.
 */
exports.whatsappWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];
    const verifyToken = process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN;
    if (mode === 'subscribe' && verifyToken && token === verifyToken) {
      res.status(200).send(challenge);
      return;
    }
    res.sendStatus(403);
    return;
  }

  if (req.method !== 'POST') {
    res.sendStatus(405);
    return;
  }
  if (!whatsAppSignatureMatches(req)) {
    console.error('WhatsApp webhook signature did not match.');
    res.sendStatus(403);
    return;
  }

  const body = req.body || {};
  const entries = Array.isArray(body.entry) ? body.entry : [];
  try {
    for (const entry of entries) {
      const changes = Array.isArray(entry.changes) ? entry.changes : [];
      for (const change of changes) {
        const value = change.value || {};
        const statuses = Array.isArray(value.statuses) ? value.statuses : [];
        for (const status of statuses) {
          const error = firstWhatsAppError(status);
          const errorDetails = error && error.error_data ? error.error_data.details : null;
          console.log('WhatsApp status', status.status, 'error', error ? error.code : 'none');
          await writeWhatsAppLog({
            messageId: status.id,
            recipientId: status.recipient_id || null,
            status: status.status || 'sent',
            errorCode: error ? error.code : null,
            errorTitle: error ? error.title : null,
            errorMessage: error ? (error.message || error.title) : null,
            errorDetails,
          });
        }
      }
    }
  } catch (error) {
    console.error('WhatsApp webhook processing failed:', error.message);
    res.sendStatus(500);
    return;
  }

  res.sendStatus(200);
});

