// v576 — « les amis ne sont pas synchronisés dans les rôles », « les PawSpot,
// PawFollow doivent être synchro, mes listes également », « PawPoints aussi
// synchronisés sur les 3 rôles » (Daniel, 21/09/2026).
//
// Une personne = jusqu'à 3 documents (Owner / Sitter / Walker) reliés par
// l'e-mail (et `oldId`). Ce que ces tests VERROUILLENT, sans réseau ni base :
//   • un ami ajouté sous un rôle est visible depuis les deux autres ;
//   • une seule entrée par HUMAIN (jamais une par rôle) ;
//   • impossible d'être ami avec son propre profil frère ;
//   • une demande reçue sur un profil est acceptable depuis un autre ;
//   • un blocage vaut pour la personne entière (liste, déblocage, barrage) ;
//   • spots, likes, validations, visites vus et jugés sur les 3 profils ;
//   • PawFollow (abonnement + famille) reconnu quel que soit le profil actif ;
//   • les PawPoints sont ceux de la personne (union par le maximum) ;
//   • aucune écriture inattendue pendant les lectures.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

// ── Magasin en mémoire (même principe que pawSpotRewards.test.js) ──────────
const mockStores = {
  Owner: [], Sitter: [], Walker: [],
  Friendship: [], Block: [], PawSpot: [], UserSubscription: [],
};
const mockSeq = { n: 1 };

// Traverse aussi les tableaux (`familyMembers.userId` → liste des userId),
// comme le fait Mongo sur un chemin pointé.
const mockGet = (doc, path) => path.split('.').reduce((o, k) => {
  if (o == null) return o;
  if (Array.isArray(o)) return o.map((x) => (x == null ? x : x[k]));
  return o[k];
}, doc);

const mockMatches = (doc, filter) => {
  if (!filter) return true;
  return Object.entries(filter).every(([k, v]) => {
    if (k === '$or') return v.some((f) => mockMatches(doc, f));
    if (k === '$and') return v.every((f) => mockMatches(doc, f));
    const cur = mockGet(doc, k);
    if (v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date)) {
      if ('$in' in v) {
        if (Array.isArray(cur)) {
          return cur.some((c) => v.$in.some((x) => String(x) === String(c)));
        }
        return v.$in.some((x) => String(x) === String(cur));
      }
      if ('$nin' in v) {
        const list = Array.isArray(cur) ? cur : [cur];
        return !list.some((c) => v.$nin.some((x) => String(x) === String(c)));
      }
      if ('$ne' in v) {
        if (Array.isArray(cur)) return !cur.some((x) => String(x) === String(v.$ne));
        return String(cur) !== String(v.$ne);
      }
      if ('$gt' in v) return cur != null && new Date(cur) > new Date(v.$gt);
      if ('$gte' in v) return Number(cur || 0) >= Number(v.$gte);
      if ('$exists' in v) return (cur !== undefined) === v.$exists;
      if ('$elemMatch' in v) {
        return (Array.isArray(cur) ? cur : []).some((x) => mockMatches(x, v.$elemMatch));
      }
      if ('$near' in v) return true;
      return false;
    }
    if (v === null) return cur === null || cur === undefined;
    if (Array.isArray(cur)) return cur.some((x) => String(x) === String(v));
    return String(cur) === String(v);
  });
};

const mockApplyUpdate = (doc, update) => {
  const u = update || {};
  const set = { ...(u.$set || {}) };
  for (const [k, v] of Object.entries(u)) if (!k.startsWith('$')) set[k] = v;
  for (const [k, v] of Object.entries(set)) doc[k] = v;
  for (const [k, v] of Object.entries(u.$inc || {})) doc[k] = (Number(doc[k]) || 0) + v;
  for (const [k, v] of Object.entries(u.$push || {})) { doc[k] = doc[k] || []; doc[k].push(v); }
  for (const [k, v] of Object.entries(u.$addToSet || {})) {
    doc[k] = doc[k] || [];
    if (!doc[k].some((x) => String(x) === String(v))) doc[k].push(v);
  }
  for (const [k, v] of Object.entries(u.$pull || {})) {
    if (v && typeof v === 'object' && Array.isArray(v.$in)) {
      doc[k] = (doc[k] || []).filter((x) => !v.$in.some((y) => String(y) === String(x)));
    } else {
      doc[k] = (doc[k] || []).filter((x) => String(x) !== String(v));
    }
  }
};

const mockChain = (result) => ({
  select: () => mockChain(result),
  sort: () => mockChain(result),
  limit: () => mockChain(result),
  populate: () => mockChain(result),
  lean: async () => (Array.isArray(result)
    ? result.map((d) => ({ ...d }))
    : (result ? { ...result } : result)),
  catch: () => mockChain(result),
  then: (res, rej) => Promise.resolve(result).then(res, rej),
});

const mockMakeDoc = (name, data) => {
  const doc = {
    createdAt: new Date(),
    updatedAt: new Date(),
    ...data,
    _id: data._id || `${name.toLowerCase()}_${mockSeq.n++}`,
  };
  Object.defineProperty(doc, 'save', {
    enumerable: false,
    value: async function save() {
      if (!mockStores[name].includes(this)) mockStores[name].push(this);
      return this;
    },
  });
  Object.defineProperty(doc, 'deleteOne', {
    enumerable: false,
    value: async function del() {
      const i = mockStores[name].indexOf(this);
      if (i >= 0) mockStores[name].splice(i, 1);
      return { deletedCount: 1 };
    },
  });
  return doc;
};

const mockFakeModel = (name) => {
  const store = mockStores[name];
  function Model(data) {
    return mockMakeDoc(name, data || {});
  }
  Object.assign(Model, {
    modelName: name,
    create: jest.fn(async (data) => {
      const d = mockMakeDoc(name, data);
      store.push(d);
      return d;
    }),
    findOne: jest.fn((f) => mockChain(store.find((d) => mockMatches(d, f)) || null)),
    findOneAndDelete: jest.fn(async (f) => {
      const i = store.findIndex((d) => mockMatches(d, f));
      if (i < 0) return null;
      return store.splice(i, 1)[0];
    }),
    find: jest.fn((f) => mockChain(store.filter((d) => mockMatches(d, f)))),
    findById: jest.fn((id) => mockChain(store.find((d) => String(d._id) === String(id)) || null)),
    findByIdAndDelete: jest.fn(async (id) => {
      const i = store.findIndex((d) => String(d._id) === String(id));
      return i >= 0 ? store.splice(i, 1)[0] : null;
    }),
    countDocuments: jest.fn(async (f) => store.filter((d) => mockMatches(d, f)).length),
    exists: jest.fn(async (f) => !!store.find((d) => mockMatches(d, f))),
    updateOne: jest.fn(async (f, u) => {
      const d = store.find((x) => mockMatches(x, f));
      if (d) mockApplyUpdate(d, Array.isArray(u) ? {} : u);
      return { modifiedCount: d ? 1 : 0 };
    }),
    updateMany: jest.fn(async (f, u) => {
      const ds = store.filter((x) => mockMatches(x, f));
      ds.forEach((d) => mockApplyUpdate(d, u));
      return { modifiedCount: ds.length };
    }),
    deleteMany: jest.fn(async (f) => {
      const keep = store.filter((d) => !mockMatches(d, f));
      const n = store.length - keep.length;
      store.length = 0;
      store.push(...keep);
      return { deletedCount: n };
    }),
    findOneAndUpdate: jest.fn((f, u, opts = {}) => {
      let d = store.find((x) => mockMatches(x, f));
      if (!d && opts.upsert) {
        d = mockMakeDoc(name, {});
        store.push(d);
      }
      if (!d) return mockChain(null);
      const before = { ...d };
      mockApplyUpdate(d, u);
      return mockChain(opts.new === false ? before : d);
    }),
    findByIdAndUpdate: jest.fn((id, u, opts = {}) => {
      const d = store.find((x) => String(x._id) === String(id));
      if (!d) return mockChain(null);
      mockApplyUpdate(d, u);
      return mockChain(opts.new === false ? { ...d } : d);
    }),
  });
  return Model;
};

jest.mock('../src/models/Owner', () => mockFakeModel('Owner'));
jest.mock('../src/models/Sitter', () => mockFakeModel('Sitter'));
jest.mock('../src/models/Walker', () => mockFakeModel('Walker'));
jest.mock('../src/models/Block', () => mockFakeModel('Block'));
jest.mock('../src/models/Friendship', () => mockFakeModel('Friendship'));
jest.mock('../src/models/Pet', () => mockFakeModel('Pet'));
jest.mock('../src/models/PawSpot', () => {
  const M = mockFakeModel('PawSpot');
  M.PAWSPOT_TYPES = ['path_walk', 'chill', 'playground', 'swimming', 'food_cafe', 'other'];
  const raw = M.create;
  M.create = jest.fn(async (data) => raw({
    hidden: false, deletedAt: null,
    likedBy: [], likesCount: 0,
    validatedBy: [], validationsCount: 0,
    visitedBy: [], visitsCount: 0,
    comments: [], commentAwardedBy: [],
    communityValidated: false, validationAwarded: false, popularAwarded: false,
    pointsAwarded: 0, featuredUntil: null,
    ...data,
  }));
  return M;
});

// UserSubscription : le vrai module exporte le modèle + des helpers. On garde
// les helpers RÉELS (c'est eux qu'on teste pour PawFollow / famille) et on
// remplace seulement la couche Mongoose par le magasin mémoire.
jest.mock('../src/models/UserSubscription', () => {
  const M = mockFakeModel('UserSubscription');
  const now = () => new Date();
  M.familyActiveMatch = (d = now()) => ({ familyExpiry: { $gt: d } });
  M.familyExpiryOf = (s) => s?.familyExpiry || null;
  M.migrateLegacyFamily = () => {};
  M.hasActivePawFollow = async (userId) => {
    const { personIds } = require('../src/utils/personScope');
    const ids = (await personIds(userId)).map(String);
    const store = mockStores.UserSubscription;
    if (store.some((s) => ids.includes(String(s.userId))
      && ((s.currentPeriodEnd && new Date(s.currentPeriodEnd) > now())
        || (s.familyExpiry && new Date(s.familyExpiry) > now())))) return true;
    return store.some((s) => s.familyExpiry && new Date(s.familyExpiry) > now()
      && (s.familyMembers || []).some((m) => ids.includes(String(m.userId))
        && (!m.status || m.status === 'active')));
  };
  M.isInSameFamily = async (a, b) => {
    const { personIds } = require('../src/utils/personScope');
    const [ga, gb] = await Promise.all([personIds(a), personIds(b)]);
    const A = ga.map(String); const B = gb.map(String);
    if (A.some((x) => B.includes(x))) return true;
    return mockStores.UserSubscription.some((s) => {
      if (!(s.familyExpiry && new Date(s.familyExpiry) > now())) return false;
      const ids = [String(s.userId), ...(s.familyMembers || [])
        .filter((m) => !m.status || m.status === 'active').map((m) => String(m.userId))];
      return ids.some((x) => A.includes(x)) && ids.some((x) => B.includes(x));
    });
  };
  return M;
});

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(),
  buildPresenceIndex: jest.fn(async () => ({})),
  isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/sockets/mapSocket', () => ({
  relayLivePosition: jest.fn(async () => 0),
  getLiveSession: jest.fn(() => null),
  getLiveSessionForIds: jest.fn(() => null),
  describeLiveSession: jest.fn(() => null),
  LIVE_STALE_MS: 180000,
}));
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async () => {}),
}));
jest.mock('../src/utils/emailLinkBuilder', () => ({
  buildEmailLink: () => 'https://www.hopetsit.com',
  buildAppRoute: () => '/notifications',
}));
jest.mock('../src/services/airwallexService', () => ({}));
jest.mock('../src/services/pricingService', () => ({ get: () => null }));
jest.mock('../src/services/textModerationService', () => ({
  moderateText: (t) => ({ clean: t }),
}));
jest.mock('../src/utils/sanitize', () => ({
  sanitizeDoc: (d) => ({ ...d }),
  sanitizeUser: (u) => ({ ...(u || {}) }),
}));

const currentUser = { id: null, role: 'owner' };
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, _res, next) => { req.user = { ...currentUser }; next(); },
  optionalAuth: (req, _res, next) => { req.user = { ...currentUser }; next(); },
  requireRole: () => (req, _res, next) => next(),
}));

const express = require('express');
const request = require('supertest');

const Owner = require('../src/models/Owner');
const Sitter = require('../src/models/Sitter');
const Walker = require('../src/models/Walker');
const Friendship = require('../src/models/Friendship');
const Block = require('../src/models/Block');
const PawSpot = require('../src/models/PawSpot');
const UserSubscription = require('../src/models/UserSubscription');

const friendRoutes = require('../src/routes/friendRoutes');
const pawSpotRoutes = require('../src/routes/pawSpotRoutes');
const blockController = require('../src/controllers/blockController');
const blockService = require('../src/services/blockService');
const { personIndex, resetPersonCache } = require('../src/utils/personScope');
const { identityGroup } = require('../src/utils/identityGroup');

const app = express();
app.use(express.json());
app.use('/friends', friendRoutes);
app.use('/pawspots', pawSpotRoutes);
const { requireAuth } = require('../src/middleware/auth');
app.get('/blocks', requireAuth, blockController.listBlocked);
app.post('/blocks', requireAuth, blockController.blockUser);
app.delete('/blocks/:id', requireAuth, blockController.unblockUser);

// ── Jeu de données : 2 personnes à 3 profils, 1 personne à 1 profil ────────
//   DANIEL  : owner_d / sitter_d / walker_d   (daniel@test)
//   LEA     : owner_l / sitter_l / walker_l   (lea@test)
//   MARC    : owner_m                          (marc@test)
// Identifiants au format ObjectId (24 caractères hexadécimaux) : le
// contrôleur de blocage valide `mongoose.Types.ObjectId.isValid`.
const ID = {
  ownerD: '000000000000000000000d01',
  sitterD: '000000000000000000000d02',
  walkerD: '000000000000000000000d03',
  ownerL: '000000000000000000000e01',
  sitterL: '000000000000000000000e02',
  walkerL: '000000000000000000000e03',
  ownerM: '000000000000000000000f01',
};

const asUser = (id, role) => { currentUser.id = id; currentUser.role = role; };

const seed = () => {
  for (const k of Object.keys(mockStores)) mockStores[k].length = 0;
  resetPersonCache();
  const push = (store, docs) => docs.forEach((d) => store.push(mockMakeDoc(store === mockStores.Owner ? 'Owner' : 'X', d)));
  mockStores.Owner.push(
    mockMakeDoc('Owner', { _id: ID.ownerD, email: 'daniel@test', name: 'Daniel', firstName: 'Daniel', pawPoints: 40, pawPointsSpendable: 40 }),
    mockMakeDoc('Owner', { _id: ID.ownerL, email: 'lea@test', name: 'Lea', firstName: 'Lea', lastSeenAt: new Date('2026-09-01') }),
    mockMakeDoc('Owner', { _id: ID.ownerM, email: 'marc@test', name: 'Marc', firstName: 'Marc' }),
  );
  mockStores.Sitter.push(
    mockMakeDoc('Sitter', { _id: ID.sitterD, email: 'daniel@test', name: 'Daniel', firstName: 'Daniel', pawPoints: 0, pawPointsSpendable: 0 }),
    mockMakeDoc('Sitter', { _id: ID.sitterL, email: 'lea@test', name: 'Lea', firstName: 'Lea', lastSeenAt: new Date('2026-09-20') }),
  );
  mockStores.Walker.push(
    mockMakeDoc('Walker', { _id: ID.walkerD, email: 'daniel@test', name: 'Daniel', firstName: 'Daniel', pawPoints: 0, pawPointsSpendable: 0 }),
    mockMakeDoc('Walker', { _id: ID.walkerL, email: 'lea@test', name: 'Lea', firstName: 'Lea', lastSeenAt: new Date('2026-09-10') }),
  );
  void push;
};

const addFriendship = (a, aModel, b, bModel, status = 'accepted') => {
  const f = mockMakeDoc('Friendship', {
    requesterId: a, requesterModel: aModel,
    addresseeId: b, addresseeModel: bModel,
    status,
    acceptedAt: status === 'accepted' ? new Date() : null,
    requesterSharesPosition: true, addresseeSharesPosition: true,
  });
  mockStores.Friendship.push(f);
  return f;
};

const snapshot = () => JSON.stringify({
  friendships: mockStores.Friendship,
  spots: mockStores.PawSpot,
  blocks: mockStores.Block,
});

beforeEach(seed);

// ════════════════════════════════════════════════════════════════════════════
describe('personScope — le groupe d’identité, en lot', () => {
  test('les 3 profils d’une personne forment un seul groupe', async () => {
    const idx = await personIndex([ID.ownerD, ID.ownerM]);
    const daniel = idx.get(ID.ownerD);
    expect([...daniel.ids].sort()).toEqual([ID.ownerD, ID.sitterD, ID.walkerD]);
    expect(daniel.roles.sort()).toEqual(['owner', 'sitter', 'walker']);
    // Marc n’a qu’un profil et n’est pas mélangé avec Daniel.
    expect(idx.get(ID.ownerM).ids).toEqual([ID.ownerM]);
    expect(idx.get(ID.ownerM).key).not.toBe(daniel.key);
  });

  test('le rôle « actif » affiché est le profil vu le plus récemment', async () => {
    const idx = await personIndex([ID.ownerL]);
    expect(idx.get(ID.ownerL).activeRole).toBe('sitter'); // lastSeenAt 20/09
  });

  test('un identifiant inconnu reste une personne à lui seul', async () => {
    const idx = await personIndex(['fantome']);
    expect(idx.get('fantome').ids).toEqual(['fantome']);
  });
});

// ════════════════════════════════════════════════════════════════════════════
describe('amis — une amitié appartient à la personne', () => {
  test('ami ajouté en propriétaire → visible depuis gardien ET promeneur', async () => {
    addFriendship(ID.ownerD, 'Owner', ID.ownerL, 'Owner');
    for (const [id, role] of [[ID.ownerD, 'owner'], [ID.sitterD, 'sitter'], [ID.walkerD, 'walker']]) {
      asUser(id, role);
      const r = await request(app).get('/friends');
      expect(r.status).toBe(200);
      expect(r.body.friends).toHaveLength(1);
      expect(r.body.friends[0].other.name).toBe('Lea');
    }
  });

  test('ami dont le profil a changé de rôle → toujours UNE seule entrée', async () => {
    // Daniel (propriétaire) ↔ Léa (gardienne) ET Daniel (promeneur) ↔ Léa
    // (propriétaire) : deux amitiés, un seul humain en face.
    addFriendship(ID.ownerD, 'Owner', ID.sitterL, 'Sitter');
    addFriendship(ID.ownerL, 'Owner', ID.walkerD, 'Walker');
    asUser(ID.sitterD, 'sitter');
    const r = await request(app).get('/friends');
    expect(r.body.friends).toHaveLength(1);
    expect(r.body.friends[0].other.roles.sort()).toEqual(['owner', 'sitter', 'walker']);
    expect(r.body.friends[0].other.activeRole).toBe('sitter');
  });

  test('impossible d’être ami avec son propre profil frère', async () => {
    asUser(ID.ownerD, 'owner');
    const r = await request(app)
      .post('/friends/request')
      .send({ targetId: ID.walkerD, targetRole: 'walker' });
    expect(r.status).toBe(400);
    expect(mockStores.Friendship).toHaveLength(0);
  });

  test('une amitié résiduelle entre mes propres profils n’apparaît jamais', async () => {
    addFriendship(ID.ownerD, 'Owner', ID.sitterD, 'Sitter');
    asUser(ID.ownerD, 'owner');
    const r = await request(app).get('/friends');
    expect(r.body.friends).toHaveLength(0);
  });

  test('demande reçue sur le profil gardien → acceptable depuis le propriétaire', async () => {
    const f = addFriendship(ID.ownerL, 'Owner', ID.sitterD, 'Sitter', 'pending');
    asUser(ID.ownerD, 'owner');
    const list = await request(app).get('/friends/requests');
    expect(list.body.incoming).toHaveLength(1);
    const acc = await request(app).post(`/friends/${f._id}/accept`);
    expect(acc.status).toBe(200);
    expect(f.status).toBe('accepted');
    // … et l’ami apparaît depuis le troisième profil.
    asUser(ID.walkerD, 'walker');
    const r = await request(app).get('/friends');
    expect(r.body.friends).toHaveLength(1);
  });

  test('deux demandes vers deux profils du même humain → une seule ligne', async () => {
    addFriendship(ID.ownerD, 'Owner', ID.ownerL, 'Owner', 'pending');
    addFriendship(ID.sitterD, 'Sitter', ID.walkerL, 'Walker', 'pending');
    asUser(ID.walkerD, 'walker');
    const r = await request(app).get('/friends/requests');
    expect(r.body.outgoing).toHaveLength(1);
    expect(r.body.incoming).toHaveLength(0);
  });

  test('retirer un ami marche depuis n’importe lequel de mes profils', async () => {
    const f = addFriendship(ID.sitterL, 'Sitter', ID.ownerD, 'Owner');
    asUser(ID.walkerD, 'walker');
    const r = await request(app).delete(`/friends/${f._id}`);
    expect(r.status).toBe(200);
    expect(mockStores.Friendship).toHaveLength(0);
  });

  test('positions live : une entrée par personne, pas une par rôle', async () => {
    addFriendship(ID.ownerD, 'Owner', ID.ownerL, 'Owner');
    addFriendship(ID.sitterD, 'Sitter', ID.sitterL, 'Sitter');
    mockStores.Owner.find((d) => d._id === ID.ownerL).location = {
      coordinates: [2.35, 48.85], city: 'Paris',
      updatedAt: new Date(), liveShareActive: true,
    };
    asUser(ID.walkerD, 'walker');
    const r = await request(app).get('/friends/live-positions');
    expect(r.status).toBe(200);
    expect(r.body.positions).toHaveLength(1);
    expect(r.body.positions[0].lat).toBeCloseTo(48.85);
  });

  test('lire la liste n’écrit rien', async () => {
    addFriendship(ID.ownerD, 'Owner', ID.sitterL, 'Sitter');
    const before = snapshot();
    asUser(ID.sitterD, 'sitter');
    await request(app).get('/friends');
    await request(app).get('/friends/requests');
    await request(app).get('/friends/live-positions');
    expect(snapshot()).toBe(before);
  });
});

// ════════════════════════════════════════════════════════════════════════════
describe('blocages — valables pour la personne entière', () => {
  test('bloqué depuis le propriétaire → listé depuis le promeneur', async () => {
    asUser(ID.ownerD, 'owner');
    const b = await request(app).post('/blocks')
      .send({ targetUserId: ID.sitterL, targetRole: 'sitter' });
    expect(b.status).toBe(201);
    asUser(ID.walkerD, 'walker');
    const list = await request(app).get('/blocks');
    expect(list.body.blocks).toHaveLength(1);
  });

  test('déblocage depuis un autre profil, quel que soit le rôle de la cible', async () => {
    asUser(ID.ownerD, 'owner');
    await request(app).post('/blocks')
      .send({ targetUserId: ID.sitterL, targetRole: 'sitter' });
    asUser(ID.sitterD, 'sitter');
    // On débloque en visant un AUTRE profil de la même personne.
    const r = await request(app).delete(`/blocks/${ID.ownerL}`);
    expect(r.status).toBe(200);
    expect(mockStores.Block).toHaveLength(0);
  });

  test('bloquer deux fois la même personne ne crée pas de doublon', async () => {
    asUser(ID.ownerD, 'owner');
    await request(app).post('/blocks').send({ targetUserId: ID.ownerL, targetRole: 'owner' });
    asUser(ID.walkerD, 'walker');
    await request(app).post('/blocks').send({ targetUserId: ID.walkerL, targetRole: 'walker' });
    expect(mockStores.Block).toHaveLength(1);
    const list = await request(app).get('/blocks');
    expect(list.body.blocks).toHaveLength(1);
  });

  test('on ne peut pas se bloquer soi-même via un profil frère', async () => {
    asUser(ID.ownerD, 'owner');
    const r = await request(app).post('/blocks')
      .send({ targetUserId: ID.walkerD, targetRole: 'walker' });
    expect(r.status).toBe(400);
  });

  test('le barrage tient quand les deux changent de profil', async () => {
    asUser(ID.ownerD, 'owner');
    await request(app).post('/blocks').send({ targetUserId: ID.ownerL, targetRole: 'owner' });
    // Daniel en promeneur face à Léa en gardienne : toujours bloqué.
    await expect(blockService.isOwnerSitterInteractionBlocked(ID.walkerD, ID.sitterL))
      .resolves.toBeTruthy();
  });
});

// ════════════════════════════════════════════════════════════════════════════
describe('PawSpot — les spots appartiennent à la personne', () => {
  const makeSpot = (creatorId, creatorModel = 'Owner') => PawSpot.create({
    type: 'chill', name: 'Parc', creatorId, creatorModel,
    creatorName: 'Daniel',
    location: { type: 'Point', coordinates: [2.35, 48.85], city: 'Paris' },
  });

  test('« mon spot » reste le mien depuis les 3 profils', async () => {
    const spot = await makeSpot(ID.ownerD);
    for (const [id, role] of [[ID.ownerD, 'owner'], [ID.sitterD, 'sitter'], [ID.walkerD, 'walker']]) {
      asUser(id, role);
      const r = await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
      const found = r.body.spots.find((s) => s.id === String(spot._id));
      expect(found.isMine).toBe(true);
    }
  });

  test('aimer son propre spot est refusé depuis un profil frère', async () => {
    const spot = await makeSpot(ID.ownerD);
    asUser(ID.walkerD, 'walker');
    const r = await request(app).post(`/pawspots/${spot._id}/like`);
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('SELF_LIKE');
  });

  test('un ❤️ posé en propriétaire se retire depuis le promeneur', async () => {
    const spot = await makeSpot(ID.ownerL);
    asUser(ID.ownerD, 'owner');
    const a = await request(app).post(`/pawspots/${spot._id}/like`);
    expect(a.body).toMatchObject({ liked: true, likesCount: 1 });
    asUser(ID.walkerD, 'walker');
    const b = await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
    expect(b.body.spots[0].likedByMe).toBe(true);
    const c = await request(app).post(`/pawspots/${spot._id}/like`);
    expect(c.body).toMatchObject({ liked: false, likesCount: 0 });
  });

  test('valider deux fois sous deux profils ne compte qu’une fois', async () => {
    const spot = await makeSpot(ID.ownerL);
    asUser(ID.ownerD, 'owner');
    await request(app).post(`/pawspots/${spot._id}/validate`);
    asUser(ID.sitterD, 'sitter');
    const again = await request(app).post(`/pawspots/${spot._id}/validate`);
    expect(again.body.already).toBe(true);
    expect(again.body.validationsCount).toBe(1);
  });

  test('une visite par personne, pas une par rôle', async () => {
    const spot = await makeSpot(ID.ownerL);
    asUser(ID.ownerD, 'owner');
    expect((await request(app).post(`/pawspots/${spot._id}/visit`)).body.visitsCount).toBe(1);
    asUser(ID.walkerD, 'walker');
    const b = await request(app).post(`/pawspots/${spot._id}/visit`);
    expect(b.body).toMatchObject({ visitsCount: 1, already: true });
  });

  test('je peux supprimer mon spot depuis un autre profil', async () => {
    const spot = await makeSpot(ID.ownerD);
    asUser(ID.sitterD, 'sitter');
    const r = await request(app).delete(`/pawspots/${spot._id}`);
    expect(r.status).toBe(200);
    expect(r.body.deleted).toBe(true);
  });

  test('le quota gratuit et le compteur comptent les 3 profils', async () => {
    await makeSpot(ID.ownerD);
    await makeSpot(ID.sitterD, 'Sitter');
    asUser(ID.walkerD, 'walker');
    const r = await request(app).get('/pawspots/me/points');
    expect(r.status).toBe(200);
    expect(r.body.mySpotsCount).toBe(2);
  });

  test('lire les spots n’écrit rien', async () => {
    await makeSpot(ID.ownerD);
    const before = snapshot();
    asUser(ID.walkerD, 'walker');
    await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
    await request(app).get('/pawspots/me/points');
    expect(snapshot()).toBe(before);
  });
});

// ════════════════════════════════════════════════════════════════════════════
describe('PawFollow — abonnement et famille reconnus sur les 3 profils', () => {
  test('abonnement acheté en propriétaire → actif depuis le promeneur', async () => {
    mockStores.UserSubscription.push(mockMakeDoc('UserSubscription', {
      userId: ID.ownerD, userModel: 'Owner',
      currentPeriodEnd: new Date(Date.now() + 86400000),
    }));
    await expect(UserSubscription.hasActivePawFollow(ID.walkerD)).resolves.toBe(true);
    await expect(UserSubscription.hasActivePawFollow(ID.ownerM)).resolves.toBe(false);
  });

  test('invitation famille reçue sur le profil gardien → visible en propriétaire', async () => {
    mockStores.UserSubscription.push(mockMakeDoc('UserSubscription', {
      userId: ID.ownerL, userModel: 'Owner',
      familyExpiry: new Date(Date.now() + 86400000),
      familyMembers: [{
        _id: 'inv1', userId: ID.sitterD, userModel: 'Sitter', status: 'pending',
        addedAt: new Date(),
      }],
    }));
    asUser(ID.ownerD, 'owner');
    const r = await request(app).get('/friends/family/invitations');
    expect(r.status).toBe(200);
    expect(r.body.invitations).toHaveLength(1);
    expect(r.body.invitations[0].familyOwnerId).toBe(ID.ownerL);
  });

  test('famille : membre invité sous un profil, reconnu sous un autre', async () => {
    mockStores.UserSubscription.push(mockMakeDoc('UserSubscription', {
      userId: ID.ownerL, userModel: 'Owner',
      familyExpiry: new Date(Date.now() + 86400000),
      familyMembers: [{ userId: ID.sitterD, userModel: 'Sitter', status: 'active' }],
    }));
    await expect(UserSubscription.isInSameFamily(ID.walkerD, ID.walkerL)).resolves.toBe(true);
    await expect(UserSubscription.isInSameFamily(ID.ownerM, ID.walkerL)).resolves.toBe(false);
  });
});

// ════════════════════════════════════════════════════════════════════════════
describe('PawPoints — le solde est celui de la personne', () => {
  test('les points gagnés sous un rôle sont lus depuis les deux autres', async () => {
    const pawPoints = require('../src/services/pawPointsService');
    // Daniel a 40 points sur son profil propriétaire, 0 sur les autres.
    const st = await pawPoints.getPawState(ID.walkerD, 'walker');
    expect(st.lifetime).toBe(40);
    expect(st.spendable).toBe(40);
    // La lecture aligne les 3 documents sur le maximum : aucun point créé.
    const total = [ID.ownerD, ID.sitterD, ID.walkerD].map((id) => {
      const d = [...mockStores.Owner, ...mockStores.Sitter, ...mockStores.Walker]
        .find((x) => x._id === id);
      return d.pawPoints;
    });
    expect(total).toEqual([40, 40, 40]);
  });

  test('les profils d’une AUTRE personne ne sont pas touchés', async () => {
    const pawPoints = require('../src/services/pawPointsService');
    await pawPoints.getPawState(ID.walkerD, 'walker');
    expect(mockStores.Owner.find((d) => d._id === ID.ownerM).pawPoints).toBeUndefined();
    expect(mockStores.Owner.find((d) => d._id === ID.ownerL).pawPoints).toBeUndefined();
  });
});

// ════════════════════════════════════════════════════════════════════════════
describe('listes / favoris — le profil propriétaire de la personne', () => {
  test('depuis un profil gardien, le groupe expose bien le document Owner', async () => {
    // C’est la condition que `asOwnerProfile` (routes/userRoutes.js) utilise
    // pour servir les favoris — stockés sur Owner.favoriteProviders — aux
    // profils gardien et promeneur, au lieu de répondre 403.
    const g = await identityGroup(ID.sitterD);
    const ownerDoc = g.docs.find((d) => d.model === 'Owner');
    expect(ownerDoc).toBeTruthy();
    expect(ownerDoc.id).toBe(ID.ownerD);
  });

  test('une personne sans profil propriétaire n’en invente pas un', async () => {
    mockStores.Owner.splice(
      mockStores.Owner.findIndex((d) => d._id === ID.ownerD), 1,
    );
    resetPersonCache();
    const g = await identityGroup(ID.sitterD);
    expect(g.docs.find((d) => d.model === 'Owner')).toBeUndefined();
  });
});
