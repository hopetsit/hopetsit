// 639 (BOB, lot D — validé par Daniel) — contrat serveur du formulaire de demande :
//   · `foodProvided` (« Je fournis la nourriture ») : true / false / null sur Post, écrit à la création ET à la
//     modification, renvoyé par les sorties des demandes ; coupe-circuit POST_FOOD_PROVIDED=off ;
//   · `breed` FACULTATIVE de la demande rapide (formulaire du site, chemin pub) → `Pet.breed` de l'animal créé ;
//     coupe-circuit QUICK_REQUEST_BREED=off.
// VRAIE base Mongo EN MÉMOIRE (jamais la production), vrais gestionnaires, zone fictive (lat −35 / lng −30),
// aucun réseau, aucun e-mail réel, adresses en example.test.
process.env.DUPLICATE_REQUEST_CHECK = 'off';
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => l) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/emailService', () => ({
  sendEmail: jest.fn(async () => ({ messageId: 'mock' })),
  sendTemplatedEmail: jest.fn(async () => ({})),
}));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { const id = req.headers['x-test-user']; if (!id) return res.status(401).json({ error: 'auth' }); req.user = { id, role: req.headers['x-test-role'] || 'owner' }; return next(); },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { resolveExtras, publicExtras, extrasSentence } = require('../src/utils/postExtras1011');
const { cleanBreed, ensureOwnerPet, BREED_MAX } = require('../src/utils/postPet612');
const { sanitizePost } = require('../src/utils/sanitize');

let mongo; let app; let Post; let Pet; let AdLead; let Owner; let postController; let ownerId;
const D = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const BASE = {
  email: 'base.demande639@example.test', firstName: 'Test', service: 'garde', animal: 'chien',
  city: 'Zone test', postalCode: '75015', lat: -35.02, lng: -30.03, country: 'FR', lang: 'fr', startDate: D(10), endDate: D(11),
  campaign: 'paris_owners', page: '/demande',
};
const site = (body) => request(app).post('/ad-leads/site').send(body);
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
const confirm = async (id, body = {}) => (await request(app).post(`/ad-leads/${id}/confirm`).set(BROWSER).send(body).expect(200)).body;
const mockRes = () => {
  const res = {};
  res.status = jest.fn(() => res);
  res.json = jest.fn((b) => { res.body = b; return res; });
  return res;
};
let seq = 0;
const publish = async (extra = {}) => {
  seq += 1;
  const res = mockRes();
  await postController.createPost({ user: { id: ownerId, role: 'owner' }, body: {
    body: `Demande 639 numéro ${seq}`, serviceTypes: ['dog_walking'], serviceLocation: 'pickup',
    startDate: '2026-12-01T09:00:00.000Z', endDate: '2026-12-01T10:00:00.000Z',
    location: { city: 'Zone test', lat: -35, lng: -30 }, ...extra,
  } }, res);
  return res;
};
const edit = async (id, body) => {
  const res = mockRes();
  await postController.updatePost({ user: { id: ownerId, role: 'owner' }, params: { id: String(id) }, body }, res);
  return res;
};

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post'); AdLead = require('../src/models/AdLead2210');
  Pet = require('../src/models/Pet'); Owner = require('../src/models/Owner');
  await Promise.all([Owner.init(), Post.init(), AdLead.init(), Pet.init()]);
  postController = require('../src/controllers/postController');
  const r = await Owner.collection.insertOne({
    name: 'Demande 639', email: 'proprio.demande639@example.test', language: 'fr', currency: 'EUR',
    location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
  });
  ownerId = r.insertedId.toString();
  app = express(); app.use(express.json());
  app.use('/ad-leads', require('../src/routes/adLeads2210'));
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
afterEach(() => { delete process.env.POST_FOOD_PROVIDED; delete process.env.QUICK_REQUEST_BREED; });

describe('639 — foodProvided : règle pure (postExtras1011)', () => {
  test('écriture : true / false lus sous toutes leurs formes, absent ou illisible → rien, null explicite → non précisé', () => {
    expect(resolveExtras({ foodProvided: true })).toEqual({ foodProvided: true });
    expect(resolveExtras({ foodProvided: 'false' })).toEqual({ foodProvided: false });
    expect(resolveExtras({ foodProvided: '1' })).toEqual({ foodProvided: true });
    expect(resolveExtras({ foodProvided: 0 })).toEqual({ foodProvided: false });
    expect(resolveExtras({})).toEqual({});
    expect(resolveExtras({ foodProvided: 'peut-être' })).toEqual({});
    expect(resolveExtras({ foodProvided: undefined })).toEqual({});
    expect(resolveExtras({ foodProvided: null })).toEqual({ foodProvided: null });
    // les champs de 1011 ne bougent pas
    expect(resolveExtras({ timeFrom: '10:00', timeTo: '18h30', ownerNoCar: 'true', foodProvided: true }))
      .toEqual({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true, foodProvided: true });
  });

  test('lecture : toujours true / false / null', () => {
    expect(publicExtras({ foodProvided: true }).foodProvided).toBe(true);
    expect(publicExtras({ foodProvided: false }).foodProvided).toBe(false);
    expect(publicExtras({}).foodProvided).toBeNull();
    expect(publicExtras(null).foodProvided).toBeNull();
    expect(publicExtras({ foodProvided: 'true' }).foodProvided).toBeNull(); // jamais une valeur douteuse
    expect(publicExtras({ timeFrom: '10:00', ownerNoCar: true, foodProvided: false }))
      .toEqual({ timeFrom: '10:00', timeTo: '', ownerNoCar: true, foodProvided: false });
  });

  test('phrase pour une ancienne app (fr / en), seulement si le propriétaire a répondu', () => {
    expect(extrasSentence({ food: true }, 'fr')).toBe('Je fournis la nourriture.');
    expect(extrasSentence({ food: true }, 'en')).toBe('I provide the food.');
    expect(extrasSentence({ food: false }, 'fr')).toBe('Nourriture à prévoir.');
    expect(extrasSentence({ food: false }, 'en')).toBe('Food to be provided by the sitter.');
    expect(extrasSentence({ food: null }, 'fr')).toBe('');
    expect(extrasSentence({}, 'fr')).toBe('');
    expect(extrasSentence({ timeFrom: '10:00', timeTo: '18:30', noCar: true, food: true }, 'fr'))
      .toBe("Horaires : de 10 h à 18 h 30. Je fournis la nourriture. Je n'ai pas de voiture.");
    // sans nourriture : exactement la phrase d'avant
    expect(extrasSentence({ timeFrom: '10:00', timeTo: '18:30', noCar: true }, 'fr')).toBe("Horaires : de 10 h à 18 h 30. Je n'ai pas de voiture.");
  });

  test('coupe-circuit POST_FOOD_PROVIDED=off : ignoré à l’écriture, null à la lecture, pas de phrase', () => {
    process.env.POST_FOOD_PROVIDED = 'OFF';
    expect(resolveExtras({ foodProvided: true, ownerNoCar: true })).toEqual({ ownerNoCar: true });
    expect(publicExtras({ foodProvided: true }).foodProvided).toBeNull();
    expect(extrasSentence({ food: true, noCar: true }, 'fr')).toBe("Je n'ai pas de voiture.");
    expect(sanitizePost({ _id: 'x', foodProvided: true }).foodProvided).toBeNull();
    delete process.env.POST_FOOD_PROVIDED;
    expect(sanitizePost({ _id: 'x', foodProvided: true }).foodProvided).toBe(true);
    expect(sanitizePost({ _id: 'x' }).foodProvided).toBeNull();
  });
});

describe('639 — foodProvided : création et modification d’une demande (vrai contrôleur)', () => {
  test('création avec true, avec false, sans le champ (ancienne app)', async () => {
    const a = await publish({ foodProvided: true });
    expect(a.status).toHaveBeenCalledWith(201);
    expect(a.body.post.foodProvided).toBe(true);
    expect((await Post.findById(a.body.post.id).lean()).foodProvided).toBe(true);

    const b = await publish({ foodProvided: false });
    expect(b.body.post.foodProvided).toBe(false);
    expect((await Post.findById(b.body.post.id).lean()).foodProvided).toBe(false);

    const c = await publish({});
    expect(c.status).toHaveBeenCalledWith(201);
    expect(c.body.post.foodProvided).toBeNull();
    expect((await Post.findById(c.body.post.id).lean()).foodProvided == null).toBe(true);

    const d = await publish({ foodProvided: 'peut-être' }); // illisible : jamais une erreur
    expect(d.status).toHaveBeenCalledWith(201);
    expect(d.body.post.foodProvided).toBeNull();
  });

  test('les champs de 1011 sont écrits exactement comme avant, avec ou sans nourriture', async () => {
    const a = await publish({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true, foodProvided: true });
    const doc = await Post.findById(a.body.post.id).lean();
    expect(doc).toMatchObject({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true, foodProvided: true });
    const b = await publish({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true });
    const doc2 = await Post.findById(b.body.post.id).lean();
    expect(doc2).toMatchObject({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true });
    expect(doc2.foodProvided == null).toBe(true);
  });

  test('modification : envoyé = modifié, absent = inchangé, null = non précisé', async () => {
    const a = await publish({ foodProvided: true });
    const id = a.body.post.id;
    const r1 = await edit(id, { notes: 'Une précision' }); // sans le champ
    expect(r1.body.post.foodProvided).toBe(true);
    expect((await Post.findById(id).lean()).foodProvided).toBe(true);
    const r2 = await edit(id, { foodProvided: false });
    expect(r2.body.post.foodProvided).toBe(false);
    expect((await Post.findById(id).lean()).foodProvided).toBe(false);
    const r3 = await edit(id, { foodProvided: 'bof' }); // illisible → inchangé
    expect(r3.body.post.foodProvided).toBe(false);
    const r4 = await edit(id, { foodProvided: null });
    expect(r4.body.post.foodProvided).toBeNull();
    expect((await Post.findById(id).lean()).foodProvided == null).toBe(true);
    // une demande publiée sans le champ peut le recevoir ensuite
    const b = await publish({});
    const r5 = await edit(b.body.post.id, { foodProvided: true });
    expect(r5.body.post.foodProvided).toBe(true);
  });

  test('coupe-circuit : rien écrit à la création ni à la modification, null en sortie même si la base contient une valeur', async () => {
    const before = await publish({ foodProvided: true }); // écrit AVANT la coupure
    process.env.POST_FOOD_PROVIDED = 'off';
    const a = await publish({ foodProvided: true, ownerNoCar: true });
    expect(a.status).toHaveBeenCalledWith(201);
    expect(a.body.post.foodProvided).toBeNull();
    const doc = await Post.findById(a.body.post.id).lean();
    expect(doc.foodProvided == null).toBe(true);
    expect(doc.ownerNoCar).toBe(true); // le reste n'est pas touché
    const r = await edit(a.body.post.id, { foodProvided: false });
    expect(r.body.post.foodProvided).toBeNull();
    expect((await Post.findById(a.body.post.id).lean()).foodProvided == null).toBe(true);
    // une valeur déjà en base n'est ni effacée ni montrée
    const r2 = await edit(before.body.post.id, { notes: 'x' });
    expect(r2.body.post.foodProvided).toBeNull();
    expect((await Post.findById(before.body.post.id).lean()).foodProvided).toBe(true);
    delete process.env.POST_FOOD_PROVIDED;
    expect(sanitizePost(await Post.findById(before.body.post.id)).foodProvided).toBe(true);
  });
});

describe('639 — race facultative : nettoyage (cleanBreed)', () => {
  test('texte simple gardé ; balises, chevrons, retours à la ligne retirés ; 60 caractères au plus', () => {
    expect(BREED_MAX).toBe(60);
    expect(cleanBreed('Golden retriever')).toBe('Golden retriever');
    expect(cleanBreed('  Berger   australien \n')).toBe('Berger australien');
    expect(cleanBreed('<b>Labrador</b>')).toBe('Labrador');
    expect(cleanBreed('<script>alert(1)</script>Carlin')).toBe('alert(1) Carlin');
    expect(cleanBreed('Chat > chien <')).toBe('Chat chien');
    expect(cleanBreed('Shiba\u0000 Inu\tnoir')).toBe('Shiba Inu noir');
    expect(cleanBreed('柴犬')).toBe('柴犬');
    const long = cleanBreed('a'.repeat(200));
    expect(long).toHaveLength(60);
    expect(cleanBreed(`${'ab '.repeat(40)}`).length).toBeLessThanOrEqual(60);
    expect(cleanBreed(cleanBreed('<i>Épagneul breton</i>'))).toBe('Épagneul breton'); // stable
  });
  test('absente ou pas une chaîne → vide ; coupe-circuit QUICK_REQUEST_BREED=off → vide', () => {
    for (const v of [undefined, null, '', '   ', 12, true, {}, ['Labrador'], '<br>']) expect(cleanBreed(v)).toBe('');
    process.env.QUICK_REQUEST_BREED = 'off';
    expect(cleanBreed('Labrador')).toBe('');
    delete process.env.QUICK_REQUEST_BREED;
    expect(cleanBreed('Labrador')).toBe('Labrador');
  });
});

describe('639 — race : fiche animal créée par une demande sans animal (ensureOwnerPet)', () => {
  const newOwner = async (tag) => String((await Owner.collection.insertOne({
    name: `Race ${tag}`, email: `race-${tag}.demande639@example.test`, language: 'fr',
    location: { type: 'Point', coordinates: [-30, -35], city: 'Zone test' },
  })).insertedId);

  test('propriétaire sans animal : la fiche créée porte la race ; sans race → comme avant', async () => {
    const o1 = await newOwner('a');
    const r = await ensureOwnerPet({ ownerId: o1, animalTypes: ['dog'], breed: ' <b>Golden</b> retriever ' });
    expect(r.created).toBe(true);
    const pet = await Pet.findById(r.id).lean();
    expect(pet).toMatchObject({ category: 'dog', autoCreated: true, breed: 'Golden retriever', petName: 'Chien' });
    const o2 = await newOwner('b');
    const r2 = await ensureOwnerPet({ ownerId: o2, animalTypes: ['cat'] });
    const pet2 = await Pet.findById(r2.id).lean();
    expect(pet2).toMatchObject({ category: 'cat', autoCreated: true, petName: 'Chat' });
    expect(pet2.breed || '').toBe('');
  });

  test('fiche faite par le propriétaire : JAMAIS modifiée ; fiche minimale sans race : complétée ; race déjà dite : gardée', async () => {
    const o = await newOwner('c');
    const mine = await Pet.create({ ownerId: o, petName: 'Rex', category: 'dog' });
    const r = await ensureOwnerPet({ ownerId: o, animalTypes: ['dog'], breed: 'Labrador' });
    expect(r).toEqual({ id: String(mine._id), created: false });
    expect((await Pet.findById(mine._id).lean()).breed || '').toBe('');
    expect(await Pet.countDocuments({ ownerId: o })).toBe(1);

    const o2 = await newOwner('d');
    const first = await ensureOwnerPet({ ownerId: o2, animalTypes: ['dog'] }); // 1re demande sans race
    await ensureOwnerPet({ ownerId: o2, animalTypes: ['dog'], breed: 'Beagle' }); // 2e demande avec race
    expect((await Pet.findById(first.id).lean()).breed).toBe('Beagle');
    await ensureOwnerPet({ ownerId: o2, animalTypes: ['dog'], breed: 'Carlin' }); // déjà une race : inchangée
    expect((await Pet.findById(first.id).lean()).breed).toBe('Beagle');
    await ensureOwnerPet({ ownerId: o2, animalTypes: ['cat'], breed: 'Siamois' }); // autre espèce : inchangée
    expect((await Pet.findById(first.id).lean()).breed).toBe('Beagle');
    expect(await Pet.countDocuments({ ownerId: o2 })).toBe(1);
  });

  test('createPost (corps `breed`) : écrit sur l’animal créé, absent = rien, coupe-circuit = rien', async () => {
    const o = await newOwner('e');
    const res = mockRes();
    await postController.createPost({ user: { id: o, role: 'owner' }, body: {
      body: 'Demande rapide avec race', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', animalTypes: ['cat'], animalCount: 1,
      startDate: '2026-12-05T09:00:00.000Z', endDate: '2026-12-05T10:00:00.000Z',
      location: { city: 'Zone test', lat: -35, lng: -30 }, breed: 'Maine coon',
    } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    const post = await Post.findById(res.body.post.id).lean();
    expect(post.petIds).toHaveLength(1);
    expect(await Pet.findById(post.petIds[0]).lean()).toMatchObject({ category: 'cat', autoCreated: true, breed: 'Maine coon' });

    process.env.QUICK_REQUEST_BREED = 'off';
    const o2 = await newOwner('f');
    const res2 = mockRes();
    await postController.createPost({ user: { id: o2, role: 'owner' }, body: {
      body: 'Demande rapide, race coupée', serviceTypes: ['dog_walking'], serviceLocation: 'pickup', animalTypes: ['dog'], animalCount: 1,
      startDate: '2026-12-05T09:00:00.000Z', endDate: '2026-12-05T10:00:00.000Z',
      location: { city: 'Zone test', lat: -35, lng: -30 }, breed: 'Teckel',
    } }, res2);
    expect(res2.status).toHaveBeenCalledWith(201);
    const post2 = await Post.findById(res2.body.post.id).lean();
    expect((await Pet.findById(post2.petIds[0]).lean()).breed || '').toBe('');
  });
});

describe('639 — chemin pub / formulaire du site (POST /ad-leads/site → confirmation)', () => {
  test('annonce construite : nourriture et race passent, absentes = exactement comme avant', () => {
    const { postInputFor } = require('../src/routes/adLeads2210');
    const lead = { lang: 'fr', animal: 'chien', service: 'garde', quand: 'plus_tard', city: 'Zone test', foodProvided: true, breed: ' <i>Beagle</i> ', noCar: true };
    const a = postInputFor(lead, 'at_owner');
    expect(a.foodProvided).toBe(true);
    expect(a.breed).toBe('Beagle');
    expect(a.body).toBe("Je cherche une garde pour mon chien. Je fournis la nourriture. Je n'ai pas de voiture.");
    const b = postInputFor({ lang: 'en', animal: 'chat', service: 'garde', quand: 'plus_tard', city: 'Zone test', foodProvided: false }, 'at_owner');
    expect(b.foodProvided).toBe(false);
    expect(b.body).toBe("I'm looking for a pet sitter for my cat. Food to be provided by the sitter.");
    const c = postInputFor({ lang: 'en', animal: 'chat', service: 'garde', quand: 'plus_tard', city: 'Zone test' }, 'at_owner');
    expect(c.body).toBe("I'm looking for a pet sitter for my cat.");
    expect('foodProvided' in c).toBe(false);
    expect('breed' in c).toBe(false);
  });

  test('formulaire avec nourriture + race : gardées sur le contact, puis sur la demande et sur l’animal créé', async () => {
    const r = await site({ ...BASE, email: 'avec.demande639@example.test', foodProvided: true, breed: 'Golden <b>retriever</b>' }).expect(202);
    const lead = await AdLead.findById(r.body.id).lean();
    expect(lead.foodProvided).toBe(true);
    expect(lead.breed).toBe('Golden retriever');
    const c = await confirm(r.body.id);
    const post = await Post.findById(c.postId).lean();
    expect(post.foodProvided).toBe(true);
    expect(post.body).toMatch(/Je fournis la nourriture\./);
    expect(post.petIds).toHaveLength(1);
    expect(await Pet.findById(post.petIds[0]).lean()).toMatchObject({ category: 'dog', autoCreated: true, breed: 'Golden retriever' });
    expect(sanitizePost(await Post.findById(c.postId)).foodProvided).toBe(true);
  });

  test('« nourriture à prévoir » (false) : écrit tel quel', async () => {
    const r = await site({ ...BASE, email: 'false.demande639@example.test', animal: 'chat', foodProvided: 'false' }).expect(202);
    expect((await AdLead.findById(r.body.id).lean()).foodProvided).toBe(false);
    const c = await confirm(r.body.id);
    const post = await Post.findById(c.postId).lean();
    expect(post.foodProvided).toBe(false);
    expect(post.body).toMatch(/Nourriture à prévoir\./);
  });

  test('formulaire SANS ces champs (site actuel) : rien ne change', async () => {
    const r = await site({ ...BASE, email: 'sans.demande639@example.test' }).expect(202);
    const lead = await AdLead.findById(r.body.id).lean();
    expect(lead.foodProvided == null).toBe(true);
    expect(lead.breed || '').toBe('');
    const c = await confirm(r.body.id);
    const post = await Post.findById(c.postId).lean();
    expect(post.foodProvided == null).toBe(true);
    expect(post.body).toBe('Je cherche une garde pour mon chien.');
    expect((await Pet.findById(post.petIds[0]).lean()).breed || '').toBe('');
  });

  test('valeurs illisibles : jamais une erreur, valeurs neutres', async () => {
    const r = await site({ ...BASE, email: 'illisible.demande639@example.test', foodProvided: 'peut-être', breed: { a: 1 } }).expect(202);
    const lead = await AdLead.findById(r.body.id).lean();
    expect(lead.foodProvided == null).toBe(true);
    expect(lead.breed || '').toBe('');
  });
});
