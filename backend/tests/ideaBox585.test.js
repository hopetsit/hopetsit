// v585 (lot D du chantier du 24/09) — « Boîte à idées » de Daniel (25/09).
// Une seule entrée « Une idée ? Un problème ? » (app + site) qui passe par
// le circuit de signalement de bugs EXISTANT (`POST /bug-reports`) avec une
// étiquette `kind` ('bug' | 'idea'). Aucune nouvelle route.
//
// Ici : les règles pures (utils/bugReportKind), puis le VRAI gestionnaire de
// `POST /bug-reports` et des routes admin, avec des modèles simulés. Aucun
// accès réseau, aucune base, aucun e-mail réel.

process.env.NODE_ENV = 'test';

const created = [];
const patched = [];

const mockChain = (result) => {
  const c = {
    select: () => c,
    sort: () => c,
    limit: () => c,
    lean: () => Promise.resolve(result),
    then: (ok, ko) => Promise.resolve(result).then(ok, ko),
    catch: () => c,
  };
  return c;
};

const personModel = (name) => ({
  findById: jest.fn(() => mockChain({ _id: 'u1', name, email: `${name}@example.test` })),
});

jest.mock('../src/models/Owner', () => personModel('daniel'));
jest.mock('../src/models/Sitter', () => personModel('lea'));
jest.mock('../src/models/Walker', () => personModel('marc'));

jest.mock('../src/models/BugReport', () => ({
  create: jest.fn(async (doc) => {
    const d = { ...doc, _id: `br${created.length + 1}`, createdAt: new Date() };
    created.push(d);
    return d;
  }),
  updateOne: jest.fn(() => ({ catch: () => {} })),
  find: jest.fn((filter) => {
    const rows = created.filter((d) => {
      if (filter.kind && d.kind !== filter.kind) return false;
      if (filter.$or) {
        const ok = filter.$or.some((c) =>
          c.kind === 'bug' ? d.kind === 'bug' : c.kind && c.kind.$exists === false ? d.kind === undefined : false,
        );
        if (!ok) return false;
      }
      if (filter.status && d.status !== filter.status) return false;
      return true;
    });
    return mockChain(rows);
  }),
  countDocuments: jest.fn(async () => 0),
  findByIdAndUpdate: jest.fn(async (id, update, opts) => {
    patched.push({ id, update, opts });
    return { _id: id, ...update };
  }),
  findByIdAndDelete: jest.fn(async () => ({})),
}));

const mockSendEmail = jest.fn(() => Promise.resolve());
jest.mock('../src/services/emailService', () => ({ sendEmail: (...a) => mockSendEmail(...a) }));
jest.mock('../src/utils/logger', () => ({
  warn: jest.fn(),
  error: jest.fn(),
  info: jest.fn(),
  debug: jest.fn(),
}));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));

const kindRules = require('../src/utils/bugReportKind');

const lastHandler = (router, method, path) => {
  const layer = router.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method],
  );
  if (!layer) throw new Error(`route ${method} ${path} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
};

const call = (handler, req) =>
  new Promise((resolve) => {
    const res = {
      statusCode: 200,
      status(c) {
        this.statusCode = c;
        return this;
      },
      json(body) {
        resolve({ status: this.statusCode, body });
      },
    };
    handler(req, res);
  });

describe('règles pures — utils/bugReportKind', () => {
  test('normalizeKind : idea ↔ idée, tout le reste = bug (anciennes apps sans kind)', () => {
    expect(kindRules.normalizeKind('idea')).toBe('idea');
    expect(kindRules.normalizeKind('IDÉE')).toBe('idea');
    expect(kindRules.normalizeKind('problem')).toBe('bug');
    expect(kindRules.normalizeKind('bug')).toBe('bug');
    expect(kindRules.normalizeKind(undefined)).toBe('bug');
    expect(kindRules.normalizeKind('')).toBe('bug');
  });

  test('description minimale : 10 pour un bug, 3 pour une idée', () => {
    expect(kindRules.minDescriptionLength('bug')).toBe(10);
    expect(kindRules.minDescriptionLength('idea')).toBe(3);
  });

  test("statuts : une idée est nouvelle / retenue / faite, un bug garde les siens", () => {
    expect(kindRules.isValidStatus('idea', 'open')).toBe(true);
    expect(kindRules.isValidStatus('idea', 'kept')).toBe(true);
    expect(kindRules.isValidStatus('idea', 'done')).toBe(true);
    expect(kindRules.isValidStatus('idea', 'fixed')).toBe(false);
    expect(kindRules.isValidStatus('bug', 'fixed')).toBe(true);
    expect(kindRules.isValidStatus('bug', 'kept')).toBe(false);
    expect(kindRules.ALL_STATUSES).toEqual(
      expect.arrayContaining(['open', 'in_progress', 'fixed', 'wontfix', 'duplicate', 'kept', 'done']),
    );
  });

  test("sujet d'e-mail : [HoPetSit idée] / [HoPetSit bug]", () => {
    expect(kindRules.mailSubject({ kind: 'idea', title: 'Mode sombre' })).toBe('[HoPetSit idée] Mode sombre');
    expect(kindRules.mailSubject({ kind: 'bug', title: '', _id: 'x1' })).toBe('[HoPetSit bug] x1');
  });

  test('filtre admin : idea = kind idea ; bug = kind bug OU absent ; sinon tout', () => {
    expect(kindRules.kindFilter('idea')).toEqual({ kind: 'idea' });
    expect(kindRules.kindFilter('bug')).toEqual({ $or: [{ kind: 'bug' }, { kind: { $exists: false } }] });
    expect(kindRules.kindFilter('')).toEqual({});
    expect(kindRules.kindFilter(undefined)).toEqual({});
  });
});

describe('POST /bug-reports (vrai gestionnaire, modèles simulés)', () => {
  const router = require('../src/routes/bugReportRoutes');
  const post = lastHandler(router, 'post', '/');

  beforeEach(() => {
    created.length = 0;
    mockSendEmail.mockClear();
  });

  test("une idée est enregistrée avec kind 'idea' et l'e-mail est étiqueté idée", async () => {
    const r = await call(post, {
      user: { id: 'u1', role: 'owner' },
      body: { kind: 'idea', title: 'Widget iOS', description: 'Un widget sur l\'écran d\'accueil', platform: 'ios' },
    });
    expect(r.status).toBe(200);
    expect(r.body.ok).toBe(true);
    expect(created).toHaveLength(1);
    expect(created[0].kind).toBe('idea');
    expect(created[0].userRole).toBe('owner');
    expect(created[0].userName).toBe('daniel');
    expect(mockSendEmail).toHaveBeenCalledTimes(1);
    expect(mockSendEmail.mock.calls[0][1]).toBe('[HoPetSit idée] Widget iOS');
    expect(mockSendEmail.mock.calls[0][2]).toContain('Type: Idée');
  });

  test("un problème (kind 'problem') devient un bug, comme avant", async () => {
    const r = await call(post, {
      user: { id: 'u1', role: 'sitter' },
      body: { kind: 'problem', description: 'Le bouton Payer ne répond pas' },
    });
    expect(r.status).toBe(200);
    expect(created[0].kind).toBe('bug');
    expect(mockSendEmail.mock.calls[0][1]).toMatch(/^\[HoPetSit bug\]/);
  });

  test('une ancienne app sans kind = bug (rien ne change pour elle)', async () => {
    const r = await call(post, {
      user: { id: 'u1', role: 'walker' },
      body: { title: 'Crash', description: "L'app se ferme au démarrage" },
    });
    expect(r.status).toBe(200);
    expect(created[0].kind).toBe('bug');
  });

  test('une idée courte (3 caractères) passe, un bug de moins de 10 caractères est refusé', async () => {
    const ok = await call(post, {
      user: { id: 'u1', role: 'owner' },
      body: { kind: 'idea', description: 'Bip' },
    });
    expect(ok.status).toBe(200);
    const ko = await call(post, {
      user: { id: 'u1', role: 'owner' },
      body: { kind: 'problem', description: 'Court' },
    });
    expect(ko.status).toBe(400);
    expect(ko.body.error).toMatch(/min 10/);
    const ko2 = await call(post, {
      user: { id: 'u1', role: 'owner' },
      body: { kind: 'idea', description: 'ab' },
    });
    expect(ko2.status).toBe(400);
    expect(ko2.body.error).toMatch(/min 3/);
  });

  test("le nom de l'utilisateur est échappé dans l'e-mail HTML", async () => {
    const Owner = require('../src/models/Owner');
    Owner.findById.mockImplementationOnce(() =>
      mockChain({ _id: 'u1', name: '<img src=x>', email: 'x@example.test' }),
    );
    await call(post, {
      user: { id: 'u1', role: 'owner' },
      body: { kind: 'idea', description: 'Une idée' },
    });
    expect(mockSendEmail.mock.calls[0][3]).not.toContain('<img src=x>');
    expect(mockSendEmail.mock.calls[0][3]).toContain('&lt;img src=x>');
  });
});

describe('admin — filtre « Idées » et statut nouvelle / retenue / faite (règles de adminRoutes)', () => {
  // adminRoutes.js charge ~3 900 lignes de contrôleurs (Firebase, paiements…)
  // et ne se charge pas isolément : la route appelle ces deux règles pures,
  // testées ici telles que la route les utilise.
  const { adminListFilter, adminUpdateFromBody } = kindRules;

  test('?kind=idea ne liste que les idées, et le compteur des idées nouvelles existe', () => {
    const r = adminListFilter({ kind: 'idea' });
    expect(r.filter).toEqual({ kind: 'idea' });
    expect(r.ideaOpenFilter).toEqual({ status: 'open', kind: 'idea' });
  });

  test('?kind=bug inclut les anciens signalements sans champ kind ; « ouverts » ne compte que les bugs', () => {
    const r = adminListFilter({ kind: 'bug' });
    expect(r.filter).toEqual({ $or: [{ kind: 'bug' }, { kind: { $exists: false } }] });
    expect(r.bugOpenFilter).toEqual({ status: 'open', $or: [{ kind: 'bug' }, { kind: { $exists: false } }] });
  });

  test('sans filtre : tout ; kind + status se combinent', () => {
    expect(adminListFilter({}).filter).toEqual({});
    expect(adminListFilter(undefined).filter).toEqual({});
    expect(adminListFilter({ kind: 'idea', status: 'kept' }).filter).toEqual({ kind: 'idea', status: 'kept' });
  });

  test('PATCH accepte kept / done (et les statuts historiques), refuse un statut inconnu', () => {
    expect(adminUpdateFromBody({ status: 'kept' })).toEqual({ update: { status: 'kept' } });
    expect(adminUpdateFromBody({ status: 'done' })).toEqual({ update: { status: 'done' } });
    expect(adminUpdateFromBody({ status: 'fixed', adminNote: 'ok' })).toEqual({ update: { status: 'fixed', adminNote: 'ok' } });
    expect(adminUpdateFromBody({ status: 'banana' })).toEqual({ error: 'Unknown status.' });
    expect(adminUpdateFromBody({ adminNote: 'note seule' })).toEqual({ update: { adminNote: 'note seule' } });
    expect(adminUpdateFromBody(undefined)).toEqual({ update: {} });
  });
});
