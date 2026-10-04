// 04/10/2026 (ADA, v613) — parcours d'une demande dans l'admin, LECTURE SEULE.
// Vraie base Mongo en mémoire, vrais modèles, vraie route.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role)
    ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const DAY = 86400000;
const NOW = Date.now();

let mongo; let app;
let Owner; let Sitter; let Walker; let Post; let Notification; let Application; let Booking; let Conversation; let Message;
const ids = {};

const ins = async (M, doc) => String((await M.collection.insertOne(doc)).insertedId);
const mkPost = (ownerId, extra = {}) => ins(Post, {
  ownerId: new mongoose.Types.ObjectId(ownerId), postType: 'request', body: 'Promenade', serviceTypes: ['dog_walking'],
  location: { city: 'Zone fictive', lat: -35, lng: -30 }, hidden: false, status: 'open',
  startDate: new Date(NOW + 2 * DAY), endDate: new Date(NOW + 2 * DAY + 3600000),
  createdAt: new Date(NOW - 3 * 3600000), updatedAt: new Date(NOW - 3 * 3600000), ...extra,
});
const notif = (postId, role, rid, read, at = NOW - 2 * 3600000) => ins(Notification, {
  type: 'new_request_nearby', recipientRole: role, recipientId: new mongoose.Types.ObjectId(rid),
  title: 't', body: 'b', data: { postId: String(postId) }, createdAt: new Date(at), readAt: read ? new Date(at + 60000) : null,
});
const appl = (postId, ownerId, role, pid, status = 'pending', extra = {}) => ins(Application, {
  postId: new mongoose.Types.ObjectId(postId), ownerId: new mongoose.Types.ObjectId(ownerId),
  sitterId: role === 'sitter' ? new mongoose.Types.ObjectId(pid) : null,
  walkerId: role === 'walker' ? new mongoose.Types.ObjectId(pid) : null,
  status, bookingId: null, createdAt: new Date(NOW - 3600000), updatedAt: new Date(NOW - 1800000), ...extra,
});
const booking = (ownerId, walkerId, extra = {}) => ins(Booking, {
  ownerId: new mongoose.Types.ObjectId(ownerId), walkerId: new mongoose.Types.ObjectId(walkerId), sitterId: null,
  status: 'agreed', paymentStatus: 'pending', agreedAt: new Date(NOW - 1700000),
  pricing: { basePrice: 20, totalPrice: 24, commission: 4.8, netPayout: 19.2, commissionRate: 0.2, currency: 'EUR' },
  createdAt: new Date(NOW - 1700000), updatedAt: new Date(NOW - 1700000), ...extra,
});
const get = (url) => request(app).get(url).set(ADMIN);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Post = require('../src/models/Post');
  Notification = require('../src/models/Notification');
  Application = require('../src/models/Application');
  Booking = require('../src/models/Booking');
  Conversation = require('../src/models/Conversation');
  Message = require('../src/models/Message');

  ids.owner = await ins(Owner, { name: 'Nina Vraie', email: 'nina613@example.org', location: { city: 'Zone fictive' } });
  ids.ownerTest = await ins(Owner, { name: 'Testy', email: 'dadaciao84+testowner@gmail.com' });
  ids.ownerStaff = await ins(Owner, { name: 'Equipe', email: 'equipe613@example.org', isStaff: true });
  ids.w1 = await ins(Walker, { name: 'Sarah Martin', email: 'sarah613@example.org', location: { city: 'Paris' } });
  ids.w2 = await ins(Walker, { name: 'Leo Petit', email: 'leo613@example.org', city: 'Boulogne' });
  ids.s1 = await ins(Sitter, { name: 'Ines', email: 'dadaciao84+testsitter@gmail.com', location: { city: 'Paris' } });

  app = express();
  app.use(express.json());
  app.use('/admin/requests613', require('../src/routes/adminRequestJourney613'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

describe('cas de BOB : 3 prévenus dont 1 lu, 1 candidature', () => {
  let pid;
  beforeAll(async () => {
    pid = await mkPost(ids.owner);
    await notif(pid, 'walker', ids.w1, true);
    await notif(pid, 'walker', ids.w2, false);
    await notif(pid, 'sitter', ids.s1, false);
    await appl(pid, ids.owner, 'walker', ids.w1);
  });

  test('résumé groupé : compteurs, pastille verte, statut « 1 candidature »', async () => {
    const r = await get(`/admin/requests613/summary?ids=${pid}`);
    expect(r.status).toBe(200);
    const it = r.body.items[pid];
    expect(it.stages.notified.count).toBe(3);
    expect(it.stages.opened.count).toBe(1);
    expect(it.stages.applications.count).toBe(1);
    expect(it.stages.applications.who).toEqual([{ name: 'Sarah', role: 'walker', kind: 'real' }]);
    expect(it.color).toBe('green');
    expect(it.status).toBe('applied');
    expect(it.stages.decision.state).toBe('none');
    expect(it.stages.payment.state).toBe('none');
    expect(it.stages.end.state).toBe('none');
    expect(it.owner).toEqual({ id: ids.owner, name: 'Nina', kind: 'real' });
    expect(JSON.stringify(r.body)).not.toMatch(/@/); // aucune adresse e-mail
  });

  test('détail : prévenus (prénom, rôle, ville, lu), +test signalé, candidatures', async () => {
    const r = await get(`/admin/requests613/${pid}/journey`);
    expect(r.status).toBe(200);
    expect(r.body.notified).toHaveLength(3);
    const sarah = r.body.notified.find((n) => n.name === 'Sarah');
    expect(sarah).toMatchObject({ role: 'walker', city: 'Paris', read: true, kind: 'real' });
    const leo = r.body.notified.find((n) => n.name === 'Leo');
    expect(leo).toMatchObject({ city: 'Boulogne', read: false });
    expect(r.body.notified.find((n) => n.role === 'sitter').kind).toBe('test');
    expect(r.body.applications).toEqual([expect.objectContaining({ name: 'Sarah', role: 'walker', status: 'pending' })]);
    expect(JSON.stringify(r.body)).not.toMatch(/@/);
  });
});

describe('pastilles et étapes', () => {
  test('personne prévenu → rouge, « en attente »', async () => {
    const pid = await mkPost(ids.owner);
    const it = (await get(`/admin/requests613/summary?ids=${pid}`)).body.items[pid];
    expect(it.stages.notified.count).toBe(0);
    expect(it.stages.applications.count).toBe(0);
    expect(it.color).toBe('red');
    expect(it.status).toBe('waiting');
  });

  test('prévenus, 0 ouverture → orange ; ouvert sans candidature → jaune', async () => {
    const a = await mkPost(ids.owner);
    await notif(a, 'walker', ids.w1, false);
    const b = await mkPost(ids.owner);
    await notif(b, 'walker', ids.w1, true);
    const r = (await get(`/admin/requests613/summary?ids=${a},${b}`)).body.items;
    expect(r[a].color).toBe('orange');
    expect(r[b].color).toBe('yellow');
  });

  test('contacts : conversation où le prestataire a écrit APRÈS la publication (lien indirect)', async () => {
    const owner = await ins(Owner, { name: 'Paul Contact', email: 'paul613@example.org' });
    const pid = await mkPost(owner);
    const conv = await ins(Conversation, { ownerId: new mongoose.Types.ObjectId(owner), walkerId: new mongoose.Types.ObjectId(ids.w2), sitterId: null });
    const old = await ins(Conversation, { ownerId: new mongoose.Types.ObjectId(owner), walkerId: new mongoose.Types.ObjectId(ids.w1), sitterId: null });
    const cid = new mongoose.Types.ObjectId(conv);
    await ins(Message, { conversationId: cid, senderRole: 'walker', senderId: new mongoose.Types.ObjectId(ids.w2), body: 'Bonjour', createdAt: new Date(NOW - 3600000) });
    await ins(Message, { conversationId: cid, senderRole: 'walker', senderId: new mongoose.Types.ObjectId(ids.w2), body: 'Dispo', createdAt: new Date(NOW - 1800000) });
    await ins(Message, { conversationId: cid, senderRole: 'owner', senderId: new mongoose.Types.ObjectId(owner), body: 'Merci', createdAt: new Date(NOW - 1000000) });
    // ancienne conversation, prestataire muet depuis la publication → pas comptée
    await ins(Message, { conversationId: new mongoose.Types.ObjectId(old), senderRole: 'walker', senderId: new mongoose.Types.ObjectId(ids.w1), body: 'vieux', createdAt: new Date(NOW - 10 * DAY) });
    const it = (await get(`/admin/requests613/summary?ids=${pid}`)).body.items[pid];
    expect(it.stages.contacts).toEqual({ count: 1, linked: false });
    const d = (await get(`/admin/requests613/${pid}/journey`)).body;
    expect(d.contacts).toEqual([expect.objectContaining({ name: 'Leo', role: 'walker', messages: 2 })]);
  });

  test('validée (candidature acceptée + réservation agreed, non payée)', async () => {
    const pid = await mkPost(ids.owner);
    const bk = await booking(ids.owner, ids.w1);
    await appl(pid, ids.owner, 'walker', ids.w1, 'accepted', { bookingId: new mongoose.Types.ObjectId(bk) });
    await Post.collection.updateOne({ _id: new mongoose.Types.ObjectId(pid) }, { $set: { reservedBy: { bookingId: new mongoose.Types.ObjectId(bk) } } });
    const it = (await get(`/admin/requests613/summary?ids=${pid}`)).body.items[pid];
    expect(it.status).toBe('accepted');
    expect(it.stages.decision).toMatchObject({ state: 'accepted', by: { name: 'Sarah', role: 'walker', kind: 'real' } });
    expect(it.stages.payment).toMatchObject({ state: 'unpaid', amount: 24, commission: 4.8, currency: 'EUR' });
  });

  test('refusée : toutes les candidatures refusées', async () => {
    const pid = await mkPost(ids.owner);
    await appl(pid, ids.owner, 'walker', ids.w1, 'rejected');
    await appl(pid, ids.owner, 'walker', ids.w2, 'rejected');
    const it = (await get(`/admin/requests613/summary?ids=${pid}`)).body.items[pid];
    expect(it.stages.decision.state).toBe('refused');
    expect(it.status).toBe('applied');
  });

  test('payée : montant et commission lus dans la réservation', async () => {
    const pid = await mkPost(ids.owner);
    const bk = await booking(ids.owner, ids.w1, { status: 'paid', paymentStatus: 'paid', paidAt: new Date(NOW - 600000) });
    await appl(pid, ids.owner, 'walker', ids.w1, 'accepted', { bookingId: new mongoose.Types.ObjectId(bk) });
    const it = (await get(`/admin/requests613/summary?ids=${pid}`)).body.items[pid];
    expect(it.status).toBe('paid');
    expect(it.stages.payment).toMatchObject({ state: 'paid', amount: 24, commission: 4.8 });
    expect(it.stages.payment.at).toBeTruthy();
  });

  test('terminée (booking completed) et annulée (booking cancelled)', async () => {
    const a = await mkPost(ids.owner);
    const bka = await booking(ids.owner, ids.w1, { status: 'completed', paymentStatus: 'paid', paidAt: new Date(NOW - DAY), ownerConfirmedAt: new Date(NOW - 3600000) });
    await appl(a, ids.owner, 'walker', ids.w1, 'accepted', { bookingId: new mongoose.Types.ObjectId(bka) });
    const b = await mkPost(ids.owner);
    const bkb = await booking(ids.owner, ids.w2, { status: 'cancelled', cancelledAt: new Date(NOW - 3600000) });
    await appl(b, ids.owner, 'walker', ids.w2, 'accepted', { bookingId: new mongoose.Types.ObjectId(bkb) });
    const r = (await get(`/admin/requests613/summary?ids=${a},${b}`)).body.items;
    expect(r[a].status).toBe('completed');
    expect(r[a].stages.end.state).toBe('completed');
    expect(r[a].stages.payment.state).toBe('paid');
    expect(r[b].status).toBe('cancelled');
    expect(r[b].stages.end.state).toBe('cancelled');
  });

  test('expirée : date de prestation passée sans validation', async () => {
    const pid = await mkPost(ids.owner, { startDate: new Date(NOW - 2 * DAY), endDate: new Date(NOW - 2 * DAY + 3600000) });
    await notif(pid, 'walker', ids.w1, true);
    const it = (await get(`/admin/requests613/summary?ids=${pid}`)).body.items[pid];
    expect(it.status).toBe('expired');
    expect(it.stages.end.state).toBe('expired');
  });
});

describe('Tableau de bord : demandes des vrais comptes seulement', () => {
  test('+test et staff exclus de la liste et des compteurs, plus récentes d abord', async () => {
    const tp = await mkPost(ids.ownerTest, { createdAt: new Date(NOW - 60000) });
    const sp = await mkPost(ids.ownerStaff, { createdAt: new Date(NOW - 50000) });
    const hidden = await mkPost(ids.owner, { hidden: true, createdAt: new Date(NOW - 40000) });
    const real = await mkPost(ids.owner, { createdAt: new Date(NOW - 30000) });
    const r = await get('/admin/requests613/live?limit=10');
    expect(r.status).toBe(200);
    const got = r.body.items.map((x) => x.postId);
    expect(got[0]).toBe(real);
    expect(got).not.toEqual(expect.arrayContaining([tp]));
    expect(got).not.toContain(sp);
    expect(got).not.toContain(hidden);
    expect(r.body.items.length).toBeLessThanOrEqual(10);
    expect(r.body.excludedTestOrStaff).toBe(2);
    const c = r.body.counters;
    expect(c.paid).toBe(2); // payée + terminée
    expect(c.accepted).toBe(4); // validée, payée, terminée, annulée (candidature acceptée)
    expect(c.withApplications).toBeGreaterThanOrEqual(6);
    expect(c.open).toBeGreaterThan(0);
  });

  test('summary : un compte +test est signalé (kind test), pas mélangé', async () => {
    const tp = await mkPost(ids.ownerTest);
    const it = (await get(`/admin/requests613/summary?ids=${tp}`)).body.items[tp];
    expect(it.owner.kind).toBe('test');
  });

  test('accès refusé sans rôle admin ; identifiant invalide → 400 ; media → ignoré', async () => {
    const r = await request(app).get('/admin/requests613/live').set({ 'x-test-user': 'x', 'x-test-role': 'owner' });
    expect(r.status).toBe(403);
    expect((await get('/admin/requests613/zz/journey')).status).toBe(400);
    const media = await ins(Post, { ownerId: new mongoose.Types.ObjectId(ids.owner), postType: 'media', createdAt: new Date() });
    expect((await get(`/admin/requests613/summary?ids=${media}`)).body.items).toEqual({});
  });

  test('lecture seule : aucune écriture dans la base pendant les appels', async () => {
    const counts = async () => Promise.all([Post, Notification, Application, Booking, Conversation, Message].map((M) => M.countDocuments()));
    const before = await counts();
    await get('/admin/requests613/live?limit=10');
    const any = (await Post.findOne({ postType: 'request' }).lean())._id;
    await get(`/admin/requests613/${any}/journey`);
    expect(await counts()).toEqual(before);
  });
});
