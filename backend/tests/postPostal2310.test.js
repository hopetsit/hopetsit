/** 23/10 (BOB, ordre de Daniel) — une demande publiée avec un code postal est placée au code postal, pas au centre
 * de la ville ; sans code postal ou si le géocodage échoue, rien ne change. Base Mongo en mémoire, vrai createPost. */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
// même contrat que l'utilitaire réel : la ville saisie est conservée, sinon celle du code postal
const mockPostal = jest.fn(async (code, o) => (code === '78370' ? { city: (o && o.city) || 'Plaisir', lat: 48.8125, lng: 1.9468, postalCode: '78370' } : null));
jest.mock('../src/utils/geocodePostal2310', () => ({ locationFromPostal: (code, o) => mockPostal(code, o) }));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { const id = req.headers['x-test-user']; if (!id) return res.status(401).json({ error: 'auth' }); req.user = { id, role: req.headers['x-test-role'] || 'owner' }; return next(); },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
const express = require('express'); const request = require('supertest'); const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
let mongo; let app; let Owner; let Post; let owner; let owner2;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create(); await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Post = require('../src/models/Post');
  await Promise.all([Owner.init(), Post.init()]);
  owner = await Owner.create({ name: 'Test Postal', email: 'postal+test2310@example.com', password: 'Hopetsit2026x', city: 'Zone test', country: 'FR', verified: true, acceptedTerms: true });
  owner2 = await Owner.create({ name: 'Test Postal 2', email: 'postal2+test2310@example.com', password: 'Hopetsit2026x', city: 'Zone test', country: 'FR', verified: true, acceptedTerms: true });
  app = express(); app.use(express.json()); app.use('/posts', require('../src/routes/postRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });
const H = (o) => ({ 'x-test-user': String((o || owner)._id), 'x-test-role': 'owner' });
const BODY = { body: 'Je cherche une garde pour mon chat.', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', serviceLocation: 'at_owner', animalCount: 1, animalTypes: ['cat'], location: { city: 'Zone test', lat: -35, lng: -30 } };

test('avec code postal : la demande est placée au code postal, la ville saisie reste', async () => {
  const r = await request(app).post('/posts').set(H()).send({ ...BODY, postalCode: '78370' }).expect(201);
  const id = r.body.post && (r.body.post.id || r.body.post._id);
  const post = await Post.findById(id).lean();
  expect([post.location.city, post.location.lat, post.location.lng, post.location.postalCode]).toEqual(['Zone test', 48.8125, 1.9468, '78370']);
  expect(mockPostal).toHaveBeenCalledWith('78370', expect.objectContaining({ city: 'Zone test' }));
});
test('sans code postal, ou code postal inconnu : position d\'avant', async () => {
  const a = await request(app).post('/posts').set(H(owner2)).send({ ...BODY, body: 'Je cherche une garde pour mon chien.' }).expect(201);
  const pa = await Post.findById(a.body.post.id || a.body.post._id).lean();
  expect([pa.location.lat, pa.location.lng]).toEqual([-35, -30]);
  const b = await request(app).post('/posts').set(H(owner2)).send({ ...BODY, body: 'Je cherche des promenades pour mon chien.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', houseSittingVenue: undefined, postalCode: '00000' }).expect(201);
  const pb = await Post.findById(b.body.post.id || b.body.post._id).lean();
  expect([pb.location.lat, pb.location.lng]).toEqual([-35, -30]);
});
