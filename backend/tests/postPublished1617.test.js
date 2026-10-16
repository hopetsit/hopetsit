// 1617 (LEO, 16/10/2026, complément BOB au §D.1) — notification `post_published_617`
// au PROPRIÉTAIRE dès la publication : cloche + téléphone, jamais d'e-mail.
// Vrai createPost sur base Mongo en mémoire ; FCM et socket captés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

const mockPush = jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: (m) => mockPush(m) }) }));
const mockEmit = jest.fn();
jest.mock('../src/sockets/emitter', () => ({ emitToUser: (...a) => mockEmit(...a), isUserOnline: () => false }));
jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { publishedText, TEXTS, LANGS, TYPE } = require('../src/utils/postPublished1617');

let mongo; let Post; let Owner; let Sitter; let Notification; let postController;
let ownerId; let ownerEn; let sitterTest;
const mockRes = () => { const res = {}; res.status = jest.fn(() => res); res.json = jest.fn((b) => { res.body = b; return res; }); return res; };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const publish = async (who, over = {}) => {
  const res = mockRes();
  await postController.createPost({
    user: { id: who, role: 'owner' },
    body: { body: 'Garde de Rex', serviceTypes: ['pet_sitting'], startDate: '2026-11-20T09:00:00.000Z', endDate: '2026-11-22T09:00:00.000Z',
      location: { city: 'Zone test', lat: -35, lng: -30 }, ...over },
  }, res);
  // L'envoi au propriétaire suit la réponse (setImmediate) : on attend la cloche (3 s au plus).
  for (let i = 0; i < 30; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await wait(100);
    // eslint-disable-next-line no-await-in-loop
    if (await Notification.countDocuments({ recipientId: who, type: TYPE })) break;
  }
  return res;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post'); Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter');
  Notification = require('../src/models/Notification');
  postController = require('../src/controllers/postController');
  ownerId = (await Owner.collection.insertOne({ name: 'Nicola', email: 'nicola-pub1617@example.test', appLocale: 'fr', status: 'active', verified: true, fcmTokens: ['tok-owner-1'], location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' } })).insertedId.toString();
  ownerEn = (await Owner.collection.insertOne({ name: 'Jane', email: 'jane-pub1617@example.test', appLocale: 'en', status: 'active', verified: true, notificationPrefs: { sound: 'frog', categories: { bookings: false } }, fcmTokens: ['tok-jane'], location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' } })).insertedId.toString();
  // Un gardien (compte neutre) dans la zone fictive : prévenu → N = 1.
  sitterTest = (await Sitter.collection.insertOne({ name: 'Ines', email: 'ines-pub1617@example.test', status: 'active', verified: true, location: { type: 'Point', coordinates: [-30.01, -35.01], city: 'Zone test' } })).insertedId;
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => { await Post.deleteMany({}); await Notification.deleteMany({}); mockPush.mockClear(); mockEmit.mockClear(); });

test('textes purs : 9 langues, singulier/pluriel, gardien vs promeneur, N = 0', () => {
  expect(LANGS.sort()).toEqual(['de', 'en', 'es', 'fr', 'it', 'ja', 'ko', 'pl', 'pt']);
  for (const l of LANGS) for (const k of ['title', 'some_sitter', 'one_sitter', 'some_walker', 'one_walker', 'none_sitter', 'none_walker']) expect(TEXTS[l][k]).toBeTruthy();
  expect(publishedText({ lang: 'fr', notified: 3, radiusKm: 100, role: 'sitter' }).body).toBe('3 gardiens à moins de 100 km ont été prévenus · en général ils répondent dans la journée');
  expect(publishedText({ lang: 'fr', notified: 1, radiusKm: 100, role: 'walker' }).body).toMatch(/^1 promeneur à moins de 100 km a été prévenu/);
  expect(publishedText({ lang: 'fr', notified: 0, radiusKm: 100, role: 'sitter' }).body).toBe('Aucun gardien près de chez toi pour l’instant : partage ton annonce');
  expect(publishedText({ lang: 'en', notified: 0, radiusKm: 100, role: 'walker' }).body).toBe('No walker near you yet: share your request');
  expect(publishedText({ lang: 'zz', notified: 2, radiusKm: 100, role: 'sitter' }).body).toMatch(/^2 sitters within 100 km/);
  expect(publishedText({ lang: 'de', notified: 2, radiusKm: 100, role: 'sitter' }).body).not.toMatch(/\{n\}|\{km\}/);
});

test('publication avec 1 gardien autour : cloche « 1 gardien … prévenu », socket, push (sans e-mail), data complet', async () => {
  const res = await publish(ownerId);
  expect(res.status).toHaveBeenCalledWith(201);
  expect(res.body.notified).toBe(1);
  const bell = await Notification.findOne({ recipientRole: 'owner', recipientId: ownerId, type: TYPE }).lean();
  expect(bell).toBeTruthy();
  expect(bell.title).toBe('Ta demande est publiée');
  expect(bell.body).toMatch(/^1 gardien à moins de 100 km a été prévenu/);
  expect(bell.data).toMatchObject({ postId: res.body.post.id, notified: 1, alertRadiusKm: 100, role: 'sitter' });
  const sock = mockEmit.mock.calls.find((c) => c[0] === 'owner' && String(c[1]) === ownerId && c[2] === 'notification.new');
  expect(sock).toBeTruthy();
  expect(sock[3].type).toBe(TYPE);
  expect(sock[3].id).toBe(String(bell._id));
  const push = mockPush.mock.calls.map((c) => c[0]).find((m) => m.tokens.includes('tok-owner-1'));
  expect(push).toBeTruthy();
  expect(push.notification.body).toBe(bell.body);
  expect(push.data.type).toBe(TYPE);
  expect(push.data.route).toBe(`/post/${res.body.post.id}`);
  expect(push.data.notified).toBe('1');
  expect(sitterTest).toBeTruthy();
}, 20000);

test('N = 0 (balade : aucun promeneur autour) : « Aucun promeneur … partage ton annonce »', async () => {
  const res = await publish(ownerId, { serviceTypes: ['dog_walking'], serviceLocation: 'pickup' });
  expect(res.body.notified).toBe(0);
  const bell = await Notification.findOne({ recipientId: ownerId, type: TYPE }).lean();
  expect(bell.body).toBe('Aucun promeneur près de chez toi pour l’instant : partage ton annonce');
  expect(bell.data.role).toBe('walker');
}, 20000);

test('catégorie « Réservations » coupée : cloche oui, téléphone non ; langue EN', async () => {
  await publish(ownerEn);
  const bell = await Notification.findOne({ recipientId: ownerEn, type: TYPE }).lean();
  expect(bell.title).toBe('Your request is live');
  expect(mockPush.mock.calls.map((c) => c[0]).find((m) => m.tokens.includes('tok-jane'))).toBeUndefined();
}, 20000);

test('republication déjà prévenue (registre 612 : same_request) → aucune 2e notification au propriétaire', async () => {
  await publish(ownerId);
  await Post.deleteMany({}); // la demande est supprimée puis republiée à l'identique
  await Notification.deleteMany({});
  const res = await publish(ownerId);
  expect(res.status).toHaveBeenCalledWith(201);
  expect(res.body.notified).toBe(0); // le gardien a déjà reçu cette demande
  expect(await Notification.countDocuments({ recipientId: ownerId, type: TYPE })).toBe(0);
}, 20000);
