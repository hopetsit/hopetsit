// v602 (ZOE, 29/09/2026) — Daniel : « la réception des messages est un peu
// molle ». Mesure : ~2 s entre l'envoi et `message:new` chez le destinataire,
// dont 15 allers-retours Mongo en série (base à Mumbai, serveur en Oregon).
// Ce test garde deux des corrections : le groupe d'identité mis en cache 60 s
// (il était recalculé 3 à 4 fois par message) et jamais un échec en cache.
process.env.NODE_ENV = 'test';
process.env.IDENTITY_CACHE_IN_TESTS = '1';

const calls = { findById: 0, find: 0 };
let failNext = false;
const mockModel = (name) => ({
  findById: jest.fn(() => ({
    select: () => ({
      lean: () => ({
        catch: () => {
          calls.findById += 1;
          if (name === 'Owner') {
            if (failNext) return Promise.reject(new Error('panne'));
            return Promise.resolve({ email: 'camille@example.test' });
          }
          return Promise.resolve(null);
        },
      }),
    }),
  })),
  find: jest.fn(() => ({
    select: () => ({
      lean: () => {
        calls.find += 1;
        if (failNext) return Promise.reject(new Error('panne'));
        return Promise.resolve(name === 'Sitter' ? [{ _id: 'S1' }] : []);
      },
    }),
  })),
});
jest.mock('../src/models/Owner', () => mockModel('Owner'));
jest.mock('../src/models/Sitter', () => mockModel('Sitter'));
jest.mock('../src/models/Walker', () => mockModel('Walker'));

const { identityGroup, invalidateIdentityGroup } = require('../src/utils/identityGroup');

beforeEach(() => {
  invalidateIdentityGroup();
  calls.findById = 0; calls.find = 0; failNext = false;
});

test('le groupe d\'identité est lu une fois puis servi par le cache', async () => {
  const a = await identityGroup('O1');
  expect([...a.set].sort()).toEqual(['O1', 'S1']);
  const lookups = calls.findById + calls.find;
  const b = await identityGroup('O1');
  const c = await identityGroup('O1');
  expect(calls.findById + calls.find).toBe(lookups);
  expect([...b.set].sort()).toEqual(['O1', 'S1']);
  // Chaque appelant reçoit sa propre copie (un appelant qui modifie son Set
  // ne pollue pas les autres).
  b.set.add('X');
  expect(c.set.has('X')).toBe(false);
  expect((await identityGroup('O1')).set.has('X')).toBe(false);
});

test('deux lectures simultanées ne font qu\'une requête', async () => {
  await Promise.all([identityGroup('O2'), identityGroup('O2'), identityGroup('O2')]);
  expect(calls.findById).toBe(3); // 3 collections, une seule fois
});

test('un échec de lecture n\'est jamais gardé en cache', async () => {
  failNext = true;
  const a = await identityGroup('O3');
  expect([...a.set]).toEqual(['O3']);
  failNext = false;
  const b = await identityGroup('O3');
  expect([...b.set].sort()).toEqual(['O3', 'S1']);
});

test('invalidateIdentityGroup force une relecture', async () => {
  await identityGroup('O4');
  const n = calls.findById;
  invalidateIdentityGroup('O4');
  await identityGroup('O4');
  expect(calls.findById).toBe(n + 3);
});
