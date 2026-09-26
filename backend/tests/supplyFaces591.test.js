// 26/09/2026 (SAM) — GET /supply/city/faces : 3 vrais prestataires autour d'une
// ville, SANS nom de famille, e-mail, date de naissance ni position.
jest.mock('../src/utils/geocodeCity', () => ({
  geocodeCity: async () => ({ lat: 48.8566, lng: 2.3522 }),
  baseCityName: (c) => String(c || '').replace(/\s+\d+\s*(er|e)?$/i, '').trim(),
}));
const mongoose = require('mongoose');
const express = require('express');
const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let app; let Sitter; let Walker;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  await Sitter.init(); await Walker.init();
  app = express();
  app.use('/supply', require('../src/routes/supplyRoutes'));
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

const base = (o) => ({
  name: 'Camille Durand', email: `c${Math.random()}@ex.com`, password: 'x'.repeat(12), phone: '0600000000',
  city: 'Paris', location: { type: 'Point', coordinates: [2.35, 48.86], city: 'Paris' },
  avatar: { url: 'https://res.cloudinary.com/x/a.jpg' }, mapBoostLocation: { type: 'Point', coordinates: [2.35, 48.86] }, ...o,
});
async function creer(Model, o) {
  const d = new Model(base(o));
  await d.save({ validateBeforeSave: false });
  return d;
}

test('renvoie prénom + photo, jamais nom de famille, e-mail ni position', async () => {
  await creer(Sitter, { name: 'Camille Durand', firstName: 'Camille', kycStatus: 'verified' });
  await creer(Walker, { name: 'Hugo Martin', firstName: 'Hugo' });
  await creer(Sitter, { name: 'Sans Photo', avatar: { url: '' } });
  await creer(Sitter, { name: 'Test Compte', email: 'dadaciao84+test9@gmail.com' });
  await creer(Sitter, { name: 'Cache Moi', hiddenFromPublic: true });
  const r = await request(app).get('/supply/city/faces?city=Paris 11e');
  expect(r.status).toBe(200);
  const noms = r.body.faces.map((f) => f.firstName).sort();
  expect(noms).toEqual(['Camille', 'Hugo']);
  const txt = JSON.stringify(r.body);
  expect(txt).not.toMatch(/Durand|Martin|@|coordinates|dateOfBirth/);
  expect(r.body.faces[0].verified).toBe(true);
});

test('ville absente → 400', async () => {
  const r = await request(app).get('/supply/city/faces');
  expect(r.status).toBe(400);
});

test('jamais un identifiant ni un nom de famille probable comme prénom ; la ville même d abord', async () => {
  await Sitter.deleteMany({}); await Walker.deleteMany({});
  await creer(Walker, { name: 'liliachehri', firstName: '' });
  await creer(Sitter, { name: 'fievet', firstName: '', city: 'Courbevoie', location: { type: 'Point', coordinates: [2.25, 48.9], city: 'Courbevoie' } });
  await creer(Sitter, { name: 'Savin', firstName: '', city: 'Bois-d Arcy', location: { type: 'Point', coordinates: [2.03, 48.8], city: 'Bois-d Arcy' } });
  await creer(Walker, { name: 'christine dupont', firstName: '' });
  await creer(Sitter, { name: 'Sasha', firstName: '' });
  const r = await request(app).get('/supply/city/faces?city=Paris&limit=6');
  const noms = r.body.faces.map((f) => f.firstName);
  expect(noms).not.toContain('liliachehri');
  expect(noms).not.toContain('fievet');
  expect(noms).toContain('Christine');
  expect(noms.slice(0, 2).sort()).toEqual(['Christine', 'Sasha']);
  expect(JSON.stringify(r.body)).not.toMatch(/_memeVille|_prenomSur|dupont/i);
});
