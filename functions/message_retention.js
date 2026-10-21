/** How often the cleanup job is scheduled. */
const RETENTION_INTERVAL_DAYS = 20;

/** Records from this many days before the current day are kept. */
const RETENTION_KEEP_DAYS = 5;

const KOLKATA_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

/**
 * Start of the Asia/Kolkata day that is five days before `now`.
 * Anything earlier than this is removed.
 */
function retentionCutoff(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const year = Number(parts.find((part) => part.type === 'year').value);
  const month = Number(parts.find((part) => part.type === 'month').value);
  const day = Number(parts.find((part) => part.type === 'day').value);
  const startOfTodayUtc = Date.UTC(year, month - 1, day) - KOLKATA_OFFSET_MS;
  return new Date(startOfTodayUtc - RETENTION_KEEP_DAYS * 24 * 60 * 60 * 1000);
}

/** Reads a Firestore timestamp, ISO string, or millis value. */
function readStoredTime(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') {
    const date = value.toDate();
    return Number.isNaN(date.getTime()) ? null : date;
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === 'string' || typeof value === 'number') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }
  if (typeof value === 'object' && typeof value._seconds === 'number') {
    return new Date(value._seconds * 1000);
  }
  return null;
}

/** True when a stored time is before the retention cutoff. */
function isOlderThanRetention(value, cutoff) {
  const time = readStoredTime(value);
  if (!time) return false;
  return time.getTime() < cutoff.getTime();
}

/** Legacy inbox rows that are still inside the five-day window. */
function keptLegacyNotifications(entries, cutoff) {
  if (!Array.isArray(entries)) return [];
  return entries.filter((entry) => !isOlderThanRetention(entry && entry.createdAt, cutoff));
}

/**
 * Deletes query results in batches. Repeats until the query is empty.
 * @param {FirebaseFirestore.Query} query
 */
async function deleteQueryBatches(query, batchSize) {
  let deleted = 0;
  while (true) {
    const snapshot = await query.limit(batchSize).get();
    if (snapshot.empty) break;
    const batch = query.firestore.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snapshot.size;
    if (snapshot.size < batchSize) break;
  }
  return deleted;
}

/**
 * Removes WhatsApp delivery rows and saved push notifications older than five days.
 */
async function purgeExpiredMessages({ db, admin, now = new Date(), batchSize = 400 }) {
  const cutoff = retentionCutoff(now);
  const cutoffStamp = admin.firestore.Timestamp.fromDate(cutoff);
  const cutoffIso = cutoff.toISOString();
  const summary = {
    cutoff: cutoffIso,
    whatsappDeleted: 0,
    inboxDeleted: 0,
    queueDeleted: 0,
    legacyRemoved: 0,
  };

  summary.whatsappDeleted = await deleteQueryBatches(
    db.collection('whatsapp_message_logs').where('updatedAt', '<', cutoffStamp),
    batchSize,
  );

  summary.queueDeleted = await deleteQueryBatches(
    db.collection('notifications_queue').where('createdAt', '<', cutoffStamp),
    batchSize,
  );

  let cursor = null;
  while (true) {
    let users = db.collection('users').orderBy(admin.firestore.FieldPath.documentId()).limit(100);
    if (cursor) users = users.startAfter(cursor);
    const page = await users.get();
    if (page.empty) break;

    for (const user of page.docs) {
      const inbox = user.ref.collection('notifications');
      summary.inboxDeleted += await deleteQueryBatches(
        inbox.where('createdAt', '<', cutoffIso),
        batchSize,
      );
      summary.inboxDeleted += await deleteQueryBatches(
        inbox.where('createdAt', '<', cutoffStamp),
        batchSize,
      );

      const legacy = user.get('platformNotifications');
      if (!Array.isArray(legacy) || legacy.length === 0) continue;
      const kept = keptLegacyNotifications(legacy, cutoff);
      if (kept.length === legacy.length) continue;
      await user.ref.update({
        platformNotifications: kept.length ? kept : admin.firestore.FieldValue.delete(),
      });
      summary.legacyRemoved += legacy.length - kept.length;
    }

    cursor = page.docs[page.docs.length - 1];
    if (page.size < 100) break;
  }

  return summary;
}

module.exports = {
  RETENTION_INTERVAL_DAYS,
  RETENTION_KEEP_DAYS,
  retentionCutoff,
  readStoredTime,
  isOlderThanRetention,
  keptLegacyNotifications,
  purgeExpiredMessages,
};
