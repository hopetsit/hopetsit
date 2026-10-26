// 620 (ZOE, 24/10/2026 — ordre de Daniel « dates à prévoir, prix par visite, grille de tarifs »)
// MOTEUR UNIQUE de quantité / estimation, prix par service, grille de tarifs, catalogue des
// 4 services (9 langues), texte du prix dans « candidature reçue » (9 langues) et les 2
// nouveaux gabarits de notification. Lecture pure, aucune base.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const engine = require('../src/utils/pricingEngine620');
const prices = require('../src/utils/prices620');
const rates = require('../src/utils/rates620');
const catalog = require('../src/services/serviceCatalogService');
const text617 = require('../src/utils/applicationNewText617');
const { render } = require('../src/utils/i18nTemplate');

const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const d = (s) => new Date(`${s}T00:00:00.000Z`);

describe('mode de dates', () => {
  test('ancienne demande : deux dates → exact ; aucune date → tbd ; champ explicite → lui', () => {
    expect(engine.effectiveDateMode({ startDate: d('2026-11-20'), endDate: d('2026-11-22') })).toBe('exact');
    expect(engine.effectiveDateMode({ startDate: d('2026-11-20') })).toBe('exact');
    expect(engine.effectiveDateMode({})).toBe('tbd');
    expect(engine.effectiveDateMode({ dateMode: 'approx', startDate: d('2026-11-20'), endDate: d('2026-11-22') })).toBe('approx');
    expect(engine.effectiveDateMode({ dateMode: 'tbd' })).toBe('tbd');
  });
  test('resolveDates : compat 619 (sans dateMode), approx, tbd, erreurs', () => {
    expect(engine.resolveDates({ startDate: '2026-11-20T09:00:00Z', endDate: '2026-11-22T09:00:00Z' })).toMatchObject({ ok: true, dateMode: 'exact' });
    expect(engine.resolveDates({})).toMatchObject({ ok: true, dateMode: 'tbd', startDate: null, endDate: null });
    expect(engine.resolveDates({ dateMode: 'approx', startDate: '2026-11-20', endDate: '2026-11-25', visitsPerDay: '2' })).toMatchObject({ ok: true, dateMode: 'approx', visitsPerDay: 2 });
    expect(engine.resolveDates({ dateMode: 'tbd', startDate: '2026-11-20' })).toMatchObject({ ok: false, code: 'DATES_FORBIDDEN' });
    expect(engine.resolveDates({ dateMode: 'exact' })).toMatchObject({ ok: false, code: 'DATES_REQUIRED' });
    expect(engine.resolveDates({ dateMode: 'exact', startDate: '2026-11-22', endDate: '2026-11-20' })).toMatchObject({ ok: false, code: 'INVALID_DATES' });
    expect(engine.resolveDates({ dateMode: 'later' })).toMatchObject({ ok: false, code: 'INVALID_DATE_MODE' });
    expect(engine.resolveDates({ visitsPerDay: 3 })).toMatchObject({ ok: false, code: 'INVALID_VISITS_PER_DAY' });
    // modification : un champ absent garde la valeur de la demande
    const cur = { dateMode: 'tbd', startDate: null, endDate: null, visitsPerDay: 2 };
    expect(engine.resolveDates({ body: 'x' }, cur)).toMatchObject({ ok: true, dateMode: 'tbd', visitsPerDay: 2 });
    expect(engine.resolveDates({ startDate: '2026-12-01', endDate: '2026-12-03' }, cur)).toMatchObject({ ok: true, dateMode: 'exact', visitsPerDay: 2 });
  });
});

describe('quantités', () => {
  const post = { dateMode: 'exact', startDate: d('2026-11-20'), endDate: d('2026-11-24') };
  test('jours = fin − début + 1 ; nuits = jours − 1 chez le gardien', () => {
    expect(engine.dayCount(post)).toBe(5);
    expect(engine.quantityFor(post, 'house_sitting')).toEqual({ quantity: 5, unit: 'day', days: 5 });
    expect(engine.quantityFor({ ...post, houseSittingVenue: 'sitters_home' }, 'house_sitting')).toEqual({ quantity: 4, unit: 'night', days: 5 });
    expect(engine.quantityFor({ ...post, startDate: d('2026-11-20'), endDate: d('2026-11-20'), houseSittingVenue: 'sitters_home' }, 'house_sitting').quantity).toBe(1);
    expect(engine.quantityFor(post, 'day_care')).toEqual({ quantity: 5, unit: 'day', days: 5 });
  });
  test('visites = jours × visites/jour (1 par défaut) ; balades = 1 par jour (2610)', () => {
    expect(engine.quantityFor(post, 'home_visit')).toEqual({ quantity: 5, unit: 'visit', days: 5 });
    expect(engine.quantityFor({ ...post, visitsPerDay: 2 }, 'home_visit')).toEqual({ quantity: 10, unit: 'visit', days: 5 });
    expect(engine.quantityFor(post, 'dog_walking')).toEqual({ quantity: 5, unit: 'walk', days: 5 });
    expect(engine.quantityFor({ ...post, endDate: post.startDate }, 'dog_walking')).toEqual({ quantity: 1, unit: 'walk', days: 1 });
  });
  test('dates à prévoir : quantité null', () => {
    expect(engine.quantityFor({ dateMode: 'tbd' }, 'home_visit')).toEqual({ quantity: null, unit: 'visit', days: null });
  });
});

describe('estimation', () => {
  test('visite 12 € × 5 jours × 2/jour : 120 + 20 % = 144', () => {
    const e = engine.estimate({ serviceType: 'home_visit', rate: 12, post: { dateMode: 'exact', startDate: d('2026-11-20'), endDate: d('2026-11-24'), visitsPerDay: 2 }, commissionRate: 0.2 });
    expect(e).toMatchObject({ indicative: false, quantity: 10, unit: 'visit', unitRate: 12, unitTotal: 120, commission: 24, ownerTotal: 144 });
  });
  test('Top (15 %) : 18 €/jour × 3 jours = 54 + 8,10 = 62,10', () => {
    const e = engine.estimate({ serviceType: 'house_sitting', rate: 18, post: { startDate: d('2026-11-20'), endDate: d('2026-11-22') }, commissionRate: 0.15 });
    expect(e).toMatchObject({ quantity: 3, unitTotal: 54, commission: 8.1, ownerTotal: 62.1 });
  });
  test('tbd → indicatif : seul le tarif unitaire', () => {
    const e = engine.estimate({ serviceType: 'home_visit', rate: 12, post: { dateMode: 'tbd' } });
    expect(e).toMatchObject({ indicative: true, quantity: null, unitRate: 12, unitTotal: null, commission: null, ownerTotal: null });
  });
  test('tarif du prestataire par service', () => {
    const sitter = { dailyRate: 18, hourlyRate: 5, visitRate: 12, visitDurationMinutes: 60, currency: 'EUR' };
    expect(engine.rateFor(sitter, 'home_visit')).toMatchObject({ rate: 12, unit: 'visit', durationMinutes: 60 });
    expect(engine.rateFor(sitter, 'house_sitting')).toMatchObject({ rate: 18, unit: 'day' });
    expect(engine.rateFor({ weeklyRate: 70 }, 'house_sitting')).toMatchObject({ rate: 10, unit: 'day', source: 'weeklyRate' });
    expect(engine.rateFor({ hourlyRate: 5 }, 'day_care')).toMatchObject({ rate: 40, source: 'hourlyRate' });
    expect(engine.rateFor({ visitRate: 0 }, 'home_visit')).toBeNull();
    const walker = { walkRates: [{ durationMinutes: 60, basePrice: 15 }, { durationMinutes: 30, basePrice: 10 }] };
    expect(engine.rateFor(walker, 'dog_walking')).toMatchObject({ rate: 10, unit: 'walk', durationMinutes: 30 });
    expect(engine.rateFor(walker, 'dog_walking', { durationMinutes: 60 })).toMatchObject({ rate: 15, durationMinutes: 60 });
  });
});

describe('prix par service (listes, PawMap)', () => {
  const sitter = { hourlyRate: 5, dailyRate: 18, visitRate: 12, visitDurationMinutes: 30 };
  test('pricesFor : gardien = jour + visite ; promeneur = balade', () => {
    expect(prices.pricesFor(sitter, 'sitter')).toEqual({
      house_sitting: { amount: 18, unit: 'day' }, day_care: { amount: 18, unit: 'day' },
      home_visit: { amount: 12, unit: 'visit', durationMinutes: 30 },
    });
    expect(prices.pricesFor({ walkRates: [{ durationMinutes: 30, basePrice: 10 }] }, 'walker')).toEqual({ dog_walking: { amount: 10, unit: 'walk', durationMinutes: 30 } });
    expect(prices.pricesFor({ dailyRate: 18 }, 'sitter').home_visit).toBeUndefined();
  });
  test('priceFrom : compatible 604 (le plus bas) sans service ; par service avec `service`', () => {
    expect(prices.priceFromFor(sitter, 'sitter')).toEqual({ priceFrom: 5, priceUnit: 'hour' });
    expect(prices.priceFromFor(sitter, 'sitter', 'home_visit')).toEqual({ priceFrom: 12, priceUnit: 'visit' });
    expect(prices.priceFromFor(sitter, 'sitter', 'house_sitting')).toEqual({ priceFrom: 18, priceUnit: 'day' });
    expect(prices.priceFromFor({ dailyRate: 18 }, 'sitter', 'home_visit')).toEqual({ priceFrom: 0, priceUnit: '' });
    expect(prices.priceFromFor(sitter, 'owner')).toEqual({ priceFrom: 0, priceUnit: '' });
  });
});

describe('grille de tarifs (PUT profil)', () => {
  test('gardien : montants ≥ 0, durée 30|60, unité par défaut + visit', () => {
    expect(rates.applyRateFields({ dailyRate: '18', visitRate: 12.5, visitDurationMinutes: 60, defaultRateType: 'visit', bio: 'x' }, 'sitter'))
      .toEqual({ ok: true, update: { dailyRate: 18, visitRate: 12.5, visitDurationMinutes: 60, defaultRateType: 'visit' } });
    expect(rates.applyRateFields({ visitRate: -1 }, 'sitter').ok).toBe(false);
    expect(rates.applyRateFields({ visitDurationMinutes: 45 }, 'sitter').ok).toBe(false);
    expect(rates.applyRateFields({ defaultRateType: 'year' }, 'sitter').ok).toBe(false);
    expect(rates.applyRateFields({}, 'sitter')).toEqual({ ok: true, update: {} });
  });
  test('promeneur : walkRates', () => {
    const r = rates.applyRateFields({ walkRates: [{ durationMinutes: 60, basePrice: '15' }, { durationMinutes: 30, basePrice: 10 }] }, 'walker');
    expect(r.ok).toBe(true);
    expect(r.update.walkRates.map((w) => w.durationMinutes)).toEqual([30, 60]);
    expect(rates.applyRateFields({ walkRates: [{ durationMinutes: 20, basePrice: 1 }] }, 'walker').ok).toBe(false);
  });
});

describe('catalogue des 4 services', () => {
  test('GET /app-config/services : 4 services, unités, options, 9 langues', () => {
    const c = catalog.getServices620();
    expect(c.services.map((s) => `${s.key}:${s.unit}`)).toEqual(['house_sitting:day', 'home_visit:visit', 'day_care:day', 'dog_walking:walk']);
    const visit = c.services.find((s) => s.key === 'home_visit');
    expect(visit.durations).toEqual([30, 60]);
    expect(visit.visitsPerDay).toEqual([1, 2]);
    expect(c.services.find((s) => s.key === 'house_sitting').venues).toEqual(['owners_home', 'sitters_home']);
    expect(c.dateModes).toEqual(['exact', 'approx', 'tbd']);
    for (const s of c.services) {
      for (const l of LANGS) {
        expect(s.label[l]).toBeTruthy();
        expect(s.desc[l]).toBeTruthy();
        expect(s.unitLabel[l]).toBeTruthy();
      }
    }
    expect(catalog.SERVICE_KEYS).toContain('home_visit');
  });
});

describe('texte du prix dans « candidature reçue » (617) et nouveaux gabarits', () => {
  test('données brutes : indicatif = tarif unitaire, daté = total', () => {
    expect(text617.priceData620({ indicative: true, appliedRate: 12, unit: 'visit', currency: 'EUR' })).toEqual({ priceAmount: '12', priceUnit: 'visit', priceCurrency: 'EUR', priceIndicative: '1' });
    expect(text617.priceData620({ indicative: false, totalPrice: 86.4, currency: 'USD' })).toEqual({ priceAmount: '86.4', priceUnit: 'total', priceCurrency: 'USD', priceIndicative: '0' });
    expect(text617.priceData620({ indicative: true, appliedRate: 0 })).toEqual({});
  });
  test.each(LANGS)('%s : « 12 €/visite » et « 86,40 € au total », aucune variable restante, anciennes notifs sans prix intactes', (l) => {
    const t = require(`../src/locales/${l}/notifications.json`)[text617.TEMPLATE];
    const base = text617.applicationNewData617({ provider: { name: 'Paul Martin' }, pendingCount: 2 });
    const ind = text617.enrichPrice620({ ...base, ...text617.priceData620({ indicative: true, appliedRate: 12, unit: 'visit', currency: 'EUR' }) }, l);
    expect(ind.priceText).toContain('12 €/');
    const bodyInd = render(t.body, ind);
    expect(bodyInd).toContain('12 €/');
    expect(bodyInd).not.toMatch(/\{\{/);
    const tot = text617.enrichPrice620({ ...base, ...text617.priceData620({ indicative: false, totalPrice: 86.4, currency: 'USD' }) }, l);
    expect(tot.priceText).toContain('$86.4');
    const old = render(t.body, base); // notification d'avant le 620 : pas de prix, pas de trou
    expect(old).not.toMatch(/\{\{/);
    expect(old).toContain('2');
    expect(render(t.emailBody, { ...ind, emailLink: 'https://www.hopetsit.com/x' })).toContain('12 €/');
  });
  test.each(LANGS)('%s : application_pricing_updated + post_dates_required présents et rendus', (l) => {
    const all = require(`../src/locales/${l}/notifications.json`);
    for (const key of ['application_pricing_updated', 'post_dates_required']) {
      const t = all[key];
      expect(t).toBeTruthy();
      for (const f of ['title', 'body', 'emailSubject', 'emailBody']) {
        const out = render(t[f], { candidates: '2', emailLink: 'https://www.hopetsit.com/x' });
        expect(out).not.toMatch(/\{\{/);
        expect(out.length).toBeGreaterThan(3);
      }
      expect(render(t.body, { candidates: '2' })).toContain('2');
      expect(render(t.emailBody, { candidates: '2', emailLink: 'https://www.hopetsit.com/x' })).toContain('https://www.hopetsit.com/x');
    }
  });
  test('lien du bouton : application_pricing_updated → la candidature (propriétaire)', () => {
    const { buildEmailRoute, buildPreciseRoute } = require('../src/utils/emailLinkBuilder');
    expect(buildPreciseRoute('application_pricing_updated', { applicationId: 'a'.repeat(24), postId: 'b'.repeat(24) }, 'owner')).toBe(`/application/${'a'.repeat(24)}`);
    // sans appareil récent connu : repli sur la demande (même règle que application_new)
    expect(buildEmailRoute('application_pricing_updated', { applicationId: 'a'.repeat(24), postId: 'b'.repeat(24) }, { role: 'owner', devices: null })).toBe(`/post/${'b'.repeat(24)}`);
    expect(buildEmailRoute('post_dates_required', { postId: 'b'.repeat(24) }, { role: 'owner', devices: null })).toBe(`/post/${'b'.repeat(24)}`);
  });
});
