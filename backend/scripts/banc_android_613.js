/* eslint-disable no-console */
/**
 * 613 §9 (ZOE, 07/10/2026) — BANC LOCAL ANDROID (jamais la production).
 * Réunit le banc « carte chargée » de PAM (banc_carte_612) et le banc du circuit
 * de l'argent (banc_local_612) pour dérouler les parcours 613 sur l'émulateur :
 *   - vrai serveur sur 0.0.0.0:5615, base Mongo EN MÉMOIRE, vraies routes, vraie
 *     prise temps réel ; Firebase (push), SMTP et réseau Airwallex = capteurs ;
 *   - 100 membres avec photo autour de Paris, 50 PawSpots, 20 signalements,
 *     1 signalement « danger » à ~60 m au nord du point de départ, 1 peluche à ~15 m ;
 *   - 3 comptes (propriétaire, gardien, promeneur) + « John Ami » (promeneur, ami du
 *     propriétaire, position simulée qui bouge) ; mot de passe = BANC_MDP (jamais affiché).
 * L'émulateur s'y branche par http://10.0.2.2:5615 (--dart-define=HPS_API_ROOT).
 * Commandes locales (127.0.0.1:5616) : voir les routes /__banc/… en bas.
 *   BANC_MDP=… BANC_IMG=/dossier/photos BANC_ETAT=/chemin/etat.json node scripts/banc_android_613.js
 */
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.ENCRYPTION_KEY = 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';

const fs = require('fs');
const path = require('path');
const http = require('http');
const express = require('express');
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
    sendEachForMulticast: async (m) => { pushes.push({ ...m, at: Date.now() }); return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) }; },
  }),
}));
stub('../src/services/emailService', (a) => ({
  ...a,
  sendEmail: async (to, subject) => { mails.push({ to, subject, at: Date.now() }); return { messageId: 'capté' }; },
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
try { stub('../src/utils/geocodeCity', (a) => ({ ...a, geocodeCity: async () => null })); } catch (_) { /* facultatif */ }

const PORT = Number(process.env.BANC_PORT || 5615);
const ROOT = process.env.BANC_ROOT || `http://10.0.2.2:${PORT}`;
const C = [2.3522, 48.8566]; // Paris (base EN MÉMOIRE, jamais la production)
const M_LAT = 1 / 111320; const M_LNG = 1 / (111320 * Math.cos((C[1] * Math.PI) / 180));
const off = (north, east) => [C[0] + east * M_LNG, C[1] + north * M_LAT]; // [lng, lat]
let seed = 613;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const near = (km) => {
  // jamais à moins de 300 m du départ (le parcours d'alerte reste lisible)
  const a = rnd() * Math.PI * 2; const d = 0.3 + Math.sqrt(rnd()) * (km - 0.3);
  return [C[0] + (d * Math.cos(a)) / 73.0, C[1] + (d * Math.sin(a)) / 111.3];
};
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '12h' });

(async () => {
  const pw = process.env.BANC_MDP;
  if (!pw) throw new Error('BANC_MDP manquant');
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const app = require('../src/app');
  const outer = express();
  outer.use('/img', express.static(process.env.BANC_IMG || '/tmp/banc_img', { maxAge: '1h' }));
  const hits = []; // dernières requêtes (diagnostic)
  outer.use((req, res, next) => { hits.push(`${Date.now()} ${req.method} ${req.url.split('?')[0]}`); if (hits.length > 400) hits.shift(); next(); });
  outer.use(app);
  const server = http.createServer(outer);
  require('../src/sockets')(server);
  try { await require('../src/services/pricingService').init(); } catch (_) { /* défaut */ }
  try { await require('../src/services/serviceCatalogService').init(); } catch (_) { /* défaut */ }
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  const Pet = require('../src/models/Pet'); const Friendship = require('../src/models/Friendship');
  const PawSpot = require('../src/models/PawSpot'); const MapReport = require('../src/models/MapReport');
  const { PawPlush } = { PawPlush: require('../src/models/PawPlush') };
  const plushSvc = require('../src/services/plushService607');

  const base = { password: pw, verified: true, appLocale: 'fr', city: 'Paris', country: 'FR', currency: 'EUR', mobile: '600000000', countryCode: '+33', address: '1 rue du Banc local' };
  const here = (lngLat) => ({ type: 'Point', coordinates: lngLat, city: 'Paris' });
  const fid = (n) => new mongoose.Types.ObjectId(`6130000000000000000000${n}`); // ids fixes : un redémarrage garde les sessions
  const O = await Owner.create({ _id: fid('01'), ...base, name: 'Camille Durand', email: 'proprio613@example.test', location: here(C), avatar: { url: `${ROOT}/img/100.jpg` } });
  const S = await Sitter.create({ _id: fid('02'), ...base, name: 'Sasha Gardien', email: 'gardien613@example.test', location: here(off(400, 300)), hourlyRate: 12, dailyRate: 40, bio: 'Gardien du banc local.', avatar: { url: `${ROOT}/img/101.jpg` } });
  const W = await Walker.create({ _id: fid('03'), ...base, name: 'Paul Promeneur', email: 'promeneur613@example.test', location: here(off(-350, 250)), bio: 'Promeneur du banc local.', avatar: { url: `${ROOT}/img/102.jpg` },
    walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }, { durationMinutes: 60, basePrice: 100, currency: 'EUR', enabled: true }] });
  const J = await Walker.create({ _id: fid('05'), ...base, name: 'john', email: 'john613@example.test', location: here(off(150, 0)), bio: 'Ami du banc local.', avatar: { url: `${ROOT}/img/103.jpg` },
    walkRates: [{ durationMinutes: 30, basePrice: 9, currency: 'EUR', enabled: true }] });
  const pet = await Pet.create({ _id: fid('04'), ownerId: O._id, petName: 'Rex', category: 'dog', breed: 'Golden retriever' });
  await Friendship.create({ requesterId: O._id, requesterModel: 'Owner', addresseeId: J._id, addresseeModel: 'Walker', status: 'accepted' });

  const N = Number(process.env.BANC_MEMBRES || 100);
  for (let i = 0; i < N; i += 1) {
    const M = [Sitter, Walker, Owner][i % 3];
    const extra = i % 3 === 0 ? { hourlyRate: 10 + (i % 9), dailyRate: 30 + (i % 20), bio: 'Membre du banc local.' }
      : (i % 3 === 1 ? { bio: 'Membre du banc local.', walkRates: [{ durationMinutes: 30, basePrice: 9 + (i % 8), currency: 'EUR', enabled: true }] } : {});
    // eslint-disable-next-line no-await-in-loop
    await M.create({ ...base, ...extra, name: `Membre ${i + 1}`, email: `membre${i}@example.test`, location: here(near(3)), avatar: { url: `${ROOT}/img/${i}.jpg` } });
  }
  const types = PawSpot.PAWSPOT_TYPES || ['path_walk'];
  let spots = 0;
  for (let i = 0; i < 50; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await PawSpot.create({ creatorId: O._id, creatorModel: 'Owner', creatorName: 'Banc', type: types[i % types.length], name: `Spot ${i + 1}`, location: here(near(3)) })
      .then(() => { spots += 1; }).catch((e) => console.log('spot', e.message));
  }
  const rt = MapReport.REPORT_TYPES;
  for (let i = 0; i < 20; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await MapReport.create({ type: rt[i % rt.length], location: here(near(3)), reporterId: S._id, reporterModel: 'Sitter', expiresAt: new Date(Date.now() + 40 * 3600000) })
      .catch((e) => console.log('report', e.message));
  }
  // Le signalement du parcours « alerte en passant » : danger, à 60 m au nord du départ, posé il y a 30 min.
  const hazard = await MapReport.create({ type: 'hazard', note: 'Verre cassé', location: here(off(60, 0)), reporterId: S._id, reporterModel: 'Sitter',
    createdAt: new Date(Date.now() - 30 * 60000), expiresAt: new Date(Date.now() + 40 * 3600000) });
  // Peluche du jour à 15 m à l'est du départ.
  const plushLngLat = off(0, 15);
  const plush = await PawPlush.create({ cityKey: 'paris', cityLabel: 'Paris', day: plushSvc.dayKeyFor(plushLngLat[0], Date.now(), plushLngLat[1]), slot: 0, type: 'puppy', location: { type: 'Point', coordinates: plushLngLat } });

  await new Promise((r) => server.listen(PORT, '0.0.0.0', r));
  const etat = {
    root: ROOT,
    depart: { lat: C[1], lng: C[0] },
    owner: { id: String(O._id), email: O.email, token: tok(O._id, 'owner') },
    sitter: { id: String(S._id), email: S.email, token: tok(S._id, 'sitter') },
    walker: { id: String(W._id), email: W.email, token: tok(W._id, 'walker') },
    john: { id: String(J._id), email: J.email, token: tok(J._id, 'walker') },
    petId: String(pet._id), hazardId: String(hazard._id), plushId: String(plush._id),
    hazard: { lat: off(60, 0)[1], lng: off(60, 0)[0] }, plush: { lat: plushLngLat[1], lng: plushLngLat[0] },
  };
  const out = process.env.BANC_ETAT || '/tmp/banc613.json';
  fs.writeFileSync(out, JSON.stringify(etat, null, 1), { mode: 0o600 });
  console.log(`banc 613 prêt sur :${PORT} — membres ${N}, spots ${spots}, signalements ${await MapReport.countDocuments()}, peluche ${plush._id}`);

  // ── john : position simulée qui bouge (vrai client socket, son propre jeton) ──
  const ioClient = require(path.join(__dirname, '../../website/node_modules/socket.io-client'));
  let johnSock = null; let johnTimer = null; let johnStep = 0; let johnPos = null;
  const johnEmit = (lngLat) => { johnPos = lngLat; johnSock.emit('map:position-update', { lat: lngLat[1], lng: lngLat[0], city: 'Paris', duration: 'until_stop', deviceId: 'banc-john' }); };
  const johnConnect = () => new Promise((resolve) => {
    if (johnSock && johnSock.connected) return resolve();
    johnSock = ioClient(`http://127.0.0.1:${PORT}`, { auth: { token: etat.john.token }, transports: ['websocket'] });
    johnSock.on('connect', () => johnSock.emit('map:identify', { userId: etat.john.id, role: 'walker' }, () => resolve()));
    return null;
  });

  const ctl = express();
  ctl.use(express.json());
  ctl.get('/__banc/hits', (req, res) => res.json(hits.slice(-Number(req.query.n || 80))));
  ctl.get('/__banc/captures', (req, res) => res.json({ pushes: pushes.map((m) => ({ at: m.at, tokens: m.tokens, type: m.data && m.data.type, title: m.notification && m.notification.title, body: m.notification && m.notification.body })), mails: mails.map((m) => ({ at: m.at, to: m.to, subject: m.subject })) }));
  ctl.post('/__banc/payer/:intent', (req, res) => { const pi = intents.get(req.params.intent); if (!pi) return res.status(404).json({ error: 'intention inconnue' }); pi.status = 'SUCCEEDED'; return res.json({ ok: true, intent: pi }); });
  ctl.get('/__banc/intents', (req, res) => res.json([...intents.values()]));
  ctl.get('/__banc/sockets', async (req, res) => {
    const io = require('../src/sockets/emitter').getSocketServer();
    const list = io ? await io.fetchSockets() : [];
    res.json(list.map((x) => ({ user: x.data && x.data.user, foreground: x.data && x.data.foreground, rooms: [...x.rooms].filter((r) => r !== x.id) })));
  });
  // john marche : départ 150 m au nord, avance de ~4 m toutes les 3,5 s vers l'est.
  ctl.post('/__banc/john/start', async (req, res) => {
    await johnConnect();
    clearInterval(johnTimer); johnStep = 0;
    johnEmit(off(150, 0));
    johnTimer = setInterval(() => { johnStep += 1; johnEmit(off(150 + (johnStep % 2), johnStep * 4)); }, 3500);
    res.json({ ok: true });
  });
  ctl.post('/__banc/john/stop', (req, res) => { clearInterval(johnTimer); if (johnSock) johnSock.emit('map:go-offline'); res.json({ ok: true, johnStep }); });
  ctl.get('/__banc/john', (req, res) => res.json({ step: johnStep, pos: johnPos, connected: !!(johnSock && johnSock.connected) }));
  // john attrape la peluche du jour EN PREMIER (cas « deux profils, la même peluche »).
  ctl.post('/__banc/john/catch', async (req, res) => {
    await johnConnect();
    clearInterval(johnTimer);
    johnEmit(plushLngLat);
    await new Promise((r) => setTimeout(r, 3200));
    const r1 = await fetch(`http://127.0.0.1:${PORT}/api/v1/plush/${etat.plushId}/catch`, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${etat.john.token}` }, body: JSON.stringify({ lat: plushLngLat[1], lng: plushLngLat[0], accuracy: 5 }) });
    const b1 = await r1.json().catch(() => ({}));
    // même personne qui redemande (réponse perdue) : doit recevoir 200 already, sans points en plus
    const r2 = await fetch(`http://127.0.0.1:${PORT}/api/v1/plush/${etat.plushId}/catch`, { method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${etat.john.token}` }, body: JSON.stringify({ lat: plushLngLat[1], lng: plushLngLat[0], accuracy: 5 }) });
    const b2 = await r2.json().catch(() => ({}));
    res.json({ premier: { status: r1.status, body: b1 }, redemande: { status: r2.status, body: b2 } });
  });
  ctl.post('/__banc/avancer/:booking', async (req, res) => {
    const Booking = require('../src/models/Booking');
    const d = new Date(Date.now() - 5 * 60000);
    const r = await Booking.updateOne({ _id: req.params.booking }, { $set: { startDate: d, serviceDate: d, date: d.toISOString().slice(0, 10), timeSlot: '1:00 AM' } });
    res.json({ ok: r.modifiedCount === 1 });
  });
  // Réglage local d'un document (ex. passer un prestataire « Top ») : { "isTopWalker": true }
  const MODELS = { owner: Owner, sitter: Sitter, walker: Walker };
  ctl.post('/__banc/set/:role/:id', async (req, res) => {
    const M = MODELS[req.params.role]; if (!M) return res.status(400).json({ error: 'rôle' });
    const r = await M.updateOne({ _id: req.params.id }, { $set: req.body || {} });
    res.json({ ok: r.matchedCount === 1 });
  });
  // Prestataire « Top » RÉEL : le serveur recalcule le badge à chaque lecture du
  // profil (20 prestations confirmées + note ≥ 4,5) ; un simple drapeau posé à la
  // main est effacé. On crée donc 20 balades terminées et 20 avis 5★ (base locale).
  ctl.post('/__banc/top/:role/:id', async (req, res) => {
    const role = req.params.role === 'sitter' ? 'sitter' : 'walker';
    const id = new mongoose.Types.ObjectId(req.params.id);
    const Booking = require('../src/models/Booking'); const Review = require('../src/models/Review');
    const field = role === 'walker' ? 'walkerId' : 'sitterId';
    const now = Date.now();
    for (let i = 0; i < 20; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      const b = await Booking.collection.insertOne({ [field]: id, ownerId: O._id, status: 'completed', confirmationStatus: 'confirmed',
        paymentStatus: 'paid', date: new Date(now - (i + 2) * 86400000).toISOString(), createdAt: new Date(now - (i + 3) * 86400000) });
      // eslint-disable-next-line no-await-in-loop
      await Review.collection.insertOne({ revieweeId: id, revieweeModel: role === 'walker' ? 'Walker' : 'Sitter', reviewerId: O._id,
        reviewerModel: 'Owner', bookingId: b.insertedId, rating: 5, comment: 'Parfait (banc local).', hidden: false, createdAt: new Date() });
    }
    const loyalty = require('../src/services/loyaltyService');
    const r = role === 'walker' ? await loyalty.recomputeWalkerStatus(req.params.id) : await loyalty.recomputeSitterStatus(req.params.id);
    res.json(r);
  });
  ctl.get('/__banc/plush', async (req, res) => res.json(await PawPlush.find({}).lean()));
  ctl.listen(5616, '127.0.0.1');
})().catch((e) => { console.error('ÉCHEC', e); process.exit(1); });
