// 0111 (ADA, bug signalé par Daniel : « Caroline est revenue et quand je mets détails c'est jamais revenu ») —
// UNE seule règle « revenu ? » (returnVerdict) pour la tuile, la carte et le détail, par PERSONNE (3 profils).
// Données FICTIVES, base Mongo en mémoire, vrai boardSignals.
process.env.NODE_ENV = 'test';
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let ActivityEvent; let CandidatesView; let R;
const H = 3600000;
const ins = async (M, doc) => String((await M.collection.insertOne(doc)).insertedId);

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter');
  ActivityEvent = require('../src/models/ActivityEvent'); CandidatesView = require('../src/models/CandidatesView2610');
  R = require('../src/utils/ownerReturn2610');
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

const now = Date.now();
const iso = (agoH) => new Date(now - agoH * H);

describe('returnVerdict (pur)', () => {
  test('jamais revenu du tout → never', () => {
    const b = R.returnVerdict({ publishedAt: iso(5), sessions: [], postViews: [], personViews: [] });
    expect(b.state).toBe('never'); expect(b.lastAt).toBeNull();
  });
  test('revenu AVANT la publication seulement → before, avec la date (pas « jamais »)', () => {
    const b = R.returnVerdict({ publishedAt: iso(5), sessions: [{ at: iso(8), origin: 'app', appVersion: '23.1.6+627' }], postViews: [], personViews: [] });
    expect(b.state).toBe('before'); expect(new Date(b.lastAt).getTime()).toBe(now - 8 * H); expect(b.channel).toBe('app');
  });
  test('ouverture des candidats après la publication, sans nouvelle session → since, via notification', () => {
    const v = { _id: 'v1', postId: 'p1', at: iso(1), channel: 'app', source: 'notification', origin: 'app' };
    const b = R.returnVerdict({ publishedAt: iso(2), sessions: [{ at: iso(3), origin: 'web' }], postViews: [v], personViews: [v] });
    expect(b.state).toBe('since'); expect(b.channel).toBe('app'); expect(b.via).toBe('notification');
    expect(b.seen.count).toBe(1); expect(b.appViews).toBe(1); // dédoublonné (même ouverture dans les 2 listes)
  });
  test('scripts jamais comptés ; compte interne → internal', () => {
    const b = R.returnVerdict({ publishedAt: iso(5), sessions: [{ at: iso(1), origin: 'script' }], postViews: [], personViews: [] });
    expect(b.state).toBe('never');
    expect(R.returnVerdict({ publishedAt: iso(5), internal: true, sessions: [{ at: iso(1), origin: 'web' }] }).state).toBe('internal');
  });
});

test('boardSignals : par personne (profil gardien), plusieurs demandes → une seule ligne principale', async () => {
  const email = 'caro0111@example.org';
  const owner = await ins(Owner, { name: 'Caro', email, status: 'active' });
  const sitter = await ins(Sitter, { name: 'Caro', email, status: 'active', fcmTokens: ['tok-fictif'] });
  const other = await ins(Owner, { name: 'Kat', email: 'kat0111@example.org', status: 'active' });
  // Caro : demande A publiée il y a 10 h, demande B il y a 3 h ; elle revient il y a 2 h via son profil GARDIEN
  // et ouvre les candidats de A il y a 2 h. Kat : publiée il y a 1 h, jamais revenue.
  await ActivityEvent.create({ userId: sitter, role: 'sitter', at: iso(2), origin: 'app', appVersion: '23.1.6+627' });
  await CandidatesView.create({ postId: 'pA', ownerId: owner, at: iso(2), channel: 'app', source: 'notification', origin: 'app' });
  const item = (postId, id, agoH) => ({ postId, owner: { id }, stages: { published: { at: iso(agoH) } } });
  const m = await R.boardSignals([item('pK', other, 1), item('pB', owner, 3), item('pA', owner, 10)]);
  const A = m.get('pA').back; const B = m.get('pB').back; const K = m.get('pK').back;
  expect(A.state).toBe('since'); expect(B.state).toBe('since');
  expect(A.primary).toBe(true); expect(B.primary).toBe(false); // la demande concernée = celle dont elle a ouvert les candidats
  expect(A.hasApp).toBe(true); expect(B.hasApp).toBe(true);    // app sur le profil gardien = la personne a l'app
  expect(A.personKey).toBe(B.personKey); expect(K.personKey).not.toBe(A.personKey);
  expect(K.state).toBe('never'); expect(K.hasApp).toBe(false);
  // B : vue des candidats de A (pas de B) → « a vu ses candidats » 0 pour B, mais revenue (la personne)
  expect(B.seen.count).toBe(0); expect(A.seen.count).toBe(1);
});

test('boardSignals : retour antérieur à la publication → before avec la date', async () => {
  const o = await ins(Owner, { name: 'Avant', email: 'avant0111@example.org', status: 'active' });
  await ActivityEvent.create({ userId: o, role: 'owner', at: iso(30), origin: 'web', appVersion: 'web' });
  const m = await R.boardSignals([{ postId: 'pV', owner: { id: o }, stages: { published: { at: iso(20) } } }]);
  const b = m.get('pV').back;
  expect(b.state).toBe('before'); expect(new Date(b.lastAt).getTime()).toBe(now - 30 * H); expect(b.primary).toBe(false);
});
