/* eslint-disable no-console */
/**
 * 612 (PAM, 06/10/2026) — BANC LOCAL « carte chargée » pour mesurer l'ouverture
 * de la PawMap sur émulateur Android (jamais la production).
 * Vrai serveur sur 0.0.0.0:5614, base Mongo EN MÉMOIRE, remplie autour de
 * Paris : 100 membres avec photo, 50 PawSpots, 20 signalements, 1 compte
 * propriétaire local (mot de passe = variable BANC_MDP, jamais affiché).
 * L'émulateur s'y branche par http://10.0.2.2:5614 (--dart-define=HPS_API_ROOT).
 *   BANC_MDP=… BANC_IMG=/dossier/des/photos node scripts/banc_carte_612.js
 */
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'silent';
process.env.ENCRYPTION_KEY = 'fa6e6fa345a9f83cb9f350828e1308f5cb9b7d7750202fb316dce12ed3702113';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.PAYMENT_PROVIDER = 'airwallex';
const http = require('http');
const express = require('express');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

const stub = (rel, build) => {
  const p = require.resolve(rel);
  let actual = {};
  try { actual = require(p); } catch (_) { actual = {}; }
  require.cache[p] = { id: p, filename: p, loaded: true, exports: build(actual) };
};
stub('../src/config/firebaseAdmin', () => ({
  messaging: () => ({ sendEachForMulticast: async (m) => ({ successCount: m.tokens.length, failureCount: 0, responses: [] }) }),
}));
stub('../src/services/emailService', (a) => ({ ...a, sendEmail: async () => ({ messageId: 'local' }) }));
try { stub('../src/utils/geocodeCity', (a) => ({ ...a, geocodeCity: async () => null })); } catch (_) { /* facultatif */ }

const PORT = Number(process.env.BANC_PORT || 5614);
const ROOT = process.env.BANC_ROOT || `http://10.0.2.2:${PORT}`;
const C = [2.3522, 48.8566]; // Paris
let seed = 612;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648; };
const near = (km) => {
  const a = rnd() * Math.PI * 2; const d = Math.sqrt(rnd()) * km;
  return [C[0] + (d * Math.cos(a)) / 73.0, C[1] + (d * Math.sin(a)) / 111.3];
};

(async () => {
  const pw = process.env.BANC_MDP;
  if (!pw) throw new Error('BANC_MDP manquant');
  const mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const app = require('../src/app');
  const outer = express();
  outer.use('/img', express.static(process.env.BANC_IMG || '/tmp/banc_img', { maxAge: '1h' }));
  const hits = { n: 0 };
  outer.use((req, res, next) => { hits.n += 1; if (process.env.BANC_TRACE) console.log(Date.now(), req.method, req.url.split('?')[0]); next(); });
  outer.use(app);
  const server = http.createServer(outer);
  require('../src/sockets')(server);
  try { await require('../src/services/pricingService').init(); } catch (_) { /* défaut */ }
  try { await require('../src/services/serviceCatalogService').init(); } catch (_) { /* défaut */ }
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker');
  const PawSpot = require('../src/models/PawSpot'); const MapReport = require('../src/models/MapReport');
  const base = { password: pw, verified: true, appLocale: 'fr', city: 'Paris', country: 'FR', currency: 'EUR' };
  const me = await Owner.create({ ...base, name: 'Banc Local', email: 'banc612@example.test', isStaff: true,
    location: { type: 'Point', coordinates: C, city: 'Paris' }, avatar: { url: `${ROOT}/img/0.jpg` } });
  const N = Number(process.env.BANC_MEMBRES || 100);
  for (let i = 0; i < N; i += 1) {
    const M = [Sitter, Walker, Owner][i % 3];
    const extra = i % 3 === 0 ? { hourlyRate: 10 + (i % 9), dailyRate: 30 + (i % 20), bio: 'Membre du banc local.' }
      : (i % 3 === 1 ? { bio: 'Membre du banc local.', walkRates: [{ durationMinutes: 30, basePrice: 9 + (i % 8), currency: 'EUR', enabled: true }] } : {});
    // eslint-disable-next-line no-await-in-loop
    await M.create({ ...base, ...extra, name: `Membre ${i + 1} Local`, email: `membre${i}@example.test`,
      location: { type: 'Point', coordinates: near(3), city: 'Paris' }, avatar: { url: `${ROOT}/img/${i}.jpg` } });
  }
  const types = PawSpot.PAWSPOT_TYPES || ['path_walk'];
  for (let i = 0; i < 50; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await PawSpot.create({ creatorId: me._id, creatorModel: 'Owner', creatorName: 'Banc', type: types[i % types.length],
      name: `Spot ${i + 1}`, location: { type: 'Point', coordinates: near(3) } }).catch((e) => console.log('spot', e.message));
  }
  const rt = MapReport.REPORT_TYPES || ['poop'];
  for (let i = 0; i < 20; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    await MapReport.create({ type: rt[i % 6], location: { type: 'Point', coordinates: near(3) }, reporterId: me._id,
      reporterModel: 'Owner', expiresAt: new Date(Date.now() + 40 * 3600000) }).catch((e) => console.log('report', e.message));
  }
  await new Promise((r) => server.listen(PORT, '0.0.0.0', r));
  console.log(`banc carte prêt sur :${PORT} — membres ${N}, spots ${await PawSpot.countDocuments()}, signalements ${await MapReport.countDocuments()}`);
})().catch((e) => { console.error('ÉCHEC', e); process.exit(1); });
