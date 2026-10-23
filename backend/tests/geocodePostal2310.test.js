/** 23/10 (BOB, ordre de Daniel) — code postal → position (Nominatim simulé, aucun réseau). */
const util = require('../src/utils/geocodePostal2310');
const nominatim = (lat, lon, city) => [{ lat: String(lat), lon: String(lon), address: { city } }];
let calls = [];
beforeEach(() => {
  util._resetForTest(); calls = [];
  global.fetch = jest.fn(async (url) => {
    calls.push(String(url));
    const u = new URL(String(url));
    const code = u.searchParams.get('postalcode'); const country = u.searchParams.get('country');
    if (code === '78370' && country === 'fr') return { ok: true, json: async () => nominatim(48.8125, 1.9468, 'Plaisir') };
    if (code === '10454' && country === 'us') return { ok: true, json: async () => nominatim(40.8077, -73.9184, 'New York') };
    return { ok: true, json: async () => [] };
  });
});
afterAll(() => { delete global.fetch; });

test('pays explicite, ville conservée si fournie, sinon celle du code postal', async () => {
  const a = await util.locationFromPostal('78370', { country: 'FR', city: 'Plaisir (78)' });
  expect(a).toEqual({ city: 'Plaisir (78)', lat: 48.8125, lng: 1.9468, postalCode: '78370' });
  const b = await util.locationFromPostal('78 370', { country: 'fr' });
  expect(b.city).toBe('Plaisir');
  expect(calls.length).toBe(1); // 2e appel servi par le cache
});
test('pays deviné de la langue : en → USA, fr → France', async () => {
  expect(util.guessCountry('', 'en', '10454')).toBe('us');
  expect(util.guessCountry('', 'fr', '78370')).toBe('fr');
  expect(util.guessCountry('', 'xx', '78370')).toBe('');
  const r = await util.geocodePostal('10454', { lang: 'en' });
  expect([r.city, r.lat, r.lng]).toEqual(['New York', 40.8077, -73.9184]);
});
test('code inconnu ou trop court → null, jamais d\'exception', async () => {
  expect(await util.geocodePostal('00000', { country: 'fr' })).toBeNull();
  expect(await util.geocodePostal('1', { country: 'fr' })).toBeNull();
  expect(await util.locationFromPostal('', { country: 'fr' })).toBeNull();
  global.fetch = jest.fn(async () => { throw new Error('réseau'); });
  util._resetForTest();
  expect(await util.geocodePostal('75001', { country: 'fr' })).toBeNull();
});
