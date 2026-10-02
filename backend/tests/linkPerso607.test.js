// 607 (NEO, 02/10/2026) — « RAMÈNE TES CLIENTS » : lien personnel /s/<slug>,
// projection publique, badge Pionnier, affiche A4 + QR.
// Vraie base Mongo en mémoire + vraie application Express. Coordonnées en
// plein Atlantique sud (« Zone test ») : aucune donnée dans une vraie ville.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/config/firebaseAdmin', () => ({
  auth: () => ({ verifyIdToken: async () => { throw new Error('no firebase in tests'); } }),
  messaging: () => ({ send: async () => 'x', sendEachForMulticast: async () => ({ responses: [] }) }),
}));
// Aucun géocodage réseau (Photon) : une ville sans position reste sans centre.
jest.mock('../src/utils/geocodeCity', () => ({
  ...jest.requireActual('../src/utils/geocodeCity'),
  geocodeCity: async () => null,
}));
jest.mock('../src/config/swagger', () => ({ openapi: '3.0.0', info: { title: 't', version: '0' }, paths: {} }));

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

const { slugBase, ensurePublicSlug } = require('../src/utils/publicSlug607');
const { _resetPioneerCache, computeIsPioneer } = require('../src/utils/pioneer607');
const { PUBLIC_PROVIDER_KEYS } = require('../src/utils/publicProvider607');
const { encodeQr } = require('../src/utils/qr607');
const { buildPosterPdf, extractPosterText, TXT } = require('../src/utils/posterPdf607');

let mongo; let app; let Sitter; let Walker; let Owner; let Booking;
const ZONE = [-30, -35]; // [lng, lat]
const at = (dLatKm) => ({ type: 'Point', coordinates: [ZONE[0], ZONE[1] + dLatKm / 111.2], city: 'Zone test' });
const tok = (doc, role) => jwt.sign({ id: String(doc._id), role }, process.env.JWT_SECRET);
let n = 0;
const mk = (Model, extra = {}) => {
  n += 1;
  return Model.create({
    name: `Personne Test${n}`, email: `neo607_${n}@example.org`, password: 'MotDePasse607!', ...extra,
  });
};

const SENSITIVE = [
  'email', 'mobile', 'phone', 'password', 'address', 'dateOfBirth', 'location', 'coordinates',
  'homeLocation', 'lat', 'lng', 'preferences', 'notificationPrefs', 'referralCode', 'referredBy',
  'fcmTokens', 'fcmDevices', 'walletBalance', 'ibanNumber', 'paypalEmail', 'lastName',
  'pendingEmail', 'twoFactorEnabled', 'marketingOptOut', 'card', 'kycStatus', 'firebaseUid',
];
const keysDeep = (v, out = new Set()) => {
  if (Array.isArray(v)) v.forEach((x) => keysDeep(x, out));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) { out.add(k); keysDeep(x, out); }
  return out;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Owner = require('../src/models/Owner');
  Booking = require('../src/models/Booking');
  await Promise.all([Sitter.init(), Walker.init(), Owner.init()]);
  app = require('../src/app');
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(async () => {
  _resetPioneerCache();
  await Promise.all([Sitter.deleteMany({}), Walker.deleteMany({}), Owner.deleteMany({}), Booking.deleteMany({})]);
});

describe('slug « prenom-initiale-ville »', () => {
  test('forme, accents, arrondissement, nom de famille jamais complet', () => {
    expect(slugBase({ firstName: 'Sasha', lastName: 'Bernard', city: 'Lyon' })).toBe('sasha-b-lyon');
    expect(slugBase({ firstName: 'Hélène', lastName: 'Örtel', city: 'Paris 11e' })).toBe('helene-o-paris');
    expect(slugBase({ name: 'Marie Dupont', city: 'Saint-Étienne' })).toBe('marie-d-saint-etienne');
    expect(slugBase({ firstName: 'Łukasz', lastName: 'Żak', city: 'Kraków' })).toBe('lukasz-z-krakow');
    expect(slugBase({ firstName: 'さくら', city: '東京' }, 'walker')).toBe('promeneur');
    expect(slugBase({ firstName: 'Sasha', lastName: 'Bernard', city: 'Lyon' })).not.toMatch(/bernard/);
  });

  test('unique sur gardiens ET promeneurs, stable même si la ville change', async () => {
    const base = { firstName: 'Sasha', lastName: 'Bernard', location: at(0) };
    const s1 = await mk(Sitter, base);
    const s2 = await mk(Sitter, base);
    const w1 = await mk(Walker, base);
    const a = await ensurePublicSlug(s1, 'sitter');
    const b = await ensurePublicSlug(s2, 'sitter');
    const c = await ensurePublicSlug(w1, 'walker');
    expect([a, b, c]).toEqual(['sasha-b-zone-test', 'sasha-b-zone-test-2', 'sasha-b-zone-test-3']);
    await Sitter.updateOne({ _id: s1._id }, { $set: { city: 'Ailleurs', 'location.city': 'Ailleurs' } });
    const again = await ensurePublicSlug(await Sitter.findById(s1._id).lean(), 'sitter');
    expect(again).toBe(a);
    expect((await Sitter.findById(s1._id).lean()).publicSlug).toBe(a);
  });

  test('créé à la volée par GET /public/providers/me/link (gardien et promeneur), refusé au propriétaire', async () => {
    const s = await mk(Sitter, { firstName: 'Nora', lastName: 'Test', location: at(0) });
    const w = await mk(Walker, { firstName: 'Ugo', lastName: 'Test', location: at(0) });
    const o = await mk(Owner, { location: at(0) });
    const rs = await request(app).get('/api/v1/public/providers/me/link').set('Authorization', `Bearer ${tok(s, 'sitter')}`);
    expect(rs.status).toBe(200);
    expect(rs.body).toEqual(expect.objectContaining({
      slug: 'nora-t-zone-test', url: 'https://www.hopetsit.com/s/nora-t-zone-test', role: 'sitter',
      city: 'Zone test', bookingsCount: 0, posterPath: '/public/providers/nora-t-zone-test/poster.pdf',
    }));
    const rw = await request(app).get('/api/v1/public/providers/me/link').set('Authorization', `Bearer ${tok(w, 'walker')}`);
    expect(rw.status).toBe(200);
    expect(rw.body.slug).toBe('ugo-t-zone-test');
    const ro = await request(app).get('/api/v1/public/providers/me/link').set('Authorization', `Bearer ${tok(o, 'owner')}`);
    expect(ro.status).toBe(403);
    const anon = await request(app).get('/api/v1/public/providers/me/link');
    expect(anon.status).toBe(401);
  });

  test('bookingsCount compte les réservations acceptées / payées / terminées', async () => {
    const s = await mk(Sitter, { firstName: 'Lea', lastName: 'Test', location: at(0) });
    const o = await mk(Owner, { location: at(0) });
    await Booking.collection.insertMany([
      { ownerId: o._id, sitterId: s._id, status: 'paid' },
      { ownerId: o._id, sitterId: s._id, status: 'cancelled' },
      { ownerId: o._id, sitterId: s._id, status: 'pending' },
    ]);
    const r = await request(app).get('/api/v1/public/providers/me/link').set('Authorization', `Bearer ${tok(s, 'sitter')}`);
    expect(r.body.bookingsCount).toBe(1);
  });
});

describe('GET /public/providers/:slug — uniquement la fiche publique', () => {
  test('liste blanche, prénom + initiale, aucun champ sensible', async () => {
    const s = await mk(Sitter, {
      firstName: 'Sasha', lastName: 'Bernardini', location: at(0), city: 'Zone test',
      bio: 'J’adore les chats.', service: ['house_sitting'], dailyRate: 30, hourlyRate: 12,
      mobile: '0600000000', address: '1 rue Secrète', dateOfBirth: '1990-01-01',
      referralCode: 'NEO607X', preferences: { notifications: true }, avatar: { url: 'https://example.org/a.jpg' },
    });
    const slug = await ensurePublicSlug(s, 'sitter');
    const r = await request(app).get(`/api/v1/public/providers/${slug}`);
    expect(r.status).toBe(200);
    const p = r.body.provider;
    expect(Object.keys(p).every((k) => PUBLIC_PROVIDER_KEYS.includes(k))).toBe(true);
    const leaks = SENSITIVE.filter((k) => keysDeep(r.body).has(k));
    expect(leaks).toEqual([]);
    const raw = JSON.stringify(r.body);
    for (const secret of ['Bernardini', '0600000000', 'rue Secrète', '1990-01-01', 'NEO607X', 'neo607_', '-35', '-30']) {
      expect(raw).not.toContain(secret);
    }
    expect(p).toEqual(expect.objectContaining({
      slug, role: 'sitter', name: 'Sasha B.', firstName: 'Sasha', city: 'Zone test',
      photo: 'https://example.org/a.jpg', services: ['house_sitting'], indexable: true,
      url: `https://www.hopetsit.com/s/${slug}`,
    }));
    expect(p.rates).toEqual([
      { unit: 'hour', amount: 12, currency: 'EUR' },
      { unit: 'day', amount: 30, currency: 'EUR' },
    ]);
  });

  test('promeneur : tarifs par promenade avec durée', async () => {
    const w = await mk(Walker, {
      firstName: 'Ugo', lastName: 'Test', location: at(0),
      walkRates: [{ durationMinutes: 60, basePrice: 18 }, { durationMinutes: 30, basePrice: 10 }, { durationMinutes: 45, basePrice: 14, enabled: false }],
    });
    const slug = await ensurePublicSlug(w, 'walker');
    const r = await request(app).get(`/api/v1/public/providers/${slug}`);
    expect(r.status).toBe(200);
    expect(r.body.provider.rates).toEqual([
      { unit: 'walk', durationMinutes: 30, amount: 10, currency: 'EUR' },
      { unit: 'walk', durationMinutes: 60, amount: 18, currency: 'EUR' },
    ]);
  });

  test('banni, suspendu, masqué, slug inconnu ou invalide → 404', async () => {
    const cases = [{ status: 'banned' }, { status: 'suspended' }, { hiddenFromPublic: true }];
    for (const extra of cases) {
      const s = await mk(Sitter, { firstName: 'Cache', lastName: 'Test', location: at(0), ...extra });
      const slug = await ensurePublicSlug(s, 'sitter');
      const r = await request(app).get(`/api/v1/public/providers/${slug}`);
      expect(r.status).toBe(404);
      const pdf = await request(app).get(`/api/v1/public/providers/${slug}/poster.pdf`);
      expect(pdf.status).toBe(404);
      // La personne elle-même garde l'aperçu de sa page (jamais indexée).
      const me = await request(app).get(`/api/v1/public/providers/${slug}`).set('Authorization', `Bearer ${tok(s, 'sitter')}`);
      expect(me.status).toBe(200);
      expect(me.body.provider.indexable).toBe(false);
    }
    expect((await request(app).get('/api/v1/public/providers/inconnu-x')).status).toBe(404);
    expect((await request(app).get('/api/v1/public/providers/..%2Fadmin')).status).toBe(404);
  });

  test('compte de test : invisible en public, visible pour lui-même', async () => {
    const s = await mk(Sitter, { firstName: 'Testeur', lastName: 'T', email: 'neo607+testsitter@example.org', location: at(0) });
    const slug = await ensurePublicSlug(s, 'sitter');
    expect((await request(app).get(`/api/v1/public/providers/${slug}`)).status).toBe(404);
    const me = await request(app).get(`/api/v1/public/providers/${slug}`).set('Authorization', `Bearer ${tok(s, 'sitter')}`);
    expect(me.status).toBe(200);
    expect(me.body.provider.indexable).toBe(false);
  });
});

describe('isPioneer : aucun autre prestataire actif à 25 km', () => {
  test('seul → pionnier ; un promeneur à 10 km → plus pionnier ; à 40 km → toujours pionnier', async () => {
    const s = await mk(Sitter, { firstName: 'Seule', lastName: 'Test', location: at(0) });
    expect(await computeIsPioneer(await Sitter.findById(s._id).select('+homeLocation').lean())).toBe(true);
    await mk(Walker, { firstName: 'Loin', lastName: 'Test', location: { ...at(40), city: 'Zone lointaine' }, city: 'Zone lointaine' });
    _resetPioneerCache();
    expect(await computeIsPioneer(await Sitter.findById(s._id).select('+homeLocation').lean())).toBe(true);
    await mk(Walker, { firstName: 'Pres', lastName: 'Test', location: at(10) });
    _resetPioneerCache();
    expect(await computeIsPioneer(await Sitter.findById(s._id).select('+homeLocation').lean())).toBe(false);
  });

  test('sans position : même ville déclarée = pas pionnier ; ville vide = inconnu (null)', async () => {
    const s = await mk(Sitter, { firstName: 'Ville', lastName: 'Test', city: 'Zone test' });
    expect(await computeIsPioneer(await Sitter.findById(s._id).select('+homeLocation').lean())).toBe(true);
    await mk(Walker, { city: 'Zone test' });
    _resetPioneerCache();
    expect(await computeIsPioneer(await Sitter.findById(s._id).select('+homeLocation').lean())).toBe(false);
    const nul = await mk(Sitter, { firstName: 'Rien', lastName: 'Test' });
    expect(await computeIsPioneer(await Sitter.findById(nul._id).select('+homeLocation').lean())).toBe(null);
  });

  test('ne comptent pas : banni, suspendu, masqué, staff, compte de test, et SES propres profils', async () => {
    const s = await mk(Sitter, { firstName: 'Seule', lastName: 'Test', location: at(0), email: 'neo607_moi@example.org' });
    await mk(Walker, { location: at(1), email: 'neo607_moi@example.org' }); // moi, en promeneur
    await mk(Sitter, { location: at(2), status: 'banned' });
    await mk(Sitter, { location: at(3), status: 'suspended' });
    await mk(Walker, { location: at(4), hiddenFromPublic: true });
    await mk(Walker, { location: at(5), isStaff: true });
    await mk(Sitter, { location: at(6), email: 'quelquun+test@example.org' });
    const r = await request(app).get('/api/v1/public/providers/me/link').set('Authorization', `Bearer ${tok(s, 'sitter')}`);
    expect(r.status).toBe(200);
    expect(r.body.isPioneer).toBe(true);
    const slug = r.body.slug;
    const pub = await request(app).get(`/api/v1/public/providers/${slug}`);
    expect(pub.body.provider.isPioneer).toBe(true);
  });
});

describe('Pionnier : jamais influencé par les comptes de test / masqués / staff', () => {
  test.each([
    ['compte +test', { email: 'seul+test@example.org' }],
    ['staff', { isStaff: true }],
    ['masqué', { hiddenFromPublic: true }],
    ['banni', { status: 'banned' }],
    ['suspendu', { status: 'suspended' }],
  ])('%s seul dans sa zone → jamais Pionnier (ni badge, ni +200)', async (_l, extra) => {
    const s = await mk(Sitter, { firstName: 'Seul', lastName: 'Test', location: at(0), ...extra });
    expect(await computeIsPioneer(await Sitter.findById(s._id).lean())).toBe(false);
    const gains = await require('../src/services/pawPointsActivity607').checkIn({ userId: String(s._id), role: 'sitter' });
    expect(gains.filter((g) => g && g.key === 'pioneer')).toEqual([]);
  });

  test('un vrai prestataire seul reçoit bien le +200 une fois (contrôle du test ci-dessus)', async () => {
    const s = await mk(Sitter, { firstName: 'Vrai', lastName: 'Seul', location: at(0) });
    await mk(Walker, { location: at(2), email: 'voisin+test@example.org' });
    await mk(Sitter, { location: at(3), isStaff: true });
    await mk(Walker, { location: at(4), hiddenFromPublic: true });
    expect(await computeIsPioneer(await Sitter.findById(s._id).lean())).toBe(true);
    const svc = require('../src/services/pawPointsActivity607');
    const g1 = await svc.checkIn({ userId: String(s._id), role: 'sitter' });
    const pioneer = g1.filter((g) => g && g.key === 'pioneer');
    expect(pioneer.length).toBe(1);
    expect(JSON.stringify(pioneer[0])).toContain('200');
    const g2 = await svc.checkIn({ userId: String(s._id), role: 'sitter' });
    expect(g2.filter((g) => g && g.key === 'pioneer')).toEqual([]);
  });
});

describe('badge Pionnier sur la fiche de l\'app', () => {
  test('GET /public/providers/badge/:role/:id → isPioneer + lien /s (profil complet seulement)', async () => {
    const s = await mk(Sitter, { firstName: 'Seule', lastName: 'Test', location: at(0), bio: 'Je garde les chats.' });
    const r = await request(app).get(`/api/v1/public/providers/badge/sitter/${s._id}`);
    expect(r.body).toEqual({ isPioneer: true, slug: 'seule-t-zone-test', url: 'https://www.hopetsit.com/s/seule-t-zone-test' });
    const w = await mk(Walker, { location: at(3) }); // coquille vide : ni photo, ni bio, ni tarif
    _resetPioneerCache();
    expect((await request(app).get(`/api/v1/public/providers/badge/sitter/${s._id}`)).body.isPioneer).toBe(false);
    const rw = await request(app).get(`/api/v1/public/providers/badge/walker/${w._id}`);
    expect(rw.body).toEqual({ isPioneer: false, slug: '', url: '' });
    expect((await Walker.findById(w._id).lean()).publicSlug).toBeUndefined();
    const t = await mk(Sitter, { location: at(300), email: 'x+test@example.org', bio: 'test' });
    expect((await request(app).get(`/api/v1/public/providers/badge/sitter/${t._id}`)).body).toEqual({ isPioneer: false, slug: '', url: '' });
    expect((await request(app).get('/api/v1/public/providers/badge/owner/abc')).body).toEqual({ isPioneer: false, slug: '', url: '' });
  });
});

describe('GET /public/providers/sitemap', () => {
  test('profils publics complets seulement ; test, masqué, banni, staff et coquilles vides absents', async () => {
    require('../src/routes/publicProviderRoutes')._resetSitemapCache();
    await mk(Sitter, { firstName: 'Photo', lastName: 'Ok', location: at(0), avatar: { url: 'https://example.org/p.jpg' }, country: 'fr' });
    await mk(Walker, { firstName: 'Tarif', lastName: 'Ok', location: at(0), walkRates: [{ durationMinutes: 30, basePrice: 10 }] });
    await mk(Sitter, { firstName: 'Bio', lastName: 'Ok', location: at(0), bio: 'Bonjour' });
    const vide = await mk(Sitter, { firstName: 'Vide', lastName: 'X', location: at(0) });
    await mk(Sitter, { firstName: 'Testeur', lastName: 'X', email: 'z+test@example.org', bio: 'x' });
    await mk(Sitter, { firstName: 'Cache', lastName: 'X', hiddenFromPublic: true, bio: 'x' });
    await mk(Walker, { firstName: 'Banni', lastName: 'X', status: 'banned', bio: 'x' });
    await mk(Walker, { firstName: 'Staff', lastName: 'X', isStaff: true, bio: 'x' });
    const r = await request(app).get('/api/v1/public/providers/sitemap');
    expect(r.status).toBe(200);
    expect(r.body.providers.map((p) => p.slug)).toEqual(['bio-o-zone-test', 'photo-o-zone-test', 'tarif-o-zone-test']);
    expect(r.body.providers.every((p) => ['sitter', 'walker'].includes(p.role) && p.updatedAt)).toBe(true);
    expect(Object.keys(r.body.providers[0]).sort()).toEqual(['country', 'role', 'slug', 'updatedAt']);
    expect(r.body.providers.find((p) => p.slug === 'photo-o-zone-test').country).toBe('FR');
    expect((await Sitter.findById(vide._id).lean()).publicSlug).toBeUndefined();
    // Chaque slug listé ouvre bien sa page publique.
    for (const p of r.body.providers) {
      expect((await request(app).get(`/api/v1/public/providers/${p.slug}`)).status).toBe(200);
    }
  });
});

describe('FUITE 02/10 : une « ville » qui est un e-mail, un lien ou un numéro n\'est jamais publiée', () => {
  const { isUnsafeCity } = require('../src/utils/publicCity607');
  test('règle', () => {
    for (const ok of ['Paris', 'Paris 11e', 'Saint-Étienne', 'Łódź', '東京', 'San Francisco', 'Zone test']) expect(isUnsafeCity(ok)).toBe(false);
    for (const bad of ['dadaniecka@gmail.com', 'www.monsite.fr', 'https://x.io', 'monsite.com', '06 12 34 56 78', '+33612345678', 'x'.repeat(61)]) expect(isUnsafeCity(bad)).toBe(true);
  });

  test('ancien slug vicié → 404, nouveau slug sans e-mail, nulle part dans les routes publiques', async () => {
    require('../src/routes/publicProviderRoutes')._resetSitemapCache();
    const s = await mk(Sitter, {
      firstName: 'Jesse', lastName: 'Tlv', city: 'neo607fuite@gmail.com', bio: 'Je garde.',
      location: { ...at(0), city: 'neo607fuite@gmail.com' }, dailyRate: 20,
    });
    // Comme en production : slug fabriqué avant la règle.
    await Sitter.collection.updateOne({ _id: s._id }, { $set: { publicSlug: 'jesse-t-neo607fuite-gmail-com' } });
    const w = await mk(Walker, { firstName: 'Lela', lastName: 'Tlv', city: 'www.neo607.fr', location: { ...at(1), city: 'www.neo607.fr' }, bio: 'x' });
    const old = await request(app).get('/api/v1/public/providers/jesse-t-neo607fuite-gmail-com');
    expect(old.status).toBe(404);
    expect((await request(app).get('/api/v1/public/providers/jesse-t-neo607fuite-gmail-com/poster.pdf')).status).toBe(404);
    const fresh = (await Sitter.findById(s._id).lean());
    expect(fresh.publicSlug).toBe('jesse-t');
    expect(fresh.city).toBe('neo607fuite@gmail.com'); // la donnée n'est pas touchée
    const sm = await request(app).get('/api/v1/public/providers/sitemap');
    const urls = [
      '/api/v1/public/providers/sitemap',
      '/api/v1/public/providers/jesse-t',
      `/api/v1/public/providers/badge/sitter/${s._id}`,
      `/api/v1/public/providers/badge/walker/${w._id}`,
      '/api/v1/sitters', `/api/v1/sitters/${s._id}`,
      '/api/v1/sitters/nearby?lat=-35&lng=-30&radiusInMeters=50000',
      '/api/v1/walkers', `/api/v1/walkers/${w._id}`,
      '/api/v1/walkers/nearby?lat=-35&lng=-30&radiusInMeters=50000',
    ];
    expect(sm.body.providers.map((p) => p.slug)).toEqual(expect.arrayContaining(['jesse-t', 'lela-t']));
    for (const u of urls) {
      const r = await request(app).get(u);
      expect([u, r.status]).toEqual([u, 200]);
      const raw = JSON.stringify(r.body);
      expect([u, /neo607fuite|gmail|www\.neo607/.test(raw)]).toEqual([u, false]);
    }
    expect((await request(app).get('/api/v1/public/providers/jesse-t')).body.provider.city).toBe('');
    // La personne elle-même voit toujours son champ (écran de modification).
    const me = await request(app).get(`/api/v1/sitters/${s._id}`).set('Authorization', `Bearer ${tok(s, 'sitter')}`);
    expect(me.body.sitter.city).toBe('neo607fuite@gmail.com');
  });
});

describe('FUITE 02/10 (suite) : liste d\'amis sans « ville » e-mail', () => {
  test('GET /friends : l\'ami est là, sa ville e-mail n\'est pas renvoyée', async () => {
    const Friendship = require('../src/models/Friendship');
    const me = await mk(Owner, { firstName: 'Moi', location: at(0) });
    const ami = await mk(Sitter, { firstName: 'Ami', lastName: 'Fuite', city: 'neo607ami@gmail.com', location: { ...at(1), city: 'neo607ami@gmail.com' } });
    await Friendship.collection.insertOne({
      requesterId: me._id, requesterModel: 'Owner', addresseeId: ami._id, addresseeModel: 'Sitter',
      status: 'accepted', acceptedAt: new Date(), createdAt: new Date(), updatedAt: new Date(),
      requesterSharesPosition: true, addresseeSharesPosition: true,
    });
    const r = await request(app).get('/api/v1/friends').set('Authorization', `Bearer ${tok(me, 'owner')}`);
    expect(r.status).toBe(200);
    const raw = JSON.stringify(r.body);
    expect(raw).toContain(String(ami._id));
    expect(raw).not.toMatch(/neo607ami|gmail/);
  });
});

describe('Décision Daniel 02/10 : ville = e-mail corrigée (2 comptes) + refus à l\'inscription / modification', () => {
  const { runFixCityEmail607 } = require('../src/scripts/fixCityEmail607');
  const { CITY_INVALID_I18N } = require('../src/middleware/cityGuard607');

  test('les 2 gardiens visés : ville vidée sans position fiable, frères corrigés, autres comptes intouchés, une seule fois', async () => {
    await mongoose.connection.db.collection('migrations').deleteMany({ _id: 'fix_city_email_607' });
    const BAD = 'neo607cible@gmail.com';
    const jesse = await Sitter.create({ _id: new mongoose.Types.ObjectId('6aacae41b4d70237d89c8def'), name: 'Jesse T', firstName: 'Jesse', email: 'neo607jesse@example.org', password: 'MotDePasse607!', city: BAD, location: { type: 'Point', coordinates: [-122.0841, 37.4220], city: BAD } });
    const frere = await Walker.create({ name: 'Jesse T', email: 'neo607jesse@example.org', password: 'MotDePasse607!', city: BAD });
    const proprio = await Owner.create({ name: 'Jesse T', email: 'neo607jesse@example.org', password: 'MotDePasse607!', city: 'Lyon' });
    const lela = await Sitter.create({ _id: new mongoose.Types.ObjectId('6ab09f325f2c7ca4acd8c315'), name: 'Lela T', firstName: 'Lela', email: 'neo607lela@example.org', password: 'MotDePasse607!', city: BAD });
    const autre = await Sitter.create({ name: 'Autre X', email: 'neo607autre@example.org', password: 'MotDePasse607!', city: 'autre@gmail.com' });
    const fetchImpl = jest.fn();
    const res = await runFixCityEmail607(mongoose.connection.db, { fetchImpl });
    expect(fetchImpl).not.toHaveBeenCalled(); // position d'émulateur = non fiable, pas de géocodage
    expect(res.map((r) => r.apres)).toEqual(['(vide)', '(vide)']);
    expect(JSON.stringify(res)).not.toContain('gmail');
    const j = await Sitter.findById(jesse._id).lean();
    expect([j.city, j.location.city]).toEqual(['', '']);
    expect((await Walker.findById(frere._id).lean()).city).toBe('');
    expect((await Owner.findById(proprio._id).lean()).city).toBe('Lyon');
    expect((await Sitter.findById(lela._id).lean()).city).toBe('');
    expect((await Sitter.findById(autre._id).lean()).city).toBe('autre@gmail.com'); // hors décision : intouché
    expect(await runFixCityEmail607(mongoose.connection.db, { fetchImpl })).toBeNull(); // une seule fois
  });

  test('position fiable → vraie ville par géocodage inverse (niveau ville)', async () => {
    await mongoose.connection.db.collection('migrations').deleteMany({ _id: 'fix_city_email_607' });
    const s = await mk(Sitter, { city: 'x@gmail.com', location: { type: 'Point', coordinates: [4.84, 45.76], city: 'x@gmail.com' } });
    const fetchImpl = jest.fn().mockResolvedValue({ ok: true, json: async () => ({ address: { city: 'Lyon' } }) });
    const res = await runFixCityEmail607(mongoose.connection.db, { fetchImpl, targets: [{ id: String(s._id), model: 'Sitter', label: 'essai' }] });
    expect(fetchImpl.mock.calls[0][0]).toContain('nominatim.openstreetmap.org/reverse');
    expect(res[0].apres).toBe('Lyon');
    expect((await Sitter.findById(s._id).lean()).city).toBe('Lyon');
  });

  test.each([
    ['POST', '/api/v1/auth/signup', { role: 'owner', appLocale: 'fr', user: { name: 'A B', email: 'neo607g@example.org', password: 'MotDePasse607!', city: 'moi@gmail.com' } }, 'fr'],
    ['POST', '/api/v1/auth/signup', { role: 'sitter', appLocale: 'ja', user: { name: 'A B', email: 'neo607h@example.org', password: 'MotDePasse607!', location: { lat: 1, lng: 1, city: 'https://moi.fr' } } }, 'ja'],
  ])('%s %s : ville invalide refusée (400 CITY_INVALID, message dans la langue)', async (m, url, body, lang) => {
    const r = await request(app).post(url).send(body);
    expect(r.status).toBe(400);
    expect(r.body).toEqual({ code: 'CITY_INVALID', error: CITY_INVALID_I18N[lang] });
  });

  test('modification du profil (3 rôles) : refusée si ville invalide, acceptée sinon', async () => {
    const s = await mk(Sitter, { firstName: 'Mod', lastName: 'If', location: at(0) });
    const w = await mk(Walker, { firstName: 'Mod', lastName: 'W', location: at(0) });
    const o = await mk(Owner, { firstName: 'Mod', location: at(0) });
    const cases = [
      ['put', '/api/v1/sitters/me/profile', tok(s, 'sitter'), { city: '06 12 34 56 78' }],
      ['patch', '/api/v1/walkers/me', tok(w, 'walker'), { location: { city: 'www.promeneur.fr' } }],
      ['put', '/api/v1/users/me/profile', tok(o, 'owner'), { city: 'proprio@gmail.com' }],
    ];
    for (const [m, url, t, body] of cases) {
      const r = await request(app)[m](url).set('Authorization', `Bearer ${t}`).set('Accept-Language', 'de-DE').send(body);
      expect([url, r.status, r.body.code]).toEqual([url, 400, 'CITY_INVALID']);
      expect(r.body.error).toBe(CITY_INVALID_I18N.de);
    }
    const ok = await request(app).put('/api/v1/sitters/me/profile').set('Authorization', `Bearer ${tok(s, 'sitter')}`).send({ city: 'Saint-Étienne' });
    expect(ok.body.code).not.toBe('CITY_INVALID');
    expect(ok.status).toBeLessThan(400);
  });

  test('les 9 langues ont leur message', () => {
    expect(Object.keys(CITY_INVALID_I18N).sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
  });
});

describe('affiche A4 + QR', () => {
  test('GET poster.pdf → 200 application/pdf, A4, lien imprimé, sans photo ni réseau', async () => {
    const s = await mk(Sitter, { firstName: 'Nora', lastName: 'Test', location: at(0) });
    const slug = await ensurePublicSlug(s, 'sitter');
    const r = await request(app).get(`/api/v1/public/providers/${slug}/poster.pdf?lang=fr`)
      .buffer(true).parse((res, cb) => { const c = []; res.on('data', (d) => c.push(d)); res.on('end', () => cb(null, Buffer.concat(c))); });
    expect(r.status).toBe(200);
    expect(r.headers['content-type']).toMatch(/^application\/pdf/);
    const txt = r.body.toString('latin1');
    expect(txt.startsWith('%PDF-1.6')).toBe(true);
    expect(txt).toContain('/MediaBox [0 0 595.28 841.89]');
    const lines = extractPosterText(r.body);
    expect(lines).toContain(`hopetsit.com/s/${slug}`);
    expect(lines).toContain('Nora T.');
    expect(txt.trim().endsWith('%%EOF')).toBe(true);
  });

  test('photo Cloudinary : JPEG demandé carré et inséré (DCTDecode)', async () => {
    const jpeg = fs.readFileSync(path.join(__dirname, 'fixtures', 'neo607_photo.jpg'));
    const spy = jest.spyOn(global, 'fetch').mockResolvedValue({ ok: true, arrayBuffer: async () => jpeg });
    const s = await mk(Sitter, {
      firstName: 'Photo', lastName: 'Test', location: at(0),
      avatar: { url: 'https://res.cloudinary.com/demo/image/upload/v1/neo607.png' },
    });
    const slug = await ensurePublicSlug(s, 'sitter');
    const r = await request(app).get(`/api/v1/public/providers/${slug}/poster.pdf?lang=en`)
      .buffer(true).parse((res, cb) => { const c = []; res.on('data', (d) => c.push(d)); res.on('end', () => cb(null, Buffer.concat(c))); });
    expect(r.status).toBe(200);
    expect(spy.mock.calls[0][0]).toContain('/upload/c_fill,g_face,w_400,h_400,f_jpg,q_80/');
    expect(r.body.toString('latin1')).toContain('/Filter /DCTDecode');
    spy.mockRestore();
  });

  test.each([
    ['fr', 'Hélène D.', 'Saint-Étienne', 'sitter'],
    ['en', 'Sasha B.', 'Zone test', 'walker'],
    ['es', 'Begoña Ñ.', 'Logroño', 'sitter'],
    ['de', 'Jürgen Ö.', 'Görlitz', 'walker'],
    ['it', 'Niccolò È.', 'Forlì', 'sitter'],
    ['pt', 'João Ç.', 'Évora', 'walker'],
    ['pl', 'Łukasz Ż.', 'Łódź', 'sitter'],
    ['ja', 'さくら T.', '東京', 'walker'],
    ['ko', '민지 K.', '서울', 'sitter'],
  ])('affiche %s : texte relu DANS le PDF, lettres intactes (police embarquée)', (lang, name, city, role) => {
    const url = `https://www.hopetsit.com/s/test-${lang}`;
    const pdf = buildPosterPdf({ name, role, city, url, lang });
    const lines = extractPosterText(pdf);
    const flat = lines.join(' ');
    const squeeze = (x) => x.replace(/\s+/g, '');
    const T = TXT[lang];
    expect(lines).toContain(name);
    expect(flat).toContain(city);
    expect(flat).toContain(role === 'walker' ? T.walker : T.sitter);
    for (const k of [role === 'walker' ? 'l1w' : 'l1', 'l2', 'l3', 'foot']) {
      expect(squeeze(flat)).toContain(squeeze(T[k]));
    }
    expect(lines).toContain(`hopetsit.com/s/test-${lang}`);
    // Les 3 polices sont embarquées en sous-ensemble (jamais Helvetica sans accents).
    const raw = pdf.toString('latin1');
    expect(raw).not.toContain('/BaseFont /Helvetica');
    expect(raw).toMatch(/\/FontFile[23] /);
    expect(pdf.length).toBeLessThan(400 * 1024);
  });

  test('texte de chaque langue écrit, aucun vide', () => {
    expect(Object.keys(TXT).sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
    for (const l of Object.keys(TXT)) for (const v of Object.values(TXT[l])) expect(v.trim().length).toBeGreaterThan(1);
  });

  test('QR identique, module pour module, à la bibliothèque Python qrcode', () => {
    const fx = JSON.parse(fs.readFileSync(path.join(__dirname, 'fixtures', 'qr607_python_qrcode.json'), 'utf8'));
    expect(fx.length).toBeGreaterThanOrEqual(12);
    for (const f of fx) {
      const q = encodeQr(f.text, { version: f.version, mask: f.mask });
      expect(q.modules.map((r) => r.map((c) => (c ? '1' : '0')).join(''))).toEqual(f.rows);
    }
  });
});
