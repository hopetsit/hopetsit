// 2211 — « RÉSERVER <prénom>, PAYER PLUS TARD » (mesure du 22/11/2026 : 55 propriétaires voient leurs candidats,
// 2 cliquent « Choisir et payer », 0 paie ; on exigeait la carte tout de suite, avant d'avoir pu parler au gardien).
//   1. Règles pures : échéance (48 h, ou début − 2 h, refus sous 6 h), créneaux de relance (24 h / 44 h).
//   2. Option refusée : éteinte (PAY_LATER_2211=off, SIBLINGS_KEEP_1011=off), trop tard ; rien n'est écrit.
//   3. Réservation créée sans carte : échéance correcte, AUCUNE intention de paiement, gardien prévenu
//      « en attente de paiement (sous 48 h) », autres candidats gardés ; « Payer maintenant » marche ensuite.
//   4. Relances : 24 h puis 44 h pour « payer plus tard », 1 h / 24 h inchangées pour les autres ; jamais la nuit.
//   5. Échéance dépassée : réservation annulée, candidature de nouveau « en attente », notifications, idempotence ;
//      payée avant l'échéance → jamais libérée ; réservation ordinaire → jamais touchée ; compte de test inclus.
//   6. `accept` sans option = comportement d'aujourd'hui ; prix négocié (2211) respecté ; admin en lecture seule.
// VRAIE base Mongo en mémoire, VRAIE application Express. Zone fictive lat -35 / lng -30. Aucun envoi réel.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.PAY_LATER_2211;
delete process.env.SIBLINGS_KEEP_1011;
delete process.env.PRICE_OFFER_2211;
delete process.env.PAYMENT_REMINDER_2910;
delete process.env.PUBLIC_API_URL;

const INTENTS = [];
const CANCELLED = [];
const mockIntent = { status: {} }; // id d'intention → statut renvoyé par Airwallex (ou 'ERR' = illisible)
jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}` })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async (body) => { INTENTS.push(body); return { id: `int_later_${INTENTS.length}`, client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: body.amount / 100, currency: body.currency }; }),
    retrievePaymentIntent: jest.fn(async (id) => { const st = mockIntent.status[id]; if (st === 'ERR') throw new Error('airwallex indisponible'); return { id, status: st || 'REQUIRES_PAYMENT_METHOD' }; }),
    cancelPaymentIntent: jest.fn(async (id) => { CANCELLED.push(id); return { id, status: 'CANCELLED' }; }),
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
  return {
    ...actual,
    sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to: String(to || '').toLowerCase(), subject: String(subject || ''), text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }),
    sendTemplatedEmail: jest.fn(async () => ({})),
  };
});
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), emitToConversation: jest.fn(), emitChatMessage: jest.fn(), touchConversationOpen: jest.fn(),
  buildPresenceIndex: jest.fn(async () => new Map()), isIdentityOnline: jest.fn(() => false), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false),
}));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const H = 3600000;
const inDays = (n) => new Date(Date.now() + n * 86400000);
const day = (n) => `${inDays(n).toISOString().slice(0, 10)}T00:00:00.000Z`;
let mongo; let app;
let Owner; let Sitter; let Walker; let Pet; let Post; let Application; let Booking; let Notification;
const PASS = 'MotDePasseTest2211!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const API = '/api/v1';
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+621' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const S = {};

const svc = () => require('../src/services/payLater2211');
const reminders = () => require('../src/services/paymentReminder2910');
const freshApp = (id) => Application.findById(id).lean();
const freshBooking = (id) => Booking.findById(id).lean();
const respond = (appId, body, who = S.owner) => request(app).post(`${API}/applications/${appId}/respond`).set(hdr(who._id, 'owner')).send(body);
const myApps = async (who = S.owner) => (await request(app).get(`${API}/applications/my`).set(hdr(who._id, 'owner')).expect(200)).body.applications;
const viewOf = async (appId, who = S.owner) => (await myApps(who)).find((a) => String(a.id) === String(appId)).payLater2211View;
// Les notifications partent sans être attendues par la réponse HTTP : on attend qu'elles soient écrites.
const notifs = (userId, filter = {}) => Notification.find({ recipientId: userId, ...filter }).sort({ createdAt: 1 }).lean();
const waitNotif = async (userId, filter, n = 1) => {
  for (let i = 0; i < 80; i += 1) {
    const rows = await notifs(userId, filter);
    if (rows.length >= n) return rows;
    await new Promise((r) => setTimeout(r, 50));
  }
  return notifs(userId, filter);
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Booking = require('../src/models/Booking'); Notification = require('../src/models/Notification');
  require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Booking.init()]);
  app = require('../src/app');
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Karine Essai', email: 'plustard2211.karine@example.org', acceptedTerms: true });
  S.ownerTest = await Owner.create({ ...fr, name: 'Compte Essai', email: 'plustard2211+test@example.org', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  S.petTest = await Pet.create({ ownerId: S.ownerTest._id, petName: 'Max', petType: 'dog' });
  S.hanene = await Sitter.create({ ...fr, name: 'Hanene Essai', email: 'plustard2211.hanene@example.org', dailyRate: 18 });
  S.sohane = await Sitter.create({ ...fr, name: 'Sohane Essai', email: 'plustard2211.sohane@example.org', dailyRate: 50 });
  S.imane = await Walker.create({ ...fr, name: 'Imane Essai', email: 'plustard2211.imane@example.org', walkRates: [{ durationMinutes: 30, basePrice: 12, currency: 'EUR', enabled: true }] });
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body, who = S.owner, pet = S.pet) => request(app).post(`${API}/posts`).set(hdr(who._id, 'owner')).send({
  body: 'Demande de test 2211 payer plus tard, zone test.', language: 'fr', animalCount: 1, animalTypes: ['dog'], petIds: [String(pet._id)], location: LOC, ...body,
});
const apply = async (post, who, role, extra = {}, owner = S.owner) => {
  const r = await request(app).post(`${API}/applications?ownerId=${owner._id}`).set(hdr(who._id, role)).send({
    postId: post.id || String(post._id), description: 'Je suis disponible.', timeSlot: 'morning', ...extra,
  });
  if (r.status !== 201) console.log('apply →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
  expect(r.status).toBe(201);
  return String(r.body.application.id || r.body.application._id);
};
/** Une demande de garde d'un jour dans `d` jours + la candidature d'un gardien (18 €/jour → 21,60 € ; 50 € → 60 €). */
const sitting = async (d, sitter, owner = S.owner, pet = S.pet) => {
  const dates = { serviceDate: day(d), startDate: day(d), endDate: day(d) };
  const post = (await createPost({ serviceTypes: ['pet_sitting'], dateMode: 'exact', startDate: day(d), endDate: day(d) }, owner, pet).expect(201)).body.post;
  const appId = await apply(post, sitter, 'sitter', { serviceType: 'pet_sitting', ...dates }, owner);
  return { post, appId };
};
/** Recale « choisi le » et l'échéance d'une réservation (les relances et la libération se lisent sur ces dates). */
const shift = (bookingId, at, deadline) => Booking.updateOne({ _id: bookingId }, { $set: { 'payLater2211.at': at, 'payLater2211.deadline': deadline, agreedAt: at } });

describe('1. Règles pures', () => {
  const NOW = new Date('2026-12-01T10:00:00Z');
  test('échéance : 48 h ; début du service plus tôt → début − 2 h ; début dans moins de 6 h → refus', () => {
    const far = svc().computeDeadline(NOW.getTime() + 20 * 24 * H, NOW);
    expect(far).toMatchObject({ ok: true, holdMs: 48 * H });
    expect(far.deadline.toISOString()).toBe('2026-12-03T10:00:00.000Z');
    const soon = svc().computeDeadline(NOW.getTime() + 30 * H, NOW);
    expect(soon).toMatchObject({ ok: true, holdMs: 28 * H });
    expect(soon.deadline.toISOString()).toBe('2026-12-02T14:00:00.000Z');
    expect(svc().computeDeadline(NOW.getTime() + 50 * H, NOW).holdMs).toBe(48 * H);       // début − 2 h = 48 h tout juste
    expect(svc().computeDeadline(NOW.getTime() + 6 * H, NOW)).toMatchObject({ ok: true, holdMs: 4 * H });
    expect(svc().computeDeadline(NOW.getTime() + 6 * H - 1, NOW)).toEqual({ ok: false, code: 'PAY_LATER_TOO_LATE' });
    expect(svc().computeDeadline(NOW.getTime() - H, NOW)).toEqual({ ok: false, code: 'PAY_LATER_TOO_LATE' });
    expect(svc().computeDeadline(NaN, NOW)).toMatchObject({ ok: true, holdMs: 48 * H });   // début inconnu : 48 h
    expect(svc().holdHours(48 * H)).toBe(48);
    expect(svc().holdHours(20 * 60000)).toBe(1);
  });
  test('relances : 24 h puis 44 h pour 48 h ; proportionnelles si l’échéance est plus courte ; 2 au maximum ; jamais après l’échéance', () => {
    const pl = { at: NOW, deadline: new Date(NOW.getTime() + 48 * H) };
    const at = (h) => new Date(NOW.getTime() + h * H);
    expect(svc().dueReminderSlot(pl, [], at(1))).toBeNull();          // l'ancienne r1 (+1 h) ne part pas
    expect(svc().dueReminderSlot(pl, [], at(23.9))).toBeNull();
    expect(svc().dueReminderSlot(pl, [], at(24))).toBe('r1');
    expect(svc().dueReminderSlot(pl, [{ at: at(24), slot: 'r1' }], at(43.9))).toBeNull();
    expect(svc().dueReminderSlot(pl, [{ at: at(24), slot: 'r1' }], at(44))).toBe('r2');
    expect(svc().dueReminderSlot(pl, [{ at: at(24) }, { at: at(44) }], at(47))).toBeNull();
    expect(svc().dueReminderSlot(pl, [], at(48))).toBeNull();
    const short = { at: NOW, deadline: new Date(NOW.getTime() + 12 * H) };
    expect(svc().dueReminderSlot(short, [], at(5.9))).toBeNull();
    expect(svc().dueReminderSlot(short, [], at(6))).toBe('r1');
    expect(svc().dueReminderSlot(short, [{ at: at(6) }], at(11))).toBe('r2');
    expect(svc().dueReminderSlot({ at: NOW }, [], at(30))).toBeNull();
    expect(svc().reminderExtras(pl, at(24))).toEqual({ templateType: 'pay_later_reminder_2211', data: { hoursLeft: 24, payLater2211: true } });
    expect(svc().reminderExtras(pl, at(44)).data.hoursLeft).toBe(4);
  });
  test('gabarits : les 4 textes existent dans les 9 langues, avec leurs variables', () => {
    const KEYS = { application_accepted_paylater_2211: '{{hours}}', pay_later_reminder_2211: '{{hoursLeft}}', pay_later_released_owner_2211: '{{providerName}}', pay_later_released_provider_2211: '' };
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ko', 'ja']) {
      const d = require(`../src/locales/${l}/notifications.json`);
      for (const [k, v] of Object.entries(KEYS)) {
        for (const f of ['title', 'body', 'emailSubject', 'emailBody']) expect(String(d[k][f]).trim().length).toBeGreaterThan(3);
        expect(d[k].body).toContain(v);
        expect(d[k].emailBody).toContain('{{emailLink}}');
      }
    }
    expect(Object.values(svc().TEMPLATES).sort()).toEqual(Object.keys(KEYS).sort());
  });
});

describe('2. Option refusée : rien n’est écrit', () => {
  test('préparation : garde d’un jour dans 20 jours, deux candidats (Hanene 21,60 €, Sohane 60 €)', async () => {
    const a = await sitting(20, S.hanene);
    S.post = a.post; S.appHanene = a.appId;
    S.appSohane = await apply(S.post, S.sohane, 'sitter', { serviceType: 'pet_sitting', serviceDate: day(20), startDate: day(20), endDate: day(20) });
    expect((await freshApp(S.appHanene)).pricing).toMatchObject({ totalPrice: 21.6, commission: 3.6, netPayout: 18, currency: 'EUR' });
    expect(await viewOf(S.appHanene)).toMatchObject({ enabled: true, canReserve: true, status: null, holdHours: 48 });
  }, 60000);

  test('PAY_LATER_2211=off : 409 PAY_LATER_DISABLED, le site masque le bouton ; SIBLINGS_KEEP_1011=off : pareil ; rallumé par défaut', async () => {
    for (const [k, v] of [['PAY_LATER_2211', 'off'], ['PAY_LATER_2211', 'OFF '], ['SIBLINGS_KEEP_1011', 'off']]) {
      process.env[k] = v;
      const r = await respond(S.appHanene, { action: 'accept', payLater: true });
      expect([r.status, r.body.code]).toEqual([409, 'PAY_LATER_DISABLED']);
      expect(await viewOf(S.appHanene)).toMatchObject({ enabled: false, canReserve: false });
      delete process.env[k];
    }
    expect((await freshApp(S.appHanene)).status).toBe('pending');
    expect((await freshApp(S.appHanene)).bookingId).toBeFalsy();
    expect(await Booking.countDocuments({})).toBe(0);
    expect(INTENTS).toHaveLength(0);
    expect(await viewOf(S.appHanene)).toMatchObject({ enabled: true, canReserve: true });
  }, 60000);

  test('service dans moins de 6 h : 409 PAY_LATER_TOO_LATE, bouton masqué, « Choisir et payer » reste possible', async () => {
    const { appId } = await sitting(21, S.hanene);
    const soon = new Date(Date.now() + 5 * H);
    await Application.updateOne({ _id: appId }, { $set: { startDate: soon, serviceDate: soon, endDate: soon } });
    const r = await respond(appId, { action: 'accept', payLater: true });
    expect([r.status, r.body.code]).toEqual([409, 'PAY_LATER_TOO_LATE']);
    const a = await freshApp(appId);
    expect([a.status, a.bookingId || null]).toEqual(['pending', null]);
    expect(await Booking.countDocuments({})).toBe(0);
    expect(await viewOf(appId)).toMatchObject({ enabled: true, canReserve: false, status: null });
  }, 60000);

  test('`payLater` avec un refus (`reject`) : ignoré, la candidature est simplement refusée', async () => {
    const { appId } = await sitting(22, S.sohane);
    const r = await respond(appId, { action: 'reject', payLater: true });
    expect(r.status).toBe(200);
    expect(r.body.payLater2211).toBeUndefined();
    expect((await freshApp(appId)).status).toBe('rejected');
    expect(await Booking.countDocuments({})).toBe(0);
  }, 60000);
});

describe('3. Réservation créée sans carte', () => {
  test('`accept` + `payLater` : réservation « agreed », échéance = 48 h, AUCUNE intention de paiement, autre candidat gardé', async () => {
    INTENTS.length = 0;
    const t0 = Date.now();
    const r = await respond(S.appHanene, { action: 'accept', payLater: true });
    const t1 = Date.now();
    if (r.status !== 200) console.log('payLater →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(r.body.payment).toBeNull();
    expect(INTENTS).toHaveLength(0);
    expect(r.body.payLater2211.holdHours).toBe(48);
    const dl = new Date(r.body.payLater2211.deadline).getTime();
    expect(dl).toBeGreaterThanOrEqual(t0 + 48 * H);
    expect(dl).toBeLessThanOrEqual(t1 + 48 * H);
    const a = await freshApp(S.appHanene);
    expect(a.status).toBe('accepted');
    S.booking = String(a.bookingId);
    const b = await freshBooking(S.booking);
    expect(b).toMatchObject({ status: 'agreed', paymentStatus: 'pending', paidAt: null });
    expect(b.airwallexPaymentIntentId || null).toBeNull();
    expect(b.pricing).toMatchObject({ totalPrice: 21.6, commission: 3.6, netPayout: 18, currency: 'EUR' });
    expect(new Date(b.payLater2211.deadline).getTime()).toBe(dl);
    expect(new Date(b.payLater2211.deadline).getTime() - new Date(b.payLater2211.at).getTime()).toBe(48 * H);
    expect(String(b.payLater2211.applicationId)).toBe(S.appHanene);
    expect(b.payLater2211.releasedAt || null).toBeNull();
    // les autres candidats restent en attente (siblings1011), la demande est marquée réservée
    expect((await freshApp(S.appSohane)).status).toBe('pending');
    expect(String((await Post.findById(S.post.id).lean()).reservedBy.bookingId)).toBe(S.booking);
    // le site : « Réservé jusqu'au … · Payer maintenant »
    const v = await viewOf(S.appHanene);
    expect(v).toMatchObject({ enabled: true, canReserve: false, status: 'waiting' });
    expect(new Date(v.deadline).getTime()).toBe(dl);
    expect(await viewOf(S.appSohane)).toMatchObject({ canReserve: true, status: null });
  }, 60000);

  test('le gardien est prévenu par le type EXISTANT `application_accepted`, avec « en attente de paiement (sous 48 h) »', async () => {
    const rows = await waitNotif(S.hanene._id, { type: 'application_accepted' });
    expect(rows).toHaveLength(1);
    expect(rows[0].data).toMatchObject({ templateKey: 'application_accepted_paylater_2211', hours: 48, bookingId: S.booking });
    expect(rows[0].body).toContain('en attente de paiement (sous 48 h)');
    // la cloche re-rend le même texte à la lecture (gabarit mémorisé)
    const { renderNotificationContent } = require('../src/services/notificationSender');
    expect(renderNotificationContent('application_accepted', rows[0].data, 'fr').body).toContain('sous 48 h');
    expect(renderNotificationContent('application_accepted', rows[0].data, 'en').body).toContain('within 48 h');
    // le propriétaire ne reçoit rien au choix (comme aujourd'hui)
    expect(await notifs(S.owner._id, { type: 'booking_accepted' })).toHaveLength(0);
  }, 60000);

  test('début du service plus tôt que 48 h + 2 h : échéance = début − 2 h', async () => {
    const { appId } = await sitting(23, S.sohane);
    const start = new Date(Date.now() + 30 * H);
    await Application.updateOne({ _id: appId }, { $set: { startDate: start, serviceDate: start, endDate: start } });
    expect((await viewOf(appId)).holdHours).toBe(28);
    const r = await respond(appId, { action: 'accept', payLater: true });
    expect(r.status).toBe(200);
    expect(r.body.payLater2211.holdHours).toBe(28);
    const b = await freshBooking((await freshApp(appId)).bookingId);
    expect(new Date(b.payLater2211.deadline).getTime()).toBe(start.getTime() - 2 * H);
    const n = (await waitNotif(S.sohane._id, { type: 'application_accepted' })).pop();
    expect(n.body).toContain('sous 28 h');
    S.bookingShort = String(b._id);
  }, 60000);

  test('« Payer maintenant » : l’intention de paiement se crée APRÈS, au bon montant (21,60 € = 2 160 centimes)', async () => {
    INTENTS.length = 0;
    const r = await request(app).post(`${API}/bookings/${S.booking}/create-payment-intent`).set(hdr(S.owner._id, 'owner')).send({});
    if (r.status !== 200) console.log('intent →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(INTENTS).toHaveLength(1);
    expect(INTENTS[0]).toMatchObject({ amount: 2160, currency: 'EUR' });
    S.intent = (await freshBooking(S.booking)).airwallexPaymentIntentId;
    expect(S.intent).toBeTruthy();
    expect((await freshBooking(S.booking)).payLater2211.at).toBeTruthy(); // le bloc survit à la création de l'intention
  }, 60000);
});

describe('4. Relances de paiement', () => {
  // 14 h UTC = 15 h à Paris (jour). +24 h = 15 h, +44 h = 11 h : de jour toutes les deux.
  const T0 = new Date('2026-12-01T14:00:00Z');
  const at = (h) => new Date(T0.getTime() + h * H);
  const mine = (rep, id) => rep.sent.filter((x) => x.bookingId === id).map((x) => x.slot);
  test('« payer plus tard » : rien à +1 h ni +23 h, r1 à +24 h, r2 à +44 h, jamais de 3e ; le texte dit le temps restant', async () => {
    await shift(S.booking, T0, at(48));
    await shift(S.bookingShort, at(100), at(148));                    // hors du champ de ce test
    await Booking.updateMany({}, { $set: { startDate: '2027-06-01', serviceDate: new Date('2027-06-01') } });
    expect(mine(await reminders().runPaymentReminders({ now: at(1.5) }), S.booking)).toEqual([]);
    expect(mine(await reminders().runPaymentReminders({ now: at(23) }), S.booking)).toEqual([]);
    expect(mine(await reminders().runPaymentReminders({ now: at(24) }), S.booking)).toEqual(['r1']);
    expect(mine(await reminders().runPaymentReminders({ now: at(30) }), S.booking)).toEqual([]);
    expect(mine(await reminders().runPaymentReminders({ now: at(43) }), S.booking)).toEqual([]);
    expect(mine(await reminders().runPaymentReminders({ now: at(44) }), S.booking)).toEqual(['r2']);
    expect(mine(await reminders().runPaymentReminders({ now: at(47) }), S.booking)).toEqual([]);
    expect((await freshBooking(S.booking)).paymentReminder2910.sent.map((x) => x.slot)).toEqual(['r1', 'r2']);
    const rows = await notifs(S.owner._id, { type: 'booking_accepted' });
    expect(rows).toHaveLength(2);
    expect(rows.map((x) => x.data.templateKey)).toEqual(['pay_later_reminder_2211', 'pay_later_reminder_2211']);
    expect(rows[0].body).toContain('Il te reste 24 h');
    expect(rows[1].body).toContain('Il te reste 4 h');
    expect(rows[0].data).toMatchObject({ bookingId: S.booking, reminder: 'r1', amount: 21.6 });
  }, 60000);

  test('jamais la nuit : une relance due à 1 h du matin (Paris) attend le jour', async () => {
    const { appId } = await sitting(24, S.sohane);
    expect((await respond(appId, { action: 'accept', payLater: true })).status).toBe(200);
    const id = String((await freshApp(appId)).bookingId);
    const night = new Date('2026-12-05T00:00:00Z');                    // 1 h à Paris
    await shift(id, new Date(night.getTime() - 24 * H), new Date(night.getTime() + 24 * H));
    await Booking.updateOne({ _id: id }, { $set: { startDate: '2027-06-01', serviceDate: new Date('2027-06-01') } });
    const rep = await reminders().runPaymentReminders({ now: night });
    expect(mine(rep, id)).toEqual([]);
    expect(rep.skipped.night).toBeGreaterThanOrEqual(1);
    expect(mine(await reminders().runPaymentReminders({ now: new Date(night.getTime() + 9 * H) }), id)).toEqual(['r1']); // 10 h à Paris
    S.bookingNight = id; S.appNight = appId;
  }, 60000);

  test('réservation ORDINAIRE (« Choisir et payer ») : inchangé, r1 à +1 h et r2 à +24 h, texte habituel', async () => {
    const { appId } = await sitting(25, S.hanene);
    const r = await respond(appId, { action: 'accept' });
    expect(r.status).toBe(200);
    const id = String((await freshApp(appId)).bookingId);
    await Booking.updateOne({ _id: id }, { $set: { agreedAt: T0, startDate: '2027-06-01', serviceDate: new Date('2027-06-01') } });
    const before = (await notifs(S.owner._id, { type: 'booking_accepted' })).length;
    expect(mine(await reminders().runPaymentReminders({ now: at(0.5) }), id)).toEqual([]);
    expect(mine(await reminders().runPaymentReminders({ now: at(1) }), id)).toEqual(['r1']);
    expect(mine(await reminders().runPaymentReminders({ now: at(20) }), id)).toEqual([]);
    expect(mine(await reminders().runPaymentReminders({ now: at(25) }), id)).toEqual(['r2']);
    const rows = (await notifs(S.owner._id, { type: 'booking_accepted' })).slice(before);
    expect(rows).toHaveLength(2);
    expect(rows[0].data.templateKey).toBeUndefined();
    expect(rows[0].data.payLater2211).toBeUndefined();
    expect(rows[0].body).toBe(require('../src/locales/fr/notifications.json').booking_accepted.body);
    S.bookingPlain = id; S.appPlain = appId;
  }, 60000);
});

describe('5. Échéance dépassée', () => {
  const run = (opts = {}) => svc().runRelease(opts);
  test('avant l’échéance : rien n’est libéré ; simulation (dryRun) : rien n’est écrit', async () => {
    await shift(S.booking, new Date(Date.now() - 47 * H), new Date(Date.now() + H));
    await shift(S.bookingShort, new Date(Date.now() - H), new Date(Date.now() + 20 * H));
    await shift(S.bookingNight, new Date(Date.now() - H), new Date(Date.now() + 20 * H));
    const r = await run();
    expect(r.released).toEqual([]);
    expect(r.examined).toBe(0);
    await shift(S.booking, new Date(Date.now() - 49 * H), new Date(Date.now() - H));
    const sim = await run({ dryRun: true });
    expect(sim.wouldRelease.map((x) => x.bookingId)).toEqual([S.booking]);
    expect((await freshBooking(S.booking)).status).toBe('agreed');
    expect((await freshApp(S.appHanene)).status).toBe('accepted');
  }, 60000);

  test('intention de paiement ABOUTIE chez Airwallex (confirmation en route) ou illisible : on ne libère pas', async () => {
    mockIntent.status[S.intent] = 'SUCCEEDED';
    let r = await run();
    expect(r.released).toEqual([]);
    expect(r.skipped.intent_succeeded).toBe(1);
    mockIntent.status[S.intent] = 'ERR';
    r = await run();
    expect(r.released).toEqual([]);
    expect(r.skipped.intent_unknown).toBe(1);
    expect((await freshBooking(S.booking)).status).toBe('agreed');
    delete mockIntent.status[S.intent];
  }, 60000);

  test('échéance passée sans paiement : réservation annulée, candidature de nouveau « en attente », demande libérée, 2 notifications', async () => {
    CANCELLED.length = 0;
    const r = await run();
    expect(r.released.map((x) => x.bookingId)).toEqual([S.booking]);
    expect(r.released[0]).toMatchObject({ applicationId: S.appHanene, applicationsReopened: 1 });
    const b = await freshBooking(S.booking);
    expect(b).toMatchObject({ status: 'cancelled', paymentStatus: 'cancelled', paidAt: null });
    expect(b.payLater2211.releasedAt).toBeTruthy();
    expect(CANCELLED).toEqual([S.intent]);                               // l'intention ouverte ne peut plus être payée
    const a = await freshApp(S.appHanene);
    expect([a.status, a.bookingId || null]).toEqual(['pending', null]);
    expect(a.pricing).toMatchObject({ totalPrice: 21.6 });
    expect((await freshApp(S.appSohane)).status).toBe('pending');        // l'autre candidat n'a jamais été fermé
    expect((await Post.findById(S.post.id).lean()).reservedBy.bookingId || null).toBeNull();
    // propriétaire : type existant `application_new` (ouvre ses candidats), texte « libérée »
    const o = await notifs(S.owner._id, { type: 'application_new', 'data.templateKey': 'pay_later_released_owner_2211' });
    expect(o).toHaveLength(1);
    expect(o[0].body).toBe('Ta réservation avec Hanene n\'a pas été payée à temps : elle est libérée. Tu peux encore choisir un gardien.');
    expect(o[0].data).toMatchObject({ applicationId: S.appHanene, bookingId: S.booking, postId: String(S.post.id) });
    // gardien : type existant `booking_cancelled_by_owner`, texte « libérée »
    const p = await notifs(S.hanene._id, { type: 'booking_cancelled_by_owner' });
    expect(p).toHaveLength(1);
    expect(p[0].data.templateKey).toBe('pay_later_released_provider_2211');
    expect(p[0].body).toContain('la réservation est libérée');
    expect(MAILS.some((m) => m.to === 'plustard2211.karine@example.org' && /libérée/.test(m.subject))).toBe(true);
  }, 60000);

  test('idempotent : un 2e passage ne libère rien et n’envoie rien', async () => {
    const before = await Notification.countDocuments({});
    const r = await run();
    expect(r.released).toEqual([]);
    expect(r.examined).toBe(0);
    await run();
    expect(await Notification.countDocuments({})).toBe(before);
    expect((await freshApp(S.appHanene)).status).toBe('pending');
  }, 60000);

  test('après la libération : pas de 2e « payer plus tard » sur ce candidat, mais « Choisir et payer » marche (nouvelle réservation)', async () => {
    expect(await viewOf(S.appHanene)).toMatchObject({ canReserve: false, status: 'released' });
    const again = await respond(S.appHanene, { action: 'accept', payLater: true });
    expect([again.status, again.body.code]).toEqual([409, 'PAY_LATER_ALREADY_USED']);
    expect((await freshApp(S.appHanene)).status).toBe('pending');
    INTENTS.length = 0;
    const r = await respond(S.appHanene, { action: 'accept' });
    expect(r.status).toBe(200);
    expect(INTENTS).toHaveLength(1);
    const a = await freshApp(S.appHanene);
    expect(a.status).toBe('accepted');
    expect(String(a.bookingId)).not.toBe(S.booking);
    expect((await freshBooking(a.bookingId)).payLater2211?.at).toBeUndefined();
    expect((await freshBooking(S.booking)).status).toBe('cancelled');
  }, 60000);

  test('PAYÉE avant l’échéance : jamais libérée, même échéance passée', async () => {
    await Booking.updateOne({ _id: S.bookingShort }, { $set: { status: 'paid', paymentStatus: 'paid', paidAt: new Date() } });
    await shift(S.bookingShort, new Date(Date.now() - 49 * H), new Date(Date.now() - H));
    const r = await run();
    expect(r.released).toEqual([]);
    const b = await freshBooking(S.bookingShort);
    expect(b).toMatchObject({ status: 'paid', paymentStatus: 'paid' });
    expect(b.payLater2211.releasedAt || null).toBeNull();
    const a = await Application.findOne({ bookingId: S.bookingShort }).lean();
    expect(a.status).toBe('accepted');
    expect(await viewOf(a._id)).toMatchObject({ status: 'paid', canReserve: false });
    // payée « au dernier moment » (statut de paiement seul) : le garde-fou de l'annulation refuse aussi
    const { releaseUnpaidBooking } = require('../src/controllers/bookingController');
    expect(await releaseUnpaidBooking(await Booking.findById(S.bookingShort))).toBe(false);
    expect((await freshBooking(S.bookingShort)).status).toBe('paid');
  }, 60000);

  test('réservation ORDINAIRE jamais payée, vieille de 30 jours : jamais touchée par ce balayage', async () => {
    await Booking.updateOne({ _id: S.bookingPlain }, { $set: { agreedAt: new Date(Date.now() - 30 * 24 * H) } });
    const r = await run();
    expect(r.examined).toBe(0);
    expect((await freshBooking(S.bookingPlain)).status).toBe('agreed');
    expect((await freshApp(S.appPlain)).status).toBe('accepted');
  }, 60000);

  test('éteint (PAY_LATER_2211=off) : les réservations déjà faites gardent leur échéance et sont libérées', async () => {
    await shift(S.bookingNight, new Date(Date.now() - 49 * H), new Date(Date.now() - H));
    process.env.PAY_LATER_2211 = 'off';
    const r = await run();
    delete process.env.PAY_LATER_2211;
    expect(r.released.map((x) => x.bookingId)).toEqual([S.bookingNight]);
    expect((await freshBooking(S.bookingNight)).status).toBe('cancelled');
    expect((await freshApp(S.appNight)).status).toBe('pending');
  }, 60000);

  test('compte de TEST : libéré comme les autres (il sert aux essais) ; promeneur : pareil', async () => {
    const dates = { serviceDate: day(26), startDate: day(26), endDate: day(26) };
    const post = (await createPost({ serviceTypes: ['dog_walking'], dateMode: 'exact', startDate: day(26), endDate: day(26), duration: 30 }, S.ownerTest, S.petTest).expect(201)).body.post;
    const appId = await apply(post, S.imane, 'walker', { serviceType: 'dog_walking', duration: 30, ...dates }, S.ownerTest);
    const r = await respond(appId, { action: 'accept', payLater: true }, S.ownerTest);
    if (r.status !== 200) console.log('payLater promeneur →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const id = String((await freshApp(appId)).bookingId);
    expect((await freshBooking(id)).walkerId.toString()).toBe(String(S.imane._id));
    await shift(id, new Date(Date.now() - 49 * H), new Date(Date.now() - H));
    const rep = await run();
    expect(rep.released.map((x) => x.bookingId)).toEqual([id]);
    expect((await freshBooking(id)).status).toBe('cancelled');
    expect((await freshApp(appId)).status).toBe('pending');
    const w = await notifs(S.imane._id, { type: 'booking_cancelled_by_owner' });
    expect(w).toHaveLength(1);
    const o = await notifs(S.ownerTest._id, { type: 'application_new', 'data.templateKey': 'pay_later_released_owner_2211' });
    expect(o).toHaveLength(1);
    expect(o[0].body).toContain('Imane');
  }, 60000);
});

describe('6. Compatibilité, prix négocié, admin', () => {
  test('`accept` SANS option (app installée) : exactement comme aujourd’hui — intention créée, pas d’échéance, texte habituel', async () => {
    const { appId } = await sitting(27, S.sohane);
    INTENTS.length = 0;
    const before = (await notifs(S.sohane._id, { type: 'application_accepted' })).length;
    const r = await respond(appId, { action: 'accept' });
    expect(r.status).toBe(200);
    expect(Object.keys(r.body).sort()).toEqual(['application', 'booking', 'conversation', 'payment']);
    expect(INTENTS).toHaveLength(1);
    expect(INTENTS[0]).toMatchObject({ amount: 6000, currency: 'EUR' });
    expect(r.body.payment).toMatchObject({ amount: 6000 });
    const b = await freshBooking((await freshApp(appId)).bookingId);
    expect(b).toMatchObject({ status: 'agreed', paymentStatus: 'pending' });
    expect(b.payLater2211?.at).toBeUndefined();
    expect(b.airwallexPaymentIntentId).toBeTruthy();
    const n = (await waitNotif(S.sohane._id, { type: 'application_accepted' }, before + 1)).pop();
    expect(n.data.templateKey).toBeUndefined();
    expect(n.body).toBe(require('../src/locales/fr/notifications.json').application_accepted.body);
    expect(await viewOf(appId)).toMatchObject({ status: null, canReserve: false });
    // `payLater: false` ou une autre valeur : pareil
    const other = await sitting(28, S.sohane);
    const r2 = await respond(other.appId, { action: 'accept', payLater: false });
    expect(r2.status).toBe(200);
    expect(r2.body.payLater2211).toBeUndefined();
    expect(r2.body.payment).toMatchObject({ amount: 6000 });
  }, 60000);

  test('prix NÉGOCIÉ (« Proposer mon prix ») respecté aussi par « payer plus tard » : réservation puis intention à 45 €, pas 60 €', async () => {
    const offers = require('../src/services/priceOffer2211');
    const { appId } = await sitting(29, S.sohane);
    const o = await request(app).post(`${API}/applications/${appId}/price-offer`).set(hdr(S.owner._id, 'owner')).send({ amount: 45 });
    await offers.effects();
    expect(o.status).toBe(201);
    const ans = await offers.respond({ applicationId: appId, providerId: String(S.sohane._id), index: 0, answer: 'accept', awaitEffects: true });
    expect(ans.ok).toBe(true);
    expect((await freshApp(appId)).pricing).toMatchObject({ totalPrice: 45, commission: 7.5, netPayout: 37.5, negotiated2211: true });
    INTENTS.length = 0;
    const r = await respond(appId, { action: 'accept', payLater: true });
    expect(r.status).toBe(200);
    expect(INTENTS).toHaveLength(0);
    const id = String((await freshApp(appId)).bookingId);
    expect((await freshBooking(id)).pricing).toMatchObject({ totalPrice: 45, commission: 7.5, netPayout: 37.5, commissionRate: 0.2, currency: 'EUR' });
    expect((await freshApp(appId)).pricing).toMatchObject({ totalPrice: 45, negotiated2211: true });
    const pay = await request(app).post(`${API}/bookings/${id}/create-payment-intent`).set(hdr(S.owner._id, 'owner')).send({});
    expect(pay.status).toBe(200);
    expect(INTENTS).toHaveLength(1);
    expect(INTENTS[0]).toMatchObject({ amount: 4500, currency: 'EUR' });
    // libérée à l'échéance : le prix négocié reste celui de la candidature
    await shift(id, new Date(Date.now() - 49 * H), new Date(Date.now() - H));
    expect((await svc().runRelease()).released.map((x) => x.bookingId)).toEqual([id]);
    expect((await freshApp(appId)).pricing).toMatchObject({ totalPrice: 45, negotiated2211: true });
    expect((await freshApp(appId)).status).toBe('pending');
  }, 60000);

  test('admin GET /admin/pay-later-2211 : compteurs + lignes, lecture seule, ni e-mail ni téléphone ni nom ; réservé à l’admin', async () => {
    expect((await request(app).get(`${API}/admin/pay-later-2211`).set(hdr(S.owner._id, 'owner'))).status).toBe(403);
    const before = await Booking.find({}).lean();
    const r = await request(app).get(`${API}/admin/pay-later-2211`).set(ADMIN).expect(200);
    expect(r.body).toMatchObject({ enabled: true, switch: 'on', total: 5, counts: { waiting: 0, due: 0, paid: 1, released: 4, cancelled: 0 } });
    expect(r.body.lines).toHaveLength(5);
    const line = r.body.lines.find((x) => x.bookingId === S.booking);
    expect(line).toMatchObject({ applicationId: S.appHanene, ownerId: String(S.owner._id), providerRole: 'sitter', providerId: String(S.hanene._id), amount: 21.6, currency: 'EUR', state: 'released', reminders: 2 });
    const raw = JSON.stringify(r.body);
    expect(raw).not.toMatch(/@|example\.org|Essai|Karine|Hanene|phone/i);
    expect(JSON.stringify(await Booking.find({}).lean())).toBe(JSON.stringify(before));
    process.env.PAY_LATER_2211 = 'off';
    const off = await request(app).get(`${API}/admin/pay-later-2211`).set(ADMIN).expect(200);
    delete process.env.PAY_LATER_2211;
    expect(off.body).toMatchObject({ enabled: false, switch: 'off', total: 5 });
  }, 60000);
});
