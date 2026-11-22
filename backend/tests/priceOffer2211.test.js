// 2211 — « PROPOSER MON PRIX » (mesure du 22/11/2026 : 55 propriétaires voient leurs candidats, 0 paie ;
// deux étaient d'accord avec le gardien sur un prix plus bas, que rien ne permettait d'enregistrer).
//   1. Formule : total négocié → base / commission / net, taux de commission INCHANGÉ.
//   2. Validations de la proposition (interrupteur, appartenance, bornes 40 % / strictement inférieur, dates).
//   3. Message dans la conversation + e-mail au gardien (même non vérifié) avec lien signé ; page de réponse
//      (GET n'écrit rien, POST avec « Origin: null », faux jeton = 400 HTML, jamais 500).
//   4. Refus → prix inchangé ; acceptation → pricing cohérent ; limite de 2 ; expiration 48 h / début du service.
//   5. Garde-fous : un prix négocié valable est respecté (filet 2610, « prix à confirmer » 3110, recalculs 620,
//      réservation et intention de paiement au prix négocié) ; un prix incohérent NON négocié est toujours
//      corrigé / bloqué ; les dates changent → prix négocié annulé, retour au prix du moteur.
// VRAIE base Mongo en mémoire, VRAIE application Express. Zone fictive lat -35 / lng -30. Aucun envoi réel.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.PRICE_OFFER_2211;
delete process.env.PRICE_OFFER_EMAIL_UNVERIFIED;
delete process.env.PUBLIC_API_URL;

const INTENTS = [];
jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}` })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async (body) => { INTENTS.push(body); return { id: `int_2211_${INTENTS.length}`, client_secret: 'cs', status: 'REQUIRES_PAYMENT_METHOD', amount: body.amount / 100, currency: body.currency }; }),
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

const inDays = (n) => new Date(Date.now() + n * 86400000);
const day = (n) => `${inDays(n).toISOString().slice(0, 10)}T00:00:00.000Z`;
let mongo; let app;
let Owner; let Sitter; let Walker; let Pet; let Post; let Application; let Booking; let Message;
const PASS = 'MotDePasseTest2211!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const API = '/api/v1';
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+621' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const S = {};

const svc = () => require('../src/services/priceOffer2211');
const settle = async () => { await svc().effects(); };
const offer = async (appId, amount, who = S.ownerUs) => {
  const r = await request(app).post(`${API}/applications/${appId}/price-offer`).set(hdr(who._id, 'owner')).send({ amount });
  await settle();
  return r;
};
// D'autres e-mails (candidature reçue, candidature acceptée…) partent en arrière-plan, sans être attendus :
// on cherche toujours NOS e-mails par destinataire ET par objet, jamais « le dernier reçu ».
const mailsTo = (email, subject = /./) => MAILS.filter((m) => m.to === email && subject.test(m.subject));
const OFFER_MAIL = /^(Price offer|Proposition de prix)/;
const ANSWER_MAIL = /(accepted your price|prefers to keep their price|a accepté votre prix|préfère garder son prix)/;
const ours = () => MAILS.filter((m) => OFFER_MAIL.test(m.subject) || ANSWER_MAIL.test(m.subject)).length;
const tokenIn = (html) => { const m = String(html).match(/\/price-offer\/([A-Za-z0-9_.%-]+)/); return m ? decodeURIComponent(m[1]) : ''; };
const page = (token) => `${API}/price-offer/${token}`;
const formActions = (html) => [...String(html).matchAll(/action="([^"]+)"/g)].map((m) => m[1].replace(/&amp;/g, '&'));
const fresh = (id) => Application.findById(id).lean();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Booking = require('../src/models/Booking'); Message = require('../src/models/Message');
  require('../src/models/Block');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Booking.init()]);
  app = require('../src/app');
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  const us = { password: PASS, city: 'Zone test', country: 'US', currency: 'USD', verified: true, location: ZONE, appLocale: 'en' };
  S.owner = await Owner.create({ ...fr, name: 'Karine Essai', email: 'prix2211.karine@example.org', acceptedTerms: true });
  S.ownerUs = await Owner.create({ ...us, name: 'Lillian Essai', email: 'prix2211.lillian@example.org', acceptedTerms: true });
  S.other = await Owner.create({ ...fr, name: 'Autre Essai', email: 'prix2211.autre@example.org', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  S.petUs = await Pet.create({ ownerId: S.ownerUs._id, petName: 'Max', petType: 'dog' });
  S.hanene = await Sitter.create({ ...fr, name: 'Hanene Essai', email: 'prix2211.hanene@example.org', dailyRate: 18 });
  S.sohane = await Sitter.create({ ...fr, name: 'Sohane Essai', email: 'prix2211.sohane@example.org', dailyRate: 50 });
  S.imane = await Walker.create({ ...fr, name: 'Imane Essai', email: 'prix2211.imane@example.org', walkRates: [{ durationMinutes: 30, basePrice: 12, currency: 'EUR', enabled: true }] });
  S.nieheem = await Sitter.create({ ...us, name: 'Nieheem Essai', email: 'prix2211.nieheem@example.org', dailyRate: 35 });
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const createPost = (body, who = S.owner, pet = S.pet) => request(app).post(`${API}/posts`).set(hdr(who._id, 'owner')).send({
  body: 'Demande de test 2211, zone test.', language: 'fr', animalCount: 1, animalTypes: ['dog'], petIds: [String(pet._id)], location: LOC, ...body,
});
const apply = async (post, who, role, extra = {}, owner = S.owner) => {
  const r = await request(app).post(`${API}/applications?ownerId=${owner._id}`).set(hdr(who._id, role)).send({
    postId: post.id || String(post._id), description: 'Je suis disponible.', timeSlot: 'morning', ...extra,
  });
  if (r.status !== 201) console.log('apply →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
  expect(r.status).toBe(201);
  return String(r.body.application.id || r.body.application._id);
};

describe('1. Formule du prix négocié (inverse de calculateTotalWithAddOns)', () => {
  test('42 $ à 20 %, proposition 30 $ → base 25, commission 5, net 25 ; taux inchangé', () => {
    const p = svc().negotiatedPricing({ basePrice: 35, appliedRate: 35, quantity: 1, unit: 'day', totalPrice: 42, commission: 7, netPayout: 35, commissionRate: 0.2, currency: 'USD' }, 30);
    expect(p).toMatchObject({ totalPrice: 30, basePrice: 25, commission: 5, netPayout: 25, commissionRate: 0.2, currency: 'USD', negotiated2211: true, quantity: 1, unit: 'day' });
    expect(p.appliedRate).toBe(25); // tarif unitaire réduit dans la même proportion : total ≥ tarif reste vrai
    const { calculateTotalWithAddOns } = require('../src/utils/pricing');
    expect(calculateTotalWithAddOns(p.netPayout, [], 'USD', 0.2)).toMatchObject({ totalPrice: 30, commission: 5, netPayout: 25 });
  });
  test('toujours : total = net + commission au centime, taux inchangé (20 % et 15 % Top), commission = net × taux à 1 centime près', () => {
    for (const rate of [0.2, 0.15]) {
      for (const amount of [29.99, 10.01, 17.5, 133.33, 0.99, 250]) {
        const p = svc().negotiatedPricing({ totalPrice: 400, appliedRate: 20, commissionRate: rate, currency: 'EUR' }, amount);
        expect(p.commissionRate).toBe(rate);
        expect(Math.round(p.totalPrice * 100)).toBe(Math.round(amount * 100));
        expect(Math.round((p.netPayout + p.commission) * 100)).toBe(Math.round(p.totalPrice * 100));
        expect(Math.round((p.totalPrice - p.commission) * 100)).toBe(Math.round(p.netPayout * 100));
        expect(Math.abs(p.commission - p.netPayout * rate)).toBeLessThanOrEqual(0.01 + 1e-9);
        expect(p.basePrice).toBe(p.netPayout);
      }
    }
  });
  test('isIncoherentTotal : un prix négocié reste cohérent, un total < tarif NON négocié reste incohérent', () => {
    const { isIncoherentTotal } = require('../src/services/applicationRepricing620');
    expect(isIncoherentTotal(svc().negotiatedPricing({ totalPrice: 42, appliedRate: 35, commissionRate: 0.2 }, 30))).toBe(false);
    expect(isIncoherentTotal({ totalPrice: 2.7, appliedRate: 18 })).toBe(true);
    expect(isIncoherentTotal({ totalPrice: 2.7, appliedRate: 18, negotiated2211: true })).toBe(true); // le marqueur seul n'excuse rien
  });
  test('jeton : signé, lié à une proposition et une réponse ; faux, expiré ou d’un autre service refusés', () => {
    const a = String(new mongoose.Types.ObjectId()); const p = String(new mongoose.Types.ObjectId());
    const t = svc().signOfferLink({ applicationId: a, providerId: p, index: 1, answer: 'decline', now: 1000 });
    expect(svc().verifyOfferLink(t, 2000)).toEqual({ ok: true, applicationId: a, providerId: p, index: 1, answer: 'decline' });
    expect(svc().verifyOfferLink(t, 1000 + svc().LINK_TTL + 1).reason).toBe('expired');
    expect(svc().verifyOfferLink(`${t.slice(0, -2)}${t.endsWith('AA') ? 'BB' : 'AA'}`).reason).toBe('signature');
    const free = require('../src/services/sitterFree1011').signAnswerLink({ applicationId: a, providerId: p, answer: 'yes' });
    expect(svc().verifyOfferLink(free).ok).toBe(false);
    expect(svc().verifyOfferLink('abc.def').ok).toBe(false);
  });
});

describe('2. Proposition du propriétaire : validations', () => {
  test('préparation : garde US 1 jour à 35 $ → total 42 $ (commission 7 $, 20 %)', async () => {
    S.postUs = (await createPost({ serviceTypes: ['pet_sitting'], dateMode: 'exact', startDate: day(20), endDate: day(20) }, S.ownerUs, S.petUs).expect(201)).body.post;
    S.appUs = await apply(S.postUs, S.nieheem, 'sitter', { serviceType: 'pet_sitting', serviceDate: day(20), startDate: day(20), endDate: day(20) }, S.ownerUs);
    expect((await fresh(S.appUs)).pricing).toMatchObject({ totalPrice: 42, commission: 7, netPayout: 35, commissionRate: 0.2, currency: 'USD', appliedRate: 35 });
    // Le gardien n'a jamais validé son e-mail : il doit quand même recevoir la proposition.
    await Sitter.updateOne({ _id: S.nieheem._id }, { $set: { verified: false } });
  }, 60000);

  test('interrupteur PRICE_OFFER_2211=off : 404 OFFER_DISABLED et le site ne propose plus ; rallumé par défaut', async () => {
    process.env.PRICE_OFFER_2211 = 'off';
    const r = await offer(S.appUs, 30);
    expect(r.status).toBe(404);
    expect(r.body.code).toBe('OFFER_DISABLED');
    const off = await request(app).get(`${API}/applications/my`).set(hdr(S.ownerUs._id, 'owner')).expect(200);
    expect(off.body.applications[0].priceOffer2211View).toMatchObject({ enabled: false, canOffer: false });
    delete process.env.PRICE_OFFER_2211;
    const on = await request(app).get(`${API}/applications/my`).set(hdr(S.ownerUs._id, 'owner')).expect(200);
    expect(on.body.applications[0].priceOffer2211View).toMatchObject({ enabled: true, canOffer: true, count: 0, max: 2, status: null, currentTotal: 42, minAmount: 16.8, currency: 'USD' });
    expect(((await fresh(S.appUs)).priceOffer2211 || {}).offers || []).toHaveLength(0);
  }, 60000);

  test('appartenance, rôle et bornes : 401 / 403 / OFFER_INVALID / OFFER_NOT_LOWER / OFFER_TOO_LOW — rien n’est écrit ni envoyé', async () => {
    const before = ours();
    expect((await request(app).post(`${API}/applications/${S.appUs}/price-offer`).send({ amount: 30 })).status).toBe(401);
    expect((await request(app).post(`${API}/applications/${S.appUs}/price-offer`).set(hdr(S.nieheem._id, 'sitter')).send({ amount: 30 })).status).toBe(403);
    expect((await offer(S.appUs, 30, S.other)).status).toBe(403);
    expect((await offer(String(new mongoose.Types.ObjectId()), 30)).status).toBe(404);
    for (const bad of [undefined, null, '', 'abc', 0, -5, true]) {
      const r = await offer(S.appUs, bad);
      expect([r.status, r.body.code]).toEqual([400, 'OFFER_INVALID']);
    }
    for (const same of [42, 42.004, 50, 4200]) {
      const r = await offer(S.appUs, same);
      expect([r.status, r.body.code]).toEqual([400, 'OFFER_NOT_LOWER']);
    }
    for (const low of [16.79, 5, 0.01]) {
      const r = await offer(S.appUs, low);
      expect([r.status, r.body.code]).toEqual([400, 'OFFER_TOO_LOW']);
      expect(r.body).toMatchObject({ minAmount: 16.8, currentTotal: 42, currency: 'USD' });
    }
    expect(((await fresh(S.appUs)).priceOffer2211 || {}).offers || []).toHaveLength(0);
    expect(ours()).toBe(before);
  }, 60000);

  test('demande « dates à prévoir » → 409 DATES_REQUIRED ; candidature déjà refusée → 409 OFFER_NOT_PENDING', async () => {
    const tbd = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'tbd' }).expect(201)).body.post;
    const a = await apply(tbd, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(5) });
    const r = await offer(a, 10, S.owner);
    expect([r.status, r.body.code]).toEqual([409, 'DATES_REQUIRED']);
    await Application.updateOne({ _id: a }, { $set: { status: 'rejected' } });
    const r2 = await offer(a, 10, S.owner);
    expect([r2.status, r2.body.code]).toEqual([409, 'OFFER_NOT_PENDING']);
  }, 60000);
});

describe('3. Envoi au gardien et page de réponse', () => {
  test('proposition 20 $ (≥ 40 %) : 201, message du propriétaire dans la conversation (sa langue), e-mail au gardien NON vérifié avec lien signé', async () => {
    const r = await offer(S.appUs, '20');
    if (r.status !== 201) console.log('offer →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    expect(r.body.offer).toMatchObject({ index: 0, amount: 20, currency: 'USD', status: 'pending', originalTotal: 42 });
    expect(r.body.priceOffer2211View).toMatchObject({ canOffer: false, status: 'pending', amount: 20, count: 1 });
    const saved = await fresh(S.appUs);
    expect(saved.priceOffer2211.offers).toHaveLength(1);
    expect(saved.pricing.totalPrice).toBe(42); // rien ne change avant la réponse
    const exp = new Date(saved.priceOffer2211.offers[0].expiresAt).getTime() - new Date(saved.priceOffer2211.offers[0].createdAt).getTime();
    expect(exp).toBe(48 * 3600 * 1000);
    const msg = await Message.findOne({ senderRole: 'owner', senderId: S.ownerUs._id }).sort({ createdAt: -1 }).lean();
    expect(msg && msg.body).toBe('I would like to offer $20 in total for this request.');
    const mails = mailsTo('prix2211.nieheem@example.org', OFFER_MAIL);
    expect(mails).toHaveLength(1);
    expect(mails[0].subject).toBe('Price offer: $20 for your application');
    expect(mails[0].html).toContain('You will receive');
    expect(mails[0].html).toContain('$16.67');
    S.tokenUs0 = tokenIn(mails[0].html);
    expect(svc().verifyOfferLink(S.tokenUs0)).toMatchObject({ ok: true, applicationId: S.appUs, providerId: String(S.nieheem._id), index: 0, answer: 'accept' });
  }, 60000);

  test('une seule proposition en attente : 409 OFFER_LIMIT (reason pending)', async () => {
    const r = await offer(S.appUs, 30);
    expect([r.status, r.body.code, r.body.reason]).toEqual([409, 'OFFER_LIMIT', 'pending']);
    expect((await fresh(S.appUs)).priceOffer2211.offers).toHaveLength(1);
  }, 60000);

  test('faux jeton : 400 HTML en GET et en POST avec « Origin: null » (jamais 500) ; page servie en Referrer-Policy same-origin ; ailleurs « Origin: null » reste refusée', async () => {
    const bad = 'abc.def';
    const viaNull = await request(app).post(page(bad)).set('Origin', 'null').type('form').send('');
    expect(viaNull.status).toBe(400);
    expect(viaNull.headers['content-type']).toMatch(/html/);
    const g = await request(app).get(page(bad));
    expect(g.status).toBe(400);
    expect(g.headers['referrer-policy']).toBe('same-origin');
    expect(g.headers['cache-control']).toBe('no-store');
    const forged = `${S.tokenUs0.slice(0, -2)}${S.tokenUs0.endsWith('AA') ? 'BB' : 'AA'}`;
    expect((await request(app).post(page(forged)).set('Origin', 'null').type('form').send('')).status).toBe(400);
    const elsewhere = await request(app).post(`${API}/auth/login`).set('Origin', 'null').send({});
    expect(elsewhere.status).toBe(500);
    expect((await fresh(S.appUs)).priceOffer2211.offers[0].status).toBe('pending');
  }, 60000);

  test('GET de la page : demande, prix proposé, net du gardien, prix actuel, deux boutons — et RIEN n’est écrit', async () => {
    const g = await request(app).get(page(S.tokenUs0)).set('Accept-Language', 'en');
    expect(g.status).toBe(200);
    expect(g.headers['referrer-policy']).toBe('same-origin');
    expect(g.text).toContain('Price offer');
    expect(g.text).toContain('Zone test');
    expect(g.text).toContain('$20');
    expect(g.text).toContain('You will receive');
    expect(g.text).toContain('$16.67');
    expect(g.text).toContain('$42 (you receive $35)');
    expect(g.text).toContain('Accept · I will receive $16.67');
    expect(g.text).toContain('Decline · keep my price');
    expect(g.text).not.toMatch(/@|prix2211|Lillian/);
    S.actionsUs0 = formActions(g.text);
    expect(S.actionsUs0).toHaveLength(2);
    expect(svc().verifyOfferLink(decodeURIComponent(S.actionsUs0[0].split('/').pop())).answer).toBe('accept');
    expect(svc().verifyOfferLink(decodeURIComponent(S.actionsUs0[1].split('/').pop())).answer).toBe('decline');
    const saved = await fresh(S.appUs);
    expect(saved.priceOffer2211.offers[0].status).toBe('pending');
    expect(saved.pricing.totalPrice).toBe(42);
  }, 60000);
});

describe('4. Refus, acceptation, limite de 2', () => {
  test('REFUS (bouton de la page, « Origin: null ») : prix inchangé, propriétaire prévenu, 2e clic sans effet', async () => {
    const before = ours();
    const r = await request(app).post(S.actionsUs0[1]).set('Origin', 'null').type('form').send('');
    await settle();
    expect(r.status).toBe(200);
    expect(r.text).toContain('you are keeping your price');
    const saved = await fresh(S.appUs);
    expect(saved.priceOffer2211.offers[0].status).toBe('declined');
    expect(saved.pricing).toMatchObject({ totalPrice: 42, commission: 7, netPayout: 35 });
    expect(saved.pricing.negotiated2211).not.toBe(true);
    const mail = mailsTo('prix2211.lillian@example.org', ANSWER_MAIL).pop();
    expect(mail.subject).toBe('Nieheem prefers to keep their price');
    expect(mail.html).toContain('$42');
    const sent = ours() - before;
    expect(sent).toBe(1);
    // après un refus, « accepter » la même proposition ne marche plus ; refuser à nouveau ne renvoie rien
    const again = await request(app).post(S.actionsUs0[0]).set('Origin', 'null').type('form').send('');
    expect(again.status).toBe(410);
    const twice = await request(app).post(S.actionsUs0[1]).set('Origin', 'null').type('form').send('');
    await settle();
    expect(twice.status).toBe(200);
    expect(ours() - before).toBe(sent);
    expect((await fresh(S.appUs)).pricing.totalPrice).toBe(42);
  }, 60000);

  test('2e proposition 30 $ ACCEPTÉE : total 30, commission 5 (20 % inchangé), net 25, ancien bloc gardé ; propriétaire prévenu avec lien signé', async () => {
    const r = await offer(S.appUs, 30);
    expect(r.status).toBe(201);
    expect(r.body.offer.index).toBe(1);
    const mail = mailsTo('prix2211.nieheem@example.org', OFFER_MAIL).pop();
    const g = await request(app).get(page(tokenIn(mail.html)));
    expect(g.text).toContain('Accept · I will receive $25');
    const [acceptUrl] = formActions(g.text);
    const before = MAILS.length;
    const a = await request(app).post(acceptUrl).set('Origin', 'null').type('form').send('');
    await settle();
    expect(a.status).toBe(200);
    expect(a.text).toContain('you accepted $30');
    expect(a.text).toContain('You will receive $25');
    const saved = await fresh(S.appUs);
    expect(saved.status).toBe('pending');
    expect(saved.pricing).toMatchObject({ totalPrice: 30, basePrice: 25, commission: 5, netPayout: 25, commissionRate: 0.2, currency: 'USD', negotiated2211: true, quantity: 1, unit: 'day', indicative: false });
    expect(Math.round((saved.pricing.totalPrice - saved.pricing.commission) * 100)).toBe(Math.round(saved.pricing.netPayout * 100));
    expect(saved.priceOffer2211.offers.map((o) => o.status)).toEqual(['declined', 'accepted']);
    expect(saved.priceOffer2211.previousPricing).toMatchObject({ totalPrice: 42, commission: 7, netPayout: 35, appliedRate: 35 });
    const owner = MAILS.slice(before).filter((m) => m.to === 'prix2211.lillian@example.org' && ANSWER_MAIL.test(m.subject));
    expect(owner).toHaveLength(1);
    expect(owner[0].subject).toBe('Nieheem accepted your price: $30');
    expect(owner[0].html).toContain('Pay $30');
    expect(owner[0].html).toMatch(new RegExp(`/application/${S.appUs}\\?[^"]*k=`));
    // double clic sur « Accepter » : même page, aucun second e-mail, prix identique
    const twice = await request(app).post(acceptUrl).set('Origin', 'null').type('form').send('');
    await settle();
    expect(twice.status).toBe(200);
    expect(MAILS.slice(before).filter((m) => m.to === 'prix2211.lillian@example.org' && ANSWER_MAIL.test(m.subject))).toHaveLength(1);
    // le site reçoit le nouveau total par `pricing`, et l'état de la proposition
    const list = await request(app).get(`${API}/applications/my`).set(hdr(S.ownerUs._id, 'owner')).expect(200);
    const row = list.body.applications.find((x) => String(x.id || x._id) === S.appUs);
    expect(row.pricing.totalPrice).toBe(30);
    expect(row.priceOffer2211View).toMatchObject({ status: 'accepted', amount: 30, canOffer: false, count: 2, negotiated: true });
  }, 60000);

  test('2 propositions au maximum : la 3e → 409 OFFER_LIMIT (reason max)', async () => {
    const r = await offer(S.appUs, 25);
    expect([r.status, r.body.code, r.body.reason]).toEqual([409, 'OFFER_LIMIT', 'max']);
    expect((await fresh(S.appUs)).pricing.totalPrice).toBe(30);
  }, 60000);
});

describe('5. Garde-fous de prix : le prix négocié est respecté, les autres cas restent protégés', () => {
  test('le TARIF DU PROFIL change (35 → 60 $/jour) : le prix négocié reste (recalcul tarif, recalcul admin forcé, matchesExpected)', async () => {
    await Sitter.updateOne({ _id: S.nieheem._id }, { $set: { dailyRate: 60 } });
    const rp = require('../src/services/applicationRepricing620');
    const post = await Post.findById(S.postUs.id);
    const doc = await Application.findById(S.appUs);
    const prov = await Sitter.findById(S.nieheem._id).lean();
    expect(svc().negotiatedState(doc, post)).toEqual({ negotiated: true, valid: true });
    expect(rp.matchesExpected(doc, post, prov, 'sitter', { rate: 60, unit: 'day' })).toBe(true);
    const a = await rp.repriceAfterServiceChange(post, { notify: false, force: true });
    expect(a.aligned).toEqual([S.appUs]);
    expect(a.repriced).toEqual([]);
    const b = await rp.repriceApplicationsForPost(post, { notify: false });
    expect(b.repriced).toEqual([]);
    await rp.repriceAfterRateChange({ providerId: String(S.nieheem._id), providerRole: 'sitter' }, { notify: false });
    const admin = await request(app).post(`${API}/admin/reprice-620/posts/${S.postUs.id}?silent=1`).set(ADMIN).send({}).expect(200);
    expect(admin.body.repriced).toEqual([]);
    expect((await fresh(S.appUs)).pricing).toMatchObject({ totalPrice: 30, commission: 5, netPayout: 25, negotiated2211: true });
  }, 60000);

  test('« Choisir et payer » : la réservation et l’intention de paiement sont au prix NÉGOCIÉ (30 $ = 3 000 centimes), pas au tarif du profil (72 $)', async () => {
    INTENTS.length = 0;
    const r = await request(app).post(`${API}/applications/${S.appUs}/respond`).set(hdr(S.ownerUs._id, 'owner')).send({ action: 'accept' });
    if (r.status !== 200) console.log('accept →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const saved = await fresh(S.appUs);
    expect(saved.status).toBe('accepted');
    expect(saved.pricing).toMatchObject({ totalPrice: 30, commission: 5, netPayout: 25, commissionRate: 0.2, negotiated2211: true });
    const b = await Booking.findById(saved.bookingId).lean();
    expect(b.pricing).toMatchObject({ totalPrice: 30, commission: 5, netPayout: 25, commissionRate: 0.2, currency: 'USD' });
    expect(INTENTS).toHaveLength(1);
    expect(INTENTS[0]).toMatchObject({ amount: 3000, currency: 'USD' });
    expect(r.body.payment).toMatchObject({ amount: 3000, commissionAmount: 500, netSitterAmount: 2500 });
    // une candidature choisie n'est plus négociable
    const late = await offer(S.appUs, 20);
    expect([late.status, late.body.code]).toEqual([409, 'OFFER_NOT_PENDING']);
  }, 60000);

  test('prix incohérent NON négocié : toujours corrigé au choix — même avec un marqueur posé sans proposition acceptée', async () => {
    S.postFr = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(30), endDate: day(44) }).expect(201)).body.post;
    const a = await apply(S.postFr, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(30), startDate: day(30), endDate: day(44) });
    expect((await fresh(a)).pricing.totalPrice).toBe(324);
    await Application.updateOne({ _id: a }, { $set: { 'pricing.totalPrice': 2.7, 'pricing.negotiated2211': true } });
    const post = await Post.findById(S.postFr.id).lean();
    expect(svc().negotiatedState(await fresh(a), post)).toMatchObject({ negotiated: true, valid: false, reason: 'no_offer' });
    const r = await request(app).post(`${API}/applications/${a}/respond`).set(hdr(S.owner._id, 'owner')).send({ action: 'accept' });
    expect(r.status).toBe(200);
    const saved = await fresh(a);
    expect(saved.pricing.totalPrice).toBe(324);
    expect(saved.pricing.negotiated2211).not.toBe(true);
    expect((await Booking.findById(saved.bookingId).lean()).pricing).toMatchObject({ totalPrice: 324, commission: 54, netPayout: 270 });
  }, 60000);

  test('contrôle ZOE : pas de proposition sur un prix stocké FAUX (2,70 € pour 15 jours à 18 €) → 409 OFFER_NO_PRICE, rien d’écrit ; le prix juste reste négociable', async () => {
    const post = (await createPost({ body: 'Garde quinze jours 2211 bis.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(70), endDate: day(84) }).expect(201)).body.post;
    const a = await apply(post, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(70), startDate: day(70), endDate: day(84) });
    expect((await fresh(a)).pricing.totalPrice).toBe(324);
    await Application.updateOne({ _id: a }, { $set: { 'pricing.totalPrice': 2.7, 'pricing.commission': 0.45, 'pricing.netPayout': 2.25, 'pricing.basePrice': 2.25 } });
    const before = ours();
    const r = await offer(a, 1.5, S.owner);
    expect([r.status, r.body.code, r.body.reason]).toEqual([409, 'OFFER_NO_PRICE', 'price_outdated']);
    expect(((await fresh(a)).priceOffer2211 || {}).offers || []).toHaveLength(0);
    expect(ours()).toBe(before);
    await Application.updateOne({ _id: a }, { $set: { 'pricing.totalPrice': 324, 'pricing.commission': 54, 'pricing.netPayout': 270, 'pricing.basePrice': 270 } });
    expect((await offer(a, 300, S.owner)).status).toBe(201);
  }, 60000);

  test('garde-fou 3110 « prix à confirmer » : bloque toujours un petit total périmé, laisse passer un petit total négocié valable, re-bloque si le total a été modifié', () => {
    const sanity = require('../src/utils/priceSanity3110');
    const post = { _id: new mongoose.Types.ObjectId(), postType: 'request', dateMode: 'exact', startDate: new Date(day(30)), endDate: new Date(day(32)), serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home' };
    const prov = { dailyRate: 18, currency: 'EUR' };
    const stale = { pricing: { totalPrice: 8, appliedRate: 18, unit: 'day', quantity: 3, commissionRate: 0.2, currency: 'EUR' } };
    expect(sanity.checkApplication(stale, post, prov, 'sitter')).toEqual({ toVerify: true, reason: 'stale_too_low' });
    const accepted = { amount: 8, status: 'accepted', requestKey: svc().requestKey(post) };
    const negotiated = { pricing: { ...stale.pricing, negotiated2211: true }, priceOffer2211: { offers: [accepted] } };
    expect(sanity.checkApplication(negotiated, post, prov, 'sitter')).toEqual({ toVerify: false, reason: null });
    // marqueur sans proposition acceptée, total ≠ montant accepté, demande changée : garde-fou intact
    expect(sanity.checkApplication({ pricing: { ...stale.pricing, negotiated2211: true } }, post, prov, 'sitter').toVerify).toBe(true);
    expect(sanity.checkApplication({ ...negotiated, pricing: { ...negotiated.pricing, totalPrice: 5 } }, post, prov, 'sitter').toVerify).toBe(true);
    expect(sanity.checkApplication(negotiated, { ...post, endDate: new Date(day(35)) }, prov, 'sitter').toVerify).toBe(true);
    expect(sanity.checkApplication({ ...negotiated, priceOffer2211: { offers: [{ ...accepted, status: 'pending' }] } }, post, prov, 'sitter').toVerify).toBe(true);
  });

  test('les DATES changent → prix négocié ANNULÉ, retour au prix du moteur ; proposition en attente annulée (lien du gardien : 410) ; une modification sans rapport ne touche à rien', async () => {
    const post = (await createPost({ body: 'Garde trois jours 2211.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', dateMode: 'exact', startDate: day(50), endDate: day(52) }).expect(201)).body.post;
    const a = await apply(post, S.hanene, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(50), startDate: day(50), endDate: day(52) });
    const b = await apply(post, S.sohane, 'sitter', { serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: day(50), startDate: day(50), endDate: day(52) });
    expect((await fresh(a)).pricing.totalPrice).toBe(64.8);
    expect((await fresh(b)).pricing.totalPrice).toBe(180);
    expect((await offer(a, 50, S.owner)).status).toBe(201);
    const mailA = mailsTo('prix2211.hanene@example.org', OFFER_MAIL).pop();
    expect(mailA.subject).toMatch(/^Proposition de prix : 50/);
    const pageA = await request(app).get(page(tokenIn(mailA.html)));
    expect(pageA.text).toContain('Vous toucherez');
    const ok = await request(app).post(formActions(pageA.text)[0]).set('Origin', 'null').type('form').send('');
    await settle();
    expect(ok.status).toBe(200);
    expect((await fresh(a)).pricing).toMatchObject({ totalPrice: 50, basePrice: 41.67, commission: 8.33, netPayout: 41.67, commissionRate: 0.2, negotiated2211: true });
    expect(mailsTo('prix2211.karine@example.org', ANSWER_MAIL).pop().subject).toMatch(/^Hanene a accepté votre prix : 50/);
    expect((await offer(b, 150, S.owner)).status).toBe(201);
    const tokenB = tokenIn(mailsTo('prix2211.sohane@example.org', OFFER_MAIL).pop().html);

    // modification sans rapport avec les dates ni le service : rien ne bouge
    await request(app).patch(`${API}/posts/${post.id}`).set(hdr(S.owner._id, 'owner')).send({ body: 'Garde trois jours 2211, texte retouché.' }).expect(200);
    expect((await fresh(a)).pricing).toMatchObject({ totalPrice: 50, negotiated2211: true });
    expect((await fresh(b)).priceOffer2211.offers[0].status).toBe('pending');

    // les dates changent : 3 jours → 4 jours
    await request(app).patch(`${API}/posts/${post.id}`).set(hdr(S.owner._id, 'owner')).send({ dateMode: 'exact', startDate: day(50), endDate: day(53) }).expect(200);
    const afterA = await fresh(a);
    expect(afterA.pricing).toMatchObject({ totalPrice: 86.4, commission: 14.4, netPayout: 72, appliedRate: 18, quantity: 4 });
    expect(afterA.pricing.negotiated2211).not.toBe(true);
    expect(afterA.priceOffer2211.offers[0]).toMatchObject({ status: 'cancelled', reason: 'request_changed' });
    expect(afterA.priceOffer2211.previousPricing).toBeFalsy();
    const afterB = await fresh(b);
    expect(afterB.priceOffer2211.offers[0].status).toBe('cancelled');
    expect(afterB.pricing.negotiated2211).not.toBe(true);
    const gone = await request(app).post(page(tokenB)).set('Origin', 'null').type('form').send('');
    expect(gone.status).toBe(410);
    expect((await request(app).get(page(tokenB))).status).toBe(410);
  }, 90000);
});

describe('6. Expiration et admin', () => {
  test('48 h : la proposition expire (réponse refusée, prix inchangé), une 2e est possible ; au début du service si c’est plus tôt', async () => {
    const post = (await createPost({ body: 'Balades 2211.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, dateMode: 'exact', startDate: day(30), endDate: day(44) }).expect(201)).body.post;
    const a = await apply(post, S.imane, 'walker', { serviceType: 'dog_walking', duration: 30, serviceDate: day(30), startDate: day(30), endDate: day(44) });
    expect((await fresh(a)).pricing.totalPrice).toBe(216);
    const deps = { sendChat: jest.fn(async () => ({ sent: true })), send: jest.fn(async () => ({ sent: true })), push: jest.fn(async () => ({})) };
    const T = new Date();
    const r = await svc().createOffer({ applicationId: a, ownerId: String(S.owner._id), amount: 150, now: T, deps, awaitEffects: true });
    expect(r.status).toBe(201);
    expect(r.body.delivery).toEqual({ chat: 'sent', email: 'sent', push: 'sent' });
    expect(deps.send).toHaveBeenCalledWith(expect.objectContaining({ role: 'walker', type: 'price_offer_2211', userId: String(S.imane._id) }));
    expect(deps.sendChat.mock.calls[0][0]).toMatchObject({ providerRole: 'walker', providerId: String(S.imane._id) });
    expect(deps.sendChat.mock.calls[0][0].body).toMatch(/^Je vous propose 150/);
    const later = new Date(T.getTime() + 49 * 3600 * 1000);
    expect(svc().ownerView(await fresh(a), T.getTime() + 47 * 3600 * 1000)).toMatchObject({ status: 'pending', canOffer: false });
    expect(svc().ownerView(await fresh(a), later.getTime())).toMatchObject({ status: 'expired', canOffer: true, count: 1 });
    const late = await svc().respond({ applicationId: a, providerId: String(S.imane._id), index: 0, answer: 'accept', now: later, deps, awaitEffects: true });
    expect(late).toEqual({ ok: false, reason: 'expired' });
    const saved = await fresh(a);
    expect(saved.priceOffer2211.offers[0].status).toBe('expired');
    expect(saved.pricing.totalPrice).toBe(216);
    expect(saved.pricing.negotiated2211).not.toBe(true);
    const second = await svc().createOffer({ applicationId: a, ownerId: String(S.owner._id), amount: 160, now: later, deps, awaitEffects: true });
    expect(second.status).toBe(201);
    expect(second.body.offer.index).toBe(1);
    const third = await svc().createOffer({ applicationId: a, ownerId: String(S.owner._id), amount: 170, now: new Date(later.getTime() + 49 * 3600 * 1000), deps, awaitEffects: true });
    expect([third.status, third.body.code, third.body.reason]).toEqual([409, 'OFFER_LIMIT', 'max']);

    // service qui commence dans moins de 48 h : la proposition expire au début du service
    const soon = (await createPost({ body: 'Balade très proche 2211.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, dateMode: 'exact', startDate: day(2), endDate: day(6) }).expect(201)).body.post;
    const s = await apply(soon, S.imane, 'walker', { serviceType: 'dog_walking', duration: 30, serviceDate: day(2), startDate: day(2), endDate: day(6) });
    const now = new Date();
    const rs = await svc().createOffer({ applicationId: s, ownerId: String(S.owner._id), amount: 50, now, deps, awaitEffects: true });
    expect(rs.status).toBe(201);
    const exp = new Date(rs.body.offer.expiresAt).getTime();
    expect(exp).toBeLessThan(now.getTime() + 48 * 3600 * 1000);
    expect(exp).toBeGreaterThan(now.getTime());
    expect(Math.abs(exp - new Date(day(2)).getTime())).toBeLessThanOrEqual(14 * 3600 * 1000); // début du service, heure locale du propriétaire
    // demande déjà commencée : plus de proposition
    const past = await svc().createOffer({ applicationId: s, ownerId: String(S.owner._id), amount: 45, now: new Date(new Date(day(2)).getTime() + 15 * 3600 * 1000), deps, awaitEffects: true });
    expect([past.status, past.body.code]).toEqual([409, 'OFFER_REQUEST_CLOSED']);
  }, 90000);

  test('admin en lecture seule : compteurs par statut + dernières lignes, sans e-mail, téléphone ni nom ; réservé à l’admin', async () => {
    expect((await request(app).get(`${API}/admin/price-offers-2211`).set(hdr(S.owner._id, 'owner'))).status).toBe(403);
    const r = await request(app).get(`${API}/admin/price-offers-2211`).set(ADMIN).expect(200);
    expect(r.body.enabled).toBe(true);
    expect(r.body.settings).toEqual({ minRatio: 0.4, maxOffers: 2, ttlHours: 48 });
    expect(r.body.counts.accepted).toBe(1);
    expect(r.body.counts.declined).toBe(1);
    expect(r.body.counts.cancelled).toBe(2);
    expect(r.body.counts.expired).toBeGreaterThanOrEqual(1);
    expect(r.body.total).toBe(r.body.rows.length);
    expect(Object.values(r.body.counts).reduce((x, y) => x + y, 0)).toBe(r.body.total);
    expect(r.body.rows.length).toBeLessThanOrEqual(50);
    const row = r.body.rows.find((x) => x.applicationId === S.appUs && x.status === 'accepted');
    expect(row).toMatchObject({ amount: 30, currency: 'USD', originalTotal: 42, providerRole: 'sitter', negotiated: true, currentTotal: 30, hasBooking: true });
    const raw = JSON.stringify(r.body);
    expect(raw).not.toMatch(/@|prix2211|Essai|Nieheem|Lillian|Hanene|mobile|phone/i);
  }, 60000);
});

describe('7. Une seule négociation aboutie (BOB, relevé de ZOE)', () => {
  test('prix déjà négocié : le site ne propose plus (canOffer faux), même s’il reste une proposition possible', () => {
    const { ownerView } = require('../src/services/priceOffer2211');
    const base = { status: 'pending', pricing: { totalPrice: 30, currency: 'USD' }, priceOffer2211: { offers: [{ amount: 30, currency: 'USD', status: 'accepted' }] } };
    expect(ownerView({ ...base, pricing: { ...base.pricing, negotiated2211: true } }).canOffer).toBe(false);
    expect(ownerView({ status: 'pending', pricing: { totalPrice: 42, currency: 'USD' }, priceOffer2211: { offers: [{ amount: 30, currency: 'USD', status: 'declined' }] } }).canOffer).toBe(true);
  });
});
