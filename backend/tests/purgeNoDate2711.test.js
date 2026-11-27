/** 27/11/2026 (BOB, ordre de Daniel : « efface celles sans date de début ») — POST /admin/posts-history-1111/purge-nodate.
 *  Simulation par défaut ; avec confirm « EFFACER » : historique 'sans_date' puis effacement de la demande et de ses candidatures.
 *  Ne touche jamais : une demande datée, une demande réservée, une demande récente, une publication « media ». */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
delete process.env.POST_ARCHIVE_1111;

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
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Post; let Application; let Archive;
const oid = () => new mongoose.Types.ObjectId();
const ADMIN = { 'x-test-user': String(oid()), 'x-test-role': 'admin' };
const D = 24 * 3600000; const NOW = Date.now();
const ids = {};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = express();
  app.use(express.json());
  app.use('/admin/posts-history-1111', require('../src/routes/adminPostsHistory1111'));
  Post = require('../src/models/Post'); Application = require('../src/models/Application'); Archive = require('../src/models/PostArchive1111');
  const mk = async (k, doc) => { ids[k] = (await Post.collection.insertOne({ ownerId: oid(), postType: 'request', body: k, location: { city: 'Zone fictive', lat: -35, lng: -30 }, reservedBy: { bookingId: null }, ...doc })).insertedId; };
  await mk('vieilleSansDate', { createdAt: new Date(NOW - 30 * D) });
  await mk('vieilleSansDateSansChamps', { createdAt: new Date(NOW - 20 * D), reservedBy: undefined });
  await mk('recenteSansDate', { createdAt: new Date(NOW - 3 * D) });
  await mk('vieilleDatee', { createdAt: new Date(NOW - 30 * D), startDate: new Date(NOW + 5 * D), endDate: new Date(NOW + 8 * D) });
  await mk('vieilleDebutSeul', { createdAt: new Date(NOW - 30 * D), startDate: new Date(NOW + 5 * D) });
  await mk('vieilleReservee', { createdAt: new Date(NOW - 30 * D), reservedBy: { bookingId: oid() } });
  await mk('media', { createdAt: new Date(NOW - 30 * D), postType: 'media' });
  // (ZOE) gardien choisi mais drapeau `reservedBy` jamais posé : la candidature acceptée protège la demande.
  await mk('vieilleSansDateChoisie', { createdAt: new Date(NOW - 30 * D) });
  await Application.collection.insertMany([
    { postId: ids.vieilleSansDateChoisie, status: 'accepted', bookingId: oid() },
    { postId: ids.vieilleSansDate, status: 'pending' }, { postId: ids.vieilleSansDate, status: 'pending' },
    { postId: ids.vieilleDatee, status: 'pending' }, { postId: ids.recenteSansDate, status: 'pending' },
  ]);
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('réservé à l\'admin', async () => {
  expect((await request(app).post('/admin/posts-history-1111/purge-nodate')).status).toBe(401);
  expect((await request(app).post('/admin/posts-history-1111/purge-nodate').set({ 'x-test-user': String(oid()), 'x-test-role': 'owner' })).status).toBe(403);
});

test('sans confirmation : simulation, rien n\'est touché', async () => {
  const r = await request(app).post('/admin/posts-history-1111/purge-nodate').set(ADMIN).send({ confirm: 'oui' });
  expect(r.status).toBe(200);
  expect(r.body).toMatchObject({ dryRun: true, found: 2, applications: 2, deleted: 0 });
  expect(await Post.countDocuments({})).toBe(8);
  expect(await Application.countDocuments({})).toBe(5);
  expect(await Archive.countDocuments({})).toBe(0);
});

test('avec « EFFACER » : seules les vieilles demandes sans aucune date partent, avec leur ligne d\'historique', async () => {
  const r = await request(app).post('/admin/posts-history-1111/purge-nodate').set(ADMIN).send({ confirm: 'EFFACER' });
  expect(r.status).toBe(200);
  expect(r.body).toMatchObject({ dryRun: false, found: 2, deleted: 2, applicationsDeleted: 2 });
  const reste = (await Post.find({}).select('body').lean()).map((p) => p.body).sort();
  expect(reste).toEqual(['media', 'recenteSansDate', 'vieilleDatee', 'vieilleDebutSeul', 'vieilleReservee', 'vieilleSansDateChoisie']);
  expect(await Application.countDocuments({})).toBe(3);
  const lignes = await Archive.find({}).lean();
  expect(lignes).toHaveLength(2);
  expect(lignes.every((l) => l.reason === 'sans_date')).toBe(true);
  expect(lignes.find((l) => String(l.postId) === String(ids.vieilleSansDate)).applicationsCount).toBe(2);
});

test('un second passage ne trouve plus rien', async () => {
  const r = await request(app).post('/admin/posts-history-1111/purge-nodate').set(ADMIN).send({ confirm: 'EFFACER' });
  expect(r.body).toMatchObject({ found: 0, deleted: 0 });
});

test('la liste de l\'historique montre la raison « sans_date »', async () => {
  const r = await request(app).get('/admin/posts-history-1111/list?tests=1').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body.items.filter((i) => i.reason === 'sans_date')).toHaveLength(2);
});

describe('passage horaire (accord de Daniel du 27/11 : retrait automatique à 14 jours)', () => {
  const S = require('../src/services/postCleanupScheduler');
  const D2 = 24 * 3600000;
  const mk2 = async (body, days, extra = {}) => (await Post.collection.insertOne({ ownerId: oid(), postType: 'request', body, location: { city: 'Zone fictive', lat: -35, lng: -30 }, reservedBy: { bookingId: null }, createdAt: new Date(Date.now() - days * D2), ...extra })).insertedId;
  afterEach(() => { delete process.env.NODATE_PURGE_2711; delete process.env.NODATE_PURGE_DAYS_2711; });

  test('13 jours : gardée ; 15 jours : retirée avec sa ligne d\'historique ; datée : jamais', async () => {
    const jeune = await mk2('auto13', 13); const vieille = await mk2('auto15', 15);
    const datee = await mk2('autoDatee', 40, { startDate: new Date(Date.now() + 9 * D2), endDate: new Date(Date.now() + 12 * D2) });
    await S.tick();
    expect(await Post.countDocuments({ _id: jeune })).toBe(1);
    expect(await Post.countDocuments({ _id: vieille })).toBe(0);
    expect(await Post.countDocuments({ _id: datee })).toBe(1);
    expect((await Archive.findOne({ postId: vieille }).lean()).reason).toBe('sans_date');
  });

  test('coupe-circuit NODATE_PURGE_2711=off : rien ne part', async () => {
    const vieille = await mk2('autoCoupe', 30);
    process.env.NODATE_PURGE_2711 = 'off';
    await S.tick();
    expect(await Post.countDocuments({ _id: vieille })).toBe(1);
    delete process.env.NODATE_PURGE_2711;
    process.env.NODATE_PURGE_DAYS_2711 = '60';
    await S.tick();
    expect(await Post.countDocuments({ _id: vieille })).toBe(1); // 30 jours < 60
    process.env.NODATE_PURGE_DAYS_2711 = '3'; // hors bornes → 14
    await S.tick();
    expect(await Post.countDocuments({ _id: vieille })).toBe(0);
  });
});
