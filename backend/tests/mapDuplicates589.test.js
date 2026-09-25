// v589 — « je vois la même personne à deux endroits » / « mon profil sort en double ».
const { friendshipsPreferredFirst, withoutViewer } = require('../src/utils/friendshipOrder589');

test('amitiés : la plus récente d\'abord (même choix que la liste d\'amis)', () => {
  const a = { _id: 'a', updatedAt: '2026-09-01T00:00:00Z' };
  const b = { _id: 'b', updatedAt: '2026-09-20T00:00:00Z' };
  const c = { _id: 'c', createdAt: '2026-09-10T00:00:00Z' };
  expect(friendshipsPreferredFirst([a, c, b]).map((f) => f._id)).toEqual(['b', 'c', 'a']);
});

test('couche monde : la personne qui regarde est retirée, sur ses 3 profils', () => {
  const members = [
    { id: 'dO', personIds: ['dO', 'dS'] },           // moi, point posé avec mon id propriétaire
    { id: 'x1', roles: [{ id: 'x1' }, { id: 'dS' }] }, // improbable, mais un de mes ids
    { id: 'friend', personIds: ['friend', 'friend2'] },
  ];
  expect(withoutViewer(members, ['dS', 'dO']).map((m) => m.id)).toEqual(['friend']);
  expect(withoutViewer(members, new Set(['zzz'])).length).toBe(3);
  expect(withoutViewer(undefined, ['a'])).toEqual([]);
});
