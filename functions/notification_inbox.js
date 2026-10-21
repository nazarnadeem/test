/** Inbox pages stay at 10 documents so a screen never reads the whole history. */
const INBOX_PAGE_SIZE = 10;

function notificationDocId(id) {
  return String(id || '').trim().replace(/\//g, '_');
}

/** Membership reminder pushes are delivered only. They are not saved. */
function isMembershipReminderNotification(entry) {
  if (!entry || typeof entry !== 'object') return false;
  const type = String(entry.type || '');
  if (type === 'membership_digest' || type === 'membership_expiry') return true;
  if (String(entry.openTab || '') === 'members') return true;
  if (String(entry.title || '').trim() === 'Membership reminders') return true;
  const id = String(entry.id || '');
  return id.includes('__digest__daily__');
}

/**
 * One inbox document. Returns null when the entry cannot be stored.
 * createdAt stays an ISO string so pages can continue with startAfter.
 */
function normalizeInboxEntry(entry, fallbackId) {
  if (!entry || typeof entry !== 'object') return null;
  if (isMembershipReminderNotification(entry)) return null;
  const id = notificationDocId(entry.id || fallbackId);
  const title = String(entry.title || '').trim();
  if (!id || !title) return null;
  const normalized = {
    id,
    title,
    body: String(entry.body || ''),
    createdAt: entry.createdAt ? String(entry.createdAt) : new Date().toISOString(),
    targetAudience: String(entry.targetAudience || 'specific_gym'),
    targetTenantId: String(entry.targetTenantId || ''),
    sound: String(entry.sound || 'default'),
  };
  if (entry.openTab) normalized.openTab = String(entry.openTab);
  return normalized;
}

/** Copies the old user-document array into individual notification documents. */
function legacyNotificationDocs(entries) {
  if (!Array.isArray(entries)) return [];
  const docs = [];
  const seen = new Set();
  entries.forEach((entry) => {
    const normalized = normalizeInboxEntry(entry);
    if (!normalized || seen.has(normalized.id)) return;
    seen.add(normalized.id);
    docs.push(normalized);
  });
  return docs;
}

/** Page payload for the inbox callable. The query itself is already limited to 10. */
function inboxPageResult(items) {
  const page = (items || []).slice(0, INBOX_PAGE_SIZE);
  const last = page.length ? page[page.length - 1] : null;
  const cursor = last && last.createdAt ? String(last.createdAt) : null;
  return {
    items: page,
    hasMore: (items || []).length >= INBOX_PAGE_SIZE,
    nextCursor: cursor,
  };
}

module.exports = {
  INBOX_PAGE_SIZE,
  notificationDocId,
  isMembershipReminderNotification,
  normalizeInboxEntry,
  legacyNotificationDocs,
  inboxPageResult,
};
