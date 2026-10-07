// 612 (ZOE, 05/10/2026) — ALERTE DES ANNONCES À 100 KM (ordre de Daniel) :
// « quand quelqu'un poste une annonce, que tous les gens à un rayon de 100 km du
// post reçoivent l'annonce par mail, notification tel, etc. »
// VRAIE base Mongo en mémoire, vrai ciblage, vrai sendNotification (cloche, gabarits
// 9 langues, préférences) ; Firebase et le SMTP sont CAPTÉS : rien ne sort.
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
  return {
    ...actual,
    sendEmail: jest.fn(async (to, subject, text, html, opts) => {
      mockMails.push({ to, subject, text, html, opts });
      return { messageId: 'capté' };
    }),
  };
});
jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
// Géocodage simulé : Versailles ≈ 17 km de Paris, Lyon ≈ 390 km, le reste introuvable.
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  const KNOWN = { versailles: { lat: 48.8049, lng: 2.1204 }, lyon: { lat: 45.764, lng: 4.8357 } };
  return { ...actual, geocodeCity: jest.fn(async (c) => KNOWN[String(c || '').trim().toLowerCase()] || null) };
});

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const PARIS = { lat: 48.8566, lng: 2.3522 };
const KM_PER_DEG_LAT = (Math.PI * 6371) / 180;
const north = (km) => ({ type: 'Point', coordinates: [PARIS.lng, PARIS.lat + km / KM_PER_DEG_LAT] });

let mongo; let Owner; let Sitter; let Walker; let Post; let Block; let Notification; let RequestAlert;
let postController; let alert612;
let owner; const W = {}; const S = {};
const oid = () => new mongoose.Types.ObjectId();
const ins = async (Model, doc) => {
  const r = await Model.collection.insertOne({ status: 'active', ...doc });
  return String(r.insertedId);
};
const mkPost = async (extra = {}) => {
  const r = await Post.collection.insertOne({
    ownerId: new mongoose.Types.ObjectId(owner), body: 'Balade pour Rex', postType: 'request',
    serviceTypes: ['dog_walking'], location: { city: 'Paris', ...PARIS },
    startDate: new Date('2026-10-12T09:30:00.000Z'), endDate: new Date('2026-10-14T18:00:00.000Z'),
    createdAt: new Date(), ...extra,
  });
  return Post.findById(r.insertedId).lean();
};
const alertFor = async (post, opts = {}, ownerDoc = null) => {
  const o = ownerDoc || await Owner.findById(post.ownerId).select('name email oldId').lean();
  return new Promise((resolve) => {
    postController.notifyNearbyProviders({
      newPost: post,
      postPayload: { location: post.location, targetProvider: post.targetProvider || null },
      normalizedServices: post.serviceTypes || [],
      owner: o,
      ownerId: String(post.ownerId),
      opts: { ...opts, onDone: resolve },
    });
  });
};
const bellOf = (postId) => Notification.find({ 'data.postId': String(postId), type: 'new_request_nearby' }).lean();
const reset = async () => {
  mockPushes.length = 0; mockMails.length = 0;
  await RequestAlert.deleteMany({});
  await Notification.deleteMany({});
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Post = require('../src/models/Post'); Block = require('../src/models/Block'); Notification = require('../src/models/Notification');
  RequestAlert = require('../src/models/RequestAlert612');
  await RequestAlert.init();
  postController = require('../src/controllers/postController');
  alert612 = require('../src/services/requestAlert612');

  owner = await ins(Owner, { name: 'Camille Durand', email: 'camille612@example.test', appLocale: 'fr' });
  // L'auteur a AUSSI un profil promeneur, tout près : jamais prévenu de sa propre annonce.
  W.self = await ins(Walker, { name: 'Camille Durand', email: 'camille612@example.test', location: north(0.5) });

  W.near = await ins(Walker, { name: 'Near', email: 'near612@example.test', appLocale: 'en', location: north(1), fcmTokens: ['jeton-near'] });
  W.km99 = await ins(Walker, { name: 'K99', email: 'k99@example.test', appLocale: 'fr', location: north(99) });
  W.km101 = await ins(Walker, { name: 'K101', email: 'k101@example.test', appLocale: 'fr', location: north(101) });
  S.near = await ins(Sitter, { name: 'SitNear', email: 'sitnear612@example.test', appLocale: 'fr', location: north(1) });
  // Une personne, deux profils (gardien + promeneur).
  S.both = await ins(Sitter, { name: 'Both', email: 'both612@example.test', appLocale: 'fr', location: north(3) });
  W.both = await ins(Walker, { name: 'Both', email: 'both612@example.test', appLocale: 'fr', location: north(3) });
  // Écartés.
  W.test = await ins(Walker, { name: 'Test', email: 'dada+testwalker612@example.test', location: north(2) });
  W.staff = await ins(Walker, { name: 'Staff', email: 'staff612@example.test', isStaff: true, location: north(2) });
  W.suspended = await ins(Walker, { name: 'Susp', email: 'susp612@example.test', status: 'suspended', location: north(2) });
  W.banned = await ins(Walker, { name: 'Ban', email: 'ban612@example.test', status: 'banned', location: north(2) });
  W.blocked = await ins(Walker, { name: 'Blocked', email: 'blocked612@example.test', location: north(2) });
  await Block.collection.insertOne({ blockerId: new mongoose.Types.ObjectId(owner), blockerModel: 'Owner', blockedId: new mongoose.Types.ObjectId(W.blocked), blockedModel: 'Walker' });
  W.blocker = await ins(Walker, { name: 'Blocker', email: 'blocker612@example.test', location: north(2) });
  await Block.collection.insertOne({ blockerId: new mongoose.Types.ObjectId(W.blocker), blockerModel: 'Walker', blockedId: new mongoose.Types.ObjectId(owner), blockedModel: 'Owner' });
  // Désabonné : le lien d'un e-mail a posé marketingOptOut sur son profil PROPRIÉTAIRE.
  W.unsub = await ins(Walker, { name: 'Unsub', email: 'unsub612@example.test', appLocale: 'fr', location: north(4), fcmTokens: ['jeton-unsub'] });
  await ins(Owner, { name: 'Unsub', email: 'unsub612@example.test', marketingOptOut: true });
  // Catégorie « Réservations » coupée dans l'app.
  W.prefsOff = await ins(Walker, {
    name: 'PrefsOff', email: 'prefsoff612@example.test', appLocale: 'fr', location: north(4), fcmTokens: ['jeton-prefs'],
    notificationPrefs: { sound: 'frog', categories: { bookings: false } },
  });
  // Sans coordonnées.
  W.versailles = await ins(Walker, { name: 'Vers', email: 'vers612@example.test', appLocale: 'fr', city: 'Versailles' });
  W.lyon = await ins(Walker, { name: 'Lyon', email: 'lyon612@example.test', appLocale: 'fr', city: 'Lyon' });
  W.parisName = await ins(Walker, { name: 'ParisNom', email: 'parisnom612@example.test', appLocale: 'fr', city: 'Paris 15e' });
  W.nowhere = await ins(Walker, { name: 'Nulle part', email: 'nowhere612@example.test', appLocale: 'fr' });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(reset);

describe('qui est prévenu', () => {
  let bilan; let post;
  beforeEach(async () => { post = await mkPost(); bilan = await alertFor(post); });

  test('rayon : 99 km inclus, 101 km exclu (distance réelle)', () => {
    expect(bilan.radiusKm).toBe(100);
    expect(bilan.sent).toContain(W.km99);
    expect(bilan.sent).not.toContain(W.km101);
    expect(bilan.excluded.tooFar).toBeGreaterThanOrEqual(1);
  });
  test('rôle : une balade prévient les promeneurs, pas les gardiens', () => {
    expect(bilan.roles).toEqual(['walker']);
    expect(bilan.sent).toContain(W.near);
    expect(bilan.sent).not.toContain(S.near);
    expect(bilan.sent).not.toContain(S.both);
  });
  test('une personne aux deux profils est prévenue, une seule fois', () => {
    expect(bilan.sent.filter((id) => id === W.both || id === S.both)).toEqual([W.both]);
  });
  test('jamais l’auteur, ni test, ni staff, ni suspendu / banni, ni bloqué (dans les deux sens)', () => {
    for (const k of ['self', 'test', 'staff', 'suspended', 'banned', 'blocked', 'blocker']) {
      expect(bilan.sent).not.toContain(W[k]);
    }
    expect(bilan.excluded).toMatchObject({ self: 1, test: 1, staff: 1, inactive: 2, blocked: 2 });
  });
  test('repli sans coordonnées : centre de SA ville (Versailles oui, Lyon non), sinon même nom de ville, sinon personne', async () => {
    expect(bilan.sent).toContain(W.versailles);
    expect(bilan.sent).not.toContain(W.lyon);
    expect(bilan.sent).toContain(W.parisName); // « Paris 15e », ville introuvable au géocodage → même ville que l'annonce
    expect(bilan.sent).not.toContain(W.nowhere);
    const rows = await RequestAlert.find({ postId: post._id }).lean();
    const via = (id) => rows.find((r) => String(r.recipientId) === id).via;
    expect(via(W.versailles)).toBe('city_center');
    expect(via(W.parisName)).toBe('city_name');
    expect(via(W.near)).toBe('coords');
    expect(rows.find((r) => String(r.recipientId) === W.km99).km).toBeCloseTo(99, 0);
  });
  test('liste exacte des prévenus', () => {
    expect([...bilan.sent].sort()).toEqual([W.near, W.km99, W.both, W.unsub, W.prefsOff, W.versailles, W.parisName].sort());
  });
});

describe('les 3 canaux', () => {
  let post; let bilan;
  beforeEach(async () => { post = await mkPost(); bilan = await alertFor(post); });

  test('cloche : une entrée par personne prévenue', async () => {
    const bell = await bellOf(post._id);
    expect(bell.map((n) => String(n.recipientId)).sort()).toEqual([...bilan.sent].sort());
    expect(bell.every((n) => n.recipientRole === 'walker' && !n.readAt)).toBe(true);
  });
  test('notification du téléphone : part vers les jetons, avec la route de l’annonce', () => {
    const p = mockPushes.find((m) => m.tokens.includes('jeton-near'));
    expect(p).toBeTruthy();
    expect(p.data.type).toBe('new_request_nearby');
    expect(p.data.postId).toBe(String(post._id));
    expect(p.data.route).toBe(`/post/${post._id}`);
    expect(p.notification.title).toBe('New listing near you');
    expect(p.notification.body).toBe('Camille Durand is looking for a dog walker · Paris · October 12 – October 14. Open the app to apply.');
  });
  test('e-mail : langue du destinataire, ville, service, dates, bouton vers l’annonce, lien de désabonnement', () => {
    const m = mockMails.find((x) => x.to === 'near612@example.test');
    expect(m).toBeTruthy();
    expect(m.subject).toBe('New listing: Dog walking · Paris');
    expect(m.html).toContain('<strong>City:</strong> Paris');
    expect(m.html).toContain('<strong>Service:</strong> Dog walking');
    expect(m.html).toContain('<strong>Dates:</strong> October 12 – October 14');
    expect(m.html).toContain(`href="https://www.hopetsit.com/post/${post._id}"`);
    expect(m.html).toContain('View the listing');
    expect(m.html).toContain('Stop receiving these emails');
    expect(m.html).toMatch(/lifecycle\/unsubscribe\?r=walker&amp;u=[a-f0-9]{24}&amp;t=[a-f0-9]{32}/);
    expect(m.opts.headers['List-Unsubscribe']).toMatch(/^<https:\/\/.+lifecycle\/unsubscribe\?r=walker&u=/);
    expect(m.html).not.toContain('{{');
    const fr = mockMails.find((x) => x.to === 'k99@example.test');
    expect(fr.subject).toBe('Nouvelle annonce : Promenade de chien · Paris');
    expect(fr.html).toContain('<strong>Dates :</strong> 12 octobre – 14 octobre');
    expect(fr.html).toContain('Ne plus recevoir ces e-mails');
  });
  test('désabonné : cloche et téléphone oui, AUCUN e-mail', async () => {
    expect(bilan.sent).toContain(W.unsub);
    expect(mockMails.some((m) => m.to === 'unsub612@example.test')).toBe(false);
    expect(mockPushes.some((m) => m.tokens.includes('jeton-unsub'))).toBe(true);
    const row = await RequestAlert.findOne({ postId: post._id, recipientId: W.unsub }).lean();
    expect(row.channels).toMatchObject({ bell: true, push: 'sent', email: 'unsubscribed' });
  });
  test('catégorie « Réservations » coupée dans l’app : cloche seule, ni téléphone ni e-mail', async () => {
    expect(mockMails.some((m) => m.to === 'prefsoff612@example.test')).toBe(false);
    expect(mockPushes.some((m) => m.tokens.includes('jeton-prefs'))).toBe(false);
    const row = await RequestAlert.findOne({ postId: post._id, recipientId: W.prefsOff }).lean();
    expect(row.channels).toMatchObject({ bell: true, push: 'prefs_off', email: 'prefs_off' });
  });
  test('admin : prévenus par canal', async () => {
    const sum = await alert612.channelSummary(post._id);
    expect(sum.people).toBe(7);
    expect(sum.bell).toBe(7);
    expect(sum.push).toBe(2); // near + unsub (les autres n'ont pas de jeton)
    expect(sum.pushNoToken).toBe(4);
    expect(sum.email).toBe(5); // 7 − désabonné − préférences coupées
    expect(sum.emailUnsubscribed).toBe(1);
    expect(bilan.channels).toEqual({ bell: 7, push: 2, email: 5 });
  });
});

describe('un envoi par annonce et par personne', () => {
  test('même annonce relancée : personne n’est prévenu deux fois', async () => {
    const post = await mkPost();
    const a = await alertFor(post);
    expect(a.sent.length).toBe(7);
    const mails = mockMails.length; const pushes = mockPushes.length;
    const b = await alertFor(post);
    expect(b.sent).toEqual([]);
    expect(b.skippedAlready.length).toBe(7);
    expect(mockMails.length).toBe(mails);
    expect(mockPushes.length).toBe(pushes);
    expect((await bellOf(post._id)).length).toBe(7);
  });
  test('annonce MODIFIÉE (même annonce, nouvelles dates) : pas de nouvel envoi', async () => {
    const post = await mkPost();
    await alertFor(post);
    const mails = mockMails.length;
    await Post.updateOne({ _id: post._id }, { $set: { startDate: new Date('2026-11-01T09:00:00.000Z'), endDate: new Date('2026-11-02T09:00:00.000Z') } });
    const b = await alertFor(await Post.findById(post._id).lean());
    expect(b.sent).toEqual([]);
    expect(mockMails.length).toBe(mails);
  });
  test('annonce REPUBLIÉE à l’identique (nouvelle annonce, même demande) : pas de nouvel envoi', async () => {
    await alertFor(await mkPost());
    const mails = mockMails.length;
    const twin = await mkPost();
    const b = await alertFor(twin);
    expect(b.sent).toEqual([]);
    expect(b.skippedAlready.length).toBe(7);
    expect(mockMails.length).toBe(mails);
    expect((await bellOf(twin._id)).length).toBe(0);
  });
  test('une AUTRE demande du même propriétaire (autres dates) prévient bien', async () => {
    await alertFor(await mkPost());
    const other = await mkPost({ startDate: new Date('2026-12-20T09:00:00.000Z'), endDate: new Date('2026-12-22T09:00:00.000Z') });
    expect((await alertFor(other)).sent.length).toBe(7);
  });
  test('deux envois lancés en même temps : le registre n’en laisse passer qu’un', async () => {
    const post = await mkPost();
    const [a, b] = await Promise.all([alertFor(post), alertFor(post)]);
    expect(a.sent.length + b.sent.length).toBe(7);
    expect((await bellOf(post._id)).length).toBe(7);
  });
  test('simulation (dryRun) : calcule, n’envoie rien, n’écrit rien', async () => {
    const post = await mkPost();
    const b = await alertFor(post, { dryRun: true });
    expect(b.candidates.length).toBe(7);
    expect(b.sent).toEqual([]);
    expect(mockMails.length + mockPushes.length).toBe(0);
    expect(await RequestAlert.countDocuments({})).toBe(0);
    expect((await bellOf(post._id)).length).toBe(0);
  });
  test('relance demandée par l’admin (resend) : renvoie, sans créer de doublon au registre', async () => {
    const post = await mkPost();
    await alertFor(post);
    const b = await alertFor(post, { resend: true });
    expect(b.sent.length).toBe(7);
    expect(await RequestAlert.countDocuments({ postId: post._id })).toBe(7);
  });
});

describe('autres services, comptes de test, publication non bloquée', () => {
  test('une garde prévient les gardiens (dont la personne aux deux profils, une fois), pas les promeneurs', async () => {
    const post = await mkPost({ serviceTypes: ['pet_sitting'] });
    const b = await alertFor(post);
    expect(b.roles).toEqual(['sitter']);
    expect([...b.sent].sort()).toEqual([S.near, S.both].sort());
    const m = mockMails.find((x) => x.to === 'sitnear612@example.test');
    expect(m.subject).toBe('Nouvelle annonce : Garde d’animaux · Paris');
    expect(m.text).toContain('cherche un gardien');
  });
  test('garde + balade : les deux rôles, la personne aux deux profils une seule fois', async () => {
    const post = await mkPost({ serviceTypes: ['pet_sitting', 'dog_walking'] });
    const b = await alertFor(post);
    expect(b.roles).toEqual(['sitter', 'walker']);
    expect(b.sent).toContain(S.near);
    expect(b.sent).toContain(W.near);
    expect(b.sent.filter((id) => id === S.both || id === W.both)).toEqual([S.both]);
  });
  test('annonce d’un compte +test : seuls des comptes +test sont prévenus, aucun vrai prestataire', async () => {
    const tOwner = await ins(Owner, { name: 'Essai', email: 'dada+testowner612@example.test' });
    const post = await mkPost({ ownerId: new mongoose.Types.ObjectId(tOwner) });
    const b = await alertFor(post);
    expect(b.testAccount).toBe(true);
    expect(b.sent).toEqual([W.test]);
    expect(mockMails.map((m) => m.to)).toEqual(['dada+testwalker612@example.test']);
  });
  test('annonce sans position ni ville géocodable : seuls les profils de la même ville (par le nom)', async () => {
    const post = await mkPost({ location: { city: 'Paris' } });
    const b = await alertFor(post);
    expect(b.sent).toEqual([W.parisName]);
  });
  test('la publication répond AVANT les envois, et une panne d’envoi ne casse rien', async () => {
    const { sendEmail } = require('../src/services/emailService');
    sendEmail.mockImplementationOnce(async () => { throw new Error('SMTP en panne'); });
    const res = {}; res.status = jest.fn(() => res); res.json = jest.fn((x) => { res.body = x; return res; });
    await postController.createPost({ user: { id: owner, role: 'owner' }, body: {
      body: 'Balade du soir', serviceTypes: ['dog_walking'], serviceLocation: 'at_owner',
      startDate: '2026-10-20T18:00:00.000Z', endDate: '2026-10-20T19:00:00.000Z',
      location: { city: 'Paris', ...PARIS },
    } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(mockMails.length).toBe(0); // rien n'est parti au moment de la réponse
    const id = res.body.post.id || res.body.post._id;
    for (let i = 0; i < 100 && (await RequestAlert.countDocuments({ postId: id, 'channels.push': { $ne: 'pending' } })) < 7; i += 1) {
      await new Promise((r) => setTimeout(r, 30));
    }
    const rows = await RequestAlert.find({ postId: id }).lean();
    expect(rows.length).toBe(7);
    expect(rows.filter((r) => r.channels.email === 'failed').length).toBe(1); // la panne est notée, les autres partent
    expect(rows.filter((r) => r.channels.email === 'sent').length).toBe(4);
    expect(rows.every((r) => r.channels.bell)).toBe(true);
  });
});

describe('613 §9 — la publication dit combien de prestataires sont RÉELLEMENT prévenus', () => {
  const publish = async (body) => {
    const res = {}; res.status = jest.fn(() => res); res.json = jest.fn((x) => { res.body = x; return res; });
    await postController.createPost({ user: { id: owner, role: 'owner' }, body }, res);
    return res;
  };
  const walk = (day) => ({
    body: 'Balade 613', serviceTypes: ['dog_walking'], serviceLocation: 'at_owner',
    startDate: `${day}T18:00:00.000Z`, endDate: `${day}T19:00:00.000Z`, location: { city: 'Paris', ...PARIS },
  });
  test('1re publication : notified = nombre de promeneurs réservés (pas l’offre de la ville)', async () => {
    const res = await publish(walk('2026-10-21'));
    expect(res.status).toHaveBeenCalledWith(201);
    const id = res.body.post.id || res.body.post._id;
    const rows = await RequestAlert.countDocuments({ postId: id });
    expect(res.body.notified).toBe(rows);
    expect(res.body.notified).toBe(7);
  });
  test('la MÊME demande republiée : notified = 0 (anti-doublon), jamais un chiffre gonflé', async () => {
    const first = await publish(walk('2026-10-22'));
    expect(first.body.notified).toBe(7);
    const again = await publish(walk('2026-10-22'));
    expect(again.status).toHaveBeenCalledWith(201);
    expect(again.body.notified).toBe(0);
  });
  test('panne avant le décompte : la réponse part quand même, sans `notified` ni attente de 4 s', async () => {
    const t0 = Date.now();
    const out = await new Promise((resolve) => {
      const res = {}; res.status = jest.fn(() => res); res.json = jest.fn((x) => { resolve(x); return res; });
      const { selectRecipients } = alert612;
      alert612.selectRecipients = async () => { alert612.selectRecipients = selectRecipients; throw new Error('base indisponible'); };
      postController.createPost({ user: { id: owner, role: 'owner' }, body: walk('2026-10-23') }, res);
    });
    expect(out.notified).toBeUndefined();
    expect(Date.now() - t0).toBeLessThan(3500);
  });
});

describe('gabarit dans les 9 langues', () => {
  const { enrichRequestAlertData, LOCALES } = require('../src/utils/requestAlertText612');
  const { render } = require('../src/utils/i18nTemplate');
  test.each(['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'])('%s : ville, service, dates, bouton ; aucune variable oubliée', (lang) => {
    expect(LOCALES).toContain(lang);
    const t = require(`../src/locales/${lang}/notifications.json`).new_request_nearby;
    for (const service of ['dog_walking', 'pet_sitting']) {
      const d = enrichRequestAlertData({
        ownerName: 'Camille', city: 'Paris', serviceType: service,
        startDate: '2026-10-12T09:30:00.000Z', endDate: '2026-10-14T18:00:00.000Z',
      }, lang);
      const all = [t.title, t.body, t.emailSubject, t.emailBody].map((x) => render(x, { ...d, emailLink: 'https://www.hopetsit.com/post/abc' }));
      for (const out of all) expect(out).not.toMatch(/\{\{|undefined|null/);
      expect(all[1]).toContain('Camille');
      expect(all[1]).toContain('Paris');
      expect(all[1]).toContain(d.serviceLabel);
      expect(all[2]).toContain(d.serviceName);
      expect(all[3]).toContain(d.dates);
      expect(all[3]).toContain('https://www.hopetsit.com/post/abc');
      expect(d.dates).toMatch(/12/);
      expect(d.dates).toMatch(/14/);
    }
    // Annonce sans dates, sans ville, sans nom : phrase toujours complète.
    const bare = enrichRequestAlertData({ serviceType: '' }, lang);
    const body = render(t.body, bare);
    expect(body).not.toMatch(/\{\{|undefined| {2}|^ /);
    expect(bare.datesSep).toBe('');
  });
});
