// v613 — GET /pricing/commission-rate : taux RÉEL d'un prestataire, calculé par
// la même fonction que la réservation (commissionRateForProvider) : 15 % Top,
// 20 % sinon. L'app l'affiche au lieu d'un 20 % figé. Sans base réelle.
process.env.NODE_ENV = 'test';

const mockDocs = {
  Sitter: { aaaaaaaaaaaaaaaaaaaaaa01: { isTopSitter: false }, aaaaaaaaaaaaaaaaaaaaaa02: { isTopSitter: true } },
  Walker: { bbbbbbbbbbbbbbbbbbbbbb01: { isTopWalker: false }, bbbbbbbbbbbbbbbbbbbbbb02: { isTopWalker: true, isTopSitter: false } },
};
const mockModel = (name) => ({
  findById: (id) => ({ select: () => ({ lean: async () => (mockDocs[name][id] ? { _id: id, ...mockDocs[name][id] } : null) }) }),
});
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));

const { getProviderCommissionRate } = require('../src/controllers/pricingController');
const { calculateTotalWithAddOns, commissionRateForProvider } = require('../src/utils/pricing');

const call = async (query) => {
  const res = { statusCode: 200, body: undefined };
  res.status = (c) => { res.statusCode = c; return res; };
  res.json = (b) => { res.body = b; return res; };
  await getProviderCommissionRate({ query }, res);
  return res;
};

test.each([
  ['sitter', 'aaaaaaaaaaaaaaaaaaaaaa01', false, 0.2, 120],
  ['sitter', 'aaaaaaaaaaaaaaaaaaaaaa02', true, 0.15, 115],
  ['walker', 'bbbbbbbbbbbbbbbbbbbbbb01', false, 0.2, 120],
  ['walker', 'bbbbbbbbbbbbbbbbbbbbbb02', true, 0.15, 115],
])('%s %s (Top=%s) → %s, 100 € → %s € payés', async (role, id, top, rate, total) => {
  const res = await call({ providerId: id, role });
  expect(res.statusCode).toBe(200);
  expect(res.body).toEqual({ providerId: id, role, isTopProvider: top, commissionRate: rate });
  // Même taux que celui que la réservation applique réellement.
  expect(res.body.commissionRate).toBe(commissionRateForProvider(top));
  expect(calculateTotalWithAddOns(100, [], 'EUR', res.body.commissionRate).ownerTotal).toBe(total);
});

test('id invalide → 400, inconnu → 404, rôle inconnu = gardien', async () => {
  expect((await call({ providerId: 'x', role: 'sitter' })).statusCode).toBe(400);
  expect((await call({ providerId: 'cccccccccccccccccccccc01', role: 'sitter' })).statusCode).toBe(404);
  expect((await call({ providerId: 'aaaaaaaaaaaaaaaaaaaaaa02', role: 'nimporte' })).body.commissionRate).toBe(0.15);
});

test('route branchée : GET /pricing/commission-rate (routeur réel)', async () => {
  const express = require('express');
  const request = require('supertest');
  const app = express();
  app.use('/api/v1/pricing', require('../src/routes/pricingRoutes'));
  const r = await request(app).get('/api/v1/pricing/commission-rate?providerId=aaaaaaaaaaaaaaaaaaaaaa02&role=sitter');
  expect(r.status).toBe(200);
  expect(r.body.commissionRate).toBe(0.15);
});
