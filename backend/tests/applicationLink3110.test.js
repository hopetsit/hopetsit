// 31/10/2026 (LEO, feu vert BOB 13 h 15) — LIEN SIGNÉ « mes candidats → payer » :
// utils/applicationLink3110 + POST /auth/application-link. VRAIE base Mongo en mémoire.
// Zone fictive lat −35 / lng −30. Aucun e-mail, aucun SMS envoyé (rien n'est appelé qui envoie).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }), getFirebaseAdmin: () => ({ messaging: () => ({ send: jest.fn() }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));
jest.mock('../src/services/emailService', () => ({ sendEmail: jest.fn(async () => ({ messageId: 'mock' })), sendTemplatedEmail: jest.fn(async () => ({})) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const ZONE = { lat: -35, lng: -30 };
let mongo;
let app;
let S = {};
let L;
let Owner; let Application; let Post; let Booking;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Application = require('../src/models/Application');
  Post = require('../src/models/Post');
  Booking = require('../src/models/Booking');
  L = require('../src/utils/applicationLink3110');
  const { exchangeApplicationLink } = require('../src/controllers/oneTimeTokenController');
  app = express();
  app.use(express.json());
  app.post('/auth/application-link', exchangeApplicationLink);

  const fr = { password: 'Hopetsit2026!', city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  S.owner = await Owner.create({ ...fr, name: 'Camille Test', email: 'leo3110m+owner@example.test', acceptedTerms: true });
  S.other = await Owner.create({ ...fr, name: 'Autre Test', email: 'leo3110m+other@example.test', acceptedTerms: true });
  S.testAcct = await Owner.create({ ...fr, name: 'Compte Plus Test', email: 'dadaciao84+testowner3110@gmail.com', acceptedTerms: true });
  const ins = async (M, doc) => { const r = await M.collection.insertOne(doc); return r.insertedId; };
  const sitterId = new mongoose.Types.ObjectId();
  S.post = await ins(Post, { ownerId: S.owner._id, postType: 'request', status: 'open', serviceTypes: ['house_sitting'], location: { city: 'Zone test', lat: ZONE.lat, lng: ZONE.lng }, createdAt: new Date() });
  S.postClosed = await ins(Post, { ownerId: S.owner._id, postType: 'request', status: 'closed', closedAt: new Date(), serviceTypes: ['house_sitting'], location: { city: 'Zone test', lat: ZONE.lat, lng: ZONE.lng }, createdAt: new Date() });
  S.postReal = await ins(Post, { ownerId: S.testAcct._id, postType: 'request', status: 'open', serviceTypes: ['house_sitting'], location: { city: 'Paris', lat: 48.85, lng: 2.35 }, createdAt: new Date() });
  S.postTestZone = await ins(Post, { ownerId: S.testAcct._id, postType: 'request', status: 'open', serviceTypes: ['house_sitting'], location: { city: 'Zone test', coordinates: [ZONE.lng, ZONE.lat] }, createdAt: new Date() });
  S.app = await ins(Application, { ownerId: S.owner._id, sitterId, postId: S.post, status: 'pending', serviceType: 'house_sitting', createdAt: new Date() });
  S.appClosed = await ins(Application, { ownerId: S.owner._id, sitterId, postId: S.postClosed, status: 'pending', serviceType: 'house_sitting', createdAt: new Date() });
  S.bookingPaid = await ins(Booking, { ownerId: S.owner._id, sitterId, status: 'paid', paymentStatus: 'paid', serviceType: 'house_sitting', createdAt: new Date() });
  S.appPaid = await ins(Application, { ownerId: S.owner._id, sitterId, postId: S.post, status: 'accepted', bookingId: S.bookingPaid, serviceType: 'house_sitting', createdAt: new Date() });
  S.appReal = await ins(Application, { ownerId: S.testAcct._id, sitterId, postId: S.postReal, status: 'pending', serviceType: 'house_sitting', createdAt: new Date() });
  S.appTestZone = await ins(Application, { ownerId: S.testAcct._id, sitterId, postId: S.postTestZone, status: 'pending', serviceType: 'house_sitting', createdAt: new Date() });
}, 120000);

afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

const BASE = 'https://www.hopetsit.com';
const tokenOf = (link) => new URL(link).searchParams.get('k');

describe('jeton : signature, date, format', () => {
  test('signer puis vérifier : même propriétaire, même candidature, même demande', () => {
    const t = L.signApplicationLink(S.owner._id, S.app, { postId: S.post });
    expect(t).toMatch(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
    const v = L.verifyApplicationLink(t);
    expect(v.ok).toBe(true);
    expect(v.ownerId).toBe(String(S.owner._id));
    expect(v.applicationId).toBe(String(S.app));
    expect(v.postId).toBe(String(S.post));
    expect(v.expiresAt - Date.now()).toBeGreaterThan(13 * 86400000);
  });
  test('jeton expiré → expired ; signature altérée → signature ; n’importe quoi → format', () => {
    const old = L.signApplicationLink(S.owner._id, S.app, { now: Date.now() - L.TTL_MS - 1000 });
    expect(L.verifyApplicationLink(old)).toMatchObject({ ok: false, reason: 'expired' });
    const t = L.signApplicationLink(S.owner._id, S.app);
    const [p, sig] = t.split('.');
    expect(L.verifyApplicationLink(`${p}.${sig.slice(0, -2)}zz`)).toMatchObject({ ok: false, reason: 'signature' });
    // charge utile modifiée (autre candidature) avec l'ancienne signature → refus
    const forged = Buffer.from(JSON.stringify({ v: 1, o: String(S.owner._id), a: String(S.appPaid), e: Date.now() + 1e7 })).toString('base64url');
    expect(L.verifyApplicationLink(`${forged}.${sig}`).ok).toBe(false);
    expect(L.verifyApplicationLink('abc')).toMatchObject({ ok: false, reason: 'format' });
    expect(L.verifyApplicationLink('')).toMatchObject({ ok: false, reason: 'format' });
    expect(L.verifyApplicationLink(null)).toMatchObject({ ok: false, reason: 'format' });
  });
  test('sans identifiants valides : pas de jeton (jamais d’exception)', () => {
    expect(L.signApplicationLink('', S.app)).toBe('');
    expect(L.signApplicationLink(S.owner._id, 'pas-un-id')).toBe('');
  });
});

describe('withSignedApplicationLink : quels liens sont signés', () => {
  test('propriétaire + /application/<id> (avec ou sans ?from=) → &k= ajouté, cible intacte', async () => {
    const a = await L.withSignedApplicationLink('owner', S.owner._id, `${BASE}/application/${S.app}?from=email&choose=1`);
    expect(a.startsWith(`${BASE}/application/${S.app}?from=email&choose=1&k=`)).toBe(true);
    expect(L.verifyApplicationLink(tokenOf(a))).toMatchObject({ ok: true, applicationId: String(S.app), postId: String(S.post) });
    const b = await L.withSignedApplicationLink('owner', S.owner._id, `${BASE}/application/${S.app}`);
    expect(b).toMatch(new RegExp(`^${BASE}/application/${S.app}\\?k=`));
  });
  test('pas signé : autre rôle, autre page, candidature d’un autre propriétaire, déjà signé', async () => {
    expect(await L.withSignedApplicationLink('sitter', S.owner._id, `${BASE}/application/${S.app}`)).toBe(`${BASE}/application/${S.app}`);
    expect(await L.withSignedApplicationLink('owner', S.owner._id, `${BASE}/posts?from=email`)).toBe(`${BASE}/posts?from=email`);
    expect(await L.withSignedApplicationLink('owner', S.owner._id, `${BASE}/application/${S.app}/x`)).toBe(`${BASE}/application/${S.app}/x`);
    expect(await L.withSignedApplicationLink('owner', S.other._id, `${BASE}/application/${S.app}`)).toBe(`${BASE}/application/${S.app}`);
    const once = await L.withSignedApplicationLink('owner', S.owner._id, `${BASE}/application/${S.app}`);
    expect(await L.withSignedApplicationLink('owner', S.owner._id, once)).toBe(once);
  });
  test('compte +test : signé SEULEMENT si la demande est en zone fictive (−35 / −30)', async () => {
    const real = await L.withSignedApplicationLink('owner', S.testAcct._id, `${BASE}/application/${S.appReal}?from=email`);
    expect(real).toBe(`${BASE}/application/${S.appReal}?from=email`);
    const zone = await L.withSignedApplicationLink('owner', S.testAcct._id, `${BASE}/application/${S.appTestZone}?from=email`);
    expect(zone).toMatch(/&k=/);
  });
  test('notificationSender.leadOwnerEmailLink signe aussi (hors pub)', async () => {
    const ns = require('../src/services/notificationSender');
    const out = await ns.leadOwnerEmailLink('owner', String(S.owner._id), `${BASE}/application/${S.app}?from=email`, BASE);
    expect(out).toMatch(new RegExp(`^${BASE}/application/${S.app}\\?from=email&k=`));
  });
});

describe('POST /auth/application-link : ouverture de session', () => {
  const post = (body) => request(app).post('/auth/application-link').send(body);
  test('jeton valable → session propriétaire (JWT owner), id de candidature et de demande', async () => {
    const t = L.signApplicationLink(S.owner._id, S.app, { postId: S.post });
    const r = await post({ token: t, applicationId: String(S.app) });
    expect(r.status).toBe(200);
    expect(r.body.role).toBe('owner');
    expect(r.body.applicationId).toBe(String(S.app));
    expect(r.body.postId).toBe(String(S.post));
    const decoded = jwt.verify(r.body.token, process.env.JWT_SECRET);
    expect(decoded).toMatchObject({ id: String(S.owner._id), role: 'owner' });
    expect(r.body.user.password).toBeUndefined();
    expect(String(r.body.user.email || '')).toContain('leo3110m+owner');
  });
  test('RÉUTILISATION : le même jeton rouvre la session une 2e et une 3e fois (le propriétaire rouvre son e-mail)', async () => {
    const t = L.signApplicationLink(S.owner._id, S.app, { postId: S.post });
    for (let i = 0; i < 3; i++) {
      // eslint-disable-next-line no-await-in-loop
      const r = await post({ token: t, applicationId: String(S.app) });
      expect(r.status).toBe(200);
    }
  });
  test('jeton expiré → 410 LINK_EXPIRED ; altéré ou format → 401/400', async () => {
    const old = L.signApplicationLink(S.owner._id, S.app, { now: Date.now() - L.TTL_MS - 5000 });
    expect((await post({ token: old })).status).toBe(410);
    const t = L.signApplicationLink(S.owner._id, S.app);
    expect((await post({ token: `${t}x` })).status).toBe(401);
    expect((await post({ token: '' })).status).toBe(400);
    expect((await post({})).status).toBe(400);
  });
  test('MAUVAISE DEMANDE : jeton d’une candidature utilisé sur la page d’une autre → 401', async () => {
    const t = L.signApplicationLink(S.owner._id, S.app, { postId: S.post });
    const r = await post({ token: t, applicationId: String(S.appPaid) });
    expect(r.status).toBe(401);
    expect(r.body.code).toBe('LINK_INVALID');
  });
  test('jeton forgé pour une candidature qui n’est pas à ce propriétaire → 401', async () => {
    const t = L.signApplicationLink(S.other._id, S.app, { postId: S.post });
    expect((await post({ token: t, applicationId: String(S.app) })).status).toBe(401);
  });
  test('DEMANDE CLOSE → 410 REQUEST_CLOSED ; déjà RÉSERVÉE ET PAYÉE → 410 REQUEST_BOOKED', async () => {
    const closed = L.signApplicationLink(S.owner._id, S.appClosed, { postId: S.postClosed });
    const r1 = await post({ token: closed, applicationId: String(S.appClosed) });
    expect(r1.status).toBe(410);
    expect(r1.body.code).toBe('REQUEST_CLOSED');
    const paid = L.signApplicationLink(S.owner._id, S.appPaid, { postId: S.post });
    const r2 = await post({ token: paid, applicationId: String(S.appPaid) });
    expect(r2.status).toBe(410);
    expect(r2.body.code).toBe('REQUEST_BOOKED');
  });
  test('un jeton valable cesse de marcher dès que la demande est close', async () => {
    const t = L.signApplicationLink(S.owner._id, S.app, { postId: S.post });
    expect((await post({ token: t, applicationId: String(S.app) })).status).toBe(200);
    await Post.collection.updateOne({ _id: S.post }, { $set: { status: 'closed', closedAt: new Date() } });
    expect((await post({ token: t, applicationId: String(S.app) })).status).toBe(410);
    await Post.collection.updateOne({ _id: S.post }, { $set: { status: 'open', closedAt: null } });
  });
});
