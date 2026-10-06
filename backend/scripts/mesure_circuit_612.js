/* eslint-disable no-console */
/**
 * 612 §8 (ZOE, 05/10/2026) — MESURE locale du CIRCUIT DE L'ARGENT, jamais la production.
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

const { io: ioClient } = require(path.resolve(__dirname, '../../website/node_modules/socket.io-client'));
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' });
const SANS_ANIMAL = process.argv.includes('--sans-animal');
const VERBEUX = process.argv.includes('--verbeux');

(async () => {
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const app = require('../src/app');
  const createSocketServer = require('../src/sockets');
  const server = http.createServer(app);
  createSocketServer(server);
  try { await require('../src/services/pricingService').init(); } catch (_) { /* grille par défaut */ }
  try { await require('../src/services/serviceCatalogService').init(); } catch (_) { /* défaut */ }
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const root = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, p, token, body, base = '/api/v1') => {
    const r = await fetch(`${root}${base}${p}`, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), 'X-App-Version': '612', 'X-App-Platform': 'ios' },
      body: body ? JSON.stringify(body) : undefined,
    });
    let j = null; try { j = await r.json(); } catch (_) { /* vide */ }
    return { status: r.status, body: j };
  };

  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  const Pet = require('../src/models/Pet'); const Notification = require('../src/models/Notification');
  const Booking = require('../src/models/Booking'); const Application = require('../src/models/Application');

  // Zone fictive (lat -35 / lng -30). Comptes locaux, créés ici, jetés à la fin.
  const loc = (d = 0) => ({ type: 'Point', coordinates: [-30 + d, -35], city: 'Zone test' });
  const pw = 'MotDePasse612!';
  const O = await Owner.create({ name: 'Camille Durand', email: 'proprio612+test@example.test', password: pw, verified: true, appLocale: 'fr', city: 'Zone test', location: loc(), fcmTokens: ['jeton-proprio'], fcmDevices: [{ token: 'jeton-proprio', platform: 'ios', appBuild: 612 }], currency: 'EUR' });
  const S = await Sitter.create({ name: 'Sasha Gardien', email: 'gardien612+test@example.test', password: pw, verified: true, appLocale: 'fr', city: 'Zone test', location: loc(0.01), hourlyRate: 12, dailyRate: 40, currency: 'EUR', fcmTokens: ['jeton-gardien'] });
  const W = await Walker.create({ name: 'Paul Promeneur', email: 'promeneur612+test@example.test', password: pw, verified: true, appLocale: 'fr', city: 'Zone test', location: loc(0.02), currency: 'EUR', fcmTokens: ['jeton-promeneur'], walkRates: [{ durationMinutes: 30, basePrice: 10, currency: 'EUR', enabled: true }, { durationMinutes: 60, basePrice: 18, currency: 'EUR', enabled: true }] });
  // Une personne à DEUX profils (gardien + promeneur).
  const D2s = await Sitter.create({ name: 'Dana Deux', email: 'deux612+test@example.test', password: pw, verified: true, appLocale: 'fr', city: 'Zone test', location: loc(0.03), hourlyRate: 11, currency: 'EUR' });
  const D2w = await Walker.create({ name: 'Dana Deux', email: 'deux612+test@example.test', password: pw, verified: true, appLocale: 'fr', city: 'Zone test', location: loc(0.03), currency: 'EUR', walkRates: [{ durationMinutes: 60, basePrice: 16, currency: 'EUR', enabled: true }] });
  const pet = SANS_ANIMAL ? { _id: null } : await Pet.create({ ownerId: O._id, name: 'Rex', petName: 'Rex', species: 'dog', category: 'dog', breed: 'Golden' }).catch(async (e) => {
    console.log('  (création animal : ', e.message.slice(0, 120), ')');
    const r = await Pet.collection.insertOne({ ownerId: O._id, name: 'Rex', petName: 'Rex', species: 'dog' });
    return { _id: r.insertedId };
  });
  const tO = tok(O._id, 'owner'); const tS = tok(S._id, 'sitter'); const tW = tok(W._id, 'walker');
  const tD2s = tok(D2s._id, 'sitter'); const tD2w = tok(D2w._id, 'walker');

  // Prises temps réel : ce que chaque app reçoit en direct.
  const live = { owner: [], sitter: [], walker: [] };
  const connect = async (token, bucket) => {
    const s = ioClient(root, { transports: ['websocket'], auth: { token } });
    s.onAny((ev, p) => bucket.push({ ev, type: p && p.type }));
    await new Promise((r) => s.on('connect', r));
    s.emit('presence:state', { foreground: false }); // app en arrière-plan : le push doit partir
    return s;
  };
  const sockO = await connect(tO, live.owner); const sockS = await connect(tS, live.sitter); const sockW = await connect(tW, live.walker);
  await wait(200);

  const tableau = [];
  const note = (etape, role, porte, ok, detail) => {
    tableau.push({ etape, role, porte, ok, detail });
    console.log(`${ok === true ? 'OK ' : ok === false ? 'KO ' : '-- '} | ${etape} | ${role} | ${porte} | ${detail}`);
  };
  const canaux = async (userId, role, type, since) => {
    const bell = await Notification.find({ recipientId: userId, type, createdAt: { $gte: since } }).lean();
    const doc = await (role === 'owner' ? Owner : role === 'sitter' ? Sitter : Walker).findById(userId).select('email fcmTokens').lean();
    const push = pushes.filter((m) => (m.tokens || []).some((t) => (doc.fcmTokens || []).includes(t)) && m.data && m.data.type === type);
    const mail = mails.filter((m) => m.to === doc.email && m._at >= since.getTime());
    return { cloche: bell.length, push: push.length, mail: mail.length, titre: bell[0] && bell[0].title, corps: bell[0] && bell[0].body, sujet: mail[0] && mail[0].subject, route: push[0] && push[0].data && push[0].data.route };
  };
  // horodatage des e-mails captés
  const origPush = mails.push.bind(mails);
  mails.push = (m) => origPush({ ...m, _at: Date.now() });
  const resetCapt = () => { pushes.length = 0; mails.length = 0; live.owner.length = 0; live.sitter.length = 0; live.walker.length = 0; };

  const circuit = async ({ nom, service, provRole, provTok, provDoc, autreTok, autreDoc, porte }) => {
    console.log(`\n================ ${nom} — porte « ${porte} » ================`);
    resetCapt();
    let t0 = new Date();
    // 1. Publication (même route pour l'accueil et la PawMap : POST /posts).
    const start = new Date(Date.now() + 3 * 86400000); start.setUTCHours(9, 0, 0, 0);
    const end = new Date(start.getTime() + (service === 'dog_walking' ? 3600000 : 2 * 86400000));
    const postBody = {
      body: service === 'dog_walking' ? 'Balade pour Rex' : 'Garde de Rex deux jours',
      serviceTypes: [service], serviceLocation: 'at_owner',
      ...(service === 'house_sitting' ? { houseSittingVenue: 'owners_home' } : {}),
      ...(service === 'dog_walking' ? { walkDurationMinutes: 60 } : {}),
      startDate: start.toISOString(), endDate: end.toISOString(),
      location: { city: 'Zone test', lat: -35, lng: -30 },
      ...(SANS_ANIMAL ? { petIds: [], animalTypes: ['dog'], animalCount: 1 } : { petIds: [String(pet._id)], petId: String(pet._id) }),
    };
    const pub = await call('POST', '/posts', tO, postBody);
    const postId = pub.body && pub.body.post && (pub.body.post.id || pub.body.post._id);
    note('1 publier', 'propriétaire', porte, pub.status === 201, `HTTP ${pub.status}${pub.status !== 201 ? ' ' + JSON.stringify(pub.body).slice(0, 200) : ''}`);
    if (!postId) return;
    await wait(1500);
    // 2. Prestataires prévenus.
    const c2 = await canaux(provDoc._id, provRole, 'new_request_nearby', t0);
    note('2 prévenu de l’annonce', provRole, porte, c2.cloche === 1 && c2.push === 1 && c2.mail === 1, `cloche ${c2.cloche} · téléphone ${c2.push} · e-mail ${c2.mail} · « ${c2.corps || ''} »`);
    const wrongRole = provRole === 'walker' ? S : W;
    const c2b = await canaux(wrongRole._id, provRole === 'walker' ? 'sitter' : 'walker', 'new_request_nearby', t0);
    note('2 mauvais rôle non prévenu', provRole === 'walker' ? 'gardien' : 'promeneur', porte, c2b.cloche === 0, `cloche ${c2b.cloche}`);
    const d2 = await canaux(provRole === 'walker' ? D2w._id : D2s._id, provRole, 'new_request_nearby', t0);
    const d2other = await canaux(provRole === 'walker' ? D2s._id : D2w._id, provRole === 'walker' ? 'sitter' : 'walker', 'new_request_nearby', t0);
    note('2 compte à deux profils prévenu une fois', 'gardien+promeneur', porte, d2.cloche === 1 && d2other.cloche === 0, `profil ${provRole} : ${d2.cloche} · autre profil : ${d2other.cloche}`);

    // 3. Le prestataire voit l'annonce (accueil = /posts/requests ; PawMap = /posts/requests/nearby ; lien cloche/e-mail = /posts/by-id).
    const feed = await call('GET', '/posts/requests', provTok);
    const inFeed = ((feed.body && (feed.body.posts || feed.body.requests)) || []).some((p) => String(p.id || p._id) === String(postId));
    note('3 voit l’annonce', provRole, 'accueil', feed.status === 200 && inFeed, `HTTP ${feed.status}, annonce dans la liste : ${inFeed}`);
    const near = await call('GET', '/posts/requests/nearby?lat=-35&lng=-30&maxDistance=50', provTok);
    const nearList = (near.body && near.body.posts) || [];
    const inNear = nearList.find((p) => String(p.id || p._id) === String(postId));
    note('3 voit l’annonce (avec un animal, sinon le bouton « Proposer » est grisé)', provRole, 'PawMap', near.status === 200 && !!inNear && (inNear.petIds || []).length > 0, `HTTP ${near.status}, annonce sur la carte : ${!!inNear}${inNear ? `, animaux joints : ${(inNear.petIds || []).length}` : ''}`);
    const byId = await call('GET', `/posts/by-id/${postId}`, provTok);
    note('3 ouvre l’annonce', provRole, 'cloche / e-mail (/post/<id>)', byId.status === 200, `HTTP ${byId.status} ; route du push : ${c2.route}`);

    // 3 bis. Il postule (même appel pour l'accueil, la PawMap et la fiche).
    resetCapt(); t0 = new Date();
    const serviceForApp = service;
    const appBody = {
      // Comme l'app (toutes versions) : l'animal envoyé est celui que l'annonce expose.
      petIds: SANS_ANIMAL ? ((inNear && inNear.petIds) || []) : [String(pet._id)],
      serviceType: serviceForApp,
      ...(service === 'house_sitting' ? { houseSittingVenue: 'owners_home' } : {}),
      serviceDate: new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate())).toISOString(),
      startDate: start.toISOString(), endDate: end.toISOString(),
      timeSlot: '9:00 AM', basePrice: provRole === 'walker' ? 18 : 12,
      ...(service === 'dog_walking' ? { duration: 60 } : {}),
      postId: String(postId),
    };
    const ap = await call('POST', `/applications?ownerId=${O._id}`, provTok, appBody);
    const applicationId = ap.body && ap.body.application && (ap.body.application.id || ap.body.application._id);
    note('3 postule', provRole, porte, ap.status === 201, `HTTP ${ap.status}${ap.status !== 201 ? ' ' + JSON.stringify(ap.body).slice(0, 220) : ` prix ${JSON.stringify((ap.body.application.pricing && { total: ap.body.application.pricing.totalPrice, commission: ap.body.application.pricing.commission, net: ap.body.application.pricing.netPayout }) || {})}`}`);
    if (!applicationId) return;
    // Un 2e candidat (l'autre personne du même rôle) pour mesurer le refus automatique.
    let app2 = null;
    if (autreTok) {
      const r2 = await call('POST', `/applications?ownerId=${O._id}`, autreTok, { ...appBody, basePrice: provRole === 'walker' ? 16 : 11 });
      app2 = r2.body && r2.body.application && (r2.body.application.id || r2.body.application._id);
      note('3 postule (2e candidat, compte à deux profils)', provRole, porte, r2.status === 201, `HTTP ${r2.status}${r2.status !== 201 ? ' ' + JSON.stringify(r2.body).slice(0, 200) : ''}`);
    }
    await wait(1200);

    // 4. LE PROPRIÉTAIRE EST PRÉVENU.
    const c4 = await canaux(O._id, 'owner', 'application_new', t0);
    note('4 prévenu de la candidature : cloche', 'propriétaire', porte, c4.cloche >= 1, `${c4.cloche} entrée(s) · « ${c4.titre || ''} — ${c4.corps || ''} »`);
    note('4 prévenu de la candidature : téléphone', 'propriétaire', porte, c4.push >= 1, `${c4.push} push · route ${c4.route}`);
    note('4 prévenu de la candidature : e-mail', 'propriétaire', porte, c4.mail >= 1, `${c4.mail} e-mail(s) · « ${c4.sujet || ''} »`);
    const liveApp = live.owner.filter((e) => e.ev === 'application:new').length;
    const liveNotif = live.owner.filter((e) => e.ev === 'notification.new' && e.type === 'application_new').length;
    note('4 prévenu en direct (app ouverte)', 'propriétaire', porte, liveApp >= 1 && liveNotif >= 1, `notification.new ${liveNotif} · application:new ${liveApp} (rafraîchit la liste des candidats sans tirer l’écran)`);
    const list = await call('GET', '/applications', tO);
    const apps = (list.body && (list.body.applications || list.body.data)) || [];
    note('4 voit la candidature dans ses demandes', 'propriétaire', 'accueil / profil', list.status === 200 && apps.some((a) => String(a.id || a._id) === String(applicationId)), `HTTP ${list.status}, ${apps.length} candidature(s)`);
    const mine = await call('GET', '/posts/my', tO);
    note('4 sa demande est dans « Mes annonces »', 'propriétaire', 'accueil / profil', mine.status === 200, `HTTP ${mine.status}`);
    const cnt = await call('GET', '/notifications/my/unread-count', tO);
    note('4 pastille de la cloche', 'propriétaire', porte, cnt.body && cnt.body.totalUnreadCount >= 1, `non lues : ${cnt.body && cnt.body.totalUnreadCount}`);

    // 5. Il accepte, puis paie.
    resetCapt(); t0 = new Date();
    const acc = await call('POST', `/applications/${applicationId}/respond`, tO, { action: 'accept' });
    const bookingId = acc.body && ((acc.body.booking && (acc.body.booking.id || acc.body.booking._id)) || (acc.body.application && acc.body.application.bookingId && (acc.body.application.bookingId.id || acc.body.application.bookingId._id || acc.body.application.bookingId)));
    note('5 accepte la candidature', 'propriétaire', porte, acc.status === 200 && !!bookingId, `HTTP ${acc.status}${acc.status !== 200 ? ' ' + JSON.stringify(acc.body).slice(0, 220) : ''}`);
    if (!bookingId) return;
    await wait(1000);
    const c5 = await canaux(provDoc._id, provRole, 'application_accepted', t0);
    note('5 prévenu « candidature acceptée »', provRole, porte, c5.cloche === 1 && c5.push === 1 && c5.mail === 1, `cloche ${c5.cloche} · téléphone ${c5.push} · e-mail ${c5.mail}`);
    if (app2) {
      const other = provRole === 'walker' ? D2w : D2s;
      const c5b = await canaux(other._id, provRole, 'application_rejected_other_accepted', t0);
      note('5 l’autre candidat est prévenu qu’un autre a été choisi', provRole, porte, c5b.cloche === 1, `cloche ${c5b.cloche} · téléphone ${c5b.push} (pas de jeton sur ce compte) · e-mail ${c5b.mail}`);
    }
    const b0 = await Booking.findById(bookingId).lean();
    if (VERBEUX) console.log('   réservation après acceptation :', JSON.stringify({ status: b0.status, paymentStatus: b0.paymentStatus, pricing: b0.pricing }));
    const agreement = await call('GET', `/bookings/${bookingId}/agreement`, tO);
    note('5 accord de réservation lisible', 'propriétaire', porte, agreement.status === 200, `HTTP ${agreement.status}`);
    const pi = await call('POST', `/bookings/${bookingId}/create-payment-intent`, tO, {});
    const piId = pi.body && (pi.body.paymentIntentId || (pi.body.paymentIntent && pi.body.paymentIntent.id) || pi.body.id);
    note('5 ouvre le paiement (intention créée)', 'propriétaire', porte, pi.status === 200 && !!piId, `HTTP ${pi.status} ${pi.status !== 200 ? JSON.stringify(pi.body).slice(0, 260) : `montant ${JSON.stringify(pi.body.amount || pi.body.totalAmount || (pi.body.pricing && pi.body.pricing.totalPrice))} ${pi.body.currency || ''}`}`);
    if (!piId) return;
    if (VERBEUX) console.log('   réponse create-payment-intent :', JSON.stringify(pi.body).slice(0, 600));
    // Paiement SIMULÉ : l'intention passe « réussie », le webhook arrive.
    const intent = intents.get(piId); if (intent) intent.status = 'SUCCEEDED';
    resetCapt(); t0 = new Date();
    const wh = await call('POST', '/webhooks/airwallex', null, { id: `evt_${piId}`, name: 'payment_intent.succeeded', data: { id: piId, amount: intent && intent.amount, currency: 'EUR', metadata: (intent && intent.metadata) || {} } }, '');
    await wait(1500);
    const b1 = await Booking.findById(bookingId).lean();
    note('5 paiement reçu (webhook simulé)', 'propriétaire', porte, wh.status === 200 && b1.paymentStatus === 'paid', `webhook HTTP ${wh.status} · réservation ${b1.status}/${b1.paymentStatus}`);
    const conf = await call('POST', `/bookings/${bookingId}/confirm-payment/${piId}`, tO, {});
    note('5 retour dans l’app après paiement (/confirm-payment)', 'propriétaire', porte, conf.status === 200, `HTTP ${conf.status}${conf.status !== 200 ? ' ' + JSON.stringify(conf.body).slice(0, 200) : ''}`);
    const p = b1.pricing || {};
    // Règle LUE dans le code : la commission (20 % du tarif du prestataire) s'AJOUTE
    // au prix ; le prestataire touche 100 % de son tarif.
    const okSplit = Math.abs((p.commission || 0) - 0.2 * (p.basePrice || 0)) < 0.011
      && Math.abs((p.netPayout || 0) - (p.basePrice || 0)) < 0.011
      && Math.abs((p.totalPrice || 0) - (p.basePrice + p.commission)) < 0.011
      && Math.abs(Number(pi.body.amount) - Math.round(p.totalPrice * 100)) < 1;
    note('5 montants : tarif prestataire + 20 % de commission = prix payé', 'tous', porte, okSplit, `tarif ${p.basePrice} · commission ${p.commission} · payé ${p.totalPrice} (intention : ${pi.body.amount} centimes) · prestataire ${p.netPayout}`);

    // 6. Le prestataire voit « payé ».
    await wait(600);
    const paidTypes = ['booking_paid', 'PAYMENT_SUCCESS', 'payment_success', 'BOOKING_PAID_CHAT_UNLOCKED', 'NEW_MESSAGE'];
    const provBell = await Notification.find({ recipientId: provDoc._id, createdAt: { $gte: t0 } }).select('type title').lean();
    const ownBell = await Notification.find({ recipientId: O._id, createdAt: { $gte: t0 } }).select('type title').lean();
    note('6 prévenu « payé »', provRole, porte, provBell.some((n) => paidTypes.includes(n.type)), `cloche : ${provBell.map((n) => n.type).join(', ') || 'rien'} · push ${pushes.filter((m) => m.tokens.includes(provRole === 'walker' ? 'jeton-promeneur' : 'jeton-gardien')).length} · e-mail ${mails.filter((m) => m.to === provDoc.email).length}`);
    note('6 reçu de paiement', 'propriétaire', porte, ownBell.length >= 1, `cloche : ${ownBell.map((n) => n.type).join(', ') || 'rien'} · e-mail ${mails.filter((m) => m.to === O.email).length}`);
    const liveKey = provRole === 'walker' ? 'walker' : 'sitter';
    note('6 « payé » en direct (app ouverte)', provRole, porte, live[liveKey].some((e) => e.ev === 'booking:paid'), `booking:paid reçu : prestataire ${live[liveKey].filter((e) => e.ev === 'booking:paid').length} · propriétaire ${live.owner.filter((e) => e.ev === 'booking:paid').length}`);
    const provBookings = await call('GET', '/bookings/my', provTok);
    const pb = ((provBookings.body && (provBookings.body.bookings || provBookings.body.data)) || []).find((x) => String(x.id || x._id) === String(bookingId));
    note('6 voit la réservation payée dans sa liste', provRole, 'réservations', !!pb && (pb.paymentStatus === 'paid'), `HTTP ${provBookings.status} · ${pb ? `${pb.status}/${pb.paymentStatus}` : 'absente'}`);

    // 6 bis. Service : démarrer → terminer → confirmer.
    // Avant l'heure, le serveur refuse de démarrer (mesuré : 409 SERVICE_NOT_STARTED_YET).
    const early = await call('POST', `/bookings/${bookingId}/service/start`, provTok, {});
    note('6 démarrer AVANT l’heure est refusé', provRole, porte, early.status === 409, `HTTP ${early.status} ${(early.body && early.body.code) || ''}`);
    // Données locales : on avance l'heure du service à « il y a 5 minutes ».
    const nowStart = new Date(Date.now() - 5 * 60000);
    await Booking.updateOne({ _id: bookingId }, { $set: { startDate: nowStart, date: nowStart.toISOString().slice(0, 10), serviceDate: nowStart } });
    resetCapt(); t0 = new Date();
    const st = await call('POST', `/bookings/${bookingId}/service/start`, provTok, {});
    note('6 démarre le service', provRole, porte, st.status === 200, `HTTP ${st.status}${st.status !== 200 ? ' ' + JSON.stringify(st.body).slice(0, 200) : ''}`);
    await wait(500);
    const oStart = await Notification.find({ recipientId: O._id, createdAt: { $gte: t0 } }).select('type').lean();
    note('6 prévenu « service commencé »', 'propriétaire', porte, oStart.length >= 1, `cloche : ${oStart.map((n) => n.type).join(', ') || 'rien'}`);
    resetCapt(); t0 = new Date();
    const fin = await call('POST', `/bookings/${bookingId}/service/complete`, provTok, {});
    note('6 termine le service', provRole, porte, fin.status === 200, `HTTP ${fin.status}${fin.status !== 200 ? ' ' + JSON.stringify(fin.body).slice(0, 200) : ''}`);
    await wait(400);
    const cf = await call('POST', `/bookings/${bookingId}/service/confirm`, tO, {});
    note('6 confirme la fin', 'propriétaire', porte, cf.status === 200, `HTTP ${cf.status}${cf.status !== 200 ? ' ' + JSON.stringify(cf.body).slice(0, 200) : ''}`);
    await wait(600);
    const b2 = await Booking.findById(bookingId).lean();
    const provAfter = await (provRole === 'walker' ? Walker : Sitter).findById(provDoc._id).select('walletBalance').lean();
    // Règle LUE dans le code : la confirmation du propriétaire libère tout de suite la part du
    // prestataire vers son portefeuille (confirmationStatus « confirmed », payoutStatus « completed »).
    note('6 fin confirmée : part du prestataire créditée', 'tous', porte,
      b2.confirmationStatus === 'confirmed' && b2.payoutStatus === 'completed' && Math.abs((provAfter.walletBalance || 0) - (b2.pricing.netPayout || 0)) < 0.011,
      `confirmation ${b2.confirmationStatus} · versement ${b2.payoutStatus} · portefeuille prestataire ${provAfter.walletBalance} (attendu ${b2.pricing.netPayout}) · statut de la réservation resté « ${b2.status} »`);
    await (provRole === 'walker' ? Walker : Sitter).updateOne({ _id: provDoc._id }, { $set: { walletBalance: 0 } });
    // Avis des deux côtés.
    const rv1 = await call('POST', '/reviews', tO, { bookingId: String(bookingId), rating: 5, comment: 'Parfait, merci.', revieweeId: String(provDoc._id), revieweeRole: provRole, sitterId: provRole === 'sitter' ? String(provDoc._id) : undefined, walkerId: provRole === 'walker' ? String(provDoc._id) : undefined });
    note('6 laisse un avis', 'propriétaire', porte, rv1.status === 201 || rv1.status === 200, `HTTP ${rv1.status}${rv1.status >= 300 ? ' ' + JSON.stringify(rv1.body).slice(0, 200) : ''}`);
    const rv2 = await call('POST', '/reviews', provTok, { bookingId: String(bookingId), rating: 5, comment: 'Propriétaire très clair.', revieweeId: String(O._id), revieweeRole: 'owner', ownerId: String(O._id) });
    note('6 laisse un avis', provRole, porte, rv2.status === 201 || rv2.status === 200, `HTTP ${rv2.status}${rv2.status >= 300 ? ' ' + JSON.stringify(rv2.body).slice(0, 200) : ''}`);
  };

  await circuit({ nom: SANS_ANIMAL ? 'GARDE sans animal enregistré' : 'GARDE (gardien)', service: 'house_sitting', provRole: 'sitter', provTok: tS, provDoc: S, autreTok: tD2s, autreDoc: D2s, porte: 'accueil / profil' });
  await circuit({ nom: SANS_ANIMAL ? 'BALADE sans animal enregistré' : 'BALADE (promeneur)', service: 'dog_walking', provRole: 'walker', provTok: tW, provDoc: W, autreTok: tD2w, autreDoc: D2w, porte: 'PawMap' });

  // Refus d'une candidature : le prestataire est prévenu.
  if (!SANS_ANIMAL) {
    console.log('\n================ REFUS d’une candidature ================');
    resetCapt(); const t0 = new Date();
    const start = new Date(Date.now() + 9 * 86400000); start.setUTCHours(15, 0, 0, 0);
    const pub = await call('POST', '/posts', tO, { body: 'Autre balade', serviceTypes: ['dog_walking'], serviceLocation: 'at_owner', walkDurationMinutes: 30, startDate: start.toISOString(), endDate: new Date(start.getTime() + 1800000).toISOString(), location: { city: 'Zone test', lat: -35, lng: -30 }, petIds: [String(pet._id)] });
    const postId = pub.body.post && (pub.body.post.id || pub.body.post._id);
    const ap = await call('POST', `/applications?ownerId=${O._id}`, tW, { petIds: [String(pet._id)], serviceType: 'dog_walking', serviceDate: start.toISOString(), startDate: start.toISOString(), timeSlot: '3:00 PM', basePrice: 10, duration: 30, postId: String(postId) });
    const aid = ap.body.application && (ap.body.application.id || ap.body.application._id);
    const rj = aid ? await call('POST', `/applications/${aid}/respond`, tO, { action: 'reject' }) : { status: 0 };
    await wait(900);
    const c = aid ? await canaux(W._id, 'walker', 'application_rejected', t0) : { cloche: 0, push: 0, mail: 0 };
    c.mail = mails.filter((m) => m.to === W.email && /refus/i.test(`${m.subject} ${m.text}`)).length;
    note('refus : le prestataire est prévenu', 'promeneur', 'accueil', rj.status === 200 && c.cloche === 1 && c.push === 1 && c.mail === 1, `HTTP ${rj.status} · cloche ${c.cloche} · téléphone ${c.push} · e-mail ${c.mail} · « ${c.corps || ''} »`);
  }

  const ko = tableau.filter((l) => l.ok === false);
  console.log(`\n--- BILAN : ${tableau.filter((l) => l.ok === true).length} étapes OK, ${ko.length} KO ---`);
  for (const l of ko) console.log(`KO → ${l.etape} | ${l.role} | ${l.porte} | ${l.detail}`);
  sockO.disconnect(); sockS.disconnect(); sockW.disconnect();
  server.close(); await mongoose.disconnect(); await mongo.stop();
  process.exit(0);
})().catch((e) => { console.error('ÉCHEC', e); process.exit(1); });
