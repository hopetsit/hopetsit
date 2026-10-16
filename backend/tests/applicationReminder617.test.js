// 617 (ADA, 16/10/2026) — RAPPELS DES DEUX CÔTÉS (§B.1) :
//   (a) 'p24' au gardien/promeneur sans réponse depuis 24 h ;
//   (b) 'x48' au propriétaire 48 h avant l'expiration de sa demande avec candidats.
// VRAIE base Mongo en mémoire, vrai sendNotification (cloche, gabarits 9 langues) ;
// Firebase et SMTP CAPTÉS : rien ne sort.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mockPushes = [];
const mockMails = [];
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false),
}));
jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({
    sendEachForMulticast: jest.fn(async (m) => {
      mockPushes.push(m);
      return { successCount: m.tokens.length, failureCount: 0, responses: [] };
    }),
  }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject) => { mockMails.push({ to, subject }); return { messageId: 'capté' }; }) };
});

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const PARIS = { lat: 48.8566, lng: 2.3522 };
let mongo; let Owner; let Walker; let Sitter; let Post; let Application; let Notification; let Reminder; let Reminder615; let svc;
const W = {}; const S = {}; const O = {};
const oid = (v) => new mongoose.Types.ObjectId(v);
const ins = async (Model, doc) => String((await Model.collection.insertOne({ status: 'active', ...doc })).insertedId);
const utc = (s) => new Date(`${s}Z`);

// Balade le 23/10 à 18 h 30 (heure murale Paris, lue en UTC) → fin 19 h 30 = 17:30Z.
const mkPost = async (ownerId, extra = {}) => String((await Post.collection.insertOne({
  ownerId: oid(ownerId), postType: 'request', status: 'open', hidden: false, body: 'Balade pour Rex',
  serviceTypes: ['dog_walking'], location: { city: 'Paris', ...PARIS },
  startDate: utc('2026-10-23T18:30:00'), endDate: utc('2026-10-23T19:30:00'),
  reservedBy: { bookingId: null }, createdAt: utc('2026-10-19T10:00:00'), ...extra,
})).insertedId);
const apply = async (postId, ownerId, provider, at, extra = {}) => String((await Application.collection.insertOne({
  postId: oid(postId), ownerId: oid(ownerId), ...provider, status: 'pending', createdAt: at, updatedAt: at, ...extra,
})).insertedId);
const run = (iso) => svc.runReminders617({ now: utc(iso) });
const bell = (id, role) => Notification.find({ recipientId: oid(id), ...(role ? { recipientRole: role } : {}) }).lean();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Walker = require('../src/models/Walker'); Sitter = require('../src/models/Sitter');
  Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Notification = require('../src/models/Notification');
  Reminder = require('../src/models/ApplicationReminder617'); Reminder615 = require('../src/models/ApplicationReminder615');
  await Reminder.init(); await Reminder615.init();
  svc = require('../src/services/applicationReminder617');

  O.nicola = await ins(Owner, { name: 'Nicola Rossi', email: 'nicola617@example.test', appLocale: 'fr', fcmTokens: ['jeton-nicola'] });
  O.test = await ins(Owner, { name: 'Camille Durand', email: 'dadaciao84+testowner617@example.test', appLocale: 'fr', fcmTokens: ['jeton-testowner'] });
  O.staff = await ins(Owner, { name: 'Staff', email: 'staff617@example.test', isStaff: true, appLocale: 'fr', fcmTokens: ['jeton-staff'] });
  W.paul = await ins(Walker, { name: 'Paul Martin', email: 'paul617@example.test', appLocale: 'fr', fcmTokens: ['jeton-paul'] });
  W.john = await ins(Walker, { name: 'John Smith', email: 'john617@example.test', appLocale: 'en', country: 'US', fcmTokens: ['jeton-john'] });
  W.test = await ins(Walker, { name: 'Testeur', email: 'x+testwalker617@example.test', appLocale: 'fr', fcmTokens: ['jeton-testwalker'] });
  W.susp = await ins(Walker, { name: 'Susp', email: 'susp617@example.test', status: 'suspended', appLocale: 'fr', fcmTokens: ['jeton-susp'] });
  S.sasha = await ins(Sitter, { name: 'Sasha Lee', email: 'sasha617@example.test', appLocale: 'es', fcmTokens: ['jeton-sasha'] });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => {
  mockPushes.length = 0; mockMails.length = 0;
  await Promise.all([Post.deleteMany({}), Application.deleteMany({}), Notification.deleteMany({}), Reminder.deleteMany({}), Reminder615.deleteMany({})]);
});

describe('(a) rappel au gardien sans réponse depuis 24 h', () => {
  test('23 h 30 : rien ; 24 h 05 : push + cloche en français, AUCUN e-mail, lien vers la demande ; jamais deux fois', async () => {
    const postId = await mkPost(O.nicola);
    const appId = await apply(postId, O.nicola, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00')); // 9 h Paris
    const early = await run('2026-10-21T06:30:00');
    expect(early.sent).toHaveLength(0);
    expect(early.skipped.not_due).toBe(1);
    const r = await run('2026-10-21T07:05:00'); // 9 h 05 Paris
    expect(r.sent).toEqual([expect.objectContaining({ slot: 'p24', applicationId: appId, postId, role: 'walker', tz: 'Europe/Paris' })]);
    expect(mockPushes).toHaveLength(1);
    expect(mockPushes[0].tokens).toEqual(['jeton-paul']);
    expect(mockPushes[0].notification.title).toBe('Nicola n’a pas encore répondu');
    expect(mockPushes[0].notification.body).toBe('Nicola n’a pas encore répondu à ta candidature. Envoie-lui un message pour te présenter.');
    expect(mockPushes[0].data.type).toBe('application_new');
    expect(mockPushes[0].data.postId).toBe(postId);
    expect(mockPushes[0].data.reminder617).toBe('p24');
    // Miroir serveur du routeur de l'app : prestataire + application_new → la demande.
    const { buildPreciseRoute } = require('../src/utils/emailLinkBuilder');
    expect(buildPreciseRoute('application_new', mockPushes[0].data, 'walker')).toBe(`/post/${postId}`);
    expect(mockMails).toHaveLength(0);
    const b = await bell(W.paul, 'walker');
    expect(b).toHaveLength(1);
    expect(b[0].body).toContain('Nicola n’a pas encore répondu à ta candidature');
    // La cloche re-rend le texte depuis type + data : même gabarit grâce au marqueur.
    const { renderNotificationContent } = require('../src/services/notificationSender');
    expect(renderNotificationContent('application_new', b[0].data, 'en').title).toBe('Nicola hasn’t replied yet');
    // Doublon : relancer ne renvoie rien.
    expect((await run('2026-10-21T09:00:00')).sent).toHaveLength(0);
    expect(await Reminder.countDocuments({ slot: 'p24' })).toBe(1);
  });

  test('deux passages simultanés : un seul rappel', async () => {
    const postId = await mkPost(O.nicola);
    await apply(postId, O.nicola, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00'));
    const [a, b] = await Promise.all([run('2026-10-21T07:05:00'), run('2026-10-21T07:05:00')]);
    expect(a.sent.length + b.sent.length).toBe(1);
    expect(mockPushes).toHaveLength(1);
  });

  test('jamais la nuit, heure locale du PRESTATAIRE (Dallas) ; texte anglais le matin', async () => {
    const postId = await mkPost(O.nicola);
    await apply(postId, O.nicola, { walkerId: oid(W.john) }, utc('2026-10-20T03:00:00'));
    // 21/10 03:30Z = 22 h 30 à Dallas → nuit (alors qu'il est 5 h 30 à Paris)
    const night = await run('2026-10-21T03:30:00');
    expect(night.sent).toHaveLength(0);
    expect(night.skipped.night).toBe(1);
    // 13:05Z = 8 h 05 à Dallas → part
    const r = await run('2026-10-21T13:05:00');
    expect(r.sent).toEqual([expect.objectContaining({ slot: 'p24', tz: 'America/Chicago' })]);
    expect(mockPushes[0].notification.body).toBe('Nicola hasn’t replied to your application yet. Send them a message to introduce yourself.');
  });

  test('propriétaire a décidé (accepté / refusé) ou demande réservée, fermée, passée : rien', async () => {
    const postId = await mkPost(O.nicola);
    await apply(postId, O.nicola, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00'), { status: 'accepted' });
    await apply(postId, O.nicola, { sitterId: oid(S.sasha) }, utc('2026-10-20T07:00:00'), { status: 'rejected' });
    expect((await run('2026-10-21T07:05:00')).sent).toHaveLength(0);
    await Post.deleteMany({}); await Application.deleteMany({});
    const reserved = await mkPost(O.nicola, { reservedBy: { bookingId: oid() } });
    await apply(reserved, O.nicola, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00'));
    expect((await run('2026-10-21T07:05:00')).skipped.reserved).toBeGreaterThanOrEqual(1); // compté par (a) et (b)
    await Post.deleteMany({}); await Application.deleteMany({});
    const closed = await mkPost(O.nicola, { status: 'closed' });
    await apply(closed, O.nicola, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00'));
    expect((await run('2026-10-21T07:05:00')).skipped.closed).toBeGreaterThanOrEqual(1);
    await Post.deleteMany({}); await Application.deleteMany({});
    const past = await mkPost(O.nicola);
    await apply(past, O.nicola, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00'));
    expect((await run('2026-10-24T10:00:00')).skipped.past).toBeGreaterThanOrEqual(1); // balade du 23 passée
    expect(mockPushes).toHaveLength(0);
  });

  test('comptes de test et suspendus : un gardien +test chez un vrai propriétaire → rien ; vrai gardien chez un propriétaire +test → rien ; test des deux côtés → part', async () => {
    const p1 = await mkPost(O.nicola);
    await apply(p1, O.nicola, { walkerId: oid(W.test) }, utc('2026-10-20T07:00:00'));
    await apply(p1, O.nicola, { walkerId: oid(W.susp) }, utc('2026-10-20T07:00:00'));
    const p2 = await mkPost(O.test);
    await apply(p2, O.test, { walkerId: oid(W.paul) }, utc('2026-10-20T07:00:00'));
    const r = await run('2026-10-21T07:05:00');
    expect(r.sent).toHaveLength(0);
    expect(r.skipped.test).toBeGreaterThanOrEqual(2); // (a) ×2 + le propriétaire test en (b)
    expect(r.skipped.inactive).toBe(1);
    const p3 = await mkPost(O.test);
    await apply(p3, O.test, { walkerId: oid(W.test) }, utc('2026-10-20T07:00:00'));
    const r2 = await run('2026-10-21T07:10:00');
    expect(r2.sent).toEqual([expect.objectContaining({ slot: 'p24', postId: p3 })]);
    expect(mockPushes[0].tokens).toEqual(['jeton-testwalker']);
    expect(mockPushes[0].notification.title).toBe('Camille n’a pas encore répondu');
  });
});

describe('(b) rappel au propriétaire 48 h avant l’expiration', () => {
  // Candidatures récentes (p24 pas dû) ; expiration = fin de balade 23/10 17:30Z → x48 dû dès 21/10 17:30Z.
  const twoFresh = async (ownerId = O.nicola, extra = {}) => {
    const postId = await mkPost(ownerId, extra);
    await apply(postId, ownerId, { walkerId: oid(W.paul) }, utc('2026-10-21T15:00:00'));
    await apply(postId, ownerId, { sitterId: oid(S.sasha) }, utc('2026-10-21T15:30:00'));
    return postId;
  };

  test('48 h 30 avant : rien ; 47 h 55 avant : push + cloche « 2 gardien(s) », type application_new + candidature en attente, AUCUN e-mail ; jamais deux fois', async () => {
    const postId = await twoFresh();
    const early = await run('2026-10-21T17:00:00');
    expect(early.sent).toHaveLength(0);
    expect(early.skipped.not_due).toBeGreaterThanOrEqual(1);
    const r = await run('2026-10-21T17:35:00'); // 19 h 35 Paris
    expect(r.sent).toEqual([expect.objectContaining({ slot: 'x48', postId, candidates: 2, tz: 'Europe/Paris' })]);
    expect(mockPushes).toHaveLength(1);
    expect(mockPushes[0].tokens).toEqual(['jeton-nicola']);
    expect(mockPushes[0].notification.title).toBe('Ta demande expire dans 2 jours');
    expect(mockPushes[0].notification.body).toBe('2 gardien(s) attendent ta réponse : choisis-en un maintenant.');
    expect(mockPushes[0].data.type).toBe('application_new');
    expect(mockPushes[0].data.reminder617).toBe('x48');
    const { buildPreciseRoute } = require('../src/utils/emailLinkBuilder');
    const appId = mockPushes[0].data.applicationId;
    expect(buildPreciseRoute('application_new', mockPushes[0].data, 'owner')).toBe(`/application/${appId}`);
    const target = await Application.findById(appId).lean();
    expect(String(target.postId)).toBe(postId);
    expect(target.status).toBe('pending');
    expect(mockMails).toHaveLength(0);
    const b = await bell(O.nicola, 'owner');
    expect(b).toHaveLength(1);
    expect(b[0].body).toBe('2 gardien(s) attendent ta réponse : choisis-en un maintenant.');
    expect((await run('2026-10-21T18:35:00')).sent).toHaveLength(0);
    expect(await Reminder.countDocuments({ slot: 'x48' })).toBe(1);
  });

  test('un rappel 615 parti il y a moins de 2 h : on attend ; au-delà de 2 h : part', async () => {
    const postId = await twoFresh();
    await Reminder615.collection.insertOne({ postId: oid(postId), slot: 'r1', ownerId: oid(O.nicola), createdAt: utc('2026-10-21T16:30:00'), updatedAt: utc('2026-10-21T16:30:00') });
    const r = await run('2026-10-21T17:35:00');
    expect(r.sent).toHaveLength(0);
    expect(r.skipped.gap).toBe(1);
    expect((await run('2026-10-21T18:35:00')).sent).toEqual([expect.objectContaining({ slot: 'x48' })]);
  });

  test('jamais la nuit (23 h à Paris) ; part à 8 h 05', async () => {
    await twoFresh();
    const night = await run('2026-10-21T21:00:00');
    expect(night.sent).toHaveLength(0);
    expect(night.skipped.night).toBe(1);
    expect((await run('2026-10-22T06:05:00')).sent).toEqual([expect.objectContaining({ slot: 'x48' })]);
  });

  test('décidé, sans date, +test, staff : rien', async () => {
    const decided = await twoFresh();
    await Application.updateOne({ postId: oid(decided), walkerId: oid(W.paul) }, { $set: { status: 'accepted' } });
    expect((await run('2026-10-21T17:35:00')).skipped.decided).toBe(1);
    await Post.deleteMany({}); await Application.deleteMany({});
    await twoFresh(O.nicola, { startDate: null, endDate: null });
    expect((await run('2026-10-21T17:35:00')).skipped.no_date).toBe(1);
    await Post.deleteMany({}); await Application.deleteMany({});
    await twoFresh(O.test);
    expect((await run('2026-10-21T17:35:00')).skipped.test).toBe(1);
    await Post.deleteMany({}); await Application.deleteMany({});
    await twoFresh(O.staff);
    expect((await run('2026-10-21T17:35:00')).skipped.staff).toBe(1);
    expect(mockPushes).toHaveLength(0);
  });

  test('expiration = endDate sinon startDate (règle openRequestFilter) ; moins de 30 min avant : plus rien', async () => {
    // Sans endDate : expiration = début 18 h 30 Paris = 16:30Z → x48 dû dès 21/10 16:30Z.
    await twoFresh(O.nicola, { endDate: null });
    expect((await run('2026-10-21T16:00:00')).skipped.not_due).toBeGreaterThanOrEqual(1);
    expect((await run('2026-10-21T16:35:00')).sent).toEqual([expect.objectContaining({ slot: 'x48' })]);
    await Reminder.deleteMany({});
    expect((await run('2026-10-23T16:15:00')).skipped.too_late).toBe(1);
  });
});

describe('décisions pures', () => {
  const tz = 'Europe/Paris';
  test('decideProvider : 24 h, nuit, doublon', () => {
    const appliedAt = utc('2026-10-20T07:00:00');
    expect(svc.decideProvider({ now: utc('2026-10-21T06:59:00'), appliedAt, tz }).why).toBe('not_due');
    expect(svc.decideProvider({ now: utc('2026-10-21T07:00:00'), appliedAt, tz }).slot).toBe('p24');
    expect(svc.decideProvider({ now: utc('2026-10-21T21:00:00'), appliedAt, tz }).why).toBe('night');
    expect(svc.decideProvider({ now: utc('2026-10-21T07:00:00'), appliedAt, tz, sent: [{ slot: 'p24' }] }).why).toBe('done');
  });
  test('decideOwnerExpiry : 48 h, écart 2 h avec 615, nuit, trop tard, sans date', () => {
    const expiresAt = utc('2026-10-23T17:30:00');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T17:00:00'), expiresAt, tz }).why).toBe('not_due');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T17:35:00'), expiresAt, tz }).slot).toBe('x48');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T17:35:00'), expiresAt, tz, sent615: [{ createdAt: utc('2026-10-21T16:00:00') }] }).why).toBe('gap');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T17:35:00'), expiresAt, tz, sent615: [{ createdAt: utc('2026-10-21T15:00:00') }] }).slot).toBe('x48');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T21:00:00'), expiresAt, tz }).why).toBe('night');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-23T17:10:00'), expiresAt, tz }).why).toBe('too_late');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T17:35:00'), expiresAt: null, tz }).why).toBe('no_date');
    expect(svc.decideOwnerExpiry({ now: utc('2026-10-21T17:35:00'), expiresAt, tz, sent: [{ slot: 'x48' }] }).why).toBe('done');
  });
  test('les 4 gabarits existent dans les 9 langues', () => {
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      const j = require(`../src/locales/${l}/notifications.json`);
      for (const k of ['application_reminder_provider_617', 'request_expiry_617', 'review_request_617', 'application_new_617']) {
        expect(j[k] && j[k].title && j[k].body).toBeTruthy();
      }
      expect(j.application_reminder_provider_617.body).toContain('{{ownerName}}');
      expect(j.request_expiry_617.body).toContain('{{candidates}}');
      expect(j.review_request_617.title).toContain('{{providerName}}');
      expect(j.application_new_617.title).toContain('{{candidateName}}');
      expect(j.application_new_617.body).toContain('{{candidates}}');
    }
  });
});
