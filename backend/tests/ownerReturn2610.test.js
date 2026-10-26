// 26/10/2026 (ADA, décision de Daniel — proposition C de SAM) — mesure fiable
// du retour des propriétaires. Données FICTIVES, base Mongo en mémoire, vraies
// routes et vrai middleware d'authentification (jetons signés en test).
//   1. l'origine d'une requête (app / web / script) ;
//   2. une session de script ne bouge JAMAIS « vu il y a » ni « vrai dernier retour » ;
//   3. le repère « a ouvert ses candidats » (propriétaire seulement, doublons fusionnés) ;
//   4. le tableau /admin/requests613/board expose ces signaux.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { classifyOrigin, isRealSession } = require('../src/utils/ownerReturn2610');

const UA_WEB = 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile Safari/604.1';
const UA_PY = 'Python-urllib/3.12';
const H = 3600000;
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET);
const req = (headers) => ({ headers });

describe('origine d’une requête', () => {
  test.each([
    ['script Python (nos outils)', { 'user-agent': UA_PY }, 'script'],
    ['curl', { 'user-agent': 'curl/8.7.1' }, 'script'],
    ['sans User-Agent', {}, 'script'],
    ['banc Chrome sans tête', { 'user-agent': 'Mozilla/5.0 HeadlessChrome/141.0', 'x-app-version': 'web' }, 'script'],
    ['script qui s’annonce même avec un UA de navigateur', { 'user-agent': UA_WEB, 'x-hps-script': 'leads_dates' }, 'script'],
    ['site (navigateur)', { 'user-agent': UA_WEB, 'x-app-version': 'web' }, 'web'],
    ['site, appel sans en-tête de version', { 'user-agent': UA_WEB }, 'web'],
    ['app Flutter', { 'user-agent': 'Dart/3.5 (dart:io)', 'x-app-version': '23.1.590+623', 'x-app-platform': 'ios' }, 'app'],
    ['app avec version seule', { 'x-app-version': '23.1.590+623' }, 'app'],
  ])('%s → %s', (_l, h, want) => expect(classifyOrigin(req(h))).toBe(want));

  test('sessions d’avant le 26/10 (sans origine) : règle de SAM', () => {
    expect(isRealSession({ appVersion: 'web' })).toBe(true);
    expect(isRealSession({ appVersion: '23.1.588+621' })).toBe(true);
    expect(isRealSession({ appVersion: '' })).toBe(false);
    expect(isRealSession({ origin: 'script', appVersion: 'web' })).toBe(false);
  });
});

let mongo; let app;
let Owner; let Sitter; let Post; let Application; let ActivityEvent; let CandidatesView;
const ids = {};
const oid = (s) => new mongoose.Types.ObjectId(s);
const ins = async (M, doc) => String((await M.collection.insertOne(doc)).insertedId);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Post = require('../src/models/Post');
  Application = require('../src/models/Application'); ActivityEvent = require('../src/models/ActivityEvent');
  CandidatesView = require('../src/models/CandidatesView2610');
  ids.claire = await ins(Owner, { name: 'Claire', email: 'claire2610@example.org', city: 'Saint-Maur', status: 'active', fcmTokens: [] });
  ids.abraham = await ins(Owner, { name: 'Abraham', email: 'abraham2610@example.org', city: 'New York', status: 'active', fcmTokens: ['fcm-fictif'] });
  ids.hanene = await ins(Sitter, { name: 'Hanene', email: 'hanene2610@example.org', city: 'Paris', status: 'active' });
  const mk = (owner, city) => ins(Post, {
    ownerId: oid(owner), postType: 'request', body: 'Visites', serviceTypes: ['home_visit'], location: { city },
    hidden: false, status: 'open', startDate: new Date(Date.now() + 5 * 24 * H), endDate: new Date(Date.now() + 9 * 24 * H),
    createdAt: new Date(Date.now() - 48 * H), updatedAt: new Date(Date.now() - 48 * H),
  });
  ids.postClaire = await mk(ids.claire, 'Saint-Maur-des-Fossés');
  ids.postAbraham = await mk(ids.abraham, 'New York');
  ids.appl = await ins(Application, {
    postId: oid(ids.postClaire), ownerId: oid(ids.claire), sitterId: oid(ids.hanene), walkerId: null, status: 'pending',
    bookingId: null, createdAt: new Date(Date.now() - 47 * H), updatedAt: new Date(Date.now() - 47 * H),
  });
  app = express();
  app.use(express.json());
  app.use('/owner-signals', require('../src/routes/candidatesView2610'));
  app.use('/admin/requests613', require('../src/routes/adminRequestJourney613'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

const settle = () => new Promise((r) => setTimeout(r, 150));

describe('une session de script ne compte jamais comme un retour', () => {
  test('script puis vraie visite dans la même demi-heure : 2 sessions séparées, « vu » posé par la vraie seulement', async () => {
    const { recordActivity } = require('../src/utils/activity590');
    const t0 = Date.now() - 2 * H;
    // 1) notre script (jeton du propriétaire, Python) : session notée « script », lastSeenAt intact
    const s = await recordActivity(req({ 'user-agent': UA_PY }), ids.claire, 'owner', t0);
    await settle();
    expect(s && s.origin).toBe('script');
    expect((await Owner.findById(ids.claire).lean()).lastSeenAt || null).toBeNull();
    // 2) 10 min plus tard, Claire ouvre le site : NOUVELLE session réelle malgré le script
    const w = await recordActivity(req({ 'user-agent': UA_WEB, 'x-app-version': 'web' }), ids.claire, 'owner', t0 + 10 * 60000);
    await settle();
    expect(w && w.origin).toBe('web');
    const seen = (await Owner.findById(ids.claire).lean()).lastSeenAt;
    expect(new Date(seen).getTime()).toBe(t0 + 10 * 60000);
    // 3) 1 h plus tard, un autre script : lastSeenAt NE BOUGE PAS
    await recordActivity(req({ 'user-agent': UA_PY }), ids.claire, 'owner', t0 + 70 * 60000);
    await settle();
    expect(new Date((await Owner.findById(ids.claire).lean()).lastSeenAt).getTime()).toBe(t0 + 10 * 60000);
    expect(await ActivityEvent.countDocuments({ userId: ids.claire, origin: 'script' })).toBe(2);
    expect(await ActivityEvent.countDocuments({ userId: ids.claire, origin: 'web' })).toBe(1);
  });

  test('l’onglet « Dernière connexion » n’affiche plus les sessions de script', async () => {
    const { activitySummary } = require('../src/utils/activity590');
    const rows = await activitySummary({ days: 1 });
    const c = rows.find((r) => r.userId === ids.claire);
    expect(c.sessions).toBe(1);
  });
});

describe('repère « a ouvert ses candidats »', () => {
  const view = (who, role, headers, body) => request(app).post('/owner-signals/candidates-view')
    .set({ Authorization: `Bearer ${tok(who, role)}`, ...headers }).send(body);

  test('le propriétaire sur le site, venu de l’e-mail : 1 repère web/email ; 2e ouverture < 2 min fusionnée', async () => {
    const r1 = await view(ids.claire, 'owner', { 'user-agent': UA_WEB, 'x-app-version': 'web' }, { applicationId: ids.appl, source: 'email' });
    expect(r1.status).toBe(204);
    const r2 = await view(ids.claire, 'owner', { 'user-agent': UA_WEB, 'x-app-version': 'web' }, { postId: ids.postClaire });
    expect(r2.status).toBe(204);
    const rows = await CandidatesView.find({ postId: ids.postClaire }).lean();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ ownerId: ids.claire, channel: 'web', source: 'email', origin: 'web' });
  });

  test('dans l’app : canal app', async () => {
    await view(ids.abraham, 'owner', { 'user-agent': 'Dart/3.5 (dart:io)', 'x-app-version': '23.1.590+623' }, { postId: ids.postAbraham, source: 'push' });
    const rows = await CandidatesView.find({ postId: ids.postAbraham }).lean();
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ channel: 'app', source: 'push', origin: 'app' });
  });

  test('quelqu’un d’autre (la gardienne) ou une demande inconnue : 204 et rien d’écrit', async () => {
    const before = await CandidatesView.countDocuments();
    expect((await view(ids.hanene, 'sitter', { 'user-agent': UA_WEB }, { postId: ids.postClaire })).status).toBe(204);
    expect((await view(ids.claire, 'owner', { 'user-agent': UA_WEB }, { postId: String(new mongoose.Types.ObjectId()) })).status).toBe(204);
    expect((await view(ids.claire, 'owner', { 'user-agent': UA_WEB }, { postId: 'pas-un-id' })).status).toBe(204);
    expect(await CandidatesView.countDocuments()).toBe(before);
  });

  test('sans jeton : 401', async () => {
    const r = await request(app).post('/owner-signals/candidates-view').send({ postId: ids.postClaire });
    expect(r.status).toBe(401);
  });

  test('un script qui appelle la route : noté « script », jamais compté', async () => {
    await view(ids.claire, 'owner', { 'user-agent': UA_PY }, { postId: ids.postClaire });
    expect(await CandidatesView.countDocuments({ postId: ids.postClaire, origin: 'script' })).toBe(1);
  });
});

describe('tableau des demandes (/board)', () => {
  test('vrai dernier retour, ouvertures des candidats, app installée', async () => {
    const r = await request(app).get('/admin/requests613/board?limit=10&tz=Europe/Paris')
      .set({ Authorization: `Bearer ${tok(new mongoose.Types.ObjectId(), 'admin')}` });
    expect(r.status).toBe(200);
    const byId = Object.fromEntries(r.body.items.map((it) => [it.postId, it]));
    const c = byId[ids.postClaire].ownerSignals;
    const realAt = (await ActivityEvent.findOne({ userId: ids.claire, origin: 'web' }).lean()).at;
    const lastScript = (await ActivityEvent.findOne({ userId: ids.claire, origin: 'script' }).sort({ at: -1 }).lean()).at;
    expect(new Date(lastScript).getTime()).toBeGreaterThan(new Date(realAt).getTime()); // le script est passé APRÈS…
    expect(new Date(c.lastRealReturnAt).getTime()).toBe(new Date(realAt).getTime()); // …mais le vrai retour reste la visite web
    expect(c.lastRealReturnChannel).toBe('web');
    expect(c.realSessionsSincePublish).toBe(1);
    expect(c.candidatesView).toMatchObject({ count: 1, fromEmail: 1, channels: { web: 1, app: 0 } });
    expect(c.hasApp).toBe(false);
    const a = byId[ids.postAbraham].ownerSignals;
    expect(a.hasApp).toBe(true);
    expect(a.lastRealReturnAt).toBeNull();
    expect(a.candidatesView).toMatchObject({ count: 1, channels: { web: 0, app: 1 } });
    // aucune donnée personnelle ajoutée (ni e-mail ni jeton push)
    expect(JSON.stringify(r.body)).not.toMatch(/example\.org|fcm-fictif/);
  });
});
