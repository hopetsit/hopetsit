// 610 (PAM, 04/10/2026) — Daniel : « réparer tout maintenant ». Mesuré au
// simulateur : le mode nuit choisi sur l'appareil A était effacé dès que
// l'appareil B bougeait sa carte (bloc `pawMap` réécrit en entier).
// Règle : seules les clés reçues sont écrites, chacune avec son horodatage ;
// une valeur plus ancienne que celle enregistrée est ignorée. Aucune base.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const STORE = { Owner: {}, Sitter: {}, Walker: {} };
function applySet(doc, set) {
  for (const [path, v] of Object.entries(set || {})) {
    const parts = path.split('.');
    let o = doc;
    for (const p of parts.slice(0, -1)) {
      if (o[p] === undefined || o[p] === null) o[p] = {};
      o = o[p];
    }
    o[parts[parts.length - 1]] = JSON.parse(JSON.stringify(v));
  }
}
const chain = (v) => ({ select: () => chain(v), lean: () => Promise.resolve(v ? JSON.parse(JSON.stringify(v)) : v), catch: () => chain(v) });
const model = (name) => ({
  findById: jest.fn((id) => chain(STORE[name][id] || null)),
  updateOne: jest.fn((q, ops) => { const d = STORE[name][q._id]; if (d) applySet(d, ops.$set); return Promise.resolve({}); }),
});
jest.mock('../src/models/Owner', () => model('Owner'));
jest.mock('../src/models/Sitter', () => model('Sitter'));
jest.mock('../src/models/Walker', () => model('Walker'));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
jest.mock('../src/utils/identityGroup', () => ({
  identityGroup: jest.fn(() => Promise.resolve({ ids: ['o1', 's1'], docs: [{ id: 'o1', model: 'Owner' }, { id: 's1', model: 'Sitter' }] })),
}));

const ctl = require('../src/controllers/mapPrefsController');

function call(fn, user, body) {
  return new Promise((resolve, reject) => {
    const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); } };
    Promise.resolve(fn({ user, body, query: {}, headers: {} }, res)).catch(reject);
  });
}
const OWNER = { id: 'o1', role: 'owner' };
const SITTER = { id: 's1', role: 'sitter' };
const iso = (s) => new Date(Date.now() - s * 1000).toISOString();

beforeEach(() => {
  STORE.Owner.o1 = { _id: 'o1', preferences: { pawMap: { nightMode: false, layers: { everyone: true, pawspots: true }, rail: ['around', 'spots'] } } };
  STORE.Sitter.s1 = { _id: 's1', preferences: { pawMap: { nightMode: false, layers: { everyone: true, pawspots: true }, rail: ['around', 'spots'] } } };
});

test('A choisit le mode nuit, B bouge la carte → la nuit est GARDÉE (les 2 profils)', async () => {
  await call(ctl.updateMapPrefs, OWNER, { pawMap: { nightMode: true }, pawMapAt: { nightMode: iso(10) } });
  // B (app 610) n'envoie QUE sa caméra.
  await call(ctl.updateMapPrefs, SITTER, { pawMap: { camera: { lat: -35, lng: -30, zoom: 12 } }, pawMapAt: { camera: iso(1) } });
  for (const d of [STORE.Owner.o1, STORE.Sitter.s1]) {
    expect(d.preferences.pawMap.nightMode).toBe(true);
    expect(d.preferences.pawMap.camera).toEqual({ lat: -35, lng: -30, zoom: 12 });
    expect(d.preferences.pawMap.rail).toEqual(['around', 'spots']);
  }
  const r = await call(ctl.getMapPrefs, SITTER, {});
  expect(r.body.pawMap.nightMode).toBe(true);
  expect(typeof r.body.pawMap.fieldAt.nightMode).toBe('string');
});

test('un bloc PÉRIMÉ (nuit éteinte plus ancienne) ne réécrit pas la nuit allumée après', async () => {
  await call(ctl.updateMapPrefs, OWNER, { pawMap: { nightMode: true }, pawMapAt: { nightMode: iso(10) } });
  await call(ctl.updateMapPrefs, SITTER, {
    pawMap: { nightMode: false, camera: { lat: -35, lng: -30, zoom: 12 } },
    pawMapAt: { nightMode: iso(60), camera: iso(1) },
  });
  expect(STORE.Owner.o1.preferences.pawMap.nightMode).toBe(true);
  expect(STORE.Owner.o1.preferences.pawMap.camera.zoom).toBe(12);
});

test('couches : changer « tout le monde » ne touche pas PawSpot, et inversement', async () => {
  await call(ctl.updateMapPrefs, OWNER, { pawMap: { layers: { everyone: false } }, pawMapAt: { layers__everyone: iso(5) } });
  await call(ctl.updateMapPrefs, SITTER, { pawMap: { layers: { pawspots: false } }, pawMapAt: { layers__pawspots: iso(2) } });
  expect(STORE.Owner.o1.preferences.pawMap.layers).toEqual({ everyone: false, pawspots: false });
  expect(STORE.Sitter.s1.preferences.pawMap.layers).toEqual({ everyone: false, pawspots: false });
});

test('ordre des barres et filtres : chacun son champ, rien d\'autre ne bouge', async () => {
  await call(ctl.updateMapPrefs, OWNER, { pawMap: { rail: ['spots', 'around'] } });
  await call(ctl.updateMapPrefs, SITTER, { pawMap: { verifiedOnly: true, memberRoles: ['sitter'] } });
  const pm = STORE.Owner.o1.preferences.pawMap;
  expect(pm.rail).toEqual(['spots', 'around']);
  expect(pm.verifiedOnly).toBe(true);
  expect(pm.memberRoles).toEqual(['sitter']);
  expect(pm.nightMode).toBe(false);
  expect(pm.layers).toEqual({ everyone: true, pawspots: true });
});

test('compte sans bloc encore : créé avec les seules clés reçues', async () => {
  STORE.Owner.o1 = { _id: 'o1', preferences: {} };
  STORE.Sitter.s1 = { _id: 's1', preferences: { pawMap: null } };
  await call(ctl.updateMapPrefs, OWNER, { pawMap: { nightMode: true, layers: { plush: false } } });
  for (const d of [STORE.Owner.o1, STORE.Sitter.s1]) {
    expect(d.preferences.pawMap.nightMode).toBe(true);
    expect(d.preferences.pawMap.layers).toEqual({ plush: false });
    expect(d.preferences.pawMap.camera).toBeUndefined();
  }
});

test('valeurs invalides toujours refusées (validation inchangée)', async () => {
  await call(ctl.updateMapPrefs, OWNER, { pawMap: { nightMode: 'oui', layers: { inconnu: true, everyone: 'x' } } });
  expect(STORE.Owner.o1.preferences.pawMap.nightMode).toBe(false);
  expect(STORE.Owner.o1.preferences.pawMap.layers).toEqual({ everyone: true, pawspots: true });
});
