// 607b (ZOE, 01/10/2026) — décision de BOB : un parrain dont l'app active est
// iOS ≥ 607 ne reçoit plus l'annonce « -10 % parrainage » (REFERRAL_CREDITED :
// push, cloche et e-mail partent tous par sendNotification). Les autres
// comptes : inchangé. Plateforme inconnue : inchangé (la notification part).
// Vraie base Mongo en mémoire, vrai referralService ; seuls l'envoi et le
// compteur de réservations sont simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockSent = [];
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async (n) => { mockSent.push(n); return { ok: true }; }),
}));
jest.mock('../src/models/Booking', () => ({ countDocuments: jest.fn(async () => 1) }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const {
  latestKnownClient, isIosNoReferralClient,
} = require('../src/utils/iosReferralNotice607');

let mongo; let Owner; let Sitter; let Walker; let Referral; let ActivityEvent; let svc;
let n = 0;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Referral = require('../src/models/Referral');
  ActivityEvent = require('../src/models/ActivityEvent');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Referral.init()]);
  svc = require('../src/services/referralService');
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(() => { mockSent.length = 0; });

const ago = (min) => new Date(Date.now() - min * 60000);

/** Crée un parrain (owner) + un filleul + le parrainage en attente. */
async function scenario({ devices = [], siblingSitterDevices = null, activity = [] } = {}) {
  n += 1;
  const email = `parrain607b_${n}@example.test`;
  const referrer = await Owner.create({ name: `Parrain ${n}`, email, password: 'MotDePasse607!' });
  if (devices.length) await Owner.collection.updateOne({ _id: referrer._id }, { $set: { fcmDevices: devices } });
  if (siblingSitterDevices) {
    const s = await Sitter.create({ name: `Parrain ${n}`, email, password: 'MotDePasse607!' });
    await Sitter.collection.updateOne({ _id: s._id }, { $set: { fcmDevices: siblingSitterDevices } });
  }
  for (const a of activity) await ActivityEvent.create({ userId: String(referrer._id), role: 'owner', ...a });
  const referred = await Walker.create({ name: `Filleul ${n}`, email: `filleul607b_${n}@example.test`, password: 'MotDePasse607!' });
  await Referral.create({
    referrerId: referrer._id, referrerRole: 'owner',
    referredUserId: referred._id, referredRole: 'walker', status: 'pending', creditAwarded: false,
  });
  await svc.onReferredFirstBookingCompleted({ bookingId: 'b1', userId: referred._id, role: 'owner' });
  const ref = await Referral.findOne({ referredUserId: referred._id }).lean();
  return { referrer, ref, sent: mockSent.filter((x) => x.type === 'REFERRAL_CREDITED') };
}

describe('annonce -10 % parrainage selon la dernière app connue du parrain', () => {
  test('iPhone, app 607 → aucune annonce (récompense quand même enregistrée)', async () => {
    const { ref, sent } = await scenario({ devices: [{ token: 't1', platform: 'ios', appBuild: 607, at: ago(5) }] });
    expect(sent).toHaveLength(0);
    expect(ref.status).toBe('completed');
    expect(ref.creditAwarded).toBe(true);
  });

  test('iPhone, app 606 → annonce envoyée (inchangé)', async () => {
    const { sent, referrer } = await scenario({ devices: [{ token: 't1', platform: 'ios', appBuild: 606, at: ago(5) }] });
    expect(sent).toHaveLength(1);
    expect(sent[0]).toMatchObject({ userId: String(referrer._id), role: 'owner', type: 'REFERRAL_CREDITED' });
  });

  test('Android 610 → annonce envoyée (inchangé)', async () => {
    const { sent } = await scenario({ devices: [{ token: 't1', platform: 'android', appBuild: 610, at: ago(5) }] });
    expect(sent).toHaveLength(1);
  });

  test('plateforme inconnue (aucune trace) → annonce envoyée (comportement actuel)', async () => {
    const { sent } = await scenario();
    expect(sent).toHaveLength(1);
  });

  test('iPhone sans numéro de build (anciennes apps, appBuild 0) → annonce envoyée', async () => {
    const { sent } = await scenario({ devices: [{ token: 't1', platform: 'ios', appBuild: 0, at: ago(5) }] });
    expect(sent).toHaveLength(1);
  });

  test('ancien iPhone 607, mais session Android PLUS RÉCENTE → annonce envoyée', async () => {
    const { sent } = await scenario({
      devices: [{ token: 't1', platform: 'ios', appBuild: 607, at: ago(600) }],
      activity: [{ platform: 'android', appVersion: '23.1.604+607', at: ago(3) }],
    });
    expect(sent).toHaveLength(1);
  });

  test('session iOS 607 la plus récente (jeton Android plus ancien) → aucune annonce', async () => {
    const { sent } = await scenario({
      devices: [{ token: 't1', platform: 'android', appBuild: 605, at: ago(600) }],
      activity: [{ platform: 'ios', appVersion: '23.1.604+607', at: ago(3) }],
    });
    expect(sent).toHaveLength(0);
  });

  test('dernière visite sur le SITE (plus récente que l’iPhone 607) → annonce envoyée', async () => {
    const { sent } = await scenario({
      devices: [{ token: 't1', platform: 'ios', appBuild: 607, at: ago(600) }],
      activity: [{ platform: 'web', appVersion: 'web', at: ago(3) }],
    });
    expect(sent).toHaveLength(1);
  });

  test('l’iPhone 607 est enregistré sur un AUTRE profil de la personne → aucune annonce', async () => {
    const { sent } = await scenario({ siblingSitterDevices: [{ token: 't9', platform: 'ios', appBuild: 608, at: ago(2) }] });
    expect(sent).toHaveLength(0);
  });
});

describe('règle pure', () => {
  test('la trace la plus récente avec une plateforme gagne', () => {
    const c = latestKnownClient([
      { platform: 'ios', build: 607, at: ago(10) },
      { platform: '', build: 999, at: ago(1) },
      { platform: 'android', build: '23.1.604+606', at: ago(5) },
    ]);
    expect(c).toMatchObject({ platform: 'android', build: 606 });
    expect(isIosNoReferralClient(c)).toBe(false);
  });
  test('iOS 607 lu dans X-App-Version', () => {
    expect(isIosNoReferralClient(latestKnownClient([{ platform: 'ios', build: '23.1.604+607', at: new Date() }]))).toBe(true);
    expect(isIosNoReferralClient(latestKnownClient([{ platform: 'iOS', build: '23.1.604', at: new Date() }]))).toBe(false);
    expect(isIosNoReferralClient(null)).toBe(false);
  });
});
