// 23/10/2026 (FLO, ordre de Daniel « vérifie si la chaîne de paiement complète marche ») —
// PREUVE de bout en bout, SANS argent réel, SANS réseau : contact de la pub → demande publiée →
// candidature du gardien → le propriétaire la voit (API + lien e-mail /posts/confirmer?l=&next=)
// → acceptation (réservation EUR Paris / USD New York, commission 20 % ajoutée) → intention
// Airwallex (HPP avec customer_id) → webhook payé → séquestre → rendu confirmé → wallet libéré →
// retrait IBAN → annulation < 72 h → remboursement (succès et échec) → notifications + e-mails.
// VRAIE base Mongo en mémoire, VRAIS routeurs Express (posts, applications, bookings, wallet,
// iban, ad-leads, notifications, webhook). Seuls Airwallex (réseau), Firebase, sockets, e-mails
// (capturés), Cloudinary, traduction et modération sont simulés. Zone fictive lat -35 / lng -30.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.AIRWALLEX_WEBHOOK_SECRET = 'whsec_test';
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.EMAIL_UNVERIFIED_GUARD = 'on';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

const AWX = { created: [], refunds: [], refundShouldFail: false, intents: {}, beneficiaries: [] };
jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  let n = 0;
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}`, merchant_customer_id: userId })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async (body) => {
      n += 1;
      const pi = { id: `int_flo2310_${n}`, client_secret: `cs_test_${n}`, status: 'REQUIRES_PAYMENT_METHOD',
        amount: body.amount / 100, currency: body.currency, metadata: body.metadata || {}, customer_id: body.customer_id || null, request: body };
      AWX.created.push(pi); AWX.intents[pi.id] = pi; return pi;
    }),
    retrievePaymentIntent: jest.fn(async (id) => {
      const pi = AWX.intents[id]; if (!pi) throw new Error('PI not found'); return pi;
    }),
    cancelPaymentIntent: jest.fn(async (id) => { if (AWX.intents[id]) AWX.intents[id].status = 'CANCELLED'; return { id, status: 'CANCELLED' }; }),
    createRefund: jest.fn(async ({ paymentIntentId, amount }) => {
      if (AWX.refundShouldFail) throw new Error('Airwallex refund refused (simulated)');
      const r = { id: `rf_${paymentIntentId}`, amount: amount != null ? amount / 100 : AWX.intents[paymentIntentId]?.amount, currency: AWX.intents[paymentIntentId]?.currency, status: 'RECEIVED' };
      AWX.refunds.push(r); return r;
    }),
    createBeneficiary: jest.fn(async (b) => { const ben = { id: `ben_${AWX.beneficiaries.length + 1}`, ...b }; AWX.beneficiaries.push(ben); return ben; }),
    deleteBeneficiary: jest.fn(async () => ({})),
    createPayout: jest.fn(async () => { throw new Error('payout réseau coupé dans le banc'); }),
    constructWebhookEvent: jest.fn((rawBody) => JSON.parse(Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody))),
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
    sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }),
    sendTemplatedEmail: jest.fn(async () => ({})),
  };
});
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const inDays = (n) => new Date(Date.now() + n * 86400000);
const iso = (d) => d.toISOString();
let mongo; let app;
let Owner; let Sitter; let Booking; let WalletTransaction; let Pet; let Post; let Application; let Notification; let AdLead;
const PASS = 'MotDePasseTest2310!';
const ZONE = { type: 'Point', coordinates: [-30, -35] }; // [lng, lat] zone fictive
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': '23.1.590+620' });
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const mailsTo = (email, subjectPart) => MAILS.filter((m) => String(m.to).toLowerCase() === email.toLowerCase() && (!subjectPart || m.subject.includes(subjectPart)));
const linkOf = (m) => { const x = m.text.match(/https?:\/\/[^\s"<)]+/); return x ? x[0] : ''; };
const notifsOf = async (id, role) => { const r = await request(app).get('/notifications/my?limit=50').set(hdr(id, role)); if (r.status !== 200 || !Array.isArray(r.body.notifications)) console.log('GET /notifications →', r.status, JSON.stringify(r.body).slice(0, 300)); return r.body; }; // eslint-disable-line no-console
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

const FR = { owner: null, sitter: null, pet: null, lead: null, post: null, application: null, booking: null, pi: null };
const US = { owner: null, sitter: null, pet: null, post: null, application: null, booking: null, pi: null };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Booking = require('../src/models/Booking');
  WalletTransaction = require('../src/models/WalletTransaction'); Pet = require('../src/models/Pet'); Post = require('../src/models/Post');
  Application = require('../src/models/Application'); Notification = require('../src/models/Notification'); AdLead = require('../src/models/AdLead2210');
  require('../src/models/Walker'); require('../src/models/ProcessedWebhook'); try { require('../src/models/Invoice'); } catch (_) { /* optionnel */ }
  await Promise.all([Owner.init(), Sitter.init(), Booking.init(), WalletTransaction.init(), Pet.init(), Post.init(), Application.init(), Notification.init(), AdLead.init()]);

  // Gardiens (vérifiés, tarif horaire 10, position dans la zone fictive)
  FR.sitter = await Sitter.create({ name: 'Inès Petit', email: 'flo2310+sitterfr@example.test', password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', hourlyRate: 10, verified: true, location: ZONE, walletBalance: 0 });
  US.sitter = await Sitter.create({ name: 'Emma Johnson', email: 'flo2310+sitterus@example.test', password: PASS, city: 'Zone test', country: 'US', currency: 'USD', hourlyRate: 10, verified: true, location: ZONE, walletBalance: 0 });
  // Propriétaire américain ordinaire (New York → USD), avec animal
  US.owner = await Owner.create({ name: 'Camille Durand', email: 'flo2310+ownerus@example.test', password: PASS, city: 'Zone test', country: 'US', currency: 'USD', verified: true, location: ZONE, acceptedTerms: true });
  US.pet = await Pet.create({ ownerId: US.owner._id, petName: 'Rex', petType: 'dog' });

  app = express();
  const webhook = require('../src/controllers/airwallexWebhookController').handleAirwallexWebhook;
  app.post('/webhooks/airwallex', express.raw({ type: 'application/json' }), webhook);
  app.use(express.json());
  const adLeads = require('../src/routes/adLeads2210');
  app.use('/admin/ad-leads', adLeads.adminRouter); app.use('/ad-leads', adLeads);
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/bookings', require('../src/routes/bookingRoutes'));
  app.use('/wallet', require('../src/routes/walletRoutes'));
  app.use('/sitter', require('../src/routes/ibanRoutes'));
  app.use('/notifications', require('../src/routes/notificationRoutes'));
}, 180000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

describe('1. Contact de la pub → demande publiée → candidature → le propriétaire la voit', () => {
  test('contact Meta (Paris → EUR) : compte propriétaire sans mot de passe + demande publiée + session', async () => {
    const reg = await request(app).post('/admin/ad-leads').set(ADMIN).send({
      metaLeadId: 'flo2310-paris', email: 'flo2310+ownerfr@example.test', firstName: 'Karine', city: 'Zone test',
      lat: -35, lng: -30, country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'bientot',
    }).expect(200);
    FR.lead = reg.body.id;
    const r = await request(app).post(`/ad-leads/${FR.lead}/confirm`).send({ lieu: 'at_owner' }).expect(200);
    FR.owner = await Owner.findOne({ email: 'flo2310+ownerfr@example.test' });
    expect(FR.owner).toBeTruthy();
    expect(FR.owner.verified).toBe(true);
    expect(FR.owner.currency).toBe('EUR');
    expect(jwt.verify(r.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(FR.owner._id), role: 'owner' });
    expect(r.body.postId).toMatch(/^[a-f0-9]{24}$/);
    FR.post = await Post.findById(r.body.postId).lean();
    expect(FR.post).toBeTruthy();
    expect(String(FR.post.ownerId)).toBe(String(FR.owner._id));
    expect(FR.post.serviceTypes).toContain('house_sitting');
    // 2e clic (bouton « Voir ma demande » / lien next=) : même demande, nouvelle session
    const r2 = await request(app).post(`/ad-leads/${FR.lead}/confirm`).send({}).expect(200);
    expect(r2.body.postId).toBe(r.body.postId);
    expect(await Post.countDocuments({ ownerId: FR.owner._id })).toBe(1);
    FR.pet = await Pet.findOne({ ownerId: FR.owner._id });
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 1a lead →', JSON.stringify({ lead: FR.lead, owner: String(FR.owner._id), post: r.body.postId, notified: r.body.notified, petAuto: FR.pet ? String(FR.pet._id) : null }));
  }, 60000);

  test('candidature du gardien (EUR) → 201, tarif 20 €/2 h, commission 20 % AJOUTÉE, total = net + commission', async () => {
    MAILS.length = 0;
    const d = inDays(10);
    const body = { postId: String(FR.post._id), serviceType: 'home_visit', serviceDate: iso(d), startDate: iso(d), endDate: iso(new Date(d.getTime() + 2 * 3600000)), timeSlot: 'morning', description: 'Je peux garder Rex.', ...(FR.pet ? { petIds: [String(FR.pet._id)] } : {}) };
    const r = await request(app).post(`/applications?ownerId=${FR.owner._id}`).set(hdr(FR.sitter._id, 'sitter')).send(body);
    if (r.status !== 201) console.log('createApplication →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(201);
    FR.application = await Application.findOne({ ownerId: FR.owner._id, sitterId: FR.sitter._id }).lean();
    expect(FR.application).toBeTruthy();
    const p = FR.application.pricing;
    expect(p.currency).toBe('EUR');
    expect(p.commissionRate).toBeCloseTo(0.2, 5);
    expect(p.commission).toBeCloseTo(0.2 * p.netPayout, 2);
    expect(p.totalPrice).toBeCloseTo(p.netPayout + p.commission, 2);
    expect(p.netPayout).toBeCloseTo(p.basePrice, 2); // le gardien touche 100 % de son prix
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 1b candidature →', JSON.stringify({ id: String(FR.application._id), base: p.basePrice, net: p.netPayout, commission: p.commission, total: p.totalPrice, currency: p.currency, tier: p.pricingTier }));
  }, 60000);

  test('le propriétaire voit la candidature (GET /applications, ce que lisent l’app et le site)', async () => {
    const r = await request(app).get('/applications').set(hdr(FR.owner._id, 'owner')).expect(200);
    const list = Array.isArray(r.body) ? r.body : (r.body.applications || r.body.items || []);
    const mine = list.find((a) => String(a.id || a._id) === String(FR.application._id));
    expect(mine).toBeTruthy();
    expect(mine.status).toBe('pending');
    const r2 = await request(app).get('/applications/my').set(hdr(FR.owner._id, 'owner')).expect(200);
    const list2 = Array.isArray(r2.body) ? r2.body : (r2.body.applications || r2.body.items || []);
    expect(list2.some((a) => String(a.id || a._id) === String(FR.application._id))).toBe(true);
  }, 60000);

  test('e-mail « Nouvelle candidature » au propriétaire sans mot de passe : bouton = /posts/confirmer?l=<jeton>&next=/application/<id> ; cloche in-app', async () => {
    await wait(300);
    const m = mailsTo('flo2310+ownerfr@example.test');
    expect(m.length).toBeGreaterThanOrEqual(1);
    const link = linkOf(m[m.length - 1]);
    expect(link).toContain(`/posts/confirmer?l=${FR.lead}&next=`);
    const { buildEmailRoute } = require('../src/utils/emailLinkBuilder');
    const attendu = buildEmailRoute('application_new', { applicationId: String(FR.application._id), providerRole: 'sitter', providerId: String(FR.sitter._id), postId: String(FR.post._id) }, { role: 'owner', devices: null });
    expect(decodeURIComponent(link.split('next=')[1])).toBe(attendu);
    expect([`/application/${FR.application._id}`, `/post/${FR.post._id}`]).toContain(attendu);
    const n = await notifsOf(FR.owner._id, 'owner');
    const items = n.notifications || n.items || n;
    expect(items.some((x) => x.type === 'application_new')).toBe(true);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 1c e-mail propriétaire →', m[m.length - 1].subject, '|', link);
  }, 60000);

  test('propriétaire US (New York, USD) : demande + candidature du gardien US en USD ; gardien EUR refusé (devise)', async () => {
    const d = inDays(10);
    const rp = await request(app).post('/posts').set(hdr(US.owner._id, 'owner')).send({
      body: "I'm looking for a pet sitter for my dog within 2 weeks.", language: 'en', animalCount: 1, animalTypes: ['dog'], petIds: [String(US.pet._id)],
      serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', serviceLocation: 'at_owner',
      startDate: iso(d), endDate: iso(inDays(11)), location: { city: 'Zone test', lat: -35, lng: -30 },
    });
    if (rp.status !== 201) console.log('createPost US →', rp.status, JSON.stringify(rp.body)); // eslint-disable-line no-console
    expect(rp.status).toBe(201);
    US.post = rp.body.post;
    const body = { postId: String(US.post.id || US.post._id), serviceType: 'home_visit', serviceDate: iso(d), startDate: iso(d), endDate: iso(new Date(d.getTime() + 2 * 3600000)), timeSlot: 'morning', petIds: [String(US.pet._id)], description: 'Happy to help.' };
    const bad = await request(app).post(`/applications?ownerId=${US.owner._id}`).set(hdr(FR.sitter._id, 'sitter')).send(body);
    expect(bad.status).toBe(403);
    expect(bad.body.code).toBe('CURRENCY_MISMATCH');
    const ok = await request(app).post(`/applications?ownerId=${US.owner._id}`).set(hdr(US.sitter._id, 'sitter')).send(body);
    if (ok.status !== 201) console.log('createApplication US →', ok.status, JSON.stringify(ok.body)); // eslint-disable-line no-console
    expect(ok.status).toBe(201);
    US.application = await Application.findOne({ ownerId: US.owner._id, sitterId: US.sitter._id }).lean();
    expect(US.application.pricing.currency).toBe('USD');
    expect(US.application.pricing.commission).toBeCloseTo(0.2 * US.application.pricing.netPayout, 2);
  }, 60000);
});

describe('2. Acceptation → réservation au bon tarif et dans la devise du propriétaire', () => {
  test('EUR : accept → booking agreed, pricing recopié, demande marquée réservée, gardien prévenu (application_accepted)', async () => {
    MAILS.length = 0;
    const r = await request(app).post(`/applications/${FR.application._id}/respond`).set(hdr(FR.owner._id, 'owner')).send({ action: 'accept' });
    if (r.status !== 200) console.log('respond →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    const a = await Application.findById(FR.application._id).lean();
    expect(a.status).toBe('accepted');
    FR.booking = await Booking.findById(a.bookingId).lean();
    expect(FR.booking.status).toBe('agreed');
    expect(FR.booking.paymentStatus).toBe('pending');
    expect(FR.booking.pricing.currency).toBe('EUR');
    expect(FR.booking.pricing.totalPrice).toBeCloseTo(FR.booking.pricing.netPayout + FR.booking.pricing.commission, 2);
    expect(FR.booking.pricing.commission).toBeCloseTo(0.2 * FR.booking.pricing.netPayout, 2);
    expect(FR.booking.pricing.totalPrice).toBeCloseTo(FR.application.pricing.totalPrice, 2);
    const post = await Post.findById(FR.post._id).lean();
    expect(String(post.reservedBy?.bookingId)).toBe(String(FR.booking._id));
    await wait(300);
    const m = mailsTo('flo2310+sitterfr@example.test');
    expect(m.length).toBeGreaterThanOrEqual(1);
    expect(linkOf(m[m.length - 1])).toContain(`/bookings/${FR.booking._id}`);
    const n = await notifsOf(FR.sitter._id, 'sitter');
    expect((n.notifications || n.items || n).some((x) => x.type === 'application_accepted')).toBe(true);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 2 booking EUR →', JSON.stringify({ id: String(FR.booking._id), ...FR.booking.pricing, status: FR.booking.status }), '| e-mail gardien :', m[m.length - 1].subject, linkOf(m[m.length - 1]));
  }, 60000);

  test('USD : accept → booking en USD', async () => {
    const r = await request(app).post(`/applications/${US.application._id}/respond`).set(hdr(US.owner._id, 'owner')).send({ action: 'accept' });
    expect(r.status).toBe(200);
    const a = await Application.findById(US.application._id).lean();
    US.booking = await Booking.findById(a.bookingId).lean();
    expect(US.booking.pricing.currency).toBe('USD');
    expect(US.booking.pricing.commission).toBeCloseTo(0.2 * US.booking.pricing.netPayout, 2);
  }, 60000);
});

describe('3. Paiement : intention Airwallex (HPP, customer_id) → webhook → payée → séquestre', () => {
  test('EUR : POST create-payment-intent → PI au montant total, devise EUR, customer_id, metadata.bookingId ; lien /pay?bookingId= pour le contact de la pub', async () => {
    const r = await request(app).post(`/bookings/${FR.booking._id}/create-payment-intent`).set(hdr(FR.owner._id, 'owner')).send({});
    if (r.status !== 200) console.log('create-payment-intent →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    // l'intention est créée DÈS l'acceptation (_prepareOwnerPaymentForAgreedBooking) puis réutilisée ici
    const b0 = await Booking.findById(FR.booking._id).lean();
    const pi = AWX.intents[b0.airwallexPaymentIntentId];
    FR.pi = pi;
    expect(pi).toBeTruthy();
    expect(r.body.message).toMatch(/reused/i);
    expect(pi.request.currency).toBe('EUR');
    expect(pi.request.amount / 100).toBeCloseTo(FR.booking.pricing.totalPrice, 2);
    expect(pi.request.customer_id).toBe(`cus_test_${FR.owner._id}`);
    expect(String(pi.request.metadata.bookingId)).toBe(String(FR.booking._id));
    expect(r.body.paymentIntentId || r.body.id).toBe(pi.id);
    expect(r.body.clientSecret || r.body.client_secret).toBeTruthy();
    expect(r.body.customerId).toBe(`cus_test_${FR.owner._id}`);
    const b = await Booking.findById(FR.booking._id).lean();
    expect(b.airwallexPaymentIntentId).toBe(pi.id);
    // lien de l'e-mail « Réservation acceptée → payer » pour un propriétaire issu de la pub
    const { buildEmailRoute } = require('../src/utils/emailLinkBuilder');
    expect(buildEmailRoute('booking_accepted', { bookingId: String(FR.booking._id) }, { role: 'owner', devices: null })).toBe(`/pay?bookingId=${FR.booking._id}`);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 3a PI →', JSON.stringify({ id: pi.id, amount: pi.request.amount, currency: pi.request.currency, customer_id: pi.request.customer_id, metadata: pi.request.metadata, reponse: { amount: r.body.amount, currency: r.body.currency, commissionAmount: r.body.commissionAmount, netSitterAmount: r.body.netSitterAmount, customerId: r.body.customerId } }));
  }, 60000);

  test('webhook payment_intent.succeeded → status paid, paymentStatus paid, séquestre (crédit non retirable), payout programmé, notifications des deux côtés, rejeu ignoré', async () => {
    MAILS.length = 0;
    AWX.intents[FR.pi.id].status = 'SUCCEEDED';
    const evt = { id: 'evt_flo2310_1', name: 'payment_intent.succeeded', data: { id: FR.pi.id, amount: FR.pi.amount, currency: 'EUR', metadata: FR.pi.metadata } };
    const r = await request(app).post('/webhooks/airwallex').set('Content-Type', 'application/json').send(JSON.stringify(evt));
    expect(r.status).toBe(200);
    const b = await Booking.findById(FR.booking._id).lean();
    expect(b.status).toBe('paid');
    expect(b.paymentStatus).toBe('paid');
    expect(b.paidAt).toBeTruthy();
    expect(b.confirmationStatus).toBe('awaiting_start');
    expect(b.payoutStatus).toBe('scheduled');
    const tx = await WalletTransaction.findOne({ userId: FR.sitter._id, type: 'credit_booking', bookingId: String(FR.booking._id) }).lean();
    expect(tx).toBeTruthy();
    expect(tx.amount).toBeCloseTo(FR.booking.pricing.netPayout, 2);
    expect(tx.meta.withdrawable).toBe(false);
    const w = await request(app).get('/wallet').set(hdr(FR.sitter._id, 'sitter')).expect(200);
    expect(Number(w.body.balance || 0)).toBe(0); // séquestre : rien de retirable avant le rendu
    expect(Number(w.body.pendingEscrowTotal || 0)).toBeCloseTo(FR.booking.pricing.netPayout, 2);
    // rejeu du même événement → ignoré
    const r2 = await request(app).post('/webhooks/airwallex').set('Content-Type', 'application/json').send(JSON.stringify(evt));
    expect(r2.body.duplicate).toBe(true);
    expect(await WalletTransaction.countDocuments({ userId: FR.sitter._id, type: 'credit_booking', bookingId: String(FR.booking._id) })).toBe(1);
    await wait(400);
    const mo = mailsTo('flo2310+ownerfr@example.test'); const ms = mailsTo('flo2310+sitterfr@example.test');
    expect(ms.length).toBeGreaterThanOrEqual(1);
    expect(mo.length).toBeGreaterThanOrEqual(1);
    const lo = linkOf(mo[mo.length - 1]);
    expect(lo).toContain(`/posts/confirmer?l=${FR.lead}&next=`);
    expect(decodeURIComponent(lo.split('next=')[1])).toBe(`/bookings/${FR.booking._id}`);
    expect(linkOf(ms[ms.length - 1])).toContain(`/bookings/${FR.booking._id}`);
    const no = await notifsOf(FR.owner._id, 'owner'); const ns = await notifsOf(FR.sitter._id, 'sitter');
    expect((no.notifications || no.items || no).some((x) => x.type === 'booking_paid_owner')).toBe(true);
    expect((ns.notifications || ns.items || ns).some((x) => x.type === 'booking_paid')).toBe(true);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 3b payée →', JSON.stringify({ status: b.status, paymentStatus: b.paymentStatus, confirmationStatus: b.confirmationStatus, payoutStatus: b.payoutStatus, autoReleaseAt: b.autoReleaseAt, wallet: { balance: w.body.balance, pendingEscrowTotal: w.body.pendingEscrowTotal, pendingAmount: w.body.pendingAmount } }), '| e-mails :', ms[ms.length - 1].subject, '/', mo[mo.length - 1].subject, lo);
  }, 60000);

  test('USD : PI en USD au montant total', async () => {
    const r = await request(app).post(`/bookings/${US.booking._id}/create-payment-intent`).set(hdr(US.owner._id, 'owner')).send({});
    expect(r.status).toBe(200);
    const pi = AWX.intents[(await Booking.findById(US.booking._id).lean()).airwallexPaymentIntentId]; US.pi = pi;
    expect(pi.request.currency).toBe('USD');
    expect(pi.request.amount / 100).toBeCloseTo(US.booking.pricing.totalPrice, 2);
    expect(pi.request.customer_id).toBe(`cus_test_${US.owner._id}`);
    AWX.intents[pi.id].status = 'SUCCEEDED';
    const evt = { id: 'evt_flo2310_us', name: 'payment_intent.succeeded', data: { id: pi.id, amount: pi.amount, currency: 'USD', metadata: pi.metadata } };
    await request(app).post('/webhooks/airwallex').set('Content-Type', 'application/json').send(JSON.stringify(evt)).expect(200);
    const b = await Booking.findById(US.booking._id).lean();
    expect(b.paymentStatus).toBe('paid');
    const tx = await WalletTransaction.findOne({ userId: US.sitter._id, type: 'credit_booking', bookingId: String(US.booking._id) }).lean();
    expect(tx.currency).toBe('USD');
  }, 60000);
});

describe('4. Remise / rendu → libération vers le wallet → retrait IBAN', () => {
  test('rendu confirmé par le propriétaire → crédit retirable = net, wallet_credited, payout wallet terminé', async () => {
    MAILS.length = 0;
    // la garde a commencé (démarrage par le gardien) : on avance la date de service à il y a 3 h
    const start = new Date(Date.now() - 3 * 3600000); const end = new Date(Date.now() - 3600000);
    await Booking.updateOne({ _id: FR.booking._id }, { $set: { date: start, startDate: start, endDate: end } });
    const s = await request(app).post(`/bookings/${FR.booking._id}/service/start`).set(hdr(FR.sitter._id, 'sitter')).send({ handoverCode: (await Booking.findById(FR.booking._id).lean()).handoverCode });
    if (s.status !== 200) console.log('service/start →', s.status, JSON.stringify(s.body)); // eslint-disable-line no-console
    const c = await request(app).post(`/bookings/${FR.booking._id}/service/confirm`).set(hdr(FR.owner._id, 'owner')).send({});
    if (c.status !== 200) console.log('service/confirm →', c.status, JSON.stringify(c.body)); // eslint-disable-line no-console
    expect(c.status).toBe(200);
    const b = await Booking.findById(FR.booking._id).lean();
    expect(b.confirmationStatus).toBe('confirmed');
    expect(b.payoutStatus).toBe('completed');
    const w = await request(app).get('/wallet').set(hdr(FR.sitter._id, 'sitter')).expect(200);
    expect(Number(w.body.balance)).toBeCloseTo(FR.booking.pricing.netPayout, 2);
    expect(Number(w.body.pendingEscrowTotal || 0)).toBe(0);
    await wait(400);
    const ns = await notifsOf(FR.sitter._id, 'sitter');
    const types = (ns.notifications || ns.items || ns).map((x) => x.type);
    expect(types).toEqual(expect.arrayContaining(['wallet_credited', 'handover_return_confirmed']));
    const ms = mailsTo('flo2310+sitterfr@example.test');
    expect(ms.some((m) => linkOf(m).endsWith('/wallet'))).toBe(true);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 4a rendu →', JSON.stringify({ start: s.status, confirmationStatus: b.confirmationStatus, payoutStatus: b.payoutStatus, payoutMethod: b.payoutMethod, wallet: { balance: w.body.balance, pendingEscrowTotal: w.body.pendingEscrowTotal } }), '| notifs gardien :', types.join(','), '| e-mails :', ms.map((m) => `${m.subject} → ${linkOf(m)}`).join(' ; '));
  }, 60000);

  test('retrait IBAN : mandat accepté + IBAN enregistré (bénéficiaire Airwallex) → retrait du net accepté, solde débité, en attente admin', async () => {
    const net = FR.booking.pricing.netPayout;
    const noMandate = await request(app).post('/wallet/withdraw').set(hdr(FR.sitter._id, 'sitter')).send({ amount: net, method: 'iban' });
    expect(noMandate.status).toBe(400);
    await request(app).post('/wallet/billing-mandate').set(hdr(FR.sitter._id, 'sitter')).send({}).expect(200);
    const noIban = await request(app).post('/wallet/withdraw').set(hdr(FR.sitter._id, 'sitter')).send({ amount: net, method: 'iban' });
    expect(noIban.status).toBe(400);
    const ib = await request(app).put('/sitter/iban').set(hdr(FR.sitter._id, 'sitter')).send({ ibanHolder: 'Inès Petit', ibanNumber: 'FR7630006000011234567890189', ibanBic: 'AGRIFRPP' });
    if (ib.status !== 200) console.log('PUT /sitter/iban →', ib.status, JSON.stringify(ib.body)); // eslint-disable-line no-console
    expect(ib.status).toBe(200);
    const tooMuch = await request(app).post('/wallet/withdraw').set(hdr(FR.sitter._id, 'sitter')).send({ amount: net + 100, method: 'iban' });
    expect(tooMuch.status).toBe(400);
    const wd = await request(app).post('/wallet/withdraw').set(hdr(FR.sitter._id, 'sitter')).send({ amount: net, method: 'iban' });
    if (wd.status !== 200) console.log('withdraw →', wd.status, JSON.stringify(wd.body)); // eslint-disable-line no-console
    expect(wd.status).toBe(200);
    const tx = await WalletTransaction.findOne({ userId: FR.sitter._id, type: 'debit_withdrawal' }).lean();
    expect(tx).toBeTruthy();
    expect(Math.abs(tx.amount)).toBeCloseTo(net, 2);
    const w = await request(app).get('/wallet').set(hdr(FR.sitter._id, 'sitter')).expect(200);
    expect(Number(w.body.balance)).toBeCloseTo(0, 2);
    expect(Number(w.body.pendingWithdrawals)).toBe(1);
    // CONSTAT (FLO 23/10) : `pendingAmount` reste à 0 — walletController.js:58 compare userId (chaîne) à un
    // ObjectId dans un $match d'agrégation (countDocuments caste, aggregate non). Affichage seulement ;
    // le solde et le retrait sont justes. Proposé à BOB, non corrigé ici.
    console.log('pendingAmount (bug d\'affichage connu) →', w.body.pendingAmount); // eslint-disable-line no-console
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 4b retrait →', JSON.stringify({ beneficiaire: AWX.beneficiaries.length, retrait: { status: tx.status, amount: tx.amount, method: tx.meta?.method || tx.method }, wallet: { balance: w.body.balance, pendingAmount: w.body.pendingAmount, pendingWithdrawals: w.body.pendingWithdrawals } }));
  }, 60000);
});

describe('5. Annulation < 72 h → remboursement', () => {
  test('USD : annulation par le propriétaire à J-10 → remboursement Airwallex du montant capturé, paymentStatus refunded, prestataire prévenu', async () => {
    MAILS.length = 0;
    const r = await request(app).post(`/bookings/${US.booking._id}/self-cancel`).set(hdr(US.owner._id, 'owner')).send({ reason: 'test' });
    if (r.status !== 200) console.log('self-cancel →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
    expect(r.status).toBe(200);
    expect(r.body.refundPending).toBe(false);
    const b = await Booking.findById(US.booking._id).lean();
    expect(b.status).toBe('cancelled');
    expect(b.paymentStatus).toBe('refunded');
    expect(b.refundId).toBe(`rf_${US.pi.id}`);
    expect(b.payoutStatus).toBe('cancelled');
    const rf = AWX.refunds[AWX.refunds.length - 1];
    expect(rf.amount).toBeCloseTo(US.booking.pricing.totalPrice, 2);
    expect(rf.currency).toBe('USD');
    await wait(300);
    const ns = await notifsOf(US.sitter._id, 'sitter');
    expect((ns.notifications || ns.items || ns).some((x) => x.type === 'booking_cancelled_by_owner')).toBe(true);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 5a annulation →', JSON.stringify({ status: b.status, paymentStatus: b.paymentStatus, refundId: b.refundId, refund: rf }));
  }, 60000);

  test('annulation à moins de 72 h → refusée (409) ; remboursement en ÉCHEC → paymentStatus « refund » + cause tracée', async () => {
    // réservation payée à J-1 : refus 72 h
    const soon = inDays(1);
    const b1 = await Booking.create({ ownerId: US.owner._id, sitterId: US.sitter._id, petIds: [US.pet._id], date: soon, startDate: soon, endDate: inDays(1.1), timeSlot: 'morning', serviceType: 'home_visit', status: 'paid', paymentStatus: 'paid', paidAt: new Date(), paymentProvider: 'airwallex', airwallexPaymentIntentId: 'int_flo2310_soon', pricing: { basePrice: 10, totalPrice: 12, commission: 2, netPayout: 10, commissionRate: 0.2, currency: 'USD' } });
    const r1 = await request(app).post(`/bookings/${b1._id}/self-cancel`).set(hdr(US.owner._id, 'owner')).send({});
    expect(r1.status).toBe(409);
    // remboursement refusé par Airwallex : la réservation reste annulée, paiement « refund » (à rembourser)
    AWX.intents.int_flo2310_fail = { id: 'int_flo2310_fail', status: 'SUCCEEDED', amount: 12, currency: 'USD', captured_amount: 12 };
    const far = inDays(10);
    const b2 = await Booking.create({ ownerId: US.owner._id, sitterId: US.sitter._id, petIds: [US.pet._id], date: far, startDate: far, endDate: inDays(10.1), timeSlot: 'morning', serviceType: 'home_visit', status: 'paid', paymentStatus: 'paid', paidAt: new Date(), paymentProvider: 'airwallex', airwallexPaymentIntentId: 'int_flo2310_fail', pricing: { basePrice: 10, totalPrice: 12, commission: 2, netPayout: 10, commissionRate: 0.2, currency: 'USD' } });
    AWX.refundShouldFail = true;
    const r2 = await request(app).post(`/bookings/${b2._id}/self-cancel`).set(hdr(US.sitter._id, 'sitter')).send({});
    AWX.refundShouldFail = false;
    expect(r2.status).toBe(200);
    expect(r2.body.refundPending).toBe(true);
    const f = await Booking.findById(b2._id).lean();
    expect(f.status).toBe('cancelled');
    expect(f.paymentStatus).toBe('refund');
    expect(f.refundError).toContain('simulated');
    await wait(300);
    const no = await notifsOf(US.owner._id, 'owner');
    expect((no.notifications || no.items || []).some((x) => x.type === 'booking_cancelled_by_provider')).toBe(true);
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 5b →', JSON.stringify({ moins72h: r1.status, echecRemboursement: { paymentStatus: f.paymentStatus, refundError: f.refundError } }));
  }, 60000);
});

describe('6. Liens des e-mails pour chaque étape (propriétaire sans mot de passe et gardien)', () => {
  test('tous les types de la chaîne ont une cible interne ; le propriétaire de la pub passe par /posts/confirmer', async () => {
    const { buildEmailRoute } = require('../src/utils/emailLinkBuilder');
    const d = { bookingId: String(FR.booking._id), applicationId: String(FR.application._id), postId: String(FR.post._id), providerRole: 'sitter', providerId: String(FR.sitter._id) };
    const owner = ['application_new', 'booking_new', 'booking_accepted', 'booking_paid_owner', 'booking_cancelled_by_provider', 'handover_pickup_confirmed', 'payment_failed'].map((t) => [t, buildEmailRoute(t, d, { role: 'owner', devices: null })]);
    const sitter = ['application_accepted', 'booking_paid', 'wallet_credited', 'handover_return_confirmed', 'booking_cancelled_by_owner', 'payout_completed', 'withdrawal_requested'].map((t) => [t, buildEmailRoute(t, d, { role: 'sitter', devices: null })]);
    [...owner, ...sitter].forEach(([, route]) => expect(route).toMatch(/^\/(?!\/)/));
    expect(Object.fromEntries(owner)).toMatchObject({ application_new: `/application/${FR.application._id}`, booking_accepted: `/pay?bookingId=${FR.booking._id}`, booking_paid_owner: `/bookings/${FR.booking._id}` });
    expect(Object.fromEntries(sitter)).toMatchObject({ application_accepted: `/bookings/${FR.booking._id}`, booking_paid: `/bookings/${FR.booking._id}`, wallet_credited: '/wallet' });
    // appareils récents (iOS ≥ 602 / Android ≥ 603) : cible précise /application/<id>
    const precise = buildEmailRoute('application_new', d, { role: 'owner', devices: [{ platform: 'ios', build: 620 }] });
    console.log('application_new avec app 620 →', precise); // eslint-disable-line no-console
    // eslint-disable-next-line no-console
    console.log('ÉTAPE 6 routes e-mail →', JSON.stringify({ owner: Object.fromEntries(owner), sitter: Object.fromEntries(sitter) }));
  });
});
