// 611 (ZOE, 04/10/2026) — point 1 de ~/hopetsit-social/PROCHAIN_BUILD_611.md
// (décision BOB) : animal perdu / trouvé GRATUIT pour tous.
//   · found_pet : gratuit et illimité pour tous (celui qui aide ne paie jamais) ;
//   · lost_pet  : gratuit pour tous ; sans abonnement 1 alerte ACTIVE à la fois
//     par PERSONNE (ses 3 profils confondus) → 409 LOST_PET_ACTIVE avec l'alerte
//     en cours et l'indice d'abonnement ; abonnés : plusieurs ;
//   · une alerte cesse d'être active quand elle est clôturée (supprimée, depuis
//     n'importe lequel des 3 profils), expirée ou masquée par la modération ;
//   · SOS : anti-abus existant gardé (1 par heure), jamais bloqué par la règle ;
//   · /types et /quota reflètent la règle ; visibilité et confirmation inchangées.
// Vraie base Mongo en mémoire, vraies routes ; seules l'authentification et
// l'envoi de notifications sont simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => {
    const id = req.headers['x-test-user'];
    if (!id) return res.status(401).json({ error: 'auth' });
    req.user = { id, role: req.headers['x-test-role'] || 'owner' };
    return next();
  },
  optionalAuth: (req, res, next) => next(),
}));
jest.mock('../src/services/notificationSender', () => ({
  sendNotification: jest.fn(async () => ({})),
}));
jest.mock('../src/services/pawPointsService', () => ({
  awardPoints: jest.fn(async () => null),
  POINTS: { correctReport: 1 },
}));

const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Owner; let Sitter; let Walker; let MapReport; let UserSubscription;
let seq = 0;
const DAY = 24 * 3600 * 1000;
const ZONE = { lat: -35, lng: -30 }; // zone fictive (règle de l'équipe)

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner');
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  MapReport = require('../src/models/MapReport');
  UserSubscription = require('../src/models/UserSubscription');
  await Promise.all([Owner.init(), Sitter.init(), Walker.init(), MapReport.init(), UserSubscription.init()]);
  app = express();
  app.use(express.json());
  app.use('/map-reports', require('../src/routes/mapReportRoutes'));
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

const MODELS = () => ({ owner: Owner, sitter: Sitter, walker: Walker });

async function member(opts = {}) {
  seq += 1;
  const role = opts.role || 'owner';
  const email = opts.email || `membre611_${seq}_${Date.now()}@example.org`;
  const doc = await MODELS()[role].create({ name: `Membre ${seq}`, email, password: 'MotDePasse611!' });
  if (opts.premium) {
    await UserSubscription.create({
      userId: doc._id,
      userModel: role.charAt(0).toUpperCase() + role.slice(1),
      plan: 'premium_monthly',
      status: 'active',
      premiumExpiry: new Date(Date.now() + 30 * DAY),
      currentPeriodEnd: new Date(Date.now() + 30 * DAY),
    });
  }
  return { doc, email, h: { 'x-test-user': String(doc._id), 'x-test-role': role } };
}

const post = (who, type) => request(app).post('/map-reports').set(who.h)
  .send({ type, ...ZONE, city: 'Zone test' });
const quota = (who) => request(app).get('/map-reports/quota').set(who.h);

describe('ANIMAL TROUVÉ — gratuit et illimité pour tous', () => {
  test('sans abonnement : 6 « animal trouvé » d\'affilée, tous acceptés', async () => {
    const free = await member();
    for (let i = 0; i < 6; i += 1) await post(free, 'found_pet').expect(201);
    // Le compteur « perdu » n'est pas touché par les « trouvé ».
    const q = (await quota(free).expect(200)).body;
    expect(q.lostPet).toMatchObject({ unlimited: false, limit: 1, active: 0, remaining: 1 });
  });
});

describe('ANIMAL PERDU — gratuit, 1 alerte active à la fois sans abonnement', () => {
  test('1re acceptée ; 2e refusée tant que la 1re est active (réponse claire + indice d\'abonnement)', async () => {
    const free = await member();
    let q = (await quota(free).expect(200)).body;
    expect(q.lostPet).toMatchObject({ unlimited: false, limit: 1, active: 0, remaining: 1, activeReportId: null });

    const first = (await post(free, 'lost_pet').expect(201)).body.report;
    q = (await quota(free).expect(200)).body;
    expect(q.lostPet).toMatchObject({ active: 1, remaining: 0, activeReportId: String(first._id) });
    expect(new Date(q.lostPet.activeExpiresAt).getTime()).toBe(new Date(first.expiresAt).getTime());

    const refused = await post(free, 'lost_pet').expect(409);
    expect(refused.body).toMatchObject({
      code: 'LOST_PET_ACTIVE',
      limit: 1,
      activeReportId: String(first._id),
      upgradeUrl: '/subscriptions/plans',
    });
    expect(refused.body.error).toMatch(/already have an active lost pet alert/i);
    expect(refused.body.subscriptionHint).toMatch(/subscription/i);
    expect(new Date(refused.body.activeExpiresAt).getTime()).toBe(new Date(first.expiresAt).getTime());
    expect(await MapReport.countDocuments({ reporterId: free.doc._id, type: 'lost_pet' })).toBe(1);

    // Pendant ce temps, aider reste possible : « trouvé » et danger acceptés.
    await post(free, 'found_pet').expect(201);
    await post(free, 'poison').expect(201);
  });

  test('accepté de nouveau après clôture (suppression de l\'alerte en cours)', async () => {
    const free = await member();
    const first = (await post(free, 'lost_pet').expect(201)).body.report;
    await post(free, 'lost_pet').expect(409);
    await request(app).delete(`/map-reports/${first._id}`).set(free.h).expect(200);
    const q = (await quota(free).expect(200)).body;
    expect(q.lostPet).toMatchObject({ active: 0, remaining: 1 });
    await post(free, 'lost_pet').expect(201);
  });

  test('accepté de nouveau après expiration de l\'alerte en cours', async () => {
    const free = await member();
    const first = (await post(free, 'lost_pet').expect(201)).body.report;
    await post(free, 'lost_pet').expect(409);
    await MapReport.collection.updateOne(
      { _id: new mongoose.Types.ObjectId(first._id) },
      { $set: { expiresAt: new Date(Date.now() - 60000) } },
    );
    await post(free, 'lost_pet').expect(201);
  });

  test('une alerte masquée par la modération ne compte plus comme active', async () => {
    const free = await member();
    const first = (await post(free, 'lost_pet').expect(201)).body.report;
    await MapReport.collection.updateOne(
      { _id: new mongoose.Types.ObjectId(first._id) },
      { $set: { hidden: true } },
    );
    await post(free, 'lost_pet').expect(201);
  });

  test('3 profils = une personne : refusé sur les 2 autres profils, clôture possible depuis n\'importe lequel', async () => {
    const asOwner = await member();
    const asSitter = await member({ role: 'sitter', email: asOwner.email });
    const asWalker = await member({ role: 'walker', email: asOwner.email });
    const first = (await post(asOwner, 'lost_pet').expect(201)).body.report;

    const r1 = await post(asSitter, 'lost_pet').expect(409);
    expect(r1.body.activeReportId).toBe(String(first._id));
    await post(asWalker, 'lost_pet').expect(409);
    const q = (await quota(asWalker).expect(200)).body;
    expect(q.lostPet).toMatchObject({ active: 1, remaining: 0, activeReportId: String(first._id) });

    // Clôture depuis le profil promeneur (une autre personne ne le peut pas).
    const stranger = await member();
    await request(app).delete(`/map-reports/${first._id}`).set(stranger.h).expect(403);
    await request(app).delete(`/map-reports/${first._id}`).set(asWalker.h).expect(200);
    await post(asSitter, 'lost_pet').expect(201);
  });

  test('deux envois simultanés sans abonnement : une seule alerte créée', async () => {
    const free = await member();
    const res = await Promise.all([1, 2, 3].map(() => post(free, 'lost_pet')));
    const codes = res.map((r) => r.status).sort();
    expect(codes).toEqual([201, 409, 409]);
    expect(await MapReport.countDocuments({ reporterId: free.doc._id, type: 'lost_pet' })).toBe(1);
  });
});

describe('ABONNÉS — plusieurs alertes animal perdu en même temps', () => {
  test('3 alertes actives acceptées, quota illimité', async () => {
    const sub = await member({ premium: true });
    for (let i = 0; i < 3; i += 1) await post(sub, 'lost_pet').expect(201);
    for (let i = 0; i < 3; i += 1) await post(sub, 'found_pet').expect(201);
    const q = (await quota(sub).expect(200)).body;
    expect(q.isPremium).toBe(true);
    expect(q.lostPet).toMatchObject({ unlimited: true, limit: null });
    expect(await MapReport.countDocuments({ reporterId: sub.doc._id, type: 'lost_pet' })).toBe(3);
  });
});

describe('/types reflète la règle', () => {
  test('perdu/trouvé ne sont plus réservés aux abonnés', async () => {
    const t = (await request(app).get('/map-reports/types').expect(200)).body;
    expect(t.premiumCreateTypes).toEqual([]);
    expect(t.petAlertTypes.sort()).toEqual(['found_pet', 'lost_pet']);
    expect(t.freeUnlimitedTypes).toContain('found_pet');
    expect(t.freeUnlimitedTypes).not.toContain('lost_pet');
    expect(t.lostPetActiveLimit).toBe(1);
    // Inchangé : le confort reste 1 par semaine, les dangers gratuits.
    expect(t.comfortWeeklyLimit).toBe(1);
    expect(t.dangerTypes).toContain('poison');
  });
});

describe('SOS — anti-abus existant gardé, jamais bloqué par la règle', () => {
  const sos = (who) => request(app).post('/map-reports/sos').set(who.h).send({ ...ZONE, city: 'Zone test' });

  test('un SOS passe même avec une alerte perdue active ; 2e SOS dans l\'heure = 429 SOS_COOLDOWN', async () => {
    const free = await member();
    await post(free, 'lost_pet').expect(201);
    const s1 = await sos(free).expect(201);
    expect(s1.body.report.isSos).toBe(true);
    const s2 = await sos(free).expect(429);
    expect(s2.body.code).toBe('SOS_COOLDOWN');
  });

  test('un SOS en cours compte comme l\'alerte active (sans abonnement)', async () => {
    const free = await member();
    const s = (await sos(free).expect(201)).body.report;
    const r = await post(free, 'lost_pet').expect(409);
    expect(r.body.activeReportId).toBe(String(s._id));
  });
});

describe('VISIBILITÉ et CONFIRMATION inchangées', () => {
  test('un membre sans abonnement voit perdu + trouvé et confirme « perdu » et « trouvé » gratuitement', async () => {
    const author = await member();
    const viewer = await member();
    const lost = (await post(author, 'lost_pet').expect(201)).body.report;
    const found = (await post(author, 'found_pet').expect(201)).body.report;
    const near = (await request(app).get('/map-reports/nearby')
      .query({ ...ZONE, radiusKm: 5 }).set(viewer.h).expect(200)).body;
    const ids = near.reports.map((x) => String(x._id));
    expect(ids).toEqual(expect.arrayContaining([String(lost._id), String(found._id)]));
    const c = await request(app).post(`/map-reports/${lost._id}/confirm`).set(viewer.h).expect(200);
    expect(c.body.confirmationsCount).toBe(1);
    // 611 (BOB, 04/10) — confirmer un « trouvé » devient GRATUIT pour tous.
    const cf = await request(app).post(`/map-reports/${found._id}/confirm`).set(viewer.h).expect(200);
    expect(cf.body.confirmationsCount).toBe(1);
    // Fiche publique (lien partagé) : inchangée.
    await request(app).get(`/map-reports/public/${lost._id}`).expect(200);
  });
});

describe('CONFIRMER — plus aucun 402 (décision BOB du 04/10)', () => {
  test('sans abonnement : confirmer trouvé, confort et info utile = 200', async () => {
    const author = await member({ premium: true });
    const free = await member();
    for (const t of ['found_pet', 'poop', 'no_dogs_zone', 'water_active']) {
      const rep = (await post(author, t).expect(201)).body.report;
      const r = await request(app).post(`/map-reports/${rep._id}/confirm`).set(free.h).expect(200);
      expect(r.body.confirmationsCount).toBe(1);
    }
  });
});
