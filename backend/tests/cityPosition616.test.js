// 616 (ZOE, 08/10/2026) — POSITION DE PROFIL DEPUIS LA VILLE (accord écrit de Daniel).
// Mesuré en prod par BOB : 43 vrais comptes sur 185 sans AUCUNE position → absents de la
// PawMap, de « X gardiens près de chez vous », et de l'alerte 100 km quand le géocodage
// de leur ville ne répond pas au moment de l'envoi.
// VRAIE base Mongo en mémoire, vrais modèles (plugins compris), vraie route de la carte,
// vraie sélection de l'alerte 612. Nominatim et Photon SIMULÉS : rien ne sort sur le réseau.
// Les réponses Nominatim simulées reprennent les réponses RÉELLES relevées le 08/10.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.CITY_POSITION_AUTO_IN_TESTS = '1';

const mockMails = [];
const mockPushes = [];
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false),
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)), isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => { mockPushes.push(m); return { successCount: 0, failureCount: 0, responses: [] }; }) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (...a) => { mockMails.push(a); return { messageId: 'capté' }; }) };
});
// Photon (contre-vérification) simulé : Asnières → Asnières-sur-Seine (réponse réelle du 08/10).
const mockPhoton = {
  stockholm: { lat: 59.3251172, lng: 18.0710935 },
  'neuilly-sur-marne': { lat: 48.8636, lng: 2.5307 },
  'asnières': { lat: 48.9105948, lng: 2.2890454 },
  'asnières-sur-seine': { lat: 48.9105948, lng: 2.2890454 },
};
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  return { ...actual, geocodeCity: jest.fn(async (c) => mockPhoton[String(c || '').trim().toLowerCase()] || null) };
});

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

// Réponses Nominatim RÉELLES (format jsonv2, abrégées), relevées le 08/10/2026.
const row = (name, addresstype, lat, lon, cc, importance, extra = {}) => ({
  name, addresstype, type: 'administrative', category: 'boundary', place_rank: 16,
  lat: String(lat), lon: String(lon), importance, address: { country_code: cc }, ...extra,
});
const NOMI = {
  stockholm: [
    row('Stockholm', 'city', 59.3251172, 18.0710935, 'se', 0.803, { category: 'place', type: 'city', place_rank: 15 }),
    row('Stockholm Municipality', 'municipality', 59.3, 18.0, 'se', 0.621),
    row('Stockholm', 'village', 44.48, -92.26, 'us', 0.433),
  ],
  'neuilly-sur-marne': [row('Neuilly-sur-Marne', 'town', 48.8636, 2.5307, 'fr', 0.52)],
  'west virginia': [row('West Virginia', 'state', 38.47, -80.97, 'us', 0.739, { place_rank: 8 })],
  springfield: [
    row('Springfield', 'city', 39.7990175, -89.6439575, 'us', 0.613),
    row('Springfield', 'city', 42.1018764, -72.5886727, 'us', 0.611),
    row('Springfield', 'city', 37.2081729, -93.2922715, 'us', 0.596),
  ],
  'asnières': [
    row('Asnières', 'village', 49.19499, 0.39723, 'fr', 0.552),
    row('Asnières-les-Bourges', 'suburb', 47.1234114, 2.405281, 'fr', 0.147, { category: 'place', type: 'suburb', place_rank: 19 }),
  ],
  'asnières-sur-seine': [row('Asnières-sur-Seine', 'town', 48.9105948, 2.2890454, 'fr', 0.6)],
  paris: [
    row('Paris', 'suburb', 48.8588897, 2.320041, 'fr', 0.897, { place_rank: 15 }),
    row('Paris', 'city', 48.8534951, 2.3483915, 'fr', 0.897, { place_rank: 12 }),
    row('Paris', 'town', 33.6617962, -95.555513, 'us', 0.53),
  ],
};
const calls = [];

const STOCKHOLM = [18.0710935, 59.3251172];
const KM_PER_DEG_LAT = (Math.PI * 6371) / 180;
const kmBetween = (a, b) => {
  const R = 6371; const r = (d) => (d * Math.PI) / 180;
  const s = Math.sin(r(b[1] - a[1]) / 2) ** 2 + Math.cos(r(a[1])) * Math.cos(r(b[1])) * Math.sin(r(b[0] - a[0]) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

let mongo; let Owner; let Sitter; let Walker; let Notification; let cp; let home590;
const ins = async (Model, doc) => String((await Model.collection.insertOne({ status: 'active', ...doc })).insertedId);
const full = (Model, id) => Model.findById(id).select('+homeLocation +positionFromCity').lean();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Notification = require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  cp = require('../src/utils/cityPosition616');
  home590 = require('../src/utils/homePosition590');
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => {
  cp._test.reset();
  calls.length = 0;
  cp._test.setFetch(async (city) => { calls.push({ city, at: Date.now() }); return NOMI[String(city).toLowerCase()] || []; });
});

describe('choix du centre-ville (réponses Nominatim réelles)', () => {
  test('Stockholm → la ville de Suède ; Paris → Paris (France)', () => {
    expect(cp.pickSettlement(NOMI.stockholm)).toMatchObject({ lat: 59.325117, lng: 18.071094, country: 'SE', type: 'city' });
    const p = cp.pickSettlement(NOMI.paris);
    expect(p.country).toBe('FR');
    expect(kmBetween([p.lng, p.lat], [2.3522, 48.8566])).toBeLessThan(5);
  });
  test('région (« West Virginia ») et nom ambigu (« Springfield ») → rien', () => {
    expect(cp.pickSettlement(NOMI['west virginia'])).toEqual({ miss: 'not_a_city:state' });
    expect(cp.pickSettlement(NOMI.springfield)).toEqual({ miss: 'ambiguous' });
    expect(cp.pickSettlement([])).toEqual({ miss: 'not_found' });
  });
  test('le pays du profil départage (Stockholm, US → le village du Wisconsin, pas la capitale)', () => {
    expect(cp.pickSettlement(NOMI.stockholm, 'US')).toMatchObject({ country: 'US', lat: 44.48 });
  });
  test('ville inutilisable : vide, « — », e-mail, adresse web → rien', () => {
    for (const v of ['', '   ', '—', '-', '?', 'jean@gmail.com', 'www.site.com']) expect(cp.usableCity(v)).toBe('');
    expect(cp.usableCity('Paris 11e')).toBe('Paris');
    expect(cp.usableCity('STOCKHOLM')).toBe('STOCKHOLM');
  });
});

describe('Nominatim : 1 requête par seconde au plus, cache par ville', () => {
  test('3 villes différentes → 3 requêtes espacées d’au moins 1 s ; la même ville ensuite → 0 requête', async () => {
    await cp.cityCenter('Stockholm');
    await cp.cityCenter('Neuilly-sur-Marne');
    await cp.cityCenter('Paris');
    expect(calls.map((c) => c.city)).toEqual(['Stockholm', 'Neuilly-sur-Marne', 'Paris']);
    for (let i = 1; i < calls.length; i += 1) expect(calls[i].at - calls[i - 1].at).toBeGreaterThanOrEqual(1000);
    await cp.cityCenter('STOCKHOLM ');
    await cp.cityCenter('stockholm');
    expect(calls).toHaveLength(3);
  }, 20000);
  test('identifiant HoPetSit dans le User-Agent', () => {
    expect(cp.UA).toBe('HoPetSit/1.0 (contact: hopetsit@gmail.com)');
    expect(cp.MIN_GAP_MS).toBeGreaterThanOrEqual(1000);
  });
  test('sources en désaccord (Asnières : village de l’Eure pour Nominatim, Asnières-sur-Seine pour Photon) → rien, on ne devine pas', async () => {
    const r = await cp.cityCenter('Asnières');
    expect(r.miss).toBe('ambiguous_sources');
    expect(r.km).toBeGreaterThan(100);
  });
});

describe('inscription : position posée automatiquement depuis la ville', () => {
  let id;
  test('pet-sitter inscrite avec la ville « STOCKHOLM » et sans GPS → centre de Stockholm, marqué approximatif', async () => {
    const s = await Sitter.create({ name: 'Astrid', email: 'astrid616@example.test', password: 'x'.repeat(12), city: 'STOCKHOLM', country: 'SE' });
    id = String(s._id);
    await cp._test.idle();
    const d = await full(Sitter, id);
    expect(d.location.coordinates).toEqual([18.071094, 59.325117]);
    expect(d.homeLocation.coordinates).toEqual([18.071094, 59.325117]);
    expect(d.positionFromCity).toMatchObject({ coordinates: [18.071094, 59.325117], provider: 'nominatim' });
    expect(cp.isCityApprox(d)).toBe(true);
    expect(d.location.updatedAt == null).toBe(true); // pas un partage en direct
    expect(kmBetween(d.location.coordinates, STOCKHOLM)).toBeLessThan(0.01);
  }, 20000);

  test('l’app renvoie les MÊMES coordonnées en enregistrant le profil → toujours approximatif', async () => {
    await Sitter.updateOne({ _id: id }, { $set: { 'location.coordinates': [18.071094, 59.325117], 'location.city': 'Stockholm', bio: 'Bonjour' } });
    expect(cp.isCityApprox(await full(Sitter, id))).toBe(true);
  });

  test('1re vraie position GPS, à 6 km du centre (moins de 50 km) → elle REMPLACE le centre-ville', async () => {
    const gps = { lat: 59.3251172 + 6 / KM_PER_DEG_LAT, lng: 18.0710935 };
    const r = await home590.updateHomePosition(id, { ...gps, city: 'Stockholm' });
    expect(r.reason).toBe('replaced_city_center');
    const d = await full(Sitter, id);
    expect(d.location.coordinates).toEqual([gps.lng, gps.lat]);
    expect(d.homeLocation.coordinates).toEqual([gps.lng, gps.lat]);
    expect(cp.isCityApprox(d)).toBe(false);
    // Le GPS suivant dans la même ville ne bouge plus rien (règle v590 normale).
    const r2 = await home590.updateHomePosition(id, { lat: gps.lat + 0.01, lng: gps.lng, city: 'Stockholm' });
    expect(r2.reason).toBe('same_city');
  });

  test('jamais l’inverse : une vraie position n’est JAMAIS remplacée par le centre-ville', async () => {
    const before = await full(Sitter, id);
    const r = await cp.positionFromCityFor('Sitter', id, { apply: true });
    expect(r).toMatchObject({ status: 'skipped', reason: 'has_position' });
    expect((await full(Sitter, id)).location.coordinates).toEqual(before.location.coordinates);
  });

  test('profil enregistré AVEC GPS dès l’inscription → aucune requête, position intacte', async () => {
    const s = await Walker.create({ name: 'Gps', email: 'gps616@example.test', password: 'x'.repeat(12), city: 'Stockholm', location: { type: 'Point', coordinates: [18.2, 59.4], city: 'Stockholm' } });
    await cp._test.idle();
    const d = await full(Walker, s._id);
    expect(d.location.coordinates).toEqual([18.2, 59.4]);
    expect(d.positionFromCity).toBeUndefined();
    expect(calls).toHaveLength(0);
  });

  test('course : une vraie position arrive pendant le géocodage → le centre-ville n’écrase rien', async () => {
    const wid = await ins(Walker, { name: 'Course', email: 'course616@example.test', city: 'Neuilly-sur-Marne' });
    cp._test.setFetch(async (city) => {
      await Walker.collection.updateOne({ _id: new mongoose.Types.ObjectId(wid) }, { $set: { location: { type: 'Point', coordinates: [2.5, 48.86] } } });
      return NOMI[String(city).toLowerCase()] || [];
    });
    const r = await cp.positionFromCityFor('Walker', wid, { apply: true });
    expect(r).toMatchObject({ status: 'skipped', reason: 'has_position' });
    expect((await full(Walker, wid)).location.coordinates).toEqual([2.5, 48.86]);
  });

  test('modification du profil : la ville est ajoutée plus tard → la position suit', async () => {
    const oid = await ins(Owner, { name: 'Sans ville', email: 'sansville616@example.test' });
    await cp._test.idle();
    expect((await full(Owner, oid)).location).toBeUndefined();
    await Owner.updateOne({ _id: oid }, { $set: { city: 'Neuilly-sur-Marne' } });
    await cp._test.idle();
    const d = await full(Owner, oid);
    expect(d.location.coordinates).toEqual([2.5307, 48.8636]);
    expect(d.location.city).toBe('Neuilly-sur-Marne');
  });
});

describe('ville vide ou introuvable → rien, et c’est noté', () => {
  test.each([
    ['', 'empty_city'], ['—', 'empty_city'], ['West Virginia', 'not_a_city:state'],
    ['Springfield', 'ambiguous'], ['Asnières', 'ambiguous_sources'], ['Atlantide', 'not_found'],
  ])('ville « %s » → %s', async (city, reason) => {
    const wid = await ins(Walker, { name: 'V', email: `v${Math.random()}@example.test`, city });
    const r = await cp.positionFromCityFor('Walker', wid, { apply: true });
    expect(r).toMatchObject({ status: 'skipped', reason });
    expect((await full(Walker, wid)).location).toBeUndefined();
  }, 20000);
  test('compte +test ou interne → jamais placé dans une vraie ville', async () => {
    const t = await ins(Walker, { name: 'T', email: 'dadaciao84+testwalker616@gmail.com', city: 'Stockholm' });
    const p = await ins(Walker, { name: 'P', email: 'probe-565@invalid.example', city: 'Stockholm' });
    expect((await cp.positionFromCityFor('Walker', t, { apply: true })).reason).toBe('test_or_internal');
    expect((await cp.positionFromCityFor('Walker', p, { apply: true })).reason).toBe('test_or_internal');
  });
});

describe('autre profil de la même personne', () => {
  test('son profil propriétaire a une vraie position → son profil gardien la reprend (pas le centre-ville)', async () => {
    await ins(Owner, { name: 'Léa', email: 'lea616@example.test', city: 'Paris', location: { type: 'Point', coordinates: [2.3, 48.87] } });
    const sid = await ins(Sitter, { name: 'Léa', email: 'lea616@example.test', city: 'Paris' });
    const r = await cp.positionFromCityFor('Sitter', sid, { apply: true });
    expect(r).toMatchObject({ status: 'set', source: 'other_profile', lat: 48.87, lng: 2.3 });
    const d = await full(Sitter, sid);
    expect(d.location.coordinates).toEqual([2.3, 48.87]);
    expect(cp.isCityApprox(d)).toBe(false);
    expect(calls).toHaveLength(0);
  });
});

describe('rattrapage (route admin)', () => {
  let ids;
  beforeAll(async () => {
    for (const M of [Owner, Sitter, Walker]) await M.collection.deleteMany({}); // eslint-disable-line no-await-in-loop
    ids = {
      sto: await ins(Sitter, { name: 'Sto', email: 'sto616@example.test', city: 'STOCKHOLM' }),
      neu: await ins(Walker, { name: 'Neu', email: 'neu616@example.test', city: 'Neuilly-sur-Marne' }),
      asn: await ins(Owner, { name: 'Asn', email: 'asn616@example.test', city: 'Asnières' }),
      wv: await ins(Owner, { name: 'Wv', email: 'wv616@example.test', city: 'West Virginia' }),
      dash: await ins(Owner, { name: 'Dash', email: 'dash616@example.test', city: '—' }),
      gps: await ins(Walker, { name: 'Gps', email: 'gps2616@example.test', city: 'Paris', location: { type: 'Point', coordinates: [2.35, 48.85] } }),
    };
  });
  const handler = () => {
    const router = require('../src/routes/adminPositionsFromCity616');
    const layer = router.stack.find((l) => l.route && l.route.path === '/');
    return layer.route.stack[layer.route.stack.length - 1].handle;
  };
  const call = (query, body = {}) => new Promise((resolve, reject) => {
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(handler()({ query, body, user: { id: 'admin', role: 'admin' }, headers: {} }, res)).catch(reject);
  });

  test('simulation (?dryRun=1) : la liste ville → coordonnées, RIEN d’écrit, aucun e-mail', async () => {
    const r = await call({ dryRun: '1' });
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ dryRun: true, examined: 5, wouldSet: 2, set: 0, skipped: 3 });
    expect(r.body.reasons).toEqual({ ambiguous_sources: 1, 'not_a_city:state': 1, empty_city: 1 });
    const byId = Object.fromEntries(r.body.rows.map((x) => [x.id, x]));
    expect(byId[ids.sto]).toMatchObject({ status: 'would_set', role: 'sitter', city: 'STOCKHOLM', lat: 59.325117, lng: 18.071094 });
    expect(byId[ids.asn].candidates.km).toBeGreaterThan(100);
    expect(JSON.stringify(r.body)).not.toMatch(/@/); // jamais d'e-mail dans la réponse
    expect(byId[ids.gps]).toBeUndefined(); // a déjà une position : pas même examiné
    for (const [M, k] of [[Sitter, 'sto'], [Walker, 'neu']]) expect((await full(M, ids[k])).location).toBeUndefined(); // eslint-disable-line no-await-in-loop
  }, 20000);

  test('écriture : 2 posés, le reste laissé vide ; 2e passage = 0 (idempotent) ; GPS intact', async () => {
    const r = await call({});
    expect(r.body).toMatchObject({ dryRun: false, set: 2, skipped: 3 });
    expect((await full(Sitter, ids.sto)).location.coordinates).toEqual([18.071094, 59.325117]);
    expect((await full(Walker, ids.neu)).location.coordinates).toEqual([2.5307, 48.8636]);
    expect((await full(Owner, ids.wv)).location).toBeUndefined();
    expect((await full(Walker, ids.gps)).location.coordinates).toEqual([2.35, 48.85]);
    const again = await call({});
    expect(again.body).toMatchObject({ set: 0, examined: 3 });
  }, 20000);

  test('ville ambiguë précisée par un humain après la simulation (« Asnières » → « Asnières-sur-Seine »)', async () => {
    const r = await call({}, { cityQueries: { Asnières: 'Asnières-sur-Seine' } });
    expect(r.body.set).toBe(1);
    const d = await full(Owner, ids.asn);
    expect(d.location.coordinates).toEqual([2.289045, 48.910595]);
    expect(d.location.city).toBe('Asnières'); // la ville écrite par la personne n'est pas réécrite
  }, 20000);

  test('aucune notification, aucun e-mail, aucun push par ce changement', async () => {
    expect(await Notification.countDocuments({})).toBe(0);
    expect(mockMails).toHaveLength(0);
    expect(mockPushes).toHaveLength(0);
  });
});

describe('la PawMap et l’alerte 100 km les voient désormais', () => {
  let ids;
  const world = async (viewerId) => {
    const router = require('../src/routes/friendRoutes');
    const layer = router.stack.find((l) => l.route && l.route.path === '/members/world');
    const fn = layer.route.stack[layer.route.stack.length - 1].handle;
    return new Promise((resolve, reject) => {
      const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
      Promise.resolve(fn({ user: { id: viewerId, role: 'walker' }, query: {}, headers: {} }, res)).catch(reject);
    });
  };
  beforeAll(async () => {
    for (const M of [Owner, Sitter, Walker]) await M.collection.deleteMany({}); // eslint-disable-line no-await-in-loop
    cp._test.reset();
    cp._test.setFetch(async (city) => NOMI[String(city).toLowerCase()] || []);
    ids = {
      visible: await ins(Sitter, { name: 'Nina Visible', email: 'nina616@example.test', city: 'Neuilly-sur-Marne' }),
      hidden: await ins(Sitter, { name: 'Hugo Masque', email: 'hugo616@example.test', city: 'Neuilly-sur-Marne', preferences: { mapVisibility: 'hidden', hideFromMap: true } }),
      viewer: await ins(Walker, { name: 'Lecteur', email: 'lecteur616@example.test', location: { type: 'Point', coordinates: [-30.4, -35.2] } }),
    };
  });

  test('AVANT : sans position, la carte ne les montre pas', async () => {
    const r = await world(ids.viewer);
    expect(r.status).toBe(200);
    expect(r.body.members.map((m) => m.id)).not.toContain(ids.visible);
  });

  test('APRÈS : visible pour un non-ami, position FLOUTÉE (pas les coordonnées enregistrées) ; « Masqué » → absent', async () => {
    await cp.backfillPositionsFromCity({ dryRun: false });
    require('../src/routes/friendRoutes')._resetWorldCacheForTest?.();
    // Le cache de 5 min de la couche monde est partagé : on attend sa fin en reculant l'horloge.
    const realNow = Date.now;
    Date.now = () => realNow() + 10 * 60 * 1000;
    let r;
    try { r = await world(ids.viewer); } finally { Date.now = realNow; }
    const got = r.body.members.find((m) => m.id === ids.visible);
    expect(got).toBeTruthy();
    expect(got.approx).toBe(true);
    const stored = (await full(Sitter, ids.visible)).location.coordinates;
    expect(got.location.coordinates).not.toEqual(stored);
    expect(kmBetween(got.location.coordinates, stored)).toBeLessThan(1.5);
    expect(r.body.members.map((m) => m.id)).not.toContain(ids.hidden);
    // Le profil masqué a bien une position (pour l'alerte), mais n'apparaît nulle part sur la carte.
    expect((await full(Sitter, ids.hidden)).location.coordinates).toEqual([2.5307, 48.8636]);
  });

  test('« X gardiens près de chez vous » à Paris (25 km) : la gardienne de Neuilly-sur-Marne est comptée APRÈS, pas AVANT', async () => {
    const supply = require('../src/routes/supplyRoutes');
    const layer = supply.stack.find((l) => l.route && l.route.path === '/city');
    const fn = layer.route.stack[layer.route.stack.length - 1].handle;
    const count = (q) => new Promise((resolve, reject) => {
      const res = { statusCode: 200, set() { return this; }, status(c) { this.statusCode = c; return this; }, json(b) { resolve(b); } };
      Promise.resolve(fn({ query: q, headers: {} }, res)).catch(reject);
    });
    const nid = await ins(Sitter, { name: 'Neuilly Seule', email: 'neuillyseule616@example.test', city: 'Neuilly-sur-Marne' });
    const before = await count({ city: 'Paris', lat: '48.8566', lng: '2.3522', radiusKm: '25' });
    await cp.positionFromCityFor('Sitter', nid, { apply: true });
    const after = await count({ city: 'Paris', lat: '48.8566', lng: '2.35221', radiusKm: '25' }); // autre clé de cache
    expect(after.sitters).toBe(before.sitters + 1);
  });

  test('alerte 612 (garde à Paris, géocodeur de secours muet) : AVANT rien, APRÈS trouvée « par ses coordonnées » à ~13 km', async () => {
    const alert612 = require('../src/services/requestAlert612');
    const sid = await ins(Sitter, { name: 'Zoe Gardienne', email: 'zoeg616@example.test', city: 'Neuilly-sur-Marne' });
    const args = { center: { lat: 48.8566, lng: 2.3522 }, city: 'Paris', services: ['pet_sitting'], selfIds: new Set(), geocode: async () => null };
    const before = await alert612.selectRecipients(args);
    const ids0 = JSON.stringify(before);
    expect(ids0).not.toContain(sid);
    await cp.positionFromCityFor('Sitter', sid, { apply: true });
    const after = await alert612.selectRecipients(args);
    const flat = JSON.stringify(after);
    expect(flat).toContain(sid);
    expect(flat).toMatch(/"via":"coords"/);
    expect(await Notification.countDocuments({})).toBe(0); // la sélection n'envoie rien
  });
});
