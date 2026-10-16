// 16/10/2026 (ADA, demande de Daniel) — parcours d'une demande dans l'admin :
// début ET fin de prestation (fuseau de la ville), visibilité pour les
// prestataires + date de suppression, distance de chaque prévenu / candidat.
// Cas réel rejoué avec des données FICTIVES : garde à New York, candidatures du
// Bronx, de Hartford et de Busan. Base Mongo en mémoire, vraie route.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const H = 3600000;
const NOW = Date.now();
const NYC = { lat: 40.7128, lng: -74.006 };

let mongo; let app;
let Owner; let Sitter; let Post; let Notification; let Application;
const ids = {};
const oid = (s) => new mongoose.Types.ObjectId(s);
const ins = async (M, doc) => String((await M.collection.insertOne(doc)).insertedId);
const mkPost = (extra = {}) => ins(Post, {
  ownerId: oid(ids.owner), postType: 'request', body: 'Garde', serviceTypes: ['pet_sitting'],
  location: { city: 'New York', ...NYC }, hidden: false, status: 'open',
  startDate: new Date('2026-10-05T15:00:00Z'), endDate: new Date('2026-10-29T00:00:00Z'),
  createdAt: new Date(NOW - 24 * H), updatedAt: new Date(NOW - 24 * H), ...extra,
});
const notif = (postId, rid, at) => ins(Notification, {
  type: 'new_request_nearby', recipientRole: 'sitter', recipientId: oid(rid), title: 't', body: 'b',
  data: { postId: String(postId) }, createdAt: new Date(at), readAt: null,
});
const appl = (postId, pid) => ins(Application, {
  postId: oid(postId), ownerId: oid(ids.owner), sitterId: oid(pid), walkerId: null, status: 'pending', bookingId: null,
  createdAt: new Date(NOW - H), updatedAt: new Date(NOW - H),
});
const get = (url) => request(app).get(url).set(ADMIN);
const journey = async (pid) => { const r = await get(`/admin/requests613/${pid}/journey`); expect(r.status).toBe(200); return r.body; };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Post = require('../src/models/Post');
  Notification = require('../src/models/Notification'); Application = require('../src/models/Application');
  ids.owner = await ins(Owner, { name: 'Abraham', email: 'abraham1610@example.org', city: 'New York' });
  ids.persia = await ins(Sitter, { name: 'Persia', email: 'persia1610@example.org', city: 'New York', location: { type: 'Point', coordinates: [-73.8559, 40.8331] } });
  ids.nieheem = await ins(Sitter, { name: 'Nieheem', email: 'nieheem1610@example.org', city: 'New York', location: { type: 'Point', coordinates: [-73.9097, 40.8361] } });
  ids.anahi = await ins(Sitter, { name: 'Anahi', email: 'anahi1610@example.org', city: 'Hartford', location: { type: 'Point', coordinates: [-72.6708, 41.7702] } });
  ids.yuju = await ins(Sitter, { name: '유주', email: 'yuju1610@example.org', city: '부산광역시', location: { type: 'Point', coordinates: [129.036, 35.1718] } });
  ids.nowhere = await ins(Sitter, { name: 'Sans', email: 'sans1610@example.org', city: '' });
  app = express();
  app.use(express.json());
  app.use('/admin/requests613', require('../src/routes/adminRequestJourney613'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

describe('la garde de New York (en cours, 3 candidatures)', () => {
  let pid; let it;
  beforeAll(async () => {
    pid = await mkPost({ startDate: new Date(NOW - 10 * 24 * H), endDate: new Date(NOW + 13 * 24 * H) });
    await notif(pid, ids.persia, NOW - 24 * H);
    await notif(pid, ids.persia, NOW - 22.5 * H); // relance admin : même personne, 2 lignes
    await appl(pid, ids.yuju); await appl(pid, ids.anahi); await appl(pid, ids.nieheem);
    it = await journey(pid);
  });
  test('début, fin, fuseau de la ville (New York) et position connue', () => {
    expect(it.serviceDate).toBeTruthy();
    expect(it.serviceEnd).toBeTruthy();
    expect(it.serviceTimeZone).toBe('America/New_York');
    expect(it.hasPosition).toBe(true);
    expect(it.walkDurationMinutes).toBeNull();
  });
  test('visibilité : en ligne pour les prestataires, suppression 48 h après la fin', () => {
    expect(it.visibility.state).toBe('online');
    expect(new Date(it.visibility.until).getTime()).toBe(new Date(it.serviceEnd).getTime());
    expect(new Date(it.visibility.deleteAt).getTime()).toBe(new Date(it.serviceEnd).getTime() + 48 * H);
  });
  test('distance de chaque candidat : Bronx ≈ 16 km, Hartford ≈ 160 km, Busan ≈ 11 000 km', () => {
    const km = Object.fromEntries(it.applications.map((a) => [a.name, a.km]));
    expect(km['Nieheem']).toBeGreaterThan(5); expect(km['Nieheem']).toBeLessThan(30);
    expect(km['Anahi']).toBeGreaterThan(140); expect(km['Anahi']).toBeLessThan(200);
    expect(km['유주']).toBeGreaterThan(10500); expect(km['유주']).toBeLessThan(11500);
  });
  test('prévenus : 1 personne, 2 notifications, distance sur chaque ligne', () => {
    expect(it.stages.notified.count).toBe(1);
    expect(it.stages.notified.notifications).toBe(2);
    expect(it.notified).toHaveLength(2);
    for (const n of it.notified) { expect(n.km).toBeGreaterThan(5); expect(n.km).toBeLessThan(30); }
    expect(JSON.stringify(it)).not.toMatch(/@/);
  });
});

describe('visibilité selon l’état', () => {
  test('prestation finie hier, sans validation : expirée, retirée des prestataires, suppression dans 48 h − 20 h', async () => {
    const pid = await mkPost({ startDate: new Date(NOW - 48 * H), endDate: new Date(NOW - 20 * H) });
    const it = await journey(pid);
    expect(it.status).toBe('expired');
    expect(it.visibility.state).toBe('expired');
    expect(new Date(it.visibility.deleteAt).getTime()).toBe(NOW - 20 * H + 48 * H);
  });
  test('réservée (booking) : retirée des prestataires', async () => {
    const pid = await mkPost({ reservedBy: { bookingId: oid(String(new mongoose.Types.ObjectId())), providerRole: 'sitter', reservedAt: new Date(NOW - H) }, endDate: new Date(NOW + 48 * H) });
    const it = await journey(pid);
    expect(it.visibility.state).toBe('reserved');
    expect(it.visibility.since).toBeTruthy();
  });
  test('fermée par completeBooking : « closed », suppression 48 h après closedAt', async () => {
    const pid = await mkPost({ status: 'closed', closedAt: new Date(NOW - 2 * H), endDate: new Date(NOW - 3 * H) });
    const it = await journey(pid);
    expect(it.visibility.state).toBe('closed');
    expect(new Date(it.visibility.deleteAt).getTime()).toBe(NOW - 2 * H + 48 * H);
  });
  test('masquée par l’admin : « hidden »', async () => {
    const pid = await mkPost({ hidden: true, bannedAt: new Date(NOW - H) });
    const it = await journey(pid);
    expect(it.visibility.state).toBe('hidden');
  });
  test('balade sans fin explicite : durée choisie renvoyée, pas de fuseau sans position', async () => {
    const pid = await mkPost({ serviceTypes: ['dog_walking'], location: { city: 'Nulle-Part' }, startDate: new Date(NOW + 5 * H), endDate: null, walkDurationMinutes: 45 });
    const it = await journey(pid);
    expect(it.walkDurationMinutes).toBe(45);
    expect(it.serviceEnd).toBeNull();
    expect(it.serviceTimeZone).toBeNull();
    expect(it.hasPosition).toBe(false);
    expect(it.visibility.state).toBe('online');
    await appl(pid, ids.nowhere);
    const again = await journey(pid);
    expect(again.applications[0].km).toBeNull(); // sans position : pas de distance inventée
  });
});
