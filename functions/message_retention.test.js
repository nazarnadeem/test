const test = require('node:test');
const assert = require('node:assert/strict');
const {
  RETENTION_INTERVAL_DAYS,
  RETENTION_KEEP_DAYS,
  retentionCutoff,
  isOlderThanRetention,
  keptLegacyNotifications,
} = require('./message_retention');

test('cleanup runs every 20 days and keeps the latest 5 days', () => {
  assert.equal(RETENTION_INTERVAL_DAYS, 20);
  assert.equal(RETENTION_KEEP_DAYS, 5);
});

test('cutoff is the start of the Kolkata day five days ago', () => {
  const now = new Date('2026-10-21T10:00:00.000Z');
  const cutoff = retentionCutoff(now);
  assert.equal(cutoff.toISOString(), '2026-10-15T18:30:00.000Z');
  assert.equal(isOlderThanRetention('2026-10-15T18:29:59.000Z', cutoff), true);
  assert.equal(isOlderThanRetention('2026-10-15T18:30:00.000Z', cutoff), false);
  assert.equal(isOlderThanRetention(null, cutoff), false);
});

test('legacy inbox rows older than the cutoff are dropped', () => {
  const cutoff = retentionCutoff(new Date('2026-10-21T10:00:00.000Z'));
  const kept = keptLegacyNotifications([
    { id: 'old', title: 'Old', createdAt: '2026-10-01T00:00:00.000Z' },
    { id: 'new', title: 'New', createdAt: '2026-10-20T00:00:00.000Z' },
    { id: 'undated', title: 'Undated' },
  ], cutoff);
  assert.deepEqual(kept.map((entry) => entry.id), ['new', 'undated']);
});
