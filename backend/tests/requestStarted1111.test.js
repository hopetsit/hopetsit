// 11/11/2026 (BOB, ordre de Daniel) — « côté gardien et promeneur, sur la PawMap et le profil, les annonces dont la
// date de commencement est dépassée ne doivent plus s'afficher, et elles s'effacent 48 h après la fin, avec un
// historique ». Vraies routes, base Mongo en mémoire, positions en zone fictive (−35/−30).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
delete process.env.REQUEST_HIDE_STARTED_1111;
delete process.env.REQUEST_START_GRACE_H_1111;
delete process.env.POST_ARCHIVE_1111;

jest.mock('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: jest.fn(async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] })) }),
}));
jest.mock('../src/services/emailService', () => {
  const actual = jest.requireActual('../src/services/emailService');
  return { ...actual, sendEmail: jest.fn(async () => ({ messageId: 'capté' })) };
});

const request = require('supertest');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const H = 3600000;
const NOW = Date.now();
let mongo; let app; let Post; let Application; let PostArchive;
let owner; let sitter; let walker;
const tok = (id, role) => `Bearer ${jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' })}`;
const mk = async (body, extra) => (await Post.collection.insertOne({
  ownerId: owner, postType: 'request', status: 'open', hidden: false, body, serviceTypes: ['pet_sitting'],
  location: { city: 'Zone fictive', lat: -35, lng: -30 }, reservedBy: { bookingId: null }, createdAt: new Date(), ...extra,
})).insertedId;
const bodies = (arr) => (arr || []).map((p) => p.body).sort();
const feed = async (who = sitter, role = 'sitter', qs = '') => {
  const r = await request(app).get(`/api/v1/posts/requests${qs}`).set('Authorization', tok(who, role));
  expect(r.status).toBe(200);
  return bodies(r.body.posts);
};
const nearby = async (who = sitter, role = 'sitter') => {
  const r = await request(app).get('/api/v1/posts/requests/nearby?lat=-35&lng=-30&radiusKm=50').set('Authorization', tok(who, role));
  expect(r.status).toBe(200);
  return bodies(r.body.posts || r.body.requests || r.body.items);
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  app = require('../src/app');
  Post = require('../src/models/Post');
  Application = require('../src/models/Application');
  PostArchive = require('../src/models/PostArchive1111');
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  owner = (await Owner.collection.insertOne({ name: 'Nina Dupont', email: 'nina-1111@example.test', status: 'active', verified: true })).insertedId;
  sitter = (await Sitter.collection.insertOne({ name: 'Ines', email: 'ines-1111@example.test', status: 'active', verified: true, location: { city: 'Zone fictive', lat: -35, lng: -30 } })).insertedId;
  walker = (await Walker.collection.insertOne({ name: 'Wil', email: 'wil-1111@example.test', status: 'active', verified: true, location: { city: 'Zone fictive', lat: -35, lng: -30 } })).insertedId;

  await mk('A venir', { startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 72 * H) });
  // « pour aujourd'hui » : date enregistrée à minuit, déjà derrière nous de quelques heures
  await mk('Aujourd hui', { startDate: new Date(NOW - 8 * H), endDate: new Date(NOW - 8 * H) });
  await mk('Sans date', { startDate: null, endDate: null });
  await mk('Debut seul a venir', { startDate: new Date(NOW + 5 * H), endDate: null });
  // commencée avant-hier, finit dans un mois : AVANT visible, MAINTENANT cachée
  await mk('Commencee', { startDate: new Date(NOW - 50 * H), endDate: new Date(NOW + 700 * H) });
  await mk('Debut seul passe', { startDate: new Date(NOW - 40 * H), endDate: null });
  await mk('Reservee', { startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 72 * H), reservedBy: { bookingId: new mongoose.Types.ObjectId() } });
  await mk('Balade a venir', { serviceTypes: ['dog_walking'], startDate: new Date(NOW + 48 * H), endDate: new Date(NOW + 48 * H) });
  await mk('Balade commencee', { serviceTypes: ['dog_walking'], startDate: new Date(NOW - 50 * H), endDate: new Date(NOW + 100 * H) });
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
afterEach(() => { delete process.env.REQUEST_HIDE_STARTED_1111; delete process.env.REQUEST_START_GRACE_H_1111; delete process.env.POST_ARCHIVE_1111; });

test('règle pure : jour de début passé = fermée ; aujourd\'hui et sans date = ouverte', () => {
  const { isDateOpen } = require('../src/utils/openRequest1111');
  const now = new Date(NOW);
  expect(isDateOpen({ startDate: new Date(NOW - 8 * H), endDate: new Date(NOW - 8 * H) }, now)).toBe(true);
  expect(isDateOpen({ startDate: new Date(NOW - 29 * H), endDate: new Date(NOW + 500 * H) }, now)).toBe(true);
  expect(isDateOpen({ startDate: new Date(NOW - 31 * H), endDate: new Date(NOW + 500 * H) }, now)).toBe(false);
  expect(isDateOpen({ startDate: null, endDate: new Date(NOW - 31 * H) }, now)).toBe(false);
  expect(isDateOpen({ startDate: null, endDate: null }, now)).toBe(true);
  expect(isDateOpen({ startDate: 'pas une date' }, now)).toBe(true);
});

test('feed du gardien : une demande déjà commencée n\'est plus proposée, celle d\'aujourd\'hui l\'est', async () => {
  const f = await feed();
  expect(f).toEqual(expect.arrayContaining(['A venir', 'Aujourd hui', 'Sans date', 'Debut seul a venir']));
  expect(f).not.toContain('Commencee');
  expect(f).not.toContain('Debut seul passe');
  expect(f).not.toContain('Reservee');
});

test('feed du promeneur : même règle', async () => {
  const f = await feed(walker, 'walker');
  expect(f).toContain('Balade a venir');
  expect(f).not.toContain('Balade commencee');
});

test('PawMap (demandes proches) : gardien et promeneur ne voient plus les demandes commencées', async () => {
  const s = await nearby();
  expect(s).toEqual(expect.arrayContaining(['A venir', 'Aujourd hui', 'Sans date']));
  expect(s).not.toContain('Commencee');
  expect(s).not.toContain('Debut seul passe');
  const w = await nearby(walker, 'walker');
  expect(w).toContain('Balade a venir');
  expect(w).not.toContain('Balade commencee');
});

test('fiche d\'un propriétaire vue par un gardien : plus de demande commencée ni réservée', async () => {
  const f = await feed(sitter, 'sitter', `?ownerId=${owner}`);
  expect(f).toContain('A venir');
  expect(f).not.toContain('Commencee');
  expect(f).not.toContain('Reservee');
});

test('fiche du propriétaire dans l\'app et le site (/posts/requests/by-owner) : plus de demande commencée (ZOE)', async () => {
  const get = async () => {
    const r = await request(app).get(`/api/v1/posts/requests/by-owner/${owner}`).set('Authorization', tok(sitter, 'sitter'));
    expect(r.status).toBe(200);
    // cette route ne renvoie pas le texte : on retrouve chaque demande par son identifiant
    const ids = (r.body.posts || []).map((x) => String(x.id));
    const docs = await Post.find({ _id: { $in: ids } }).select('body').lean();
    return docs.map((d) => d.body).sort();
  };
  const b = await get();
  expect(b).toEqual(expect.arrayContaining(['A venir', 'Aujourd hui']));
  expect(b).not.toContain('Commencee');
  expect(b).not.toContain('Debut seul passe');
  process.env.REQUEST_HIDE_STARTED_1111 = 'off';
  expect(await get()).toContain('Commencee'); // coupe-circuit : ancienne règle
});

test('« mes annonces » : le propriétaire voit toujours TOUTES les siennes', async () => {
  const f = await feed(owner, 'owner', `?ownerId=${owner}`);
  expect(f).toEqual(expect.arrayContaining(['A venir', 'Commencee', 'Debut seul passe', 'Reservee', 'Aujourd hui']));
});

test('liste publique du site : même règle', async () => {
  const r = await request(app).get('/api/v1/posts/requests/public');
  expect(r.status).toBe(200);
  const b = bodies(r.body.requests);
  expect(b).toContain('Aujourd hui');
  expect(b).not.toContain('Commencee');
});

test('coupe-circuit REQUEST_HIDE_STARTED_1111=off : ancienne règle (date de fin)', async () => {
  process.env.REQUEST_HIDE_STARTED_1111 = 'off';
  const f = await feed();
  expect(f).toContain('Commencee'); // fin dans un mois : visible comme avant
  expect(f).not.toContain('Aujourd hui'); // ancien défaut : disparaissait dès minuit
  expect(await nearby()).toContain('Debut seul passe'); // la PawMap n'avait aucun filtre de date
  expect(await feed(sitter, 'sitter', `?ownerId=${owner}`)).toContain('Reservee');
});

test('marge réglable : REQUEST_START_GRACE_H_1111=0 cache dès l\'heure de début', async () => {
  process.env.REQUEST_START_GRACE_H_1111 = '0';
  expect(await feed()).not.toContain('Aujourd hui');
  process.env.REQUEST_START_GRACE_H_1111 = 'n\'importe quoi';
  expect(await feed()).toContain('Aujourd hui'); // valeur illisible → 30 h
});

test('effacement 48 h après la fin : une ligne d\'historique est écrite AVANT, sans e-mail', async () => {
  const { purgeFinishedPosts } = require('../src/services/postCleanupScheduler');
  const old = await mk('Finie il y a 3 jours', { startDate: new Date(NOW - 100 * H), endDate: new Date(NOW - 72 * H) });
  const startOnly = await mk('Debut seul il y a 3 jours', { startDate: new Date(NOW - 72 * H), endDate: null });
  await mk('Finie hier', { startDate: new Date(NOW - 40 * H), endDate: new Date(NOW - 20 * H) });
  await Application.collection.insertOne({ postId: old, sitterId: sitter, status: 'pending', createdAt: new Date() });
  await Application.collection.insertOne({ postId: old, sitterId: walker, status: 'pending', createdAt: new Date() });

  expect(await purgeFinishedPosts()).toBe(2);
  expect(await Post.countDocuments({ _id: { $in: [old, startOnly] } })).toBe(0);
  expect(await Post.countDocuments({ body: 'Finie hier' })).toBe(1); // moins de 48 h : encore là
  expect(await Post.countDocuments({ body: 'Commencee' })).toBe(1); // commencée mais pas finie : pas effacée
  expect(await Application.countDocuments({ postId: old })).toBe(0);

  const a = await PostArchive.findOne({ postId: old }).lean();
  expect(a).toBeTruthy();
  expect(a.ownerFirstName).toBe('Nina'); // prénom seul
  expect(a.city).toBe('Zone fictive');
  expect(a.applicationsCount).toBe(2);
  expect(a.reason).toBe('date_passee');
  expect(a.isTest).toBe(true); // zone fictive / e-mail de test
  expect(JSON.stringify(a)).not.toMatch(/@|Dupont/);
  expect(await PostArchive.countDocuments({ postId: startOnly })).toBe(1);

  // relancer ne crée pas de doublon
  expect(await purgeFinishedPosts()).toBe(0);
  expect(await PostArchive.countDocuments({})).toBe(2);
});

test('début seul passé MAIS réservée : jamais effacée par la nouvelle clause (ZOE)', async () => {
  const { purgeFinishedPosts } = require('../src/services/postCleanupScheduler');
  const id = await mk('Debut seul reservee', { startDate: new Date(NOW - 72 * H), endDate: null, reservedBy: { bookingId: new mongoose.Types.ObjectId() } });
  await Application.collection.insertOne({ postId: id, sitterId: sitter, status: 'accepted', createdAt: new Date() });
  expect(await purgeFinishedPosts()).toBe(0);
  expect(await Post.countDocuments({ _id: id })).toBe(1);
  expect(await Application.countDocuments({ postId: id })).toBe(1);
});

test('historique : extrait de texte court (120 caractères au plus)', async () => {
  const { purgeFinishedPosts } = require('../src/services/postCleanupScheduler');
  const id = await mk('x'.repeat(400), { startDate: new Date(NOW - 100 * H), endDate: new Date(NOW - 72 * H) });
  expect(await purgeFinishedPosts()).toBe(1);
  expect((await PostArchive.findOne({ postId: id }).lean()).body).toHaveLength(120);
});

test('historique impossible à écrire : la demande n\'est PAS effacée', async () => {
  const sched = require('../src/services/postCleanupScheduler');
  const id = await mk('Finie, archive en panne', { startDate: new Date(NOW - 100 * H), endDate: new Date(NOW - 72 * H) });
  const spy = jest.spyOn(PostArchive, 'updateOne').mockRejectedValue(new Error('panne'));
  expect(await sched.purgeFinishedPosts()).toBe(0);
  expect(await Post.countDocuments({ _id: id })).toBe(1);
  spy.mockRestore();
  expect(await sched.purgeFinishedPosts()).toBe(1);
});

test('coupe-circuit POST_ARCHIVE_1111=off : effacement comme avant, sans historique ni « début seul »', async () => {
  process.env.POST_ARCHIVE_1111 = 'off';
  const { purgeFinishedPosts } = require('../src/services/postCleanupScheduler');
  const before = await PostArchive.countDocuments({});
  const a = await mk('Finie (ancien mode)', { startDate: new Date(NOW - 100 * H), endDate: new Date(NOW - 72 * H) });
  const b = await mk('Debut seul (ancien mode)', { startDate: new Date(NOW - 72 * H), endDate: null });
  expect(await purgeFinishedPosts()).toBe(1);
  expect(await Post.countDocuments({ _id: a })).toBe(0);
  expect(await Post.countDocuments({ _id: b })).toBe(1);
  expect(await PostArchive.countDocuments({})).toBe(before);
});
