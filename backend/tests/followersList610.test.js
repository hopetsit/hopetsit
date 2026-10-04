// 610 (PAM, 04/10/2026) — Daniel : « quand je clique sur "1 te suit", il ne
// me dit pas QUI me suit ». Mémoire vive simulée, aucune base.
process.env.NODE_ENV = 'test';
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));

const f = require('../src/utils/followers589');
const { followersOf } = require('../src/utils/followersList610');

const ME = ['aaa0', 'aaa1'];
const DOCS = [
  { d: { _id: 'b1', firstName: 'Camille', lastName: 'Durand', name: 'Camille Durand', email: 'cam@example.com', avatar: { url: 'https://cdn/c.jpg' } }, role: 'owner' },
  { d: { _id: 'c1', firstName: 'Léo', lastName: 'Martin', name: 'Léo Martin', email: 'leo@example.com' }, role: 'walker' },
  { d: { _id: 't1', firstName: 'Test', lastName: 'Walker', name: 'Test Walker', email: 'dadaciao84+testwalker@gmail.com' }, role: 'walker' },
];
const load = async (ids) => DOCS.filter((x) => ids.includes(x.d._id));
const T0 = Date.UTC(2026, 9, 4, 13, 0);

beforeEach(() => f._resetForTests());

test('0 suiveur : liste vide', async () => {
  expect(await followersOf(ME, { load, now: T0 })).toEqual([]);
});

test('1 ami qui me suit : prénom, photo, rôle, depuis — jamais l\'e-mail', async () => {
  f.touch(f.personKey(ME), 'kb', true, T0, 'b1');
  f.touch(f.personKey(ME), 'kb', true, T0 + 60000, 'b1'); // rafraîchi : « depuis » ne bouge pas
  const r = await followersOf(ME, { load, now: T0 + 60000, friendIds: new Set(['b1']) });
  expect(r).toEqual([{
    id: 'b1', name: 'Camille', avatar: 'https://cdn/c.jpg', role: 'owner',
    since: new Date(T0).toISOString(), isFriend: true,
  }]);
  expect(JSON.stringify(r)).not.toMatch(/@|Durand/);
});

test('3 suiveurs : non-ami « Prénom I. », compte +test seulement pour ses amis, une personne = une entrée', async () => {
  const k = f.personKey(ME);
  f.touch(k, 'kb', true, T0, 'b1');
  f.touch(k, 'kc', true, T0 + 1000, 'c1');
  f.touch(k, 'kt', true, T0 + 2000, 't1');
  f.touch(k, 'kb', true, T0 + 3000, 'b1'); // même personne, autre appel
  expect(f.count(k, T0 + 3000)).toBe(3); // le nombre (apps ≤ 609) inchangé
  let r = await followersOf(ME, { load, now: T0 + 3000, friendIds: new Set(['b1']) });
  expect(r.map((x) => x.name)).toEqual(['Camille', 'Léo M.']);
  r = await followersOf(ME, { load, now: T0 + 3000, friendIds: new Set(['b1', 't1']) });
  expect(r.map((x) => x.name)).toEqual(['Camille', 'Léo M.', 'Test']);
});

test('un suivi arrêté ou expiré (3 min) disparaît de la liste', async () => {
  const k = f.personKey(ME);
  f.touch(k, 'kb', true, T0, 'b1');
  f.touch(k, 'kc', true, T0, 'c1');
  f.touch(k, 'kc', false, T0 + 1000, 'c1');
  expect((await followersOf(ME, { load, now: T0 + 1000 })).map((x) => x.id)).toEqual(['b1']);
  expect(await followersOf(ME, { load, now: T0 + f.TTL_MS + 1 })).toEqual([]);
});
