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
const { buildPosterPdf, TXT } = require('../src/utils/posterPdf607');

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

describe('badge Pionnier sur la fiche de l\'app', () => {
  test('GET /public/providers/badge/:role/:id', async () => {
    const s = await mk(Sitter, { firstName: 'Seule', lastName: 'Test', location: at(0) });
    const r = await request(app).get(`/api/v1/public/providers/badge/sitter/${s._id}`);
    expect(r.body).toEqual({ isPioneer: true });
    const w = await mk(Walker, { location: at(3) });
    _resetPioneerCache();
    expect((await request(app).get(`/api/v1/public/providers/badge/sitter/${s._id}`)).body).toEqual({ isPioneer: false });
    expect((await request(app).get(`/api/v1/public/providers/badge/walker/${w._id}`)).body).toEqual({ isPioneer: false });
    const t = await mk(Sitter, { location: at(300), email: 'x+test@example.org' });
    expect((await request(app).get(`/api/v1/public/providers/badge/sitter/${t._id}`)).body).toEqual({ isPioneer: false });
    expect((await request(app).get('/api/v1/public/providers/badge/owner/abc')).body).toEqual({ isPioneer: false });
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
    expect(txt.startsWith('%PDF-1.4')).toBe(true);
    expect(txt).toContain('/MediaBox [0 0 595.28 841.89]');
    expect(txt).toContain(`(hopetsit.com/s/${slug})`);
    expect(txt).toContain('(Nora T.)');
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

  test('textes de l\'affiche : 7 langues écrites, ja/ko en anglais, aucun texte vide', () => {
    for (const l of Object.keys(TXT)) for (const v of Object.values(TXT[l])) expect(v.trim().length).toBeGreaterThan(3);
    const ja = buildPosterPdf({ name: 'さくら T.', role: 'walker', city: '東京', url: 'https://www.hopetsit.com/s/promeneur-t', lang: 'ja' }).toString('latin1');
    expect(ja).toContain('(I now walk dogs through HoPetSit.)');
    expect(ja).toContain('(HoPetSit)');
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
