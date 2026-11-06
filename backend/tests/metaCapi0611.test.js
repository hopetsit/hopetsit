// 06/11/2026 (SAM, ordre de Daniel « oui fais tout ») — Meta Conversions API côté serveur :
// hachage de l'e-mail, aucun envoi pour une adresse de test, aucun envoi si non configuré, coupe-circuit,
// Lead envoyé UNE fois quand la page merci publie (vraie route /ad-leads/thanks/confirm, Mongo mémoire,
// Graph simulé), Purchase avec montant + devise, jamais bloquant si Graph tombe.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
process.env.POSTAL_GEOCODE = 'off';
jest.mock('../src/services/translationService', () => ({ translateToAll: jest.fn(async (text) => ({ translations: { fr: text }, sourceLanguage: 'fr' })) }));
jest.mock('../src/services/notificationService', () => ({ createNotificationSafe: jest.fn(async () => null) }));
jest.mock('../src/services/notificationSender', () => ({ sendNotification: jest.fn(async () => null), leadOwnerEmailLink: jest.fn(async (r, u, l) => l) }));
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
jest.mock('../src/services/cloudinary', () => ({ uploadMedia: jest.fn(async () => ({})) }));
jest.mock('../src/services/contentModerationService', () => ({ rejectIfUnsafe: jest.fn(async () => null) }));
jest.mock('../src/services/emailService', () => ({ sendEmail: jest.fn(async () => ({ messageId: 'mock' })), sendTemplatedEmail: jest.fn(async () => ({})) }));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => { const id = req.headers['x-test-user']; if (!id) return res.status(401).json({ error: 'auth' }); req.user = { id, role: req.headers['x-test-role'] || 'owner' }; return next(); },
  requireRole: (...roles) => (req, res, next) => (roles.includes(req.user.role) ? next() : res.status(403).json({ error: 'forbidden' })),
  optionalAuth: (req, res, next) => next(),
}));
// La config CAPI (pixel + jeton) vit dans la route metaLeadgen0511 ; ici on la simule : configurée.
const CAPI_CFG = { pixelId: '972651422131697', token: 'jeton-test' };
jest.mock('../src/routes/metaLeadgen0511', () => ({ getCapiConfig: jest.fn(async () => CAPI_CFG) }));

const crypto = require('crypto');
const express = require('express');
const request = require('supertest');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const capi = require('../src/services/metaCapi0611');

const okFetch = () => jest.fn(async () => ({ ok: true, status: 200, json: async () => ({ events_received: 1 }) }));
const cfg = () => ({ pixelId: CAPI_CFG.pixelId, token: CAPI_CFG.token });
const BROWSER = { 'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Safari/604.1' };

describe('sendEvent (unitaire, fetch simulé)', () => {
  afterEach(() => { delete process.env.META_CAPI_0611; });

  test('e-mail haché SHA-256 en minuscules, action_source website, event_id, custom_data', async () => {
    const fetchImpl = okFetch();
    const r = await capi.sendEvent({ name: 'Purchase', email: '  Jeanne.CAPI0611@Exemple-domaine.fr ', value: 72, currency: 'eur', eventId: 'bk1', sourceUrl: 'https://www.hopetsit.com/application/x' }, { fetch: fetchImpl, getConfig: cfg, now: () => 1_762_430_400_000 });
    expect(r.sent).toBe(true);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe(`https://graph.facebook.com/v21.0/${CAPI_CFG.pixelId}/events?access_token=jeton-test`);
    const body = JSON.parse(init.body);
    const ev = body.data[0];
    expect(ev.event_name).toBe('Purchase');
    expect(ev.event_time).toBe(1_762_430_400);
    expect(ev.action_source).toBe('website');
    expect(ev.event_id).toBe('bk1');
    expect(ev.event_source_url).toBe('https://www.hopetsit.com/application/x');
    expect(ev.user_data.em).toEqual([crypto.createHash('sha256').update('jeanne.capi0611@exemple-domaine.fr').digest('hex')]);
    expect(ev.custom_data).toEqual({ value: 72, currency: 'EUR' });
    expect(JSON.stringify(body)).not.toContain('Jeanne'); // jamais l'e-mail en clair
    expect(body.test_event_code).toBeUndefined();
  });

  test('adresse de test (+test, example.com, .test) → aucun envoi', async () => {
    const fetchImpl = okFetch();
    for (const email of ['dadaciao84+testowner@gmail.com', 'x@example.com', 'jeanne.thanks0511@example.test', 'hopetsit@gmail.com']) {
      expect(await capi.sendEvent({ name: 'Lead', email }, { fetch: fetchImpl, getConfig: cfg })).toEqual({ sent: false, reason: 'email_test' });
    }
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test('non configuré (pas de pixel ou pas de jeton) → aucun envoi ; e-mail invalide → aucun envoi', async () => {
    const fetchImpl = okFetch();
    expect(await capi.sendEvent({ name: 'Lead', email: 'a@b.fr' }, { fetch: fetchImpl, getConfig: async () => ({ pixelId: '', token: 'x' }) })).toEqual({ sent: false, reason: 'non_configure' });
    expect(await capi.sendEvent({ name: 'Lead', email: 'a@b.fr' }, { fetch: fetchImpl, getConfig: async () => ({ pixelId: '972651422131697', token: '' }) })).toEqual({ sent: false, reason: 'non_configure' });
    expect(await capi.sendEvent({ name: 'Lead', email: 'pas-un-email' }, { fetch: fetchImpl, getConfig: cfg })).toEqual({ sent: false, reason: 'email_invalide' });
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test('coupe-circuit META_CAPI_0611=off → aucun envoi', async () => {
    process.env.META_CAPI_0611 = 'off';
    const fetchImpl = okFetch();
    expect(await capi.sendEvent({ name: 'Lead', email: 'a@b.fr' }, { fetch: fetchImpl, getConfig: cfg })).toEqual({ sent: false, reason: 'off' });
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test('Graph refuse (400) ou tombe (exception) → { sent:false }, jamais de levée', async () => {
    const bad = jest.fn(async () => ({ ok: false, status: 400, json: async () => ({ error: { message: 'x' } }) }));
    expect(await capi.sendEvent({ name: 'Lead', email: 'a@b.fr' }, { fetch: bad, getConfig: cfg })).toMatchObject({ sent: false, reason: 'graph_400' });
    const boom = jest.fn(async () => { throw new Error('réseau'); });
    expect(await capi.sendEvent({ name: 'Lead', email: 'a@b.fr' }, { fetch: boom, getConfig: cfg })).toEqual({ sent: false, reason: 'exception' });
  });

  test('test_event_code transmis quand fourni (script --test)', async () => {
    const fetchImpl = okFetch();
    await capi.sendEvent({ name: 'Lead', email: 'a@b.fr', testEventCode: 'TEST1234' }, { fetch: fetchImpl, getConfig: cfg });
    expect(JSON.parse(fetchImpl.mock.calls[0][1].body).test_event_code).toBe('TEST1234');
  });

  test('bookingPaid : Purchase avec montant Airwallex + devise, e-mail du propriétaire, event_id = réservation', async () => {
    const fetchImpl = okFetch();
    const booking = { _id: 'b0611', ownerId: 'o1', pricing: { totalPrice: 60, currency: 'EUR' } };
    const r = await capi.bookingPaid(booking, { amount: 72, currency: 'EUR' }, { fetch: fetchImpl, getConfig: cfg, findOwner: async () => ({ email: 'proprio@exemple-domaine.fr' }) });
    expect(r.sent).toBe(true);
    const ev = JSON.parse(fetchImpl.mock.calls[0][1].body).data[0];
    expect(ev.event_name).toBe('Purchase');
    expect(ev.event_id).toBe('b0611');
    expect(ev.custom_data.value).toBe(72);
    expect(ev.custom_data.currency).toBe('EUR');
    // sans montant Airwallex : repli sur le prix total de la réservation
    const f2 = okFetch();
    await capi.bookingPaid(booking, {}, { fetch: f2, getConfig: cfg, findOwner: async () => ({ email: 'proprio@exemple-domaine.fr' }) });
    expect(JSON.parse(f2.mock.calls[0][1].body).data[0].custom_data.value).toBe(60);
  });
});

describe('Lead envoyé UNE fois quand la page merci publie (vraie route, Mongo mémoire)', () => {
  let mongo; let app; let AdLead; let Post; let thanks; let realFetch;
  beforeAll(async () => {
    mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
    await mongoose.connect(mongo.getUri());
    const Owner = require('../src/models/Owner');
    Post = require('../src/models/Post');
    AdLead = require('../src/models/AdLead2210');
    await Promise.all([Owner.init(), Post.init(), AdLead.init()]);
    const routes = require('../src/routes/adLeads2210');
    thanks = require('../src/routes/adLeadsThanks0511');
    app = express();
    app.set('trust proxy', 1);
    app.use(express.json());
    app.use('/ad-leads/thanks', thanks);
    app.use('/ad-leads', routes);
    realFetch = global.fetch;
  }, 120000);
  afterAll(async () => { global.fetch = realFetch; await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);
  beforeEach(() => thanks._resetForTest());

  test('1er appui → publication + 1 événement Lead (event_id = id du contact) ; 2e appui → aucun nouvel envoi', async () => {
    const graph = okFetch();
    global.fetch = graph;
    const lead = await AdLead.create({
      metaLeadId: `meta_${Math.random().toString(16).slice(2)}`, email: 'jeanne.capi0611@exemple-domaine.fr', firstName: 'Jeanne',
      city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr', service: 'garde', animal: 'chien', quand: 'bientot', pendingConfirm: true,
    });
    const r = await request(app).post('/ad-leads/thanks/confirm').set(BROWSER).send({ email: 'jeanne.capi0611@exemple-domaine.fr', city: 'paris' });
    expect(r.status).toBe(200);
    expect(r.body.postId).toMatch(/^[a-f0-9]{24}$/);
    // l'envoi est « fire and forget » : on attend un tour de boucle
    await new Promise((res) => setTimeout(res, 300));
    const calls = graph.mock.calls.filter(([u]) => String(u).includes('/events'));
    expect(calls).toHaveLength(1);
    const ev = JSON.parse(calls[0][1].body).data[0];
    expect(ev.event_name).toBe('Lead');
    expect(ev.event_id).toBe(String(lead._id));
    expect(ev.user_data.em[0]).toBe(crypto.createHash('sha256').update('jeanne.capi0611@exemple-domaine.fr').digest('hex'));
    expect(ev.event_source_url).toContain('/ad-leads/thanks/confirm');
    // 2e appui : même demande, pas de 2e Lead
    const r2 = await request(app).post('/ad-leads/thanks/confirm').set(BROWSER).send({ email: 'jeanne.capi0611@exemple-domaine.fr', city: 'paris' });
    expect(r2.status).toBe(200);
    expect(r2.body.existing).toBe(true);
    await new Promise((res) => setTimeout(res, 300));
    expect(graph.mock.calls.filter(([u]) => String(u).includes('/events'))).toHaveLength(1);
    expect(await Post.countDocuments()).toBe(1);
  });

  test('clic e-mail (/ad-leads/:id/confirm) → 1 Lead ; le même lien une 2e fois → rien', async () => {
    const graph = okFetch();
    global.fetch = graph;
    const lead = await AdLead.create({
      metaLeadId: `meta_${Math.random().toString(16).slice(2)}`, email: 'paul.capi0611@exemple-domaine.fr', firstName: 'Paul',
      city: 'Zone test', lat: -35, lng: -30, country: 'FR', lang: 'fr', service: 'promenade', animal: 'chien', quand: 'bientot', pendingConfirm: true,
    });
    const r = await request(app).post(`/ad-leads/${lead._id}/confirm`).set(BROWSER).send({});
    expect(r.status).toBe(200);
    await new Promise((res) => setTimeout(res, 300));
    expect(graph.mock.calls.filter(([u]) => String(u).includes('/events'))).toHaveLength(1);
    expect(JSON.parse(graph.mock.calls[0][1].body).data[0].event_id).toBe(String(lead._id));
    const r2 = await request(app).post(`/ad-leads/${lead._id}/confirm`).set(BROWSER).send({});
    expect(r2.status).toBe(200);
    await new Promise((res) => setTimeout(res, 300));
    expect(graph.mock.calls.filter(([u]) => String(u).includes('/events'))).toHaveLength(1);
  });
});
