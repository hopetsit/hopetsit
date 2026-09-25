// v585 (25/09/2026) — retours de Daniel sur le build 584 (Samsung réel) :
//   bug 2 — john C est son ami, mais en gardien / promeneur la fiche propose
//           « Ajouter en ami » : l'amitié doit valoir pour TOUS les profils
//           des deux personnes (drapeau `isFriend` du serveur) ;
//   bug 3 — john C affiché vers Valence alors qu'il est vers Murcie : la
//           couche monde prenait le 1er rôle lu (propriétaire) et un partage
//           en direct EXPIRÉ avait écrasé la position du profil ;
//   bug 5/7 — une personne propriétaire + gardienne = UN point avec ses deux
//           rôles (`roles`), jamais deux points superposés ; floutage tiré
//           vers le centre-ville (jamais au large) ; hors ligne = là où elle
//           s'est inscrite (règle de Daniel).
// Zone fictive (lat -35 / lng -30), sans base ni réseau (modèles simulés).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const P = require('../src/utils/personMapPosition');
const { blurTowardAnchor, blurLngLat } = require('../src/utils/coarseLocation');

// « Murcie » et « Valence » fictives, à ~180 km l'une de l'autre.
const MURCIE = [-30.0, -35.0];
const VALENCE = [-30.0, -33.4];
const DAYS = (n) => new Date(Date.now() - n * 24 * 3600 * 1000);

const DOCS = {
  Owner: [
    // Daniel (spectateur) : ses 3 profils, même e-mail.
    { _id: 'dan_owner', email: 'dan@example.test', name: 'Daniel', location: { coordinates: [-30.5, -35.5] }, preferences: {} },
    // john C, profil propriétaire : inscrit à Murcie, mais un ancien partage
    // en direct (il y a 2 jours, à Valence) a écrasé `location`.
    { _id: 'john_owner', email: 'john@example.test', name: 'john C', updatedAt: DAYS(2),
      location: { coordinates: VALENCE, updatedAt: DAYS(2), liveShareActive: true },
      homeLocation: { coordinates: MURCIE, city: 'Murcie', at: DAYS(30) }, preferences: {} },
  ],
  Sitter: [
    { _id: 'dan_sitter', email: 'dan@example.test', name: 'Daniel', location: { coordinates: [-30.5, -35.5] }, preferences: {} },
    // john C, profil gardien : même personne, position de formulaire à Murcie.
    { _id: 'john_sitter', email: 'john@example.test', name: 'john C', updatedAt: DAYS(1), dailyRate: 20,
      location: { coordinates: [MURCIE[0] + 0.01, MURCIE[1]] }, preferences: {}, mapBoostExpiry: new Date(Date.now() + 864e5) },
  ],
  Walker: [
    { _id: 'dan_walker', email: 'dan@example.test', name: 'Daniel', location: { coordinates: [-30.5, -35.5] }, preferences: {} },
  ],
};

function matches(doc, q) {
  if (!q) return true;
  for (const [k, v] of Object.entries(q)) {
    if (k === '$or') {
      if (!v.some((c) => matches(doc, c))) return false;
    } else if (k === 'location') {
      // $near : ignoré (tout le monde est dans le rayon de test)
    } else if (k === 'location.coordinates.1') {
      if (!doc.location || !Array.isArray(doc.location.coordinates)) return false;
    } else if (k === 'preferences.hideFromMap') {
      const val = doc.preferences ? doc.preferences.hideFromMap : undefined;
      if (v && typeof v === 'object' && '$ne' in v) { if (val === v.$ne) return false; }
      else if (val !== v) return false;
    } else if (k === '_id') {
      if (v && typeof v === 'object' && '$in' in v) { if (!v.$in.map(String).includes(String(doc._id))) return false; }
      else if (String(doc._id) !== String(v)) return false;
    } else if (v && typeof v === 'object' && '$ne' in v) {
      if (doc[k] === v.$ne) return false;
    } else if (v && typeof v === 'object' && '$in' in v) {
      if (!v.$in.map(String).includes(String(doc[k]))) return false;
    } else if (doc[k] !== v) {
      return false;
    }
  }
  return true;
}

const chain = (result) => {
  const c = {
    select: () => c, limit: () => c, sort: () => c,
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
});

jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));
jest.mock('../src/models/UserSubscription', () => ({
  find: jest.fn(() => chain([])),
  findOne: jest.fn(() => chain(null)),
}));
jest.mock('../src/models/Friendship', () => ({
  find: jest.fn((q) => {
    // Une seule amitié acceptée : friend1 ↔ me1.
    // Amitié nouée par le profil PROPRIÉTAIRE de Daniel avec le profil
    // PROPRIÉTAIRE de john.
    const rows = [{ requesterId: 'dan_owner', addresseeId: 'john_owner', status: 'accepted' }];
    const ids = new Set();
    for (const c of (q.$or || [])) {
      for (const v of Object.values(c)) for (const x of (v.$in || [])) ids.add(String(x));
    }
    return chain(rows.filter((r) => ids.has(String(r.requesterId)) || ids.has(String(r.addresseeId))));
  }),
}));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
}));
// Personne = e-mail (comme personScope) : tous les ids de rôle d'un même e-mail.
const allDocs = () => [...DOCS.Owner, ...DOCS.Sitter, ...DOCS.Walker];
const groupOf = (id) => {
  const d = allDocs().find((x) => String(x._id) === String(id));
  if (!d) return [String(id)];
  return allDocs().filter((x) => x.email === d.email).map((x) => String(x._id));
};
jest.mock('../src/utils/personScope', () => ({
  personIds: jest.fn((id) => Promise.resolve(groupOf(id))),
  personIndex: jest.fn((ids) => Promise.resolve(new Map(ids.map((i) => [String(i), { ids: groupOf(i) }])))),
}));

const router = require('../src/routes/friendRoutes');

function handler(path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path);
  if (!layer) throw new Error(`route ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}

function call(fn, user, query = {}) {
  return new Promise((resolve, reject) => {
    const req = { user, query, headers: {} };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(body) { resolve({ status: this.statusCode, body }); },
    };
    fn(req, res).catch(reject);
  });
}


const kmBetween = (a, b) => {
  const dy = (a[1] - b[1]) * 111.32;
  const dx = (a[0] - b[0]) * 111.32 * Math.cos((a[1] * Math.PI) / 180);
  return Math.hypot(dx, dy);
};
const world = () => handler('/members/world');
const nearby = () => handler('/members/nearby');
const Q = { lat: String(MURCIE[1]), lng: String(MURCIE[0]), radiusInMeters: '50000' };

describe('règle pure pickPersonPosition', () => {
  test('profil inscrit à Murcie + ancien partage à Valence expiré → Murcie', () => {
    const r = P.pickPersonPosition([{ d: DOCS.Owner[1], role: 'owner' }]);
    expect(r.source).toBe('home');
    expect(r.coordinates).toEqual(MURCIE);
  });
  test('deux profils, deux villes : la position de PROFIL la plus récente gagne, jamais le 1er rôle lu', () => {
    const owner = { d: { _id: 'o', updatedAt: DAYS(1), location: { coordinates: VALENCE, updatedAt: DAYS(1) } }, role: 'owner' };
    const sitter = { d: { _id: 's', updatedAt: DAYS(3), location: { coordinates: MURCIE } }, role: 'sitter' };
    const r = P.pickPersonPosition([owner, sitter]);
    expect(r.entry.role).toBe('sitter');
    expect(r.coordinates).toEqual(MURCIE);
  });
  test('un partage en direct ACTIF (30 s) prime sur tout', () => {
    const live = { d: { _id: 'l', location: { coordinates: VALENCE, updatedAt: new Date(Date.now() - 30000), liveShareActive: true }, homeLocation: { coordinates: MURCIE, at: DAYS(1) } }, role: 'walker' };
    const r = P.pickPersonPosition([live]);
    expect(r.source).toBe('live');
    expect(r.coordinates).toEqual(VALENCE);
  });
  test('aucune position de profil : centre de la ville du profil', () => {
    const gps = { d: { _id: 'g', city: 'Murcie', location: { coordinates: VALENCE, updatedAt: DAYS(5) } }, role: 'owner' };
    const r = P.pickPersonPosition([gps], { cityAnchor: (c) => (c === 'Murcie' ? { lat: MURCIE[1], lng: MURCIE[0] } : null) });
    expect(r.source).toBe('city');
    expect(r.coordinates).toEqual(MURCIE);
  });
  test('displayLocationOf (listes / fiches publiques) : profil hors direct', () => {
    expect(P.displayLocationOf(DOCS.Owner[1]).coordinates).toEqual(MURCIE);
  });
});

describe('floutage tiré vers le centre-ville (« il est dans l\'eau »)', () => {
  test('un membre sur la côte glisse vers le centre, jamais plus loin que la grille seule', () => {
    const coast = { lat: -35.03, lng: -30.06 }; // ~6 km du centre
    const center = { lat: -35.0, lng: -30.0 };
    const plain = blurLngLat(coast.lat, coast.lng, 'x');
    const anch = blurTowardAnchor(coast.lat, coast.lng, 'x', center);
    const c = [center.lng, center.lat];
    expect(kmBetween(anch, c)).toBeLessThan(kmBetween(plain, c));
    // Toujours flouté (jamais la position exacte) et à moins de 1,5 km d'elle.
    expect(anch).not.toEqual([coast.lng, coast.lat]);
    expect(kmBetween(anch, [coast.lng, coast.lat])).toBeLessThan(1.5);
  });
  test('à moins de 1 km du centre : le centre-ville lui-même', () => {
    const r = blurTowardAnchor(-35.004, -30.003, 'x', { lat: -35.0, lng: -30.0 });
    expect(kmBetween(r, [-30.0, -35.0])).toBeLessThan(0.1);
  });
});

describe('couche monde et proches : john C vu par Daniel', () => {
  test('bug 2+3+7 — Daniel en PROMENEUR : un seul point pour john, ami, à Murcie, avec ses 2 rôles', async () => {
    const r = await call(world(), { id: 'dan_walker', role: 'walker' });
    expect(r.status).toBe(200);
    const johns = r.body.members.filter((m) => (m.personIds || [m.id]).some((x) => x.startsWith('john')));
    expect(johns).toHaveLength(1);
    const j = johns[0];
    expect(j.isFriend).toBe(true);
    expect(j.roles.map((x) => x.role).sort()).toEqual(['owner', 'sitter']);
    expect(kmBetween(j.location.coordinates, MURCIE)).toBeLessThan(2);
    expect(kmBetween(j.location.coordinates, VALENCE)).toBeGreaterThan(100);
  });
  test('bug 2 — même réponse vue en GARDIEN et en PROPRIÉTAIRE', async () => {
    for (const viewer of [{ id: 'dan_sitter', role: 'sitter' }, { id: 'dan_owner', role: 'owner' }]) {
      const r = await call(world(), viewer);
      const j = r.body.members.find((m) => (m.personIds || []).includes('john_owner'));
      expect(j && j.isFriend).toBe(true);
    }
  });
  test('proches : un seul point pour john (abonné par son profil gardien), ami, à Murcie', async () => {
    const r = await call(nearby(), { id: 'dan_walker', role: 'walker' }, Q);
    expect(r.status).toBe(200);
    const johns = r.body.members.filter((m) => (m.personIds || []).includes('john_owner'));
    expect(johns).toHaveLength(1);
    expect(johns[0].isFriend).toBe(true);
    expect(johns[0].roles).toHaveLength(2);
    expect(kmBetween(johns[0].location.coordinates, MURCIE)).toBeLessThan(2);
    // Daniel ne se voit pas lui-même (ses 3 profils).
    expect(r.body.members.some((m) => String(m.id).startsWith('dan'))).toBe(false);
  });
  test('homeLocation (position exacte de profil) ne sort jamais', async () => {
    const r = await call(world(), { id: 'dan_walker', role: 'walker' });
    expect(JSON.stringify(r.body)).not.toMatch(/homeLocation/);
  });
});
