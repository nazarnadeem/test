/**
 * Daily membership expiry reminders.
 * Calendar math uses the gym timezone and falls back to Asia/Kolkata.
 * WhatsApp is sent on every reminder day for each member.
 * Gym admins get one summary push per gym for all members reminded that day.
 */

const DEFAULT_TIME_ZONE = 'Asia/Kolkata';
const SENDING_LEASE_MS = 15 * 60 * 1000;

const REMINDER_MILESTONES = [
  { id: 'before_7', daysUntilExpiry: 7, whatsAppKind: 'membership_expiry', dayCount: '7' },
  { id: 'before_3', daysUntilExpiry: 3, whatsAppKind: 'membership_expiry', dayCount: '3' },
  { id: 'before_1', daysUntilExpiry: 1, whatsAppKind: 'membership_expiry', dayCount: '1' },
  { id: 'after_1', daysUntilExpiry: -1, whatsAppKind: 'membership_expired', dayCount: '1' },
  { id: 'after_3', daysUntilExpiry: -3, whatsAppKind: 'membership_expired', dayCount: '3' },
  { id: 'after_7', daysUntilExpiry: -7, whatsAppKind: 'membership_expired', dayCount: '7' },
];

const MILESTONE_BY_DAYS = new Map(
  REMINDER_MILESTONES.map((milestone) => [milestone.daysUntilExpiry, milestone]),
);

const GYM_ADMIN_ROLES = new Set([
  'gymowner',
  'gym_owner',
  'gym_admin',
  'gymadmin',
  'owner',
  'admin',
]);

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function resolveTimeZone(value) {
  const zone = String(value || '').trim() || DEFAULT_TIME_ZONE;
  try {
    Intl.DateTimeFormat('en-US', { timeZone: zone }).format(new Date());
    return zone;
  } catch (error) {
    return DEFAULT_TIME_ZONE;
  }
}

function calendarParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const map = {};
  parts.forEach((part) => {
    map[part.type] = part.value;
  });
  return {
    year: Number(map.year),
    month: Number(map.month),
    day: Number(map.day),
  };
}

function toInstant(value) {
  if (value == null || value === '') return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === 'function') {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  if (typeof value === 'number') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  if (typeof value === 'object') {
    const seconds = value._seconds != null ? value._seconds : value.seconds;
    if (typeof seconds === 'number') return new Date(seconds * 1000);
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (/(?:[zZ]|[+-]\d{2}:\d{2})$/.test(trimmed)) {
      const parsed = new Date(trimmed);
      return Number.isNaN(parsed.getTime()) ? null : parsed;
    }
  }
  return null;
}

/**
 * Calendar day of a stored expiry, as UTC midnight of that gym-local date.
 * Strings saved without a timezone keep the date the gym picked.
 * Instants are converted into the gym timezone.
 */
function calendarDayUtc(value, timeZone) {
  const zone = resolveTimeZone(timeZone);
  if (typeof value === 'string') {
    const trimmed = value.trim();
    const match = trimmed.match(/^(\d{4})-(\d{2})-(\d{2})(?:[T\s].*)?$/);
    const hasZone = /(?:[zZ]|[+-]\d{2}:\d{2})$/.test(trimmed);
    if (match && !hasZone) {
      return Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    }
  }
  const instant = toInstant(value);
  if (!instant) return null;
  const parts = calendarParts(instant, zone);
  return Date.UTC(parts.year, parts.month - 1, parts.day);
}

function daysUntilExpiry(expiryValue, now, timeZone) {
  const zone = resolveTimeZone(timeZone);
  const expiryDay = calendarDayUtc(expiryValue, zone);
  if (expiryDay == null || !(now instanceof Date)) return null;
  const today = calendarDayUtc(now.toISOString(), zone);
  return Math.round((expiryDay - today) / 86400000);
}

function milestoneForDays(daysUntil) {
  return MILESTONE_BY_DAYS.get(daysUntil) || null;
}

function formatCalendarDay(calendarUtc) {
  const date = new Date(calendarUtc);
  return `${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]} ${date.getUTCFullYear()}`;
}

function memberDisplayName(data) {
  const first = String((data && data.firstName) || '').trim();
  const last = String((data && data.lastName) || '').trim();
  const combined = `${first} ${last}`.trim();
  if (combined) return combined;
  const fullName = String((data && data.fullName) || '').trim();
  return fullName || 'Member';
}

function digestPushCopy(expiringSoon, expired) {
  const expiringLabel = expiringSoon === 1
    ? '1 membership is expiring soon'
    : `${expiringSoon} memberships are expiring soon`;
  const expiredLabel = expired === 1
    ? '1 membership has expired'
    : `${expired} memberships have expired`;
  let body;
  if (expiringSoon > 0 && expired > 0) {
    body = `${expiringLabel} and ${expired === 1 ? '1 has expired' : `${expired} have expired`}.`;
  } else if (expired > 0) {
    body = `${expiredLabel}.`;
  } else {
    body = `${expiringLabel}.`;
  }
  return {
    title: 'Membership reminders',
    body,
  };
}

function reminderDocId(tenantId, memberId, milestoneId, expiryKey) {
  return [tenantId, memberId, milestoneId, expiryKey]
    .map((part) => String(part || '').replace(/[/\s]/g, '_'))
    .join('__');
}

function digestDocId(tenantId, dayKey) {
  return reminderDocId(tenantId, 'digest', 'daily', dayKey);
}

function isEligibleTenant(data) {
  return String((data && data.status) || 'active') !== 'suspended';
}

function isEligibleMember(data) {
  if (!data || data.isLifetimeFree === true) return false;
  if (data.isActive === false) return false;
  return true;
}

async function loadGymAdminRecipients(db, tenant) {
  const userIds = new Set();
  const tokens = new Set();
  const adminIds = new Set([tenant.adminId, tenant.ownerId].filter(Boolean).map(String));

  const addUser = (id, data) => {
    if (!data) return;
    const role = String(data.role || '').toLowerCase().trim();
    if (!adminIds.has(String(id)) && !GYM_ADMIN_ROLES.has(role)) return;
    if (id) userIds.add(String(id));
    const token = typeof data.fcmToken === 'string' ? data.fcmToken.trim() : '';
    if (token) tokens.add(token);
  };

  const snapshot = await db.collection('users').where('tenantId', '==', tenant.id).get();
  snapshot.forEach((doc) => addUser(doc.id, doc.data()));

  for (const uid of adminIds) {
    if (userIds.has(uid)) continue;
    const userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) addUser(userDoc.id, userDoc.data());
  }

  return { userIds: Array.from(userIds), tokens: Array.from(tokens) };
}

async function acquireChannel(db, ref, channel, details, nowMs) {
  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const current = snap.exists ? snap.data() : {};
    const status = current[`${channel}Status`];
    const startedAt = Number(current[`${channel}StartedAt`] || 0);
    if (status === 'sent' || status === 'skipped') return false;
    if (status === 'sending' && nowMs - startedAt < SENDING_LEASE_MS) return false;
    transaction.set(ref, Object.assign({}, details, {
      [`${channel}Status`]: 'sending',
      [`${channel}StartedAt`]: nowMs,
    }), { merge: true });
    return true;
  });
}

async function finishChannel(ref, channel, status, error) {
  const update = { [`${channel}Status`]: status };
  if (error) update[`${channel}Error`] = String(error).slice(0, 500);
  await ref.set(update, { merge: true });
}

function documentIdOrder() {
  return require('firebase-admin').firestore.FieldPath.documentId();
}

async function eachMember(db, tenantId, visitor) {
  let last = null;
  for (;;) {
    let query = db.collection('tenants').doc(tenantId).collection('members')
      .orderBy(documentIdOrder())
      .limit(400);
    if (last) query = query.startAfter(last);
    const snapshot = await query.get();
    if (snapshot.empty) return;
    for (const doc of snapshot.docs) {
      await visitor(doc);
    }
    last = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < 400) return;
  }
}

async function processMemberReminder({
  db,
  tenant,
  memberId,
  member,
  now,
  deliverWhatsApp,
}) {
  if (!isEligibleMember(member)) return null;
  const timeZone = tenant.timeZone;
  const days = daysUntilExpiry(member.expiryDate, now, timeZone);
  const milestone = milestoneForDays(days);
  if (!milestone) return null;

  const expiryDay = calendarDayUtc(member.expiryDate, timeZone);
  const expiryKey = new Date(expiryDay).toISOString().slice(0, 10);
  const memberName = memberDisplayName(member);
  const gymName = tenant.gymName || 'Gym';
  const logId = reminderDocId(tenant.id, memberId, milestone.id, expiryKey);
  const ref = db.collection('membership_reminder_logs').doc(logId);
  const details = {
    tenantId: tenant.id,
    memberId,
    memberName,
    milestone: milestone.id,
    daysUntilExpiry: days,
    expiryDate: expiryKey,
    timeZone,
  };
  const nowMs = now.getTime();
  const whatsAppClaimed = await acquireChannel(db, ref, 'whatsapp', details, nowMs);
  if (!whatsAppClaimed) {
    return { logId, milestone: milestone.id, daysUntilExpiry: days, whatsapp: 'already_done' };
  }

  try {
    const result = await deliverWhatsApp({
      tenantId: tenant.id,
      phone: member.phone,
      memberName,
      gymName,
      kind: milestone.whatsAppKind,
      dayCount: milestone.dayCount,
      memberId,
    });
    if (result && result.skipped) {
      await finishChannel(ref, 'whatsapp', 'skipped', result.error);
      return { logId, milestone: milestone.id, daysUntilExpiry: days, whatsapp: 'skipped' };
    }
    if (!result || result.ok === false) {
      await finishChannel(ref, 'whatsapp', 'failed', (result && result.error) || 'WhatsApp failed');
      return { logId, milestone: milestone.id, daysUntilExpiry: days, whatsapp: 'failed' };
    }
    await finishChannel(ref, 'whatsapp', 'sent');
    return { logId, milestone: milestone.id, daysUntilExpiry: days, whatsapp: 'sent' };
  } catch (error) {
    await finishChannel(ref, 'whatsapp', 'failed', error.message);
    return { logId, milestone: milestone.id, daysUntilExpiry: days, whatsapp: 'failed' };
  }
}

async function sendGymDigestPush({
  db,
  tenant,
  now,
  expiringSoon,
  expired,
  deliverPush,
}) {
  if (expiringSoon + expired <= 0) return null;
  const timeZone = tenant.timeZone;
  const dayKey = new Date(calendarDayUtc(now.toISOString(), timeZone)).toISOString().slice(0, 10);
  const copy = digestPushCopy(expiringSoon, expired);
  const createdAt = new Date(calendarDayUtc(now.toISOString(), timeZone) + (7.5 * 60 * 60 * 1000)).toISOString();
  const logId = digestDocId(tenant.id, dayKey);
  const ref = db.collection('membership_reminder_logs').doc(logId);
  const claimed = await acquireChannel(db, ref, 'push', {
    tenantId: tenant.id,
    kind: 'daily_digest',
    expiringSoon,
    expired,
    dayKey,
    timeZone,
  }, now.getTime());
  if (!claimed) return 'already_done';

  try {
    const result = await deliverPush({
      tenant,
      copy,
      logId,
      createdAt,
      expiringSoon,
      expired,
    });
    if (result && result.skipped) {
      await finishChannel(ref, 'push', 'skipped', result.error);
      return 'skipped';
    }
    if (!result || result.ok === false) {
      await finishChannel(ref, 'push', 'failed', (result && result.error) || 'Push failed');
      return 'failed';
    }
    await finishChannel(ref, 'push', 'sent');
    return 'sent';
  } catch (error) {
    await finishChannel(ref, 'push', 'failed', error.message);
    return 'failed';
  }
}

async function runMembershipExpiryReminders({
  db,
  now = new Date(),
  deliverPush,
  deliverWhatsApp,
}) {
  const summary = { checked: 0, due: 0, pushFailed: 0, whatsappFailed: 0 };
  const tenants = await db.collection('tenants').get();

  for (const tenantDoc of tenants.docs) {
    const tenantData = tenantDoc.data() || {};
    if (!isEligibleTenant(tenantData)) continue;
    const tenant = {
      id: tenantDoc.id,
      gymName: String(tenantData.gymName || 'Gym').trim() || 'Gym',
      timeZone: resolveTimeZone(tenantData.timezone || tenantData.timeZone),
      adminId: tenantData.adminId || null,
      ownerId: tenantData.ownerId || null,
      recipients: null,
    };
    let expiringSoon = 0;
    let expired = 0;

    await eachMember(db, tenant.id, async (memberDoc) => {
      summary.checked += 1;
      const member = memberDoc.data() || {};
      if (!isEligibleMember(member)) return;
      if (!milestoneForDays(daysUntilExpiry(member.expiryDate, now, tenant.timeZone))) return;
      const outcome = await processMemberReminder({
        db,
        tenant,
        memberId: memberDoc.id,
        member,
        now,
        deliverWhatsApp,
      });
      if (!outcome) return;
      summary.due += 1;
      if (outcome.whatsapp === 'failed') summary.whatsappFailed += 1;
      if (outcome.daysUntilExpiry > 0) expiringSoon += 1;
      else if (outcome.daysUntilExpiry < 0) expired += 1;
    });

    if (expiringSoon + expired > 0) {
      tenant.recipients = await loadGymAdminRecipients(db, tenant);
      const push = await sendGymDigestPush({
        db,
        tenant,
        now,
        expiringSoon,
        expired,
        deliverPush: (payload) => deliverPush(Object.assign({}, payload, {
          userIds: tenant.recipients.userIds,
          tokens: tenant.recipients.tokens,
        })),
      });
      if (push === 'failed') summary.pushFailed += 1;
    }
  }

  console.log('Membership expiry reminders finished', summary);
  return summary;
}

module.exports = {
  DEFAULT_TIME_ZONE,
  REMINDER_MILESTONES,
  resolveTimeZone,
  calendarDayUtc,
  daysUntilExpiry,
  milestoneForDays,
  formatCalendarDay,
  memberDisplayName,
  digestPushCopy,
  reminderDocId,
  isEligibleMember,
  isEligibleTenant,
  loadGymAdminRecipients,
  processMemberReminder,
  sendGymDigestPush,
  runMembershipExpiryReminders,
};
