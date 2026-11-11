/** 11/11/2026 (BOB) — GET /admin/posts-history-1111/list : historique des demandes effacées. Lecture seule, sans e-mail. */
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
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (req, res, next) => next() }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app;
const oid = () => new mongoose.Types.ObjectId();
const ADMIN = { 'x-test-user': String(oid()), 'x-test-role': 'admin' };
const H = 3600000; const NOW = Date.now();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = express();
  app.use(express.json());
  app.use('/admin/posts-history-1111', require('../src/routes/adminPostsHistory1111'));
  const A = require('../src/models/PostArchive1111'); const Post = require('../src/models/Post');
  await A.collection.insertMany([
    { postId: oid(), ownerId: oid(), ownerFirstName: 'Lea', city: 'Zone A', serviceTypes: ['pet_sitting'], startDate: new Date(NOW - 200 * H), endDate: new Date(NOW - 150 * H), body: 'Garde', applicationsCount: 3, bookingId: oid(), reason: 'service_termine', isTest: false, archivedAt: new Date(NOW - 2 * H) },
    { postId: oid(), ownerId: oid(), ownerFirstName: 'Max', city: 'Zone B', serviceTypes: ['dog_walking'], startDate: new Date(NOW - 300 * H), endDate: null, body: '', applicationsCount: 0, bookingId: null, reason: 'date_passee', isTest: false, archivedAt: new Date(NOW - 50 * H) },
    { postId: oid(), ownerId: oid(), ownerFirstName: 'Test', city: 'Zone fictive', serviceTypes: [], reason: 'date_passee', isTest: true, archivedAt: new Date(NOW - H) },
  ]);
  await Post.collection.insertMany([
    { postType: 'request', startDate: new Date(NOW - 60 * H), endDate: new Date(NOW - 10 * H) }, // finie < 48 h : en attente
    { postType: 'request', startDate: new Date(NOW + 60 * H), endDate: new Date(NOW + 90 * H) }, // à venir
    { postType: 'request', startDate: new Date(NOW - 300 * H), endDate: new Date(NOW - 200 * H) }, // > 48 h : sera effacée au prochain passage
  ]);
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('réservé à l\'admin', async () => {
  expect((await request(app).get('/admin/posts-history-1111/list')).status).toBe(401);
  expect((await request(app).get('/admin/posts-history-1111/list').set({ 'x-test-user': String(oid()), 'x-test-role': 'sitter' })).status).toBe(403);
});

test('liste : la plus récente d\'abord, tests à part, aucune donnée personnelle', async () => {
  const r = await request(app).get('/admin/posts-history-1111/list').set(ADMIN);
  expect(r.status).toBe(200);
  expect(r.body.total).toBe(2);
  expect(r.body.testsCount).toBe(1);
  expect(r.body.pending).toBe(1);
  expect(r.body.archiveEnabled).toBe(true);
  expect(r.body.items.map((i) => i.firstName)).toEqual(['Lea', 'Max']);
  expect(r.body.items[0]).toMatchObject({ city: 'Zone A', applications: 3, booked: true, reason: 'service_termine' });
  expect(r.body.items[1]).toMatchObject({ booked: false, reason: 'date_passee', endDate: null });
  expect(JSON.stringify(r.body)).not.toMatch(/@|email|phone/i);
});

test('tests=1 et pagination', async () => {
  const all = await request(app).get('/admin/posts-history-1111/list?tests=1&limit=2').set(ADMIN);
  expect(all.body.total).toBe(3);
  expect(all.body.pages).toBe(2);
  expect(all.body.items).toHaveLength(2);
  const p2 = await request(app).get('/admin/posts-history-1111/list?tests=1&limit=2&page=2').set(ADMIN);
  expect(p2.body.items).toHaveLength(1);
});
