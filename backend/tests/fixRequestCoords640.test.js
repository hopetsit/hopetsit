// 640 — position posée UNE fois sur la demande de São Paulo (accord de Daniel).
// Aucune base, aucun réseau : faux `db`, faux modèle, vraie table des villes.
const { runFixRequestCoords640, coordsToSet640, POST_IDS_640, KEY_640 } = require('../src/scripts/fixRequestCoords640');
const { coordsOf640 } = require('../src/utils/feedNoCoords640');
const { peekCity } = require('../src/utils/geocodeCity');

function fakeDb(done = false) {
  const rows = new Map();
  if (done) rows.set(KEY_640, { _id: KEY_640 });
  return {
    rows,
    collection: () => ({
      findOne: async ({ _id }) => rows.get(_id) || null,
      insertOne: async (doc) => { rows.set(doc._id, doc); },
    }),
  };
}

function fakePost(docs) {
  const calls = [];
  return {
    calls,
    findById: (id) => ({ select: () => ({ lean: async () => docs[id] || null }) }),
    updateOne: async (filter, update, options) => { calls.push({ filter, update, options }); return { modifiedCount: 1 }; },
  };
}

const quiet = { info: () => {}, error: () => {} };
const ID = POST_IDS_640[0];

describe('coordsToSet640 (règle pure)', () => {
  test('São Paulo sans position → centre de São Paulo (table fixe du serveur)', () => {
    const p = coordsToSet640({ city: 'São Paulo' }, peekCity, coordsOf640);
    expect(p).not.toBeNull();
    expect(p.lat).toBeGreaterThan(-24.2);
    expect(p.lat).toBeLessThan(-23.2);
    expect(p.lng).toBeGreaterThan(-47.2);
    expect(p.lng).toBeLessThan(-46.2);
  });
  test('variantes d\'écriture de la ville', () => {
    for (const city of ['Sao Paulo', 'São Paulo - SP', 'Sao Paulo/SP, Brasil']) {
      expect(coordsToSet640({ city }, peekCity, coordsOf640)).not.toBeNull();
    }
  });
  test('position déjà présente → rien', () => {
    expect(coordsToSet640({ city: 'São Paulo', lat: 1.5, lng: 2.5 }, peekCity, coordsOf640)).toBeNull();
  });
  test('pas de ville, ville inconnue de la table, objet invalide → rien', () => {
    expect(coordsToSet640({ city: '' }, peekCity, coordsOf640)).toBeNull();
    expect(coordsToSet640({ city: 'Ville qui n existe pas 640' }, peekCity, coordsOf640)).toBeNull();
    expect(coordsToSet640(null, peekCity, coordsOf640)).toBeNull();
    expect(coordsToSet640([], peekCity, coordsOf640)).toBeNull();
    expect(coordsToSet640({ city: 'x' }, () => { throw new Error('boom'); }, coordsOf640)).toBeNull();
  });
});

describe('runFixRequestCoords640', () => {
  const OLD = process.env.FIX_REQUEST_COORDS_640;
  afterEach(() => {
    if (OLD === undefined) delete process.env.FIX_REQUEST_COORDS_640; else process.env.FIX_REQUEST_COORDS_640 = OLD;
  });

  test('une seule annonce visée', () => {
    expect(POST_IDS_640).toHaveLength(1);
    expect(ID).toMatch(/^[0-9a-f]{24}$/);
  });

  test('pose lat/lng/geocoded, rien d\'autre, sans changer la date de modification', async () => {
    const db = fakeDb();
    const Post = fakePost({ [ID]: { _id: ID, postType: 'request', location: { city: 'São Paulo' } } });
    const stats = await runFixRequestCoords640(db, quiet, { Post });
    expect(stats).toEqual({ found: 1, alreadySet: 0, cityUnknown: 0, updated: 1 });
    expect(Post.calls).toHaveLength(1);
    const { filter, update, options } = Post.calls[0];
    expect(filter._id).toBe(ID);
    expect(Object.keys(update)).toEqual(['$set']);
    expect(Object.keys(update.$set).sort()).toEqual(['location.geocoded', 'location.lat', 'location.lng']);
    expect(update.$set['location.geocoded']).toBe(true);
    expect(coordsOf640({ lat: update.$set['location.lat'], lng: update.$set['location.lng'] })).not.toBeNull();
    expect(options).toEqual({ timestamps: false });
    expect(db.rows.has(KEY_640)).toBe(true);
  });

  test('deuxième démarrage : marqueur présent → aucune écriture', async () => {
    const db = fakeDb(true);
    const Post = fakePost({ [ID]: { _id: ID, location: { city: 'São Paulo' } } });
    expect(await runFixRequestCoords640(db, quiet, { Post })).toBeNull();
    expect(Post.calls).toHaveLength(0);
  });

  test('annonce déjà positionnée → aucune écriture', async () => {
    const db = fakeDb();
    const Post = fakePost({ [ID]: { _id: ID, location: { city: 'São Paulo', lat: -23.5, lng: -46.6 } } });
    const stats = await runFixRequestCoords640(db, quiet, { Post });
    expect(stats.alreadySet).toBe(1);
    expect(Post.calls).toHaveLength(0);
  });

  test('annonce supprimée ou ville inconnue → aucune écriture', async () => {
    const gone = fakePost({});
    expect((await runFixRequestCoords640(fakeDb(), quiet, { Post: gone })).found).toBe(0);
    expect(gone.calls).toHaveLength(0);
    const odd = fakePost({ [ID]: { _id: ID, location: { city: 'Ville qui n existe pas 640' } } });
    expect((await runFixRequestCoords640(fakeDb(), quiet, { Post: odd })).cityUnknown).toBe(1);
    expect(odd.calls).toHaveLength(0);
  });

  test('coupe-circuit FIX_REQUEST_COORDS_640=off → rien, pas de marqueur', async () => {
    process.env.FIX_REQUEST_COORDS_640 = 'off';
    const db = fakeDb();
    const Post = fakePost({ [ID]: { _id: ID, location: { city: 'São Paulo' } } });
    expect(await runFixRequestCoords640(db, quiet, { Post })).toBeNull();
    expect(Post.calls).toHaveLength(0);
    expect(db.rows.size).toBe(0);
  });

  test('une panne ne remonte jamais (non bloquant)', async () => {
    const db = { collection: () => { throw new Error('base coupée'); } };
    await expect(runFixRequestCoords640(db, quiet, {})).resolves.toBeNull();
  });
});
