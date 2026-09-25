// v587 — BUDGET d'une demande (option A, décision de Daniel du 25/09) : champ
// facultatif « Mon budget » (montant + devise du propriétaire) dans « Publier
// une annonce », stocké (Post.budget / Post.budgetCurrency) et renvoyé par les
// routes des demandes (nearby, by-owner, /posts). VRAIE base Mongo en mémoire,
// vrais gestionnaires, zone fictive (lat -35 / lng -30), aucun réseau.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({
  uploadMedia: jest.fn(async () => ({ url: 'https://example.test/p.jpg', secure_url: 'https://example.test/p.jpg', public_id: 'p', publicId: 'p' })),
}));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { resolveBudget, publicBudget } = require('../src/utils/postBudget587');

let mongo;
let Post;
let postController;
let ownerActive;
let ownerId;
let walkerId;

const mockRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn((b) => { res.body = b; return res; });
  return res;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post');
  const Owner = require('../src/models/Owner');
  const Walker = require('../src/models/Walker');
  postController = require('../src/controllers/postController');
  ownerActive = require('../src/controllers/ownerActiveRequestsController');
  const r = await Owner.collection.insertOne({
    name: 'Budget 587', email: 'budget587@example.test', language: 'fr', currency: 'USD',
    location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
  });
  ownerId = r.insertedId.toString();
  const w = await Walker.collection.insertOne({
    name: 'Promeneur 587', email: 'walker587@example.test',
    location: { type: 'Point', coordinates: [-30.01, -35], city: 'Zone test' },
  });
  walkerId = w.insertedId.toString();
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

const publish = async (extra) => {
  const res = mockRes();
  await postController.createPost({ user: { id: ownerId, role: 'owner' }, body: {
    body: 'Annonce budget 587', serviceTypes: ['dog_walking'], serviceLocation: 'pickup',
    startDate: '2026-12-01T09:00:00.000Z', endDate: '2026-12-01T10:00:00.000Z',
    location: { city: 'Zone test', lat: -35, lng: -30 }, ...extra,
  } }, res);
  return res;
};

describe('resolveBudget / publicBudget — règle pure', () => {
  test('absent → rien à écrire (ancienne app)', () => {
    expect(resolveBudget({}, 'EUR')).toEqual({});
  });
  test('montant (nombre, texte, virgule) + devise du propriétaire par défaut', () => {
    expect(resolveBudget({ budget: 35 }, 'EUR')).toEqual({ budget: 35, budgetCurrency: 'EUR' });
    expect(resolveBudget({ budget: '12,5' }, 'usd')).toEqual({ budget: 12.5, budgetCurrency: 'USD' });
    expect(resolveBudget({ budget: '40', budgetCurrency: 'gbp' }, 'EUR')).toEqual({ budget: 40, budgetCurrency: 'GBP' });
    expect(resolveBudget({ budget: 20, budgetCurrency: 'XXX' }, null)).toEqual({ budget: 20, budgetCurrency: 'EUR' });
  });
  test('vide / 0 / négatif / texte → effacé, jamais « 0 € »', () => {
    for (const v of ['', 0, '0', -5, 'abc', null]) {
      expect(resolveBudget({ budget: v }, 'EUR')).toEqual({ budget: null, budgetCurrency: '' });
    }
    expect(publicBudget({ budget: null })).toEqual({ budget: 0, budgetCurrency: '' });
  });
});

describe('createPost / updatePost / routes des demandes (vrais gestionnaires)', () => {
  let withBudget;
  let noBudget;

  test('publier AVEC budget : stocké et renvoyé', async () => {
    const res = await publish({ budget: '35', budgetCurrency: 'EUR' });
    expect(res.status).toHaveBeenCalledWith(201);
    withBudget = res.body.post.id;
    expect(res.body.post.budget).toBe(35);
    expect(res.body.post.budgetCurrency).toBe('EUR');
    const stored = await Post.findById(withBudget).lean();
    expect(stored.budget).toBe(35);
    expect(stored.budgetCurrency).toBe('EUR');
  });

  test('publier SANS budget : 0 et devise vide (l\'app montre l\'icône)', async () => {
    const res = await publish({});
    noBudget = res.body.post.id;
    expect(res.body.post.budget).toBe(0);
    expect(res.body.post.budgetCurrency).toBe('');
  });

  test('devise absente → celle du propriétaire (USD)', async () => {
    const res = await publish({ budget: 20 });
    expect(res.body.post.budgetCurrency).toBe('USD');
  });

  test('avec photo (multipart) : le budget n\'est pas perdu', async () => {
    const res = mockRes();
    await postController.createPostWithMedia({
      user: { id: ownerId, role: 'owner' },
      body: {
        body: 'Annonce photo budget', serviceTypes: 'dog_walking', serviceLocation: 'pickup',
        startDate: '2026-12-02T09:00:00.000Z', endDate: '2026-12-02T10:00:00.000Z',
        budget: '18', budgetCurrency: 'EUR',
        location: JSON.stringify({ city: 'Zone test', lat: -35, lng: -30 }),
      },
      files: { images: [{ fieldname: 'images', originalname: 'p.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('x') }] },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.body.post.budget).toBe(18);
  });

  test('demandes près de moi (bulle PawMap) : budget + devise', async () => {
    const res = mockRes();
    await postController.getNearbyRequestPosts({
      user: { id: walkerId, role: 'walker' }, query: { lat: '-35', lng: '-30', radiusKm: '10' }, headers: {},
    }, res);
    const posts = (res.body && res.body.posts) || [];
    const a = posts.find((p) => String(p.id) === String(withBudget));
    const b = posts.find((p) => String(p.id) === String(noBudget));
    expect(a && a.budget).toBe(35);
    expect(a && a.budgetCurrency).toBe('EUR');
    expect(b && b.budget).toBe(0);
    expect(b && b.budgetCurrency).toBe('');
  });

  test('demandes d\'un propriétaire (fiche) : budget + devise', async () => {
    const res = mockRes();
    await ownerActive.getOwnerActiveRequests({
      user: { id: walkerId, role: 'walker' }, params: { ownerId }, query: {}, headers: {},
    }, res);
    const a = (res.body.posts || []).find((p) => String(p.id) === String(withBudget));
    expect(a && a.budget).toBe(35);
    expect(a && a.budgetCurrency).toBe('EUR');
  });

  test('modifier : nouveau montant, puis vide = effacé ; absent = inchangé', async () => {
    const upd = async (body) => {
      const res = mockRes();
      await postController.updatePost({ user: { id: ownerId, role: 'owner' }, params: { id: withBudget }, body }, res);
      return Post.findById(withBudget).lean();
    };
    expect((await upd({ budget: 40 })).budget).toBe(40);
    expect((await upd({ notes: 'rien sur le budget' })).budget).toBe(40);
    const cleared = await upd({ budget: '' });
    expect(cleared.budget).toBeNull();
    expect(cleared.budgetCurrency).toBe('');
  });
});
