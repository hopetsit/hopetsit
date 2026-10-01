// 607 (ZOE, 01/10/2026) — codes de PARRAINAGE masqués sur iPhone/iPad (décision de
// Daniel). Le serveur ignore le code saisi à l'inscription et refuse proprement
// GET /users/me/referrals pour l'app iOS >= 607 ; iOS <= 606, Android et site inchangés.
// Faux modèles en mémoire repris de authSignupFlow.test.js (aucune base, aucun réseau).

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

const baseUser = (email, extra = {}) => ({
  name: 'Camille Durand', email, password: 'Secret123', city: 'Lyon', country: 'FR', countryCode: '+33',
  location: { city: 'Lyon' }, language: 'fr', ...extra,
});

const express = require('express');
const request = require('supertest');
const referralService = require('../src/services/referralService');
const {
  isIosNoReferralClient607,
  refuseReferralCodesOnIos607,
  isIosStoreClient606,
} = require('../src/utils/iosHouseCodes606');

const IOS607 = { 'x-app-platform': 'ios', 'x-app-version': '23.1.581+607' };
const IOS606 = { 'x-app-platform': 'ios', 'x-app-version': '23.1.580+606' };
const ANDROID607 = { 'x-app-platform': 'android', 'x-app-version': '23.1.581+607' };

describe('règle isIosNoReferralClient607', () => {
  const r = (headers) => ({ headers });
  test('iOS 607 et plus → parrainage refusé', () => {
    expect(isIosNoReferralClient607(r(IOS607))).toBe(true);
    expect(isIosNoReferralClient607(r({ 'x-app-platform': 'ios', 'x-app-version': '23.1.590+612' }))).toBe(true);
  });
  test('iOS 606 et plus anciennes, sans version, Android, site → tolérés', () => {
    expect(isIosNoReferralClient607(r(IOS606))).toBe(false);
    expect(isIosNoReferralClient607(r({ 'x-app-platform': 'ios' }))).toBe(false);
    expect(isIosNoReferralClient607(r(ANDROID607))).toBe(false);
    expect(isIosNoReferralClient607(r({}))).toBe(false);
  });
  test('la règle 606 des codes promo est inchangée', () => {
    expect(isIosStoreClient606(r(IOS606))).toBe(true);
    expect(isIosStoreClient606(r({ 'x-app-platform': 'ios', 'x-app-version': '23.1.602+605' }))).toBe(false);
  });
});

describe('inscription avec un code de parrainage', () => {
  beforeEach(() => { reset(); referralService.createPendingReferral.mockClear(); });

  test('iOS 607 : inscription OK (201) mais code ignoré, aucun parrainage créé', async () => {
    const res = await call(auth.signup, {
      body: { role: 'owner', user: baseUser('p607@x.io', { referralCode: 'abcd1234' }) },
      headers: IOS607,
    });
    expect(res.statusCode).toBe(201);
    expect(mockStores.Owner[0].referredBy).toBeUndefined();
    expect(mockStores.Owner[0].referralCode).toBe('REF123'); // son propre code existe toujours
    expect(referralService.createPendingReferral).not.toHaveBeenCalled();
  });

  test.each([['iOS 606', IOS606], ['Android 607', ANDROID607], ['site (sans en-tête)', {}]])(
    '%s : code pris en compte comme avant', async (_n, headers) => {
      const res = await call(auth.signup, {
        body: { role: 'sitter', user: baseUser('pold@x.io', { referralCode: 'abcd1234' }) },
        headers,
      });
      expect(res.statusCode).toBe(201);
      expect(mockStores.Sitter[0].referredBy).toBe('ABCD1234');
      expect(referralService.createPendingReferral).toHaveBeenCalledTimes(1);
      expect(referralService.createPendingReferral.mock.calls[0][0].referralCode).toBe('ABCD1234');
    },
  );
});

describe('GET /users/me/referrals (middleware réel)', () => {
  const app = express();
  app.get('/users/me/referrals', refuseReferralCodesOnIos607, (_req, res) => res.json({ code: 'REF123' }));

  test('iOS 607 → 403 IOS_APP_STORE_CODES_ONLY (message FR si la langue est FR)', async () => {
    const r = await request(app).get('/users/me/referrals').set(IOS607).set('Accept-Language', 'fr-FR');
    expect(r.status).toBe(403);
    expect(r.body.code).toBe('IOS_APP_STORE_CODES_ONLY');
    expect(r.body.error).toMatch(/App Store/);
  });
  test.each([['iOS 606', IOS606], ['Android', ANDROID607], ['site', {}]])('%s → 200 inchangé', async (_n, h) => {
    const r = await request(app).get('/users/me/referrals').set(h);
    expect(r.status).toBe(200);
    expect(r.body.code).toBe('REF123');
  });
  test('la vraie route est bien branchée avec ce middleware', () => {
    const src = require('fs').readFileSync(require.resolve('../src/routes/userRoutes.js'), 'utf8');
    expect(src).toMatch(/router\.get\('\/me\/referrals', requireAuth, refuseReferralCodesOnIos607, getMyReferralsRoute\)/);
  });
});
