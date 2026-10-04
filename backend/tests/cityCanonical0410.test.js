// 04/10/2026 (ZOE, mission BOB) — première vraie demande, ville « Parigi ».
// Une ville écrite dans la langue du téléphone ne doit casser ni le ciblage
// des promeneurs, ni l'enregistrement, ni la relance depuis l'admin.
// VRAIE base Mongo en mémoire, vrais gestionnaires, envois simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  return { ...actual, geocodeCity: jest.fn(async () => null) };
});
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role)
    ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { sendNotification } = require('../src/services/notificationSender');
const { canonicalCityName } = require('../src/utils/canonicalCity0410');

const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
// Position réelle de la demande de Nicola (Paris 11e), relevée le 04/10.
const PARIS11 = { lat: 48.866412377839644, lng: 2.369837512661996 };

let mongo; let app;
let Owner; let Walker; let Post; let Notification;
let owner; let wParis; let wBoulogne; let wLyon; let wParigiLegacy;
let notify;

const run = (args) => new Promise((resolve) => notify({ ...args, opts: { ...(args.opts || {}), onDone: resolve } }));
const sentTo = () => sendNotification.mock.calls.map((c) => c[0].userId);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Walker = require('../src/models/Walker');
  Post = require('../src/models/Post');
  Notification = require('../src/models/Notification');
  ({ notifyNearbyProviders: notify } = require('../src/controllers/postController'));
  const o = await Owner.collection.insertOne({
    name: 'Nicola Test', email: 'nicola0410@example.test', language: 'it',
    location: { type: 'Point', coordinates: [PARIS11.lng, PARIS11.lat], city: 'Parigi' },
  });
  owner = { _id: o.insertedId, name: 'Nicola Test', email: 'nicola0410@example.test' };
  const ins = async (name, city, lng, lat, extra = {}) => String((await Walker.collection.insertOne({
    name, email: `${name.toLowerCase()}0410@example.test`,
    location: { type: 'Point', coordinates: [lng, lat], city }, city, ...extra,
  })).insertedId);
  wParis = await ins('Sarah', 'Paris', 2.38, 48.85, { coverageRadiusKm: 20 });
  wBoulogne = await ins('Ishwari', 'Boulogne-Billancourt', 2.24, 48.835, { coverageRadiusKm: 15, password: 'MotDePasse0410!' });
  wLyon = await ins('Lea', 'Lyon', 4.8357, 45.764, { coverageRadiusKm: 20 });
  // Promeneur enregistré AVANT le correctif avec « Parigi », sans coordonnées.
  wParigiLegacy = String((await Walker.collection.insertOne({
    name: 'Marco', email: 'marco0410@example.test', city: 'Parigi', location: { city: 'Parigi' },
  })).insertedId);
  app = express();
  app.use(express.json());
  app.use('/admin/requests0410', require('../src/routes/adminRequests0410'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(() => sendNotification.mockClear());

const post = (city, coords) => ({
  newPost: { _id: new mongoose.Types.ObjectId() },
  postPayload: { location: coords ? { city, lat: coords.lat, lng: coords.lng } : { city } },
  normalizedServices: ['dog_walking'],
  owner,
  ownerId: String(owner._id),
});

describe('nom canonique (9 langues de l app + néerlandais)', () => {
  test.each([
    ['Parigi', 'Paris'], ['París', 'Paris'], ['Paryż', 'Paris'], ['Parijs', 'Paris'],
    ['パリ', 'Paris'], ['파리', 'Paris'], ['Paris', 'Paris'], ['Parigi 11', 'Paris 11'],
    ['Parigi, Francia', 'Paris'], ['Londra', 'London'], ['Londres', 'London'], ['Mailand', 'Milano'],
    ['Nueva York', 'New York'], ['Nowy Jork', 'New York'], ['ニューヨーク', 'New York'], ['댈러스', 'Dallas'],
    ['Marsiglia', 'Marseille'], ['Lione', 'Lyon'], ['Nizza', 'Nice'], ['Monachium', 'München'],
  ])('%s → %s', (inp, out) => expect(canonicalCityName(inp)).toBe(out));

  test.each(['Paris 15e', 'Boulogne-Billancourt', 'Saint-Germain-en-Laye', 'Zone test', 'Vienne', 'Monaco', 'Dallas'])(
    '%s inchangé', (v) => expect(canonicalCityName(v)).toBe(v),
  );

  test('autre lieu du même nom (coordonnées en Indonésie) → inchangé', () => {
    expect(canonicalCityName('Parigi', { lat: -0.8, lng: 120.18 })).toBe('Parigi');
    expect(canonicalCityName('Parigi', PARIS11)).toBe('Paris');
  });
});

describe('ciblage des promeneurs : demande avec les coordonnées de Paris', () => {
  test.each(['Parigi', 'París', 'Paris', 'Paryż', 'パリ', '파리', 'Parijs', 'Parigi 11'])(
    '« %s » + Paris 11e → promeneurs de Paris et Boulogne prévenus, pas Lyon', async (city) => {
      const b = await run(post(city, PARIS11));
      const ids = sentTo();
      expect(ids).toEqual(expect.arrayContaining([wParis, wBoulogne]));
      expect(ids).not.toContain(wLyon);
      expect(b.cityKey).toBe('Paris');
      expect(b.sent.length).toBe(ids.length);
      expect(sendNotification.mock.calls[0][0].type).toBe('new_request_nearby');
      expect(sendNotification.mock.calls[0][0].data.city).toBe('Paris');
    },
  );
});

describe('repli par nom quand la demande n a pas de coordonnées', () => {
  test.each(['Parigi', 'París', 'Paryż', 'パリ', '파리', 'Parijs'])(
    '« %s » sans coordonnées → le promeneur qui écrit « Paris » est prévenu', async (city) => {
      const b = await run(post(city, null));
      expect(sentTo()).toContain(wParis);
      expect(sentTo()).not.toContain(wLyon);
      expect(b.cityKey).toBe('Paris');
    },
  );

  test('« Parigi » en Indonésie (coordonnées là-bas) → aucun promeneur parisien', async () => {
    await run(post('Parigi', { lat: -0.8, lng: 120.18 }));
    expect(sentTo()).not.toContain(wParis);
    expect(sentTo()).not.toContain(wBoulogne);
  });
});

describe('enregistrement : toutes les écritures de ville', () => {
  test('Post.create « Parigi » + coordonnées de Paris → « Paris »', async () => {
    const p = await Post.create({
      ownerId: owner._id, body: 'Richiesta di prenotazione', postType: 'request',
      serviceTypes: ['dog_walking'], location: { city: 'Parigi', ...PARIS11 },
    });
    const back = await Post.findById(p._id).lean();
    expect(back.location.city).toBe('Paris');
    expect(back.location.lat).toBeCloseTo(PARIS11.lat, 6);
  });

  test('profil : updateOne $set location.city / city, findOneAndUpdate, save()', async () => {
    await Owner.updateOne({ _id: owner._id }, { $set: { 'location.city': 'París', city: 'Parigi' } });
    let o = await Owner.findById(owner._id).lean();
    expect(o.location.city).toBe('Paris');
    expect(o.city).toBe('Paris');
    await Walker.findOneAndUpdate({ _id: wLyon }, { $set: { coverageCity: 'Lione' } });
    expect((await Walker.findById(wLyon).lean()).coverageCity).toBe('Lyon');
    const w = await Walker.findById(wBoulogne);
    w.city = 'Boulogne-Billancourt';
    w.coverageCity = 'Parigi';
    await w.save();
    expect((await Walker.findById(wBoulogne).lean()).coverageCity).toBe('Paris');
    o = await Owner.findById(owner._id).lean();
    expect(o.location.coordinates).toEqual([PARIS11.lng, PARIS11.lat]);
  });

  test('un nom inconnu passe intact', async () => {
    await Owner.updateOne({ _id: owner._id }, { $set: { city: 'Saint-Germain-en-Laye' } });
    expect((await Owner.findById(owner._id).lean()).city).toBe('Saint-Germain-en-Laye');
  });
});

describe('admin : qui a été prévenu, relance sans doublon, villes non canoniques', () => {
  let pid;
  beforeAll(async () => {
    const p = await Post.collection.insertOne({
      ownerId: owner._id, body: 'Richiesta di prenotazione', postType: 'request',
      serviceTypes: ['dog_walking'], location: { city: 'Parigi', ...PARIS11 }, createdAt: new Date(),
    });
    pid = String(p.insertedId);
    // Sarah a déjà été prévenue à la publication.
    await Notification.create({
      recipientRole: 'walker', recipientId: wParis, actorRole: 'owner', actorId: owner._id,
      type: 'new_request_nearby', data: { postId: pid, city: 'Parigi' },
    });
  });

  test('GET notified : liste ceux déjà prévenus', async () => {
    const r = await request(app).get(`/admin/requests0410/${pid}/notified`).set(ADMIN);
    expect(r.status).toBe(200);
    expect(r.body.notifiedCount).toBe(1);
    expect(r.body.notified[0]).toMatchObject({ id: wParis, role: 'walker', name: 'Sarah', read: false });
    expect(JSON.stringify(r.body)).not.toMatch(/@/);
  });

  test('POST renotify : simulation par défaut, rien n est envoyé', async () => {
    const r = await request(app).post(`/admin/requests0410/${pid}/renotify`).set(ADMIN).send({});
    expect(r.status).toBe(200);
    expect(r.body.dryRun).toBe(true);
    expect(r.body.sent).toBe(0);
    expect(r.body.skippedAlready).toBe(1);
    expect(r.body.candidateIds).toContain(wBoulogne);
    expect(r.body.candidateIds).not.toContain(wParis);
    expect(sendNotification).not.toHaveBeenCalled();
  });

  test('POST renotify dryRun:false : envoie aux seuls non prévenus, jamais deux fois', async () => {
    const r = await request(app).post(`/admin/requests0410/${pid}/renotify`).set(ADMIN).send({ dryRun: false });
    expect(r.status).toBe(200);
    expect(r.body.sent).toBeGreaterThan(0);
    expect(sentTo()).toContain(wBoulogne);
    expect(sentTo()).not.toContain(wParis);
    expect(sentTo()).not.toContain(wLyon);
    expect(sendNotification.mock.calls.every((c) => c[0].type === 'new_request_nearby')).toBe(true);
  });

  test('POST renotify resend:true : renvoie AUSSI à ceux déjà prévenus (ordre explicite), jamais par défaut', async () => {
    const r = await request(app).post(`/admin/requests0410/${pid}/renotify`).set(ADMIN).send({ dryRun: false, resend: true });
    expect(r.status).toBe(200);
    expect(r.body.resend).toBe(true);
    expect(sentTo()).toContain(wParis);
    expect(sentTo()).toContain(wBoulogne);
    expect(sentTo()).not.toContain(wLyon);
  });

  test('alsoSkipPostIds : déjà prévenu pour l autre demande du même propriétaire → pas renvoyé', async () => {
    const other = String((await Post.collection.insertOne({
      ownerId: owner._id, body: 'Richiesta di prenotazione', postType: 'request',
      serviceTypes: ['dog_walking'], location: { city: 'Parigi', ...PARIS11 }, createdAt: new Date(),
    })).insertedId);
    const first = String((await Post.collection.insertOne({
      ownerId: owner._id, body: 'Richiesta di prenotazione', postType: 'request',
      serviceTypes: ['dog_walking'], location: { city: 'Parigi', ...PARIS11 }, createdAt: new Date(),
    })).insertedId);
    await Notification.create({
      recipientRole: 'walker', recipientId: wBoulogne, actorRole: 'owner', actorId: owner._id,
      type: 'new_request_nearby', data: { postId: first, city: 'Parigi' },
    });
    const r = await request(app).post(`/admin/requests0410/${other}/renotify`).set(ADMIN)
      .send({ dryRun: true, alsoSkipPostIds: [first] });
    expect(r.status).toBe(200);
    expect(r.body.candidateIds).not.toContain(wBoulogne);
    expect(r.body.candidateIds).toContain(wParis);
  });

  test('refusé sans droits admin', async () => {
    const r = await request(app).post(`/admin/requests0410/${pid}/renotify`)
      .set({ 'x-test-user': String(owner._id), 'x-test-role': 'owner' }).send({ dryRun: false });
    expect(r.status).toBe(403);
  });

  test('GET cities/non-canonical : liste « Parigi » sans rien modifier', async () => {
    const r = await request(app).get('/admin/requests0410/cities/non-canonical').set(ADMIN);
    expect(r.status).toBe(200);
    expect(r.body.readOnly).toBe(true);
    const vals = r.body.rows.map((x) => `${x.collection}:${x.field}:${x.value}`);
    expect(vals).toEqual(expect.arrayContaining(['walkers:city:Parigi', 'posts:location.city:Parigi']));
    expect((await Walker.findById(wParigiLegacy).lean()).city).toBe('Parigi');
  });
});

describe('géocodage : on interroge le nom local', () => {
  test('geocodeCity(« Parigi ») demande « Paris » à Photon', async () => {
    const real = jest.requireActual('../src/utils/geocodeCity');
    real._resetForTest();
    const urls = [];
    const orig = global.fetch;
    global.fetch = jest.fn(async (u) => { urls.push(String(u)); return { ok: true, json: async () => ({ features: [{ geometry: { coordinates: [2.35, 48.85] } }] }) }; });
    try {
      const g = await real.geocodeCity('Parigi');
      expect(g).toEqual({ lat: 48.85, lng: 2.35 });
      expect(urls[0]).toContain('q=Paris');
      expect(real.baseCityName('Parigi 11')).toBe('Paris');
    } finally { global.fetch = orig; }
  });
});
