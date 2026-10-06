/* eslint-disable no-console */
/**
 * 612 §8 (ZOE, 05/10/2026) — BANC LOCAL pour l'app au simulateur (jamais la production).
 * Reste allumé sur 127.0.0.1:5612 ; l'app s'y branche avec
 *   flutter build ios --simulator --debug --dart-define=HPS_API_ROOT=http://127.0.0.1:5612
 * Comptes locaux jetables (base en mémoire), mêmes capteurs que la mesure :
 *
 * Vrai serveur lancé sur 127.0.0.1 (base Mongo en mémoire, vraies routes, vraie prise
 * temps réel). Sont remplacés par des capteurs : Firebase (push), le SMTP (e-mails) et
 * le RÉSEAU Airwallex (création / lecture d'intention de paiement, signature du
 * webhook). Aucun paiement réel, aucune carte, aucun argent déplacé.
 *
 *   node scripts/mesure_circuit_612.js            # garde (gardien) + balade (promeneur)
 *   node scripts/mesure_circuit_612.js --sans-animal   # demande publiée sans animal enregistré
 */
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.ENCRYPTION_KEY = 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';

const path = require('path');
const http = require('http');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const pushes = []; const mails = [];
const stub = (rel, build) => {
  const p = require.resolve(rel);
  let actual = {};
  try { actual = require(p); } catch (_) { actual = {}; }
  require.cache[p] = { id: p, filename: p, loaded: true, exports: build(actual) };
};
stub('../src/config/firebaseAdmin', () => ({
  messaging: () => ({
    sendEachForMulticast: async (m) => { pushes.push(m); return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) }; },
  }),
}));
stub('../src/services/emailService', (a) => ({
  ...a,
  sendEmail: async (to, subject, text, html) => { mails.push({ to, subject, text, html }); return { messageId: 'capté' }; },
}));
let piSeq = 0;
const intents = new Map();
stub('../src/services/airwallexService', (a) => ({
  ...a,
  getAccessToken: async () => 'jeton-factice',
  findOrCreateCustomer: async () => ({ id: 'cus_local' }),
  findCustomerByMerchantId: async () => null,
  listPaymentMethods: async () => [],
  listAllPaymentConsents: async () => [],
  createPlatformPaymentIntent: async (o) => {
    piSeq += 1; const id = `int_local_${piSeq}`;
    // Comme le vrai service : reçoit des centimes, Airwallex répond en unités.
    const pi = { id, client_secret: `cs_${id}`, status: 'REQUIRES_PAYMENT_METHOD', amount: Number(o.amount) / 100, currency: o.currency, metadata: o.metadata || {} };
    intents.set(id, pi); return pi;
  },
  createPaymentIntent: async (o) => {
    piSeq += 1; const id = `int_local_${piSeq}`;
    const pi = { id, client_secret: `cs_${id}`, status: 'REQUIRES_PAYMENT_METHOD', amount: o.amount, currency: o.currency, metadata: o.metadata || {} };
    intents.set(id, pi); return pi;
  },
  retrievePaymentIntent: async (id) => intents.get(id) || { id, status: 'REQUIRES_PAYMENT_METHOD' },
  cancelPaymentIntent: async (id) => ({ id, status: 'CANCELLED' }),
  constructWebhookEvent: (body) => JSON.parse(Buffer.isBuffer(body) ? body.toString('utf8') : body),
  createRefund: async ({ paymentIntentId }) => ({ id: `rfd_${paymentIntentId}`, status: 'RECEIVED' }),
}));
try {
  stub('../src/utils/geocodeCity', (a) => ({ ...a, geocodeCity: async () => null }));
} catch (_) { /* facultatif */ }


const fs = require('fs');
const jwtTok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '12h' });
(async () => {
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const app = require('../src/app');
  const createSocketServer = require('../src/sockets');
  const server = http.createServer(app);
  createSocketServer(server);
  try { await require('../src/services/pricingService').init(); } catch (_) { /* défaut */ }
  try { await require('../src/services/serviceCatalogService').init(); } catch (_) { /* défaut */ }
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  const Pet = require('../src/models/Pet');
  const loc = (d = 0) => ({ type: 'Point', coordinates: [-30 + d, -35], city: 'Zone test' });
  const pw = process.env.BANC_MDP || require('crypto').randomBytes(6).toString('hex') + 'A1!';
  const base = { password: pw, verified: true, appLocale: 'fr', city: 'Zone test', country: 'FR', currency: 'EUR', mobile: '600000000', countryCode: '+33', address: '1 rue de la Zone test' };
  const fid = (n) => new mongoose.Types.ObjectId(`6120000000000000000000${n}`);
  const O = await Owner.create({ _id: fid('01'), ...base, name: 'Camille Durand', email: 'proprio612+test@example.test', location: loc() });
  const S = await Sitter.create({ _id: fid('02'), ...base, name: 'Sasha Gardien', email: 'gardien612+test@example.test', location: loc(0.01), hourlyRate: 12, dailyRate: 40, bio: 'Gardien de test local, zone fictive.' });
  const W = await Walker.create({ _id: fid('03'), ...base, name: 'Paul Promeneur', email: 'promeneur612+test@example.test', location: loc(0.02), bio: 'Promeneur de test local, zone fictive.', walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }, { durationMinutes: 60, basePrice: 18, currency: 'EUR', enabled: true }] });
  const pet = await Pet.create({ _id: fid('04'), ownerId: O._id, petName: 'Rex', category: 'dog', breed: 'Golden retriever' });
  await new Promise((r) => server.listen(5612, '127.0.0.1', r));
  const out = process.env.BANC_ETAT || '/tmp/banc612.json';
  fs.writeFileSync(out, JSON.stringify({
    root: 'http://127.0.0.1:5612', motDePasse: pw,
    owner: { id: String(O._id), email: O.email, token: jwtTok(O._id, 'owner') },
    sitter: { id: String(S._id), email: S.email, token: jwtTok(S._id, 'sitter') },
    walker: { id: String(W._id), email: W.email, token: jwtTok(W._id, 'walker') },
    petId: String(pet._id),
  }, null, 1), { mode: 0o600 });
  console.log('banc local prêt sur http://127.0.0.1:5612 — état :', out);
  // Petites commandes locales pour la mesure : captures et paiement simulé.
  const ctl = require('express')();
  ctl.listen(5613, '127.0.0.1');
  ctl.get('/__banc/captures', (req, res) => res.json({ pushes: pushes.map((m) => ({ tokens: m.tokens, type: m.data && m.data.type, title: m.notification && m.notification.title })), mails: mails.map((m) => ({ to: m.to, subject: m.subject })) }));
  ctl.post('/__banc/payer/:intent', (req, res) => { const pi = intents.get(req.params.intent); if (!pi) return res.status(404).json({ error: 'intention inconnue' }); pi.status = 'SUCCEEDED'; return res.json({ ok: true, intent: pi }); });
  ctl.get('/__banc/sockets', async (req, res) => {
    const io = require('../src/sockets/emitter').getSocketServer();
    const list = io ? await io.fetchSockets() : [];
    res.json(list.map((x) => ({ user: x.data && x.data.user, foreground: x.data && x.data.foreground, rooms: [...x.rooms].filter((r) => r !== x.id) })));
  });
  // Données locales : avance l'heure de début d'une réservation à « il y a 5 minutes »
  // (le serveur refuse de démarrer un service avant l'heure).
  ctl.post('/__banc/avancer/:booking', async (req, res) => {
    const Booking = require('../src/models/Booking');
    const d = new Date(Date.now() - 5 * 60000);
    const r = await Booking.updateOne({ _id: req.params.booking }, { $set: { startDate: d, serviceDate: d, date: d.toISOString().slice(0, 10), timeSlot: '1:00 AM' } });
    res.json({ ok: r.modifiedCount === 1 });
  });
  ctl.get('/__banc/intents', (req, res) => res.json([...intents.values()]));
})().catch((e) => { console.error('ÉCHEC', e); process.exit(1); });
