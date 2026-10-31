process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}` })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async (body) => ({ id: 'int_620', client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: body.amount / 100, currency: body.currency })),
    retrievePaymentIntent: jest.fn(async (id) => ({ id })),
    cancelPaymentIntent: jest.fn(async (id) => ({ id, status: 'CANCELLED' })),
  };
});
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  requireVerifiedEmail: (req, res, next) => next(),
  attachUserFromToken: (req, res, next) => next(),
  attachOwnerFromToken: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject, text) => { MAILS.push({ to, subject, text: String(text || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: [] }; }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));




// 3110 (ADA) — relance « posez vos dates » : tbd + candidat → 1 e-mail ; dates posées → rien ; 3 relances
// déjà parties → rien ; nuit → différé ; +test exclu ; propriétaire revenu < 24 h → rien ; mention fêtes.
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Pet; let Post; let Application; let ActivityEvent; let Reminder;
const PASS = 'MotDePasseTest3110!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const T0 = new Date('2026-11-02T09:00:00.000Z'); // 10 h à Paris
const at = (h) => new Date(T0.getTime() + h * 3600000);
let sitter; let n = 0;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Pet = require('../src/models/Pet');
  Post = require('../src/models/Post'); Application = require('../src/models/Application');
  ActivityEvent = require('../src/models/ActivityEvent'); Reminder = require('../src/models/CandidatesReminder2810');
  await Promise.all([Owner.init(), Sitter.init(), Pet.init(), Post.init(), Application.init(), Reminder.init()]);
  sitter = await Sitter.create({ name: 'Inès Petit', email: 'ines.relance3110@example.org', password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', dailyRate: 18, verified: true, location: ZONE });
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

/** Une demande tbd avec 1 candidat en attente depuis 30 h. */
async function mk(email, extra = {}) {
  n += 1;
  const o = await Owner.create({ name: 'Camille Durand', email, password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', verified: true, location: { type: 'Point', coordinates: [2.35, 48.85] }, acceptedTerms: true, appLocale: 'fr' });
  const pet = await Pet.create({ ownerId: o._id, petName: 'Rex', petType: 'cat' });
  const post = await Post.collection.insertOne({ ownerId: o._id, postType: 'request', status: 'open', dateMode: 'tbd', serviceTypes: ['house_sitting'], animalTypes: ['cat'], city: 'Paris', body: 'Garde', petIds: [pet._id], createdAt: at(-40), location: { type: 'Point', coordinates: [2.35, 48.85] }, ...extra });
  await Application.collection.insertOne({ ownerId: o._id, sitterId: sitter._id, postId: post.insertedId, petIds: [pet._id], serviceType: 'house_sitting', status: 'pending', createdAt: at(-30), updatedAt: at(-30), pricing: { indicative: true, appliedRate: 18, unit: 'day', currency: 'EUR', commissionRate: 0.2 } });
  return { owner: o, postId: post.insertedId };
}

const svc = () => require('../src/services/datesReminder3110');
const SENT = [];
const send = jest.fn(async (m) => { SENT.push(m); return { sent: true }; });
const run = (h, extra = {}) => svc().runDatesReminders({ now: at(h), send, ...extra });
const mine = (r, x) => r.sent.filter((l) => l.postId === String(x.postId));

describe('relance « posez vos dates » 3110', () => {
  test('tbd + candidat depuis 30 h, propriétaire jamais revenu → 1 e-mail (cartes, bouton « Poser mes dates »), jamais deux fois', async () => {
    const x = await mk('camille.a3110@example.org');
    const r = await run(0);
    expect(mine(r, x)).toEqual([expect.objectContaining({ slot: 'dates', candidates: 1, remindersBefore: 0 })]);
    const m = SENT.find((s) => s.data.postId === String(x.postId));
    expect(m).toMatchObject({ userId: String(x.owner._id), role: 'owner', type: 'application_new', templateType: 'application_new_2610' });
    expect(m.data.subjectLine).toBe('1 gardien est prêt à garder votre chat à Paris');
    expect(m.data.ctaLabel).toBe('Poser mes dates');
    expect(m.data.candidatesHtml2610).toContain('Posez vos dates : vous verrez leur prix total');
    expect(m.data.candidatesHtml2610).toContain('Inès');
    expect(m.data.candidatesHtml2610).not.toContain('Choisir Inès'); // un seul bouton : poser les dates
    expect(m.data.candidatesHtml2610).not.toContain('fêtes');
    expect(mine(await run(1), x)).toHaveLength(0);
    expect(await Reminder.countDocuments({ postId: x.postId, slot: 'dates' })).toBe(1);
  });

  test('dates posées → rien ; demande close ou réservée → rien', async () => {
    const a = await mk('camille.b3110@example.org', { dateMode: 'dates', startDate: at(100), endDate: at(150) });
    const b = await mk('camille.c3110@example.org', { status: 'closed' });
    const c = await mk('camille.d3110@example.org', { reservedBy: { bookingId: new mongoose.Types.ObjectId() } });
    const r = await run(0);
    for (const x of [a, b, c]) expect(mine(r, x)).toHaveLength(0);
    for (const x of [a, b, c]) expect(await Reminder.countDocuments({ postId: x.postId })).toBe(0);
  });

  test('3 relances déjà parties (2810) → rien ; registre commun : après « dates » + e1 + e2, la relance 2810 ne part plus (3 au total)', async () => {
    const x = await mk('camille.e3110@example.org');
    for (const slot of ['e1', 'e2', 'e3']) await Reminder.create({ postId: x.postId, slot, ownerId: x.owner._id, createdAt: at(-100) });
    const r = await run(0);
    expect(mine(r, x)).toHaveLength(0);
    expect(r.skipped.max_3).toBeGreaterThanOrEqual(1);

    const y = await mk('camille.f3110@example.org');
    await Reminder.create({ postId: y.postId, slot: 'e1', ownerId: y.owner._id, createdAt: at(-100) });
    await Reminder.create({ postId: y.postId, slot: 'e2', ownerId: y.owner._id, createdAt: at(-50) });
    expect(mine(await run(0), y)).toEqual([expect.objectContaining({ remindersBefore: 2 })]);
    // 2810 voudrait e3 (J+5 après e1) : refusée, le total est atteint.
    const r2810 = await require('../src/services/candidatesReminder2810').runCandidatesReminders({ now: at(30), send });
    expect(r2810.sent.filter((l) => l.postId === String(y.postId))).toHaveLength(0);
    expect(await Reminder.countDocuments({ postId: y.postId })).toBe(3);
  });

  test('une autre relance il y a moins de 24 h → attend ; ensuite part', async () => {
    const x = await mk('camille.g3110@example.org');
    await Reminder.create({ postId: x.postId, slot: 'e1', ownerId: x.owner._id, createdAt: at(-5) });
    const r = await run(0);
    expect(mine(r, x)).toHaveLength(0);
    expect(mine(await run(24), x)).toHaveLength(1); // 10 h le lendemain, 29 h après e1
  });

  test('nuit → différé au matin', async () => {
    const x = await mk('camille.h3110@example.org');
    const night = await run(13); // 23 h à Paris
    expect(mine(night, x)).toHaveLength(0);
    expect(night.skipped.night).toBeGreaterThanOrEqual(1);
    expect(await Reminder.countDocuments({ postId: x.postId })).toBe(0);
    expect(mine(await run(23), x)).toHaveLength(1); // 9 h le lendemain
  });

  test('compte +test exclu ; propriétaire revenu (vraie session) depuis moins de 24 h → rien ; une session de script ne compte pas', async () => {
    const t = await mk('camille+test3110@example.org');
    const back = await mk('camille.i3110@example.org');
    const script = await mk('camille.j3110@example.org');
    await ActivityEvent.create({ userId: String(back.owner._id), role: 'owner', at: at(-3), platform: 'web', appVersion: 'web', origin: 'web' });
    await ActivityEvent.create({ userId: String(script.owner._id), role: 'owner', at: at(-3), origin: 'script' });
    const sim = await run(0, { dryRun: true });
    const ids = sim.wouldSend.map((l) => l.postId);
    expect(ids).not.toContain(String(t.postId));
    expect(ids).not.toContain(String(back.postId));
    expect(ids).toContain(String(script.postId));
    expect(sim.skipped.test).toBeGreaterThanOrEqual(1);
    expect(sim.skipped.owner_back_24h).toBeGreaterThanOrEqual(1);
    expect(await Reminder.countDocuments({ postId: script.postId })).toBe(0); // simulation : rien écrit
    // 25 h après sa visite, le propriétaire revenu reçoit la relance.
    expect(mine(await run(22), back)).toHaveLength(1);
  });

  test('coupée par DATES_REMINDER_3110=off : rien envoyé', async () => {
    process.env.DATES_REMINDER_3110 = 'off';
    await mk('camille.k3110@example.org');
    const before = SENT.length;
    const r = await run(0);
    expect(r.enabled).toBe(false);
    expect(r.sent).toHaveLength(0);
    expect(SENT.length).toBe(before);
    delete process.env.DATES_REMINDER_3110;
  });

  test('mention « fêtes » seulement quand les dates touchent le 15/12 → 06/01 (relance dates et e-mail candidats 2610)', () => {
    const t3110 = require('../src/utils/datesReminderText3110');
    const t2610 = require('../src/utils/applicationEmailText2610');
    const cards = [{ name: 'Inès', role: 'sitter' }];
    const noel = { dateMode: 'dates', startDate: '2026-12-14T09:00:00Z', endDate: '2027-01-03T18:00:00Z', animalTypes: ['dog'], city: 'Paris' };
    const nov = { dateMode: 'dates', startDate: '2026-11-20T09:00:00Z', endDate: '2026-11-27T18:00:00Z', animalTypes: ['dog'], city: 'Paris' };
    const jan7 = { dateMode: 'dates', startDate: '2027-01-07T09:00:00Z', animalTypes: ['dog'] };
    const dec15 = { dateMode: 'dates', startDate: '2026-12-01T09:00:00Z', endDate: '2026-12-15T09:00:00Z', animalTypes: ['dog'] };
    expect(t2610.buildEmailData({ lang: 'fr', post: noel, cards, newCount: 1, totalPending: 1 }).candidatesHtml2610).toContain('Les gardiens se réservent tôt pour les fêtes.');
    expect(t2610.buildEmailData({ lang: 'fr', post: nov, cards, newCount: 1, totalPending: 1 }).candidatesHtml2610).not.toContain('fêtes');
    expect(t2610.buildEmailData({ lang: 'en', post: dec15, cards, newCount: 1, totalPending: 1 }).candidatesHtml2610).toContain('Sitters get booked early for the holidays.');
    expect(t3110.touchesHolidays(jan7)).toBe(false);
    expect(t3110.touchesHolidays({ startDate: '2027-01-06T20:00:00Z' })).toBe(true);
    expect(t3110.touchesHolidays({ dateMode: 'tbd' })).toBe(false);
    expect(t3110.buildEmailData({ lang: 'es', post: { ...noel, dateMode: 'tbd' }, cards, totalPending: 1 }).candidatesHtml2610).toContain('Los cuidadores se reservan pronto para las fiestas.');
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      const d = t3110.buildEmailData({ lang: l, post: { ...noel, dateMode: 'tbd' }, cards, totalPending: 2 });
      expect(d.subjectLine.length).toBeGreaterThan(10);
      expect(d.candidatesHtml2610).toContain(t3110.HOLIDAY[l].replace(/'/g, '&#39;'));
      expect(d.ctaLabel).toBe(t3110.D[l].cta);
    }
  });

  test('envoi réel par le notificationSender : e-mail FR complet, bouton signé vers /application/<id>', async () => {
    const x = await mk('camille.l3110@example.org');
    const before = MAILS.length;
    const r = await svc().runDatesReminders({ now: at(0) });
    expect(mine(r, x)).toHaveLength(1);
    const mail = MAILS.slice(before).find((m) => m.to === 'camille.l3110@example.org');
    expect(mail).toBeTruthy();
    expect(mail.subject).toBe('1 gardien est prêt à garder votre chat à Paris');
    expect(mail.text).toMatch(/\/application\/[a-f0-9]{24}/);
    // eslint-disable-next-line no-console
    console.log('E-MAIL FR 3110 >>>', JSON.stringify(mail));
  });
});
