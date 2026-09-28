// 28/09/2026 (NEO) — « Demander à Sasha » : une demande peut viser UN
// prestataire (targetProvider). Il est prévenu en premier, avec une
// notification distincte (new_request_for_you), puis la ville comme avant,
// et jamais deux fois. Ciblage invalide → ignoré sans casser la publication.
// VRAIE base Mongo en mémoire, vrais gestionnaires, zone fictive
// (lat -35 / lng -30), aucun réseau (géocodage simulé).
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/services/translationService', () => ({
  translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })),
}));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({
  uploadMedia: jest.fn(async () => ({ url: 'https://example.test/p.jpg', secure_url: 'https://example.test/p.jpg', public_id: 'p', publicId: 'p' })),
}));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/utils/geocodeCity', () => {
  const actual = jest.requireActual('../src/utils/geocodeCity');
  return { ...actual, geocodeCity: jest.fn(async () => null) };
});

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { sendNotification } = require('../src/services/notificationSender');
const { parseTargetProvider, publicTargetProvider } = require('../src/utils/targetProvider2809');

let mongo;
let Post;
let postController;
let ownerId;
let sitterA; // ciblé
let sitterB; // même ville, pas ciblé
let walkerC; // promeneur de la ville

const mockRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn((b) => { res.body = b; return res; });
  return res;
};

// notifyNearbyProviders tourne dans setImmediate + requêtes Mongo : on laisse
// la boucle d'événements se vider avant de compter les envois.
const flush = () => new Promise((r) => setTimeout(r, 250));

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post');
  const Owner = require('../src/models/Owner');
  const Sitter = require('../src/models/Sitter');
  const Walker = require('../src/models/Walker');
  postController = require('../src/controllers/postController');
  const o = await Owner.collection.insertOne({
    name: 'Marie', email: 'marie2809@example.test', language: 'fr', currency: 'EUR',
    location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
  });
  ownerId = o.insertedId.toString();
  const a = await Sitter.collection.insertOne({
    name: 'Sasha B.', email: 'sasha2809@example.test',
    location: { type: 'Point', coordinates: [-30.01, -35], city: 'Zone test' },
  });
  sitterA = a.insertedId.toString();
  const b = await Sitter.collection.insertOne({
    name: 'Nina', email: 'nina2809@example.test',
    location: { type: 'Point', coordinates: [-30.02, -35], city: 'Zone test' },
  });
  sitterB = b.insertedId.toString();
  const c = await Walker.collection.insertOne({
    name: 'Paul', email: 'paul2809@example.test',
    location: { type: 'Point', coordinates: [-30.03, -35], city: 'Zone test' },
  });
  walkerC = c.insertedId.toString();
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

beforeEach(() => { sendNotification.mockClear(); });

const publish = async (extra) => {
  const res = mockRes();
  await postController.createPost({ user: { id: ownerId, role: 'owner' }, body: {
    body: 'Garde de mon chat une semaine', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home',
    serviceLocation: 'at_owner',
    startDate: '2026-12-01T09:00:00.000Z', endDate: '2026-12-08T09:00:00.000Z',
    location: { city: 'Zone test', lat: -35, lng: -30 }, ...extra,
  } }, res);
  await flush();
  return res;
};

const sentTo = (type) => sendNotification.mock.calls
  .map((c) => c[0]).filter((n) => n.type === type).map((n) => `${n.role}:${n.userId}`);

describe('parseTargetProvider — règle pure', () => {
  const id = 'a'.repeat(24);
  test('objet ou chaîne JSON (multipart), rôle en minuscules', () => {
    expect(parseTargetProvider({ role: 'sitter', id })).toEqual({ role: 'sitter', id });
    expect(parseTargetProvider(JSON.stringify({ role: 'Walker', id }))).toEqual({ role: 'walker', id });
  });
  test('absent, rôle inconnu, id mal formé, JSON cassé → null', () => {
    expect(parseTargetProvider(undefined)).toBeNull();
    expect(parseTargetProvider('')).toBeNull();
    expect(parseTargetProvider({ role: 'owner', id })).toBeNull();
    expect(parseTargetProvider({ role: 'sitter', id: 'abc' })).toBeNull();
    expect(parseTargetProvider({ role: 'sitter' })).toBeNull();
    expect(parseTargetProvider('{pas du json')).toBeNull();
    expect(parseTargetProvider(['sitter', id])).toBeNull();
  });
  test('publicTargetProvider : { role, id } ou null', () => {
    expect(publicTargetProvider({ targetProvider: { role: 'sitter', id: new mongoose.Types.ObjectId(id) } }))
      .toEqual({ role: 'sitter', id });
    expect(publicTargetProvider({ targetProvider: { role: null, id: null } })).toBeNull();
    expect(publicTargetProvider({})).toBeNull();
  });
});

describe('POST /posts avec targetProvider — 28/09', () => {
  test('le ciblé reçoit « vous a choisi » en premier, les autres la diffusion ville, jamais deux fois', async () => {
    const res = await publish({ targetProvider: { role: 'sitter', id: sitterA } });
    expect(res.status).toHaveBeenCalledWith(201);
    // Enregistré et renvoyé par sanitizePost.
    expect(res.body.post.targetProvider).toEqual({ role: 'sitter', id: sitterA });
    const stored = await Post.findById(res.body.post.id || res.body.post._id).lean();
    expect(String(stored.targetProvider.id)).toBe(sitterA);
    expect(stored.targetProvider.role).toBe('sitter');

    // Notification distincte, une seule fois, pour le ciblé.
    expect(sentTo('new_request_for_you')).toEqual([`sitter:${sitterA}`]);
    const chosen = sendNotification.mock.calls.map((c) => c[0]).find((n) => n.type === 'new_request_for_you');
    expect(chosen.data.ownerName).toBe('Marie');
    expect(chosen.data.postId).toBe(String(stored._id));
    // Le ciblé est prévenu AVANT la diffusion ville.
    expect(sendNotification.mock.calls[0][0].type).toBe('new_request_for_you');

    // Diffusion ville : Nina oui, Sasha NON (déjà prévenue), Paul non (promeneur, demande de garde).
    const nearby = sentTo('new_request_nearby');
    expect(nearby).toContain(`sitter:${sitterB}`);
    expect(nearby).not.toContain(`sitter:${sitterA}`);
    expect(nearby).not.toContain(`walker:${walkerC}`);
  });

  test('un promeneur ciblé par une demande de garde est quand même prévenu, dans son rôle', async () => {
    await publish({ targetProvider: { role: 'walker', id: walkerC } });
    expect(sentTo('new_request_for_you')).toEqual([`walker:${walkerC}`]);
    expect(sentTo('new_request_nearby')).toEqual(expect.arrayContaining([`sitter:${sitterA}`, `sitter:${sitterB}`]));
  });

  test('chaîne JSON (multipart) acceptée', async () => {
    const res = await publish({ targetProvider: JSON.stringify({ role: 'sitter', id: sitterB }) });
    expect(res.body.post.targetProvider).toEqual({ role: 'sitter', id: sitterB });
    expect(sentTo('new_request_for_you')).toEqual([`sitter:${sitterB}`]);
  });

  test('id inexistant, rôle inconnu ou id mal formé → ignoré, la demande part quand même à la ville', async () => {
    for (const bad of [
      { role: 'sitter', id: new mongoose.Types.ObjectId().toString() },
      { role: 'owner', id: sitterA },
      { role: 'sitter', id: 'pas-un-id' },
      'n importe quoi',
    ]) {
      sendNotification.mockClear();
      const res = await publish({ targetProvider: bad });
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.body.post.targetProvider).toBeNull();
      expect(sentTo('new_request_for_you')).toEqual([]);
      expect(sentTo('new_request_nearby')).toEqual(expect.arrayContaining([`sitter:${sitterA}`, `sitter:${sitterB}`]));
    }
  });

  test('sans targetProvider : comportement d avant, rien de nouveau', async () => {
    const res = await publish({});
    expect(res.body.post.targetProvider).toBeNull();
    expect(sentTo('new_request_for_you')).toEqual([]);
    expect(sentTo('new_request_nearby').length).toBe(2);
  });

  test('un compte +test ne prévient personne, ciblé compris', async () => {
    const Owner = require('../src/models/Owner');
    const { encrypt } = require('../src/utils/encryption');
    const t = await Owner.collection.insertOne({
      name: 'Testeur', email: encrypt('dadaciao84+testcible@gmail.com'), language: 'fr',
      location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
    });
    const res = mockRes();
    await postController.createPost({ user: { id: t.insertedId.toString(), role: 'owner' }, body: {
      body: 'Test cible', serviceTypes: ['house_sitting'], houseSittingVenue: 'owners_home', serviceLocation: 'at_owner',
      location: { city: 'Zone test', lat: -35, lng: -30 }, targetProvider: { role: 'sitter', id: sitterA },
    } }, res);
    await flush();
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.body.post.targetProvider).toEqual({ role: 'sitter', id: sitterA });
    expect(sendNotification).not.toHaveBeenCalled();
  });
});

describe('textes de la notification new_request_for_you — 9 langues', () => {
  const fs = require('fs');
  const path = require('path');
  test.each(['fr', 'en', 'es', 'de', 'it', 'pt', 'pl', 'ja', 'ko'])('%s : titre, corps, e-mail, avec {{ownerName}}', (lang) => {
    const cat = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'src', 'locales', lang, 'notifications.json'), 'utf8'));
    const n = cat.new_request_for_you;
    expect(n).toBeTruthy();
    for (const k of ['title', 'body', 'emailSubject', 'emailBody']) expect(typeof n[k]).toBe('string');
    expect(n.title).toContain('{{ownerName}}');
    expect(n.body).toContain('{{city}}');
    expect(n.emailBody).toContain('{{emailLink}}');
  });
  test('catégorie « bookings » et lien vers l annonce', () => {
    const { categoryForType } = jest.requireActual('../src/services/notificationSender');
    const { buildAppRoute } = require('../src/utils/emailLinkBuilder');
    expect(categoryForType('new_request_for_you')).toBe('bookings');
    const pid = 'b'.repeat(24);
    expect(buildAppRoute('new_request_for_you', { postId: pid })).toBe(`/post/${pid}`);
  });
});
