// 640 (BOB, 10/11/2026) — retour de Daniel : « il m'apparaît une annonce du
// Brésil et en boost actif ? le mec est au Brésil, moi en Espagne ».
// Mesuré sur le vrai serveur : la demande n'avait AUCUNE position enregistrée
// et le fil GET /api/v1/posts/requests gardait partout dans le monde une
// annonce sans coordonnées. Vraie route, base Mongo en mémoire, AUCUN réseau
// (géocodeur de ville simulé, fetch coupé).
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
// Géocodeur de ville : le vrai module (peekCity, baseCityName, villes fixes)
// mais l'appel réseau est remplacé par une petite table.
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  const table = {
    'zone fictive': { lat: -35, lng: -30 },
    procheville: { lat: -35.5, lng: -30.5 }, autreville: { lat: -34.2, lng: -29.1 },
    loinville: { lat: 40, lng: 10 }, loin2: { lat: 41, lng: 11 }, loin3: { lat: 42, lng: 12 }, loin4: { lat: 43, lng: 13 },
  };
  return {
    ...actual,
    geocodeCity: jest.fn(async (city) => {
      const k = String(city || '').trim().toLowerCase();
      if (k === 'panneville') throw new Error('géocodeur en panne');
      if (k === 'lenteville') return new Promise((resolve) => { const t = setTimeout(() => resolve({ lat: 40, lng: 10 }), 6000); if (t.unref) t.unref(); });
      return table[k] || null;
    }),
  };
});
jest.mock('../src/utils/geocodePostal2310', () => {
  const actual = jest.requireActual('../src/utils/geocodePostal2310');
  return { ...actual, locationFromPostal: jest.fn(async () => null), geocodePostal: jest.fn(async () => null) };
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const H = 3600000;
const NOW = Date.now();
let mongo; let app; let Post;
let owner; let sitterZone; let sitterBresil; let sitterSansPosition; let walkerZone;
const realFetch = global.fetch;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mk = async (body, location, extra) => String((await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body, serviceTypes: ['pet_sitting'],
  location, reservedBy: { bookingId: null }, createdAt: new Date(),
  startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 72 * H), ...extra,
})).insertedId);
const feed = async (id, role) => {
  const r = await request(app).get('/api/v1/posts/requests').set('Authorization', tok(id, role));
  expect(r.status).toBe(200);
  return (r.body.posts || []).map((p) => p.body).sort();
};

beforeAll(async () => {
  global.fetch = jest.fn(async () => { throw new Error('réseau coupé pendant le test'); });
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Post = require('../src/models/Post');
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  owner = (await Owner.collection.insertOne({ name: 'Nina', email: 'nina-feed640@example.test', status: 'active', verified: true })).insertedId;
  const pos = (city, lng, lat) => ({ city, type: 'Point', coordinates: [lng, lat] });
  sitterZone = (await Sitter.collection.insertOne({ name: 'Ines', email: 'ines-feed640@example.test', status: 'active', verified: true, city: 'Zone fictive', location: pos('Zone fictive', -30, -35) })).insertedId;
  sitterBresil = (await Sitter.collection.insertOne({ name: 'Bia', email: 'bia-feed640@example.test', status: 'active', verified: true, city: 'Campinas', location: pos('Campinas', -47.06, -22.9) })).insertedId;
  sitterSansPosition = (await Sitter.collection.insertOne({ name: 'Sam', email: 'sam-feed640@example.test', status: 'active', verified: true })).insertedId;
  walkerZone = (await Walker.collection.insertOne({ name: 'Wil', email: 'wil-feed640@example.test', status: 'active', verified: true, city: 'Zone fictive', location: pos('Zone fictive', -30, -35) })).insertedId;

  await mk('Coords proche', { city: 'Zone fictive', lat: -35, lng: -30 });
  await mk('Coords loin', { city: 'Loinville', lat: 40, lng: 10 });
  await mk('Sans coords meme ville', { city: 'zone FICTIVE' });
  await mk('Sans coords ville proche', { city: 'Procheville' });
  await mk('Sans coords Sao Paulo', { city: 'São Paulo', postalCode: '00000-000' });
  await mk('Sans coords ville inconnue', { city: 'Nullepartville' });
  await mk('Sans ville', null);
  await mk('Lieu vide', {});
  await mk('Balade sans coords Sao Paulo', { city: 'São Paulo' }, { serviceTypes: ['dog_walking'] });
  await mk('Balade coords proche', { city: 'Zone fictive', lat: -35.01, lng: -30.01 }, { serviceTypes: ['dog_walking'] });
}, 120000);
afterAll(async () => {
  global.fetch = realFetch;
  delete process.env.FEED_NO_COORDS_STRICT;
  await mongoose.disconnect(); if (mongo) await mongo.stop();
}, 60000);

describe('fil des demandes — annonce sans coordonnées', () => {
  test('gardien en zone fictive : la demande de São Paulo sans position n’apparaît plus', async () => {
    const vu = await feed(sitterZone, 'sitter');
    expect(vu).not.toContain('Sans coords Sao Paulo');
    // ville que le géocodeur ne trouve pas : on ne masque JAMAIS dans le doute
    expect(vu).toContain('Sans coords ville inconnue');
    expect(vu).toEqual(['Coords proche', 'Lieu vide', 'Sans coords meme ville', 'Sans coords ville inconnue', 'Sans coords ville proche', 'Sans ville']);
  });

  test('gardien près de São Paulo : il la voit toujours (ville résolue sans réseau, ≤ 500 km)', async () => {
    const vu = await feed(sitterBresil, 'sitter');
    expect(vu).toContain('Sans coords Sao Paulo');
    expect(vu).not.toContain('Coords proche'); // règle des 500 km d'avant, inchangée
    expect(vu).not.toContain('Sans coords meme ville');
  });

  test('gardien sans position enregistrée : rien ne change (il voit tout)', async () => {
    const vu = await feed(sitterSansPosition, 'sitter');
    expect(vu).toEqual(['Coords loin', 'Coords proche', 'Lieu vide', 'Sans coords Sao Paulo', 'Sans coords meme ville', 'Sans coords ville inconnue', 'Sans coords ville proche', 'Sans ville']);
  });

  test('promeneur en zone fictive : même règle sur les balades', async () => {
    expect(await feed(walkerZone, 'walker')).toEqual(['Balade coords proche']);
  });

  test('« mes annonces » (ownerId) : le propriétaire voit toujours toutes ses demandes', async () => {
    const r = await request(app).get(`/api/v1/posts/requests?ownerId=${owner}`).set('Authorization', tok(owner, 'owner'));
    expect(r.status).toBe(200);
    expect((r.body.posts || []).length).toBe(10);
  });

  test('coupe-circuit FEED_NO_COORDS_STRICT=off : comportement d’avant', async () => {
    process.env.FEED_NO_COORDS_STRICT = 'off';
    try {
      const vu = await feed(sitterZone, 'sitter');
      expect(vu).toContain('Sans coords Sao Paulo');
      expect(vu).toContain('Sans coords ville inconnue');
      expect(vu).not.toContain('Coords loin');
    } finally { delete process.env.FEED_NO_COORDS_STRICT; }
  });

  test('rien n’est écrit en base à la lecture', async () => {
    await feed(sitterZone, 'sitter');
    const p = await Post.collection.findOne({ body: 'Sans coords Sao Paulo' });
    expect(p.location).toEqual({ city: 'São Paulo', postalCode: '00000-000' });
  });
});

describe('modification d’une annonce — la position n’est jamais perdue', () => {
  const put = (id, body) => request(app).put(`/api/v1/posts/${id}`).set('Authorization', tok(owner, 'owner')).send(body);

  test('ville seule, même ville : les coordonnées sont conservées', async () => {
    const id = await mk('A modifier 1', { city: 'Zone fictive', lat: -35, lng: -30, postalCode: 'ZF1' });
    const r = await put(id, { location: { city: 'Zone fictive' } });
    expect(r.status).toBeLessThan(300);
    const p = await Post.collection.findOne({ _id: new mongoose.Types.ObjectId(id) });
    expect(p.location.lat).toBe(-35); expect(p.location.lng).toBe(-30);
    expect(p.location.city).toBe('Zone fictive'); expect(p.location.postalCode).toBe('ZF1');
  });

  test('ville changée sans GPS : la nouvelle ville est géocodée (pas l’ancienne position)', async () => {
    const id = await mk('A modifier 2', { city: 'Zone fictive', lat: -35, lng: -30 });
    const r = await put(id, { location: { city: 'Procheville' } });
    expect(r.status).toBeLessThan(300);
    const p = await Post.collection.findOne({ _id: new mongoose.Types.ObjectId(id) });
    expect(p.location).toMatchObject({ city: 'Procheville', lat: -35.5, lng: -30.5, geocoded: true });
  });

  test('coordonnées envoyées par le client : prises telles quelles', async () => {
    const id = await mk('A modifier 3', { city: 'Zone fictive', lat: -35, lng: -30 });
    const r = await put(id, { location: { city: 'Autreville', lat: -34.2, lng: -29.1 } });
    expect(r.status).toBeLessThan(300);
    const p = await Post.collection.findOne({ _id: new mongoose.Types.ObjectId(id) });
    expect(p.location).toEqual({ city: 'Autreville', lat: -34.2, lng: -29.1 });
  });

  test('ville introuvable : l’annonce est enregistrée quand même, sans position inventée', async () => {
    const id = await mk('A modifier 4', { city: 'Zone fictive', lat: -35, lng: -30 });
    const r = await put(id, { location: { city: 'Nullepartville' } });
    expect(r.status).toBeLessThan(300);
    const p = await Post.collection.findOne({ _id: new mongoose.Types.ObjectId(id) });
    expect(p.location).toEqual({ city: 'Nullepartville' });
  });
});

describe('utilitaire feedNoCoords640', () => {
  const u = require('../src/utils/feedNoCoords640');
  test('coordsOf640 : 0/0, vide, hors bornes = pas de coordonnées', () => {
    expect(u.coordsOf640({ lat: 0, lng: 0 })).toBeNull();
    expect(u.coordsOf640({ lat: '', lng: 3 })).toBeNull();
    expect(u.coordsOf640({ lat: null, lng: 3 })).toBeNull();
    expect(u.coordsOf640({ lat: 95, lng: 3 })).toBeNull();
    expect(u.coordsOf640({ lat: '48.85', lng: '2.35' })).toEqual({ lat: 48.85, lng: 2.35 });
    expect(u.coordsOf640(null)).toBeNull();
  });
  test('sameCity640 : accents et casse ignorés, vide jamais égal', () => {
    expect(u.sameCity640('São Paulo', 'sao paulo')).toBe(true);
    expect(u.sameCity640('', '')).toBe(false);
    expect(u.sameCity640('Zone fictive', 'Procheville')).toBe(false);
  });
  test('prestataire sans position ou liste vide : rien à masquer', async () => {
    const posts = [{ location: { city: 'São Paulo' } }];
    expect((await u.noCoordsPostsToHide640(posts, { viewerCoords: null, maxKm: 500 })).size).toBe(0);
    expect((await u.noCoordsPostsToHide640([], { viewerCoords: [-30, -35], maxKm: 500 })).size).toBe(0);
    expect((await u.noCoordsPostsToHide640(posts, { viewerCoords: [-30, -35], maxKm: 500 })).size).toBe(1);
  });
  const V = { viewerCoords: [-30, -35], viewerCity: 'Zone fictive', maxKm: 500 };
  test('ville trouvée et lointaine : masquée ; ville trouvée et proche : gardée', async () => {
    const loin = { location: { city: 'Loinville' } };
    const pres = { location: { city: 'Procheville' } };
    const hide = await u.noCoordsPostsToHide640([loin, pres], V);
    expect(hide.has(loin)).toBe(true);
    expect(hide.has(pres)).toBe(false);
  });
  test('géocodeur en panne : l’annonce est gardée (jamais masquée dans le doute)', async () => {
    const p = { location: { city: 'Panneville' } };
    expect((await u.noCoordsPostsToHide640([p], V)).size).toBe(0);
  });
  test('géocodeur trop lent (> 2,5 s) : l’annonce est gardée', async () => {
    const p = { location: { city: 'Lenteville' } };
    const t0 = Date.now();
    expect((await u.noCoordsPostsToHide640([p], V)).size).toBe(0);
    expect(Date.now() - t0).toBeLessThan(4500);
  }, 15000);
  test('ville inconnue du géocodeur : gardée', async () => {
    const p = { location: { city: 'Nullepartville' } };
    expect((await u.noCoordsPostsToHide640([p], V)).size).toBe(0);
  });
  test('plus de 3 villes nouvelles : seules les 3 premières sont jugées, les autres sont gardées', async () => {
    const { geocodeCity } = require('../src/utils/geocodeCity');
    geocodeCity.mockClear();
    const posts = ['Loin2', 'Loin3', 'Loin4', 'Loinville'].map((city) => ({ location: { city } }));
    const hide = await u.noCoordsPostsToHide640(posts, V);
    expect(geocodeCity).toHaveBeenCalledTimes(3);
    expect(hide.size).toBe(3);
    expect(hide.has(posts[3])).toBe(false); // 4e ville : non jugée → gardée
  });
  test('ville fixe São Paulo : résolue sans réseau, variantes d’écriture comprises', () => {
    const { peekCity } = require('../src/utils/geocodeCity');
    for (const v of ['São Paulo', 'sao paulo', 'São Paulo, SP', 'SAO PAULO Brasil', 'São Paulo - SP', 'Sao Paulo/SP, Brasil', 'São Paulo – SP']) {
      expect(peekCity(v)).toEqual({ lat: -23.5505, lng: -46.6333 });
    }
  });
  test('ville fixe Tokyo (contrôle ZOE) : résolue sans réseau, écritures latines, japonaises et coréenne', () => {
    const { peekCity } = require('../src/utils/geocodeCity');
    for (const v of ['Tokyo', 'tokyo', 'Tōkyō', 'Tokio', '東京', '東京都', '도쿄', 'Tokyo, Japan', 'TOKYO JP', '東京 日本']) {
      expect(peekCity(v)).toEqual({ lat: 35.6762, lng: 139.6503 });
    }
  });
  test('annonce « Tokyo » sans position : visible à Shinjuku, Yokohama et Osaka, masquée loin', async () => {
    const { geocodeCity } = require('../src/utils/geocodeCity');
    geocodeCity.mockClear();
    for (const city of ['Tokyo', 'Tōkyō', '東京都']) {
      const posts = [{ location: { city } }];
      // Shinjuku, Yokohama, Osaka (≈ 400 km) : sous les 500 km.
      for (const viewerCoords of [[139.7034, 35.6938], [139.638, 35.4437], [135.5023, 34.6937]]) {
        expect((await u.noCoordsPostsToHide640(posts, { viewerCoords, viewerCity: '', maxKm: 500 })).size).toBe(0);
      }
      // Zone fictive et Paris : masquée.
      expect((await u.noCoordsPostsToHide640(posts, { viewerCoords: [-30, -35], viewerCity: 'Zone fictive', maxKm: 500 })).size).toBe(1);
      expect((await u.noCoordsPostsToHide640(posts, { viewerCoords: [2.3522, 48.8566], viewerCity: 'Paris', maxKm: 500 })).size).toBe(1);
    }
    expect(geocodeCity).not.toHaveBeenCalled(); // aucune requête au géocodeur
  });
  test('noms piégés (« constructor », « __proto__ ») : pas une ville fixe', () => {
    const { peekCity } = require('../src/utils/geocodeCity');
    for (const v of ['constructor', '__proto__', 'toString', 'hasOwnProperty']) {
      const r = peekCity(v);
      expect(r == null || (Number.isFinite(r.lat) && Number.isFinite(r.lng))).toBe(true);
    }
  });
  test('modification : ancienne annonce sans position + même ville → on tente la ville', async () => {
    const out = await u.keepOrGeocodeLocation640({ city: 'Procheville' }, { city: 'Procheville' });
    expect(out).toMatchObject({ city: 'Procheville', lat: -35.5, lng: -30.5, geocoded: true });
    expect(await u.keepOrGeocodeLocation640({ city: 'X', lat: 1, lng: 2 }, null)).toBeNull();
  });
  test('modification : même ville écrite autrement (≤ 30 km) → la position précise d’avant est gardée', async () => {
    const out = await u.keepOrGeocodeLocation640({ city: 'São Paulo', lat: -23.6, lng: -46.7 }, { city: 'Sao Paulo - SP' });
    expect(out).toMatchObject({ city: 'Sao Paulo - SP', lat: -23.6, lng: -46.7 });
  });
  test('modification : géocodeur en panne sur une nouvelle ville → enregistrée sans position inventée', async () => {
    const out = await u.keepOrGeocodeLocation640({ city: 'Zone fictive', lat: -35, lng: -30 }, { city: 'Panneville' });
    expect(out).toEqual({ city: 'Panneville' });
  });
});
