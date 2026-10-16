// 16/10/2026 (ADA, demande de Daniel : « vérifier qu'elle s'efface bien une fois
// exécutée, finie ou délai passé ») — ce que voit un prestataire dans le feed
// GET /api/v1/posts/requests et dans la liste publique /posts/requests/public.
// Mesuré avant le correctif : une demande dont la date était passée restait
// visible jusqu'à sa suppression 48 h plus tard ; une demande réservée restait
// visible jusqu'au « terminé ». Vraie route, base Mongo en mémoire.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const H = 3600000;
const NOW = Date.now();
let mongo; let app; let Post;
let owner; let sitter;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mk = async (body, extra) => String((await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body, serviceTypes: ['pet_sitting'],
  location: { city: 'Zone fictive', lat: -35, lng: -30 }, reservedBy: { bookingId: null }, createdAt: new Date(), ...extra,
})).insertedId);
const feedBodies = async () => {
  const r = await request(app).get('/api/v1/posts/requests').set('Authorization', tok(sitter, 'sitter'));
  expect(r.status).toBe(200);
  return (r.body.posts || []).map((p) => p.body).sort();
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Post = require('../src/models/Post');
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter');
  owner = (await Owner.collection.insertOne({ name: 'Nina', email: 'nina-feed1610@example.test', status: 'active', verified: true })).insertedId;
  sitter = (await Sitter.collection.insertOne({ name: 'Ines', email: 'ines-feed1610@example.test', status: 'active', verified: true })).insertedId;

  await mk('A venir', { startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 72 * H) });
  await mk('En cours', { startDate: new Date(NOW - 24 * H), endDate: new Date(NOW + 24 * H) });
  await mk('Sans date', { startDate: null, endDate: null });
  await mk('Debut seul a venir', { startDate: new Date(NOW + 5 * H), endDate: null });
  await mk('Finie hier', { startDate: new Date(NOW - 48 * H), endDate: new Date(NOW - 20 * H) });
  await mk('Debut seul passe', { startDate: new Date(NOW - 3 * H), endDate: null });
  await mk('Reservee', { startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 72 * H), reservedBy: { bookingId: new mongoose.Types.ObjectId(), providerRole: 'sitter' } });
  await mk('Terminee', { startDate: new Date(NOW - 48 * H), endDate: new Date(NOW + 72 * H), status: 'closed', closedAt: new Date(NOW - H) });
  await mk('Masquee', { startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 72 * H), hidden: true });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

test('feed prestataire : seules les demandes encore ouvertes (à venir, en cours, sans date)', async () => {
  expect(await feedBodies()).toEqual(['A venir', 'Debut seul a venir', 'En cours', 'Sans date']);
});

test('expirée (fin passée) : retirée du feed même si elle n’est pas encore supprimée', async () => {
  expect(await feedBodies()).not.toContain('Finie hier');
  expect(await feedBodies()).not.toContain('Debut seul passe');
  expect(await Post.countDocuments({ body: 'Finie hier' })).toBe(1); // suppression = postCleanupScheduler, 48 h après la fin
});

test('validée puis payée (réservée) : retirée du feed', async () => {
  expect(await feedBodies()).not.toContain('Reservee');
});

test('« mes annonces » (ownerId) : le propriétaire voit encore ses demandes passées et réservées', async () => {
  const r = await request(app).get(`/api/v1/posts/requests?ownerId=${owner}`).set('Authorization', tok(owner, 'owner'));
  expect(r.status).toBe(200);
  const bodies = (r.body.posts || []).map((p) => p.body);
  expect(bodies).toContain('Finie hier');
  expect(bodies).toContain('Reservee');
  expect(bodies).not.toContain('Terminee'); // fermée par completeBooking : plus nulle part
});

test('liste publique (site) : mêmes règles, et jamais une annonce masquée', async () => {
  const r = await request(app).get('/api/v1/posts/requests/public');
  expect(r.status).toBe(200);
  const bodies = (r.body.requests || []).map((p) => p.body).sort();
  expect(bodies).toEqual(['A venir', 'Debut seul a venir', 'En cours', 'Sans date']);
});

test('suppression : postCleanupScheduler efface 48 h après la fin, pas avant', async () => {
  const { purgeFinishedPosts } = require('../src/services/postCleanupScheduler');
  await mk('Finie il y a 3 jours', { startDate: new Date(NOW - 100 * H), endDate: new Date(NOW - 72 * H) });
  const n = await purgeFinishedPosts();
  expect(n).toBe(1);
  expect(await Post.countDocuments({ body: 'Finie il y a 3 jours' })).toBe(0);
  expect(await Post.countDocuments({ body: 'Finie hier' })).toBe(1); // 20 h < 48 h : encore là, mais déjà hors feed
});
