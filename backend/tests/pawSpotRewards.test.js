// v567 — audit PawSpot & récompenses (aucune base réelle : les modèles
// Mongoose sont remplacés par un magasin en mémoire, comme authSignupFlow).
//
// Ce que ces tests VERROUILLENT (bugs mesurés en prod le 19/09) :
//   • créer puis supprimer un spot en boucle ne fabrique plus de PawPoints ;
//   • la limite de 3 tags gratuits compte les CRÉATIONS CUMULÉES (supprimer un
//     spot ne rend pas un tag gratuit) et vaut pour les 3 profils du compte ;
//   • pas de ❤️ ni de validation sur son propre spot ;
//   • +2 « commentaire utile » une seule fois par personne et par spot ;
//   • les paliers (10 ❤️ → validé, 50 ❤️ → populaire) ne créditent qu'une fois ;
//   • « points doublés » Paw Premium appliqués même depuis un autre profil ;
//   • le classement ne montre pas trois fois la même personne ;
//   • /me/points expose bien le solde dépensable et les tags restants.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

// ── Magasin en mémoire ─────────────────────────────────────────────────────
const mockStores = { Owner: [], Sitter: [], Walker: [], PawSpot: [], UserSubscription: [] };
const mockSeq = { n: 1 };

const mockGet = (doc, path) => path.split('.').reduce((o, k) => (o == null ? o : o[k]), doc);

const mockMatches = (doc, filter) => {
  if (!filter) return true;
  return Object.entries(filter).every(([k, v]) => {
    if (k === '$or') return v.some((f) => mockMatches(doc, f));
    const cur = mockGet(doc, k);
    if (v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date)) {
      if ('$in' in v) return v.$in.some((x) => String(x) === String(cur));
      if ('$ne' in v) {
        if (Array.isArray(cur)) return !cur.some((x) => String(x) === String(v.$ne));
        return String(cur) !== String(v.$ne) && !(v.$ne === true && cur === true);
      }
      if ('$gt' in v) return cur != null && new Date(cur) > new Date(v.$gt);
      if ('$gte' in v) return Number(cur || 0) >= Number(v.$gte);
      if ('$exists' in v) return (cur !== undefined) === v.$exists;
      if ('$near' in v) return true; // index géo : hors de portée du magasin mémoire
      return false;
    }
    if (v === null) return cur === null || cur === undefined;
    if (Array.isArray(cur)) return cur.some((x) => String(x) === String(v));
    return String(cur) === String(v);
  });
};

const mockMakeDoc = (name, data) => {
  const doc = {
    createdAt: new Date(),
    ...data,
    _id: data._id || `${name.toLowerCase()}_${mockSeq.n++}`,
  };
  Object.defineProperty(doc, 'save', { enumerable: false, value: async function () { return this; } });
  Object.defineProperty(doc, 'toObject', { enumerable: false, value: function () { return { ...this }; } });
  Object.defineProperty(doc, 'deleteOne', {
    enumerable: false,
    value: async function () {
      const store = mockStores[name];
      const i = store.indexOf(this);
      if (i >= 0) store.splice(i, 1);
      return { deletedCount: 1 };
    },
  });
  return doc;
};

const mockChain = (result) => ({
  select: () => mockChain(result),
  sort: () => mockChain(result),
  limit: () => mockChain(result),
  lean: async () => (Array.isArray(result) ? result.map((d) => ({ ...d })) : result ? { ...result } : result),
  then: (res, rej) => Promise.resolve(result).then(res, rej),
});

const mockApplyUpdate = (doc, update) => {
  const u = update || {};
  const set = { ...(u.$set || {}) };
  for (const [k, v] of Object.entries(u)) if (!k.startsWith('$')) set[k] = v;
  for (const [k, v] of Object.entries(set)) {
    if (k.includes('.')) {
      const parts = k.split('.');
      let o = doc;
      for (const p of parts.slice(0, -1)) { o[p] = o[p] || {}; o = o[p]; }
      o[parts[parts.length - 1]] = v;
    } else doc[k] = v;
  }
  for (const [k, v] of Object.entries(u.$inc || {})) doc[k] = (Number(doc[k]) || 0) + v;
  for (const [k, v] of Object.entries(u.$push || {})) { doc[k] = doc[k] || []; doc[k].push(v); }
  for (const [k, v] of Object.entries(u.$addToSet || {})) {
    doc[k] = doc[k] || [];
    if (!doc[k].some((x) => String(x) === String(v))) doc[k].push(v);
  }
  for (const [k, v] of Object.entries(u.$pull || {})) {
    doc[k] = (doc[k] || []).filter((x) => String(x) !== String(v));
  }
};

const mockFakeModel = (name) => {
  const store = mockStores[name];
  const M = {
    modelName: name,
    create: jest.fn(async (data) => { const d = mockMakeDoc(name, data); store.push(d); return d; }),
    findOne: jest.fn((filter) => mockChain(store.find((d) => mockMatches(d, filter)) || null)),
    find: jest.fn((filter) => mockChain(store.filter((d) => mockMatches(d, filter)))),
    findById: jest.fn((id) => mockChain(store.find((d) => String(d._id) === String(id)) || null)),
    countDocuments: jest.fn(async (filter) => store.filter((d) => mockMatches(d, filter)).length),
    exists: jest.fn(async (filter) => !!store.find((d) => mockMatches(d, filter))),
    updateOne: jest.fn(async (filter, update) => {
      const d = store.find((x) => mockMatches(x, filter));
      if (d) mockApplyUpdate(d, Array.isArray(update) ? {} : update);
      return { modifiedCount: d ? 1 : 0 };
    }),
    updateMany: jest.fn(async (filter, update) => {
      const ds = store.filter((x) => mockMatches(x, filter));
      ds.forEach((d) => mockApplyUpdate(d, update));
      return { modifiedCount: ds.length };
    }),
    findOneAndUpdate: jest.fn((filter, update, opts = {}) => {
      const d = store.find((x) => mockMatches(x, filter));
      if (!d) return mockChain(null);
      const before = { ...d };
      mockApplyUpdate(d, update);
      return mockChain(opts.new === false ? before : d);
    }),
    findByIdAndUpdate: jest.fn((id, update, opts = {}) => {
      const d = store.find((x) => String(x._id) === String(id));
      if (!d) return mockChain(null);
      mockApplyUpdate(d, update);
      return mockChain(opts.new === false ? { ...d } : d);
    }),
    deleteOne: jest.fn(async (filter) => {
      const i = store.findIndex((x) => mockMatches(x, filter));
      if (i >= 0) store.splice(i, 1);
      return { deletedCount: i >= 0 ? 1 : 0 };
    }),
  };
  return M;
};

jest.mock('../src/models/Owner', () => mockFakeModel('Owner'));
jest.mock('../src/models/Sitter', () => mockFakeModel('Sitter'));
jest.mock('../src/models/Walker', () => mockFakeModel('Walker'));
jest.mock('../src/models/UserSubscription', () => mockFakeModel('UserSubscription'));
jest.mock('../src/models/PawSpot', () => {
  const M = mockFakeModel('PawSpot');
  M.PAWSPOT_TYPES = ['path_walk', 'chill', 'playground', 'swimming', 'food_cafe', 'other'];
  // Le magasin mémoire n'applique pas les defaults du schéma Mongoose : on les
  // reproduit ici pour que les filtres (`hidden:false`, `deletedAt:null`) et
  // les tableaux (likedBy…) se comportent comme en base.
  const rawCreate = M.create;
  M.create = jest.fn(async (data) => rawCreate({
    hidden: false,
    deletedAt: null,
    likedBy: [], likesCount: 0,
    validatedBy: [], validationsCount: 0,
    visitedBy: [], visitsCount: 0,
    comments: [], commentAwardedBy: [],
    communityValidated: false,
    validationAwarded: false,
    popularAwarded: false,
    pointsAwarded: 0,
    featuredUntil: null,
    ...data,
  }));
  return M;
});
jest.mock('../src/utils/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../src/services/airwallexService', () => ({}));
jest.mock('../src/services/pricingService', () => ({ get: () => null }));
jest.mock('../src/services/textModerationService', () => ({
  moderateText: (t) => ({ clean: t }),
}));
// Les notifications sont simulées : on vérifie simplement qu'elles partent.
const mockNotifs = [];
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async (p) => { mockNotifs.push(p); }),
}));

// L'authentification est injectée par le test (currentUser).
const currentUser = { id: null, role: 'owner' };
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, _res, next) => { req.user = { ...currentUser }; next(); },
}));

const express = require('express');
const request = require('supertest');
const router = require('../src/routes/pawSpotRoutes');
const Owner = require('../src/models/Owner');
const Sitter = require('../src/models/Sitter');
const PawSpot = require('../src/models/PawSpot');
const UserSubscription = require('../src/models/UserSubscription');

const app = express();
app.use(express.json());
app.use('/pawspots', router);

const reset = () => {
  for (const k of Object.keys(mockStores)) mockStores[k].length = 0;
  mockNotifs.length = 0;
  mockSeq.n = 1;
};

const makeUser = (Model, name, email, extra = {}) =>
  Model.create({ name, email, pawPoints: 0, pawPointsSpendable: 0, ...extra });

const asUser = (doc, role = 'owner') => { currentUser.id = String(doc._id); currentUser.role = role; };

const newSpot = (over = {}) => request(app).post('/pawspots').send({
  type: 'chill', name: 'Parc des chiens', lat: 48.85, lng: 2.35, ...over,
});

const pointsOf = (doc) => Number(doc.pawPoints) || 0;

describe('création : points réellement crédités + tags gratuits', () => {
  beforeEach(reset);

  test('+10 (et +15 avec photo), compteur de tags gratuits renvoyé', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(u);
    const r1 = await newSpot();
    expect(r1.status).toBe(201);
    expect(r1.body.pointsEarned).toBe(10);
    expect(r1.body.freeSpotLimit).toBe(3);
    expect(r1.body.freeSpotsLeft).toBe(2);
    expect(pointsOf(u)).toBe(10);

    const r2 = await newSpot({ photoUrl: 'https://cdn/x.jpg' });
    expect(r2.body.pointsEarned).toBe(15);
    expect(r2.body.freeSpotsLeft).toBe(1);
    expect(pointsOf(u)).toBe(25);
  });

  test('4e tag gratuit → 402 PAWSPOT_REQUIRED (boutique)', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(u);
    await newSpot(); await newSpot(); await newSpot();
    const r = await newSpot();
    expect(r.status).toBe(402);
    expect(r.body.code).toBe('PAWSPOT_REQUIRED');
    expect(r.body.freeSpotsLeft).toBe(0);
  });

  test('abonné PawSpot → illimité, freeSpotsLeft = null', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(u._id), userModel: 'Owner',
      pawspotExpiry: new Date(Date.now() + 30 * 86400000),
    });
    asUser(u);
    for (let i = 0; i < 4; i += 1) {
      const r = await newSpot();
      expect(r.status).toBe(201);
      expect(r.body.freeSpotsLeft).toBeNull();
    }
  });

  test('abonnement acheté en propriétaire → reconnu depuis le profil gardien', async () => {
    const owner = await makeUser(Owner, 'Ana', 'ana@x.io');
    const sitter = await makeUser(Sitter, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(owner._id), userModel: 'Owner',
      pawspotExpiry: new Date(Date.now() + 30 * 86400000),
    });
    asUser(sitter, 'sitter');
    for (let i = 0; i < 5; i += 1) {
      expect((await newSpot()).status).toBe(201);
    }
  });

  test('quota gratuit COMMUN aux 3 profils (pas 3 tags par profil)', async () => {
    const owner = await makeUser(Owner, 'Ana', 'ana@x.io');
    const sitter = await makeUser(Sitter, 'Ana', 'ana@x.io');
    asUser(owner);
    await newSpot(); await newSpot(); await newSpot();
    asUser(sitter, 'sitter');
    const r = await newSpot();
    expect(r.status).toBe(402);
  });

  test('plafond quotidien : au-delà de 10 spots/24 h, plus de points', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(u._id), userModel: 'Owner',
      pawspotExpiry: new Date(Date.now() + 30 * 86400000),
    });
    asUser(u);
    for (let i = 0; i < 10; i += 1) await newSpot();
    expect(pointsOf(u)).toBe(100);
    const r = await newSpot();
    expect(r.status).toBe(201);
    expect(r.body.dailyCapReached).toBe(true);
    expect(r.body.pointsEarned).toBe(0);
    expect(pointsOf(u)).toBe(100);
  });
});

describe('suppression : les points sont repris (ferme à points fermée)', () => {
  beforeEach(reset);

  test('créer 4 spots puis les supprimer laisse 0 point (prod : 80 conservés)', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(u._id), userModel: 'Owner',
      premiumExpiry: new Date(Date.now() + 30 * 86400000), // ×2 Paw Premium
    });
    asUser(u);
    const ids = [];
    for (let i = 0; i < 4; i += 1) {
      const r = await newSpot();
      expect(r.body.pointsEarned).toBe(20); // points doublés Premium
      ids.push(r.body.spot.id);
    }
    expect(pointsOf(u)).toBe(80);
    for (const id of ids) {
      const d = await request(app).delete(`/pawspots/${id}`);
      expect(d.status).toBe(200);
      expect(d.body.pointsRevoked).toBe(20);
    }
    expect(pointsOf(u)).toBe(0);
    expect(Number(u.pawPointsSpendable) || 0).toBe(0);
  });

  test('supprimer ne rend PAS un tag gratuit (créations cumulées)', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(u);
    const first = await newSpot();
    await newSpot();
    await newSpot();
    await request(app).delete(`/pawspots/${first.body.spot.id}`);
    const r = await newSpot();
    expect(r.status).toBe(402);
    expect(r.body.code).toBe('PAWSPOT_REQUIRED');
  });

  test('un spot supprimé disparaît des lectures', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(u);
    const r = await newSpot();
    await request(app).delete(`/pawspots/${r.body.spot.id}`);
    const near = await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
    expect(near.body.spots).toHaveLength(0);
    const pub = await request(app).get(`/pawspots/public/${r.body.spot.id}`);
    expect(pub.status).toBe(404);
    // Deuxième suppression : plus rien à reprendre.
    const again = await request(app).delete(`/pawspots/${r.body.spot.id}`);
    expect(again.status).toBe(404);
    expect(pointsOf(u)).toBe(0);
  });

  test('seul le créateur peut supprimer', async () => {
    const a = await makeUser(Owner, 'Ana', 'ana@x.io');
    const b = await makeUser(Owner, 'Bo', 'bo@x.io');
    asUser(a);
    const r = await newSpot();
    asUser(b);
    const d = await request(app).delete(`/pawspots/${r.body.spot.id}`);
    expect(d.status).toBe(403);
    expect(pointsOf(a)).toBe(10);
  });
});

describe('anti-triche : likes, validations, commentaires', () => {
  beforeEach(reset);

  const seedSpot = async () => {
    const author = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(author);
    const r = await newSpot();
    return { author, id: r.body.spot.id };
  };

  test('pas de ❤️ sur son propre spot', async () => {
    const { id } = await seedSpot();
    const r = await request(app).post(`/pawspots/${id}/like`);
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('SELF_LIKE');
  });

  test('pas de validation de son propre spot', async () => {
    const { id } = await seedSpot();
    const r = await request(app).post(`/pawspots/${id}/validate`);
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('SELF_VALIDATE');
  });

  test('un ❤️ par personne : retaper enlève, retaper remet (jamais 2)', async () => {
    const { id } = await seedSpot();
    const bo = await makeUser(Owner, 'Bo', 'bo@x.io');
    asUser(bo);
    const a = await request(app).post(`/pawspots/${id}/like`);
    expect(a.body).toMatchObject({ liked: true, likesCount: 1 });
    const b = await request(app).post(`/pawspots/${id}/like`);
    expect(b.body).toMatchObject({ liked: false, likesCount: 0 });
    const c = await request(app).post(`/pawspots/${id}/like`);
    expect(c.body).toMatchObject({ liked: true, likesCount: 1 });
  });

  test('10 ❤️ → validé communauté, +10 à l’auteur UNE fois, auteur notifié', async () => {
    const { author, id } = await seedSpot();
    for (let i = 0; i < 12; i += 1) {
      const fan = await makeUser(Owner, `Fan${i}`, `fan${i}@x.io`);
      asUser(fan);
      await request(app).post(`/pawspots/${id}/like`);
    }
    expect(pointsOf(author)).toBe(20); // 10 (création) + 10 (validé)
    const validated = mockNotifs.filter((n) => n.type === 'pawspot_validated');
    expect(validated).toHaveLength(1);
    expect(validated[0].data.spotName).toBe('Parc des chiens');
    // Le spot est doré pour tout le monde.
    const near = await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
    expect(near.body.spots[0].isGolden).toBe(true);
  });

  test('3 validations → +10 à l’auteur, une seule fois', async () => {
    const { author, id } = await seedSpot();
    for (let i = 0; i < 5; i += 1) {
      const v = await makeUser(Owner, `V${i}`, `v${i}@x.io`);
      asUser(v);
      const r = await request(app).post(`/pawspots/${id}/validate`);
      expect(r.status).toBe(200);
    }
    expect(pointsOf(author)).toBe(20);
    expect(mockNotifs.filter((n) => n.type === 'pawspot_validated')).toHaveLength(1);
  });

  test('deux validations de la même personne → already, compteur inchangé', async () => {
    const { id } = await seedSpot();
    const bo = await makeUser(Owner, 'Bo', 'bo@x.io');
    asUser(bo);
    await request(app).post(`/pawspots/${id}/validate`);
    const again = await request(app).post(`/pawspots/${id}/validate`);
    expect(again.body.already).toBe(true);
    expect(again.body.validationsCount).toBe(1);
  });

  test('+2 « commentaire utile » UNE seule fois par personne et par spot', async () => {
    const { id } = await seedSpot();
    const bo = await makeUser(Owner, 'Bo', 'bo@x.io');
    asUser(bo);
    const first = await request(app).post(`/pawspots/${id}/comment`).send({ text: 'super' });
    expect(first.body.pointsEarned).toBe(2);
    for (let i = 0; i < 10; i += 1) {
      const next = await request(app).post(`/pawspots/${id}/comment`).send({ text: `ok ${i}` });
      expect(next.body.pointsEarned).toBe(0);
    }
    expect(pointsOf(bo)).toBe(2);
  });

  test('la visite ne compte qu’une fois', async () => {
    const { id } = await seedSpot();
    const bo = await makeUser(Owner, 'Bo', 'bo@x.io');
    asUser(bo);
    const a = await request(app).post(`/pawspots/${id}/visit`);
    expect(a.body.visitsCount).toBe(1);
    const b = await request(app).post(`/pawspots/${id}/visit`);
    expect(b.body).toMatchObject({ visitsCount: 1, already: true });
  });
});

describe('points doublés Paw Premium (promesse de la boutique)', () => {
  beforeEach(reset);

  test('Premium sur le profil ACTIF → ×2', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(u._id), userModel: 'Owner',
      premiumExpiry: new Date(Date.now() + 30 * 86400000),
    });
    asUser(u);
    const r = await newSpot({ photoUrl: 'https://cdn/x.jpg' });
    expect(r.body.pointsEarned).toBe(30); // (10 + 5) × 2
  });

  test('Premium acheté en propriétaire → ×2 aussi depuis le profil gardien', async () => {
    const owner = await makeUser(Owner, 'Ana', 'ana@x.io');
    const sitter = await makeUser(Sitter, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(owner._id), userModel: 'Owner',
      premiumExpiry: new Date(Date.now() + 30 * 86400000),
    });
    asUser(sitter, 'sitter');
    const r = await newSpot();
    expect(r.body.pointsEarned).toBe(20);
  });

  test('Premium expiré → pas de doublement', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    await UserSubscription.create({
      userId: String(u._id), userModel: 'Owner',
      premiumExpiry: new Date(Date.now() - 86400000),
    });
    asUser(u);
    const r = await newSpot();
    expect(r.body.pointsEarned).toBe(10);
  });
});

describe('lecture : état du lecteur, classement, /me/points', () => {
  beforeEach(reset);

  test('nearby renvoie likedByMe / validatedByMe / isMine', async () => {
    const ana = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(ana);
    const created = await newSpot();
    let near = await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
    expect(near.body.spots[0]).toMatchObject({ isMine: true, likedByMe: false });

    const bo = await makeUser(Owner, 'Bo', 'bo@x.io');
    asUser(bo);
    await request(app).post(`/pawspots/${created.body.spot.id}/like`);
    near = await request(app).get('/pawspots/nearby?lat=48.85&lng=2.35');
    expect(near.body.spots[0]).toMatchObject({ isMine: false, likedByMe: true });
  });

  test('classement : une seule ligne par personne (3 profils = 1 entrée)', async () => {
    const owner = await makeUser(Owner, 'Ana', 'ana@x.io', { pawPoints: 500 });
    await makeUser(Sitter, 'Ana', 'ana@x.io', { pawPoints: 500 });
    await makeUser(Owner, 'Bo', 'bo@x.io', { pawPoints: 900 });
    asUser(owner);
    const r = await request(app).get('/pawspots/leaderboard?scope=europe');
    expect(r.status).toBe(200);
    const names = r.body.leaderboard.map((x) => x.name);
    expect(names).toEqual(['Bo', 'Ana']);
    expect(r.body.leaderboard[0]._email).toBeUndefined();
  });

  test('/me/points : solde dépensable (alias boutique) + tags restants', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io', {
      pawPoints: 1200, pawPointsSpendable: 200,
    });
    asUser(u);
    await newSpot();
    const r = await request(app).get('/pawspots/me/points');
    expect(r.status).toBe(200);
    expect(r.body.lifetime).toBe(1210);
    expect(r.body.spendable).toBe(210);
    // La boutique lit cette clé : sans elle, elle affichait le total à vie.
    expect(r.body.pawPointsSpendable).toBe(210);
    expect(r.body.mySpotsCount).toBe(1);
    expect(r.body.spotsCreatedTotal).toBe(1);
    expect(r.body.freeSpotsLeft).toBe(2);
    expect(r.body.isGoldCreator).toBe(true);
  });

  test('validation d’entrée : type inconnu, nom vide, coordonnées manquantes', async () => {
    const u = await makeUser(Owner, 'Ana', 'ana@x.io');
    asUser(u);
    expect((await newSpot({ type: 'casino' })).status).toBe(400);
    expect((await newSpot({ name: '   ' })).status).toBe(400);
    expect((await newSpot({ lat: 'abc' })).status).toBe(400);
    expect(mockStores.PawSpot).toHaveLength(0);
  });
});
