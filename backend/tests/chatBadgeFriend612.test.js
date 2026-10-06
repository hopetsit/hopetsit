// 612 (ZOE, 05/10/2026) — Daniel : « notification message dans le menu, surtout sur
// Apple, n'apparaît pas, que dans la cloche, et ça reste ».
// MESURÉ (scripts/mesure_pastille_612.js, vrai serveur local) :
//   1. fil ENTRE AMIS : le compteur de non-lus du serveur restait à 0 pour toujours
//      (filtre `$nin` posé sur le document au lieu du seul tableau) → l'app, qui recale
//      sa pastille sur ce compteur, l'effaçait ; la cloche, elle, comptait bien 1 ;
//   2. un fil ouvert une fois restait « ouvert à l'écran » pour le serveur (l'app ≤ 611
//      ne quitte jamais la salle) → plus de notification du téléphone pour ce fil.
// Vraie base Mongo en mémoire, vraies routes HTTP, vrai emitter ; Firebase capté.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockPushes = [];
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({
    sendEachForMulticast: jest.fn(async (m) => {
      mockPushes.push(m);
      return { successCount: m.tokens.length, failureCount: 0, responses: [] };
    }),
  }),
}));

const mongoose = require('mongoose');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let Conversation; let Notification; let emitter;
let A; let Aw; let B; let conv; let tA; let tAw; let tB;
const fakeSockets = [];
const fakeIo = {
  to: () => ({ emit: () => {} }),
  in: () => ({ fetchSockets: async () => fakeSockets }),
  fetchSockets: async () => fakeSockets,
  sockets: { adapter: { rooms: new Map() }, sockets: new Map() },
};
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const api = (method, path, token) => request(app)[method](`/api/v1${path}`)
  .set('Authorization', `Bearer ${token}`).set('X-App-Version', '611').set('X-App-Platform', 'ios');
const unreadOf = async (token, cid) => {
  const r = await api('get', '/conversations/list', token);
  expect(r.status).toBe(200);
  const row = (r.body.conversations || []).find((c) => String(c._id || c.id) === String(cid));
  return row ? row.unreadCount : null;
};
const bellUnread = () => Notification.countDocuments({ type: 'NEW_MESSAGE', 'data.conversationId': String(conv._id), readAt: null });
const settleBell = async (n) => {
  for (let i = 0; i < 100 && (await bellUnread()) !== n; i += 1) await wait(20);
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Conversation = require('../src/models/Conversation'); Notification = require('../src/models/Notification');
  emitter = require('../src/sockets/emitter');
  emitter.setSocketServer(fakeIo);
  app = require('../src/app');
  const e = 'dest612+test@example.test';
  A = await Owner.create({ name: 'Dest Test', email: e, password: 'MotDePasse612!', fcmTokens: ['jeton-A'], fcmDevices: [{ token: 'jeton-A', platform: 'ios', appBuild: 611 }] });
  await Sitter.create({ name: 'Dest Test', email: e, password: 'MotDePasse612!' });
  Aw = await Walker.create({ name: 'Dest Test', email: e, password: 'MotDePasse612!' });
  B = await Owner.create({ name: 'Exp Test', email: 'exp612+test@example.test', password: 'MotDePasse612!' });
  conv = await Conversation.create({
    friendChat: true,
    participants: [{ userId: A._id, userModel: 'Owner' }, { userId: B._id, userModel: 'Owner' }],
  });
  tA = tok(A._id, 'owner'); tAw = tok(Aw._id, 'walker'); tB = tok(B._id, 'owner');
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

test('fil entre amis : un message reçu compte 1 non-lu chez le destinataire (pastille), 0 chez l’expéditeur', async () => {
  const s = await api('post', `/conversations/${conv._id}/messages`, tB).send({ body: 'coucou' });
  expect(s.status).toBe(201);
  expect(await unreadOf(tA, conv._id)).toBe(1); // avant le correctif : 0
  expect(await unreadOf(tB, conv._id)).toBe(0);
  await settleBell(1);
  expect(await bellUnread()).toBe(1);
});

test('la même personne connectée sous un AUTRE profil (promeneur) voit la même pastille', async () => {
  expect(await unreadOf(tAw, conv._id)).toBe(1);
});

test('deuxième message : 2 non-lus, toujours UNE seule entrée dans la cloche', async () => {
  await api('post', `/conversations/${conv._id}/messages`, tB).send({ body: 'tu es là ?' });
  expect(await unreadOf(tA, conv._id)).toBe(2);
  await wait(300);
  expect(await bellUnread()).toBe(1);
});

test('lire le fil : pastille à 0 ET l’entrée de la cloche passe en lu (elle ne « reste » pas)', async () => {
  const r = await api('post', `/conversations/${conv._id}/read`, tA);
  expect(r.status).toBe(200);
  expect(await unreadOf(tA, conv._id)).toBe(0);
  await settleBell(0);
  expect(await bellUnread()).toBe(0);
  const c = await api('get', '/notifications/my/unread-count', tA);
  expect(c.body.totalUnreadCount).toBe(0);
});

test('répondre ne crée pas de non-lu chez soi (3 profils = une personne)', async () => {
  await api('post', `/conversations/${conv._id}/messages`, tAw).send({ body: 'oui !' });
  expect(await unreadOf(tA, conv._id)).toBe(0);
  expect(await unreadOf(tB, conv._id)).toBe(1);
});

describe('fil « ouvert à l’écran » : doit être confirmé récemment (apps ≤ 611 ne quittent jamais la salle)', () => {
  const cid = () => String(conv._id);
  const sock = (extra = {}) => ({
    id: 's1',
    rooms: new Set([cid()]),
    data: { user: { id: String(A._id), role: 'owner' }, foreground: true, lastActiveAt: Date.now(), openConversationId: cid(), ...extra },
  });
  beforeEach(() => { fakeSockets.length = 0; });

  test('entré dans le fil il y a 5 s → ouvert (pas de notification du téléphone)', async () => {
    fakeSockets.push(sock({ openConversationAt: Date.now() - 5000 }));
    expect(await emitter.isConversationOpenFor(cid(), [String(A._id)])).toBe(true);
  });
  test('fil quitté sans prévenir, dernière confirmation il y a 61 s → PAS ouvert (la notification part)', async () => {
    fakeSockets.push(sock({ openConversationAt: Date.now() - 61000 }));
    expect(await emitter.isConversationOpenFor(cid(), [String(A._id)])).toBe(false);
  });
  test('prise dans la salle sans jamais avoir confirmé → PAS ouvert', async () => {
    fakeSockets.push(sock({}));
    expect(await emitter.isConversationOpenFor(cid(), [String(A._id)])).toBe(false);
  });
  test('lire par HTTP confirme le fil ouvert pour 60 s ; ne déclare jamais ouvert un fil quitté', async () => {
    const s = sock({ openConversationAt: Date.now() - 61000 });
    fakeSockets.push(s);
    expect(await emitter.touchConversationOpen(cid(), [String(A._id)])).toBe(1);
    expect(await emitter.isConversationOpenFor(cid(), [String(A._id)])).toBe(true);
    s.data.openConversationId = null; // conversation:leave (app 612)
    expect(await emitter.touchConversationOpen(cid(), [String(A._id)])).toBe(0);
    expect(await emitter.isConversationOpenFor(cid(), [String(A._id)])).toBe(false);
  });
  test('bout en bout : fil resté « ouvert » depuis 2 min, app devant → le message fait bien partir la notification', async () => {
    fakeSockets.push(sock({ openConversationAt: Date.now() - 120000 }));
    await api('post', `/conversations/${conv._id}/read`, tB); // B lit la réponse
    mockPushes.length = 0;
    // (le POST /read de B ne confirme que les prises de B : celle de A reste périmée)
    await api('post', `/conversations/${conv._id}/messages`, tB).send({ body: 'dernier message' });
    for (let i = 0; i < 100 && !mockPushes.length; i += 1) await wait(20);
    expect(mockPushes.length).toBe(1);
    expect(mockPushes[0].tokens).toEqual(['jeton-A']);
    expect(mockPushes[0].data.type).toBe('NEW_MESSAGE');
  });
  test('bout en bout : fil confirmé à l’écran il y a 5 s → aucune notification du téléphone', async () => {
    fakeSockets.push(sock({ openConversationAt: Date.now() - 5000 }));
    mockPushes.length = 0;
    await api('post', `/conversations/${conv._id}/messages`, tB).send({ body: 'en direct' });
    await wait(500);
    expect(mockPushes.filter((m) => m.data && m.data.type === 'NEW_MESSAGE').length).toBe(0);
  });
});
