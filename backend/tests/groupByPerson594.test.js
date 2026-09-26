// v594 — PawBoost du frère de Daniel invisible : son propriétaire et son
// promeneur ont le même _id ; le regroupement jetait le promeneur boosté.
const { groupByPerson } = require('../src/utils/personMapPosition');

test('même _id, deux rôles : les deux restent dans le groupe', () => {
  const id = '6a5005bd7be16accb52aa548';
  const tagged = [
    { d: { _id: id, email: 'frere@example.test' }, role: 'owner' },
    { d: { _id: id, email: 'frere@example.test', boostExpiry: new Date(Date.now() + 86400000) }, role: 'walker' },
    { d: { _id: id, email: 'frere@example.test' }, role: 'owner' }, // vrai doublon
  ];
  const groups = [...groupByPerson(tagged).values()];
  expect(groups).toHaveLength(1);
  expect(groups[0].map((e) => e.role).sort()).toEqual(['owner', 'walker']);
});
