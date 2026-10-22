const test = require('node:test');
const assert = require('node:assert/strict');
const {
  INBOX_PAGE_SIZE,
  normalizeInboxEntry,
  legacyNotificationDocs,
  inboxPageResult,
  isMembershipReminderNotification,
} = require('./notification_inbox');

test('inbox page size is 10', () => {
  assert.equal(INBOX_PAGE_SIZE, 10);
});

test('normalizes a custom notification and drops invalid ones', () => {
  const entry = normalizeInboxEntry({
    id: 'broadcast/1',
    title: 'Holiday hours',
    body: 'The gym closes at 6 PM.',
    createdAt: '2026-10-21T07:30:00.000Z',
    targetAudience: 'all',
  });
  assert.equal(entry.id, 'broadcast_1');
  assert.equal(entry.title, 'Holiday hours');
  assert.equal(entry.createdAt, '2026-10-21T07:30:00.000Z');
  assert.equal(normalizeInboxEntry({ id: 'x' }), null);
  assert.equal(normalizeInboxEntry(null), null);
});

test('membership reminders are never stored', () => {
  assert.equal(isMembershipReminderNotification({
    title: 'Membership reminders',
    openTab: 'members',
  }), true);
  assert.equal(normalizeInboxEntry({
    id: 'gym__digest__daily__2026-10-21',
    title: 'Membership reminders',
    body: '2 memberships are expiring soon.',
    openTab: 'members',
  }), null);
  const docs = legacyNotificationDocs([
    { id: 'custom-1', title: 'Holiday hours' },
    { id: 'gym__digest__daily__2026-10-21', title: 'Membership reminders', openTab: 'members' },
  ]);
  assert.deepEqual(docs.map((doc) => doc.id), ['custom-1']);
});

test('legacy array becomes one document per notification', () => {
  const docs = legacyNotificationDocs([
    { id: 'a', title: 'First', createdAt: '2026-10-20T00:00:00.000Z' },
    { id: 'a', title: 'Duplicate' },
    { title: 'Missing id' },
    { id: 'b', title: 'Second', createdAt: '2026-10-21T00:00:00.000Z' },
  ]);
  assert.deepEqual(docs.map((doc) => doc.id), ['a', 'b']);
});

test('a full page reports another page and keeps the last timestamp', () => {
  const items = Array.from({ length: 10 }, (_, index) => ({
    id: `n${index}`,
    title: `Note ${index}`,
    createdAt: `2026-10-21T00:00:0${index}.000Z`,
  }));
  const page = inboxPageResult(items);
  assert.equal(page.items.length, 10);
  assert.equal(page.hasMore, true);
  assert.equal(page.nextCursor, items[9].createdAt);

  const shortPage = inboxPageResult(items.slice(0, 4));
  assert.equal(shortPage.hasMore, false);
  assert.equal(shortPage.nextCursor, items[3].createdAt);
});
