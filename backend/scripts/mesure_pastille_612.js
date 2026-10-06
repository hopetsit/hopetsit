/* eslint-disable no-console */
/**
 * 612 (ZOE, 05/10/2026) — MESURE locale, jamais la production.
 *
 * Rejoue, sur un vrai serveur lancé sur 127.0.0.1 (base Mongo en mémoire, vraies
 * routes, vraie prise temps réel), ce que fait l'app d'un destinataire quand un
 * message de chat arrive. Aucun push ni e-mail réel : Firebase est remplacé par un
 * capteur, le SMTP n'est pas configuré (les e-mails sont seulement journalisés).
 *
 *   node scripts/mesure_pastille_612.js
 *
 * Le client temps réel vient de website/node_modules (socket.io-client).
 */
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.ENCRYPTION_KEY = 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const path = require('path');
const http = require('http');
const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

// Capteur de push à la place de Firebase (rien ne sort de la machine).
const pushes = [];
const fbPath = require.resolve('../src/config/firebaseAdmin');
require.cache[fbPath] = {
  id: fbPath, filename: fbPath, loaded: true,
  exports: {
    messaging: () => ({
      sendEachForMulticast: async (m) => {
        pushes.push(m);
        return { successCount: m.tokens.length, failureCount: 0, responses: m.tokens.map(() => ({ success: true })) };
      },
    }),
  },
};

const { io: ioClient } = require(path.resolve(__dirname, '../../website/node_modules/socket.io-client'));

const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' });

(async () => {
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const app = require('../src/app');
  const createSocketServer = require('../src/sockets');
  const server = http.createServer(app);
  createSocketServer(server);
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const api = async (method, p, token, body) => {
    const r = await fetch(`${base}/api/v1${p}`, {
      method,
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'X-App-Version': '611', 'X-App-Platform': 'ios' },
      body: body ? JSON.stringify(body) : undefined,
    });
    let j = null; try { j = await r.json(); } catch (_) { /* vide */ }
    return { status: r.status, body: j };
  };

  const Owner = require('../src/models/Owner');
  const Sitter = require('../src/models/Sitter');
  const Walker = require('../src/models/Walker');
  const Conversation = require('../src/models/Conversation');
  const Notification = require('../src/models/Notification');

  // A = le destinataire (une personne, 3 profils, iPhone 611). B = l'expéditeur.
  const mailA = 'dest612+test@example.test';
  const dev = [{ token: 'jeton-iphone-A', platform: 'ios', appBuild: 611 }];
  const aOwner = await Owner.create({ name: 'Dest Test', email: mailA, password: 'MotDePasse612!', fcmTokens: ['jeton-iphone-A'], fcmDevices: dev, isStaff: process.argv.includes('--staff') });
  await Sitter.create({ name: 'Dest Test', email: mailA, password: 'MotDePasse612!' });
  await Walker.create({ name: 'Dest Test', email: mailA, password: 'MotDePasse612!' });
  const b = await Owner.create({ name: 'Exp Test', email: 'exp612+test@example.test', password: 'MotDePasse612!' });
  const AMIS = !process.argv.includes('--reservation');
  const bSitter = await Sitter.create({ name: 'Exp Test', email: 'exp612+test@example.test', password: 'MotDePasse612!' });
  console.log(AMIS ? '##### FIL ENTRE AMIS (friendChat) #####' : '##### FIL DE RÉSERVATION (propriétaire ↔ gardien) #####');
  const conv = AMIS
    ? await Conversation.create({
      friendChat: true,
      participants: [
        { userId: aOwner._id, userModel: 'Owner', unreadCount: 0 },
        { userId: b._id, userModel: 'Owner', unreadCount: 0 },
      ],
    })
    : await Conversation.create({ ownerId: aOwner._id, sitterId: bSitter._id });
  const cid = String(conv._id);
  const tA = tok(aOwner._id, 'owner');
  const tB = AMIS ? tok(b._id, 'owner') : tok(bSitter._id, 'sitter');

  const etat = async (titre) => {
    const list = await api('GET', '/conversations/list', tA);
    const row = (list.body?.conversations || []).find((c) => String(c._id || c.id) === cid);
    const bell = await Notification.find({ recipientId: aOwner._id, type: 'NEW_MESSAGE' }).lean();
    const cnt = await api('GET', '/notifications/my/unread-count', tA);
    const out = {
      etape: titre,
      pastilleChatServeur: row ? row.unreadCount : `fil absent (HTTP ${list.status})`,
      clocheEntrees: bell.length,
      clocheNonLues: bell.filter((n) => !n.readAt).length,
      compteurCloche: cnt.body,
      pushEnvoyes: pushes.length,
    };
    console.log(JSON.stringify(out));
    return out;
  };

  // ── L'app de A : prise connectée, comme SocketService.connect() ──────────
  const recu = [];
  const sock = ioClient(base, { transports: ['websocket'], auth: { token: tA } });
  sock.onAny((ev, p) => { recu.push({ ev, conv: p && p.conversationId, type: p && p.type }); });
  await new Promise((r) => sock.on('connect', r));
  sock.emit('user:identify', { role: 'owner', userId: String(aOwner._id) });
  sock.emit('presence:state', { foreground: true });
  await wait(200);

  console.log('=== CAS 1 : app ouverte sur l’accueil, fil JAMAIS ouvert dans cette session ===');
  pushes.length = 0; recu.length = 0;
  await api('POST', `/conversations/${cid}/messages`, tB, { body: 'message 1' });
  await wait(600);
  console.log('  prise reçu :', JSON.stringify(recu.map((r) => r.ev)));
  await etat('après message 1');

  console.log('=== A ouvre le fil (comme loadChatMessages) puis REVIENT à la liste / à l’accueil ===');
  const ack = await new Promise((r) => {
    sock.emit('conversation:join', { conversationId: cid, role: 'owner', userId: String(aOwner._id) }, (a) => r(a));
    setTimeout(() => r({ status: 'sans réponse' }), 1500);
  });
  console.log('  entrée dans la salle du fil :', JSON.stringify({ status: ack && ack.status, error: ack && ack.error, code: ack && ack.code }));
  sock.emit('conversation:read', { conversationId: cid, role: 'owner', userId: String(aOwner._id) });
  await api('POST', `/conversations/${cid}/read`, tA);
  await api('GET', `/conversations/${cid}/messages`, tA);
  await wait(500);
  await etat('fil lu');
  if (process.argv.includes('--quitte')) {
    // Ce que fait l'app CORRIGÉE (612) en quittant l'écran de discussion.
    sock.emit('conversation:leave', { conversationId: cid });
    await wait(200);
    console.log('  (app corrigée : conversation:leave émis en quittant l’écran)');
  } else {
    console.log('  (app actuelle ≤ 611 : aucun conversation:leave en quittant l’écran)');
  }

  console.log('=== CAS 1 bis : A a le fil À L’ÉCRAN ; B écrit ; l’app lit 350 ms après (comme _scheduleRead) ===');
  pushes.length = 0; recu.length = 0;
  await api('POST', `/conversations/${cid}/messages`, tB, { body: 'message 1 bis' });
  await wait(350);
  await api('POST', `/conversations/${cid}/read`, tA);
  await wait(900);
  console.log('  prise reçu :', JSON.stringify(recu.map((r) => r.ev)));
  const c1b = await etat('après message 1 bis lu à l’écran');
  if (process.argv.includes('--attendre')) {
    console.log('  (attente de 62 s : la confirmation « fil à l’écran » du serveur 612 expire au bout de 60 s)');
    await wait(62000);
  }
  console.log('=== CAS 2 : A est revenu sur l’ACCUEIL (app au premier plan), B écrit ===');
  pushes.length = 0; recu.length = 0;
  await api('POST', `/conversations/${cid}/messages`, tB, { body: 'message 2' });
  await wait(600);
  console.log('  prise reçu :', JSON.stringify(recu.map((r) => r.ev)));
  const c2 = await etat('après message 2');

  console.log('=== CAS 3 : A lit le fil, puis met l’app en ARRIÈRE-PLAN ; B écrit ===');
  await api('POST', `/conversations/${cid}/read`, tA); await wait(300);
  sock.emit('presence:state', { foreground: false }); await wait(200);
  pushes.length = 0; recu.length = 0;
  await api('POST', `/conversations/${cid}/messages`, tB, { body: 'message 3' });
  await wait(600);
  const c3 = await etat('après message 3 (arrière-plan déclaré)');

  console.log('=== CAS 4 : iPhone qui GÈLE l’app sans prévenir (aucun presence:state) ; B écrit dans les 2 min ===');
  await api('POST', `/conversations/${cid}/read`, tA); await wait(300);
  sock.emit('presence:state', { foreground: true }); await wait(200); // l'app était devant…
  // … puis iOS la suspend : la prise reste ouverte côté serveur, plus rien n'est émis.
  pushes.length = 0; recu.length = 0;
  await api('POST', `/conversations/${cid}/messages`, tB, { body: 'message 4' });
  await wait(600);
  const c4 = await etat('après message 4 (app gelée, prise encore vue « présente »)');

  console.log('=== CAS 5 : app FERMÉE (prise coupée) ; B écrit ===');
  await api('POST', `/conversations/${cid}/read`, tA); await wait(300);
  sock.disconnect(); await wait(400);
  pushes.length = 0;
  await api('POST', `/conversations/${cid}/messages`, tB, { body: 'message 5' });
  await wait(600);
  const c5 = await etat('après message 5 (app fermée)');

  console.log('=== CAS 6 : la cloche après lecture du fil (POST /read) ===');
  await api('POST', `/conversations/${cid}/read`, tA); await wait(500);
  const c6 = await etat('fil lu');

  console.log('--- RÉSUMÉ ---');
  console.log(JSON.stringify({
    cas1bis_cloche_non_lue_alors_que_lu_a_l_ecran: c1b.clocheNonLues,
    cas1bis_push_alors_que_fil_a_l_ecran: c1b.pushEnvoyes,
    cas2_push_app_devant_autre_onglet: c2.pushEnvoyes,
    cas3_push_arriere_plan: c3.pushEnvoyes,
    cas4_push_app_gelee: c4.pushEnvoyes,
    cas5_push_app_fermee: c5.pushEnvoyes,
    cas6_cloche_non_lues_apres_lecture: c6.clocheNonLues,
  }));

  server.close();
  await mongoose.disconnect();
  await mongo.stop();
  process.exit(0);
})().catch((e) => { console.error('ÉCHEC', e); process.exit(1); });
