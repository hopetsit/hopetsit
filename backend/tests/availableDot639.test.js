// 639 (BOB, lot D) — pastille « Disponible aujourd'hui » de la PawMap : drapeau
// serveur `availableDot` dans `pinFlags` (backend/src/utils/mapVisibility.js).
//
//   availableDot = disponibilité DÉCLARÉE aujourd'hui (availableToday, inchangé)
//                  ET dernière présence (`lastSeenAt`) de moins de N heures
//                     (PAWMAP_AVAILABLE_DOT_HOURS, 48 par défaut ; absente = faux)
//                  ET gardien ou promeneur (jamais un propriétaire)
//                  ET coupe-circuit PAWMAP_AVAILABLE_DOT !== 'off'.
//
// Sans base ni réseau : modèles simulés, zone fictive (lat −35 / lng −30),
// VRAIS gestionnaires de GET /friends/members/world et /friends/members/nearby.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const LAT = -35.2;
const LNG = -30.4;
const FUTURE = new Date(Date.now() + 30 * 24 * 3600 * 1000);
const H = 3600 * 1000;
const ago = (hours) => new Date(Date.now() - hours * H);
const TODAY = [new Date()];
const loc = (dx) => ({ type: 'Point', coordinates: [LNG + dx, LAT] });
const base = (id, dx, extra = {}) => ({
  _id: id, email: `${id}@example.test`, name: `Membre ${id}`, location: loc(dx), preferences: {}, mapBoostExpiry: FUTURE, ...extra,
});

const DOCS = {
  Owner: [
    // propriétaire avec des dates « disponibles » et vu à l'instant : JAMAIS de point vert
    base('prop', 0.001, { availableDates: TODAY, lastSeenAt: ago(0.1) }),
    base('friend1', 0.002, {}),
  ],
  Sitter: [
    base('dispo', 0.003, { availableDates: TODAY, lastSeenAt: ago(2) }), // dispo + vue il y a 2 h → vrai
    base('vieux', 0.004, { availableDates: TODAY, lastSeenAt: ago(5 * 24) }), // dispo, vue il y a 5 jours → faux
    base('jamais', 0.005, { availableDates: TODAY }), // dispo, jamais vue → faux
    base('pasdispo', 0.006, { lastSeenAt: ago(1) }), // vue, mais rien déclaré → faux
    // amie « amis seulement » : hors cache partagé, ajoutée pour ses amis
    base('amie', 0.007, { availableDates: TODAY, lastSeenAt: ago(1), preferences: { hideFromMap: true } }),
  ],
  Walker: [
    base('prom', 0.008, { availableDates: TODAY, lastSeenAt: ago(10) }), // promeneur dispo, vu il y a 10 h → vrai
    base('stranger1', -0.01, { mapBoostExpiry: null }),
  ],
};
const MODEL_OF = (id) => {
  for (const [name, list] of Object.entries(DOCS)) if (list.some((d) => String(d._id) === String(id))) return name;
  return 'Sitter';
};
const SELECTS = [];

function get(doc, path) {
  return path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), doc);
}
function matches(doc, q) {
  if (!q) return true;
  for (const [k, v] of Object.entries(q)) {
    if (k === '$or') { if (!v.some((c) => matches(doc, c))) return false; continue; }
    if (k === 'location') continue; // $near ignoré : tout le monde est dans le rayon de test
    if (k === 'location.coordinates.1') { if (!Array.isArray(get(doc, 'location.coordinates'))) return false; continue; }
    const val = k === '_id' ? String(doc._id) : get(doc, k);
    if (v && typeof v === 'object' && '$ne' in v) { if (val === v.$ne) return false; continue; }
    if (v && typeof v === 'object' && '$in' in v) { if (!v.$in.map(String).includes(String(val))) return false; continue; }
    if (v && typeof v === 'object' && '$exists' in v) continue;
    if (v && typeof v === 'object' && '$gt' in v) { if (!(val && new Date(val) > new Date(v.$gt))) return false; continue; }
    if (String(val) !== String(v)) return false;
  }
  return true;
}
const chain = (result) => {
  const c = {
    select: (s) => { SELECTS.push(String(s || '')); return c; }, limit: () => c, sort: () => c,
    lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko),
    catch: () => c,
  };
  return c;
};
const mockModel = (name) => ({
  find: jest.fn((q) => chain(DOCS[name].filter((d) => matches(d, q)).map((d) => ({ ...d })))),
  findById: jest.fn((id) => chain(DOCS[name].find((d) => String(d._id) === String(id)) || null)),
  exists: jest.fn(() => Promise.resolve(false)),
  updateOne: jest.fn(() => Promise.resolve({ acknowledged: true })),
});

jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => chain([])),
  findOne: jest.fn(() => chain(null)),
  hasActivePawFollow: jest.fn(() => Promise.resolve(false)),
  isInSameFamily: jest.fn(() => Promise.resolve(false)),
  familyActiveMatch: jest.fn(() => ({})),
}));
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn((q) => {
    // Une seule amitié acceptée : friend1 ↔ amie.
    const rows = [{ requesterId: 'friend1', addresseeId: 'amie', status: 'accepted' }];
    const ids = new Set();
    for (const c of (q.$or || [])) {
      for (const v of Object.values(c)) for (const x of ((v && v.$in) || [])) ids.add(String(x));
    }
    return chain(rows.filter((r) => ids.has(String(r.requesterId)) || ids.has(String(r.addresseeId))));
  }),
}));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
  emitToUser: jest.fn(),
}));
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve([String(id)])),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), {
    ids: [String(i)], set: new Set([String(i)]), docs: [{ id: String(i), model: MODEL_OF(i) }],
  }])))),
}));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn((id) => {
    const s = String(id);
    return Promise.resolve({ ids: [s], set: new Set([s]), docs: [{ id: s, model: MODEL_OF(s) }] });
  }),
}));

const mv = require('../src/utils/mapVisibility');

/** Gestionnaire d'une route, sur un module friendRoutes NEUF (cache monde vide). */
function freshHandlers() {
  jest.resetModules();
  const router = require('../src/routes/friendRoutes');
  const of = (path) => {
    const layer = router.stack.find((l) => l.route && l.route.path === path);
    if (!layer) throw new Error(`route ${path} introuvable`);
    return layer.route.stack[layer.route.stack.length - 1].handle;
  };
  return { world: of('/members/world'), nearby: of('/members/nearby') };
}
function call(fn, user, query = {}) {
  return new Promise((resolve, reject) => {
    const req = { user, query, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: b }); },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}
const STRANGER = { id: 'stranger1', role: 'walker' };
const FRIEND = { id: 'friend1', role: 'owner' };
const Q = { lat: String(LAT), lng: String(LNG), radiusInMeters: '25000' };
const dots = (body) => Object.fromEntries((body.members || []).map((m) => [m.id, m.availableDot]));

afterEach(() => {
  delete process.env.PAWMAP_AVAILABLE_DOT;
  delete process.env.PAWMAP_AVAILABLE_DOT_HOURS;
});

describe('639 — règle pure (pinFlags / isAvailableDot)', () => {
  const now = new Date('2026-11-12T10:00:00Z'); // un jeudi
  const dispoDoc = (seen) => ({ availableDays: ['thursday'], ...(seen === undefined ? {} : { lastSeenAt: seen }) });
  const seen = (hours) => new Date(now.getTime() - hours * H);

  test('gardien et promeneur disponibles et vus récemment → vrai', () => {
    expect(mv.pinFlags(dispoDoc(seen(1)), now, { role: 'sitter' }).availableDot).toBe(true);
    expect(mv.pinFlags(dispoDoc(seen(47)), now, { role: 'walker' }).availableDot).toBe(true);
    // la date peut arriver en texte ISO (document lu en lean puis sérialisé)
    expect(mv.pinFlags(dispoDoc(seen(3).toISOString()), now, { role: 'sitter' }).availableDot).toBe(true);
  });

  test('disponibilité NON déclarée aujourd’hui → faux, même vu à l’instant', () => {
    expect(mv.pinFlags({ lastSeenAt: seen(0.1) }, now, { role: 'sitter' }).availableDot).toBe(false);
    expect(mv.pinFlags({ availableDays: ['friday'], lastSeenAt: seen(0.1) }, now, { role: 'sitter' }).availableDot).toBe(false);
    // jour marqué indisponible : availableToday est faux, donc le point aussi
    expect(mv.pinFlags({ availableDays: ['thursday'], unavailableDates: ['2026-11-12T00:00:00Z'], lastSeenAt: seen(1) }, now, { role: 'sitter' }).availableDot).toBe(false);
  });

  test('fraîcheur : 48 h par défaut, absent / illisible = faux', () => {
    expect(mv.availableDotHours()).toBe(48);
    expect(mv.pinFlags(dispoDoc(seen(47.9)), now, { role: 'sitter' }).availableDot).toBe(true);
    expect(mv.pinFlags(dispoDoc(seen(48)), now, { role: 'sitter' }).availableDot).toBe(false);
    expect(mv.pinFlags(dispoDoc(seen(72)), now, { role: 'sitter' }).availableDot).toBe(false);
    expect(mv.pinFlags(dispoDoc(), now, { role: 'sitter' }).availableDot).toBe(false);
    expect(mv.pinFlags(dispoDoc(null), now, { role: 'sitter' }).availableDot).toBe(false);
    expect(mv.pinFlags(dispoDoc('pas une date'), now, { role: 'sitter' }).availableDot).toBe(false);
  });

  test('PAWMAP_AVAILABLE_DOT_HOURS règle la fenêtre ; valeur illisible → 48', () => {
    process.env.PAWMAP_AVAILABLE_DOT_HOURS = '6';
    expect(mv.availableDotHours()).toBe(6);
    expect(mv.pinFlags(dispoDoc(seen(5)), now, { role: 'sitter' }).availableDot).toBe(true);
    expect(mv.pinFlags(dispoDoc(seen(7)), now, { role: 'sitter' }).availableDot).toBe(false);
    for (const bad of ['', 'abc', '0', '-3']) {
      process.env.PAWMAP_AVAILABLE_DOT_HOURS = bad;
      expect(mv.availableDotHours()).toBe(48);
    }
  });

  test('rôle : jamais un propriétaire, jamais sans rôle', () => {
    expect(mv.pinFlags(dispoDoc(seen(1)), now, { role: 'owner' }).availableDot).toBe(false);
    expect(mv.pinFlags(dispoDoc(seen(1)), now, {}).availableDot).toBe(false);
    expect(mv.pinFlags(dispoDoc(seen(1)), now).availableDot).toBe(false); // ancien appel à 2 arguments
    expect(mv.pinFlags(dispoDoc(seen(1))).availableDot).toBe(false);
  });

  test('présence de la PERSONNE : la plus récente de ses profils', () => {
    const doc = dispoDoc(seen(200)); // ce profil-ci : vieux
    expect(mv.pinFlags(doc, now, { role: 'sitter' }).availableDot).toBe(false);
    expect(mv.pinFlags(doc, now, { role: 'sitter', lastSeenAt: [seen(200), seen(3), null] }).availableDot).toBe(true);
    expect(mv.pinFlags(doc, now, { role: 'sitter', lastSeenAt: [null, undefined] }).availableDot).toBe(false);
  });

  test('coupe-circuit PAWMAP_AVAILABLE_DOT=off → toujours faux ; availableToday ne bouge pas', () => {
    process.env.PAWMAP_AVAILABLE_DOT = 'OFF';
    const f = mv.pinFlags(dispoDoc(seen(1)), now, { role: 'sitter' });
    expect(f.availableDot).toBe(false);
    expect(f.availableToday).toBe(true);
    delete process.env.PAWMAP_AVAILABLE_DOT;
    expect(mv.pinFlags(dispoDoc(seen(1)), now, { role: 'sitter' }).availableDot).toBe(true);
  });

  test('les autres drapeaux sont inchangés et lastSeenAt ne sort pas des drapeaux', () => {
    const f = mv.pinFlags({ boostExpiry: '2026-12-01', kycStatus: 'verified', availableDays: ['thursday'], lastSeenAt: seen(1) }, now, { role: 'sitter' });
    expect(f).toEqual({ isBoosted: true, kycVerified: true, identityVerified: true, availableToday: true, availableDot: true });
    expect(Object.keys(f)).not.toContain('lastSeenAt');
  });
});

describe('639 — couche monde (GET /friends/members/world)', () => {
  test('point vert seulement pour gardien / promeneur disponibles et vus récemment ; lastSeenAt lu en base mais jamais renvoyé', async () => {
    SELECTS.length = 0;
    const { world } = freshHandlers();
    const r = await call(world, STRANGER);
    expect(r.status).toBe(200);
    const d = dots(r.body);
    expect(d.dispo).toBe(true);
    expect(d.prom).toBe(true);
    expect(d.vieux).toBe(false);
    expect(d.jamais).toBe(false);
    expect(d.pasdispo).toBe(false);
    expect(d.prop).toBe(false); // propriétaire : jamais
    expect(d.amie).toBeUndefined(); // « amis seulement » : hors couche publique
    // availableToday (filtre existant) reste la seule disponibilité déclarée
    const by = (id) => r.body.members.find((m) => m.id === id);
    expect(by('vieux').availableToday).toBe(true);
    expect(by('jamais').availableToday).toBe(true);
    expect(by('pasdispo').availableToday).toBe(false);
    // tous les membres portent un booléen
    expect(r.body.members.every((m) => typeof m.availableDot === 'boolean')).toBe(true);
    // la requête de la couche monde charge bien lastSeenAt…
    const worldSelects = SELECTS.filter((s) => s.includes('walkRates') && s.includes('availableDays'));
    expect(worldSelects.length).toBeGreaterThan(0);
    expect(worldSelects.every((s) => /\blastSeenAt\b/.test(s))).toBe(true);
    // … mais la réponse publique ne le contient pas
    expect(JSON.stringify(r.body)).not.toMatch(/lastSeenAt/);
  });

  test('ami « amis seulement » (ajouté hors cache) : même règle', async () => {
    const { world } = freshHandlers();
    await call(world, STRANGER); // remplit le cache partagé sans l'amie
    const w = await call(world, FRIEND);
    const amie = w.body.members.find((m) => m.id === 'amie');
    expect(amie).toBeDefined();
    expect(amie.availableDot).toBe(true);
    expect(amie.availableToday).toBe(true);
  });

  test('coupe-circuit : plus aucun point vert, le reste de la réponse est identique', async () => {
    const a = await call(freshHandlers().world, STRANGER);
    process.env.PAWMAP_AVAILABLE_DOT = 'off';
    const b = await call(freshHandlers().world, STRANGER);
    expect(Object.values(dots(b.body)).every((v) => v === false)).toBe(true);
    const strip = (body) => body.members.map(({ availableDot, ...rest }) => rest);
    expect(strip(b.body)).toEqual(strip(a.body));
  });
});

describe('639 — couche « proches » (GET /friends/members/nearby)', () => {
  test('même règle, et la fenêtre suit PAWMAP_AVAILABLE_DOT_HOURS', async () => {
    const { nearby } = freshHandlers();
    const r = await call(nearby, STRANGER, Q);
    expect(r.status).toBe(200);
    const d = dots(r.body);
    expect(d.dispo).toBe(true);
    expect(d.prom).toBe(true);
    expect(d.vieux).toBe(false);
    expect(d.jamais).toBe(false);
    expect(d.pasdispo).toBe(false);
    expect(d.prop).toBe(false);

    process.env.PAWMAP_AVAILABLE_DOT_HOURS = '1'; // dispo (2 h) et prom (10 h) sortent de la fenêtre
    const r2 = await call(nearby, STRANGER, Q);
    expect(dots(r2.body).dispo).toBe(false);
    expect(dots(r2.body).prom).toBe(false);

    delete process.env.PAWMAP_AVAILABLE_DOT_HOURS;
    process.env.PAWMAP_AVAILABLE_DOT = 'off';
    const r3 = await call(nearby, STRANGER, Q);
    expect(Object.values(dots(r3.body)).every((v) => v === false)).toBe(true);
  });
});
