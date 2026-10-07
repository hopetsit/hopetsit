// 615 (ZOE, 07/10/2026) — RAPPEL AU PROPRIÉTAIRE QUI A DES CANDIDATS SANS CHOISIR.
// Cas réel : balade de Nicola (Paris 11e, 05/10), 2 candidatures, personne choisi,
// demande expirée. VRAIE base Mongo en mémoire, vrai sendNotification (cloche,
// gabarits 9 langues) ; Firebase et SMTP CAPTÉS : rien ne sort.
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
const DALLAS = { lat: 32.7767, lng: -96.797 };
let mongo; let Owner; let Walker; let Sitter; let Post; let Application; let Notification; let Reminder; let svc;
const W = {}; const S = {}; const O = {};
const oid = (v) => new mongoose.Types.ObjectId(v);
const ins = async (Model, doc) => String((await Model.collection.insertOne({ status: 'active', ...doc })).insertedId);
const utc = (s) => new Date(`${s}Z`);

// Balade « 18 h 30 » le 20/10 à Paris (heure murale enregistrée telle quelle, lue en UTC).
// Paris = UTC+2 le 20/10 → instant réel 16:30Z. 1re candidature à 9 h (07:00Z).
const mkPost = async (ownerId, extra = {}) => String((await Post.collection.insertOne({
  ownerId: oid(ownerId), postType: 'request', status: 'open', hidden: false, body: 'Balade pour Rex',
  serviceTypes: ['dog_walking'], location: { city: 'Paris', ...PARIS },
  startDate: utc('2026-10-20T18:30:00'), endDate: utc('2026-10-20T19:30:00'),
  reservedBy: { bookingId: null }, createdAt: utc('2026-10-19T10:00:00'), ...extra,
})).insertedId);
const apply = async (postId, ownerId, provider, at, extra = {}) => String((await Application.collection.insertOne({
  postId: oid(postId), ownerId: oid(ownerId), ...provider, status: 'pending', createdAt: at, updatedAt: at, ...extra,
})).insertedId);
const run = (iso) => svc.runApplicationReminders({ now: utc(iso) });
const bell = (ownerId) => Notification.find({ recipientId: oid(ownerId), type: 'application_new' }).lean();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Walker = require('../src/models/Walker'); Sitter = require('../src/models/Sitter');
  Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Notification = require('../src/models/Notification'); Reminder = require('../src/models/ApplicationReminder615');
  await Reminder.init();
  svc = require('../src/services/applicationReminder615');

  O.nicola = await ins(Owner, { name: 'Nicola', email: 'nicola615@example.test', appLocale: 'fr', fcmTokens: ['jeton-nicola'] });
  O.en = await ins(Owner, { name: 'Amy', email: 'amy615@example.test', appLocale: 'en', fcmTokens: ['jeton-amy'], country: 'US' });
  O.test = await ins(Owner, { name: 'Test', email: 'dadaciao84+testowner615@example.test', appLocale: 'fr', fcmTokens: ['jeton-test'] });
  O.staff = await ins(Owner, { name: 'Staff', email: 'staff615@example.test', isStaff: true, appLocale: 'fr', fcmTokens: ['jeton-staff'] });
  O.susp = await ins(Owner, { name: 'Susp', email: 'susp615@example.test', status: 'suspended', appLocale: 'fr', fcmTokens: ['jeton-susp'] });
  W.a = await ins(Walker, { name: 'Paul', email: 'paul615@example.test' });
  W.b = await ins(Walker, { name: 'John', email: 'john615@example.test' });
  W.test = await ins(Walker, { name: 'T', email: 'x+testwalker615@example.test' });
  S.a = await ins(Sitter, { name: 'Sasha', email: 'sasha615@example.test' });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => {
  mockPushes.length = 0; mockMails.length = 0;
  await Promise.all([Post.deleteMany({}), Application.deleteMany({}), Notification.deleteMany({}), Reminder.deleteMany({})]);
});

const twoCandidates = async (ownerId = O.nicola, extra = {}) => {
  const postId = await mkPost(ownerId, extra);
  await apply(postId, ownerId, { walkerId: oid(W.a) }, utc('2026-10-20T07:00:00'));
  await apply(postId, ownerId, { walkerId: oid(W.b) }, utc('2026-10-20T07:40:00'));
  return postId;
};

describe('le parcours de Nicola : 2 candidats, aucun choix', () => {
  test('r1 2 h après la 1re candidature : push + cloche, AUCUN e-mail, texte exact', async () => {
    expect((await run('2026-10-20T08:55:00')).sent).toHaveLength(0); // 1 h 55 : trop tôt
    const postId = await twoCandidates();
    const r = await run('2026-10-20T09:05:00'); // 11 h 05 à Paris
    expect(r.sent).toEqual([expect.objectContaining({ postId, slot: 'r1', candidates: 2, tz: 'Europe/Paris' })]);
    expect(mockPushes).toHaveLength(1);
    expect(mockPushes[0].tokens).toEqual(['jeton-nicola']);
    expect(mockPushes[0].notification.title).toBe('2 candidats t’attendent');
    expect(mockPushes[0].notification.body).toBe('Tu as 2 candidats pour ta balade de 18 h 30 — choisis le tien.');
    // Le lien : type application_new + une candidature en attente de CETTE demande
    // → les apps installées (≥ 602) ouvrent les candidats de la demande.
    expect(mockPushes[0].data.type).toBe('application_new');
    expect(mockPushes[0].data.postId).toBe(postId);
    // Miroir serveur du routeur de l'app (DeepLinkService.routeForNotification, ≥ 602).
    const { buildPreciseRoute } = require('../src/utils/emailLinkBuilder');
    const appId = mockPushes[0].data.applicationId;
    expect(buildPreciseRoute('application_new', mockPushes[0].data, 'owner')).toBe(`/application/${appId}`);
    const target = await Application.findById(appId).lean();
    expect(String(target.postId)).toBe(postId);
    expect(target.status).toBe('pending');
    expect(mockPushes[0].data.reminder615).toBe('r1');
    expect(mockMails).toHaveLength(0);
    const b = await bell(O.nicola);
    expect(b).toHaveLength(1);
    expect(b[0].body).toBe('Tu as 2 candidats pour ta balade de 18 h 30 — choisis le tien.');
  });

  test('pas de doublon : relancer le passage ne renvoie rien ; r2 2 h avant, puis plus jamais', async () => {
    await twoCandidates();
    expect((await run('2026-10-20T09:05:00')).sent).toHaveLength(1);
    expect((await run('2026-10-20T09:15:00')).sent).toHaveLength(0);
    expect((await run('2026-10-20T13:00:00')).sent).toHaveLength(0); // r2 pas encore dû (14:30Z)
    const r2 = await run('2026-10-20T14:35:00'); // 16 h 35 à Paris, balade à 18 h 30
    expect(r2.sent).toEqual([expect.objectContaining({ slot: 'r2' })]);
    expect((await run('2026-10-20T15:30:00')).sent).toHaveLength(0);
    expect((await run('2026-10-20T16:10:00')).sent).toHaveLength(0);
    expect(mockPushes).toHaveLength(2);
    expect(await Reminder.countDocuments({})).toBe(2);
    expect(mockMails).toHaveLength(0);
  });

  test('deux passages simultanés (deux serveurs) : un seul rappel', async () => {
    await twoCandidates();
    const [a, b] = await Promise.all([run('2026-10-20T09:05:00'), run('2026-10-20T09:05:00')]);
    expect(a.sent.length + b.sent.length).toBe(1);
    expect(mockPushes).toHaveLength(1);
  });

  test('1 seul candidat : phrase au singulier', async () => {
    const postId = await mkPost(O.nicola);
    await apply(postId, O.nicola, { walkerId: oid(W.a) }, utc('2026-10-20T07:00:00'));
    await run('2026-10-20T09:05:00');
    expect(mockPushes[0].notification.body).toBe('Tu as 1 candidat pour ta balade de 18 h 30 — accepte-le pour réserver.');
  });
});

describe('jamais la nuit (22 h - 8 h, heure locale du propriétaire)', () => {
  test('candidature à 20 h : rien à 23 h 30 ni à 7 h 50, le rappel part à 8 h 05', async () => {
    const postId = await mkPost(O.nicola, { startDate: utc('2026-10-22T18:00:00'), endDate: utc('2026-10-22T19:00:00') });
    await apply(postId, O.nicola, { walkerId: oid(W.a) }, utc('2026-10-20T18:00:00')); // 20 h Paris
    const night = await run('2026-10-20T21:30:00'); // 23 h 30 Paris
    expect(night.sent).toHaveLength(0);
    expect(night.skipped.night).toBe(1);
    expect((await run('2026-10-21T05:50:00')).sent).toHaveLength(0); // 7 h 50
    expect((await run('2026-10-21T06:05:00')).sent).toHaveLength(1); // 8 h 05
    expect(mockPushes[0].notification.body).toBe('Tu as 1 candidat pour ta balade du 22 octobre à 18 h — accepte-le pour réserver.');
  });

  test('Dallas : la nuit est celle de Dallas, pas celle de Paris', async () => {
    const postId = await mkPost(O.en, {
      location: { city: 'Dallas', ...DALLAS }, startDate: utc('2026-10-22T18:00:00'), endDate: utc('2026-10-22T19:00:00'),
    });
    await apply(postId, O.en, { walkerId: oid(W.a) }, utc('2026-10-20T12:00:00'));
    // 03:30Z = 22 h 30 à Dallas (UTC-5) → nuit, alors qu'il est 5 h 30 à Paris
    expect((await run('2026-10-21T03:30:00')).skipped.night).toBe(1);
    // 13:00Z = 8 h à Dallas → part, en anglais
    const r = await run('2026-10-21T13:05:00');
    expect(r.sent).toEqual([expect.objectContaining({ tz: 'America/Chicago' })]);
    expect(mockPushes[0].notification.body).toBe('You have 1 candidate for your walk on October 22 at 6:00 PM — accept to book.');
  });
});

describe('jamais pour les comptes de test, staff, suspendus', () => {
  test.each([['+test', 'test'], ['staff', 'staff'], ['suspendu', 'susp']])('%s', async (_, key) => {
    await twoCandidates(O[key]);
    const r = await run('2026-10-20T09:05:00');
    expect(r.sent).toHaveLength(0);
    expect(mockPushes).toHaveLength(0);
    expect(await Reminder.countDocuments({})).toBe(0);
  });
  test('un candidat de test ne déclenche rien chez un vrai propriétaire', async () => {
    const postId = await mkPost(O.nicola);
    await apply(postId, O.nicola, { walkerId: oid(W.test) }, utc('2026-10-20T07:00:00'));
    expect((await run('2026-10-20T09:05:00')).sent).toHaveLength(0);
    expect(mockPushes).toHaveLength(0);
  });
});

describe('arrêt dès qu\'il y a une décision', () => {
  test('une candidature acceptée : plus aucun rappel', async () => {
    const postId = await twoCandidates();
    await Application.updateOne({ postId: oid(postId), walkerId: oid(W.a) }, { $set: { status: 'accepted' } });
    const r = await run('2026-10-20T09:05:00');
    expect(r.sent).toHaveLength(0);
    expect(r.skipped.decided).toBe(1);
  });
  test('une candidature refusée : plus aucun rappel', async () => {
    const postId = await twoCandidates();
    await Application.updateOne({ postId: oid(postId), walkerId: oid(W.b) }, { $set: { status: 'rejected' } });
    expect((await run('2026-10-20T09:05:00')).skipped.decided).toBe(1);
  });
  test('décision prise entre r1 et r2 : pas de r2', async () => {
    const postId = await twoCandidates();
    expect((await run('2026-10-20T09:05:00')).sent).toHaveLength(1);
    await Application.updateOne({ postId: oid(postId), walkerId: oid(W.a) }, { $set: { status: 'accepted' } });
    expect((await run('2026-10-20T14:35:00')).sent).toHaveLength(0);
    expect(mockPushes).toHaveLength(1);
  });
  test('demande réservée, fermée ou masquée : rien', async () => {
    await twoCandidates(O.nicola, { reservedBy: { bookingId: oid() } });
    expect((await run('2026-10-20T09:05:00')).skipped.reserved).toBe(1);
    await Post.deleteMany({}); await Application.deleteMany({});
    await twoCandidates(O.nicola, { status: 'closed' });
    expect((await run('2026-10-20T09:05:00')).skipped.closed).toBe(1);
  });
  test('service commencé (ou dans moins de 30 min) : plus rien', async () => {
    await twoCandidates();
    const r = await run('2026-10-20T16:05:00'); // 18 h 05, balade à 18 h 30
    expect(r.sent).toHaveLength(0);
    expect(r.skipped.too_late).toBe(1);
  });
});

describe('moments', () => {
  test('r1 sauté si r2 tombe moins de 2 h plus tard (jamais deux rappels rapprochés)', async () => {
    const postId = await mkPost(O.nicola, { startDate: utc('2026-10-20T14:30:00') }); // 12:30Z réel
    await apply(postId, O.nicola, { walkerId: oid(W.a) }, utc('2026-10-20T07:00:00'));
    const r = await run('2026-10-20T09:05:00'); // r1 dû, r2 dû à 10:30Z
    expect(r.skipped.r2_soon).toBe(1);
    expect((await run('2026-10-20T10:35:00')).sent).toEqual([expect.objectContaining({ slot: 'r2' })]);
    expect(await Reminder.countDocuments({})).toBe(1);
  });
  test('garde : r2 24 h avant le début, « ta garde du 23 octobre »', async () => {
    const postId = await mkPost(O.nicola, {
      serviceTypes: ['pet_sitting'], startDate: utc('2026-10-23T00:00:00'), endDate: utc('2026-10-25T00:00:00'),
    });
    await apply(postId, O.nicola, { sitterId: oid(S.a) }, utc('2026-10-20T07:00:00'));
    await apply(postId, O.nicola, { walkerId: oid(W.b) }, utc('2026-10-20T08:00:00'));
    expect((await run('2026-10-20T09:05:00')).sent).toEqual([expect.objectContaining({ slot: 'r1', candidates: 2 })]);
    expect(mockPushes[0].notification.body).toBe('Tu as 2 candidats pour ta garde du 23 octobre — choisis le tien.');
    // 23/10 00:00 Paris = 22/10 22:00Z ; r2 à 21/10 22:00Z = minuit à Paris → nuit → 8 h.
    expect((await run('2026-10-21T22:05:00')).skipped.night).toBe(1);
    expect((await run('2026-10-22T06:05:00')).sent).toEqual([expect.objectContaining({ slot: 'r2' })]);
  });
});

describe('textes : 9 langues', () => {
  const { buildReminderText } = require('../src/utils/applicationReminderText615');
  test.each(['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'])('%s : titre et phrase complets, nombre présent', (l) => {
    for (const n of [1, 2]) {
      const t = buildReminderText({ candidates: n, serviceKind: 'walk', start: '2026-10-20T14:30:00.000Z', hasTime: true, sameDay: true }, l);
      expect(t.title.length).toBeGreaterThan(5);
      expect(t.body).toContain(String(n));
      expect(`${t.title}${t.body}`).not.toMatch(/\{|undefined|NaN/);
    }
  });
  test('le gabarit existe dans les 9 fichiers de notifications', () => {
    for (const l of ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      // eslint-disable-next-line global-require, import/no-dynamic-require
      const cat = require(`../src/locales/${l}/notifications.json`);
      expect(cat.application_reminder_615.body).toBe('{{reminderBody}}');
    }
  });
  test('exemple de Daniel', () => {
    expect(buildReminderText({ candidates: 2, serviceKind: 'walk', start: '2026-10-20T14:30:00.000Z', hasTime: true, sameDay: true }, 'fr').body)
      .toBe('Tu as 2 candidats pour ta balade de 14 h 30 — choisis le tien.');
  });
});

describe('cloche : le texte relu par l\'app (GET /notifications/my) est le bon', () => {
  const { renderNotificationContent } = require('../src/services/notificationSender');
  test('rappel : la cloche affiche « tu as N candidats », pas « nouvelle candidature »', () => {
    const data = { reminder615: 'r1', candidates: '2', serviceKind: 'walk', startWall: '2026-10-20T14:30:00.000Z', hasTime: '1', sameDay: '1', applicationId: 'x', postId: 'y' };
    expect(renderNotificationContent('application_new', data, 'fr').body).toBe('Tu as 2 candidats pour ta balade de 14 h 30 — choisis le tien.');
    expect(renderNotificationContent('application_new', data, 'en').body).toBe('You have 2 candidates for your walk at 2:30 PM — pick yours.');
    // Une vraie candidature garde son texte.
    expect(renderNotificationContent('application_new', { applicationId: 'x' }, 'fr').body).toBe("Un prestataire t'a envoyé une demande.");
  });
  test('alerte 612 relue : plus de « cherche  · . » (bug mesuré sur le banc le 07/10)', () => {
    const data = { ownerName: 'Camille Durand', serviceType: 'dog_walking', city: 'Paris', startDate: '2026-10-09T18:30:00.000Z', endDate: '2026-10-09T19:00:00.000Z', postId: 'p' };
    const fr = renderNotificationContent('new_request_nearby', data, 'fr');
    expect(fr.body).toBe("Camille Durand cherche un promeneur · Paris · 9 octobre. Ouvre l'app pour postuler.");
    expect(fr.body).not.toMatch(/ {2}|· \./);
  });
});
