// 1610 (SAM, 16/10/2026) — « Partagez votre fiche » : UNE notification (cloche +
// téléphone, JAMAIS d'e-mail) par personne, aux gardiens/promeneurs réels avec une
// ville, jamais la nuit, étalée. VRAIE base Mongo en mémoire, vrai sendNotification
// (gabarits 9 langues) ; Firebase et SMTP CAPTÉS : rien ne sort.
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

const PARIS = { type: 'Point', coordinates: [2.3522, 48.8566] };
const DALLAS = { type: 'Point', coordinates: [-96.797, 32.7767] };
let mongo; let Sitter; let Walker; let Notification; let Registry; let svc;
const S = {}; const W = {};
const oid = (v) => new mongoose.Types.ObjectId(v);
const ins = async (Model, doc) => String((await Model.collection.insertOne({ status: 'active', ...doc })).insertedId);
const utc = (s) => new Date(`${s}Z`);
const run = (iso, opts = {}) => svc.runSitterInvites({ now: utc(iso), ...opts });
const bell = (id, role) => Notification.find({ recipientId: oid(id), recipientRole: role, type: 'sitter_invite_1610' }).lean();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Notification = require('../src/models/Notification'); Registry = require('../src/models/SitterInvite1610');
  await Registry.init();
  svc = require('../src/services/sitterInvite1610');
  S.paris = await ins(Sitter, { name: 'Alina', email: 'alina1610@example.test', appLocale: 'fr', city: 'Paris', location: PARIS, fcmTokens: ['jeton-alina'] });
  S.dallasEn = await ins(Sitter, { name: 'Amy', email: 'amy1610@example.test', appLocale: 'en', city: 'Dallas', location: DALLAS, country: 'US', fcmTokens: ['jeton-amy'] });
  S.sansVille = await ins(Sitter, { name: 'Sans', email: 'sans1610@example.test', appLocale: 'fr', city: '', fcmTokens: ['jeton-sans'] });
  S.test = await ins(Sitter, { name: 'Test', email: 'dadaciao84+testsitter1610@example.test', appLocale: 'fr', city: 'Paris', fcmTokens: ['jeton-test'] });
  S.staff = await ins(Sitter, { name: 'Staff', email: 'staff1610@example.test', isStaff: true, appLocale: 'fr', city: 'Paris', fcmTokens: ['jeton-staff'] });
  S.susp = await ins(Sitter, { name: 'Susp', email: 'susp1610@example.test', status: 'suspended', appLocale: 'fr', city: 'Paris', fcmTokens: ['jeton-susp'] });
  S.probe = await ins(Sitter, { name: 'Probe', email: 'probe-1610@invalid.example', appLocale: 'fr', city: 'Paris' });
  // Paul est gardien ET promeneur (même e-mail) : une seule invitation.
  S.paul = await ins(Sitter, { name: 'Paul', email: 'paul1610@example.test', appLocale: 'fr', city: 'Paris', location: PARIS, fcmTokens: ['jeton-paul'] });
  W.paul = await ins(Walker, { name: 'Paul', email: 'paul1610@example.test', appLocale: 'fr', city: 'Paris', fcmTokens: ['jeton-paul-w'] });
  W.lyon = await ins(Walker, { name: 'Léa', email: 'lea1610@example.test', appLocale: 'fr', location: { type: 'Point', coordinates: [4.8357, 45.764], city: 'Lyon' } });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(async () => {
  mockPushes.length = 0; mockMails.length = 0;
  await Promise.all([Notification.deleteMany({}), Registry.deleteMany({})]);
});

test('sélection : réels avec une ville ; jamais test, staff, sonde, suspendu, sans ville ; une personne = une fois', async () => {
  const { candidates, excluded } = await svc.selectCandidates({ now: utc('2026-10-16T10:00:00') });
  const ids = candidates.map((c) => c.id).sort();
  expect(ids).toEqual([S.paris, S.dallasEn, S.paul, W.lyon].sort());
  expect(candidates.find((c) => c.id === S.paul).role).toBe('sitter');
  expect(excluded).toMatchObject({ test: 1, staff: 1, probe: 1, inactive: 1, noCity: 1, samePerson: 1 });
  expect(candidates.find((c) => c.id === S.paris).tz).toBe('Europe/Paris');
  expect(candidates.find((c) => c.id === S.dallasEn).tz).toMatch(/^America\//);
});

test('de jour à Paris : push + cloche, texte exact de Daniel, lien de la fiche avec utm, AUCUN e-mail', async () => {
  const r = await run('2026-10-16T10:00:00'); // 12 h à Paris, 5 h à Dallas (nuit → attend)
  expect(r.sent.map((s) => s.id).sort()).toEqual([S.paris, S.paul, W.lyon].sort());
  expect(r.waitingNight).toBe(1);
  const push = mockPushes.find((m) => m.tokens.includes('jeton-alina'));
  expect(push).toBeTruthy();
  expect(push.notification.title).toBe("Vous n'avez pas encore de client ?");
  expect(push.notification.body).toBe(`Partagez votre fiche HoPetSit aux propriétaires que vous connaissez et à vos voisins : https://www.hopetsit.com/p/sitter/${S.paris}?utm_source=app&utm_medium=share&utm_campaign=sitter_invite`);
  expect(push.data.type).toBe('sitter_invite_1610');
  expect(push.data.route).toBe('/profile');
  expect(push.data.profileUrl).toBe(`https://www.hopetsit.com/p/sitter/${S.paris}?utm_source=app&utm_medium=share&utm_campaign=sitter_invite`);
  expect(mockMails).toHaveLength(0);
  const b = await bell(S.paris, 'sitter');
  expect(b).toHaveLength(1);
  expect(b[0].title).toBe("Vous n'avez pas encore de client ?");
  // Paul : une seule invitation (gardien), aucune au profil promeneur.
  expect(await bell(S.paul, 'sitter')).toHaveLength(1);
  expect(await bell(W.paul, 'walker')).toHaveLength(0);
  // Léa (promeneuse, ville dans location.city) : lien /p/walker/<id>.
  const lea = await bell(W.lyon, 'walker');
  expect(lea).toHaveLength(1);
  expect(lea[0].body).toContain(`/p/walker/${W.lyon}?utm_source=app`);
  expect(await Registry.countDocuments({})).toBe(3);
});

test('jamais deux fois : relancer n’envoie rien ; Dallas reçoit quand il fait jour là-bas, en anglais', async () => {
  await run('2026-10-16T10:00:00');
  expect((await run('2026-10-16T10:10:00')).sent).toHaveLength(0);
  const r = await run('2026-10-16T15:00:00'); // 10 h à Dallas
  expect(r.sent.map((s) => s.id)).toEqual([S.dallasEn]);
  const push = mockPushes.find((m) => m.tokens.includes('jeton-amy'));
  expect(push.notification.title).toBe('No client yet?');
  expect(push.notification.body).toContain(`/p/sitter/${S.dallasEn}?utm_source=app&utm_medium=share&utm_campaign=sitter_invite`);
  expect((await run('2026-10-16T16:00:00')).sent).toHaveLength(0);
  expect(await Registry.countDocuments({})).toBe(4);
  expect(mockMails).toHaveLength(0);
});

test('nuit à Paris (23 h) : rien ne part, tout attend le matin', async () => {
  const r = await run('2026-10-16T21:30:00'); // 23 h 30 à Paris, 16 h 30 à Dallas
  expect(r.sent.map((s) => s.id)).toEqual([S.dallasEn]);
  expect(r.waitingNight).toBe(3);
  expect(mockPushes).toHaveLength(1);
});

test('étalé : limit=1 → un seul envoi par passage ; deux passages simultanés ne doublent pas', async () => {
  expect((await run('2026-10-16T10:00:00', { limit: 1 })).sent).toHaveLength(1);
  const [a, b] = await Promise.all([run('2026-10-16T10:00:00'), run('2026-10-16T10:00:00')]);
  expect(a.sent.length + b.sent.length + 1).toBe(3);
  expect(await Registry.countDocuments({})).toBe(3);
  expect(mockPushes).toHaveLength(2); // Léa n’a pas de téléphone enregistré : cloche seulement
  expect(await Notification.countDocuments({ type: 'sitter_invite_1610' })).toBe(3);
});

test('mode test : seuls les comptes +test reçoivent ; simulation : rien n’est écrit', async () => {
  const dry = await run('2026-10-16T10:00:00', { dryRun: true });
  expect(dry.eligible).toBe(4);
  expect(await Registry.countDocuments({})).toBe(0);
  expect(mockPushes).toHaveLength(0);
  const r = await run('2026-10-16T10:00:00', { testOnly: true });
  expect(r.sent.map((s) => s.id)).toEqual([S.test]);
  expect((await Registry.findOne({ recipientId: oid(S.test) }).lean()).testOnly).toBe(true);
  expect(mockMails).toHaveLength(0);
  // Le mode test n’empêche pas les vrais envois ensuite, et ne les double pas.
  expect((await run('2026-10-16T10:00:00')).sent).toHaveLength(3);
  expect((await run('2026-10-16T10:00:00', { testOnly: true })).sent).toHaveLength(0);
});
