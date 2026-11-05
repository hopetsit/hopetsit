// 05/11/2026 (LEO, plan B1 de BOB — ordre de Daniel « je veux réussir mes transactions ») — « POSER UNE
// QUESTION À <PRÉNOM> » AVANT DE PAYER, depuis la page des candidats du site (/application/<id>).
// Aucune route neuve : le site enchaîne les DEUX routes que l'app utilise déjà —
//   POST /conversations/start?sitterId=… (ou { walkerId }) → conversation créée ou retrouvée ;
//   POST /conversations/:id/messages { body }            → message + notification habituelle.
// Ce test prouve, avec de VRAIS routeurs et une VRAIE base Mongo en mémoire, que :
//   1. un propriétaire SANS l'app, SANS réservation payée, en phase de lancement (< 1 000 comptes), peut créer
//      la conversation depuis une candidature et poser sa question (gardien ET promeneur) ;
//   2. le gardien reçoit sa notification habituelle : push tout de suite, e-mail différé 15 min si non lu ;
//   3. la RÉPONSE du gardien déclenche l'e-mail « Nouveau message » au propriétaire (sans l'app), avec le lien
//      vers la conversation ; jamais d'e-mail immédiat (règle du 29/09), un seul par conversation non lue ;
//   4. une 2e question retrouve la même conversation (pas de doublon) ;
//   5. un propriétaire +test ne reçoit aucun e-mail (règle des comptes de test).
// Zone fictive lat -35 / lng -30. Sans SMTP, sans Firebase, sans socket réel.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  requireVerifiedEmail: (req, res, next) => next(),
  attachUserFromToken: (req, res, next) => next(),
  attachOwnerFromToken: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));
const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }), sendTemplatedEmail: jest.fn(async () => ({})) };
});
const PUSHES = [];
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => { PUSHES.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) }; }) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({
  emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), emitToConversation: jest.fn(), emitChatMessage: jest.fn(),
  isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false), touchConversationOpen: jest.fn(async () => {}),
  buildPresenceIndex: jest.fn(async () => new Map()), isIdentityOnline: jest.fn(() => false),
}));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const MIN = 60 * 1000;
const PASS = 'MotDePasseTest0511!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': 'web' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const QUESTION = 'Avez-vous déjà gardé un chien comme le mien ?';
const ANSWER = 'Oui, deux labradors cet été. Je peux passer le voir samedi.';
let mongo; let app;
let Owner; let Sitter; let Walker; let Pet; let Post; let Application; let Conversation; let Message; let ChatUnreadEmail;
let sched;
const S = {};
const mailsTo = (addr) => MAILS.filter((m) => m.to === addr);
const pushesTo = (token) => PUSHES.filter((m) => (m.tokens || []).includes(token) && /new_message/i.test(String(m.data && m.data.type)));

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); Post = require('../src/models/Post'); Application = require('../src/models/Application');
  Conversation = require('../src/models/Conversation'); Message = require('../src/models/Message');
  ChatUnreadEmail = require('../src/models/ChatUnreadEmail599');
  require('../src/models/Booking'); require('../src/models/Block'); require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Conversation.init(), Message.init(), ChatUnreadEmail.init()]);
  const fr = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr' };
  // Propriétaire du SITE : aucun jeton push (pas l'app), e-mail normal.
  S.owner = await Owner.create({ ...fr, name: 'Karine Site', email: 'leo0511+owner@example.test', acceptedTerms: true });
  S.ownerTest = await Owner.create({ ...fr, name: 'Compte Test', email: 'dadaciao84+test0511@gmail.com', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Rex', petType: 'dog' });
  S.petTest = await Pet.create({ ownerId: S.ownerTest._id, petName: 'Mina', petType: 'cat' });
  // Gardien et promeneur AVEC l'app (jeton push).
  S.hanene = await Sitter.create({ ...fr, name: 'Hanene Test', email: 'leo0511+hanene@example.test', dailyRate: 18, fcmTokens: ['tok-hanene-0511'] });
  S.marc = await Walker.create({ ...fr, name: 'Marc Test', email: 'leo0511+marc@example.test', fcmTokens: ['tok-marc-0511'], walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }] });
  sched = require('../src/services/chatUnreadEmailScheduler599');
  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  app.use('/conversations', require('../src/routes/conversationRoutes'));
}, 180000);
afterAll(async () => {
  try { require('../src/services/applicationEmail2610').stopApplicationEmailScheduler(); } catch (_) { /* pas démarré */ }
  sched.stopChatUnreadEmailScheduler();
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

const createPost = (body, who = S.owner, pet = S.pet) => request(app).post('/posts').set(hdr(who._id, 'owner')).send({
  body: 'Demande de test 0511 (question avant de payer), zone test.', language: 'fr', animalCount: 1, location: LOC, petIds: [String(pet._id)], ...body,
});
const apply = async (post, who, role, owner = S.owner, extra = {}) => {
  const r = await request(app).post(`/applications?ownerId=${owner._id}`).set(hdr(who._id, role)).send({ postId: post.id, description: 'Disponible.', ...extra });
  if (r.status !== 201) console.log('apply →', r.status, JSON.stringify(r.body)); // eslint-disable-line no-console
  expect(r.status).toBe(201);
  await wait(300);
  return r.body.application;
};
/** Ce que fait le site (OwnerCandidatesPay3110.askSend) : conversation puis message. */
const askFromSite = async (owner, provider, role, text) => {
  const start = role === 'walker'
    ? await request(app).post('/conversations/start').set(hdr(owner._id, 'owner')).send({ walkerId: String(provider._id) })
    : await request(app).post(`/conversations/start?sitterId=${provider._id}`).set(hdr(owner._id, 'owner')).send({});
  expect(start.status).toBe(201);
  const convId = String(start.body.conversation.id || start.body.conversation._id);
  expect(convId).toMatch(/^[a-f0-9]{24}$/);
  const msg = await request(app).post(`/conversations/${convId}/messages`).set(hdr(owner._id, 'owner')).send({ body: text });
  expect(msg.status).toBe(201);
  await wait(400); // la notification part en tâche de fond (sendNotification non attendu par la route)
  return { convId, message: msg.body.message };
};

describe('B1 — « Poser une question à <prénom> » avant de payer (routes existantes, phase de lancement)', () => {
  test('0. mise en place : une demande « garde » (dates posées) avec un candidat gardien, et une demande « balade » avec un candidat promeneur', async () => {
    const d = (n) => { const x = new Date(Date.now() + n * 86400000); return `${x.toISOString().slice(0, 10)}T00:00:00.000Z`; };
    S.post = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', startDate: d(10), endDate: d(13), animalTypes: ['dog'] }).expect(201)).body.post;
    S.app1 = await apply(S.post, S.hanene, 'sitter', S.owner, { timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: d(10) });
    expect(S.app1.status).toBe('pending');
    S.postW = (await createPost({ body: 'Balade pour Rex.', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', walkDurationMinutes: 30, dateMode: 'tbd', animalTypes: ['dog'] }).expect(201)).body.post;
    S.app2 = await apply(S.postW, S.marc, 'walker', S.owner, { serviceType: 'dog_walking', duration: 30, serviceDate: d(8), timeSlot: 'morning' });
    expect(S.app2.status).toBe('pending');
    // Aucune réservation payée, aucun abonnement : seule la phase de lancement ouvre le chat.
    const { isLaunchPhase } = require('../src/services/chatAccessService');
    expect(await isLaunchPhase()).toBe(true);
    MAILS.length = 0; PUSHES.length = 0;
  }, 60000);

  test('1. gardien : la question crée la conversation et le message ; Hanene a son push tout de suite, pas d\'e-mail immédiat, e-mail 15 min plus tard si non lu', async () => {
    const { convId, message } = await askFromSite(S.owner, S.hanene, 'sitter', QUESTION);
    S.conv1 = convId;
    expect(message.body).toBe(QUESTION);
    const conv = await Conversation.findById(convId).lean();
    expect(String(conv.ownerId)).toBe(String(S.owner._id));
    expect(String(conv.sitterId)).toBe(String(S.hanene._id));
    expect(conv.sitterUnreadCount).toBe(1);
    expect(await Message.countDocuments({ conversationId: convId })).toBe(1);
    // Push au gardien, au nom du propriétaire, avec la question.
    const p = pushesTo('tok-hanene-0511');
    expect(p.length).toBeGreaterThanOrEqual(1);
    const flat = JSON.stringify(p[0]);
    expect(flat).toContain('Karine');
    expect(flat).toContain(QUESTION);
    // E-mail : rien tout de suite (règle du 29/09), une attente de 15 min posée.
    expect(mailsTo('leo0511+hanene@example.test')).toHaveLength(0);
    const pending = await ChatUnreadEmail.find({ conversationId: convId, recipientId: String(S.hanene._id) }).lean();
    expect(pending).toHaveLength(1);
    expect(pending[0].sentAt).toBeNull();
    const t0 = Date.now();
    expect((await sched.runOnce({ now: t0 + 14 * MIN })).sent).toBe(0);
    const r = await sched.runOnce({ now: t0 + 16 * MIN });
    expect(r.sent).toBe(1);
    const m = mailsTo('leo0511+hanene@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('Nouveau message sur HoPetSit');
    expect(m[0].html).toContain('Karine');
    expect(m[0].html).toContain(QUESTION.replace(/'/g, '&#39;').split(' ')[0]); // « Avez-vous »
    expect(m[0].text).toContain(`https://www.hopetsit.com/chat/${convId}`);
    expect(m[0].html).not.toContain('{{');
  }, 60000);

  test('2. la RÉPONSE du gardien déclenche l\'e-mail au propriétaire SANS l\'app (différé 15 min, lien vers la conversation), aucun push (pas de jeton)', async () => {
    MAILS.length = 0; PUSHES.length = 0;
    const r = await request(app).post(`/conversations/${S.conv1}/messages`).set(hdr(S.hanene._id, 'sitter')).send({ body: ANSWER });
    expect(r.status).toBe(201);
    await wait(400);
    const conv = await Conversation.findById(S.conv1).lean();
    expect(conv.ownerUnreadCount).toBe(1);
    expect(PUSHES).toHaveLength(0); // le propriétaire n'a pas l'app : rien à pousser
    expect(mailsTo('leo0511+owner@example.test')).toHaveLength(0); // pas d'e-mail immédiat
    const pending = await ChatUnreadEmail.find({ conversationId: S.conv1, recipientId: String(S.owner._id) }).lean();
    expect(pending).toHaveLength(1);
    const t0 = Date.now();
    expect((await sched.runOnce({ now: t0 + 16 * MIN })).sent).toBe(1);
    const m = mailsTo('leo0511+owner@example.test');
    expect(m).toHaveLength(1);
    expect(m[0].subject).toBe('Nouveau message sur HoPetSit');
    expect(m[0].html).toContain('Hanene');
    expect(m[0].html).toContain('deux labradors');
    expect(m[0].text).toContain(`https://www.hopetsit.com/chat/${S.conv1}`);
    expect(m[0].html).not.toContain('{{');
    // Une 2e réponse avant lecture : pas de 2e e-mail (un seul par conversation non lue).
    MAILS.length = 0;
    await request(app).post(`/conversations/${S.conv1}/messages`).set(hdr(S.hanene._id, 'sitter')).send({ body: 'Et dimanche aussi.' }).expect(201);
    await wait(300);
    expect((await sched.runOnce({ now: t0 + 40 * MIN })).sent).toBe(0);
    expect(mailsTo('leo0511+owner@example.test')).toHaveLength(0);
  }, 60000);

  test('3. une 2e question retrouve la MÊME conversation (pas de doublon) et le propriétaire peut la lire sur le site (GET messages)', async () => {
    const start = await request(app).post(`/conversations/start?sitterId=${S.hanene._id}`).set(hdr(S.owner._id, 'owner')).send({});
    expect(start.status).toBe(201);
    expect(String(start.body.conversation.id || start.body.conversation._id)).toBe(S.conv1);
    expect(await Conversation.countDocuments({ ownerId: S.owner._id, sitterId: S.hanene._id })).toBe(1);
    await request(app).post(`/conversations/${S.conv1}/messages`).set(hdr(S.owner._id, 'owner')).send({ body: 'Pouvez-vous passer le voir avant ?' }).expect(201);
    const list = await request(app).get(`/conversations/${S.conv1}/messages`).set(hdr(S.owner._id, 'owner'));
    expect(list.status).toBe(200);
    const bodies = (list.body.messages || []).map((x) => x.body);
    expect(bodies).toEqual(expect.arrayContaining([QUESTION, ANSWER, 'Pouvez-vous passer le voir avant ?']));
  }, 60000);

  test('4. promeneur : même parcours (POST /conversations/start { walkerId }), push à Marc avec la question', async () => {
    MAILS.length = 0; PUSHES.length = 0;
    const q = 'Avez-vous déjà promené un chien comme le mien ?';
    const { convId } = await askFromSite(S.owner, S.marc, 'walker', q);
    const conv = await Conversation.findById(convId).lean();
    expect(String(conv.walkerId)).toBe(String(S.marc._id));
    expect(conv.sitterId).toBeNull();
    const p = pushesTo('tok-marc-0511');
    expect(p.length).toBeGreaterThanOrEqual(1);
    expect(JSON.stringify(p[0])).toContain(q);
    expect(await ChatUnreadEmail.countDocuments({ conversationId: convId, recipientId: String(S.marc._id) })).toBe(1);
  }, 60000);

  test('5. propriétaire +test : la question part, mais aucune attente d\'e-mail n\'est posée pour lui quand on lui répond (comptes de test = jamais d\'e-mail)', async () => {
    const d = (n) => { const x = new Date(Date.now() + n * 86400000); return `${x.toISOString().slice(0, 10)}T00:00:00.000Z`; };
    const post = (await createPost({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', startDate: d(20), endDate: d(22), animalTypes: ['cat'] }, S.ownerTest, S.petTest).expect(201)).body.post;
    await apply(post, S.hanene, 'sitter', S.ownerTest, { timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: d(20) });
    MAILS.length = 0;
    const { convId } = await askFromSite(S.ownerTest, S.hanene, 'sitter', 'Avez-vous déjà gardé un chat comme le mien ?');
    await request(app).post(`/conversations/${convId}/messages`).set(hdr(S.hanene._id, 'sitter')).send({ body: 'Oui, bien sûr.' }).expect(201);
    await wait(400);
    expect(await ChatUnreadEmail.countDocuments({ conversationId: convId, recipientId: String(S.ownerTest._id) })).toBe(0);
    await sched.runOnce({ now: Date.now() + 60 * MIN });
    expect(mailsTo('dadaciao84+test0511@gmail.com')).toHaveLength(0);
  }, 60000);
});
