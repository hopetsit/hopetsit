// v565 — audit inscription : signup / verify / verify-link / login / google
// sur les 3 rôles, SANS base réelle (modèles Mongoose remplacés par un
// magasin en mémoire). Aucun e-mail réel : emailService est simulé.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

// ── Faux modèles Mongoose (magasin en mémoire) ─────────────────────────────
const mockStores = { Owner: [], Sitter: [], Walker: [], VerificationCode: [] };
const mockSeq = { n: 1 };

const mockMatches = (doc, filter) => {
  if (!filter) return true;
  return Object.entries(filter).every(([k, v]) => {
    if (k === '$or') return v.some((f) => mockMatches(doc, f));
    if (v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Date)) {
      if ('$in' in v) return v.$in.includes(doc[k]);
    }
    return doc[k] === v;
  });
};

const mockMakeDoc = (name, data) => {
  const doc = { createdAt: new Date(), updatedAt: new Date(), ...data, _id: data._id || `${name.toLowerCase()}_${mockSeq.n++}` };
  Object.defineProperty(doc, 'save', { enumerable: false, value: async function () { return this; } });
  Object.defineProperty(doc, 'comparePassword', { enumerable: false, value: async function (p) { return p === this.password; } });
  Object.defineProperty(doc, 'toObject', { enumerable: false, value: function () { return { ...this }; } });
  return doc;
};

const mockChain = (result) => ({
  select: () => mockChain(result),
  lean: async () => (Array.isArray(result) ? result.map((d) => ({ ...d })) : result ? { ...result } : result),
  then: (res, rej) => Promise.resolve(result).then(res, rej),
});

const mockApplyUpdate = (doc, update) => {
  const u = update || {};
  const set = { ...(u.$set || {}) };
  for (const [k, v] of Object.entries(u)) if (!k.startsWith('$')) set[k] = v;
  Object.assign(doc, set);
  for (const k of Object.keys(u.$unset || {})) delete doc[k];
  doc.updatedAt = new Date(); // timestamps: true
};

const mockFakeModel = (name) => {
  const store = mockStores[name];
  const M = {
    modelName: name,
    create: jest.fn(async (data) => { const d = mockMakeDoc(name, data); store.push(d); return d; }),
    findOne: jest.fn((filter) => mockChain(store.find((d) => mockMatches(d, filter)) || null)),
    find: jest.fn((filter) => mockChain(store.filter((d) => mockMatches(d, filter)))),
    findById: jest.fn((id) => mockChain(store.find((d) => String(d._id) === String(id)) || null)),
    updateOne: jest.fn(async (filter, update) => { const d = store.find((x) => mockMatches(x, filter)); if (d) mockApplyUpdate(d, update); return { modifiedCount: d ? 1 : 0 }; }),
    updateMany: jest.fn(async (filter, update) => { const ds = store.filter((x) => mockMatches(x, filter)); ds.forEach((d) => mockApplyUpdate(d, update)); return { modifiedCount: ds.length }; }),
    deleteOne: jest.fn(async (filter) => { const i = store.findIndex((x) => mockMatches(x, filter)); if (i >= 0) store.splice(i, 1); return { deletedCount: i >= 0 ? 1 : 0 }; }),
    deleteMany: jest.fn(async () => ({ deletedCount: 0 })),
    findOneAndUpdate: jest.fn(async (filter, update) => {
      let d = store.find((x) => mockMatches(x, filter));
      if (!d) { d = mockMakeDoc(name, {}); store.push(d); }
      mockApplyUpdate(d, update);
      return d;
    }),
    findByIdAndUpdate: jest.fn(async (id, update) => { const d = store.find((x) => String(x._id) === String(id)); if (d) mockApplyUpdate(d, update); return mockChain(d); }),
    countDocuments: jest.fn(async () => 0),
    exists: jest.fn(async () => null),
  };
  return M;
};

jest.mock('../src/models/Owner', () => mockFakeModel('Owner'));
jest.mock('../src/models/Sitter', () => mockFakeModel('Sitter'));
jest.mock('../src/models/Walker', () => mockFakeModel('Walker'));
jest.mock('../src/models/Admin', () => ({}));
jest.mock('../src/models/VerificationCode', () => mockFakeModel('VerificationCode'));
jest.mock('../src/models/UserSubscription', () => ({ syncAllRolesByEmail: jest.fn(async () => {}), syncSubscriptionAcrossRoles: jest.fn(async () => {}) }));
jest.mock('../src/services/referralService', () => ({ createPendingReferral: jest.fn(async () => {}) }));
jest.mock('../src/utils/avatarFallback', () => ({ ensureAvatarFromSiblingRoles: jest.fn(async () => {}) }));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
jest.mock('../src/utils/referralCode', () => ({ generateUniqueReferralCode: jest.fn(async () => 'REF123') }));
jest.mock('../src/utils/sanitize', () => ({ sanitizeUser: (u) => ({ ...u, id: u._id }) }));

const mockSentEmails = [];
jest.mock('../src/services/emailService', () => ({
  sendVerificationEmail: jest.fn(async (email, code, lang, name) => { mockSentEmails.push({ email, code, lang, name }); }),
  sendPasswordResetEmail: jest.fn(async () => {}),
  sendEmail: jest.fn(async () => {}),
}));

const mockFirebase = { decoded: null };
jest.mock('../src/config/firebaseAdmin', () => ({
  auth: () => ({ verifyIdToken: async () => { if (!mockFirebase.decoded) throw new Error('bad token'); return mockFirebase.decoded; } }),
}));

const auth = require('../src/controllers/authController');
const { hashCode } = require('../src/utils/code');

const mockRes = () => {
  const res = { statusCode: 200, body: null, headers: {} };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  res.type = () => res;
  res.send = (b) => { res.body = b; return res; };
  return res;
};
const call = async (fn, { body = {}, query = {}, headers = {} } = {}) => { const res = mockRes(); await fn({ body, query, headers }, res); return res; };

const reset = () => { for (const k of Object.keys(mockStores)) mockStores[k].length = 0; mockSentEmails.length = 0; };
const lastCodeFor = (email) => mockSentEmails.filter((e) => e.email === email).slice(-1)[0]?.code;

const baseUser = (email, extra = {}) => ({
  name: 'Camille Durand', email, password: 'Secret123', city: 'Lyon', country: 'FR', countryCode: '+33',
  location: { city: 'Lyon' }, language: 'fr', ...extra,
});

describe('signup — 3 rôles, ville sans coordonnées', () => {
  beforeEach(reset);

  test.each(['owner', 'sitter', 'walker'])('%s : city enregistrée, pas de location GeoJSON partiel', async (role) => {
    const res = await call(auth.signup, { body: { role, user: baseUser('a@x.io'), appLocale: 'fr' } });
    expect(res.statusCode).toBe(201);
    const Model = { owner: 'Owner', sitter: 'Sitter', walker: 'Walker' }[role];
    const doc = mockStores[Model][0];
    expect(doc.city).toBe('Lyon');
    expect(doc.country).toBe('FR');
    expect(doc.location).toBeUndefined(); // pas de coordonnées → pas de Point (index 2dsphere)
    expect(doc.verified).toBe(false);
    expect(res.body.token).toBeTruthy();
    expect(res.body.emailVerified).toBe(false);
  });

  test('appLocale/language dans user.* → e-mail dans la langue du compte, prénom, appLocale stocké', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('b@x.io', { appLocale: 'es', language: 'es' }) } });
    expect(mockSentEmails[0].lang).toBe('es');
    expect(mockSentEmails[0].name).toBe('Camille Durand');
    expect(mockStores.Owner[0].appLocale).toBe('es');
  });

  test('code haché + expiration 24 h', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('c@x.io') } });
    const rec = mockStores.VerificationCode[0];
    expect(rec.code).toBe(hashCode(lastCodeFor('c@x.io')));
    expect(rec.expiresAt.getTime() - Date.now()).toBeGreaterThan(23.9 * 3600 * 1000);
  });

  test('e-mail déjà inscrit dans un AUTRE rôle → accepté (2e profil), même rôle → 409', async () => {
    const r1 = await call(auth.signup, { body: { role: 'owner', user: baseUser('d@x.io') } });
    expect(r1.statusCode).toBe(201);
    mockStores.Owner[0].verified = true;
    const r2 = await call(auth.signup, { body: { role: 'sitter', user: baseUser('d@x.io') } });
    expect(r2.statusCode).toBe(201);
    expect(mockStores.Sitter[0].city).toBe('Lyon');
    // frère vérifié → le nouveau profil hérite verified:true et la réponse le dit
    expect(mockStores.Sitter[0].verified).toBe(true);
    expect(r2.body.emailVerified).toBe(true);
    const r3 = await call(auth.signup, { body: { role: 'sitter', user: baseUser('d@x.io') } });
    expect(r3.statusCode).toBe(409);
  });

  test('même rôle NON vérifié → 200 sans token + code renvoyé (pas de 409 trompeur)', async () => {
    await call(auth.signup, { body: { role: 'walker', user: baseUser('e@x.io') } });
    const r = await call(auth.signup, { body: { role: 'walker', user: baseUser('e@x.io') } });
    expect(r.statusCode).toBe(200);
    expect(r.body.needsVerification).toBe(true);
    expect(r.body.token).toBeUndefined();
    expect(mockSentEmails.filter((e) => e.email === 'e@x.io')).toHaveLength(2);
  });
});

describe('ville obligatoire côté serveur selon X-App-Version', () => {
  beforeEach(() => { reset(); mockFirebase.decoded = null; });
  const noCity = (email) => ({ name: 'Sam', email, password: 'Secret123', language: 'fr' });

  test('build ≥ 565 sans ville → 400 CITY_REQUIRED traduit (fr)', async () => {
    const r = await call(auth.signup, { body: { role: 'owner', user: noCity('v1@x.io') }, headers: { 'x-app-version': '23.1.562+565', 'x-app-platform': 'ios' } });
    expect(r.statusCode).toBe(400);
    expect(r.body.code).toBe('CITY_REQUIRED');
    expect(r.body.error).toMatch(/ville/);
    expect(mockStores.Owner).toHaveLength(0);
  });

  test('site (web) sans ville → 400 ; avec ville → 201', async () => {
    const r = await call(auth.signup, { body: { role: 'sitter', user: noCity('v2@x.io') }, headers: { 'x-app-version': 'web' } });
    expect(r.statusCode).toBe(400);
    const ok = await call(auth.signup, { body: { role: 'sitter', user: { ...noCity('v2@x.io'), city: 'Lille' } }, headers: { 'x-app-version': 'web' } });
    expect(ok.statusCode).toBe(201);
  });

  test('sans en-tête ou build < 565 → tolérant (201, ancien comportement)', async () => {
    const a = await call(auth.signup, { body: { role: 'walker', user: noCity('v3@x.io') } });
    expect(a.statusCode).toBe(201);
    const b = await call(auth.signup, { body: { role: 'owner', user: noCity('v4@x.io') }, headers: { 'x-app-version': '23.1.561+564' } });
    expect(b.statusCode).toBe(201);
  });

  test('Google/Apple nouveau compte, build ≥ 565 sans ville → 400 CITY_REQUIRED (en)', async () => {
    mockFirebase.decoded = { uid: 'g9', email: 'v5@x.io', name: 'G', firebase: { sign_in_provider: 'google.com' } };
    const r = await call(auth.googleAuth, { body: { idToken: 't', role: 'owner', user: { appLocale: 'en' } }, headers: { 'x-app-version': '23.1.562+565' } });
    expect(r.statusCode).toBe(400);
    expect(r.body.code).toBe('CITY_REQUIRED');
    expect(r.body.error).toMatch(/city/);
    const a = await call(auth.appleAuth, { body: { idToken: 't', role: 'owner' }, headers: { 'x-app-version': '23.1.562+565' } });
    expect(a.statusCode).toBe(400);
    expect(a.body.code).toBe('CITY_REQUIRED');
  });
});

describe('vérification (code, lien) et propagation aux 3 profils', () => {
  beforeEach(reset);

  test('POST /auth/verify : verified sur les 3 profils, token du rôle demandé, availableRoles', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('f@x.io') } });
    await call(auth.signup, { body: { role: 'walker', user: baseUser('f@x.io') } });
    const code = lastCodeFor('f@x.io');
    const r = await call(auth.verifyEmail, { query: { email: 'f@x.io' }, body: { code, role: 'walker' } });
    expect(r.statusCode).toBe(200);
    expect(r.body.role).toBe('walker');
    expect(mockStores.Owner[0].verified).toBe(true);
    expect(mockStores.Walker[0].verified).toBe(true);
    expect(r.body.availableRoles.map((x) => x.role).sort()).toEqual(['owner', 'walker']);
  });

  test('code faux → 400, code expiré → 410', async () => {
    await call(auth.signup, { body: { role: 'sitter', user: baseUser('g@x.io') } });
    const bad = await call(auth.verifyEmail, { query: { email: 'g@x.io' }, body: { code: '000000' } });
    expect(bad.statusCode).toBe(400);
    mockStores.VerificationCode[0].expiresAt = new Date(Date.now() - 1000);
    const exp = await call(auth.verifyEmail, { query: { email: 'g@x.io' }, body: { code: lastCodeFor('g@x.io') } });
    expect(exp.statusCode).toBe(410);
  });

  test('GET /auth/verify-link : page 200 + verified sur les 3 profils', async () => {
    await call(auth.signup, { body: { role: 'sitter', user: baseUser('h@x.io') } });
    await call(auth.signup, { body: { role: 'owner', user: baseUser('h@x.io') } });
    const r = await call(auth.verifyEmailLink, { query: { email: 'h@x.io', code: lastCodeFor('h@x.io') } });
    expect(r.statusCode).toBe(200);
    expect(String(r.body)).toContain('hopetsit://');
    expect(mockStores.Sitter[0].verified).toBe(true);
    expect(mockStores.Owner[0].verified).toBe(true);
  });

  test('verify-link : owner déjà vérifié mais walker pas encore → active le walker (pas « déjà activé »)', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('i@x.io') } });
    mockStores.Owner[0].verified = true;
    mockStores.Walker.push(mockMakeDoc('Walker', { email: 'i@x.io', verified: false, password: 'x' }));
    // nouveau code (comme le fait l'inscription walker)
    await call(auth.resendVerificationCode, { query: { email: 'i@x.io' } });
    const r = await call(auth.verifyEmailLink, { query: { email: 'i@x.io', code: lastCodeFor('i@x.io') } });
    expect(r.statusCode).toBe(200);
    expect(mockStores.Walker[0].verified).toBe(true);
  });
});

describe('login', () => {
  beforeEach(reset);

  test('compte vérifié → token + availableRoles + rôle préféré respecté', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('j@x.io') } });
    await call(auth.signup, { body: { role: 'sitter', user: baseUser('j@x.io') } });
    mockStores.Owner[0].verified = true; mockStores.Sitter[0].verified = true;
    const r = await call(auth.login, { body: { email: 'j@x.io', password: 'Secret123', role: 'sitter' } });
    expect(r.statusCode).toBe(200);
    expect(r.body.role).toBe('sitter');
    expect(r.body.availableRoles.map((x) => x.role).sort()).toEqual(['owner', 'sitter']);
    expect(r.body.emailVerified).toBe(true);
  });

  test('compte NON vérifié → entre quand même (token), emailVerified:false, availableRoles, et le code de l’inscription reste VALIDE (pas de 2e e-mail immédiat)', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('k@x.io') } });
    const codeSignup = lastCodeFor('k@x.io');
    const r = await call(auth.login, { body: { email: 'k@x.io', password: 'Secret123', role: 'owner' } });
    expect(r.statusCode).toBe(200);
    expect(r.body.token).toBeTruthy();
    expect(r.body.emailVerified).toBe(false);
    expect(Array.isArray(r.body.availableRoles)).toBe(true);
    // l'app appelle login juste après signup : le lien du 1er e-mail doit rester bon
    expect(mockSentEmails.filter((e) => e.email === 'k@x.io')).toHaveLength(1);
    const v = await call(auth.verifyEmail, { query: { email: 'k@x.io' }, body: { code: codeSignup } });
    expect(v.statusCode).toBe(200);
  });

  test('compte non vérifié, code ancien (> 10 min) → un nouveau code est renvoyé au login', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('l@x.io') } });
    mockStores.VerificationCode[0].updatedAt = new Date(Date.now() - 11 * 60 * 1000);
    await call(auth.login, { body: { email: 'l@x.io', password: 'Secret123' } });
    expect(mockSentEmails.filter((e) => e.email === 'l@x.io')).toHaveLength(2);
  });

  test('mauvais mot de passe → 401', async () => {
    await call(auth.signup, { body: { role: 'owner', user: baseUser('m@x.io') } });
    const r = await call(auth.login, { body: { email: 'm@x.io', password: 'nope' } });
    expect(r.statusCode).toBe(401);
  });
});

describe('Google / Apple', () => {
  beforeEach(() => { reset(); mockFirebase.decoded = null; });

  test('nouveau compte Google : ROLE_REQUIRED sans rôle ; avec rôle + ville → créé vérifié, city/appLocale stockés', async () => {
    mockFirebase.decoded = { uid: 'g1', email: 'n@x.io', name: 'Nina G', picture: 'p.jpg', firebase: { sign_in_provider: 'google.com' } };
    const r0 = await call(auth.googleAuth, { body: { idToken: 't' } });
    expect(r0.statusCode).toBe(400);
    expect(r0.body.code).toBe('ROLE_REQUIRED');
    const r1 = await call(auth.googleAuth, { body: { idToken: 't', role: 'walker', user: { city: 'Nice', location: { lat: 43.7, lng: 7.26, city: 'Nice' }, appLocale: 'fr', language: 'fr', country: 'FR' } } });
    expect(r1.statusCode).toBe(201);
    expect(mockStores.Walker[0].verified).toBe(true);
    expect(mockStores.Walker[0].city).toBe('Nice');
    expect(mockStores.Walker[0].country).toBe('FR');
    expect(mockStores.Walker[0].appLocale).toBe('fr');
    expect(mockStores.Walker[0].location.coordinates).toEqual([7.26, 43.7]);
    expect(mockSentEmails).toHaveLength(0);
  });

  test('Google sur un e-mail déjà owner, rôle demandé sitter existant → connecte sur sitter', async () => {
    mockFirebase.decoded = { uid: 'g2', email: 'o@x.io', name: 'Olga', firebase: { sign_in_provider: 'google.com' } };
    mockStores.Owner.push(mockMakeDoc('Owner', { email: 'o@x.io', verified: true, password: 'x' }));
    mockStores.Sitter.push(mockMakeDoc('Sitter', { email: 'o@x.io', verified: true, password: 'x' }));
    const r = await call(auth.googleAuth, { body: { idToken: 't', role: 'sitter' } });
    expect(r.statusCode).toBe(200);
    expect(r.body.existingUser).toBe(true);
    expect(r.body.role).toBe('sitter');
    expect(r.body.availableRoles.map((x) => x.role).sort()).toEqual(['owner', 'sitter']);
  });

  test('Apple : le nom transmis par l’app est utilisé (pas le préfixe privaterelay)', async () => {
    mockFirebase.decoded = { uid: 'a1', email: 'abc123@privaterelay.appleid.com', firebase: { sign_in_provider: 'apple.com' } };
    const r = await call(auth.appleAuth, { body: { idToken: 't', role: 'owner', user: { name: 'Paul Martin', city: 'Paris' } } });
    expect(r.statusCode).toBe(201);
    expect(mockStores.Owner[0].name).toBe('Paul Martin');
    expect(mockStores.Owner[0].city).toBe('Paris');
  });
});
