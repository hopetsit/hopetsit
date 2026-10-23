/** 23/10 (BOB, relevé FLO) — le montant des retraits en attente additionne bien les retraits quand l'id vient
 * d'une chaîne (cas de l'app) : avant, `$match` comparait une chaîne à un ObjectId → toujours 0. */
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
let mongo;
beforeAll(async () => { mongo = await MongoMemoryServer.create(); await mongoose.connect(mongo.getUri()); }, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('retraits en attente : somme juste avec un userId en chaîne', async () => {
  const WalletTransaction = require('../src/models/WalletTransaction');
  const uid = new mongoose.Types.ObjectId();
  const base = { userId: uid, userRole: 'sitter', type: 'debit_withdrawal', status: 'pending', currency: 'EUR', balanceAfter: 0, description: 'test' };
  await WalletTransaction.create([{ ...base, amount: 20 }, { ...base, amount: 15 }, { ...base, amount: 7, status: 'completed' }]);
  const pending = await WalletTransaction.aggregate([
    { $match: { userId: mongoose.Types.ObjectId.createFromHexString(String(uid)), type: 'debit_withdrawal', status: 'pending' } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  expect(pending[0].total).toBe(35);
  const avant = await WalletTransaction.aggregate([{ $match: { userId: String(uid), type: 'debit_withdrawal', status: 'pending' } }, { $group: { _id: null, total: { $sum: '$amount' } } }]);
  expect(avant.length).toBe(0); // l'ancien code : aucune ligne trouvée
});
