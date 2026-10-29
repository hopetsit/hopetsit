// 2910 (BOB) — relance de paiement : réservation choisie mais non payée → notification « booking_accepted »
// à +1 h, puis +24 h, 2 au maximum ; jamais si payée, annulée, service commencé, compte test, ou la nuit.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const SENT = [];
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async (p) => { SENT.push(p); return { ok: true }; }),
  sendEmailOnly: jest.fn(async () => ({ sent: true })),
}));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Booking; let svc;
const H = 3600000;
const PASS = 'MotDePasse2910!';
// 12 h UTC = 13 h Paris / 8 h New York : jour à Paris.
const NOON = new Date('2026-11-03T12:00:00Z');
let n = 0;
async function booking(extra = {}, ownerExtra = {}) {
  n += 1;
  const o = await Owner.create({ name: 'O', email: `pr2910_${n}@example.org`, password: PASS, ...ownerExtra });
  const s = await Sitter.create({ name: 'S', email: `prs2910_${n}@example.org`, password: PASS });
  const b = await Booking.create({
    ownerId: o._id, sitterId: s._id, status: 'agreed', paymentStatus: 'pending',
    date: new Date('2026-12-20'), timeSlot: '09:00', startDate: '2026-12-20', serviceDate: new Date('2026-12-20'), agreedAt: new Date(NOON.getTime() - 2 * H),
    pricing: { basePrice: 215, totalPrice: 258, commission: 43, netPayout: 215, currency: 'EUR' }, ...extra,
  });
  return b;
}

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Booking = require('../src/models/Booking');
  await Promise.all([Owner.init(), Sitter.init(), Booking.init()]);
  svc = require('../src/services/paymentReminder2910');
});
afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });
beforeEach(() => { SENT.length = 0; });

test('r1 à +1 h, puis r2 à +24 h, jamais une 3e', async () => {
  const b = await booking();
  let r = await svc.runPaymentReminders({ now: NOON });
  expect(r.sent.map((x) => x.slot)).toEqual(['r1']);
  expect(SENT[0]).toMatchObject({ role: 'owner', type: 'booking_accepted', data: { bookingId: String(b._id), amount: 258 } });
  r = await svc.runPaymentReminders({ now: new Date(NOON.getTime() + 2 * H) });
  expect(r.sent).toHaveLength(0);
  r = await svc.runPaymentReminders({ now: new Date(NOON.getTime() + 25 * H) });
  expect(r.sent.map((x) => x.slot)).toEqual(['r2']);
  r = await svc.runPaymentReminders({ now: new Date(NOON.getTime() + 60 * H) });
  expect(r.sent).toHaveLength(0);
  const d = await Booking.findById(b._id).lean();
  expect(d.paymentReminder2910.sent).toHaveLength(2);
});

test('rien si trop tôt, payée, annulée, service commencé, compte test, ou la nuit', async () => {
  await booking({ agreedAt: new Date(NOON.getTime() - 10 * 60000) });            // 10 min : trop tôt
  await booking({ status: 'paid', paymentStatus: 'paid' });
  await booking({ status: 'cancelled', paymentStatus: 'cancelled' });
  await booking({ date: new Date('2026-11-01'), startDate: '2026-11-01', serviceDate: new Date('2026-11-01') });  // déjà commencé
  await booking({}, { email: 'dadaciao84+testowner@gmail.com' });
  const r = await svc.runPaymentReminders({ now: NOON });
  expect(r.sent).toHaveLength(0);
  expect(r.skipped.not_due).toBeGreaterThanOrEqual(1);
  expect(r.skipped).toMatchObject({ service_started: 1, test: 1 });
  const night = await booking();
  const r2 = await svc.runPaymentReminders({ now: new Date('2026-11-03T23:00:00Z') }); // 0 h Paris
  expect(r2.sent).toHaveLength(0);
  expect(r2.skipped.night).toBeGreaterThanOrEqual(1);
  expect(((await Booking.findById(night._id).lean()).paymentReminder2910 || {}).sent || []).toHaveLength(0);
});

test('simulation (dryRun) : rien n’est envoyé ni écrit', async () => {
  const b = await booking();
  const r = await svc.runPaymentReminders({ now: NOON, dryRun: true });
  expect(r.wouldSend.some((x) => x.bookingId === String(b._id))).toBe(true);
  expect(SENT).toHaveLength(0);
  expect(((await Booking.findById(b._id).lean()).paymentReminder2910 || {}).sent || []).toHaveLength(0);
});
