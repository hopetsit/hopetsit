// 610 (PAM, 04/10/2026) — lien partagé /alert/<id> : l'app appelle
// GET /map-reports/:id pour centrer la carte (404 jusqu'ici). Modèles simulés.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const HEX = '6ac243f79ee105a67fa6ad31';
const mockReports = [];
jest.mock('../src/models/MapReport', () => {
  const chain = (v) => ({ select: () => chain(v), lean: () => Promise.resolve(v) });
  const M = {
    findById: jest.fn((id) => chain(mockReports.find((r) => String(r._id) === String(id)) || null)),
  };
  M.REPORT_TYPES = ['hazard', 'lost_pet'];
  M.REPORT_TTL_MS = 48 * 3600 * 1000;
  return M;
});
jest.mock('../src/models/UserSubscription', () => ({}));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
jest.mock('../src/middleware/auth', () => ({
  requireAuth: (req, _res, next) => { req.user = { id: 'u1', role: 'owner' }; next(); },
}));

const express = require('express');
const request = require('supertest');
const app = express();
app.use(express.json());
app.use('/map-reports', require('../src/routes/mapReportRoutes'));

describe('610 — GET /map-reports/:id', () => {
  beforeEach(() => { mockReports.length = 0; });
  test('position renvoyée dans location.coordinates (forme lue par l’app), jamais l’auteur', async () => {
    mockReports.push({ _id: HEX, type: 'hazard', reporterId: 'secret', location: { type: 'Point', coordinates: [-30, -35] }, hidden: false });
    const r = await request(app).get(`/map-reports/${HEX}`);
    expect(r.status).toBe(200);
    expect(r.body.report.location.coordinates).toEqual([-30, -35]);
    expect(JSON.stringify(r.body)).not.toContain('secret');
  });
  test('masqué ou id invalide : 404', async () => {
    mockReports.push({ _id: HEX, type: 'hazard', location: { coordinates: [-30, -35] }, hidden: true });
    expect((await request(app).get(`/map-reports/${HEX}`)).status).toBe(404);
    expect((await request(app).get('/map-reports/xyz')).status).toBe(404);
  });
});
