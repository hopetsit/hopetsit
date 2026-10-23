// 23/10/2026 (PAM, build 619 — ordre de Daniel « code postal = position ») :
// PUT /users/me/profile { postalCode, country, city } → le code postal est mémorisé et la
// position du compte devient celle du code postal ; vide → effacé, position inchangée ;
// géocodage muet → position d'avant ; le reste du profil est enregistré comme avant.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const STORE = {
  Owner: { p1: { _id: 'p1', email: 'x@example.test', country: 'FR', appLocale: 'fr', city: 'Paris', preferences: {} } },
  Sitter: {},
  Walker: {},
};
function applySet(doc, set) {
  for (const [k, v] of Object.entries(set || {})) {
    const parts = k.split('.');
    let o = doc;
    for (const p of parts.slice(0, -1)) { o[p] = o[p] || {}; o = o[p]; }
    o[parts[parts.length - 1]] = v;
  }
}
const model = (name) => ({
  findByIdAndUpdate: jest.fn((id, ops) => {
    const d = STORE[name][id];
    if (!d) return Promise.resolve(null);
    applySet(d, ops.$set);
    if (ops.$unset && ops.$unset.location !== undefined) delete d.location;
    return Promise.resolve({ ...d, toObject() { return { ...d }; } });
  }),
  updateOne: jest.fn(() => ({ catch: () => null })),
  findById: jest.fn((id) => {
    const d = STORE[name][id] || null;
    return { select: () => ({ lean: () => Promise.resolve(d ? { ...d } : null) }), lean: () => Promise.resolve(d ? { ...d } : null) };
  }),
});
jest.mock('../src/models/Owner', () => model('Owner'));
jest.mock('../src/models/Sitter', () => model('Sitter'));
jest.mock('../src/models/Walker', () => model('Walker'));
jest.mock('../src/config/firebaseAdmin', () => ({}));
jest.mock('../src/services/loyaltyService', () => ({ getOwnerStats: jest.fn(async () => ({})) }));
jest.mock('../src/services/referralService', () => ({ getMyReferrals: jest.fn(async () => ({})) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn() }));
jest.mock('../src/utils/sharedIdentity', () => ({ propagateSharedIdentity: jest.fn(() => Promise.resolve()) }));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn(() => Promise.resolve({ ids: ['p1'], set: new Set(['p1']), docs: [{ id: 'p1', model: 'Owner' }] })),
}));
const geo = { calls: [] };
jest.mock('../src/utils/geocodePostal2310', () => ({
  cleanCode: (v) => String(v == null ? '' : v).toUpperCase().replace(/[^0-9A-Z]/g, '').slice(0, 10),
  locationFromPostal: jest.fn(async (code, opts) => {
    geo.calls.push({ code, opts });
    if (code === '75011') return { city: opts.city || 'Paris', lat: 48.8594, lng: 2.3765, postalCode: code };
    if (code === '10454') return { city: 'New York', lat: 40.8077, lng: -73.9184, postalCode: code };
    return null;
  }),
}));

const { updateProfile } = require('../src/controllers/userController');

function put(body) {
  return new Promise((resolve, reject) => {
    const req = { params: { id: 'p1' }, user: { id: 'p1', role: 'owner' }, body, headers: {} };
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(updateProfile(req, res)).catch(reject);
  });
}

test('code postal seul : mémorisé, position = code postal, ville conservée', async () => {
  const r = await put({ postalCode: '75011' });
  expect(r.status).toBe(200);
  const d = STORE.Owner.p1;
  expect(d.postalCode).toBe('75011');
  expect(d.location.coordinates).toEqual([2.3765, 48.8594]);
  expect(d.location.city).toBe('Paris');
  expect(d.city).toBe('Paris');
  // pays et langue du compte transmis au géocodeur (l'app n'envoie pas toujours le pays)
  expect(geo.calls[0].opts.country).toBe('FR');
  expect(geo.calls[0].opts.lang).toBe('fr');
  // la réponse porte la position : l'app rafraîchit le profil et la PawMap sans redémarrer
  expect(r.body.user.postalCode).toBe('75011');
  expect(r.body.user.location.coordinates).toEqual([2.3765, 48.8594]);
});

test('code postal + ville + pays envoyés par l\'app : le pays envoyé prime, la ville saisie est gardée', async () => {
  const r = await put({ postalCode: '10454', country: 'US', city: 'Bronx' });
  expect(r.status).toBe(200);
  const d = STORE.Owner.p1;
  expect(geo.calls[1].opts.country).toBe('US');
  expect(d.location.coordinates).toEqual([-73.9184, 40.8077]);
  expect(d.city).toBe('Bronx');
  expect(d.postalCode).toBe('10454');
});

test('code postal gagne sur une position GPS envoyée dans le même appel (même règle qu\'à l\'inscription)', async () => {
  const r = await put({ postalCode: '75011', location: { lat: -35.2, lng: -30.4, city: 'Zone test' } });
  expect(r.status).toBe(200);
  expect(STORE.Owner.p1.location.coordinates).toEqual([2.3765, 48.8594]);
});

test('code postal inconnu : position d\'avant conservée, code mémorisé quand même, 200', async () => {
  const before = STORE.Owner.p1.location.coordinates.slice();
  const r = await put({ postalCode: '00000', bio: 'Bonjour' });
  expect(r.status).toBe(200);
  expect(STORE.Owner.p1.location.coordinates).toEqual(before);
  expect(STORE.Owner.p1.postalCode).toBe('00000');
  expect(STORE.Owner.p1.bio).toBe('Bonjour');
});

test('code postal vide : effacé, position inchangée ; nettoyage « 75 011 » → 75011', async () => {
  const before = STORE.Owner.p1.location.coordinates.slice();
  let r = await put({ postalCode: '' });
  expect(r.status).toBe(200);
  expect(STORE.Owner.p1.postalCode).toBe('');
  expect(STORE.Owner.p1.location.coordinates).toEqual(before);
  r = await put({ postalCode: ' 75 011 ' });
  expect(STORE.Owner.p1.postalCode).toBe('75011');
});

test('sans postalCode dans le corps : rien ne change (ancienne app)', async () => {
  const n = geo.calls.length;
  const r = await put({ bio: 'Salut' });
  expect(r.status).toBe(200);
  expect(geo.calls.length).toBe(n);
  expect(STORE.Owner.p1.postalCode).toBe('75011');
});
