// 1617 (LEO, 16/10/2026, §D.2) — DOUBLON DE PUBLICATION REFUSÉ.
// Cas réel : 2 balades identiques à Tallinn le 15/10. Vrais gestionnaires
// createPost / createPostWithMedia sur une base Mongo en mémoire, zone fictive
// (lat −35 / lng −30), aucun envoi réel (push, e-mail, Cloudinary mockés).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async () => null),
  resolveAppLocaleAcrossRoles: jest.fn(async () => 'fr'),
  resolveNotificationPrefsAcrossRoles: jest.fn(async () => ({ sound: 'default', categories: {} })),
  pushSoundConfig: jest.fn(() => ({ android: {}, apnsSound: null, dataSound: 'default' })),
}));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/services/cloudinary', () => ({
  uploadMedia: jest.fn(async () => ({ url: 'https://example.test/p.jpg', secure_url: 'https://example.test/p.jpg', public_id: 'p', publicId: 'p' })),
}));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || '').replace(/\s*\d+\s*(er|e|eme|ème)?\s*$/i, '').trim(),
  geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Post; let Owner; let postController; let ownerId; let otherOwnerId;
const mockRes = () => { const res = {}; res.status = jest.fn(() => res); res.json = jest.fn((b) => { res.body = b; return res; }); return res; };
const D1 = '2026-11-20T18:30:00.000Z'; const D1E = '2026-11-20T19:00:00.000Z';
const D2 = '2026-11-21T18:30:00.000Z'; const D2E = '2026-11-21T19:00:00.000Z';

const publish = async (over = {}, who = ownerId) => {
  const res = mockRes();
  await postController.createPost({
    user: { id: who, role: 'owner' },
    body: {
      body: 'Balade de Rex', serviceTypes: ['dog_walking'], startDate: D1, endDate: D1E,
      location: { city: 'Zone test', lat: -35, lng: -30 }, serviceLocation: 'pickup', ...over,
    },
  }, res);
  return res;
};
const publishMedia = async (over = {}) => {
  const res = mockRes();
  await postController.createPostWithMedia({
    user: { id: ownerId, role: 'owner' },
    body: {
      body: 'Balade photo', serviceTypes: 'dog_walking', startDate: D1, endDate: D1E, serviceLocation: 'pickup',
      location: JSON.stringify({ city: 'Zone test', lat: -35, lng: -30 }), ...over,
    },
    files: { images: [{ fieldname: 'images', originalname: 'p.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('x') }] },
  }, res);
  return res;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post');
  Owner = require('../src/models/Owner');
  postController = require('../src/controllers/postController');
  const r = await Owner.collection.insertOne({ name: 'Nicola', email: 'nicola-dup1617@example.test', language: 'fr', appLocale: 'fr', status: 'active', verified: true, location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' } });
  ownerId = r.insertedId.toString();
  const r2 = await Owner.collection.insertOne({ name: 'Autre', email: 'autre-dup1617@example.test', language: 'en', status: 'active', verified: true, location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' } });
  otherOwnerId = r2.insertedId.toString();
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => { await Post.deleteMany({}); });

test('1re publication : 201 avec notified ET alertRadiusKm (= 100, pas en dur côté client)', async () => {
  const res = await publish();
  expect(res.status).toHaveBeenCalledWith(201);
  expect(res.body.alertRadiusKm).toBe(require('../src/services/requestAlert612').ALERT_RADIUS_KM);
  expect(res.body.alertRadiusKm).toBe(100);
  expect(typeof res.body.notified).toBe('number');
  expect(res.body.notified).toBe(0); // zone fictive : personne autour
});

test('doublon exact (même propriétaire, service, ville, jours) → 409 DUPLICATE_REQUEST, message FR, id de la demande existante', async () => {
  const first = await publish();
  const second = await publish();
  expect(second.status).toHaveBeenCalledWith(409);
  expect(second.body.code).toBe('DUPLICATE_REQUEST');
  expect(second.body.existingPostId).toBe(first.body.post.id);
  expect(second.body.error).toMatch(/déjà publié/);
  expect(await Post.countDocuments({ ownerId })).toBe(1);
});

test('la langue du propriétaire est respectée (appLocale fr ; language en pour l\'autre)', async () => {
  await publish({}, otherOwnerId);
  const again = await publish({}, otherOwnerId);
  expect(again.status).toHaveBeenCalledWith(409);
  expect(again.body.error).toMatch(/already posted/);
});

test('« Paris 11e » et « paris » = même ville ; les accents ne comptent pas', async () => {
  await publish({ location: { city: 'Paris 11e', lat: 48.86, lng: 2.38 } });
  const twin = await publish({ location: { city: 'PARIS', lat: 48.86, lng: 2.38 } });
  expect(twin.status).toHaveBeenCalledWith(409);
});

test('dates différentes → OK (2 balades, mardi et mercredi)', async () => {
  await publish();
  const other = await publish({ startDate: D2, endDate: D2E });
  expect(other.status).toHaveBeenCalledWith(201);
  expect(await Post.countDocuments({ ownerId })).toBe(2);
});

test('ville différente → OK', async () => {
  await publish();
  const other = await publish({ location: { city: 'Autre zone', lat: -36, lng: -31 } });
  expect(other.status).toHaveBeenCalledWith(201);
});

test('services différents → OK (garde ≠ balade)', async () => {
  await publish();
  const other = await publish({ serviceTypes: ['pet_sitting'], serviceLocation: 'at_owner' });
  expect(other.status).toHaveBeenCalledWith(201);
});

test('un autre propriétaire peut publier la même demande', async () => {
  await publish();
  const other = await publish({}, otherOwnerId);
  expect(other.status).toHaveBeenCalledWith(201);
});

test('demande existante FERMÉE → republier est permis', async () => {
  const first = await publish();
  await Post.updateOne({ _id: first.body.post.id }, { $set: { status: 'closed', closedAt: new Date() } });
  const again = await publish();
  expect(again.status).toHaveBeenCalledWith(201);
});

test('demande existante MASQUÉE (admin) ou RÉSERVÉE → republier est permis', async () => {
  const a = await publish();
  await Post.updateOne({ _id: a.body.post.id }, { $set: { hidden: true } });
  expect((await publish()).status).toHaveBeenCalledWith(201);
  await Post.deleteMany({});
  const b = await publish();
  await Post.updateOne({ _id: b.body.post.id }, { $set: { 'reservedBy.bookingId': new mongoose.Types.ObjectId() } });
  expect((await publish()).status).toHaveBeenCalledWith(201);
});

test('demande existante dont la prestation est PASSÉE → republier est permis', async () => {
  const past = { startDate: '2026-01-05T09:00:00.000Z', endDate: '2026-01-05T10:00:00.000Z' };
  await Post.collection.insertOne({
    ownerId: new mongoose.Types.ObjectId(ownerId), postType: 'request', status: 'open', hidden: false, body: 'Vieille',
    serviceTypes: ['dog_walking'], location: { city: 'Zone test', lat: -35, lng: -30 },
    startDate: new Date(past.startDate), endDate: new Date(past.endDate), reservedBy: { bookingId: null }, createdAt: new Date('2026-01-01'),
  });
  const again = await publish(past);
  expect(again.status).toHaveBeenCalledWith(201);
});

test('createPostWithMedia (demande AVEC photo) : doublon refusé aussi, 409 + existingPostId ; autre date OK', async () => {
  const first = await publish();
  const dup = await publishMedia();
  expect(dup.status).toHaveBeenCalledWith(409);
  expect(dup.body.code).toBe('DUPLICATE_REQUEST');
  expect(dup.body.existingPostId).toBe(first.body.post.id);
  const ok = await publishMedia({ startDate: D2, endDate: D2E });
  expect(ok.status).toHaveBeenCalledWith(201);
  expect(ok.body.alertRadiusKm).toBe(100);
});

test('photo SOCIALE (media, sans service ni dates) : jamais concernée', async () => {
  const res = mockRes();
  await postController.createPostWithMedia({
    user: { id: ownerId, role: 'owner' }, body: { body: 'Rex au parc' },
    files: { images: [{ fieldname: 'images', originalname: 'p.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('x') }] },
  }, res);
  expect(res.status).toHaveBeenCalledWith(201);
  expect(res.body.alertRadiusKm).toBeUndefined();
  const res2 = mockRes();
  await postController.createPostWithMedia({
    user: { id: ownerId, role: 'owner' }, body: { body: 'Rex au parc' },
    files: { images: [{ fieldname: 'images', originalname: 'p.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('x') }] },
  }, res2);
  expect(res2.status).toHaveBeenCalledWith(201);
});

test('utilitaire pur : fingerprint trie les services et replie la ville', () => {
  const { fingerprint, duplicateMessage, MESSAGES } = require('../src/utils/duplicateRequest1617');
  expect(fingerprint({ services: ['b', 'a'], city: 'Paris 11e', startDate: D1, endDate: D1E }))
    .toBe(fingerprint({ services: ['a', 'b'], city: 'PARÍS', startDate: D1, endDate: D1E }));
  expect(Object.keys(MESSAGES).sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
  expect(duplicateMessage('xx')).toBe(MESSAGES.en);
});
