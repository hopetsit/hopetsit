// v600 NEO (29/09/2026, GO de Daniel) — publier une demande SANS animal
// enregistré : l'app envoie `petIds: []` + `animalTypes` / `animalCount`
// (comme le site). Le serveur ne change pas ; ce test verrouille qu'il
// ACCEPTE ce cas (201), garde espèces + nombre, et prévient quand même les
// prestataires de la ville. Vraie base Mongo en mémoire, zone fictive
// (lat -35 / lng -30), aucun réseau (géocodage simulé).
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
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  return { ...actual, geocodeCity: jest.fn(async () => null) };
});

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { sendNotification } = require('../src/services/notificationSender');

let mongo;
let Post;
let postController;
let ownerId;
let sitterId;

const mockRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn((b) => { res.body = b; return res; });
  return res;
};

// 612 — l'alerte fait plus de lectures (blocages, désabonnements, registre) : on attend
// que le nombre d'envois ne bouge plus pendant 300 ms (3 s au plus).
const flush = async () => {
  let last = -1; let stable = 0;
  for (let i = 0; i < 60 && stable < 6; i += 1) {
    await new Promise((r) => setTimeout(r, 50));
    const n = sendNotification.mock.calls.length;
    stable = n === last ? stable + 1 : 0;
    last = n;
  }
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post');
  const Owner = require('../src/models/Owner');
  const Sitter = require('../src/models/Sitter');
  postController = require('../src/controllers/postController');
  await require('../src/models/RequestAlert612').init(); // 612 — index du registre prêts avant le 1er envoi
  const o = await Owner.collection.insertOne({
    name: 'Marie', email: 'marie600@example.test', language: 'fr', currency: 'EUR',
    location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
  });
  ownerId = o.insertedId.toString();
  const s = await Sitter.collection.insertOne({
    name: 'Nina', email: 'nina600@example.test',
    location: { type: 'Point', coordinates: [-30.01, -35], city: 'Zone test' },
  });
  sitterId = s.insertedId.toString();
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

// 612 — registre des alertes vidé entre les cas : ces tests republient la MÊME demande
// (même propriétaire, service, ville, dates), que la production ne renvoie plus (voir requestAlert612.test.js).
beforeEach(async () => { sendNotification.mockClear(); await require('mongoose').connection.collection('requestalerts612').deleteMany({}); });

const publish = async (extra) => {
  const res = mockRes();
  await postController.createPost({ user: { id: ownerId, role: 'owner' }, body: {
    body: 'Garde de mes deux chiens', serviceTypes: ['pet_sitting'], serviceLocation: 'at_owner',
    startDate: '2026-12-01T08:00:00.000Z', endDate: '2026-12-02T20:00:00.000Z',
    location: { city: 'Zone test', lat: -35, lng: -30 }, ...extra,
  } }, res);
  await flush();
  return res;
};

describe('POST /posts sans animal enregistré (app 600)', () => {
  test('petIds vide + animalTypes / animalCount → 201, espèces et nombre gardés, ville prévenue', async () => {
    const res = await publish({ petIds: [], animalCount: 2, animalTypes: ['dog', 'cat'] });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.body.post).toBeTruthy();
    const saved = await Post.findById(res.body.post.id || res.body.post._id).lean();
    expect(saved).toBeTruthy();
    // 612 (ZOE) — une demande a toujours un animal : sans cela aucun prestataire
    // ne pouvait postuler (mesuré). Fiche minimale créée depuis l'espèce déclarée.
    expect(saved.petIds || []).toHaveLength(1);
    const autoPet = await require('../src/models/Pet').findById(saved.petIds[0]).lean();
    expect(autoPet).toMatchObject({ petName: 'Chien', category: 'dog', autoCreated: true });
    expect(saved.animalTypes).toEqual(['dog', 'cat']);
    expect(saved.animalCount).toBe(2);
    expect(saved.postType).toBe('request');
    const nearby = sendNotification.mock.calls.map((c) => c[0]).filter((n) => n.type === 'new_request_nearby');
    expect(nearby.map((n) => `${n.role}:${n.userId}`)).toContain(`sitter:${sitterId}`);
  });

  test('forme multipart de l\'app (JSON en texte, nombre en texte) : même résultat', async () => {
    const res = await publish({ petIds: '[]', animalCount: '1', animalTypes: '["dog"]' });
    expect(res.status).toHaveBeenCalledWith(201);
    const saved = await Post.findById(res.body.post.id || res.body.post._id).lean();
    expect(saved.animalTypes).toEqual(['dog']);
    expect(saved.animalCount).toBe(1);
  });

  test('sans petIds du tout, ni animalTypes : la demande passe quand même (rien de bloquant côté serveur)', async () => {
    const res = await publish({});
    expect(res.status).toHaveBeenCalledWith(201);
    const saved = await Post.findById(res.body.post.id || res.body.post._id).lean();
    expect(saved.animalTypes || []).toHaveLength(0);
    expect(saved.animalCount || 0).toBe(0);
  });
});
