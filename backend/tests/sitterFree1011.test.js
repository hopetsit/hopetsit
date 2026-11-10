process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.SITTER_FREE_1011;
delete process.env.PUBLIC_API_URL;

jest.mock('../src/services/airwallexService', () => {
  const actual = jest.requireActual('../src/services/airwallexService');
  return {
    ...actual,
    findOrCreateCustomer: jest.fn(async ({ userId }) => ({ id: `cus_test_${userId}` })),
    findCustomerByMerchantId: jest.fn(async () => null),
    retrieveCustomer: jest.fn(async (id) => ({ id })),
    listAllPaymentConsents: jest.fn(async () => []),
    listPaymentMethods: jest.fn(async () => []),
    createPlatformPaymentIntent: jest.fn(async () => { throw new Error('aucun paiement dans ce test'); }),
    retrievePaymentIntent: jest.fn(async (id) => ({ id })),
    cancelPaymentIntent: jest.fn(async () => { throw new Error('aucun paiement dans ce test'); }),
  };
});
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
// Envois SIMULÉS : rien ne sort du test. On garde l'objet et le HTML réellement rendus.
const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return {
    ...actual,
    sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to: String(to || '').toLowerCase(), subject: String(subject || ''), text: String(text || ''), html: String(html || '') }); return { messageId: 'mock' }; }),
    sendTemplatedEmail: jest.fn(async () => ({})),
  };
});
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/sockets', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), emitToUsersAllRoles: jest.fn(() => 0), isUserOnline: jest.fn(async () => false), isConversationOpenFor: jest.fn(async () => false) }));
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/paymentAlert0410', () => new Proxy({}, { get: () => jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => ({
  baseCityName: (c) => String(c || ''), geocodeCity: jest.fn(async () => null), peekCity: () => undefined, warmCities: () => {}, ensureAnchorsLoaded: async () => {},
}));

// 1011 (FLO) — message automatique « un gardien est libre et vous attend → payer » :
// question « toujours libre ? » (une fois par candidature, 2 par personne et par 24 h, jamais la
// nuit, jamais un compte de test hors zone fictive, jamais sans dates), « oui » → UN message au
// propriétaire par demande (même au plafond des 3 relances), « non » → retrait par le chemin
// existant, un GET n'agit jamais, signature fausse refusée, coupe-circuit SITTER_FREE_1011.
const mongoose = require('mongoose');
const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let Pet; let Post; let Application; let Free; let Reminder; let Notification;
const PASS = 'MotDePasseTest1011!';
const PARIS = (lng = 2.35, lat = 48.85) => ({ type: 'Point', coordinates: [lng, lat] });
const ZONE = { type: 'Point', coordinates: [-30, -35] };
const PHONE = '0611223344';
const PRICING = { indicative: true, appliedRate: 18, unit: 'day', currency: 'EUR', commissionRate: 0.2 };
const T0 = new Date('2026-11-02T09:00:00.000Z'); // lundi, 10 h à Paris
const at = (h) => new Date(T0.getTime() + h * 3600000);
const day = (d) => new Date(`2026-11-${String(d).padStart(2, '0')}T00:00:00.000Z`);
const S = { mail: {}, sitter: {}, post: {}, app: {} };
const ADMIN = { 'x-test-user': new mongoose.Types.ObjectId().toString(), 'x-test-role': 'admin' };

// L'horloge des routes (new Date()) est figée ; les minuteries restent réelles (base en mémoire, HTTP).
let clockOn = false;
const clock = (h) => {
  if (!clockOn) {
    jest.useFakeTimers({
      now: at(h),
      doNotFake: ['hrtime', 'nextTick', 'performance', 'queueMicrotask', 'requestAnimationFrame', 'cancelAnimationFrame', 'requestIdleCallback', 'cancelIdleCallback',
        'setImmediate', 'clearImmediate', 'setInterval', 'clearInterval', 'setTimeout', 'clearTimeout'],
    });
    clockOn = true;
  }
  jest.setSystemTime(at(h));
};

const svc = () => require('../src/services/sitterFree1011');
const text = () => require('../src/utils/sitterFreeText1011');
const run = (h, extra = {}) => svc().runSitterFree({ now: at(h), ...extra });
const questionMails = () => MAILS.filter((m) => /toujours libre/.test(m.subject));
const ownerMails = () => MAILS.filter((m) => /est libre et vous attend/.test(m.subject));
const tokensIn = (html) => [...String(html).matchAll(/https:\/\/[^"'<> ]+\/sitter-free\/([A-Za-z0-9_.-]+)/g)].map((m) => m[1]);
const linksOf = (mail) => {
  const out = {};
  for (const t of tokensIn(mail.html)) {
    const v = svc().verifyAnswerLink(t, at(24).getTime());
    if (v.ok) out[v.answer] = t;
  }
  return out;
};
const url = (token) => `/api/v1/sitter-free/${token}`;
const reasons = (r, postId) => r.excluded.filter((x) => x.postId === String(postId)).map((x) => x.reason);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker'); Pet = require('../src/models/Pet');
  Post = require('../src/models/Post'); Application = require('../src/models/Application'); Free = require('../src/models/SitterFree1011');
  Reminder = require('../src/models/CandidatesReminder2810'); Notification = require('../src/models/Notification');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Pet.init(), Post.init(), Application.init(), Free.init(), Reminder.init()]);
  app = require('../src/app');

  const owner = async (key, name, email) => {
    S.mail[key] = email;
    const o = await Owner.create({ name, email, password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', verified: true, location: PARIS(), acceptedTerms: true, appLocale: 'fr' });
    const pet = await Pet.create({ ownerId: o._id, petName: 'Rex', petType: 'dog' });
    S[key] = { owner: o, pet };
    return S[key];
  };
  const post = async (key, who, fields = {}) => {
    const r = await Post.collection.insertOne({
      ownerId: who.owner._id, postType: 'request', status: 'open', dateMode: 'range', serviceTypes: ['house_sitting'], city: 'Paris', body: 'Garde', petIds: [who.pet._id], createdAt: at(-40), location: PARIS(), ...fields,
    });
    S.post[key] = r.insertedId;
    return r.insertedId;
  };
  const sitter = async (key, name, email, fields = {}) => {
    S.mail[key] = email;
    S.sitter[key] = await Sitter.create({ name, email, password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', dailyRate: 18, verified: true, location: PARIS(), ...fields });
    return S.sitter[key];
  };
  const apply = async (key, postKey, who, providerKey, fields = {}) => {
    const provider = S.sitter[providerKey];
    const r = await Application.collection.insertOne({
      ownerId: who.owner._id, [fields.walker ? 'walkerId' : 'sitterId']: provider._id, postId: S.post[postKey], petIds: [who.pet._id], serviceType: 'house_sitting', status: fields.status || 'pending',
      createdAt: fields.createdAt || at(-30), updatedAt: fields.createdAt || at(-30), pricing: PRICING,
    });
    S.app[key] = r.insertedId;
    return r.insertedId;
  };

  // Propriétaire 1 : une demande, cinq candidats (boost, identité vérifiée, le plus proche, un promeneur plus loin, un trop loin).
  const o1 = await owner('o1', 'Camille Durand', 'camille.libre1011@example.org');
  await post('p1', o1, { startDate: day(12), endDate: day(15) });
  await sitter('a', 'Alice Martin', 'alice.libre1011@example.org', { location: PARIS(2.40), boostExpiry: at(24 * 30), mobile: PHONE, countryCode: '+33' });
  await sitter('b', 'Bruno Petit', 'bruno.libre1011@example.org', { location: PARIS(2.44, 48.87), kycStatus: 'verified' });
  await sitter('c', 'Chloe Roux', 'chloe.libre1011@example.org', { location: PARIS(2.36) });
  S.mail.d = 'david.libre1011@example.org';
  S.sitter.d = await Walker.create({ name: 'David Morel', email: S.mail.d, password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', verified: true, location: PARIS(2.50) });
  await sitter('e', 'Emile Lyon', 'emile.libre1011@example.org', { city: 'Lyon', location: PARIS(4.83, 45.76) });
  await apply('a', 'p1', o1, 'a'); await apply('b', 'p1', o1, 'b'); await apply('c', 'p1', o1, 'c');
  await apply('d', 'p1', o1, 'd', { walker: true }); await apply('e', 'p1', o1, 'e');

  // Propriétaire 2 : trois demandes, le même gardien sur les trois (plafond par personne).
  const o2 = await owner('o2', 'Louis Bernard', 'louis.libre1011@example.org');
  await post('p2', o2, { startDate: day(13), endDate: day(14) });
  await post('p3', o2, { startDate: day(14), endDate: day(15) });
  await post('p4', o2, { startDate: day(16), endDate: day(17) });
  await sitter('cap', 'Karim Capelle', 'karim.libre1011@example.org', { location: PARIS(2.37) });
  await apply('cap2', 'p2', o2, 'cap'); await apply('cap3', 'p3', o2, 'cap'); await apply('cap4', 'p4', o2, 'cap');

  // Propriétaire de test : une demande dans une vraie ville (jamais), une en zone fictive (permise).
  const ot = await owner('ot', 'Tess Essai', 'tess+test1011@example.org');
  await post('pt1', ot, { startDate: day(17), endDate: day(18) });
  await post('pt2', ot, { startDate: day(18), endDate: day(19), location: ZONE, city: 'Zone test' });
  await sitter('tom', 'Tom Essai', 'tom+test1011@example.org', { location: ZONE, city: 'Zone test' });
  await sitter('remi', 'Remi Reel', 'remi.libre1011@example.org', { location: ZONE, city: 'Zone test' });
  await apply('tom1', 'pt1', ot, 'tom'); await apply('tom2', 'pt2', ot, 'tom'); await apply('remi2', 'pt2', ot, 'remi');

  // Propriétaire 3 : les demandes qui ne doivent rien recevoir.
  const o3 = await owner('o3', 'Nina Faure', 'nina.libre1011@example.org');
  await post('p5', o3, { startDate: day(19), endDate: day(20) }); // seul candidat : un compte de test
  await post('p6', o3, { dateMode: 'tbd' }); // sans dates
  await post('p7', o3, { startDate: new Date('2026-10-20T00:00:00.000Z'), endDate: new Date('2026-10-22T00:00:00.000Z') }); // passée
  await post('p8', o3, { startDate: day(20), endDate: day(21) }); // candidature trop récente
  await post('p9', o3, { startDate: day(21), endDate: day(22) }); // un candidat déjà choisi
  await sitter('x', 'Xavier Blanc', 'xavier.libre1011@example.org', { location: PARIS(2.38) });
  await sitter('y', 'Yann Noir', 'yann.libre1011@example.org', { location: PARIS(2.39) });
  await apply('tom5', 'p5', o3, 'tom'); await apply('x6', 'p6', o3, 'x'); await apply('x7', 'p7', o3, 'x');
  await apply('x8', 'p8', o3, 'x', { createdAt: at(-1) });
  await apply('x9', 'p9', o3, 'x', { status: 'accepted' }); await apply('y9', 'p9', o3, 'y');
}, 240000);
afterAll(async () => {
  jest.useRealTimers();
  delete process.env.SITTER_FREE_1011;
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
}, 60000);

describe('« un gardien est libre et vous attend » 1011', () => {
  test('liens signés : aller-retour, réponse non modifiable, autre fonction refusée, expiration', () => {
    const a = new mongoose.Types.ObjectId().toString(); const p = new mongoose.Types.ObjectId().toString();
    const yes = svc().signAnswerLink({ applicationId: a, providerId: p, answer: 'yes', now: 1000 });
    const no = svc().signAnswerLink({ applicationId: a, providerId: p, answer: 'no', now: 1000 });
    expect(svc().verifyAnswerLink(yes, 2000)).toEqual({ ok: true, applicationId: a, providerId: p, answer: 'yes' });
    expect(svc().verifyAnswerLink(no, 2000)).toEqual({ ok: true, applicationId: a, providerId: p, answer: 'no' });
    // la signature du « oui » collée sur le contenu du « non » : refusée
    expect(svc().verifyAnswerLink(`${no.split('.')[0]}.${yes.split('.')[1]}`, 2000)).toEqual({ ok: false, reason: 'signature' });
    expect(svc().verifyAnswerLink(yes, 1000 + svc().LINK_TTL + 1)).toEqual({ ok: false, reason: 'expired' });
    expect(svc().verifyAnswerLink('', 2000).ok).toBe(false);
    expect(svc().verifyAnswerLink('abc', 2000).ok).toBe(false);
    // un jeton d'un AUTRE lien signé du serveur (même secret) n'ouvre rien ici
    const other = require('../src/utils/applicationLink3110').signApplicationLink(a, p);
    expect(other).toBeTruthy();
    expect(svc().verifyAnswerLink(other, Date.now()).ok).toBe(false);
    expect(svc().signAnswerLink({ applicationId: 'x', providerId: p, answer: 'yes' })).toBe('');
  });

  test('état d’une demande : sans dates, passée, close, masquée, réservée → jamais', () => {
    const now = at(0); const tz = 'Europe/Paris';
    const ok = { postType: 'request', status: 'open', dateMode: 'range', startDate: day(12) };
    expect(svc().postBlocker(ok, now, tz)).toBeNull();
    expect(svc().postBlocker({ ...ok, startDate: undefined }, now, tz)).toBe('no_dates');
    expect(svc().postBlocker({ ...ok, dateMode: 'tbd' }, now, tz)).toBe('no_dates');
    expect(svc().postBlocker({ ...ok, startDate: new Date('2026-10-20T00:00:00.000Z') }, now, tz)).toBe('past');
    expect(svc().postBlocker({ ...ok, status: 'closed' }, now, tz)).toBe('closed');
    expect(svc().postBlocker({ ...ok, closedAt: at(-1) }, now, tz)).toBe('closed');
    expect(svc().postBlocker({ ...ok, hidden: true }, now, tz)).toBe('hidden');
    expect(svc().postBlocker({ ...ok, reservedBy: { bookingId: new mongoose.Types.ObjectId() } }, now, tz)).toBe('reserved');
    expect(svc().postBlocker({ ...ok, postType: 'offer' }, now, tz)).toBe('not_a_request');
  });

  test('coupe-circuit : variable absente ou « off » → rien ne part, rien n’est écrit, planificateur éteint ; la simulation dit tout', async () => {
    for (const v of [undefined, 'off', 'ON ', 'oui']) {
      if (v === undefined) delete process.env.SITTER_FREE_1011; else process.env.SITTER_FREE_1011 = v;
      if (v === 'ON ') continue; // « on » (casse et espaces tolérés) : c'est allumé, vu plus bas
      // eslint-disable-next-line no-await-in-loop
      const r = await run(0);
      expect(r.enabled).toBe(false);
      expect(r.asked).toHaveLength(0);
      expect(r.examined).toBe(0);
      expect(svc().startSitterFreeScheduler()).toBe(false);
    }
    process.env.SITTER_FREE_1011 = 'off';
    expect(MAILS).toHaveLength(0);
    expect(await Free.countDocuments({})).toBe(0);

    const sim = await run(0, { dryRun: true });
    expect(sim.dryRun).toBe(true);
    // demande 1 : boost, puis identité vérifiée, puis le plus proche ; le 4e attend ; le Lyonnais est hors distance
    expect(sim.wouldAsk.filter((l) => l.postId === String(S.post.p1)).map((l) => l.applicationId)).toEqual([String(S.app.a), String(S.app.b), String(S.app.c)]);
    expect(sim.excluded).toContainEqual({ postId: String(S.post.p1), applicationId: String(S.app.e), reason: 'too_far' });
    // plafond par personne : 2 questions, la 3e demande attend
    expect(sim.wouldAsk.map((l) => l.applicationId)).toEqual(expect.arrayContaining([String(S.app.cap2), String(S.app.cap3)]));
    expect(sim.excluded).toContainEqual({ postId: String(S.post.p4), applicationId: String(S.app.cap4), reason: 'person_cap' });
    // comptes de test : jamais dans une vraie ville ; en zone fictive, le compte de test oui, la vraie personne non
    expect(reasons(sim, S.post.pt1)).toEqual(['test']);
    expect(sim.wouldAsk.map((l) => l.applicationId)).toContain(String(S.app.tom2));
    expect(sim.excluded).toContainEqual({ postId: String(S.post.pt2), applicationId: String(S.app.remi2), reason: 'real_provider_on_test' });
    expect(reasons(sim, S.post.p5)).toEqual(['test_provider', 'nobody_to_ask']);
    // sans dates, passée, trop récente, déjà choisie
    expect(reasons(sim, S.post.p6)).toEqual(['no_dates']);
    expect(reasons(sim, S.post.p7)).toEqual(['past']);
    expect(reasons(sim, S.post.p8)).toEqual(['too_recent']);
    expect(reasons(sim, S.post.p9)).toEqual(['already_chosen']);
    expect(sim.wouldAsk).toHaveLength(6);
    const line = sim.wouldAsk.find((l) => l.applicationId === String(S.app.a));
    expect(line).toEqual(expect.objectContaining({ providerRole: 'sitter', providerFirstName: 'Alice', ownerFirstName: 'Camille' }));
    expect(line.price).toBe(require('../src/utils/applicationEmailText2610').priceLabel('fr', PRICING));
    expect(line.price).not.toBe('');
    // la simulation n'écrit rien et n'envoie rien
    expect(MAILS).toHaveLength(0);
    expect(await Free.countDocuments({})).toBe(0);
    await Application.deleteOne({ _id: S.app.x8 }); // ne sert qu'à ce cas
  });

  test('route admin de simulation : réservée à l’admin, ne change rien, ni e-mail ni téléphone dans la réponse', async () => {
    clock(0);
    const path = '/api/v1/admin/sitter-free-1011?dryRun=1';
    expect((await request(app).get(path)).status).toBe(401);
    expect((await request(app).get(path).set({ 'x-test-user': String(S.o1.owner._id), 'x-test-role': 'owner' })).status).toBe(403);
    expect((await request(app).get(path).set({ 'x-test-user': String(S.sitter.a._id), 'x-test-role': 'sitter' })).status).toBe(403);
    const r = await request(app).get(path).set(ADMIN);
    expect(r.status).toBe(200);
    expect(r.body.enabled).toBe(false);
    expect(r.body.dryRun).toBe(true);
    expect(r.body.wouldAsk).toHaveLength(6);
    expect(r.body.asked).toHaveLength(0);
    expect(r.body.settings).toEqual({ askAfterHours: 24, maxAskedPerRequest: 3, maxPerPersonPerDay: 2, maxRequestsPerRun: 10 });
    expect(r.body.excluded.length).toBeGreaterThan(5);
    const raw = JSON.stringify(r.body);
    expect(raw).not.toContain('@');
    expect(raw).not.toContain('example.org');
    expect(raw).not.toContain(PHONE);
    expect(raw).not.toMatch(/Martin|Durand|Capelle/); // prénoms seulement
    expect(MAILS).toHaveLength(0);
    expect(await Free.countDocuments({})).toBe(0);
  });

  test('allumé, la nuit (22 h à Paris) : aucune question', async () => {
    process.env.SITTER_FREE_1011 = 'ON ';
    expect(svc().enabled()).toBe(true);
    process.env.SITTER_FREE_1011 = 'on';
    const r = await run(12);
    expect(r.enabled).toBe(true);
    expect(r.asked).toHaveLength(0);
    expect(r.skipped.night).toBeGreaterThanOrEqual(5);
    expect(MAILS).toHaveLength(0);
    expect(await Free.countDocuments({})).toBe(0);
  });

  test('allumé, le jour : la question part (e-mail réellement rendu, deux liens signés), 3 candidats au plus, 2 questions par personne', async () => {
    const r = await run(24);
    expect(r.asked.filter((l) => l.postId === String(S.post.p1)).map((l) => l.applicationId)).toEqual([String(S.app.a), String(S.app.b), String(S.app.c)]);
    expect(r.asked.map((l) => l.applicationId).sort()).toEqual([S.app.a, S.app.b, S.app.c, S.app.cap2, S.app.cap3, S.app.tom2].map(String).sort());
    expect(r.excluded).toContainEqual({ postId: String(S.post.p4), applicationId: String(S.app.cap4), reason: 'person_cap' });
    expect(r.excluded).toContainEqual({ postId: String(S.post.p1), applicationId: String(S.app.e), reason: 'too_far' });
    expect(r.ownerTold).toHaveLength(0);

    expect(questionMails()).toHaveLength(6);
    expect(MAILS).toHaveLength(6);
    expect(MAILS.filter((m) => m.to === S.mail.cap)).toHaveLength(2);
    for (const k of ['d', 'e', 'remi', 'x', 'y', 'o1', 'o2', 'o3', 'ot']) expect(MAILS.filter((m) => m.to === S.mail[k])).toHaveLength(0);
    const mail = MAILS.find((m) => m.to === S.mail.a);
    const p1 = await Post.findById(S.post.p1).lean();
    expect(mail.subject).toBe(text().questionLine({ lang: 'fr', post: p1, serviceType: 'house_sitting', petNames: ['Rex'] }));
    expect(mail.subject).toMatch(/^Êtes-vous toujours libre pour garder Rex du .+ au .+ à Paris \?$/);
    expect(mail.html).toContain('Oui, je suis libre');
    expect(mail.html).toContain('Non, plus disponible');
    const links = linksOf(mail);
    expect(svc().verifyAnswerLink(links.yes, at(24).getTime())).toEqual({ ok: true, applicationId: String(S.app.a), providerId: String(S.sitter.a._id), answer: 'yes' });
    expect(svc().verifyAnswerLink(links.no, at(24).getTime())).toEqual({ ok: true, applicationId: String(S.app.a), providerId: String(S.sitter.a._id), answer: 'no' });
    expect(mail.html).not.toContain(PHONE);

    const rows = await Free.find({}).lean();
    expect(rows).toHaveLength(6);
    expect(rows.every((x) => x.kind === 'question' && x.status === 'sent' && x.answer === '' && x.attempts === 1)).toBe(true);
    // la cloche de l'app est posée, sans second e-mail
    expect(await Notification.countDocuments({ type: 'still_free_1011', recipientId: S.sitter.a._id })).toBe(1);
  });

  test('une seule fois par candidature : le passage suivant ne renvoie rien', async () => {
    const r = await run(25);
    expect(r.asked).toHaveLength(0);
    expect(reasons(r, S.post.p1)).toEqual(['waiting_answers']);
    expect(r.excluded).toContainEqual({ postId: String(S.post.p4), applicationId: String(S.app.cap4), reason: 'person_cap' });
    expect(MAILS).toHaveLength(6);
    expect(await Free.countDocuments({})).toBe(6);
  });

  test('un simple GET (robot de messagerie) affiche une page avec un bouton et ne change RIEN', async () => {
    clock(25);
    const la = linksOf(MAILS.find((m) => m.to === S.mail.a));
    const lc = linksOf(MAILS.find((m) => m.to === S.mail.c));
    for (let i = 0; i < 2; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      const yes = await request(app).get(url(la.yes));
      expect(yes.status).toBe(200);
      expect(yes.headers['content-type']).toMatch(/text\/html/);
      expect(yes.headers['cache-control']).toBe('no-store');
      expect(yes.text).toContain(`<form method="POST" action="/api/v1/sitter-free/${la.yes}"`);
      expect(yes.text).toContain('Oui, je suis libre');
      expect(yes.text).not.toContain('@');
      expect(String(yes.headers['content-security-policy'] || '')).not.toMatch(/form-action 'none'/);
    }
    const no = await request(app).get(url(lc.no));
    expect(no.status).toBe(200);
    expect(no.text).toContain('<form method="POST"');
    expect(no.text).toContain('Confirmer : plus disponible');

    expect((await Free.findOne({ key: `q:${S.app.a}` }).lean()).answer).toBe('');
    expect((await Free.findOne({ key: `q:${S.app.c}` }).lean()).answer).toBe('');
    expect((await Application.findById(S.app.c).lean()).status).toBe('pending');
    expect(await Free.countDocuments({ kind: 'owner' })).toBe(0);
    expect(ownerMails()).toHaveLength(0);
    expect(MAILS).toHaveLength(6);
  });

  test('signature fausse, jeton d’un autre candidat, jeton expiré : refusés en GET comme en POST, rien ne change', async () => {
    clock(25);
    const la = linksOf(MAILS.find((m) => m.to === S.mail.a));
    const bad = `${la.yes.slice(0, -2)}${la.yes.endsWith('AA') ? 'BB' : 'AA'}`;
    expect((await request(app).get(url(bad))).status).toBe(400);
    const p = await request(app).post(url(bad));
    expect(p.status).toBe(400);
    expect(p.text).toContain('Ce lien n’est pas valable.');
    // contenu du « non » + signature du « oui »
    expect((await request(app).post(url(`${la.no.split('.')[0]}.${la.yes.split('.')[1]}`))).status).toBe(400);
    // bien signé, mais pour un autre prestataire que l'auteur de la candidature
    const wrong = svc().signAnswerLink({ applicationId: String(S.app.a), providerId: String(S.sitter.b._id), answer: 'no', now: at(25).getTime() });
    expect((await request(app).get(url(wrong))).status).toBe(400);
    expect((await request(app).post(url(wrong))).status).toBe(400);
    // expiré (signé il y a 15 jours, valable 14)
    const old = svc().signAnswerLink({ applicationId: String(S.app.a), providerId: String(S.sitter.a._id), answer: 'no', now: at(25).getTime() - 15 * 24 * 3600000 });
    expect((await request(app).get(url(old))).status).toBe(410);
    const e = await request(app).post(url(old));
    expect(e.status).toBe(410);
    expect(e.text).toContain('Ce lien a expiré.');

    expect((await Application.findById(S.app.a).lean()).status).toBe('pending');
    expect((await Free.findOne({ key: `q:${S.app.a}` }).lean()).answer).toBe('');
    expect(await Free.countDocuments({ kind: 'owner' })).toBe(0);
    expect(MAILS).toHaveLength(6);
  });

  test('« non » : la candidature est retirée par le chemin existant ; la place libérée va au candidat suivant (promeneur), push sans e-mail', async () => {
    clock(25);
    const lc = linksOf(MAILS.find((m) => m.to === S.mail.c));
    const r = await request(app).post(url(lc.no));
    expect(r.status).toBe(200);
    expect(r.text).toContain('votre candidature a été retirée');
    expect(await Application.findById(S.app.c).lean()).toBeNull();
    const row = await Free.findOne({ key: `q:${S.app.c}` }).lean();
    expect(row.answer).toBe('no');
    expect(row.answeredAt).toEqual(at(25));
    // double clic : même page, sans erreur
    expect((await request(app).post(url(lc.no))).status).toBe(200);
    // le « oui » de la même candidature n'ouvre plus rien
    expect((await request(app).post(url(lc.yes))).status).toBe(410);
    expect(ownerMails()).toHaveLength(0);

    const push = jest.fn(async () => ({}));
    const next = await run(26, { push });
    expect(next.asked).toEqual([expect.objectContaining({ postId: String(S.post.p1), applicationId: String(S.app.d), providerRole: 'walker', providerFirstName: 'David' })]);
    expect(MAILS.filter((m) => m.to === S.mail.d)).toHaveLength(1);
    expect(push).toHaveBeenCalledTimes(1);
    expect(push.mock.calls[0][0]).toEqual(expect.objectContaining({ userId: String(S.sitter.d._id), role: 'walker', type: 'still_free_1011', channels: { email: false } }));
    expect(questionMails()).toHaveLength(7);
  });

  test('« oui » : UN message « est libre et vous attend → Payer et réserver » au propriétaire, même au plafond des 3 relances ; un 2e « oui » n’en renvoie pas', async () => {
    clock(27); // 13 h à Paris
    await Reminder.collection.insertMany(['e1', 'e2', 'e3'].map((slot, i) => ({ postId: S.post.p1, slot, ownerId: S.o1.owner._id, candidates: 3, status: 'sent', error: '', createdAt: at(-20 + i) })));
    const la = linksOf(MAILS.find((m) => m.to === S.mail.a));
    const lb = linksOf(MAILS.find((m) => m.to === S.mail.b));

    const first = await request(app).post(url(la.yes));
    expect(first.status).toBe(200);
    expect(first.text).toContain('vous êtes libre pour cette demande');
    expect(first.text).toContain('Nous prévenons le propriétaire.');
    expect(ownerMails()).toHaveLength(1);
    const mail = ownerMails()[0];
    expect(mail.to).toBe(S.mail.o1);
    const price = require('../src/utils/applicationEmailText2610').priceLabel('fr', PRICING);
    expect(price).not.toBe('');
    expect(mail.subject).toBe(`Alice est libre et vous attend · ${price}`);
    expect(mail.html).toContain('Payer et réserver');
    expect(mail.html).toContain('Alice');
    expect(mail.html).toContain(price);
    const pay = mail.html.match(new RegExp(`href="([^"]*/application/${S.app.a}\\?[^"]*)"[^>]*>Payer et réserver`));
    expect(pay).not.toBeNull();
    const href = pay[1].replace(/&amp;/g, '&');
    expect(href).toContain('from=email');
    expect(href).toContain('choose=1');
    expect(href).toMatch(/[?&]k=[A-Za-z0-9_.-]{20,}/); // lien signé : pas de mot de passe
    expect(mail.html).not.toContain(PHONE);
    expect(mail.html).not.toContain(S.mail.a);

    // 2e « oui » (un autre candidat) : noté, mais aucun nouveau message et aucune promesse fausse
    const second = await request(app).post(url(lb.yes));
    expect(second.status).toBe(200);
    expect(second.text).toContain('vous êtes libre pour cette demande');
    expect(second.text).not.toContain('Nous prévenons le propriétaire.');
    // double clic du 1er : rien de plus
    const again = await request(app).post(url(la.yes));
    expect(again.status).toBe(200);
    expect(again.text).toContain('Nous prévenons le propriétaire.');
    expect(ownerMails()).toHaveLength(1);

    expect(await Free.countDocuments({ kind: 'owner' })).toBe(1);
    const told = await Free.findOne({ key: `o:${S.post.p1}` }).lean();
    expect(told).toEqual(expect.objectContaining({ status: 'sent', attempts: 1 }));
    expect(String(told.applicationId)).toBe(String(S.app.a));
    expect((await Free.findOne({ key: `q:${S.app.a}` }).lean()).answer).toBe('yes');
    expect((await Free.findOne({ key: `q:${S.app.b}` }).lean()).answer).toBe('yes');
    // les candidatures restent en attente : c'est le propriétaire qui choisit et paie
    expect((await Application.findById(S.app.a).lean()).status).toBe('pending');
    expect((await Application.findById(S.app.b).lean()).status).toBe('pending');
    // le registre des 3 relances n'est ni lu ni touché
    expect(await Reminder.countDocuments({ postId: S.post.p1 })).toBe(3);
    expect(await Notification.countDocuments({ recipientId: S.o1.owner._id, type: 'application_new' })).toBe(1);

    const next = await run(28);
    expect(next.asked).toHaveLength(0);
    expect(next.ownerTold).toHaveLength(0);
    expect(reasons(next, S.post.p1)).toEqual(['owner_already_told']);
    expect(ownerMails()).toHaveLength(1);
  });

  test('« oui » reçu la nuit du propriétaire : message reporté au matin, puis envoyé une fois ; le plafond par personne se libère après 24 h', async () => {
    const yes = await svc().answerYes({ applicationId: String(S.app.cap2), providerId: String(S.sitter.cap._id), now: at(36) }); // 22 h à Paris
    expect(yes).toEqual(expect.objectContaining({ ok: true, answer: 'yes', first: true, ownerTold: true, owner: 'night' }));
    expect(ownerMails()).toHaveLength(1);
    expect(await Free.countDocuments({ key: `o:${S.post.p2}` })).toBe(0);
    const night = await run(37);
    expect(night.ownerTold).toHaveLength(0);
    expect(night.asked).toHaveLength(0);
    expect(ownerMails()).toHaveLength(1);

    const r = await run(49); // 10 h à Paris le lendemain
    expect(r.ownerTold).toEqual([expect.objectContaining({ postId: String(S.post.p2), applicationId: String(S.app.cap2), providerFirstName: 'Karim', ownerFirstName: 'Louis' })]);
    expect(ownerMails()).toHaveLength(2);
    expect(ownerMails()[1].to).toBe(S.mail.o2);
    expect(ownerMails()[1].subject).toMatch(/^Karim est libre et vous attend/);
    // les 2 questions de la veille ont plus de 24 h : la 3e demande est enfin servie
    expect(r.asked).toEqual([expect.objectContaining({ postId: String(S.post.p4), applicationId: String(S.app.cap4) })]);
    expect(MAILS.filter((m) => m.to === S.mail.cap)).toHaveLength(3);

    const again = await run(50);
    expect(again.ownerTold).toHaveLength(0);
    expect(again.asked).toHaveLength(0);
    expect(ownerMails()).toHaveLength(2);
    expect(await Free.countDocuments({ kind: 'owner' })).toBe(2);
  });

  test('coupe-circuit sur un « oui » : noté, aucun message, aucune promesse ; un « oui » de plus de 24 h ne part plus', async () => {
    process.env.SITTER_FREE_1011 = 'off';
    clock(50);
    const lt = linksOf(MAILS.find((m) => m.to === S.mail.tom));
    const page = await request(app).post(url(lt.yes));
    expect(page.status).toBe(200);
    expect(page.text).toContain('vous êtes libre pour cette demande');
    expect(page.text).not.toContain('Nous prévenons le propriétaire.');
    expect((await Free.findOne({ key: `q:${S.app.tom2}` }).lean()).answer).toBe('yes');
    expect(ownerMails()).toHaveLength(2);
    expect(await Free.countDocuments({ key: `o:${S.post.pt2}` })).toBe(0);
    // un « non » reste honoré même éteint : la personne retire sa candidature
    const ld = linksOf(MAILS.find((m) => m.to === S.mail.d));
    expect((await request(app).post(url(ld.no))).status).toBe(200);
    expect(await Application.findById(S.app.d).lean()).toBeNull();

    process.env.SITTER_FREE_1011 = 'on';
    const r = await run(76); // 26 h après ce « oui »
    expect(r.ownerTold).toHaveLength(0);
    expect(reasons(r, S.post.pt2)).toContain('has_yes');
    expect(ownerMails()).toHaveLength(2);
    expect(MAILS.filter((m) => m.to === S.mail.ot)).toHaveLength(0);
  });

  test('lot limité : 10 demandes servies par passage, le reste au passage suivant', async () => {
    const who = { owner: await Owner.create({ name: 'Paul Girard', email: 'paul.libre1011@example.org', password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', verified: true, location: PARIS(), acceptedTerms: true, appLocale: 'fr' }), pet: S.o1.pet };
    const lot = [];
    for (let i = 0; i < 6; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      const s = await Sitter.create({ name: `Lot${i} Test`, email: `lot${i}.libre1011@example.org`, password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', dailyRate: 18, verified: true, location: PARIS(2.36) });
      for (let j = 0; j < 2; j += 1) {
        // eslint-disable-next-line no-await-in-loop
        const p = await Post.collection.insertOne({ ownerId: who.owner._id, postType: 'request', status: 'open', dateMode: 'range', serviceTypes: ['house_sitting'], city: 'Paris', body: 'Garde', petIds: [who.pet._id], createdAt: at(30), location: PARIS(), startDate: day(22 + j), endDate: day(24 + j) });
        lot.push(String(p.insertedId));
        // eslint-disable-next-line no-await-in-loop
        await Application.collection.insertOne({ ownerId: who.owner._id, sitterId: s._id, postId: p.insertedId, petIds: [who.pet._id], serviceType: 'house_sitting', status: 'pending', createdAt: at(40), updatedAt: at(40), pricing: PRICING });
      }
    }
    const before = await Free.countDocuments({});
    const sim = await run(76, { dryRun: true });
    const served = new Set(sim.wouldAsk.map((l) => l.postId));
    expect(served.size).toBe(10);
    expect([...served].every((id) => lot.includes(id))).toBe(true);
    expect(sim.batchFull).toBe(true);
    expect(await Free.countDocuments({})).toBe(before);

    const real = await run(76);
    expect(real.asked).toHaveLength(10);
    expect(real.batchFull).toBe(true);
    const rest = await run(77);
    expect(rest.asked).toHaveLength(2);
    expect(rest.batchFull).toBeUndefined();
    expect(new Set([...real.asked, ...rest.asked].map((l) => l.postId)).size).toBe(12);
  });

  // 10/11/2026 (BOB, « Oui, autorise » de Daniel) — la question part aussi vers un gardien dont
  // l'e-mail n'a jamais été validé, et une ligne arrêtée à 3 essais par ce garde-fou repart UNE fois.
  test('10/11 — gardien à l\'e-mail non validé : bloqué coupe-circuit fermé, puis la question part et la ligne repart une seule fois', async () => {
    const dom = S.mail.a.split('@')[1];
    const mk = (n) => `${n}@${dom}`;
    const o = await Owner.create({ name: 'Ines Morin', email: mk('ines1011'), password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', verified: true, location: PARIS(), acceptedTerms: true, appLocale: 'fr' });
    const nv = await Sitter.create({ name: 'Nora Vidal', email: mk('nora1011'), password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', dailyRate: 18, verified: false, location: PARIS(2.36) });
    const ok = await Sitter.create({ name: 'Omar Klein', email: mk('omar1011'), password: PASS, city: 'Paris', country: 'FR', currency: 'EUR', dailyRate: 18, verified: true, location: PARIS(2.37) });
    const mkPost = async (d) => (await Post.collection.insertOne({ ownerId: o._id, postType: 'request', status: 'open', dateMode: 'range', serviceTypes: ['house_sitting'], city: 'Paris', body: 'Garde', petIds: [S.o1.pet._id], createdAt: at(60), location: PARIS(), startDate: day(d), endDate: day(d + 1) })).insertedId;
    const mkApp = async (postId, sitterId) => (await Application.collection.insertOne({ ownerId: o._id, sitterId, postId, petIds: [S.o1.pet._id], serviceType: 'house_sitting', status: 'pending', createdAt: at(70), updatedAt: at(70), pricing: PRICING })).insertedId;
    const pNv = await mkPost(25); const aNv = await mkApp(pNv, nv._id);
    const pOk = await mkPost(27); const aOk = await mkApp(pOk, ok._id);
    const mailsTo = (n) => questionMails().filter((m) => m.to === mk(n)).length;

    // 1) Coupe-circuit fermé = l'ancien comportement : la question au non-validé ne part pas.
    process.env.SITTER_FREE_EMAIL_UNVERIFIED = 'off';
    try {
      const r1 = await run(98);
      expect(reasons(r1, pNv)).toContain('not_sent:email_blocked:unverified');
      expect(mailsTo('nora1011')).toBe(0);
      expect(mailsTo('omar1011')).toBe(1); // le gardien validé, lui, reçoit sa question
      let row = await Free.findOne({ key: `q:${aNv}` }).lean();
      expect(row).toMatchObject({ status: 'failed', error: 'email_blocked:unverified', attempts: 1 });
      // Trois essais atteints : la ligne est arrêtée.
      await Free.updateOne({ key: `q:${aNv}` }, { $set: { attempts: 3 } });
      const r2 = await run(99);
      expect(reasons(r2, pNv)).toContain('failed_max');
      expect(mailsTo('nora1011')).toBe(0);
      row = await Free.findOne({ key: `q:${aNv}` }).lean();
      expect(row.unblockedAt == null).toBe(true);
    } finally { delete process.env.SITTER_FREE_EMAIL_UNVERIFIED; }

    // 2) Une ligne arrêtée pour une AUTRE raison ne repart jamais.
    await Free.updateOne({ key: `q:${aOk}` }, { $set: { status: 'failed', error: 'smtp_down', attempts: 3 } });

    // 3) Exception active (par défaut) : la ligne « e-mail non validé » repart, la question est envoyée.
    const sim = await run(100, { dryRun: true });
    expect(sim.wouldAsk.map((l) => l.applicationId)).toContain(String(aNv));
    expect(sim.wouldAsk.map((l) => l.applicationId)).not.toContain(String(aOk));
    const r3 = await run(100);
    expect(r3.asked.map((l) => l.applicationId)).toContain(String(aNv));
    expect(reasons(r3, pOk)).toContain('failed_max');
    expect(mailsTo('nora1011')).toBe(1);
    expect(mailsTo('omar1011')).toBe(1);
    let row = await Free.findOne({ key: `q:${aNv}` }).lean();
    expect(row).toMatchObject({ status: 'sent', error: '', attempts: 1 });
    expect(row.unblockedAt).toBeInstanceOf(Date);

    // 4) Un seul déblocage par ligne : arrêtée de nouveau, elle ne repart plus.
    await Free.updateOne({ key: `q:${aNv}` }, { $set: { status: 'failed', error: 'email_blocked:unverified', attempts: 3 } });
    const r4 = await run(101);
    expect(reasons(r4, pNv)).toContain('failed_max');
    expect(mailsTo('nora1011')).toBe(1);
    row = await Free.findOne({ key: `q:${aNv}` }).lean();
    expect(row.status).toBe('failed');
  });

  test('planificateur : démarre seulement si SITTER_FREE_1011=on', () => {
    process.env.SITTER_FREE_1011 = 'off';
    expect(svc().startSitterFreeScheduler({ firstDelayMs: 3600000, intervalMs: 3600000 })).toBe(false);
    process.env.SITTER_FREE_1011 = 'on';
    expect(svc().startSitterFreeScheduler({ firstDelayMs: 3600000, intervalMs: 3600000 })).toBe(true);
    expect(svc().startSitterFreeScheduler({ firstDelayMs: 3600000, intervalMs: 3600000 })).toBe(false); // déjà lancé
    svc().stopSitterFreeScheduler();
  });
});
