// 606 (ZOE, 01/10/2026) — refus Apple 1.25/605, guideline 3.1.1 (« promo codes
// to unlock access »). Le serveur refuse proprement les codes MAISON quand la
// requête vient d'une app iOS ≥ 606 ; anciennes apps iOS, Android et site :
// inchangés. Ici : la règle pure, puis les VRAIES routes /promo/check,
// /promo/redeem et /app-config/public-promo, avec modèles simulés (aucune
// base, aucun réseau).

process.env.NODE_ENV = 'test';

const mockFindOne = jest.fn(async () => null); // « code invalide » → 404
jest.mock('../src/models/PromoCode', () => ({ findOne: (...a) => mockFindOne(...a) }));
jest.mock('../src/models/PromoCodeRedemption', () => ({ findOne: jest.fn(), create: jest.fn() }));
jest.mock('../src/models/UserSubscription', () => ({}));
jest.mock('../src/models/Owner', () => ({}));
jest.mock('../src/models/Sitter', () => ({}));
jest.mock('../src/models/Walker', () => ({}));
jest.mock('../src/models/AppConfig', () => ({
  getPublicPromo: jest.fn(async () => ({ code: 'HOPDALIOS', enabled: true, message: '' })),
}));
jest.mock('../src/middleware/auth', () => {
  const pass = (req, _res, next) => {
    req.user = { id: 'u1', role: 'owner' };
    next();
  };
  return {
    requireAuth: pass,
    optionalAuth: pass,
    requireRole: () => pass,
    requireVerifiedEmail: pass,
    requireAdmin: pass,
  };
});

const express = require('express');
const request = require('supertest');
const {
  isIosStoreClient606,
  buildFromVersionHeader,
} = require('../src/utils/iosHouseCodes606');

const req = (headers) => ({ headers });

describe('règle isIosStoreClient606', () => {
  test('iOS build 606 et plus → refusé', () => {
    expect(isIosStoreClient606(req({ 'x-app-platform': 'ios', 'x-app-version': '23.1.606+606' }))).toBe(true);
    expect(isIosStoreClient606(req({ 'x-app-platform': 'ios', 'x-app-version': '23.1.610+612' }))).toBe(true);
  });
  test('anciennes apps iOS (< 606 ou sans version) → tolérées', () => {
    expect(isIosStoreClient606(req({ 'x-app-platform': 'ios', 'x-app-version': '23.1.602+605' }))).toBe(false);
    expect(isIosStoreClient606(req({ 'x-app-platform': 'ios' }))).toBe(false);
    expect(isIosStoreClient606(req({}))).toBe(false);
  });
  test('Android et site → jamais refusés', () => {
    expect(isIosStoreClient606(req({ 'x-app-platform': 'android', 'x-app-version': '23.1.606+606' }))).toBe(false);
    expect(isIosStoreClient606(req({ 'x-app-version': 'web' }))).toBe(false);
  });
  test('lecture du numéro de build', () => {
    expect(buildFromVersionHeader('23.1.606+606')).toBe(606);
    expect(buildFromVersionHeader('web')).toBeNull();
  });
});

describe('routes réelles', () => {
  const app = express();
  app.use(express.json());
  app.use('/promo', require('../src/routes/promoRoutes'));
  app.use('/app-config', require('../src/routes/appConfigRoutes'));

  const IOS606 = { 'X-App-Platform': 'ios', 'X-App-Version': '23.1.606+606' };
  const IOS605 = { 'X-App-Platform': 'ios', 'X-App-Version': '23.1.602+605' };
  const ANDROID = { 'X-App-Platform': 'android', 'X-App-Version': '23.1.606+606' };

  beforeEach(() => mockFindOne.mockClear());

  test('iOS 606 : /promo/check et /promo/redeem → 403 IOS_APP_STORE_CODES_ONLY, code jamais lu', async () => {
    for (const path of ['/promo/check', '/promo/redeem']) {
      const r = await request(app).post(path).set(IOS606).send({ code: 'HOPDALIOS' });
      expect(r.status).toBe(403);
      expect(r.body.code).toBe('IOS_APP_STORE_CODES_ONLY');
    }
    expect(mockFindOne).not.toHaveBeenCalled();
  });

  test('iOS 606 : message en français si la langue est fr', async () => {
    const r = await request(app).post('/promo/redeem')
      .set({ ...IOS606, 'Accept-Language': 'fr-FR' }).send({ code: 'X' });
    expect(r.body.error).toMatch(/App Store/);
    expect(r.body.error).toMatch(/uniquement/);
  });

  test('Android : chemin inchangé (le code est cherché, 404 si invalide)', async () => {
    const r = await request(app).post('/promo/check').set(ANDROID).send({ code: 'NOPE' });
    expect(r.status).toBe(404);
    expect(mockFindOne).toHaveBeenCalledTimes(1);
  });

  test('ancienne app iOS 605 : tolérée (chemin inchangé)', async () => {
    const r = await request(app).post('/promo/redeem').set(IOS605).send({ code: 'NOPE' });
    expect(r.status).toBe(404);
    expect(mockFindOne).toHaveBeenCalledTimes(1);
  });

  test('/app-config/public-promo : désactivé pour iOS 606, inchangé ailleurs', async () => {
    const ios = await request(app).get('/app-config/public-promo').set(IOS606);
    expect(ios.status).toBe(200);
    expect(ios.body).toEqual({ code: '', enabled: false, message: '' });
    const and = await request(app).get('/app-config/public-promo').set(ANDROID);
    expect(and.body).toEqual({ code: 'HOPDALIOS', enabled: true, message: '' });
    const old = await request(app).get('/app-config/public-promo').set(IOS605);
    expect(old.body.code).toBe('HOPDALIOS');
  });
});
