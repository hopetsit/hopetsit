// v575 — audit « lot B » du 21/09/2026. Quatre défauts, un test par cause :
//
//   P0-3  `PUT /users/:id/service|profile|card` et `DELETE /users/:id` étaient
//         montées SANS `requireAuth` : n'importe qui connaissant un id — et un
//         id fuit dans `ownerId` / `sitterId` / `walkerId` de nombreuses
//         réponses — pouvait modifier un profil ou SUPPRIMER un compte.
//   P0-4  « Supprimer mon compte » effaçait le mauvais profil : la collection
//         était devinée par `Owner.findById(id)` EN PREMIER, alors que
//         `switchRole` peut créer l'Owner avec le MÊME `_id` que le Sitter.
//   P1-10 La suppression d'un compte PROMENEUR ne faisait aucune cascade
//         (conversations, messages, réservations, candidatures restaient).
//   P1-5  `chooseService` écrivait les services sur le document PROPRIÉTAIRE
//         d'un prestataire multi-rôles (`findAccountByEmail` = owner d'abord).
//
// Aucun réseau, aucune base : les modèles Mongoose sont remplacés par une base
// en mémoire (même approche que `selfExclusion.test.js` / `sharedIdentity.test.js`).

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = 'a'.repeat(64);

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');

// ─── Base en mémoire ────────────────────────────────────────────────────────
// PIÈGE REPRODUIT : `switchRole` réutilise `baseOldId` comme `_id` du document
// créé. Une personne inscrite d'abord en GARDIEN qui active son profil
// propriétaire se retrouve donc avec `Owner._id === Sitter._id` (« shared1 »).
let mockDb;
const mockSpy = {};

const mockResetSpies = () => {
  for (const k of Object.keys(mockSpy)) delete mockSpy[k];
  Object.assign(mockSpy, {
    conversationFind: [],
    conversationDelete: [],
    messageDelete: [],
    bookingDelete: [],
    applicationDelete: [],
    deletedDocs: [], // { model, id }
  });
};

const mockResetDb = () => {
  mockDb = {
    Owner: {
      // Profil propriétaire de la personne A — MÊME `_id` que son gardien.
      shared1: { _id: 'shared1', email: 'a@test', name: 'A Owner', service: ['Pet Sitting'] },
      // Personne B, sans aucun lien avec A.
      owner2: { _id: 'owner2', email: 'b@test', name: 'B Owner', service: [] },
    },
    Sitter: {
      shared1: { _id: 'shared1', email: 'a@test', name: 'A Sitter', service: [] },
    },
    Walker: {
      walkerA: { _id: 'walkerA', email: 'a@test', name: 'A Walker', service: [] },
    },
  };
};

/** Faux `Query` mongoose : `await`able ET chaînable (`select`/`lean`/`sort`). */
const mockQuery = (value) => {
  const p = Promise.resolve(value);
  const q = {
    select: () => q,
    sort: () => q,
    populate: () => q,
    lean: () => Promise.resolve(value),
    then: (a, b) => p.then(a, b),
    catch: (b) => p.catch(b),
  };
  return q;
};

const mockClone = (doc) => (doc ? { ...doc } : null);

const mockMatchesOr = (doc, filter) => {
  const or = filter && filter.$or;
  if (!Array.isArray(or)) return false;
  return or.some((cond) =>
    Object.entries(cond).every(([k, v]) => doc[k] === v));
};

const mockRoleModel = (name) => ({
  findById: jest.fn((id) => {
    const doc = mockClone(mockDb[name][id]);
    if (!doc) return mockQuery(null);
    doc.save = jest.fn(async () => {
      mockDb[name][id] = { ...mockDb[name][id], ...doc };
      return doc;
    });
    return mockQuery(doc);
  }),
  findOne: jest.fn((filter = {}) => {
    const found = Object.values(mockDb[name]).find((d) =>
      Object.entries(filter).every(([k, v]) => d[k] === v));
    const doc = mockClone(found);
    if (!doc) return mockQuery(null);
    doc.save = jest.fn(async () => {
      mockDb[name][doc._id] = { ...mockDb[name][doc._id], ...doc };
      return doc;
    });
    return mockQuery(doc);
  }),
  find: jest.fn((filter = {}) =>
    mockQuery(Object.values(mockDb[name])
      .filter((d) => (filter.$or ? mockMatchesOr(d, filter) : true))
      .map(mockClone))),
  findByIdAndUpdate: jest.fn((id, ops = {}) => {
    if (!mockDb[name][id]) return mockQuery(null);
    mockDb[name][id] = { ...mockDb[name][id], ...(ops.$set || {}) };
    return mockQuery(mockClone(mockDb[name][id]));
  }),
  updateOne: jest.fn(async (filter = {}, ops = {}) => {
    const id = filter._id;
    if (mockDb[name][id]) mockDb[name][id] = { ...mockDb[name][id], ...(ops.$set || {}) };
    return { modifiedCount: mockDb[name][id] ? 1 : 0 };
  }),
  updateMany: jest.fn(async () => ({ modifiedCount: 0 })),
  deleteOne: jest.fn(async (filter = {}) => {
    mockSpy.deletedDocs.push({ model: name, id: filter._id });
    delete mockDb[name][filter._id];
    return { deletedCount: 1 };
  }),
  deleteMany: jest.fn(async () => ({ deletedCount: 0 })),
  countDocuments: jest.fn(async () => 0),
  aggregate: jest.fn(async () => []),
});

jest.mock('../src/models/Owner', () => mockRoleModel('Owner'));
jest.mock('../src/models/Sitter', () => mockRoleModel('Sitter'));
jest.mock('../src/models/Walker', () => mockRoleModel('Walker'));

// ─── Collections secondaires : on n'observe que QUI est ciblé ───────────────
jest.mock('../src/models/Conversation', () => ({
  find: jest.fn((filter) => {
    mockSpy.conversationFind.push(filter);
    return mockQuery([{ _id: 'conv1' }]);
  }),
  deleteMany: jest.fn(async (filter) => {
    mockSpy.conversationDelete.push(filter);
    return { deletedCount: 1 };
  }),
}));
jest.mock('../src/models/Message', () => ({
  deleteMany: jest.fn(async (filter) => {
    mockSpy.messageDelete.push(filter);
    return { deletedCount: 1 };
  }),
}));
jest.mock('../src/models/Booking', () => ({
  deleteMany: jest.fn(async (filter) => {
    mockSpy.bookingDelete.push(filter);
    return { deletedCount: 1 };
  }),
  countDocuments: jest.fn(async () => 0),
  find: jest.fn(() => mockQuery([])),
}));
jest.mock('../src/models/Application', () => ({
  deleteMany: jest.fn(async (filter) => {
    mockSpy.applicationDelete.push(filter);
    return { deletedCount: 1 };
  }),
}));

const mockEmptyModel = () => ({
  find: jest.fn(() => mockQuery([])),
  findOne: jest.fn(() => mockQuery(null)),
  findById: jest.fn(() => mockQuery(null)),
  deleteMany: jest.fn(async () => ({ deletedCount: 0 })),
  deleteOne: jest.fn(async () => ({ deletedCount: 0 })),
  updateMany: jest.fn(async () => ({ modifiedCount: 0 })),
  updateOne: jest.fn(async () => ({ modifiedCount: 0 })),
  countDocuments: jest.fn(async () => 0),
  aggregate: jest.fn(async () => []),
  create: jest.fn(async (d) => d),
});

for (const m of [
  'Pet', 'Post', 'Task', 'Block', 'Review', 'Invoice', 'Notification',
  'WalletTransaction', 'UserSubscription', 'VerificationCode', 'VisitReport',
  'BugReport', 'Report', 'Friendship', 'OwnerCredit', 'MapReport', 'Admin',
]) {
  jest.mock(`../src/models/${m}`, () => mockEmptyModel(), { virtual: false });
}

jest.mock('../src/models/AccountDeletion', () => ({
  ACCOUNT_DELETION_REASONS: [],
  recordAccountDeletion: jest.fn(async () => ({})),
}));
jest.mock('../src/utils/deletedAccountLog', () => ({
  logDeletedAccount: jest.fn(async () => ({})),
}));
jest.mock('../src/services/personaService', () => ({
  deleteInquiry: jest.fn(async () => ({})),
}));
jest.mock('../src/services/cloudinary', () => ({
  uploadMedia: jest.fn(async () => ({ url: '', publicId: '' })),
}));
jest.mock('../src/services/loyaltyService', () => ({ getOwnerStats: jest.fn(async () => ({})) }));
jest.mock('../src/services/referralService', () => ({ getMyReferrals: jest.fn(async () => ({})) }));
jest.mock('../src/services/textModerationService', () => ({
  moderateText: (t) => ({ clean: t, flagged: false }),
}));
jest.mock('../src/services/emailService', () => ({
  sendVerificationEmail: jest.fn(async () => ({})),
  sendPasswordResetEmail: jest.fn(async () => ({})),
  sendEmail: jest.fn(async () => ({})),
}));
jest.mock('../src/config/firebaseAdmin', () => ({}));
jest.mock('../src/utils/avatarFallback', () => ({
  ensureAvatarFromSiblingRoles: jest.fn(async () => {}),
}));
jest.mock('../src/controllers/rolesController', () => ({ getMyRoles: (req, res) => res.json({}) }));
jest.mock('../src/controllers/billingInfoController', () => ({
  getMyBillingInfo: (req, res) => res.json({}),
  updateMyBillingInfo: (req, res) => res.json({}),
}));
jest.mock('../src/utils/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

// ─── Application de test : le VRAI routeur et les VRAIS contrôleurs ─────────
const userRoutes = require('../src/routes/userRoutes');
const { deleteAccount } = require('../src/controllers/userController');
const { chooseService } = require('../src/controllers/authController');

const app = express();
app.use(express.json());
app.use('/users', userRoutes);

const tokenFor = (id, role) =>
  jwt.sign({ id, role }, process.env.JWT_SECRET, { expiresIn: '1h' });

beforeEach(() => {
  mockResetSpies();
  mockResetDb();
  jest.clearAllMocks();
});

// ════════════════════════════════════════════════════════════════════════════
// P0-3 — les 4 routes `/users/:id` exigent un jeton ET la bonne identité
// ════════════════════════════════════════════════════════════════════════════
describe('P0-3 — routes /users/:id : authentification + cible = soi-même', () => {
  // `card` répond 410 depuis la v568 (plus aucun PAN ne transite par le
  // serveur) : ce qui compte ici est qu'elle ne réponde ni 401 ni 403.
  const ROUTES = [
    { name: 'service', method: 'put', path: (id) => `/users/${id}/service`, body: { service: ['Pet Sitting'] }, ok: 200 },
    { name: 'profile', method: 'put', path: (id) => `/users/${id}/profile`, body: { bio: 'coucou' }, ok: 200 },
    { name: 'card', method: 'put', path: (id) => `/users/${id}/card`, body: {}, ok: 410 },
    { name: 'delete', method: 'delete', path: (id) => `/users/${id}`, body: {}, ok: 200 },
  ];

  for (const r of ROUTES) {
    test(`${r.method.toUpperCase()} ${r.path(':id')} — 401 sans jeton`, async () => {
      const res = await request(app)[r.method](r.path('shared1')).send(r.body);
      expect(res.status).toBe(401);
      // Rien n'a été touché en base.
      expect(mockDb.Sitter.shared1).toBeDefined();
      expect(mockDb.Owner.shared1).toBeDefined();
    });

    test(`${r.method.toUpperCase()} ${r.path(':id')} — 403 pour un autre utilisateur`, async () => {
      const res = await request(app)[r.method](r.path('shared1'))
        .set('Authorization', `Bearer ${tokenFor('owner2', 'owner')}`)
        .send(r.body);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('FORBIDDEN_NOT_SELF');
      expect(mockDb.Sitter.shared1).toBeDefined();
      expect(mockDb.Owner.shared1).toBeDefined();
    });

    test(`${r.method.toUpperCase()} ${r.path(':id')} — ${r.ok} pour soi-même`, async () => {
      const res = await request(app)[r.method](r.path('shared1'))
        .set('Authorization', `Bearer ${tokenFor('shared1', 'sitter')}`)
        .send(r.body);
      expect(res.status).toBe(r.ok);
    });

    test(`${r.method.toUpperCase()} ${r.path(':id')} — ${r.ok} pour un id FRÈRE du même groupe d'identité`, async () => {
      // Jeton gardien `shared1` → cible `walkerA` : même e-mail, donc même
      // personne (identityGroup). Doit passer.
      const res = await request(app)[r.method](r.path('walkerA'))
        .set('Authorization', `Bearer ${tokenFor('shared1', 'sitter')}`)
        .send(r.body);
      expect(res.status).toBe(r.ok);
    });
  }

  test('un id inconnu d’un tiers reste refusé (403, pas 404)', async () => {
    const res = await request(app)
      .put('/users/inconnu42/profile')
      .set('Authorization', `Bearer ${tokenFor('owner2', 'owner')}`)
      .send({ bio: 'x' });
    expect(res.status).toBe(403);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// P0-4 — la collection cible vient du RÔLE DU JETON
// ════════════════════════════════════════════════════════════════════════════
describe('P0-4 — deleteAccount cible le rôle du jeton, jamais l’Owner par défaut', () => {
  const runDelete = async (id, role) => {
    const req = { params: { id }, user: { id, role }, body: {}, query: {}, headers: {} };
    const res = {
      statusCode: 200,
      payload: null,
      status(c) { this.statusCode = c; return this; },
      json(p) { this.payload = p; return this; },
    };
    await deleteAccount(req, res);
    return res;
  };

  test('jeton GARDIEN + Owner._id === Sitter._id → le profil Owner est INTACT', async () => {
    const res = await runDelete('shared1', 'sitter');
    expect(res.statusCode).toBe(200);
    expect(mockSpy.deletedDocs).toEqual([{ model: 'Sitter', id: 'shared1' }]);
    // La régression historique : c'était l'Owner qui partait.
    expect(mockDb.Owner.shared1).toBeDefined();
    expect(mockDb.Sitter.shared1).toBeUndefined();
  });

  test('jeton PROPRIÉTAIRE sur le même id → c’est bien l’Owner qui part', async () => {
    await runDelete('shared1', 'owner');
    expect(mockSpy.deletedDocs).toEqual([{ model: 'Owner', id: 'shared1' }]);
    expect(mockDb.Sitter.shared1).toBeDefined();
  });

  test('jeton PROMENEUR → le document Walker est supprimé', async () => {
    await runDelete('walkerA', 'walker');
    expect(mockSpy.deletedDocs).toEqual([{ model: 'Walker', id: 'walkerA' }]);
  });

  test('`PUT /users/:id/profile` avec un jeton gardien écrit sur le Sitter, pas sur l’Owner', async () => {
    await request(app)
      .put('/users/shared1/profile')
      .set('Authorization', `Bearer ${tokenFor('shared1', 'sitter')}`)
      .send({ bio: 'Gardien depuis 10 ans' });
    expect(mockDb.Sitter.shared1.bio).toBe('Gardien depuis 10 ans');
    expect(mockDb.Owner.shared1.bio).toBeUndefined();
  });

  test('`PUT /users/:id/service` avec un jeton gardien écrit sur le Sitter', async () => {
    await request(app)
      .put('/users/shared1/service')
      .set('Authorization', `Bearer ${tokenFor('shared1', 'sitter')}`)
      .send({ service: ['Dog Walking'] });
    expect(mockDb.Sitter.shared1.service).toEqual(['Dog Walking']);
    expect(mockDb.Owner.shared1.service).toEqual(['Pet Sitting']);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// P1-10 — cascade de suppression du PROMENEUR
// ════════════════════════════════════════════════════════════════════════════
describe('P1-10 — suppression d’un compte promeneur : cascade complète', () => {
  const runDelete = async (id, role) => {
    const req = { params: { id }, user: { id, role }, body: {}, query: {}, headers: {} };
    const res = { status() { return this; }, json() { return this; } };
    await deleteAccount(req, res);
  };

  test('conversations, messages, réservations et candidatures ciblent walkerId', async () => {
    await runDelete('walkerA', 'walker');
    expect(mockSpy.conversationFind).toEqual([{ walkerId: 'walkerA' }]);
    expect(mockSpy.messageDelete).toEqual([{ conversationId: { $in: ['conv1'] } }]);
    expect(mockSpy.conversationDelete).toEqual([{ _id: { $in: ['conv1'] } }]);
    expect(mockSpy.bookingDelete).toEqual([{ walkerId: 'walkerA' }]);
    expect(mockSpy.applicationDelete).toEqual([{ walkerId: 'walkerA' }]);
  });

  test('le gardien garde exactement le même traitement (non-régression)', async () => {
    await runDelete('shared1', 'sitter');
    expect(mockSpy.conversationFind).toEqual([{ sitterId: 'shared1' }]);
    expect(mockSpy.bookingDelete).toEqual([{ sitterId: 'shared1' }]);
    expect(mockSpy.applicationDelete).toEqual([{ sitterId: 'shared1' }]);
  });

  test('le propriétaire garde exactement le même traitement (non-régression)', async () => {
    await runDelete('owner2', 'owner');
    expect(mockSpy.conversationFind).toEqual([{ ownerId: 'owner2' }]);
    expect(mockSpy.bookingDelete).toEqual([{ ownerId: 'owner2' }]);
  });
});

// ════════════════════════════════════════════════════════════════════════════
// P1-5 — chooseService écrit sur le bon document
// ════════════════════════════════════════════════════════════════════════════
describe('P1-5 — chooseService : le rôle décide du document mis à jour', () => {
  const run = async ({ role, user } = {}) => {
    const req = {
      query: { email: 'a@test' },
      body: { service: ['Dog Walking'], ...(role ? { role } : {}) },
      ...(user ? { user } : {}),
    };
    const res = {
      statusCode: 200,
      payload: null,
      status(c) { this.statusCode = c; return this; },
      json(p) { this.payload = p; return this; },
    };
    await chooseService(req, res);
    return res;
  };

  test('`role: "walker"` → écrit sur le document Walker', async () => {
    const res = await run({ role: 'walker' });
    expect(res.statusCode).toBe(200);
    expect(res.payload.role).toBe('walker');
    expect(mockDb.Walker.walkerA.service).toEqual(['Dog Walking']);
    expect(mockDb.Owner.shared1.service).toEqual(['Pet Sitting']); // intact
  });

  test('`role: "sitter"` → écrit sur le document Sitter', async () => {
    const res = await run({ role: 'sitter' });
    expect(res.payload.role).toBe('sitter');
    expect(mockDb.Sitter.shared1.service).toEqual(['Dog Walking']);
    expect(mockDb.Owner.shared1.service).toEqual(['Pet Sitting']);
  });

  test('le rôle du JETON prime sur celui du corps', async () => {
    const res = await run({ role: 'owner', user: { id: 'walkerA', role: 'walker' } });
    expect(res.payload.role).toBe('walker');
    expect(mockDb.Walker.walkerA.service).toEqual(['Dog Walking']);
    expect(mockDb.Owner.shared1.service).toEqual(['Pet Sitting']);
  });

  test('sans rôle → comportement historique conservé (document propriétaire)', async () => {
    const res = await run();
    expect(res.payload.role).toBe('owner');
    expect(mockDb.Owner.shared1.service).toEqual(['Dog Walking']);
    expect(mockDb.Walker.walkerA.service).toEqual([]);
  });

  test('un rôle inconnu est ignoré, pas une erreur', async () => {
    const res = await run({ role: 'dragon' });
    expect(res.statusCode).toBe(200);
    expect(res.payload.role).toBe('owner');
  });
});
