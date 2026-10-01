// 607b (ZOE, 01/10/2026) — FUITE relevée par PAM : les routes PUBLIQUES (sans
// connexion) renvoyaient `preferences` et `notificationPrefs` des gardiens,
// et d'autres champs de compte que ni l'app ni le site n'affichent jamais
// pour une autre personne (e-mail en attente, refus marketing, 2FA, code et
// parrain, position de profil brute, préférences de recherche…).
// Vraie base Mongo en mémoire + vraie application Express : on appelle les
// routes exactement comme un inconnu sur Internet, puis on cherche les clés
// interdites PARTOUT dans la réponse (à toutes les profondeurs).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

// Aucun réseau : Firebase (push) et la doc Swagger sont neutralisés.
jest.mock('../src/config/firebaseAdmin', () => ({
  auth: () => ({ verifyIdToken: async () => { throw new Error('no firebase in tests'); } }),
  messaging: () => ({ send: async () => 'x', sendEachForMulticast: async () => ({ responses: [] }) }),
}));
jest.mock('../src/config/swagger', () => ({ openapi: '3.0.0', info: { title: 't', version: '0' }, paths: {} }));

const mongoose = require('mongoose');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Sitter; let Walker; let Owner;
let sitter; let walker; let owner;

// Clés qui ne doivent JAMAIS sortir d'une route publique.
const PRIVATE_KEYS = [
  'preferences', 'notificationPrefs', 'searchPreferences', 'servicePreferences',
  'pendingEmail', 'pendingEmailExpiresAt', 'pendingEmailSentAt', 'pendingEmailCodeHash',
  'marketingOptOut', 'twoFactorEnabled', 'referralCode', 'referredBy',
  'favoriteProviders', 'homeLocation', 'email', 'mobile', 'password',
  'fcmTokens', 'fcmDevices', 'walletBalance', 'ibanNumber', 'paypalEmail',
];

const keysDeep = (v, out = new Set()) => {
  if (Array.isArray(v)) v.forEach((x) => keysDeep(x, out));
  else if (v && typeof v === 'object') {
    for (const [k, x] of Object.entries(v)) { out.add(k); keysDeep(x, out); }
  }
  return out;
};
// `email`, `mobile` : la fiche gardien garde volontairement la clé VIDE (forme
// stable de la réponse, v576). Une clé vide n'est pas une fuite ; une valeur l'est.
const SHAPE_ONLY = new Set(['email', 'mobile']);
const valuesOf = (v, key, out = []) => {
  if (Array.isArray(v)) v.forEach((x) => valuesOf(x, key, out));
  else if (v && typeof v === 'object') {
    for (const [k, x] of Object.entries(v)) { if (k === key) out.push(x); valuesOf(x, key, out); }
  }
  return out;
};
const leaked = (body) => PRIVATE_KEYS.filter((k) => {
  if (!keysDeep(body).has(k)) return false;
  if (SHAPE_ONLY.has(k)) return valuesOf(body, k).some((x) => x !== '' && x != null);
  return true;
});

const PRIVATE_DATA = {
  preferences: { notifications: true, wallpaper: 'paws', mapVisibility: 'all', sendPhotosVideos: false },
  notificationPrefs: { sound: 'bark', categories: { messages: false } },
  pendingEmail: 'nouvelle607b@example.test',
  pendingEmailExpiresAt: new Date(Date.now() + 3600e3),
  pendingEmailSentAt: new Date(),
  marketingOptOut: true,
  twoFactorEnabled: true,
  referralCode: 'ZOE607B',
  referredBy: 'PARRAIN1',
  mobile: '0600000000',
  fcmDevices: [{ token: 't', platform: 'ios', appBuild: 607 }],
};
const PARIS_TEST = { type: 'Point', coordinates: [-30, -35], city: 'Zone test' };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Owner = require('../src/models/Owner');
  await Promise.all([Sitter.init(), Walker.init(), Owner.init()]);
  app = require('../src/app');
  sitter = await Sitter.create({
    name: 'Gardienne Publique', email: 'gardienne607b@example.org', password: 'MotDePasse607!',
    location: PARIS_TEST, service: ['house_sitting'], ...PRIVATE_DATA,
  });
  walker = await Walker.create({
    name: 'Promeneur Public', email: 'promeneur607b@example.org', password: 'MotDePasse607!',
    location: PARIS_TEST, ...PRIVATE_DATA,
  });
  owner = await Owner.create({
    name: 'Proprio Public', email: 'proprio607b@example.org', password: 'MotDePasse607!',
    location: PARIS_TEST, ...PRIVATE_DATA,
    searchPreferences: { radiusKm: 5 },
  });
  // Position de profil + code haché posés en base directement (champs
  // `select: false`) : l'agrégation $geoNear des promeneurs les lisait quand même.
  for (const M of [Sitter, Walker]) {
    await M.collection.updateMany({}, { $set: {
      homeLocation: { coordinates: [-30.001, -35.001], city: 'Zone test', at: new Date() },
      pendingEmailCodeHash: 'hash607b',
    } });
  }
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

describe('routes publiques : aucune préférence ni donnée de compte', () => {
  test.each([
    ['GET /sitters', () => '/api/v1/sitters', 'sitters'],
    ['GET /sitters/:id', () => `/api/v1/sitters/${sitter._id}`, 'sitter'],
    ['GET /sitters/nearby', () => '/api/v1/sitters/nearby?lat=-35&lng=-30&radiusInMeters=50000', 'sitters'],
    ['GET /walkers', () => '/api/v1/walkers', 'walkers'],
    ['GET /walkers/:id', () => `/api/v1/walkers/${walker._id}`, 'walker'],
    ['GET /walkers/nearby', () => '/api/v1/walkers/nearby?lat=-35&lng=-30&radiusInMeters=50000', 'walkers'],
  ])('%s', async (_label, url, field) => {
    const r = await request(app).get(url());
    expect(r.status).toBe(200);
    // La route renvoie bien la personne (sinon le test ne prouverait rien).
    const payload = r.body[field];
    const list = Array.isArray(payload) ? payload : [payload];
    expect(list.length).toBeGreaterThan(0);
    expect(leaked(r.body)).toEqual([]);
  });

  test('ce que la carte et le site lisent reste là (nom, ville, note, tarifs)', async () => {
    const r = await request(app).get(`/api/v1/sitters/${sitter._id}`);
    expect(r.body.sitter).toEqual(expect.objectContaining({
      id: String(sitter._id), rating: expect.any(Number), dailyRate: expect.any(Number),
      bio: expect.any(String), service: ['house_sitting'],
    }));
    expect(r.body.sitter.location.city).toBe('Zone test');
    const w = await request(app).get(`/api/v1/walkers/${walker._id}`);
    expect(w.body.walker.id).toBe(String(walker._id));
    expect(w.body.walker.location).toBeTruthy();
  });
});

describe('listes publiques /sitters et /walkers : même règle que la fiche et /nearby', () => {
  test.each([
    ['GET /sitters', '/api/v1/sitters', 'sitters', 'Gardienne P.'],
    ['GET /walkers', '/api/v1/walkers', 'walkers', 'Promeneur P.'],
  ])('%s : prénom + initiale, position floutée ~1 km (jamais l’exacte)', async (_l, url, field, shown) => {
    const r = await request(app).get(url);
    expect(r.status).toBe(200);
    const e = r.body[field][0];
    expect(e.name).toBe(shown);
    expect(e.lastName).toBe('P.');
    const [lng, lat] = e.location.coordinates;
    expect(e.location.approxKm).toBe(1);
    expect(e.location.lat).toBe(lat);
    expect(e.location.lng).toBe(lng);
    // ni la position de profil exacte, ni la position du document
    expect([lng, lat]).not.toEqual([-30, -35]);
    expect([lng, lat]).not.toEqual([-30.001, -35.001]);
    // mais dans le bon quartier (< 1,5 km)
    expect(Math.abs(lat + 35) * 111.32).toBeLessThan(1.5);
    expect(e.location.city).toBe('Zone test');
  });
});

describe('la personne elle-même garde ses réglages (écran Préférences)', () => {
  test('GET /sitters/:id avec SON jeton : preferences + 2FA présents', async () => {
    const token = jwt.sign({ id: String(sitter._id), role: 'sitter' }, process.env.JWT_SECRET);
    const r = await request(app).get(`/api/v1/sitters/${sitter._id}`).set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(200);
    expect(r.body.sitter.preferences).toEqual(expect.objectContaining({ wallpaper: 'paws', mapVisibility: 'all' }));
    expect(r.body.sitter.twoFactorEnabled).toBe(true);
  });

  test('GET /walkers/me avec SON jeton : preferences présentes', async () => {
    const token = jwt.sign({ id: String(walker._id), role: 'walker' }, process.env.JWT_SECRET);
    const r = await request(app).get('/api/v1/walkers/me').set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(200);
    expect(r.body.walker.preferences).toEqual(expect.objectContaining({ wallpaper: 'paws' }));
  });

  test('GET /users/me/profile (propriétaire) : preferences présentes', async () => {
    const token = jwt.sign({ id: String(owner._id), role: 'owner' }, process.env.JWT_SECRET);
    const r = await request(app).get('/api/v1/users/me/profile').set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(200);
    const u = r.body.user || r.body.owner || r.body.profile || r.body;
    expect(u.preferences).toEqual(expect.objectContaining({ wallpaper: 'paws' }));
  });

  test('site : GET /users/me/profile d’un GARDIEN garde ses préférences', async () => {
    const token = jwt.sign({ id: String(sitter._id), role: 'sitter' }, process.env.JWT_SECRET);
    const r = await request(app).get('/api/v1/users/me/profile').set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(200);
    const u = r.body.user || r.body.profile || r.body;
    expect(u.preferences).toEqual(expect.objectContaining({ wallpaper: 'paws' }));
    expect(u.twoFactorEnabled).toBe(true);
  });

  test('un AUTRE membre connecté ne voit pas les réglages du gardien', async () => {
    const token = jwt.sign({ id: String(owner._id), role: 'owner' }, process.env.JWT_SECRET);
    const r = await request(app).get(`/api/v1/sitters/${sitter._id}`).set('Authorization', `Bearer ${token}`);
    expect(r.status).toBe(200);
    expect(leaked(r.body)).toEqual([]);
  });
});
