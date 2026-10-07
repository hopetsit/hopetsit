/* eslint-disable no-console */
/**
 * 616 (ZOE, 08/10/2026) — BANC LOCAL « position depuis la ville » (jamais la production).
 * Vrai serveur HTTP (127.0.0.1:5617), base Mongo EN MÉMOIRE, vraies routes ;
 * VRAIS Nominatim et Photon (une dizaine de requêtes, User-Agent identifiant,
 * 1 req/s) ; Firebase et SMTP = capteurs (rien ne sort, tout est compté).
 *   node scripts/banc_city_position_616.js
 */
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.CITY_POSITION_AUTO_IN_TESTS = '1';
process.env.ENCRYPTION_KEY = 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

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
stub('../src/config/firebaseAdmin', () => ({ messaging: () => ({ sendEachForMulticast: async (m) => { pushes.push(m); return { successCount: 0, failureCount: 0, responses: [] }; } }) }));
stub('../src/services/emailService', (a) => ({ ...a, sendEmail: async (to, subject) => { mails.push({ to, subject }); return { messageId: 'capté' }; } }));

const PORT = 5617;
const tok = (id, role) => jwt.sign({ id: String(id), role }, process.env.JWT_SECRET, { expiresIn: '1h' });
const call = async (method, path, token, body) => {
  const r = await fetch(`http://127.0.0.1:${PORT}/api/v1${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let j = null; try { j = await r.json(); } catch (_) { j = null; }
  return { status: r.status, body: j };
};
const sleep = (ms) => new Promise((r) => { setTimeout(r, ms); });
const km = (a, b) => {
  const R = 6371; const r = (d) => (d * Math.PI) / 180;
  const s = Math.sin(r(b[1] - a[1]) / 2) ** 2 + Math.cos(r(a[1])) * Math.cos(r(b[1])) * Math.sin(r(b[0] - a[0]) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
};

(async () => {
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const app = require('../src/app');
  const server = http.createServer(app);
  await new Promise((r) => server.listen(PORT, '127.0.0.1', r));
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init()]);
  const cp = require('../src/utils/cityPosition616');
  const full = (M, id) => M.findById(id).select('+homeLocation +positionFromCity').lean();
  const out = (k, v) => console.log(`${k.padEnd(48)} ${typeof v === 'string' ? v : JSON.stringify(v)}`);

  // 1) Inscription RÉELLE par la route de l'app : pet-sitter « STOCKHOLM », sans GPS.
  const su = await call('POST', '/auth/signup', null, {
    role: 'sitter',
    user: { name: 'Astrid Banc', email: 'astrid.banc616@example.test', password: 'Banc-616-motdepasse', city: 'STOCKHOLM', country: 'SE' },
  });
  out('1. POST /auth/signup (sitter, STOCKHOLM)', `HTTP ${su.status}`);
  let astrid = await Sitter.findOne({ name: 'Astrid Banc' }).select('_id').lean();
  for (let i = 0; i < 20; i += 1) { // eslint-disable-line no-await-in-loop
    const d = await full(Sitter, astrid._id); // eslint-disable-line no-await-in-loop
    if (d.location && d.location.coordinates) { astrid = d; break; }
    await sleep(500); // eslint-disable-line no-await-in-loop
  }
  out('   position posée (vrai Nominatim)', astrid.location && astrid.location.coordinates);
  out('   marqueur source ville', astrid.positionFromCity && astrid.positionFromCity.provider);

  // 2) Comptes anciens sans position (comme en prod), insérés tels quels.
  const ins = async (M, doc) => String((await M.collection.insertOne({ status: 'active', ...doc })).insertedId);
  const legacy = {
    montpellier: await ins(Owner, { name: 'Mo', email: 'mo616@example.test', city: 'Montpellier' }),
    newyork: await ins(Walker, { name: 'Ny', email: 'ny616@example.test', city: 'New York', country: 'US' }),
    copenhague: await ins(Sitter, { name: 'Co', email: 'co616@example.test', city: 'Copenhague' }),
    neuilly: await ins(Sitter, { name: 'Ne', email: 'ne616@example.test', city: 'Neuilly-sur-Marne' }),
    asnieres: await ins(Owner, { name: 'As', email: 'as616@example.test', city: 'Asnières' }),
    wv: await ins(Owner, { name: 'Wv', email: 'wv616@example.test', city: 'West Virginia' }),
    dash: await ins(Owner, { name: 'Da', email: 'da616@example.test', city: '—' }),
    test: await ins(Walker, { name: 'Te', email: 'dadaciao84+testwalker616@gmail.com', city: 'Paris' }),
  };
  const admin = tok(new mongoose.Types.ObjectId(), 'admin');
  const viewerId = await ins(Walker, { name: 'Lecteur', email: 'lecteur616@example.test', location: { type: 'Point', coordinates: [-30.4, -35.2] } });

  // 3) Route admin : refus sans droits, simulation, puis écriture.
  out('2. sans jeton admin', `HTTP ${(await call('POST', '/admin/positions-from-city?dryRun=1', tok(viewerId, 'walker'))).status}`);
  const t0 = Date.now();
  const dry = await call('POST', '/admin/positions-from-city?dryRun=1', admin);
  out('3. simulation ?dryRun=1', `HTTP ${dry.status} en ${Date.now() - t0} ms`);
  out('   compteurs', { examined: dry.body.examined, wouldSet: dry.body.wouldSet, skipped: dry.body.skipped, reasons: dry.body.reasons });
  for (const r of dry.body.rows) out(`   ${r.role} « ${r.city} »`, r.status === 'would_set' ? `→ ${r.lat}, ${r.lng} (${r.label || r.source})` : `laissé : ${r.reason}${r.candidates ? ` (${r.candidates.km} km entre les 2 sources)` : ''}`);
  out('   e-mail dans la réponse ?', /@/.test(JSON.stringify(dry.body)) ? 'OUI (ERREUR)' : 'non');
  out('   rien écrit par la simulation ?', (await full(Owner, legacy.montpellier)).location ? 'ÉCRIT (ERREUR)' : 'rien écrit');
  const real = await call('POST', '/admin/positions-from-city', admin);
  out('4. écriture', { set: real.body.set, skipped: real.body.skipped, reasons: real.body.reasons });
  const again = await call('POST', '/admin/positions-from-city', admin);
  out('5. 2e passage (idempotent)', { set: again.body.set, examined: again.body.examined });
  const fix = await call('POST', '/admin/positions-from-city', admin, { cityQueries: { Asnières: 'Asnières-sur-Seine' } });
  const asn = await full(Owner, legacy.asnieres);
  out('6. Asnières précisé « Asnières-sur-Seine »', { set: fix.body.set, coords: asn.location && asn.location.coordinates, kmParis: asn.location ? Math.round(km(asn.location.coordinates, [2.3522, 48.8566])) : null });

  // 4) La carte : un non-ami voit la pet-sitter de Stockholm, floutée.
  const w = await call('GET', '/friends/members/world', tok(viewerId, 'walker'));
  const m = (w.body.members || []).find((x) => x.id === String(astrid._id));
  out('7. GET /friends/members/world (non-ami)', `HTTP ${w.status}, ${(w.body.members || []).length} membres`);
  out('   Astrid visible ?', m ? `oui, approx=${m.approx}, ${km(m.location.coordinates, astrid.location.coordinates).toFixed(2)} km du point enregistré` : 'NON');

  // 5) Sa 1re vraie position GPS (à ~6 km du centre) remplace le centre-ville.
  const gps = { lat: astrid.location.coordinates[1] + 0.054, lng: astrid.location.coordinates[0], city: 'Stockholm' };
  const hp = await call('POST', '/users/me/home-position', tok(astrid._id, 'sitter'), gps);
  const after = await full(Sitter, astrid._id);
  out('8. POST /users/me/home-position (GPS à 6 km)', { http: hp.status, ...hp.body });
  out('   nouvelle position = GPS ?', JSON.stringify(after.location.coordinates) === JSON.stringify([gps.lng, gps.lat]) ? 'oui' : `NON ${JSON.stringify(after.location.coordinates)}`);
  out('   encore approximative ?', cp.isCityApprox(after) ? 'OUI (ERREUR)' : 'non');

  out('9. e-mails / push envoyés', { mails: mails.filter((x) => !/verif|code|activ/i.test(String(x.subject))).length, mailsVerification: mails.length, pushes: pushes.length });
  out('   notifications (cloche)', await require('../src/models/Notification').countDocuments({}));

  server.close(); await mongoose.disconnect(); await mongo.stop();
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
