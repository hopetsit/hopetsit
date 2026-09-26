// v590 — bouton « Restaurer » des désinscriptions de l'admin (Daniel, 26/09 :
// « j'ai effacé un compte sans vouloir »). Vraie base Mongo en mémoire.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { logDeletedAccount } = require('../src/utils/deletedAccountLog');
const {
  restoreDeletedAccount, restoreBlocker, buildPartialDoc, purgeOldSnapshots,
} = require('../src/utils/accountRestore590');

let mongo; let Sitter; let Walker; let Owner; let DeletedAccount;

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  Sitter = require('../src/models/Sitter');
  Walker = require('../src/models/Walker');
  Owner = require('../src/models/Owner');
  DeletedAccount = require('../src/models/DeletedAccount');
  await Promise.all([Sitter.init(), Walker.init(), Owner.init()]);
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('suppression admin puis restauration COMPLÈTE : même id, même mot de passe', async () => {
  const s = await Sitter.create({ name: 'Carol Test', email: 'carol590@example.test', password: 'MotDePasse590!', city: 'Paris' });
  const hash = (await Sitter.findById(s._id).lean()).password;
  const doc = await Sitter.findByIdAndDelete(s._id);
  await logDeletedAccount({ role: 'sitter', doc, source: 'admin' });
  expect(await Sitter.exists({ _id: s._id })).toBeNull();

  const entry = await DeletedAccount.findOne({ userId: String(s._id) }).select('+snapshot').lean();
  expect(entry.snapshot).toBeTruthy();

  const r = await restoreDeletedAccount(entry._id);
  expect(r).toMatchObject({ ok: true, mode: 'complet', role: 'sitter' });
  const back = await Sitter.findById(s._id).lean();
  expect(back.email).toBe('carol590@example.test');
  expect(back.city).toBe('Paris');
  expect(back.password).toBe(hash); // pas re-haché
  const after = await DeletedAccount.findById(entry._id).select('+snapshot').lean();
  expect(after.restoredAt).toBeTruthy();
  expect(after.snapshot).toBeUndefined();

  const again = await restoreDeletedAccount(entry._id);
  expect(again.ok).toBe(false);
});

test('suppression demandée par la personne : jamais copiée, jamais restaurable', async () => {
  const w = await Walker.create({ name: 'Parti', email: 'parti590@example.test', password: 'MotDePasse590!' });
  const doc = await Walker.findByIdAndDelete(w._id);
  await logDeletedAccount({ role: 'walker', doc, source: 'user' });
  const entry = await DeletedAccount.findOne({ userId: String(w._id) }).select('+snapshot').lean();
  expect(entry.snapshot).toBeUndefined();
  const r = await restoreDeletedAccount(entry._id);
  expect(r.ok).toBe(false);
  expect(await Walker.exists({ _id: w._id })).toBeNull();
});

test('ancienne suppression admin sans copie : reconstruction partielle depuis le profil frère', async () => {
  const o = await Owner.create({ name: 'Didier', email: 'didier590@example.test', password: 'MotDePasse590!', city: 'Murcia', mobile: '600000000' });
  const ownerHash = (await Owner.findById(o._id).lean()).password;
  const id = new mongoose.Types.ObjectId();
  const entry = await DeletedAccount.create({
    role: 'walker', name: 'Didier', email: 'didier590@example.test', userId: String(id), source: 'admin', deletedAt: new Date(),
  });
  const r = await restoreDeletedAccount(entry._id);
  expect(r.ok).toBe(true);
  expect(r.mode).toMatch(/partiel/);
  const back = await Walker.findById(id).lean();
  expect(back.city).toBe('Murcia');
  expect(back.mobile).toBe('600000000');
  expect(back.password).toBe(ownerHash);
});

test('refus si un compte du même rôle a déjà cet e-mail', async () => {
  await Sitter.create({ name: 'Déjà là', email: 'double590@example.test', password: 'MotDePasse590!' });
  const entry = await DeletedAccount.create({
    role: 'sitter', name: 'Double', email: 'double590@example.test', userId: String(new mongoose.Types.ObjectId()), source: 'admin',
  });
  const r = await restoreDeletedAccount(entry._id);
  expect(r).toMatchObject({ ok: false, status: 409 });
});

test('copie de plus de 30 jours : effacée et plus restaurable', async () => {
  const old = new Date(Date.now() - 31 * 86400000);
  const entry = await DeletedAccount.create({
    role: 'owner', name: 'Vieux', email: 'vieux590@example.test', userId: String(new mongoose.Types.ObjectId()),
    source: 'admin', deletedAt: old, snapshot: { name: 'Vieux' },
  });
  expect(restoreBlocker({ ...entry.toObject(), snapshot: true })).toMatch(/expirée/);
  await purgeOldSnapshots();
  const after = await DeletedAccount.findById(entry._id).select('+snapshot').lean();
  expect(after.snapshot).toBeUndefined();
});

test('buildPartialDoc sans profil frère : mot de passe aléatoire fourni', () => {
  const d = buildPartialDoc({ name: 'X', email: ' X@Ex.Test ' }, null, new Date(), 'HASH');
  expect(d).toMatchObject({ name: 'X', email: 'x@ex.test', password: 'HASH' });
});

// v590 — Bloquer / Débloquer (anti-spam) : les 3 profils de la personne.
test('bloquer un profil bloque les autres profils de la personne, débloquer les rend', async () => {
  const { setBlocked, listBlocked } = require('../src/utils/userBlock590');
  const o = await Owner.create({ name: 'Bot', email: 'bot590@example.test', password: 'MotDePasse590!' });
  const w = await Walker.create({ name: 'Bot', email: 'bot590@example.test', password: 'MotDePasse590!' });
  const r = await setBlocked('owner', o._id, true, 'spam');
  expect(r.ok).toBe(true);
  expect(r.profiles.length).toBe(2);
  expect((await Walker.findById(w._id).lean()).status).toBe('banned');
  const list = await listBlocked();
  expect(list.filter((u) => u.email === 'bot590@example.test').length).toBe(2);
  await setBlocked('walker', w._id, false);
  expect((await Owner.findById(o._id).lean()).status).toBe('active');
  expect((await listBlocked()).some((u) => u.email === 'bot590@example.test')).toBe(false);
});

// v590 — onglet « Dernière connexion » : un début de session par tranche de 30 min.
test('journal d\'activité : une session par tranche de 30 min, lieu du profil', async () => {
  const { recordActivity, activitySummary, isNewSession, _seen } = require('../src/utils/activity590');
  expect(isNewSession(null, 1000)).toBe(true);
  expect(isNewSession(1000, 1000 + 10 * 60000)).toBe(false);
  const o = await Owner.create({ name: 'Actif', email: 'actif590@example.test', password: 'MotDePasse590!', city: 'Paris', country: 'FR' });
  const req = { headers: { 'x-app-platform': 'ios', 'x-app-version': '590' } };
  const t0 = Date.now();
  _seen.clear();
  expect(await recordActivity(req, o._id, 'owner', t0)).toBeTruthy();
  expect(await recordActivity(req, o._id, 'owner', t0 + 5 * 60000)).toBeNull();
  _seen.clear(); // redémarrage du serveur : la base empêche le doublon
  expect(await recordActivity(req, o._id, 'owner', t0 + 6 * 60000)).toBeNull();
  expect(await recordActivity(req, o._id, 'owner', t0 + 45 * 60000)).toBeTruthy();
  const s = (await activitySummary({ days: 1 })).find((u) => u.userId === String(o._id));
  expect(s).toMatchObject({ sessions: 2, platform: 'ios', appVersion: '590', city: 'Paris', country: 'FR', name: 'Actif' });
});

// v590 — le badge staff suit la personne sur tous ses profils, même créés plus tard.
test('staff : un rôle ajouté plus tard hérite du badge ; rattrapage global', async () => {
  const { propagateStaffForPerson, propagateAllStaff } = require('../src/utils/staffSync590');
  const o = await Owner.create({ name: 'Maman', email: 'staff590@example.test', password: 'MotDePasse590!', isStaff: true });
  const s = await Sitter.create({ name: 'Maman', email: 'staff590@example.test', password: 'MotDePasse590!' });
  expect(await propagateStaffForPerson(o._id)).toBe(1);
  expect((await Sitter.findById(s._id).lean()).isStaff).toBe(true);
  const w = await Walker.create({ name: 'Maman', email: 'staff590@example.test', password: 'MotDePasse590!' });
  expect(await propagateAllStaff()).toBeGreaterThanOrEqual(1);
  expect((await Walker.findById(w._id).lean()).isStaff).toBe(true);
  const other = await Walker.create({ name: 'Pas staff', email: 'nostaff590@example.test', password: 'MotDePasse590!' });
  expect(await propagateStaffForPerson(other._id)).toBe(0);
});
