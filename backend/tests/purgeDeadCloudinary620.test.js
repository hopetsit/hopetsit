/** 24/10 (BOB) — les références vers l'ancien cloud Cloudinary (401) sont effacées, le reste ne bouge pas. */
process.env.NODE_ENV = 'test';
jest.mock('../src/config/firebaseAdmin', () => ({ messaging: () => ({ send: jest.fn() }) }));
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
let mongo;
beforeAll(async () => { mongo = await MongoMemoryServer.create(); await mongoose.connect(mongo.getUri()); }, 60000);
afterAll(async () => { await mongoose.disconnect(); if (mongo) await mongo.stop(); });

test('avatars et photos morts effacés, nouveaux conservés, idempotent', async () => {
  const Owner = require('../src/models/Owner'); const Sitter = require('../src/models/Sitter'); const Walker = require('../src/models/Walker'); const Pet = require('../src/models/Pet');
  const { purgeDeadCloudinary } = require('../src/utils/purgeDeadCloudinary620');
  const base = { password: 'Hopetsit2026x', city: 'Zone test', acceptedTerms: true };
  const o1 = await Owner.create({ ...base, name: 'Mort', email: 'mort+test@example.com', avatar: { url: 'https://res.cloudinary.com/ddllooujo/image/upload/v1/a.jpg', publicId: 'a' } });
  const o2 = await Owner.create({ ...base, name: 'Vivant', email: 'vivant+test@example.com', avatar: { url: 'https://res.cloudinary.com/knciqtl6/image/upload/v1/b.jpg', publicId: 'b' } });
  const s1 = await Sitter.create({ ...base, name: 'Gardien', email: 'gard+test@example.com', avatar: { url: 'https://res.cloudinary.com/ddllooujo/image/upload/v1/c.jpg', publicId: 'c' } });
  const pet = await Pet.create({ ownerId: o1._id, petName: 'Rex', name: 'Rex', species: 'dog', avatar: { url: 'https://res.cloudinary.com/ddllooujo/image/upload/v1/d.jpg', publicId: 'd' },
    photos: [{ url: 'https://res.cloudinary.com/ddllooujo/image/upload/v1/e.jpg', publicId: 'e' }, { url: 'https://res.cloudinary.com/knciqtl6/image/upload/v1/f.jpg', publicId: 'f' }] });
  const r = await purgeDeadCloudinary({ Owner, Sitter, Walker, Pet });
  expect(r).toEqual({ accounts: 2, petAvatars: 1, petPhotos: 1 });
  expect((await Owner.findById(o1._id)).avatar.url).toBe('');
  expect((await Owner.findById(o2._id)).avatar.url).toContain('knciqtl6');
  expect((await Sitter.findById(s1._id)).avatar.url).toBe('');
  const p = await Pet.findById(pet._id);
  expect(p.avatar.url).toBe('');
  expect(p.photos.map((x) => x.publicId)).toEqual(['f']);
  const r2 = await purgeDeadCloudinary({ Owner, Sitter, Walker, Pet });
  expect(r2).toEqual({ accounts: 0, petAvatars: 0, petPhotos: 0 });
});
