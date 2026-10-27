// 22/10/2026 (SAM, accord de Daniel « bouton 1 clic ») — contact de la pub à
// formulaire → demande publiée en un clic. VRAIE base Mongo en mémoire, vrais
// gestionnaires (createPost compris), zone fictive (lat -35 / lng -30), aucun réseau.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
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
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Post; let AdLead;
const ADMIN = { 'x-test-user': String(new mongoose.Types.ObjectId()), 'x-test-role': 'admin' };
const LEAD = {
  metaLeadId: 'meta-1', email: 'Lea+test2210@example.com', firstName: 'Léa',
  city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr',
  service: 'garde', animal: 'chat', quand: 'fetes',
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Post = require('../src/models/Post');
  AdLead = require('../src/models/AdLead2210');
  await Promise.all([Owner.init(), Post.init(), AdLead.init()]);
  const routes = require('../src/routes/adLeads2210');
  app = express();
  app.use(express.json());
  app.use('/admin/ad-leads', routes.adminRouter);
  app.use('/ad-leads', routes);
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('enregistrement réservé à l’admin, idempotent, id opaque', async () => {
  await request(app).post('/admin/ad-leads').send(LEAD).expect(401);
  const a = await request(app).post('/admin/ad-leads').set(ADMIN).send(LEAD).expect(200);
  const b = await request(app).post('/admin/ad-leads').set(ADMIN).send(LEAD).expect(200);
  expect(a.body.id).toMatch(/^[a-f0-9]{32}$/);
  expect(b.body.id).toBe(a.body.id);
  const pub = await request(app).get(`/ad-leads/${a.body.id}`).expect(200);
  expect(pub.body).toMatchObject({ firstName: 'Léa', city: 'Zone test', service: 'garde', confirmed: false });
  expect(JSON.stringify(pub.body)).not.toMatch(/example\.com/);
  await request(app).get('/ad-leads/pas-un-id').expect(404);
});

// 27/10 (SAM, décision de Daniel) — seul un VRAI clic (navigateur / app) prouve l'e-mail.
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
test('un clic depuis un navigateur : compte vérifié + preuve datée + demande publiée + session ; 2e clic = même demande', async () => {
  const { body: { id } } = await request(app).post('/admin/ad-leads').set(ADMIN).send(LEAD);
  const r = await request(app).post(`/ad-leads/${id}/confirm`).set(BROWSER).send({ lieu: 'at_sitter' }).expect(200);
  const owner = await Owner.findOne({ email: 'lea+test2210@example.com' });
  expect(owner).toBeTruthy();
  expect(owner.verified).toBe(true);
  expect(owner.emailProvenAt).toBeTruthy();
  expect(owner.emailProofSource).toBe('lead_web');
  expect(owner.adLeadAt).toBeTruthy();
  expect((await AdLead.findById(id)).clickedAt).toBeTruthy();
  expect(owner.acceptedTerms).toBe(true);
  expect(owner.currency).toBe('EUR');
  expect(jwt.verify(r.body.token, process.env.JWT_SECRET)).toMatchObject({ id: String(owner._id), role: 'owner' });
  const post = await Post.findById(r.body.postId);
  expect(post.body).toBe("Je cherche une garde pour mon chat pendant les fêtes de fin d'année.");
  expect(post.serviceTypes).toEqual(['house_sitting']);
  expect(post.houseSittingVenue).toBe('sitters_home');
  expect(post.location.city).toBe('Zone test');

  const r2 = await request(app).post(`/ad-leads/${id}/confirm`).send({}).expect(200);
  expect(r2.body.postId).toBe(r.body.postId);
  expect(await Post.countDocuments({ ownerId: owner._id })).toBe(1);
  expect((await request(app).get(`/ad-leads/${id}`)).body.confirmed).toBe(true);
});

test('compte existant non vérifié : réutilisé, vérifié au vrai clic ; promenade en anglais', async () => {
  await Owner.create({ name: 'Sam', email: 'sam+test2210@example.com', password: 'motdepasse123', verified: false });
  const { body: { id } } = await request(app).post('/admin/ad-leads').set(ADMIN).send({
    ...LEAD, metaLeadId: 'meta-2', email: 'sam+test2210@example.com', lang: 'en', country: 'US',
    service: 'promenade', animal: 'chien', quand: 'bientot',
  });
  const r = await request(app).post(`/ad-leads/${id}/confirm`).set(BROWSER).send({}).expect(200);
  expect(await Owner.countDocuments({ email: 'sam+test2210@example.com' })).toBe(1);
  expect((await Owner.findOne({ email: 'sam+test2210@example.com' })).verified).toBe(true);
  const post = await Post.findById(r.body.postId);
  expect(post.body).toBe("I'm looking for dog walks for my dog within 2 weeks.");
  expect(post.serviceTypes).toEqual(['dog_walking']);
});

// 23/10 (SAM, consigne de Daniel) — le suivi publie dès le formulaire rempli, par la route admin.
test('admin publish : compte NON vérifié (marqué pub) + demande + gardiens, sans session ; un clic de script ne prouve rien ; GET renvoie postId', async () => {
  const { body: { id } } = await request(app).post('/admin/ad-leads').set(ADMIN).send({
    ...LEAD, metaLeadId: 'meta-3', email: 'ana+test2310@example.com', firstName: 'Ana', service: 'visites', quand: 'bientot',
  });
  await request(app).post(`/admin/ad-leads/${id}/publish`).send({}).expect(401);
  const r = await request(app).post(`/admin/ad-leads/${id}/publish`).set(ADMIN).send({}).expect(200);
  expect(r.body.token).toBeUndefined();
  expect(r.body.alreadyPublished).toBe(false);
  expect(r.body.postId).toMatch(/^[a-f0-9]{24}$/);
  const owner = await Owner.findOne({ email: 'ana+test2310@example.com' });
  expect(owner.verified).toBe(false);
  expect(owner.emailProvenAt).toBeNull();
  expect(owner.adLeadAt).toBeTruthy();
  expect(String(r.body.ownerId)).toBe(String(owner._id));
  const post = await Post.findById(r.body.postId);
  expect(post.body).toBe('Je cherche des visites à domicile pour mon chat dans les 15 jours.');
  expect(post.serviceLocation).toBe('at_owner');

  const r2 = await request(app).post(`/admin/ad-leads/${id}/publish`).set(ADMIN).send({}).expect(200);
  expect(r2.body.postId).toBe(r.body.postId);
  expect(r2.body.alreadyPublished).toBe(true);
  expect(await Post.countDocuments({ ownerId: owner._id })).toBe(1);
  const pub = await request(app).get(`/ad-leads/${id}`).expect(200);
  expect(pub.body).toMatchObject({ confirmed: true, postId: r.body.postId });
  // le clic depuis l'e-mail, après coup, ouvre la session sur la même demande
  const r3 = await request(app).post(`/ad-leads/${id}/confirm`).send({}).expect(200);
  expect(r3.body.postId).toBe(r.body.postId);
  // sans User-Agent (= script) : aucune preuve
  expect((await Owner.findById(owner._id)).verified).toBe(false);
  await request(app).post(`/ad-leads/${id}/confirm`).set({ 'User-Agent': 'Python-urllib/3.12' }).send({}).expect(200);
  expect((await Owner.findById(owner._id)).verified).toBe(false);
  await request(app).post(`/ad-leads/${id}/confirm`).set(BROWSER).send({}).expect(200);
  const proven = await Owner.findById(owner._id);
  expect(proven.verified).toBe(true);
  expect(proven.emailProvenAt).toBeTruthy();
  await request(app).post('/admin/ad-leads/00000000000000000000000000000000/publish').set(ADMIN).send({}).expect(404);
});

// 23/10 (BOB, demande de Daniel « sur les annonces publiées il faut les dates »)
test('dates : réponses du formulaire posées sur l\'annonce ; sinon déduites de « quand »', async () => {
  const a = await request(app).post('/admin/ad-leads').set(ADMIN).send({
    ...LEAD, metaLeadId: 'meta-dates-1', email: 'lea+test2310@example.com', firstName: 'Léa', service: 'garde',
    quand: 'plus_tard', startText: '24/12/2026', endText: '2/1/2027',
  }).expect(200);
  const r = await request(app).post(`/admin/ad-leads/${a.body.id}/publish`).set(ADMIN).send({}).expect(200);
  expect(r.body.dates).toBe('form');
  const post = await Post.findById(r.body.postId);
  expect(post.startDate.toISOString().slice(0, 10)).toBe('2026-12-24');
  expect(post.endDate.toISOString().slice(0, 10)).toBe('2027-01-02');

  const b = await request(app).post('/admin/ad-leads').set(ADMIN).send({
    ...LEAD, metaLeadId: 'meta-dates-2', email: 'noe+test2310@example.com', firstName: 'Noé', service: 'garde', quand: 'fetes',
  }).expect(200);
  const r2 = await request(app).post(`/admin/ad-leads/${b.body.id}/publish`).set(ADMIN).send({}).expect(200);
  expect(r2.body.dates).toBe('quand');
  const post2 = await Post.findById(r2.body.postId);
  expect(post2.startDate.toISOString().slice(5, 10)).toBe('12-20');
  expect(post2.endDate.toISOString().slice(5, 10)).toBe('01-03');

  const c = await request(app).post('/admin/ad-leads').set(ADMIN).send({
    ...LEAD, metaLeadId: 'meta-dates-3', email: 'ava+test2310@example.com', firstName: 'Ava', service: 'garde', quand: 'plus_tard',
  }).expect(200);
  const r3 = await request(app).post(`/admin/ad-leads/${c.body.id}/publish`).set(ADMIN).send({}).expect(200);
  expect(r3.body.dates).toBeNull();
  const post3 = await Post.findById(r3.body.postId);
  expect(post3.startDate == null).toBe(true);
});

// 27/10 (SAM, décision de Daniel) — mesure (sans e-mail) puis remise en « non vérifié » des comptes
// pub sans preuve ; un compte d'avant la pub n'est jamais touché ; une vraie session = preuve datée.
test('proof2710 + unverify2710 : essai sans écriture, puis seuls les comptes sans preuve repassent non vérifiés', async () => {
  const ActivityEvent = require('../src/models/ActivityEvent');
  const mk = async (n, opts = {}) => {
    const { body: { id } } = await request(app).post('/admin/ad-leads').set(ADMIN).send({
      ...LEAD, metaLeadId: `meta-u${n}`, email: `u${n}.t2710@example.com`, firstName: `U${n}`,
    });
    await request(app).post(`/admin/ad-leads/${id}/publish`).set(ADMIN).send({}).expect(200);
    const o = await Owner.findOne({ email: `u${n}.t2710@example.com` });
    // ancien comportement (avant 27/10) : compte posé vérifié d'office par la publication
    await Owner.collection.updateOne({ _id: o._id }, { $set: { verified: true, adLeadAt: null, ...(opts.old ? { createdAt: new Date('2026-01-01') } : {}) } });
    if (opts.session) await ActivityEvent.create({ userId: String(o._id), at: new Date(), platform: 'web', appVersion: 'web', origin: 'web' });
    return o._id;
  };
  const none = await mk(1);
  const withSession = await mk(2, { session: true });
  const old = await mk(3, { old: true });
  const proof = await request(app).get('/admin/ad-leads/proof2710').set(ADMIN).expect(200);
  expect(JSON.stringify(proof.body)).not.toMatch(/@/); // jamais d'e-mail
  const dec = Object.fromEntries(proof.body.rows.filter((r) => [none, withSession, old].map(String).includes(r.ownerId)).map((r) => [r.ownerId, r.decision]));
  expect(dec[String(none)]).toBe('unverify');
  expect(dec[String(withSession)]).toBe('keep_proven');
  expect(dec[String(old)]).toBe('keep_preexisting');
  const dry = await request(app).post('/admin/ad-leads/unverify2710').set(ADMIN).send({}).expect(200);
  expect(dry.body.dryRun).toBe(true);
  expect((await Owner.findById(none)).verified).toBe(true); // rien écrit
  const run = await request(app).post('/admin/ad-leads/unverify2710').set(ADMIN).send({ dryRun: false }).expect(200);
  expect(run.body.dryRun).toBe(false);
  const [a, b, c] = await Promise.all([none, withSession, old].map((i) => Owner.findById(i)));
  expect(a.verified).toBe(false); expect(a.adLeadAt).toBeTruthy(); expect(a.emailProvenAt).toBeNull();
  expect(b.verified).toBe(true); expect(b.emailProvenAt).toBeTruthy(); expect(b.emailProofSource).toBe('session_web');
  expect(c.verified).toBe(true); expect(c.emailProvenAt).toBeNull();
});
