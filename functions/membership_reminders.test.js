const test = require('node:test');
const assert = require('node:assert/strict');
const {
  daysUntilExpiry,
  milestoneForDays,
  resolveTimeZone,
  digestPushCopy,
  processMemberReminder,
  sendGymDigestPush,
} = require('./membership_reminders');

const ZONE = 'Asia/Kolkata';
const EXPIRY = '2026-10-14T00:00:00.000';

function atKolkata(year, month, day) {
  return new Date(Date.UTC(year, month - 1, day, 7, 30, 0));
}

test('uses the gym calendar for the six reminder days', () => {
  const cases = [
    ['2026-10-07', 7, 'before_7'],
    ['2026-10-11', 3, 'before_3'],
    ['2026-10-13', 1, 'before_1'],
    ['2026-10-14', 0, null],
    ['2026-10-15', -1, 'after_1'],
    ['2026-10-17', -3, 'after_3'],
    ['2026-10-21', -7, 'after_7'],
    ['2026-10-08', 6, null],
  ];

  for (const [day, expectedDays, milestoneId] of cases) {
    const [year, month, date] = day.split('-').map(Number);
    const days = daysUntilExpiry(EXPIRY, atKolkata(year, month, date), ZONE);
    assert.equal(days, expectedDays, day);
    const milestone = milestoneForDays(days);
    assert.equal(milestone ? milestone.id : null, milestoneId, day);
  }
});

test('converts a UTC instant into the Kolkata expiry date', () => {
  const instant = new Date('2026-10-13T18:30:00.000Z');
  const days = daysUntilExpiry(instant, atKolkata(2026, 10, 7), ZONE);
  assert.equal(days, 7);
  assert.equal(milestoneForDays(days).whatsAppKind, 'membership_expiry');
  assert.equal(milestoneForDays(days).dayCount, '7');
});

test('falls back to Asia/Kolkata for a missing or invalid timezone', () => {
  assert.equal(resolveTimeZone(''), 'Asia/Kolkata');
  assert.equal(resolveTimeZone('Not/AZone'), 'Asia/Kolkata');
  assert.equal(resolveTimeZone('Asia/Dubai'), 'Asia/Dubai');
});

test('writes one general push for a mix of expiring and expired memberships', () => {
  const mixed = digestPushCopy(2, 2);
  assert.equal(mixed.title, 'Membership reminders');
  assert.equal(mixed.body, '2 memberships are expiring soon and 2 have expired.');
  assert.equal(digestPushCopy(1, 0).body, '1 membership is expiring soon.');
  assert.equal(digestPushCopy(0, 4).body, '4 memberships have expired.');
  assert.equal(digestPushCopy(3, 1).body, '3 memberships are expiring soon and 1 has expired.');
});

function memoryDb(initial = {}) {
  const docs = new Map(Object.entries(initial));
  const refFor = (path) => ({
    path,
    async get() {
      const data = docs.get(path);
      return {
        exists: data != null,
        id: path.split('/').pop(),
        data: () => data,
        get: (field) => (data ? data[field] : undefined),
      };
    },
    async set(value, options) {
      const current = options && options.merge ? (docs.get(path) || {}) : {};
      docs.set(path, Object.assign({}, current, value));
    },
  });

  return {
    docs,
    async runTransaction(work) {
      const transaction = {
        async get(ref) {
          return ref.get();
        },
        set(ref, value, options) {
          return ref.set(value, options);
        },
      };
      return work(transaction);
    },
    collection(name) {
      return {
        doc(id) {
          return refFor(`${name}/${id}`);
        },
      };
    },
  };
}

test('a WhatsApp reminder is sent once for that day, and the next reminder day sends again', async () => {
  const db = memoryDb();
  let whatsAppCalls = 0;
  const tenant = {
    id: 'gym1',
    gymName: 'GCRM One',
    timeZone: ZONE,
    adminId: 'admin1',
    ownerId: 'admin1',
  };
  const member = {
    firstName: 'Asha',
    lastName: 'Khan',
    phone: '9876543210',
    expiryDate: EXPIRY,
    isActive: true,
    isLifetimeFree: false,
  };

  const first = await processMemberReminder({
    db,
    tenant,
    memberId: 'member1',
    member,
    now: atKolkata(2026, 10, 7),
    deliverWhatsApp: async (payload) => {
      whatsAppCalls += 1;
      assert.equal(payload.kind, 'membership_expiry');
      assert.equal(payload.dayCount, '7');
      return { ok: true };
    },
  });

  const repeat = await processMemberReminder({
    db,
    tenant,
    memberId: 'member1',
    member,
    now: atKolkata(2026, 10, 7),
    deliverWhatsApp: async () => {
      whatsAppCalls += 1;
      return { ok: true };
    },
  });

  const later = await processMemberReminder({
    db,
    tenant,
    memberId: 'member1',
    member,
    now: atKolkata(2026, 10, 15),
    deliverWhatsApp: async (payload) => {
      whatsAppCalls += 1;
      assert.equal(payload.kind, 'membership_expired');
      assert.equal(payload.dayCount, '1');
      return { ok: true };
    },
  });

  assert.equal(first.whatsapp, 'sent');
  assert.equal(repeat.whatsapp, 'already_done');
  assert.equal(later.whatsapp, 'sent');
  assert.equal(whatsAppCalls, 2);
});

test('several reminders on the same day produce one summary push', async () => {
  const db = memoryDb();
  let pushCalls = 0;
  const tenant = { id: 'gym1', gymName: 'GCRM One', timeZone: ZONE };
  const now = atKolkata(2026, 10, 7);

  const first = await sendGymDigestPush({
    db,
    tenant,
    now,
    expiringSoon: 2,
    expired: 2,
    deliverPush: async (payload) => {
      pushCalls += 1;
      assert.equal(payload.copy.title, 'Membership reminders');
      assert.equal(payload.copy.body, '2 memberships are expiring soon and 2 have expired.');
      return { ok: true };
    },
  });

  const second = await sendGymDigestPush({
    db,
    tenant,
    now,
    expiringSoon: 2,
    expired: 2,
    deliverPush: async () => {
      pushCalls += 1;
      return { ok: true };
    },
  });

  assert.equal(first, 'sent');
  assert.equal(second, 'already_done');
  assert.equal(pushCalls, 1);
});
