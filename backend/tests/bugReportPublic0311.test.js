// 03/11 — « Signaler un bug » du site : POST /bug-reports/public, ouvert aux visiteurs.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
const MAILS = [];
jest.mock('../src/services/emailService', () => ({ sendEmail: jest.fn(async (to, subject) => { MAILS.push({ to, subject }); return { messageId: 'm' }; }) }));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, res, next) => (req.headers['x-test-user'] ? (req.user = { id: req.headers['x-test-user'], role: 'owner' }, next()) : res.status(401).json({})),
  optionalAuth: (req, res, next) => { if (req.headers['x-test-user']) req.user = { id: req.headers['x-test-user'], role: 'owner' }; next(); },
}));
const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let BugReport; let Owner;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create({ instance: { launchTimeout: 90000 } });
  await mongoose.connect(mongo.getUri());
  BugReport = require('../src/models/BugReport'); Owner = require('../src/models/Owner');
  app = express(); app.use(express.json()); app.use('/bug-reports', require('../src/routes/bugReportRoutes'));
}, 120000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); }, 60000);

describe('POST /bug-reports/public', () => {
  test('visiteur : e-mail obligatoire ; avec e-mail → enregistré (visitor, web) + e-mail à la boîte', async () => {
    const noMail = await request(app).post('/bug-reports/public').send({ kind: 'problem', description: 'Le bouton payer ne répond pas' });
    expect(noMail.status).toBe(400); expect(noMail.body.code).toBe('EMAIL_REQUIRED');
    const r = await request(app).post('/bug-reports/public').send({ kind: 'problem', description: 'Le bouton payer ne répond pas', email: 'Visiteur.Test@example.org', screen: 'web:/pricing' });
    expect(r.status).toBe(200);
    const d = await BugReport.findById(r.body.reportId).lean();
    expect(d).toMatchObject({ userRole: 'visitor', userEmail: 'visiteur.test@example.org', platform: 'web', kind: 'bug', screen: 'web:/pricing', userId: null });
    await new Promise((x) => setTimeout(x, 20));
    expect(MAILS.length).toBe(1);
  });
  test('trop court → 400 ; champ piège rempli → 200 sans rien écrire', async () => {
    expect((await request(app).post('/bug-reports/public').send({ description: 'abc', email: 'a@b.fr' })).status).toBe(400);
    const n = await BugReport.countDocuments({});
    const r = await request(app).post('/bug-reports/public').send({ description: 'Spam spam spam spam', email: 'a@b.fr', website: 'http://x' });
    expect(r.status).toBe(200);
    expect(await BugReport.countDocuments({})).toBe(n);
  });
  test('connecté : rattaché au compte (nom et e-mail du compte)', async () => {
    const o = await Owner.create({ name: 'Camille Durand', email: 'camille.bug0311@example.org', password: 'MotDePasse0311!', acceptedTerms: true, city: 'Paris', country: 'FR', currency: 'EUR' });
    const r = await request(app).post('/bug-reports/public').set('x-test-user', String(o._id)).send({ kind: 'idea', description: 'Mode sombre' });
    expect(r.status).toBe(200);
    const d = await BugReport.findById(r.body.reportId).lean();
    expect(d).toMatchObject({ userRole: 'owner', userEmail: 'camille.bug0311@example.org', kind: 'idea' });
    expect(String(d.userId)).toBe(String(o._id));
  });
});
