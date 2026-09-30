// v604 (ZOE, 30/09/2026) — PARCOURS COMPLET du suivi en direct dans le chat,
// sur une VRAIE base Mongo en mémoire, avec les VRAIS gestionnaires :
//   POST /conversations/:id/follow-request   (requestLiveTrackingByConversation)
//   POST /bookings/pawfollow-request/:id/respond
//   POST /friends/live-position              (démarrage, puis offline:true)
//   GET  /conversations/:id/pawfollow-state
//   POST /conversations/:id/pawfollow/stop
// Seuls la socket et les notifications sont interceptées (on lit ce qui
// serait émis). Aucun réseau, aucune production, zone fictive (-35 / -30).
//
// Daniel (30/09) : « En direct » restait affiché après l'arrêt ; le suivi
// mutuel (A suit B ET B suit A) doit tenir ses deux sens séparément.
//
// Avec PF604_FIXTURES=1, les réponses réelles de GET pawfollow-state sont
// écrites dans frontend/test/fixtures/pawfollow604/ : le test widget Flutter
// les rejoue telles quelles.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');

const mockEmits = [];
jest.mock('../src/services/notificationSender', () => new Proxy({}, {
  get: () => jest.fn(async () => ({})),
}));
jest.mock('../src/sockets/emitter', () => ({
  buildPresenceIndex: jest.fn(() => Promise.resolve(null)),
  isIdentityOnline: jest.fn(() => false),
  userRoom: (role, id) => `user:${role}:${id}`,
  emitToUser: jest.fn((role, id, event, payload) => mockEmits.push({ kind: 'user', role, id: String(id), event, payload })),
  emitToUsersAllRoles: jest.fn((ids, event, payload) => {
    mockEmits.push({ kind: 'all', ids: (ids || []).map(String), event, payload });
    return (ids || []).length;
  }),
  emitChatMessage: jest.fn((conv, event, payload) => mockEmits.push({ kind: 'chat', event, payload })),
  emitToConversation: jest.fn(),
}));

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo;
let Sitter; let Walker; let Owner; let Conversation; let Message; let Friendship;
let convRouter; let friendRouter; let booking;

const oid = () => new mongoose.Types.ObjectId();
const LAT = -35.2;
const LNG = -30.4;

// A = gardien (comme +testsitter), B = promeneur (comme +testwalker),
// O = propriétaire (comme +testowner). Un profil chacun.
const A = { id: oid(), role: 'sitter', email: 'pf604a@example.test', name: 'Alice' };
const B = { id: oid(), role: 'walker', email: 'pf604b@example.test', name: 'Bruno' };
const O = { id: oid(), role: 'owner', email: 'pf604o@example.test', name: 'Olga' };

const FIX_DIR = path.join(__dirname, '..', '..', 'frontend', 'test', 'fixtures', 'pawfollow604');
const WRITE = process.env.PF604_FIXTURES === '1';

function handlerOf(router, method, p) {
  const layer = router.stack.find((l) => l.route && l.route.path === p && l.route.methods[method]);
  if (!layer) throw new Error(`route ${method} ${p} introuvable`);
  return layer.route.stack[layer.route.stack.length - 1].handle;
}
function run(fn, { user, params = {}, body = {}, headers = {} }) {
  return new Promise((resolve, reject) => {
    const req = { user: { id: String(user.id), role: user.role }, params, body, query: {}, headers };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: JSON.parse(JSON.stringify(b)) }); },
    };
    Promise.resolve(fn(req, res)).catch(reject);
  });
}
const flush = () => new Promise((r) => setTimeout(r, 80));

const api = {
  ask: (user, convId) => run(booking.requestLiveTrackingByConversation, { user, params: { id: String(convId) } }),
  respond: (user, messageId, action) => run(booking.respondToPawfollowRequest, { user, params: { messageId: String(messageId) }, body: { action } }),
  goLive: (user) => run(handlerOf(friendRouter, 'post', '/live-position'), {
    user, body: { lat: LAT, lng: LNG }, headers: { 'x-app-version': '604' },
  }),
  stopLive: (user) => run(handlerOf(friendRouter, 'post', '/live-position'), {
    user, body: { offline: true }, headers: { 'x-app-version': '604' },
  }),
  state: (user, convId) => run(handlerOf(convRouter, 'get', '/:id/pawfollow-state'), { user, params: { id: String(convId) } }),
  stopFollow: (user, convId, body = {}) => run(handlerOf(convRouter, 'post', '/:id/pawfollow/stop'), { user, params: { id: String(convId) }, body }),
};

function saveFixture(name, body) {
  if (!WRITE) return;
  fs.mkdirSync(FIX_DIR, { recursive: true });
  fs.writeFileSync(path.join(FIX_DIR, `${name}.json`), `${JSON.stringify(body, null, 2)}\n`);
}

async function person(p) {
  const Model = p.role === 'sitter' ? Sitter : p.role === 'walker' ? Walker : Owner;
  await Model.collection.insertOne({
    _id: p.id, email: p.email, name: p.name, firstName: p.name, password: 'x'.repeat(60),
    location: { type: 'Point', coordinates: [LNG, LAT], city: '' },
    createdAt: new Date(), updatedAt: new Date(),
  });
}
async function friendChat(x, y) {
  const model = (p) => (p.role === 'sitter' ? 'Sitter' : p.role === 'walker' ? 'Walker' : 'Owner');
  // Une seule amitié par paire (index unique) : réutilisée d'un scénario à l'autre.
  await Friendship.collection.updateOne(
    { requesterId: x.id, addresseeId: y.id },
    {
      $setOnInsert: {
        requesterId: x.id, requesterModel: model(x), addresseeId: y.id, addresseeModel: model(y),
        status: 'accepted', acceptedAt: new Date(), createdAt: new Date(), updatedAt: new Date(),
        requesterSharesPosition: true, addresseeSharesPosition: true,
      },
    },
    { upsert: true },
  );
  const c = await Conversation.create({
    friendChat: true,
    participants: [{ userId: x.id, userModel: model(x) }, { userId: y.id, userModel: model(y) }],
  });
  return c._id;
}
async function resetLive() {
  const map = require('../src/sockets/mapSocket');
  for (const p of [A, B, O]) {
    map.clearLiveSession(String(p.id));
    const Model = p.role === 'sitter' ? Sitter : p.role === 'walker' ? Walker : Owner;
    // eslint-disable-next-line no-await-in-loop
    await Model.updateOne({ _id: p.id }, { $set: { 'location.liveShareActive': false, 'location.liveShareStoppedAt': null } });
  }
}
const statesFor = (who) => mockEmits.filter((e) => e.event === 'pawfollow:state' && e.ids.includes(String(who.id)));
const lastStateFor = (who) => { const l = statesFor(who); return l.length ? l[l.length - 1].payload : null; };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Owner = require('../src/models/Owner');
  Conversation = require('../src/models/Conversation');
  Message = require('../src/models/Message');
  Friendship = require('../src/models/Friendship');
  convRouter = require('../src/routes/conversationRoutes');
  friendRouter = require('../src/routes/friendRoutes');
  booking = require('../src/controllers/bookingController');
  await person(A); await person(B); await person(O);
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

describe('suivi MUTUEL A (gardien) ⇄ B (promeneur), ordre de Daniel', () => {
  let conv;
  let aMsg; let bMsg;
  beforeAll(async () => {
    await resetLive();
    conv = await friendChat(A, B);
  });

  test('A demande, puis B demande pendant que celle de A attend : DEUX demandes (plus de « duplicate »)', async () => {
    const r1 = await api.ask(A, conv);
    const r2 = await api.ask(B, conv);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
    expect(r2.body.duplicate).toBeUndefined();
    aMsg = r1.body.chatMessageId;
    bMsg = r2.body.chatMessageId;
    expect(aMsg).not.toBe(bMsg);
    expect(await Message.countDocuments({ conversationId: conv, type: 'pawfollow_request' })).toBe(2);
  });

  test('B accepte la demande de A, A accepte celle de B : deux sens suivis, personne en direct', async () => {
    expect((await api.respond(B, aMsg, 'accept')).status).toBe(200);
    expect((await api.respond(A, bMsg, 'accept')).status).toBe(200);
    await flush();
    const sa = (await api.state(A, conv)).body;
    const sb = (await api.state(B, conv)).body;
    expect(sa.outgoing).toMatchObject({ status: 'accepted', following: true, live: false, messageId: aMsg });
    expect(sa.incoming).toMatchObject({ status: 'accepted', following: true, live: false, messageId: bMsg });
    expect(sb.outgoing).toMatchObject({ following: true, live: false, messageId: bMsg });
    expect(sb.incoming).toMatchObject({ following: true, live: false, messageId: aMsg });
    saveFixture('mutual_accepted_nolive_A', sa);
    // Accepter pousse l'état aux deux (pilule d'en-tête sans attendre).
    expect(lastStateFor(A)).not.toBeNull();
    expect(lastStateFor(B)).not.toBeNull();
  });

  test('les deux diffusent : chacun voit l\'autre EN DIRECT (état serveur + socket)', async () => {
    mockEmits.length = 0;
    expect((await api.goLive(A)).status).toBe(200);
    expect((await api.goLive(B)).status).toBe(200);
    await flush();
    const sa = (await api.state(A, conv)).body;
    const sb = (await api.state(B, conv)).body;
    expect(sa.incoming.live).toBe(true);
    expect(sa.outgoing.live).toBe(true);
    expect(sb.incoming.live).toBe(true);
    expect(sb.outgoing.live).toBe(true);
    saveFixture('mutual_both_live_A', sa);
    saveFixture('mutual_both_live_B', sb);
    // Le démarrage de B est poussé à A (son sens entrant passe en direct).
    expect(statesFor(A).some((e) => e.payload.incoming.live === true)).toBe(true);
  });

  test('A « arrête de suivre » : seul B→A se termine ; B voit toujours A en direct', async () => {
    mockEmits.length = 0;
    const r = await api.stopFollow(A, conv, { scope: 'following' });
    expect(r.status).toBe(200);
    expect(r.body.ended).toBe(1);
    expect(r.body.incoming).toMatchObject({ status: 'ended', following: false, live: false, endReason: 'follow_stopped' });
    expect(r.body.outgoing).toMatchObject({ following: true, live: true });
    const sb = (await api.state(B, conv)).body;
    expect(sb.incoming).toMatchObject({ following: true, live: true, messageId: aMsg });
    expect(sb.outgoing).toMatchObject({ status: 'ended', following: false });
    saveFixture('mutual_A_stopped_following_A', r.body);
    saveFixture('mutual_A_stopped_following_B', sb);
    // Les deux téléphones sont prévenus : la carte (message:updated) + l'en-tête.
    expect(mockEmits.some((e) => e.event === 'message:updated' && String(e.payload.message._id) === bMsg && e.payload.message.metadata.status === 'ended')).toBe(true);
    expect(lastStateFor(B).outgoing.status).toBe('ended');
    expect(lastStateFor(A).incoming.status).toBe('ended');
    // La demande de A (A→B) reste acceptée en base.
    const still = await Message.findById(aMsg).lean();
    expect(still.metadata.status).toBe('accepted');
  });

  test('B arrête son direct : A garde sa diffusion et reste en direct pour B', async () => {
    mockEmits.length = 0;
    expect((await api.stopLive(B)).status).toBe(200);
    await flush();
    const sa = (await api.state(A, conv)).body;
    const sb = (await api.state(B, conv)).body;
    expect(sa.outgoing).toMatchObject({ following: true, live: true });
    expect(sb.incoming).toMatchObject({ following: true, live: true });
    saveFixture('mutual_B_stopped_live_after_A_unfollow_A', sa);
    saveFixture('mutual_B_stopped_live_after_A_unfollow_B', sb);
    // A→B n'a pas été touchée par l'arrêt de B.
    expect((await Message.findById(aMsg).lean()).metadata.status).toBe('accepted');
  });
});

describe('suivi MUTUEL : B arrête son direct pendant que A le suit encore', () => {
  let conv;
  let aMsg; let bMsg;
  beforeAll(async () => {
    await resetLive();
    await Message.deleteMany({});
    conv = await friendChat(A, B);
    aMsg = (await api.ask(A, conv)).body.chatMessageId;
    bMsg = (await api.ask(B, conv)).body.chatMessageId;
    await api.respond(B, aMsg, 'accept');
    await api.respond(A, bMsg, 'accept');
    await api.goLive(A);
    await api.goLive(B);
    await flush();
  });

  test('après l\'arrêt de B : pour A « direct arrêté » (B→A terminé), A reste en direct pour B', async () => {
    // Avant l'arrêt (même conversation, mêmes demandes) : les deux en direct.
    const before = (await api.state(A, conv)).body;
    expect(before.incoming).toMatchObject({ following: true, live: true });
    saveFixture('mutual2_both_live_A', before);
    mockEmits.length = 0;
    expect((await api.stopLive(B)).status).toBe(200);
    await flush();
    const sa = (await api.state(A, conv)).body;
    const sb = (await api.state(B, conv)).body;
    expect(sa.incoming).toMatchObject({ status: 'ended', following: false, live: false, endReason: 'live_stopped' });
    expect(sa.outgoing).toMatchObject({ following: true, live: true });
    expect(sb.outgoing).toMatchObject({ status: 'ended', live: false, endReason: 'live_stopped' });
    expect(sb.incoming).toMatchObject({ following: true, live: true });
    saveFixture('mutual_B_stopped_live_A', sa);
    saveFixture('mutual_B_stopped_live_B', sb);
    // Poussé aux deux dans la foulée (pas d'attente de la relecture).
    expect(lastStateFor(A).incoming.status).toBe('ended');
    expect(lastStateFor(B).outgoing.status).toBe('ended');
    // Le suivi de B par A n'existe plus, celui de A par B tient.
    expect((await Message.findById(bMsg).lean()).metadata.status).toBe('ended');
    expect((await Message.findById(aMsg).lean()).metadata.status).toBe('accepted');
  });
});

describe('un seul sens : O (propriétaire) suit A (gardien)', () => {
  let conv;
  let oMsg;
  beforeAll(async () => {
    await resetLive();
    await Message.deleteMany({});
    conv = await friendChat(O, A);
  });

  test('demande en attente : rien en direct', async () => {
    oMsg = (await api.ask(O, conv)).body.chatMessageId;
    const so = (await api.state(O, conv)).body;
    expect(so.incoming).toMatchObject({ status: 'pending', following: false, live: false });
    expect(so.outgoing.status).toBe('none');
    saveFixture('single_pending_O', so);
  });

  test('A accepte sans diffuser : « suivi actif », pas « en direct »', async () => {
    await api.respond(A, oMsg, 'accept');
    await flush();
    const so = (await api.state(O, conv)).body;
    const sa = (await api.state(A, conv)).body;
    expect(so.incoming).toMatchObject({ following: true, live: false });
    expect(sa.outgoing).toMatchObject({ following: true, live: false });
    saveFixture('single_accepted_nolive_O', so);
    saveFixture('single_accepted_nolive_A', sa);
  });

  test('A diffuse : O le voit en direct, A voit « ta position part en direct »', async () => {
    await api.goLive(A);
    await flush();
    const so = (await api.state(O, conv)).body;
    const sa = (await api.state(A, conv)).body;
    expect(so.incoming).toMatchObject({ following: true, live: true });
    expect(sa.outgoing).toMatchObject({ following: true, live: true });
    saveFixture('single_live_O', so);
    saveFixture('single_live_A', sa);
  });

  test('A arrête son direct : terminé des DEUX côtés, poussé aux deux', async () => {
    mockEmits.length = 0;
    await api.stopLive(A);
    await flush();
    const so = (await api.state(O, conv)).body;
    const sa = (await api.state(A, conv)).body;
    expect(so.incoming).toMatchObject({ status: 'ended', following: false, live: false, endReason: 'live_stopped' });
    expect(sa.outgoing).toMatchObject({ status: 'ended', following: false, live: false });
    saveFixture('single_stopped_O', so);
    saveFixture('single_stopped_A', sa);
    expect(lastStateFor(O).incoming.status).toBe('ended');
    expect(lastStateFor(A).outgoing.status).toBe('ended');
    const upd = mockEmits.find((e) => e.event === 'message:updated');
    expect(upd.payload.message.metadata).toMatchObject({ status: 'ended', endReason: 'live_stopped' });
  });

  test('A relance son direct : la demande terminée ne se rallume pas', async () => {
    await api.goLive(A);
    await flush();
    const so = (await api.state(O, conv)).body;
    expect(so.incoming).toMatchObject({ status: 'ended', live: false });
    await api.stopLive(A);
  });

  test('O redemande, A accepte : nouveau suivi, de nouveau suivi actif', async () => {
    const again = (await api.ask(O, conv)).body.chatMessageId;
    await api.respond(A, again, 'accept');
    const so = (await api.state(O, conv)).body;
    expect(so.incoming).toMatchObject({ following: true, messageId: again });
  });

  test('un inconnu de la conversation : 403', async () => {
    const r = await api.state(B, conv);
    expect(r.status).toBe(403);
  });
});
