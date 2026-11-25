// 25/11/2026 (BOB, ordre de Daniel : « je veux que les clients comprennent », constat de ZOE) — lot 2511b, serveur :
//   1. notification « tarif à venir » du gardien : titre et texte courts, l'action en premier (9 langues) ;
//   2. refus « il manque un tarif » : phrase dans la langue du prestataire, mêmes codes, mêmes statuts HTTP ;
//   3. cloche et e-mail du PROPRIÉTAIRE : une candidature en « tarif à venir » ne dit plus « choisis et paie » ;
//   5. promeneur sur « garde + balade » : toujours refusé (calcul inchangé), avec un texte clair.
// VRAIS routeurs, VRAIE base Mongo en mémoire, zone fictive lat -35 / lng -30.
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



const PASS = 'MotDePasseTest2511b!';
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const LOC = { city: 'Zone test', lat: -35, lng: -30 };
const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const hdr = (id, role) => ({ 'x-test-user': String(id), 'x-test-role': role, 'X-App-Version': 'web' });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const d = (n) => `${new Date(Date.now() + n * 86400000).toISOString().slice(0, 10)}T00:00:00.000Z`;
let mongo; let app; let Owner; let Sitter; let Walker; let Pet; let Application; let Notification;
const S = {};
const txt = require('../src/utils/rateRefusalText2511');
const sender = require('../src/services/notificationSender');

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Pet = require('../src/models/Pet'); const Post = require('../src/models/Post'); Application = require('../src/models/Application');
  require('../src/models/Conversation'); require('../src/models/Message'); require('../src/models/Booking'); require('../src/models/Block'); Notification = require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init()]);
  const base = { password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE };
  S.owner = await Owner.create({ ...base, appLocale: 'fr', name: 'Marie Site', email: 'bob2511b+owner@example.test', acceptedTerms: true });
  S.pet = await Pet.create({ ownerId: S.owner._id, petName: 'Nana', petType: 'cat' });
  S.hourly = await Sitter.create({ ...base, appLocale: 'fr', name: 'Solene Test', email: 'bob2511b+solene@example.test', hourlyRate: 30 });
  S.daily = await Sitter.create({ ...base, appLocale: 'fr', name: 'Isabelle Test', email: 'bob2511b+isabelle@example.test', dailyRate: 15 });
  S.noneFr = await Sitter.create({ ...base, appLocale: 'fr', name: 'Sans Tarif', email: 'bob2511b+sanstarif@example.test' });
  S.dailyEs = await Sitter.create({ ...base, appLocale: 'es', name: 'Lucia Test', email: 'bob2511b+lucia@example.test', dailyRate: 20 }); // pas de tarif par visite
  S.noneJa = await Sitter.create({ ...base, language: 'ja', name: 'Yuki Test', email: 'bob2511b+yuki@example.test' });
  S.walkerNoRate = await Walker.create({ ...base, appLocale: 'de', name: 'Jonas Test', email: 'bob2511b+jonas@example.test' });
  S.walker = await Walker.create({ ...base, appLocale: 'fr', name: 'Imane Test', email: 'bob2511b+imane@example.test', walkRates: [{ durationMinutes: 60, basePrice: 12, currency: 'EUR', enabled: true }] });
  app = express();
  app.use(express.json());
  app.use('/posts', require('../src/routes/postRoutes'));
  app.use('/applications', require('../src/routes/applicationRoutes'));
  const mk = async (extra) => {
    const p = await request(app).post('/posts').set(hdr(S.owner._id, 'owner')).send({
      body: 'Demande de test, zone test.', language: 'fr', animalCount: 1, location: LOC, petIds: [String(S.pet._id)],
      startDate: d(30), endDate: d(32), animalTypes: ['cat'], ...extra,
    });
    expect(p.status).toBe(201);
    return p.body.post;
  };
  S.garde = await mk({ serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home' });
  S.visite = await mk({ serviceTypes: ['home_visit'], visitsPerDay: 1 });
  S.mixte = await mk({ serviceTypes: ['house_sitting', 'dog_walking'], houseSittingVenue: 'owners_home' });
  await wait(300);
  MAILS.length = 0;
}, 180000);
afterAll(async () => {
  try { require('../src/services/applicationEmail2610').stopApplicationEmailScheduler(); } catch (_) { /* pas démarré */ }
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

const apply = (who, post, role, body = {}) => request(app).post(`/applications?ownerId=${S.owner._id}`).set(hdr(who._id, role))
  .send({ postId: post.id, description: 'Disponible.', timeSlot: 'morning', serviceType: 'house_sitting', houseSittingVenue: 'owners_home', serviceDate: d(30), ...body });

describe('2511b — textes : 9 langues, courts, sans trou', () => {
  test('refus : 5 phrases × 9 langues, toutes différentes de l\'anglais, sans accolade ni clé brute', () => {
    expect(txt.LANGS).toEqual(LANGS);
    for (const l of LANGS) {
      for (const k of txt.KEYS) {
        const s = txt.refusalText(l, k);
        expect(typeof s).toBe('string');
        expect(s.length).toBeGreaterThan(12);
        expect(s.length).toBeLessThanOrEqual(130);
        expect(s).not.toMatch(/[{}]|undefined|_RATE|RATE_/);
        if (l !== 'en') expect(s).not.toBe(txt.refusalText('en', k));
      }
      expect(new Set(txt.KEYS.map((k) => txt.refusalText(l, k))).size).toBe(txt.KEYS.length);
    }
    expect(txt.refusalText('fr', 'visitRate')).toBe('Ajoute ton tarif par visite dans Mes tarifs pour répondre à cette demande.');
    expect(txt.refusalText('fr', 'walkRate')).toContain('tarif de balade');
  });

  test('langue : appLocale, sinon language, sinon anglais ; clé inconnue → phrase générique', () => {
    expect(txt.localeOf({ appLocale: 'pt-BR' })).toBe('pt');
    expect(txt.localeOf({ language: 'KO' })).toBe('ko');
    expect(txt.localeOf({ appLocale: 'nl' })).toBe('en');
    expect(txt.localeOf(null)).toBe('en');
    expect(txt.refusalText({ appLocale: 'it' }, 'noRate')).toContain('Le mie tariffe');
    expect(txt.refusalText('fr', 'nimportequoi')).toBe(txt.TEXTS.fr.serviceRate);
    expect(txt.rateRequiredKey({ providerRole: 'walker', unit: 'day' })).toBe('walkerNotWalk');
    expect(txt.rateRequiredKey({ providerRole: 'walker', unit: 'walk' })).toBe('serviceRate');
    expect(txt.rateRequiredKey({ providerRole: 'sitter', unit: 'day' })).toBe('serviceRate');
  });

  test('notification du gardien : titre ≤ 36 caractères et texte ≤ 100, l\'action en premier, e-mail avec les deux noms de rubrique', () => {
    const SITE = { fr: 'Garde à domicile', en: 'House sitting', es: 'Cuidado a domicilio', de: 'Betreuung zu Hause', it: 'Custodia a domicilio', pt: 'Cuidado ao domicílio', ko: '방문 펫시팅', ja: '自宅でのお世話', pl: 'Opieka w domu' };
    const APP = { fr: 'Garde — par jour ou par nuit', en: 'Boarding — per day or per night', es: 'Cuidado — por día o por noche', de: 'Betreuung — pro Tag oder pro Nacht', it: 'Custodia — al giorno o a notte', pt: 'Guarda — por dia ou por noite', ko: '돌봄 — 1일 또는 1박 기준', ja: 'お預かり — 1日または1泊ごと', pl: 'Opieka — za dzień lub za noc' };
    for (const l of LANGS) {
      const n = require(`../src/locales/${l}/notifications.json`);
      const r = n.rate_to_confirm_2511;
      expect([...r.title].length).toBeLessThanOrEqual(36);
      expect([...r.body].length).toBeLessThanOrEqual(100);
      expect(r.title.startsWith('💶 ')).toBe(true);
      expect(`${r.title}${r.body}${r.emailSubject}`).not.toMatch(/[{}]/);
      expect(r.emailBody).toContain(APP[l]);   // libellé exact de l'app (dates620_rates_sitting_title)
      expect(r.emailBody).toContain(SITE[l]);  // libellé exact du site (dates620.ts rates_sitting)
      expect((r.emailBody.match(/<li>/g) || []).length).toBe(3);
      expect(r.emailBody.replace('{{emailLink}}', '')).not.toMatch(/[{}]/);
      const o = n.application_new_stale_2511;
      expect(o.title).toBe(n.application_new_617.title); // même titre que d'habitude : « <Prénom> a répondu »
      expect(o.body).not.toMatch(/[{}]|2 min|2分|2분/);
      expect(o.emailBody).toContain('{{emailLink}}');
    }
    expect(require('../src/locales/fr/notifications.json').rate_to_confirm_2511.title).toBe('💶 Ajoute ton prix par jour');
  });
});

describe('2511b — refus du serveur dans la langue du prestataire (mêmes codes, mêmes statuts)', () => {
  test('gardien français sans aucun tarif, demande de visites : 400, phrase française', async () => {
    const r = await apply(S.noneFr, S.visite, 'sitter', { serviceType: 'home_visit', houseSittingVenue: undefined });
    expect(r.status).toBe(400);
    expect(r.body.error).toBe('Ajoute ton tarif dans Mes tarifs pour répondre à cette demande.');
  }, 60000);

  test('gardien japonais (champ language) sans aucun tarif, demande de visites : 400, phrase japonaise', async () => {
    const r = await apply(S.noneJa, S.visite, 'sitter', { serviceType: 'home_visit', houseSittingVenue: undefined });
    expect(r.status).toBe(400);
    expect(r.body.error).toBe(txt.TEXTS.ja.noRate);
  }, 60000);

  test('gardienne espagnole sans tarif par visite : 400 VISIT_RATE_REQUIRED, phrase espagnole', async () => {
    const r = await apply(S.dailyEs, S.visite, 'sitter', { serviceType: 'home_visit', houseSittingVenue: undefined });
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('VISIT_RATE_REQUIRED');
    expect(r.body.error).toBe('Añade tu precio por visita en Mis tarifas para responder a esta solicitud.');
  }, 60000);

  test('promeneur allemand sans tarif de balade : 400, phrase allemande', async () => {
    const r = await apply(S.walkerNoRate, S.mixte, 'walker', { serviceType: 'dog_walking', duration: 60, houseSittingVenue: undefined });
    expect(r.status).toBe(400);
    expect(r.body.error).toBe(txt.TEXTS.de.walkRate);
    expect(r.body.error).toContain('Meine Tarife');
  }, 60000);

  test('promeneur AVEC tarif sur « garde + balade » : toujours refusé (calcul inchangé), 400 RATE_REQUIRED, texte clair qui ne l\'envoie pas dans Mes tarifs', async () => {
    const r = await apply(S.walker, S.mixte, 'walker', { serviceType: 'dog_walking', duration: 60, houseSittingVenue: undefined });
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('RATE_REQUIRED');
    expect(r.body.error).toBe(txt.TEXTS.fr.walkerNotWalk);
    expect(r.body.error).not.toContain('Mes tarifs');
    expect(await Application.countDocuments({ walkerId: S.walker._id })).toBe(0);
  }, 60000);

  test('interrupteur coupé, gardienne avec seulement un tarif à l\'heure sur une garde : 400 RATE_REQUIRED en français', async () => {
    process.env.RATE_CONFIRM_2511 = 'off';
    const h = await Sitter.create({ password: PASS, city: 'Zone test', country: 'FR', currency: 'EUR', verified: true, location: ZONE, appLocale: 'fr', name: 'Autre Test', email: 'bob2511b+autre@example.test', hourlyRate: 25 });
    const r = await apply(h, S.garde, 'sitter');
    delete process.env.RATE_CONFIRM_2511;
    expect(r.status).toBe(400);
    expect(r.body.code).toBe('RATE_REQUIRED');
    expect(r.body.error).toBe('Ajoute ton tarif pour ce service dans Mes tarifs pour répondre à cette demande.');
  }, 60000);
});

describe('2511b — le propriétaire lit la vérité quand le tarif n\'est pas encore là', () => {
  const bell = async (appId) => {
    const all = await Notification.find({ recipientId: S.owner._id, type: 'application_new' }).lean();
    return all.find((n) => n.data && String(n.data.applicationId) === String(appId));
  };

  test('candidature en « tarif à venir » : cloche « Son tarif arrive… », jamais « choisis et paie » ; e-mail sans bouton « Choisir »', async () => {
    MAILS.length = 0; PUSHES.length = 0;
    const r = await apply(S.hourly, S.garde, 'sitter');
    expect(r.status).toBe(201);
    expect(r.body.application.pricing.stale).toBe(true); // ce que lit le site pour afficher « il manque ton prix par jour »
    await wait(900);
    const n = await bell(r.body.application.id || r.body.application._id);
    expect(n).toBeTruthy();
    expect(n.title).toBe('Solene a répondu');
    expect(n.body).toBe('Son tarif arrive : tu pourras choisir dès qu\'il sera ajouté. On te prévient.');
    expect(n.data.rateStale2511).toBe('1');
    // La cloche re-rend le texte à la lecture : même phrase, dans la langue du lecteur.
    const again = sender.renderNotificationContent('application_new', n.data, 'fr');
    expect(again.body).toBe(n.body);
    expect(sender.renderNotificationContent('application_new', n.data, 'en').body).toBe("Their rate is on its way: you can choose as soon as it's added. We'll let you know.");
    for (const l of LANGS) expect(sender.renderNotificationContent('application_new', n.data, l).body).not.toMatch(/[{}]|2 min|2分|2분/);
    const mails = MAILS.filter((x) => x.to === 'bob2511b+owner@example.test');
    expect(mails).toHaveLength(1);
    expect(mails[0].subject).toContain('Solene');
    expect(mails[0].subject).toContain('Tarif à venir');
    expect(mails[0].html).toContain('n&#39;a pas encore indiqué son tarif');
    expect(mails[0].html).not.toContain('Choisir Solene');
    expect(mails[0].html).not.toContain('Entrez votre carte bancaire');
    expect(mails[0].html).not.toMatch(/\{\{|undefined/);
  }, 60000);

  test('candidature AVEC un prix : cloche inchangée (« … candidat(s) sur ta demande · … au total · choisis et paie en 2 minutes »)', async () => {
    const r = await apply(S.daily, S.garde, 'sitter');
    expect(r.status).toBe(201);
    expect(r.body.application.pricing.stale).not.toBe(true);
    await wait(900);
    const n = await bell(r.body.application.id || r.body.application._id);
    expect(n.title).toBe('Isabelle a répondu');
    expect(n.body).toMatch(/^2 candidat\(s\) sur ta demande · Isabelle : .* au total · choisis et paie en 2 minutes$/);
    expect(n.data.rateStale2511).toBeUndefined();
    expect(sender.renderNotificationContent('application_new', n.data, 'fr').body).toBe(n.body);
  }, 60000);

  test('cartes de l\'e-mail : candidat avec prix = bouton « Choisir » ; candidat en « tarif à venir » = phrase, dans les 9 langues', () => {
    const t = require('../src/utils/applicationEmailText2610');
    const priced = { name: 'Isabelle', role: 'sitter', pricing: { totalPrice: 54, currency: 'EUR', quantity: 3, unit: 'day', indicative: false }, link: 'https://www.hopetsit.com/application/a?choose=1' };
    const stale = { name: 'Solene', role: 'sitter', pricing: { totalPrice: null, stale: true, indicative: true, unit: 'day' }, link: 'https://www.hopetsit.com/application/b?choose=1', askLink: 'https://www.hopetsit.com/application/b?ask=1' };
    for (const l of LANGS) {
      const html = t.cardsHtml(l, [priced, stale]);
      expect(html).toContain(t.esc(t.T[l].choose('Isabelle')));
      expect(html).not.toContain(t.esc(t.T[l].choose('Solene')));
      expect(html).toContain(t.esc(t.T[l].rateSoon));
      expect(html).toContain(t.esc(t.T[l].rateNote('Solene')));
      expect(html).not.toMatch(/undefined|\{\{/);
      expect((html.match(/application\/b\?choose=1/g) || []).length).toBe(0); // aucun lien de paiement pour elle
    }
    // Une seule carte, avec un prix : rien de nouveau dans l'e-mail.
    const before = t.cardsHtml('fr', [priced]);
    expect(before).not.toContain('Tarif à venir');
    expect(before).toContain('Choisir Isabelle');
    const post = { serviceTypes: ['house_sitting'], startDate: d(30), endDate: d(32), animalTypes: ['cat'], location: { city: 'Clamart' } };
    const one = t.buildEmailData({ lang: 'fr', post, cards: [stale], newCount: 1, totalPending: 1 });
    expect(one.subjectLine).toBe('Solene peut garder votre chat à Clamart · Tarif à venir');
    expect(one.candidatesHtml2610).not.toContain('Comment faire, pas à pas');
    const two = t.buildEmailData({ lang: 'fr', post, cards: [priced, stale], newCount: 1, totalPending: 2 });
    expect(two.candidatesHtml2610).toContain('Comment faire, pas à pas'); // un candidat est payable : le pas-à-pas reste
  });
});
