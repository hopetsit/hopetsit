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
    cancelPaymentIntent: jest.fn(async (id) => { if (mockIntent.cancelFails && mockIntent.cancelFails[id]) { if (typeof mockIntent.cancelFails[id] === 'function') mockIntent.cancelFails[id](); throw new Error('cannot cancel'); } CANCELLED.push(id); return { id, status: 'CANCELLED' }; }),
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
  S.owner = await Owner.create({ ...fr, name: 'Karine Essai', email: 'zoe2211.karine@example.org', acceptedTerms: true });
  S.ownerTest = await Owner.create({ ...fr, name: 'Compte Essai', email: 'zoe2211+test@example.org', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  S.petTest = await Pet.create({ ownerId: S.ownerTest._id, petName: 'Max', petType: 'dog' });
  S.hanene = await Sitter.create({ ...fr, name: 'Hanene Essai', email: 'zoe2211.hanene@example.org', dailyRate: 18 });
  S.sohane = await Sitter.create({ ...fr, name: 'Sohane Essai', email: 'zoe2211.sohane@example.org', dailyRate: 50 });
  S.imane = await Walker.create({ ...fr, name: 'Imane Essai', email: 'zoe2211.imane@example.org', walkRates: [{ durationMinutes: 30, basePrice: 12, currency: 'EUR', enabled: true }] });
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


// ───────────── ZOE 22/11 — contrôle indépendant : chercher à casser « payer plus tard » ─────────────
const run = (opts = {}) => svc().runRelease(opts);
const hold = async (d, sitter, owner = S.owner, pet = S.pet) => {
  const x = await sitting(d, sitter, owner, pet);
  const r = await respond(x.appId, { action: 'accept', payLater: true }, owner);
  expect(r.status).toBe(200);
  return { ...x, bookingId: String((await freshApp(x.appId)).bookingId) };
};
const intentFor = async (bookingId, who = S.owner) => {
  const r = await request(app).post(`${API}/bookings/${bookingId}/create-payment-intent`).set(hdr(who._id, 'owner')).send({});
  expect(r.status).toBe(200);
  return (await freshBooking(bookingId)).airwallexPaymentIntentId;
};
const expire = (bookingId) => shift(bookingId, new Date(Date.now() - 49 * H), new Date(Date.now() - H));

describe('A. Entrées tordues et droits', () => {
  test('`payLater` tordu (1, "yes", objet, tableau, "false", null) : accept ORDINAIRE (intention créée, pas d’échéance)', async () => {
    let d = 30;
    for (const v of [1, 'yes', { a: 1 }, [true], 'false', null, 'TRUE']) {
      const { appId } = await sitting(d++, S.hanene);
      INTENTS.length = 0;
      const r = await respond(appId, { action: 'accept', payLater: v });
      expect(r.status).toBe(200);
      expect(r.body.payLater2211).toBeUndefined();
      expect(INTENTS).toHaveLength(1);
      const b = await freshBooking((await freshApp(appId)).bookingId);
      expect(b.payLater2211 && b.payLater2211.at).toBeFalsy();
    }
  }, 120000);

  test('un AUTRE propriétaire, un gardien, un anonyme : refusés, rien n’est écrit', async () => {
    const { appId } = await sitting(40, S.sohane);
    const n = await Booking.countDocuments({});
    const other = await respond(appId, { action: 'accept', payLater: true }, S.ownerTest);
    expect(other.status).toBe(403);
    const asSitter = await request(app).post(`${API}/applications/${appId}/respond`).set(hdr(S.sohane._id, 'sitter')).send({ action: 'accept', payLater: true });
    expect(asSitter.status).toBe(403);
    const anon = await request(app).post(`${API}/applications/${appId}/respond`).send({ action: 'accept', payLater: true });
    expect(anon.status).toBe(401);
    expect((await freshApp(appId)).status).toBe('pending');
    expect(await Booking.countDocuments({})).toBe(n);
  }, 60000);
});

describe('B. Argent : jamais une réservation payée libérée, jamais un paiement après libération', () => {
  test('paiement abouti ENTRE la lecture de l’intention et la libération : pas libérée, aucune notification « libérée »', async () => {
    const h = await hold(41, S.hanene);
    const pid = await intentFor(h.bookingId);
    await expire(h.bookingId);
    // la 1re lecture dit « ouverte » ; au moment d'annuler, Airwallex refuse : le paiement vient d'aboutir
    mockIntent.cancelFails = { [pid]: () => { mockIntent.status[pid] = 'SUCCEEDED'; } };
    const before = await Notification.countDocuments({});
    const r = await run();
    mockIntent.cancelFails = {};
    expect(r.released).toEqual([]);
    expect(r.skipped.intent_succeeded).toBe(1);
    const b = await freshBooking(h.bookingId);
    expect(b.status).toBe('agreed');
    expect(b.payLater2211.releasedAt || null).toBeNull();
    expect((await freshApp(h.appId)).status).toBe('accepted');
    expect(String((await Post.findById(h.post.id).lean()).reservedBy.bookingId)).toBe(h.bookingId);
    expect(await Notification.countDocuments({})).toBe(before);
    // le webhook arrive ensuite : payée, et plus jamais libérée
    await Booking.updateOne({ _id: h.bookingId }, { $set: { status: 'paid', paymentStatus: 'paid', paidAt: new Date() } });
    expect((await run()).released).toEqual([]);
    expect((await freshBooking(h.bookingId)).status).toBe('paid');
  }, 60000);

  test('annulation refusée et intention illisible : rien n’est libéré, le verrou est rendu, le passage suivant libère', async () => {
    const h = await hold(42, S.hanene);
    const pid = await intentFor(h.bookingId);
    await expire(h.bookingId);
    mockIntent.cancelFails = { [pid]: () => { mockIntent.status[pid] = 'ERR'; } };
    let r = await run();
    expect(r.released).toEqual([]);
    expect((await freshBooking(h.bookingId)).status).toBe('agreed');
    expect((await freshBooking(h.bookingId)).payLater2211.claimAt || null).toBeNull();
    mockIntent.cancelFails = {}; delete mockIntent.status[pid];
    CANCELLED.length = 0;
    r = await run();
    expect(r.released.map((x) => x.bookingId)).toEqual([h.bookingId]);
    expect(CANCELLED).toEqual([pid]);
    expect((await freshBooking(h.bookingId)).status).toBe('cancelled');
  }, 60000);

  test('redémarrage après l’annulation de l’intention (déjà CANCELLED chez Airwallex) : le passage suivant libère quand même', async () => {
    const h = await hold(43, S.hanene);
    const pid = await intentFor(h.bookingId);
    await expire(h.bookingId);
    mockIntent.status[pid] = 'CANCELLED';
    mockIntent.cancelFails = { [pid]: true };
    const r = await run();
    mockIntent.cancelFails = {};
    expect(r.released.map((x) => x.bookingId)).toEqual([h.bookingId]);
    expect((await freshApp(h.appId)).status).toBe('pending');
  }, 60000);

  test('deux balayages EN MÊME TEMPS : libérée une seule fois, 2 notifications en tout', async () => {
    const h = await hold(44, S.sohane);
    await expire(h.bookingId);
    const before = await Notification.countDocuments({});
    const [a, b] = await Promise.all([run(), run()]);
    expect(a.released.length + b.released.length).toBe(1);
    expect(await Notification.countDocuments({})).toBe(before + 2);
    const a2 = await freshApp(h.appId);
    expect([a2.status, a2.bookingId || null]).toEqual(['pending', null]);
    expect((await Post.findById(h.post.id).lean()).reservedBy.bookingId || null).toBeNull();
  }, 60000);

  test('payer une réservation LIBÉRÉE : « Payer maintenant » refusé (400), aucune intention créée', async () => {
    const h = await hold(45, S.sohane);
    await expire(h.bookingId);
    await run();
    INTENTS.length = 0;
    const r = await request(app).post(`${API}/bookings/${h.bookingId}/create-payment-intent`).set(hdr(S.owner._id, 'owner')).send({});
    expect(r.status).toBe(400);
    expect(INTENTS).toHaveLength(0);
  }, 60000);
});

describe('C. États après coup, autres candidats, abus', () => {
  test('choisir un AUTRE gardien pendant les 48 h : l’ancien choix est fermé, jamais de message « libérée », un seul réservé par demande', async () => {
    const x = await sitting(46, S.hanene);
    const appB = await apply(x.post, S.sohane, 'sitter', { serviceType: 'pet_sitting', serviceDate: day(46), startDate: day(46), endDate: day(46) });
    expect((await respond(x.appId, { action: 'accept', payLater: true })).status).toBe(200);
    const h = { ...x, bookingId: String((await freshApp(x.appId)).bookingId) };
    // pendant la réservation : un nouveau gardien ne peut plus candidater (demande « réservée »)
    const late = await request(app).post(`${API}/applications?ownerId=${S.owner._id}`).set(hdr(S.imane._id, 'walker')).send({ postId: x.post.id, description: 'x', timeSlot: 'morning', serviceType: 'pet_sitting', serviceDate: day(46), startDate: day(46), endDate: day(46) });
    console.log('candidature pendant la réservation →', late.status, late.body.code); // eslint-disable-line no-console
    const r = await respond(appB, { action: 'accept', payLater: true });
    expect(r.status).toBe(200);
    expect((await freshBooking(h.bookingId)).status).toBe('cancelled');
    expect((await freshApp(h.appId)).status).toBe('rejected');
    const bB = String((await freshApp(appB)).bookingId);
    expect(String((await Post.findById(h.post.id).lean()).reservedBy.bookingId)).toBe(bB);
    await expire(h.bookingId);
    const before = await Notification.countDocuments({ 'data.templateKey': /released/ });
    expect((await run()).released).toEqual([]);
    expect(await Notification.countDocuments({ 'data.templateKey': /released/ })).toBe(before);
    S.multiPost = h.post; S.multiB = appB; S.multiBk = bB;
  }, 60000);

  test('boucle : réservé, expiré, re-réservé → refusé sur le même candidat ; double clic simultané → une seule réservation ouverte', async () => {
    await expire(S.multiBk);
    await run();
    const again = await respond(S.multiB, { action: 'accept', payLater: true });
    expect([again.status, again.body.code]).toEqual([409, 'PAY_LATER_ALREADY_USED']);
    const x = await sitting(47, S.hanene);
    const n = await Booking.countDocuments({});
    const [r1, r2] = await Promise.all([respond(x.appId, { action: 'accept', payLater: true }), respond(x.appId, { action: 'accept', payLater: true })]);
    const created = (await Booking.countDocuments({})) - n;
    console.log('double clic →', r1.status, r2.status, 'réservations créées :', created); // eslint-disable-line no-console
    // les deux échéances passent : UNE seule libération annoncée (2 notifications), la réservation en double est annulée sans bruit
    const bks = await Booking.find({ 'payLater2211.applicationId': x.appId }).select('_id').lean();
    for (const b of bks) await expire(b._id);
    const before = await Notification.countDocuments({ 'data.templateKey': /released/ });
    const rep = await run();
    expect(rep.released).toHaveLength(1);
    expect(await Notification.countDocuments({ 'data.templateKey': /released/ })).toBe(before + 2);
    expect(await Booking.countDocuments({ 'payLater2211.applicationId': x.appId, status: 'cancelled' })).toBe(bks.length);
    const a = await freshApp(x.appId);
    expect([a.status, a.bookingId || null]).toEqual(['pending', null]);
  }, 60000);

  test('annulation par le propriétaire (cancelBooking) : 200 non payé, 409 déjà annulé, 409 payé, 403 mauvais propriétaire', async () => {
    const h = await hold(48, S.sohane);
    const url = (id, q = `sitterId=${S.sohane._id}`) => `${API}/bookings/${id}/cancel?${q}`;
    const routes = require('fs').readFileSync(require('path').join(__dirname, '../src/routes/bookingRoutes.js'), 'utf8');
    const m = routes.match(/router\.(\w+)\('([^']+)'[^\n]*cancelBooking\b/);
    console.log('route cancelBooking →', m && m[1], m && m[2]); // eslint-disable-line no-console
    const call = (id, who, q) => request(app)[m[1]](`${API}/bookings${m[2].replace(':id', id)}?${q || `sitterId=${S.sohane._id}`}`).set(hdr(who._id, 'owner')).send({});
    const wrong = await call(h.bookingId, S.ownerTest);
    expect(wrong.status).toBe(403);
    const noq = await request(app)[m[1]](`${API}/bookings${m[2].replace(':id', h.bookingId)}`).set(hdr(S.owner._id, 'owner')).send({});
    expect(noq.status).toBe(400);
    const ok = await call(h.bookingId, S.owner);
    expect(ok.status).toBe(200);
    expect(ok.body.message).toBe('Booking cancelled.');
    expect(ok.body.booking.status).toBe('cancelled');
    expect((await freshBooking(h.bookingId))).toMatchObject({ status: 'cancelled', paymentStatus: 'cancelled' });
    expect((await Post.findById(h.post.id).lean()).reservedBy.bookingId || null).toBeNull();
    const twice = await call(h.bookingId, S.owner);
    expect([twice.status, twice.body.error]).toEqual([409, 'Booking already cancelled.']);
    const a = await freshApp(h.appId);
    console.log('après cancelBooking : candidature', a.status, 'bookingId', !!a.bookingId, 'vue', JSON.stringify(await viewOf(h.appId))); // eslint-disable-line no-console
    await expire(h.bookingId);
    expect((await run()).released).toEqual([]);
    const p = await hold(49, S.sohane);
    await Booking.updateOne({ _id: p.bookingId }, { $set: { paymentStatus: 'paid' } });
    const paid = await call(p.bookingId, S.owner);
    expect([paid.status, paid.body.code]).toEqual([409, 'PAID_BOOKING_USE_SELF_CANCEL']);
    expect((await freshBooking(p.bookingId)).status).toBe('agreed');
    void url;
  }, 60000);

  test('formulaire de carte fermé dans l’app (cancel-payment-intent) : les relances « payer plus tard » partent-elles encore ?', async () => {
    const h = await hold(50, S.hanene);
    await intentFor(h.bookingId);
    const routes = require('fs').readFileSync(require('path').join(__dirname, '../src/routes/bookingRoutes.js'), 'utf8');
    const m = routes.match(/router\.(\w+)\('([^']+)'[^\n]*cancelBookingPaymentIntent\b/);
    const r = await request(app)[m[1]](`${API}/bookings${m[2].replace(':id', h.bookingId)}`).set(hdr(S.owner._id, 'owner')).send({});
    expect(r.status).toBe(200);
    const b = await freshBooking(h.bookingId);
    console.log('après fermeture du formulaire : paymentStatus', b.paymentStatus, 'status', b.status, 'vue', (await viewOf(h.appId)).status); // eslint-disable-line no-console
    await shift(h.bookingId, new Date(Date.now() - 25 * H), new Date(Date.now() + 23 * H));
    const rep = await reminders().runPaymentReminders({ now: new Date(), force: true, dryRun: true });
    expect(rep.wouldSend.filter((x) => x.bookingId === h.bookingId).map((x) => x.slot)).toEqual(['r1']);
    // réservation ORDINAIRE au formulaire refermé : toujours aucune relance (comportement d'avant)
    const y = await sitting(52, S.hanene);
    expect((await respond(y.appId, { action: 'accept' })).status).toBe(200);
    const yb = String((await freshApp(y.appId)).bookingId);
    await Booking.updateOne({ _id: yb }, { $set: { paymentStatus: 'cancelled', agreedAt: new Date(Date.now() - 2 * H) } });
    const rep2 = await reminders().runPaymentReminders({ now: new Date(), force: true, dryRun: true });
    expect(rep2.wouldSend.filter((x) => x.bookingId === yb)).toEqual([]);
  }, 60000);

  test('« Proposer mon prix » en attente au moment de réserver : réservation au prix affiché, la réponse du gardien n’y change plus rien', async () => {
    const x = await sitting(51, S.sohane);
    const o = await request(app).post(`${API}/applications/${x.appId}/price-offer`).set(hdr(S.owner._id, 'owner')).send({ amount: 50 });
    console.log('offre →', o.status, JSON.stringify(o.body).slice(0, 200)); // eslint-disable-line no-console
    const r = await respond(x.appId, { action: 'accept', payLater: true });
    expect(r.status).toBe(200);
    const bid = String((await freshApp(x.appId)).bookingId);
    expect((await freshBooking(bid)).pricing.totalPrice).toBe(60);
    if (o.status === 201) {
      const ans = await require('../src/services/priceOffer2211').respond({ applicationId: x.appId, providerId: String(S.sohane._id), index: 0, answer: 'accept', awaitEffects: true });
      console.log('réponse du gardien pendant la réservation →', JSON.stringify(ans).slice(0, 200)); // eslint-disable-line no-console
      expect((await freshBooking(bid)).pricing.totalPrice).toBe(60);
      expect((await freshApp(x.appId)).pricing.totalPrice).toBe(60);
    }
  }, 60000);
});
