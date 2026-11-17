// 17/11/2026 (NEO, ordre de Daniel via BOB) — INSCRIPTION « E-MAIL D'ABORD » : aucun compte tant que le code n'est pas bon.
//   POST /auth/email-first/send | /check → jeton `emailProof` ; POST /auth/signup { emailProof } → compte né vérifié ;
//   POST /ad-leads/site { emailProof } → compte vérifié + demande PUBLIÉE tout de suite ; sans preuve : parcours d'avant.
//   Interrupteurs (éteints par défaut) : SIGNUP_EMAIL_PROOF_REQUIRED, AD_LEAD_ACCOUNT_AT_CLICK_1711.
// VRAIE base Mongo en mémoire, vrais contrôleurs (signup, createPost), vrai middleware d'auth, zone fictive
// (lat −35 / lng −30), aucun réseau (POSTAL_GEOCODE=off), aucun e-mail réel (emailService simulé).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => `${l}?k=signed`) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }), auth: () => ({ verifyIdToken: async () => { throw new Error('no'); } }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
const MAILS = [];
const VERIFY_MAILS = [];
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text, html }); return { messageId: 'mock' }; }),
  sendVerificationEmail: jest.fn(async (email, code) => { VERIFY_MAILS.push({ email, code }); }),
  sendPasswordResetEmail: jest.fn(async () => {}),
  sendTemplatedEmail: jest.fn(async () => ({})),
}));

const express = require('express');
const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let Post; let AdLead; let VerificationCode; let proofUtil;
const D = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const WEB = { 'X-App-Version': 'web' };
const send = (email, extra = {}) => request(app).post('/auth/email-first/send').send({ email, lang: 'fr', ...extra });
const check = (email, code) => request(app).post('/auth/email-first/check').send({ email, code });
const mailsTo = (email) => MAILS.filter((m) => m.to === email);
const codeOf = (mail) => { const m = /\b(\d{6})\b/.exec(mail.text); return m ? m[1] : ''; };
const USER = (email, extra = {}) => ({ name: 'Léa Martin', email, password: 'Motdepasse2026', city: 'Zone test', country: 'FR', appLocale: 'fr', acceptedTerms: true, ...extra });
const signup = (role, user, extra = {}, headers = WEB) => request(app).post('/auth/signup').set(headers).send({ role, user, ...extra });
const DEMANDE = (email, extra = {}) => ({
  email, firstName: 'Léa', service: 'garde', animal: 'chat', city: 'Zone test', postalCode: '75015', lat: -35, lng: -30,
  country: 'FR', lang: 'fr', startDate: D(10), endDate: D(12), campaign: 'paris_owners', page: '/demande', ...extra,
});
const site = (body) => request(app).post('/ad-leads/site').send(body);
/** Parcours complet envoi → bon code : rend la preuve. */
async function proofFor(email, extra = {}) {
  await send(email, extra).expect(200);
  const code = codeOf(mailsTo(email).slice(-1)[0]);
  const r = await check(email, code).expect(200);
  return r.body.emailProof;
}

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  Post = require('../src/models/Post'); AdLead = require('../src/models/AdLead2210');
  VerificationCode = require('../src/models/VerificationCode');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), Post.init(), AdLead.init(), VerificationCode.init()]);
  proofUtil = require('../src/utils/emailProof1711');
  app = express();
  app.use(express.json());
  app.use('/auth', require('../src/routes/authRoutes'));
  app.use('/ad-leads', require('../src/routes/adLeads2210'));
  const { requireAuth } = require('../src/middleware/auth');
  app.get('/prive', requireAuth, (req, res) => res.json({ id: req.user.id || null }));
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
beforeEach(() => {
  require('../src/routes/emailFirst1711')._resetForTest();
  require('../src/routes/adLeadsSite3110')._resetForTest();
  require('../src/routes/demandeCode0811')._resetForTest();
  delete process.env.SIGNUP_EMAIL_PROOF_REQUIRED; delete process.env.SIGNUP_EMAIL_PROOF_MIN_BUILD; delete process.env.AD_LEAD_ACCOUNT_AT_CLICK_1711; delete process.env.EMAIL_FIRST_1711;
});

describe('POST /auth/email-first/send', () => {
  test('adresse neuve : UN e-mail avec un code à 6 chiffres, dans la langue, SANS lien de validation ; code haché en base ; AUCUN compte créé', async () => {
    const email = 'lea.neuve1711@example.test';
    const r = await send(email, { lang: 'fr' }).expect(200);
    expect(r.body).toMatchObject({ ok: true, sent: true, retryAfter: 60 });
    const m = mailsTo(email);
    expect(m).toHaveLength(1);
    expect(m[0].subject).toMatch(/^\d{6} — ton code HoPetSit$/);
    const code = codeOf(m[0]);
    expect(code).toMatch(/^\d{6}$/);
    expect(m[0].text).not.toMatch(/verify-link|https?:\/\//);
    expect(m[0].html).not.toMatch(/href=/);
    const rec = await VerificationCode.findOne({ email, purpose: 'email_first' }).lean();
    expect(rec).toBeTruthy();
    expect(rec.code).not.toBe(code); // haché
    expect(rec.code).toHaveLength(64);
    expect(new Date(rec.expiresAt).getTime() - Date.now()).toBeLessThanOrEqual(60 * 60 * 1000 + 5000);
    expect(await Owner.countDocuments({ email })).toBe(0);
    expect(await Sitter.countDocuments({ email })).toBe(0);
    expect(await Walker.countDocuments({ email })).toBe(0);
    expect(await AdLead.countDocuments({ email })).toBe(0);
  });

  test('langue : anglais, coréen ; langue inconnue → anglais', async () => {
    await send('en1711@example.test', { lang: 'en' }).expect(200);
    expect(mailsTo('en1711@example.test')[0].subject).toMatch(/your HoPetSit code$/);
    await send('ko1711@example.test', { lang: 'ko' }).expect(200);
    expect(mailsTo('ko1711@example.test')[0].subject).toMatch(/HoPetSit 인증 코드$/);
    await send('xx1711@example.test', { lang: 'zz' }).expect(200);
    expect(mailsTo('xx1711@example.test')[0].subject).toMatch(/your HoPetSit code$/);
  });

  test.each([
    ['lea@gmail.con', 'lea@gmail.com'], ['lea@gmail.fr', 'lea@gmail.com'], ['lea@aol.coms', 'lea@aol.com'],
    ['lea@hotmial.com', 'lea@hotmail.com'], ['Lea.Martin@GMAI.COM', 'lea.martin@gmail.com'], ['lea@iclous.com', 'lea@icloud.com'],
  ])('faute de frappe %s → suggestion %s, RIEN envoyé, rien en base', async (typed, wanted) => {
    const before = MAILS.length;
    const r = await send(typed).expect(200);
    expect(r.body).toEqual({ suggestion: wanted });
    expect(MAILS.length).toBe(before);
    expect(await VerificationCode.countDocuments({ email: typed.toLowerCase() })).toBe(0);
  });

  test('e-mail invalide → 400 ; adresse +test ou staff → 403 TEST_ACCOUNT, aucun envoi', async () => {
    const before = MAILS.length;
    await send('pas-un-email').expect(400);
    await send('').expect(400);
    const r = await send('dadaciao84+testowner@gmail.com').expect(403);
    expect(r.body.code).toBe('TEST_ACCOUNT');
    await send('staff@hopetsit.com').expect(403);
    expect(MAILS.length).toBe(before);
  });

  test('compte VÉRIFIÉ existant (n\'importe quel rôle) → { exists: true } sans envoi ; avec allowExisting → code envoyé ; compte NON vérifié → code envoyé', async () => {
    await Sitter.create({ name: 'Déjà Là', email: 'deja.verifie1711@example.test', password: 'Motdepasse2026', verified: true, acceptedTerms: true });
    const before = MAILS.length;
    const r = await send('deja.verifie1711@example.test').expect(200);
    expect(r.body).toEqual({ exists: true });
    expect(MAILS.length).toBe(before);
    const r2 = await send('deja.verifie1711@example.test', { allowExisting: true }).expect(200);
    expect(r2.body).toMatchObject({ ok: true, sent: true, exists: true });
    expect(MAILS.length).toBe(before + 1);
    await Owner.create({ name: 'Pas Encore', email: 'non.verifie1711@example.test', password: 'Motdepasse2026', verified: false, acceptedTerms: true });
    const r3 = await send('non.verifie1711@example.test').expect(200);
    expect(r3.body.ok).toBe(true);
    expect(r3.body.exists).toBeUndefined();
  });

  test('limites : 2e envoi < 60 s → 429 RESEND_TOO_SOON (aussi après « redémarrage ») ; 5 envois / 24 h puis 429 TOO_MANY ; l\'alias +x compte pour la même boîte', async () => {
    const email = 'limite1711@example.test';
    const ef = require('../src/routes/emailFirst1711');
    await send(email).expect(200);
    const r = await send(email).expect(429);
    expect(r.body.code).toBe('RESEND_TOO_SOON');
    expect(r.body.retryAfter).toBeGreaterThan(50);
    // « redémarrage » : compteurs mémoire vidés, la date du code en base garde le délai
    ef._resetForTest();
    expect((await send(email).expect(429)).body.code).toBe('RESEND_TOO_SOON');
    // le délai passe (mémoire reculée + code en base vieilli) → nouveaux envois jusqu'à 5 au total
    const age = async () => { ef._backdateForTest(email, 61000); await VerificationCode.collection.updateMany({ email: { $in: [email, 'limite1711+a@example.test'] } }, { $set: { updatedAt: new Date(Date.now() - 61000), createdAt: new Date(Date.now() - 61000) } }); };
    ef._resetForTest();
    await age();
    for (let i = 0; i < 4; i += 1) { await send(email).expect(200); await age(); }
    await send('limite1711+a@example.test').expect(200); // 5e envoi de la boîte (alias)
    await age();
    const r6 = await send(email).expect(429);
    expect(r6.body.code).toBe('TOO_MANY');
    expect(mailsTo(email).length + mailsTo('limite1711+a@example.test').length).toBe(6); // 1 (avant reset) + 5
  });
});

test('COUPE-CIRCUIT EMAIL_FIRST_1711=off : les deux routes répondent 404 (site et app reprennent l\'ancien parcours), rien envoyé', async () => {
  process.env.EMAIL_FIRST_1711 = 'off';
  const before = MAILS.length;
  await send('coupe1711@example.test').expect(404);
  await check('coupe1711@example.test', '123456').expect(404);
  expect(MAILS.length).toBe(before);
  delete process.env.EMAIL_FIRST_1711;
  await send('coupe1711@example.test').expect(200);
});

describe('POST /auth/email-first/check', () => {
  test('bon code → emailProof (jeton 60 min pour CETTE adresse, minuscules), code consommé (2e essai → 410)', async () => {
    const email = 'Bon.Code1711@Example.test';
    await send(email).expect(200);
    const code = codeOf(mailsTo('bon.code1711@example.test')[0]);
    const r = await check(email, code).expect(200);
    expect(typeof r.body.emailProof).toBe('string');
    const p = jwt.decode(r.body.emailProof);
    expect(p).toMatchObject({ t: 'email_first', email: 'bon.code1711@example.test' });
    expect(p.exp - p.iat).toBe(3600);
    expect(proofUtil.verifyEmailProof(r.body.emailProof, 'bon.code1711@example.test')).toBe(true);
    expect(proofUtil.verifyEmailProof(r.body.emailProof, 'autre@example.test')).toBe(false);
    expect((await check(email, code).expect(410)).body.code).toBe('CODE_EXPIRED');
    expect(await Owner.countDocuments({ email: 'bon.code1711@example.test' })).toBe(0); // toujours aucun compte
  });

  test('faux code → 400 CODE_INVALID avec les essais restants ; 5 faux → 429 TOO_MANY_TRIES même avec le bon code', async () => {
    const email = 'faux1711@example.test';
    await send(email).expect(200);
    const good = codeOf(mailsTo(email)[0]);
    const bad = good === '000000' ? '111111' : '000000';
    for (let left = 4; left >= 0; left -= 1) {
      const r = await check(email, bad).expect(400);
      expect(r.body).toMatchObject({ code: 'CODE_INVALID', left });
    }
    expect((await check(email, good).expect(429)).body.code).toBe('TOO_MANY_TRIES');
  });

  test('sans code demandé → 410 ; code expiré → 410 ; e-mail invalide → 400', async () => {
    expect((await check('jamais1711@example.test', '123456').expect(410)).body.code).toBe('CODE_EXPIRED');
    const email = 'expire1711@example.test';
    await send(email).expect(200);
    await VerificationCode.updateOne({ email, purpose: 'email_first' }, { $set: { expiresAt: new Date(Date.now() - 1000) } });
    expect((await check(email, codeOf(mailsTo(email)[0])).expect(410)).body.code).toBe('CODE_EXPIRED');
    await check('rien', '123456').expect(400);
  });

  test('le code « e-mail d\'abord » ne valide PAS /auth/verify, et la preuve n\'est PAS un jeton de session', async () => {
    const email = 'cloison1711@example.test';
    const proof = await proofFor(email);
    await request(app).get('/prive').set('Authorization', `Bearer ${proof}`).expect(401);
    // un jeton de session ne vaut pas preuve
    const session = require('../src/controllers/authController').signAuthToken({ id: String(new mongoose.Types.ObjectId()), role: 'owner', t: 'email_first', email });
    expect(proofUtil.verifyEmailProof(session, email)).toBe(false);
    expect(proofUtil.verifyEmailProof('n-importe-quoi', email)).toBe(false);
    expect(proofUtil.verifyEmailProof('', email)).toBe(false);
  });
});

describe('POST /auth/signup avec ou sans preuve', () => {
  test.each(['owner', 'sitter', 'walker'])('%s AVEC preuve : 201, compte né vérifié, jeton, emailVerified:true, AUCUN e-mail de code, preuve datée', async (role) => {
    const email = `avec.preuve.${role}1711@example.test`;
    const proof = await proofFor(email);
    const vBefore = VERIFY_MAILS.length;
    const r = await signup(role, USER(email), { emailProof: proof }).expect(201);
    expect(r.body).toMatchObject({ role, emailVerified: true });
    expect(typeof r.body.token).toBe('string');
    expect(r.body.user.email).toBe(email);
    expect(r.body.availableRoles.map((x) => x.role)).toContain(role);
    expect(VERIFY_MAILS.length).toBe(vBefore);
    expect(await VerificationCode.countDocuments({ email })).toBe(0);
    const M = role === 'owner' ? Owner : role === 'sitter' ? Sitter : Walker;
    const acc = await M.findOne({ email }).lean();
    expect(acc.verified).toBe(true);
    expect(acc.city).toBe('Zone test');
    if (role === 'owner') { expect(acc.emailProvenAt).toBeTruthy(); expect(acc.emailProofSource).toBe('email_first'); }
    // le jeton rendu ouvre bien une session
    const me = await request(app).get('/prive').set('Authorization', `Bearer ${r.body.token}`).expect(200);
    expect(me.body.id).toBe(String(acc._id));
  });

  test('SANS preuve (app installée) : parcours d\'avant inchangé — 201, compte NON vérifié, e-mail de code envoyé', async () => {
    const email = 'sans.preuve1711@example.test';
    const vBefore = VERIFY_MAILS.length;
    const r = await signup('owner', USER(email), {}, { 'X-App-Version': '23.1.640+646' }).expect(201);
    expect(r.body.emailVerified).toBe(false);
    expect(typeof r.body.token).toBe('string');
    expect(VERIFY_MAILS.length).toBe(vBefore + 1);
    expect((await Owner.findOne({ email }).lean()).verified).toBe(false);
    expect(await VerificationCode.countDocuments({ email, purpose: 'email_verification' })).toBe(1);
  });

  test('preuve d\'une AUTRE adresse, preuve trafiquée ou expirée → 400 EMAIL_PROOF_INVALID, rien créé', async () => {
    const proofA = await proofFor('a.preuve1711@example.test');
    const r = await signup('owner', USER('b.preuve1711@example.test'), { emailProof: proofA }).expect(400);
    expect(r.body.code).toBe('EMAIL_PROOF_INVALID');
    await signup('owner', USER('b.preuve1711@example.test'), { emailProof: `${proofA}x` }).expect(400);
    const crypto = require('crypto');
    const secret = crypto.createHmac('sha256', process.env.JWT_SECRET).update('hopetsit:email_first:1711').digest('hex');
    const old = jwt.sign({ t: 'email_first', email: 'b.preuve1711@example.test' }, secret, { expiresIn: -10 });
    await signup('owner', USER('b.preuve1711@example.test'), { emailProof: old }).expect(400);
    expect(await Owner.countDocuments({ email: 'b.preuve1711@example.test' })).toBe(0);
  });

  test('compte NON vérifié déjà en base (ancienne inscription, contact pub) + preuve : même compte, vérifié, nouveau mot de passe actif, connecté', async () => {
    const email = 'ancien.nonverifie1711@example.test';
    const old = await Owner.create({ name: 'Ancien', email, password: 'AncienMotDePasse1', verified: false, acceptedTerms: true, city: 'Zone test' });
    const proof = await proofFor(email);
    const r = await signup('owner', USER(email, { password: 'NouveauMotDePasse2' }), { emailProof: proof }).expect(200);
    expect(r.body).toMatchObject({ role: 'owner', emailVerified: true });
    expect(typeof r.body.token).toBe('string');
    expect(await Owner.countDocuments({ email })).toBe(1);
    const acc = await Owner.findById(old._id);
    expect(acc.verified).toBe(true);
    expect(await acc.comparePassword('NouveauMotDePasse2')).toBe(true);
  });

  test('compte VÉRIFIÉ déjà en base → 409 comme avant, même avec une preuve', async () => {
    const email = 'deja.owner1711@example.test';
    await Owner.create({ name: 'Déjà', email, password: 'Motdepasse2026', verified: true, acceptedTerms: true, city: 'Zone test' });
    const proof = proofUtil.signEmailProof(email);
    await signup('owner', USER(email), { emailProof: proof }).expect(409);
  });

  test('INTERRUPTEUR éteint par défaut ; SIGNUP_EMAIL_PROOF_REQUIRED=on → le site sans preuve = 400 EMAIL_PROOF_REQUIRED (rien créé), les anciennes apps passent toujours, les apps ≥ build minimum sont tenues à la preuve', async () => {
    process.env.SIGNUP_EMAIL_PROOF_REQUIRED = 'on';
    const r = await signup('owner', USER('exige.web1711@example.test')).expect(400);
    expect(r.body.code).toBe('EMAIL_PROOF_REQUIRED');
    expect(await Owner.countDocuments({ email: 'exige.web1711@example.test' })).toBe(0);
    // ancienne app (aucun build minimum posé) : comme avant
    await signup('owner', USER('exige.app1711@example.test'), {}, { 'X-App-Version': '23.1.640+646' }).expect(201);
    // sans en-tête (très vieille app) : comme avant
    await request(app).post('/auth/signup').send({ role: 'owner', user: USER('exige.vieux1711@example.test') }).expect(201);
    process.env.SIGNUP_EMAIL_PROOF_MIN_BUILD = '650';
    await signup('owner', USER('exige.app2.1711@example.test'), {}, { 'X-App-Version': '23.1.640+649' }).expect(201);
    expect((await signup('owner', USER('exige.app3.1711@example.test'), {}, { 'X-App-Version': '23.1.641+650' }).expect(400)).body.code).toBe('EMAIL_PROOF_REQUIRED');
    // avec preuve : passe
    const proof = await proofFor('exige.ok1711@example.test');
    await signup('owner', USER('exige.ok1711@example.test'), { emailProof: proof }).expect(201);
    // 2e profil d'une personne déjà vérifiée : pas de nouvelle preuve demandée
    await signup('sitter', USER('exige.ok1711@example.test')).expect(201);
    expect((await Sitter.findOne({ email: 'exige.ok1711@example.test' }).lean()).verified).toBe(true);
  });

  test('2e profil d\'une personne dont le 1er profil n\'a PAS de position GPS : l\'héritage passe (e-mail déjà vérifié, pas de nouveau code)', async () => {
    const email = 'frere.sansgps1711@example.test';
    const proof = await proofFor(email);
    await signup('owner', USER(email, { mobile: '0611223344' }), { emailProof: proof }).expect(201);
    const vBefore = VERIFY_MAILS.length;
    const r = await signup('walker', USER(email), {}, { 'X-App-Version': '23.1.640+646' }).expect(201);
    expect(r.body.emailVerified).toBe(true);
    expect(VERIFY_MAILS.length).toBe(vBefore);
    const w = await Walker.findOne({ email }).lean();
    expect(w.verified).toBe(true);
    expect(w.mobile).toBe('0611223344');
  });
});

describe('POST /ad-leads/site avec preuve (pages /demande et /request)', () => {
  test('adresse neuve + preuve : 200, compte propriétaire VÉRIFIÉ, demande PUBLIÉE tout de suite, session ouverte, aucun brouillon, aucun e-mail « code » en plus', async () => {
    const email = 'demande.neuve1711@example.test';
    const proof = await proofFor(email, { allowExisting: true });
    expect(await Owner.countDocuments({ email })).toBe(0); // rien avant l'envoi du formulaire
    expect(await AdLead.countDocuments({ email })).toBe(0);
    const before = mailsTo(email).length;
    const r = await site(DEMANDE(email, { emailProof: proof })).expect(200);
    expect(r.body).toMatchObject({ existing: false, pending: false, published: true, accountCreated: true });
    expect(typeof r.body.token).toBe('string');
    expect(r.body.user).toMatchObject({ email, role: 'owner' });
    expect(r.body.postId).toBeTruthy();
    expect(r.body.link).toContain('/posts');
    const owner = await Owner.findOne({ email }).lean();
    expect(owner.verified).toBe(true);
    expect(owner.emailProofSource).toBe('email_first');
    expect(owner.adLeadAt).toBeTruthy();
    const post = await Post.findById(r.body.postId).lean();
    expect(post).toBeTruthy();
    expect(String(post.ownerId)).toBe(String(owner._id));
    const lead = await AdLead.findById(r.body.id).lean();
    expect(lead).toMatchObject({ pendingConfirm: false, source: 'site', campaign: 'paris_owners', page: '/demande' });
    expect(String(lead.postId)).toBe(String(r.body.postId));
    expect(lead.clickedAt).toBeTruthy();
    expect(mailsTo(email).filter((m) => /code/i.test(m.subject)).length).toBe(before); // pas de 2e e-mail « code »
    expect(await VerificationCode.countDocuments({ email })).toBe(0);
  });

  test('compte VÉRIFIÉ existant + preuve : demande publiée sur SON compte, pas de 2e compte', async () => {
    const email = 'demande.existant1711@example.test';
    const o = await Owner.create({ name: 'Zoé Existante', email, password: 'Motdepasse2026', verified: true, acceptedTerms: true, city: 'Zone test' });
    const proof = await proofFor(email, { allowExisting: true });
    const r = await site(DEMANDE(email, { emailProof: proof })).expect(200);
    expect(r.body.published).toBe(true);
    expect(r.body.accountCreated).toBe(false);
    expect(r.body.user.id).toBe(String(o._id));
    expect(await Owner.countDocuments({ email })).toBe(1);
  });

  test('preuve fausse ou d\'une autre adresse → 400 EMAIL_PROOF_INVALID : ni contact, ni compte, ni demande', async () => {
    const proofA = await proofFor('autre.demande1711@example.test', { allowExisting: true });
    const email = 'vol.demande1711@example.test';
    const posts = await Post.countDocuments({});
    const r = await site(DEMANDE(email, { emailProof: proofA })).expect(400);
    expect(r.body.code).toBe('EMAIL_PROOF_INVALID');
    expect(await AdLead.countDocuments({ email })).toBe(0);
    expect(await Owner.countDocuments({ email })).toBe(0);
    expect(await Post.countDocuments({})).toBe(posts);
  });

  test('preuve valide mais formulaire refusé (dates manquantes) → 400 DATES_REQUIRED, rien créé ; la MÊME preuve sert au 2e envoi corrigé', async () => {
    const email = 'dates.demande1711@example.test';
    const proof = await proofFor(email, { allowExisting: true });
    const r = await site(DEMANDE(email, { emailProof: proof, startDate: '', endDate: '' })).expect(400);
    expect(r.body.code).toBe('DATES_REQUIRED');
    expect(await Owner.countDocuments({ email })).toBe(0);
    expect(await AdLead.countDocuments({ email })).toBe(0);
    const ok = await site(DEMANDE(email, { emailProof: proof })).expect(200);
    expect(ok.body.published).toBe(true);
  });

  test('un ancien brouillon en attente pour la même boîte est clos (plus de rappel) et c\'est la nouvelle demande qui est publiée', async () => {
    const email = 'brouillon.demande1711@example.test';
    const d = await site(DEMANDE(email, { codeFlow: true })).expect(202); // ancien parcours : brouillon + compte non vérifié
    expect((await AdLead.findById(d.body.id).lean()).pendingConfirm).toBe(true);
    require('../src/routes/adLeadsSite3110')._resetForTest();
    const proof = await proofFor(email, { allowExisting: true });
    const r = await site(DEMANDE(email, { emailProof: proof, startDate: D(20), endDate: D(22) })).expect(200);
    expect(r.body.published).toBe(true);
    expect(r.body.id).not.toBe(d.body.id);
    expect((await AdLead.findById(d.body.id).lean()).pendingConfirm).toBe(false);
    expect(await Owner.countDocuments({ email })).toBe(1);
    expect((await Owner.findOne({ email }).lean()).verified).toBe(true);
    const rem = await require('../src/services/adLeadConfirmReminder3110').runAdLeadConfirmReminders({ now: new Date(Date.now() + 5 * 3600 * 1000), dryRun: true });
    expect(rem.wouldSend).toBe(0);
  });

  test('demande encore ouverte + preuve : la même demande, session ouverte (existing:true, jeton)', async () => {
    const email = 'encore.ouverte1711@example.test';
    const p1 = await proofFor(email, { allowExisting: true });
    const a = await site(DEMANDE(email, { emailProof: p1 })).expect(200);
    require('../src/routes/adLeadsSite3110')._resetForTest();
    const b = await site(DEMANDE(email, { emailProof: p1 })).expect(200);
    expect(b.body).toMatchObject({ existing: true, published: false, postId: a.body.postId });
    expect(typeof b.body.token).toBe('string');
    expect(await Post.countDocuments({ ownerId: a.body.user.id })).toBe(1);
  });

  test('SANS preuve : parcours du 08/11 intact (202, brouillon, compte non vérifié, e-mail « code »)', async () => {
    const email = 'ancien.parcours1711@example.test';
    const r = await site(DEMANDE(email, { codeFlow: true })).expect(202);
    expect(r.body).toMatchObject({ pending: true, code: true });
    expect((await Owner.findOne({ email }).lean()).verified).toBe(false);
    expect(await Post.countDocuments({ ownerId: (await Owner.findOne({ email }).lean())._id })).toBe(0);
  });
});

describe('Formulaire Facebook : compte créé seulement au clic (AD_LEAD_ACCOUNT_AT_CLICK_1711, éteint par défaut)', () => {
  const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
  const newLead = (email) => AdLead.create({ metaLeadId: `meta_1711_${email}`, email, firstName: 'Léa', city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'bientot' });

  test('éteint (défaut) : comme aujourd\'hui, le brouillon crée un compte NON vérifié', async () => {
    const email = 'fb.defaut1711@example.test';
    const lead = await newLead(email);
    const r = await require('../src/routes/adLeads2210').draftLead(lead);
    expect(r).toMatchObject({ pending: true, emailSent: true });
    expect(r.ownerId).toBeTruthy();
    expect((await Owner.findOne({ email }).lean()).verified).toBe(false);
  });

  test('allumé : brouillon + e-mail « confirme » SANS compte ; rappel +3 h dû ; le clic crée le compte, le vérifie et publie', async () => {
    process.env.AD_LEAD_ACCOUNT_AT_CLICK_1711 = 'on';
    const email = 'fb.auclic1711@example.test';
    const lead = await newLead(email);
    const r = await require('../src/routes/adLeads2210').draftLead(lead);
    expect(r).toMatchObject({ pending: true, emailSent: true, ownerId: null, verified: false });
    expect(await Owner.countDocuments({ email })).toBe(0);
    const fresh = await AdLead.findById(lead._id).lean();
    expect(fresh.pendingConfirm).toBe(true);
    expect(fresh.ownerId).toBeFalsy();
    expect(mailsTo(email)).toHaveLength(1);
    expect(mailsTo(email)[0].text).toContain(`/posts/confirmer?l=${lead._id}`);
    // rappel : dû à +4 h en journée, sans compte
    const reminder = require('../src/services/adLeadConfirmReminder3110');
    const noon = new Date(); noon.setUTCHours(11, 0, 0, 0);
    await AdLead.updateOne({ _id: lead._id }, { $set: { confirmEmailAt: new Date(noon.getTime() - 4 * 3600 * 1000) } });
    await reminder.runAdLeadConfirmReminders({ now: noon });
    expect(mailsTo(email)).toHaveLength(2);
    expect(mailsTo(email)[1].subject).toBe('Léa, ta demande attend ta confirmation');
    expect((await AdLead.findById(lead._id).lean()).confirmReminderAt).toBeTruthy();
    expect(await Owner.countDocuments({ email })).toBe(0);
    // 2e appel de /draft : toujours pas de compte, pas de 2e e-mail « confirme »
    await require('../src/routes/adLeads2210').draftLead(await AdLead.findById(lead._id));
    expect(await Owner.countDocuments({ email })).toBe(0);
    // le clic de l'e-mail
    const c = await request(app).post(`/ad-leads/${lead._id}/confirm`).set(BROWSER).send({}).expect(200);
    expect(typeof c.body.token).toBe('string');
    expect(c.body.postId).toBeTruthy();
    const owner = await Owner.findOne({ email }).lean();
    expect(owner.verified).toBe(true);
    expect(owner.adLeadAt).toBeTruthy();
    expect(await Post.countDocuments({ ownerId: owner._id })).toBe(1);
  });

  test('allumé + compte déjà existant pour l\'adresse : rattaché, jamais dupliqué, état de vérification intact', async () => {
    process.env.AD_LEAD_ACCOUNT_AT_CLICK_1711 = 'on';
    const email = 'fb.existant1711@example.test';
    const o = await Owner.create({ name: 'Déjà', email, password: 'Motdepasse2026', verified: true, acceptedTerms: true, city: 'Zone test' });
    const r = await require('../src/routes/adLeads2210').draftLead(await newLead(email));
    expect(r.ownerId).toBe(String(o._id));
    expect(r.verified).toBe(true);
    expect(await Owner.countDocuments({ email })).toBe(1);
    expect((await Owner.findById(o._id).lean()).adLeadAt).toBeTruthy();
  });
});
