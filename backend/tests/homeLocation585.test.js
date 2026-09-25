// v585 — le plugin `homeLocationPlugin` sur une VRAIE base Mongo en mémoire :
// la position de PROFIL est mémorisée à l'inscription et à « Modifier le
// profil », jamais par un partage en direct ; elle ne sort jamais par défaut.
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { homeLocationPlugin } = require('../src/utils/personMapPosition');

let mongo;
let M;
beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  const s = new mongoose.Schema({
    name: String,
    city: String,
    location: {
      type: { type: String, default: 'Point' },
      coordinates: { type: [Number], default: undefined },
      city: String,
      updatedAt: { type: Date, default: null },
      liveShareActive: { type: Boolean, default: false },
    },
  }, { timestamps: true });
  s.plugin(homeLocationPlugin);
  M = mongoose.model('Home585', s);
}, 60000);
afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('inscription (save) → homeLocation = position du formulaire', async () => {
  const d = await M.create({ name: 'john', location: { coordinates: [-1.13, 37.98], city: 'Murcia' } });
  const r = await M.findById(d._id).select('+homeLocation').lean();
  expect(r.homeLocation.coordinates).toEqual([-1.13, 37.98]);
  expect(r.homeLocation.city).toBe('Murcia');
});

test('partage en direct (updateOne avec location.updatedAt) → homeLocation inchangé', async () => {
  const d = await M.create({ name: 'john', location: { coordinates: [-1.13, 37.98] } });
  await M.updateOne({ _id: d._id }, { $set: { 'location.coordinates': [-0.37, 39.47], 'location.updatedAt': new Date(), 'location.liveShareActive': true } });
  const r = await M.findById(d._id).select('+homeLocation').lean();
  expect(r.location.coordinates).toEqual([-0.37, 39.47]);
  expect(r.homeLocation.coordinates).toEqual([-1.13, 37.98]);
});

test('Modifier le profil (updateOne sans updatedAt) → homeLocation suit', async () => {
  const d = await M.create({ name: 'john', location: { coordinates: [-1.13, 37.98] } });
  await M.findOneAndUpdate({ _id: d._id }, { $set: { 'location.coordinates': [-0.48, 38.34], 'location.city': 'Alicante' } });
  const r = await M.findById(d._id).select('+homeLocation').lean();
  expect(r.homeLocation.coordinates).toEqual([-0.48, 38.34]);
  expect(r.homeLocation.city).toBe('Alicante');
});

test('homeLocation ne sort jamais sans le demander', async () => {
  const d = await M.create({ name: 'john', location: { coordinates: [-1.13, 37.98] } });
  const r = await M.findById(d._id).lean();
  expect(r.homeLocation).toBeUndefined();
  const r2 = await M.findById(d._id).select('name location').lean();
  expect(r2.homeLocation).toBeUndefined();
});
