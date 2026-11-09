// 1011 (BOB, plan validé par Daniel le 09/11 « il faut que les gens concluent ») — contrat serveur :
//   · précisions d'une demande : horaires, « pas de voiture », budget, garde EN JOURNÉE (day_care) ;
//   · code postal OBLIGATOIRE sur le formulaire du site (POSTAL_REQUIRED, coupe-circuit) et recopié sur la demande ;
//   · lieu choisi dans le formulaire gardé sur le contact et repris à la confirmation ;
//   · « J'ai un véhicule » sur les profils gardien et promeneur, visible dans la fiche publique.
// VRAIE base Mongo en mémoire, vrai createPost, zone fictive (lat −35 / lng −30), aucun réseau, aucun e-mail réel.
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
const { cleanTime, toBool, resolveExtras, publicExtras, extrasSentence } = require('../src/utils/postExtras1011');

let mongo; let app; let Post; let AdLead; let Sitter; let Walker;
const D = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const BASE = {
  email: 'jeanne.contrat1011@example.test', firstName: 'Jeanne', service: 'journee', animal: 'chien',
  city: 'Zone test', postalCode: '75015', lat: -35.02, lng: -30.03, country: 'FR', lang: 'fr', startDate: D(10), endDate: D(11),
  campaign: 'paris_owners', page: '/demande',
};
const site = (body) => request(app).post('/ad-leads/site').send(body);
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };
const confirm = async (id, body = {}) => (await request(app).post(`/ad-leads/${id}/confirm`).set(BROWSER).send(body).expect(200)).body;
/** Appelle un contrôleur avec une fausse réponse Express. */
const call = (fn, req) => new Promise((resolve, reject) => {
  const res = { statusCode: 200, status(c) { this.statusCode = c; return this; }, json(b) { resolve({ status: this.statusCode, body: b }); return this; } };
  Promise.resolve(fn(req, res)).catch(reject);
});

beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  Post = require('../src/models/Post'); AdLead = require('../src/models/AdLead2210');
  Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  await Promise.all([require('../src/models/Owner').init(), Post.init(), AdLead.init(), Sitter.init(), Walker.init()]);
  const routes = require('../src/routes/adLeads2210');
  app = express(); app.use(express.json());
  app.use('/ad-leads', routes);
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
afterEach(() => { delete process.env.SITE_POSTAL_REQUIRED_1011; });

test('heures : « 9:30 » et « 9h30 » lus, illisible ignoré, jamais une erreur', () => {
  expect(cleanTime('9:30')).toBe('09:30');
  expect(cleanTime('9h30')).toBe('09:30');
  expect(cleanTime('18:30')).toBe('18:30');
  expect(cleanTime('')).toBe('');
  expect(cleanTime(null)).toBe('');
  expect(cleanTime('25:00')).toBeNull();
  expect(cleanTime('midi')).toBeNull();
  expect(toBool('true')).toBe(true); expect(toBool(0)).toBe(false); expect(toBool('peut-être')).toBeNull();
});

test('précisions : absent → rien à écrire ; invalide → ignoré ; vide → effacé', () => {
  expect(resolveExtras({})).toEqual({});
  expect(resolveExtras({ timeFrom: '10:00', timeTo: '18h30', ownerNoCar: 'true' })).toEqual({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true });
  expect(resolveExtras({ timeFrom: 'n importe quoi', ownerNoCar: 'bof' })).toEqual({});
  expect(resolveExtras({ timeFrom: '', ownerNoCar: false })).toEqual({ timeFrom: '', ownerNoCar: false });
  expect(publicExtras(null)).toEqual({ timeFrom: '', timeTo: '', ownerNoCar: false });
  expect(publicExtras({ timeFrom: '10:00', timeTo: 'xx', ownerNoCar: true })).toEqual({ timeFrom: '10:00', timeTo: '', ownerNoCar: true });
});

test('phrase en clair (lisible par une ancienne app), en français et en anglais', () => {
  expect(extrasSentence({ timeFrom: '10:00', timeTo: '18:30', noCar: true }, 'fr')).toBe("Horaires : de 10 h à 18 h 30. Je n'ai pas de voiture.");
  expect(extrasSentence({ timeFrom: '10:00', timeTo: '18:30', noCar: true }, 'en')).toBe("Hours: 10:00 to 18:30. I don't have a car.");
  expect(extrasSentence({ timeFrom: '08:15' }, 'fr')).toBe('À partir de 08 h 15.');
  expect(extrasSentence({}, 'fr')).toBe('');
});

test('annonce construite : garde en journée = day_care, lieu, code postal, précisions ; la garde classique ne change pas', () => {
  const { postInputFor, lieuFor } = require('../src/routes/adLeads2210');
  const lead = { lang: 'fr', animal: 'chien', service: 'journee', quand: 'plus_tard', city: 'Zone test', lat: -35, lng: -30,
    postalCode: '75 015', timeFrom: '10:00', timeTo: '18:30', noCar: true, budget: 20, lieu: 'at_sitter' };
  const a = postInputFor(lead, lieuFor({}, lead));
  expect(a.serviceTypes).toEqual(['day_care']);
  expect(a.serviceLocation).toBe('at_sitter');
  expect(a.houseSittingVenue).toBe('sitters_home');
  expect(a.location).toEqual({ city: 'Zone test', lat: -35, lng: -30, postalCode: '75015' });
  expect(a).toMatchObject({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true, budget: 20 });
  expect(a.body).toBe("Je cherche une garde en journée pour mon chien. Horaires : de 10 h à 18 h 30. Je n'ai pas de voiture.");
  expect(a.postalCode).toBeUndefined(); // jamais en champ de requête : la position du contact n'est pas recalculée
  // lieu explicite à la confirmation > lieu du formulaire > chez le propriétaire
  expect(lieuFor({ lieu: 'at_owner' }, lead)).toBe('at_owner');
  expect(lieuFor(null, { lieu: 'at_sitter' })).toBe('at_sitter');
  expect(lieuFor({ lieu: 'nimp' }, {})).toBe('at_owner');
  // garde classique sans précision : exactement comme avant
  const b = postInputFor({ lang: 'en', animal: 'chat', service: 'garde', quand: 'plus_tard', city: 'Zone test' }, 'at_owner');
  expect(b.serviceTypes).toEqual(['house_sitting']);
  expect(b.body).toBe("I'm looking for a pet sitter for my cat.");
  expect(b.location).toEqual({ city: 'Zone test' });
  expect(b.timeFrom).toBeUndefined(); expect(b.ownerNoCar).toBeUndefined(); expect(b.budget).toBeUndefined();
});

test('formulaire du site SANS code postal → 400 POSTAL_REQUIRED (message traduit), rien créé ; coupe-circuit = comme avant', async () => {
  const before = await AdLead.countDocuments({});
  const fr = await site({ ...BASE, email: 'sanscp.contrat1011@example.test', postalCode: '' });
  expect(fr.status).toBe(400); expect(fr.body.code).toBe('POSTAL_REQUIRED'); expect(fr.body.error).toMatch(/code postal/);
  const en = await site({ ...BASE, email: 'sanscp.contrat1011@example.test', postalCode: '  ', lang: 'en' });
  expect(en.status).toBe(400); expect(en.body.code).toBe('POSTAL_REQUIRED'); expect(en.body.error).toMatch(/postal code/);
  expect(await AdLead.countDocuments({})).toBe(before);
  process.env.SITE_POSTAL_REQUIRED_1011 = 'off';
  expect((await site({ ...BASE, email: 'coupecircuit.contrat1011@example.test', postalCode: '' })).status).toBe(202);
});

test('garde en journée avec précisions : gardées sur le contact, puis sur la demande publiée (day_care, horaires, sans voiture, budget, code postal, position de la carte intacte)', async () => {
  const r = await site({ ...BASE, lieu: 'at_sitter', timeFrom: '10:00', timeTo: '18h30', noCar: true, budget: '20' }).expect(202);
  const lead = await AdLead.findById(r.body.id).lean();
  expect(lead).toMatchObject({ service: 'journee', lieu: 'at_sitter', timeFrom: '10:00', timeTo: '18:30', noCar: true, budget: 20, postalCode: '75015', positionSource: 'map' });
  const c = await confirm(r.body.id); // la confirmation n'envoie PAS le lieu : celui du formulaire est repris
  const post = await Post.findById(c.postId).lean();
  expect(post.serviceTypes).toEqual(['day_care']);
  expect(post.serviceLocation).toBe('at_sitter');
  expect(post).toMatchObject({ timeFrom: '10:00', timeTo: '18:30', ownerNoCar: true, budget: 20 });
  expect(post.location.postalCode).toBe('75015');
  expect(post.location.lat).toBeCloseTo(-35.02, 5); expect(post.location.lng).toBeCloseTo(-30.03, 5);
  expect(post.body).toMatch(/garde en journée/); expect(post.body).toMatch(/Horaires : de 10 h à 18 h 30\. Je n'ai pas de voiture\./);
});

test('précisions illisibles ou absentes : jamais une erreur, valeurs neutres', async () => {
  const r = await site({ ...BASE, email: 'neutre.contrat1011@example.test', service: 'garde', timeFrom: 'matin', noCar: 'peut-être', budget: 'pas cher' }).expect(202);
  const lead = await AdLead.findById(r.body.id).lean();
  expect(lead).toMatchObject({ service: 'garde', lieu: 'at_owner', timeFrom: '', timeTo: '', noCar: false });
  expect(lead.budget == null).toBe(true);
  const c = await confirm(r.body.id);
  const post = await Post.findById(c.postId).lean();
  expect(post.serviceTypes).toEqual(['house_sitting']);
  expect(post.timeFrom || '').toBe(''); expect(post.ownerNoCar).toBe(false);
  expect(post.body).toBe('Je cherche une garde pour mon chien.');
});

test('« J\'ai un véhicule » : gardien et promeneur l\'enregistrent (true, false, null), valeur illisible ignorée, visible dans la fiche', async () => {
  const { updateSitterProfile } = require('../src/controllers/sitterController');
  const { updateMyWalkerProfile } = require('../src/controllers/walkerController');
  const { sanitizeUser } = require('../src/utils/sanitize');
  const s = await Sitter.create({ name: 'Agnès Test', email: 'agnes.contrat1011@example.test', password: 'x'.repeat(24), acceptedTerms: true });
  const w = await Walker.create({ name: 'Marc Test', email: 'marc.contrat1011@example.test', password: 'x'.repeat(24), acceptedTerms: true });
  expect(s.hasVehicle).toBeNull(); expect(w.hasVehicle).toBeNull();

  const r1 = await call(updateSitterProfile, { user: { id: String(s._id), role: 'sitter' }, params: {}, body: { hasVehicle: true } });
  expect(r1.status).toBe(200);
  expect((await Sitter.findById(s._id).lean()).hasVehicle).toBe(true);
  await call(updateSitterProfile, { user: { id: String(s._id), role: 'sitter' }, params: {}, body: { hasVehicle: 'oui' } });
  expect((await Sitter.findById(s._id).lean()).hasVehicle).toBe(true); // illisible → inchangé
  expect(sanitizeUser(await Sitter.findById(s._id)).hasVehicle).toBe(true); // fiche publique + liste des candidats

  const r2 = await call(updateMyWalkerProfile, { user: { id: String(w._id), role: 'walker' }, params: {}, body: { hasVehicle: false } });
  expect(r2.status).toBe(200);
  expect((await Walker.findById(w._id).lean()).hasVehicle).toBe(false);
  await call(updateMyWalkerProfile, { user: { id: String(w._id), role: 'walker' }, params: {}, body: { hasVehicle: null } });
  expect((await Walker.findById(w._id).lean()).hasVehicle).toBeNull();
});
