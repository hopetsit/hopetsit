// 609 (ZOE, 02/10/2026) — pastille Chat « en retard » (Daniel). Mesuré en production
// avec un vrai client socket : un destinataire à plusieurs profils ne recevait
// message:new que sur le profil enregistré dans le fil ; connecté sous un autre
// profil, rien en direct. Vraie base Mongo en mémoire, vrai emitter, faux serveur io.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_jwt_secret_'.padEnd(64, 'x');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');

let mongo; let Owner; let Sitter; let Walker; let emitter;
const sent = [];
const fakeIo = { to: (room) => ({ emit: (ev, p) => sent.push({ room: String(room), ev, p }) }) };

beforeAll(async () => {
  mongo = await MongoMemoryServer.create(); await mongoose.connect(mongo.getUri());
  Owner = require('../src/models/Owner'); Sitter = require('../src/models/Sitter'); Walker = require('../src/models/Walker');
  emitter = require('../src/sockets/emitter');
  emitter.setSocketServer(fakeIo);
}, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('message:new atteint TOUS les profils du destinataire, une salle par rôle', async () => {
  const e = 'dest609@example.test';
  const ro = await Owner.create({ name: 'Dest Test', email: e, password: 'MotDePasse609!' });
  const rw = await Walker.create({ name: 'Dest Test', email: e, password: 'MotDePasse609!' });
  const snd = await Sitter.create({ name: 'Exp Test', email: 'exp609@example.test', password: 'MotDePasse609!' });
  sent.length = 0;
  const conv = { _id: new mongoose.Types.ObjectId(), friendChat: true, participants: [
    { userId: ro._id, userModel: 'Owner' }, { userId: snd._id, userModel: 'Sitter' }] };
  emitter.emitChatMessage(conv, 'message:new', { message: { _id: 'm1', senderId: String(snd._id) }, triggeredBy: { userId: String(snd._id) } });
  for (let i = 0; i < 200 && !sent.some((x) => x.room === `user:walker:${rw._id}`); i += 1) {
    await new Promise((r) => setTimeout(r, 20));
  }
  const rooms = sent.filter((x) => x.ev === 'message:new').map((x) => x.room);
  expect(rooms).toContain(`user:owner:${ro._id}`);
  expect(rooms).toContain(`user:walker:${rw._id}`); // le profil promeneur connecté reçoit aussi
  // chaque salle une seule fois (pas de double pastille)
  expect(rooms.length).toBe(new Set(rooms).size);
});
