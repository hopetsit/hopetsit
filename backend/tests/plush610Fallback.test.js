// 610 (PAM, 04/10/2026) — Daniel en Balade à Alhama de Murcia (Espagne) : 0
// peluche. Mesuré en prod : aucun parc à chiens OSM à moins de 5 km. Le tirage
// se replie sur les PawSpots de plein air puis les fontaines/plages OSM.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const plush = require('../src/services/plushService607');

let mongo; let MapPOI; let PawPlush; let PawSpot;
const ALHAMA = { lat: 37.7322, lng: -1.3471, key: 'z:377:-9', label: 'Alhama de Murcia' };
const PARIS = { lat: 48.8566, lng: 2.3522, key: 'z:488:15', label: 'Paris' };
const ghost = () => new mongoose.Types.ObjectId();

beforeAll(async () => {
  mongo = await MongoMemoryServer.create();
  await mongoose.connect(mongo.getUri());
  MapPOI = require('../src/models/MapPOI');
  PawPlush = require('../src/models/PawPlush');
  PawSpot = require('../src/models/PawSpot');
  await Promise.all([MapPOI.init(), PawPlush.init(), PawSpot.init()]);
  const spot = (name, type, lng, lat, extra = {}) => PawSpot.create({
    creatorId: ghost(), creatorModel: 'Owner', type, name,
    location: { type: 'Point', coordinates: [lng, lat] }, ...extra,
  });
  // Les vrais lieux mesurés en prod (coordonnées des PawSpots de La Isla).
  await spot('paseo perros', 'path_walk', -1.34868, 37.73161);
  await spot('paseo perros', 'path_walk', -1.34917, 37.73150); // 43 m : même lieu
  await spot('con agua', 'playground', -1.34871, 37.73124);
  await spot('perros', 'path_walk', -1.36058, 37.72384);
  await spot('Café', 'food_cafe', -1.3480, 37.7320); // pas un lieu de plein air
  await spot('Supprimé', 'path_walk', -1.3500, 37.7330, { deletedAt: new Date() });
  await spot('Masqué', 'chill', -1.3510, 37.7335, { hidden: true });
  await MapPOI.create({ title: 'Fuente', category: 'water', status: 'active', source: 'seed', osmId: 'node/1', location: { type: 'Point', coordinates: [-1.3440, 37.7300] } });
  await MapPOI.create({ title: 'Hotel', category: 'hotel', status: 'active', source: 'seed', osmId: 'node/2', location: { type: 'Point', coordinates: [-1.3460, 37.7310] } });
  // Paris : 4 parcs à chiens → aucun repli.
  for (let i = 0; i < 4; i += 1) {
    await MapPOI.create({ title: 'Dog park', category: 'park', status: 'active', source: 'seed', osmId: `way/${i}`, location: { type: 'Point', coordinates: [PARIS.lng + i * 0.003, PARIS.lat] } });
  }
  await PawSpot.create({ creatorId: ghost(), creatorModel: 'Owner', type: 'path_walk', name: 'Quai', location: { type: 'Point', coordinates: [PARIS.lng, PARIS.lat + 0.002] } });
}, 60000);

afterAll(async () => {
  await mongoose.disconnect();
  if (mongo) await mongo.stop();
});

test('Alhama : sans parc à chiens, 3 peluches posées sur des lieux publics', async () => {
  const r = await plush.ensureDraw(ALHAMA);
  expect(r.created).toBe(3);
  const list = await PawPlush.find({ cityKey: ALHAMA.key }).lean();
  expect(list).toHaveLength(3);
  const spots = await PawSpot.find({}).lean();
  const ok = new Map(spots.filter((s) => ['paseo perros', 'con agua', 'perros'].includes(s.name)).map((s) => [String(s._id), s.name]));
  const fuente = await MapPOI.findOne({ title: 'Fuente' }).lean();
  ok.set(String(fuente._id), 'Fuente');
  for (const p of list) expect(ok.has(String(p.poiId))).toBe(true);
  // les deux « paseo perros » à 43 m comptent pour UN lieu
  expect(new Set(list.map((p) => String(p.poiId))).size).toBe(3);
});

test('jamais un café, un spot supprimé ou masqué, ni un hôtel', async () => {
  const bad = await PawSpot.find({ name: { $in: ['Café', 'Supprimé', 'Masqué'] } }).lean();
  const hotel = await MapPOI.findOne({ title: 'Hotel' }).lean();
  const badIds = new Set([...bad.map((s) => String(s._id)), String(hotel._id)]);
  const list = await PawPlush.find({}).lean();
  for (const p of list) expect(badIds.has(String(p.poiId))).toBe(false);
});

test('les deux « paseo perros » à 43 m ne portent jamais deux peluches', async () => {
  const pp = await PawSpot.find({ name: 'paseo perros' }).lean();
  const ids = new Set(pp.map((s) => String(s._id)));
  const n = (await PawPlush.find({ cityKey: ALHAMA.key }).lean()).filter((p) => ids.has(String(p.poiId))).length;
  expect(n).toBeLessThanOrEqual(1);
});

test('Paris : avec des parcs à chiens, le tirage reste 100 % parcs à chiens', async () => {
  await plush.ensureDraw(PARIS);
  const list = await PawPlush.find({ cityKey: PARIS.key }).lean();
  expect(list.length).toBeGreaterThanOrEqual(3);
  const parks = new Set((await MapPOI.find({ category: 'park' }).lean()).map((p) => String(p._id)));
  for (const p of list) expect(parks.has(String(p.poiId))).toBe(true);
});
