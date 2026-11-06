// 0611 (LEO) — lien par e-mail SANS mot de passe (POST /auth/owner-link) : compte existant → 1 e-mail
// avec le lien signé `k=` ; inconnu → 200 identique sans e-mail ; adresse de test → 200 sans e-mail ;
// limiteur 3 / 15 min (429) ; `next` hors liste → /posts ; script → 403. Vraie base Mongo en mémoire,
// vrais modèles Owner/Application/Post, vraie signature (utils/applicationLink3110) ; seul l'envoi
// d'e-mail et la couche push/socket sont simulés. Zone fictive −35/−30 pour le compte +test.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'a'.repeat(64);

const MAILS = [];
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async (to, subject, text, html) => { MAILS.push({ to, subject, text, html }); return { messageId: 'mock' }; }) };
});
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn(), sendEachForMulticast: jest.fn(async () => ({ successCount: 0, failureCount: 0, responses: [] })) }) }));
jest.mock('../src/sockets/emitter', () => ({ emitToUser: jest.fn(), isUserOnline: jest.fn(async () => false) }));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let routes; let Owner; let Application; let Post;
let owner; let appA; let appB; let testOwner; let testApp;
const UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1';
const post = (body, ua = UA, ip = '203.0.113.7') => {
  const r = request(app).post('/api/v1/auth/owner-link').set('X-Forwarded-For', ip).send(body);
  return ua ? r.set('User-Agent', ua) : r;
};
const settle = async () => { await Promise.all(routes.deps.pending.splice(0)); };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Application = require('../src/models/Application');
  Post = require('../src/models/Post');
  const Sitter = require('../src/models/Sitter');
  await Promise.all([Owner.init(), Application.init(), Post.init(), Sitter.init()]);
  owner = await Owner.create({ name: 'Karine Dupont', email: 'Karine.Magic0611@Example.com', password: 'motdepasse-long', appLocale: 'fr', verified: true, status: 'active' });
  const sitter = await Sitter.create({ name: 'Léa S', email: 'lea.magic0611@example.com', password: 'motdepasse-long' });
  const p1 = await Post.create({ ownerId: owner._id, postType: 'request', body: 'Garde de Rex', status: 'open', location: { city: 'Paris', lat: 48.85, lng: 2.35 } });
  appA = await Application.create({ ownerId: owner._id, sitterId: sitter._id, postId: p1._id, status: 'pending', createdAt: new Date(Date.now() - 3600 * 1000) });
  appB = await Application.create({ ownerId: owner._id, sitterId: sitter._id, postId: p1._id, status: 'pending', requestFingerprint: 'b' });
  // compte +test : demande en zone fictive (sinon jamais de jeton, règle d'équipe)
  testOwner = await Owner.create({ name: 'Test Owner', email: 'dadaciao84+testowner0611@gmail.com', password: 'motdepasse-long', appLocale: 'fr' });
  const p2 = await Post.create({ ownerId: testOwner._id, postType: 'request', body: 'Test', status: 'open', location: { city: 'Le Marais', lat: -35, lng: -30 } });
  testApp = await Application.create({ ownerId: testOwner._id, sitterId: sitter._id, postId: p2._id, status: 'pending' });
  routes = require('../src/routes/ownerMagicLink0611');
  routes.deps = { pending: [] };
  app = express();
  app.set('trust proxy', 1);
  app.use('/api/v1/auth/owner-link', routes);
}, 60000);

afterAll(async () => { await mongoose.disconnect(); await mongo.stop(); });
beforeEach(() => { MAILS.length = 0; routes.resetLimiter(); });

test('compte existant (casse différente) → 200 { ok } et UN e-mail avec le lien signé k= vers SA candidature', async () => {
  const r = await post({ email: '  KARINE.magic0611@example.com ', next: `/application/${appA._id}?choose=1&k=perime`, lang: 'fr' });
  expect(r.status).toBe(200); expect(r.body).toEqual({ ok: true });
  await settle();
  expect(MAILS).toHaveLength(1);
  expect(MAILS[0].to).toBe('karine.magic0611@example.com');
  expect(MAILS[0].subject).toBe('Ton lien pour voir tes candidats');
  const link = (MAILS[0].text.match(/https?:\/\/[^\s"<)]+/) || [])[0];
  expect(link).toBeTruthy();
  expect(link).toContain(`/application/${appA._id}?choose=1&k=`);
  expect(link).not.toContain('k=perime');
  // le jeton est bien celui que le site échange contre une session (même règle que les e-mails candidats)
  const token = decodeURIComponent(link.split('k=')[1]);
  const chk = await require('../src/utils/applicationLink3110').checkApplicationLink(token);
  expect(chk.ok).toBe(true); expect(chk.ownerId).toBe(String(owner._id)); expect(String(chk.application._id)).toBe(String(appA._id));
  // l'e-mail est en langage simple : un geste, rien à payer, bouton unique
  expect(MAILS[0].text).toContain('Bonjour Karine,');
  expect(MAILS[0].text).toContain('Pas de mot de passe, rien à payer pour regarder.');
  expect((MAILS[0].html.match(/display:inline-block;background:#C92A12/g) || []).length).toBe(1);
  expect(MAILS[0].html).toContain('Voir mes candidats');
});

test('adresse inconnue → même réponse 200 { ok }, aucun e-mail (jamais révéler un compte)', async () => {
  const r = await post({ email: 'personne.magic0611@example.com', next: '/posts' });
  expect(r.status).toBe(200); expect(r.body).toEqual({ ok: true });
  await settle();
  expect(MAILS).toHaveLength(0);
});

test('adresse de test (+test) → 200 sans e-mail', async () => {
  const r = await post({ email: 'dadaciao84+testowner0611@gmail.com', next: `/application/${testApp._id}` });
  expect(r.status).toBe(200); expect(r.body).toEqual({ ok: true });
  await settle();
  expect(MAILS).toHaveLength(0);
});

test('script (sans navigateur) → 403, e-mail mal formé → 400', async () => {
  expect((await post({ email: 'karine.magic0611@example.com', next: '/posts' }, 'curl/8.0')).status).toBe(403);
  expect((await post({ email: 'karine.magic0611@example.com', next: '/posts' }, '')).status).toBe(403);
  expect((await post({ email: 'pas-un-email', next: '/posts' })).status).toBe(400);
  await settle();
  expect(MAILS).toHaveLength(0);
});

test('limiteur : 3 envois / 15 min par e-mail (4e → 429), et par IP', async () => {
  for (let i = 0; i < 3; i += 1) expect((await post({ email: 'karine.magic0611@example.com', next: '/posts' }, UA, `198.51.100.${i}`)).status).toBe(200);
  expect((await post({ email: 'karine.magic0611@example.com', next: '/posts' }, UA, '198.51.100.9')).status).toBe(429);
  routes.resetLimiter();
  for (let i = 0; i < 3; i += 1) expect((await post({ email: `inconnu${i}.magic0611@example.com`, next: '/posts' }, UA, '198.51.100.50')).status).toBe(200);
  const r = await post({ email: 'inconnu9.magic0611@example.com', next: '/posts' }, UA, '198.51.100.50');
  expect(r.status).toBe(429); expect(r.body.code).toBe('TOO_MANY');
  await settle();
  expect(MAILS).toHaveLength(3); // les 3 premiers (compte connu) sont partis, pas le 4e
});

test('next hors liste → /posts, puis ramené à la candidature en attente la plus récente (lien k=)', async () => {
  expect(routes.cleanNext('https://evil.example/x')).toBe('/posts');
  expect(routes.cleanNext('//evil.example')).toBe('/posts');
  expect(routes.cleanNext('/admin')).toBe('/posts');
  expect(routes.cleanNext('/dashboard')).toBe('/dashboard');
  expect(routes.cleanNext('/chat?c=abc')).toBe('/chat?c=abc');
  expect(routes.cleanNext(`/application/${appA._id}?k=x&choose=1`)).toBe(`/application/${appA._id}?choose=1`);
  await post({ email: 'karine.magic0611@example.com', next: 'javascript:alert(1)' });
  await settle();
  expect(MAILS).toHaveLength(1);
  const link = (MAILS[0].text.match(/https?:\/\/[^\s"<)]+/) || [])[0];
  expect(link).toContain(`/application/${appB._id}?k=`); // la plus récente, pas appA
});

test("candidature d'un AUTRE propriétaire dans next → on vise la sienne, jamais celle de l'autre", async () => {
  await post({ email: 'karine.magic0611@example.com', next: `/application/${testApp._id}?choose=1` });
  await settle();
  expect(MAILS).toHaveLength(1);
  const link = (MAILS[0].text.match(/https?:\/\/[^\s"<)]+/) || [])[0];
  expect(link).not.toContain(String(testApp._id));
  expect(link).toContain(`/application/${appB._id}?choose=1&k=`);
});

test('compte en anglais (appLocale en) → e-mail en anglais ; /chat garde sa cible', async () => {
  await Owner.updateOne({ _id: owner._id }, { $set: { appLocale: 'en' } });
  await post({ email: 'karine.magic0611@example.com', next: '/chat?c=abc' });
  await settle();
  expect(MAILS).toHaveLength(1);
  expect(MAILS[0].subject).toBe('Your HoPetSit link');
  expect(MAILS[0].text).toContain('Hi Karine,');
  expect(MAILS[0].text).toContain('/chat?c=abc');
  await Owner.updateOne({ _id: owner._id }, { $set: { appLocale: 'fr' } });
});
