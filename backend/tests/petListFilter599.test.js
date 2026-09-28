// v599 — FLO : GET /pets ne liste plus tous les animaux de la plateforme.
process.env.NODE_ENV = 'test';
const { buildPetListFilter } = require('../src/utils/petListFilter599');
test('propriétaire : ses animaux seulement', () => {
  expect(buildPetListFilter({ userId: 'o1', userRole: 'owner' })).toEqual({ ownerId: 'o1' });
  expect(buildPetListFilter({ userId: 'o1', userRole: 'owner', ownerIdQuery: 'o2' })).toEqual({ ownerId: 'o1' });
});
test('gardien / promeneur : uniquement le propriétaire désigné', () => {
  expect(buildPetListFilter({ userId: 's1', userRole: 'sitter', ownerIdQuery: 'o2' })).toEqual({ ownerId: 'o2' });
  expect(buildPetListFilter({ userId: 'w1', userRole: 'walker' })).toBeNull();
});
test('sans connexion ou rôle inconnu : rien', () => {
  expect(buildPetListFilter({})).toBeNull();
  expect(buildPetListFilter({ userId: 'x', userRole: 'admin' })).toBeNull();
});
