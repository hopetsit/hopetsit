// v599 — FLO : GET /bookings ne renvoie que les réservations de l'utilisateur connecté.
process.env.NODE_ENV = 'test';
const { buildBookingListFilter } = require('../src/utils/bookingListFilter599');

describe('filtre de GET /bookings par rôle', () => {
  test('propriétaire : ownerId, annulées exclues par défaut', () => {
    expect(buildBookingListFilter({ userId: 'o1', userRole: 'owner' }))
      .toEqual({ ownerId: 'o1', status: { $ne: 'cancelled' } });
  });
  test('gardien : sitterId', () => {
    expect(buildBookingListFilter({ userId: 's1', userRole: 'sitter' }))
      .toEqual({ sitterId: 's1', status: { $ne: 'cancelled' } });
  });
  test('promeneur : walkerId (bug corrigé : avant, aucune contrainte → toutes les réservations)', () => {
    const f = buildBookingListFilter({ userId: 'w1', userRole: 'walker' });
    expect(f).toEqual({ walkerId: 'w1', status: { $ne: 'cancelled' } });
    expect(Object.keys(f)).toContain('walkerId');
  });
  test('statut demandé respecté', () => {
    expect(buildBookingListFilter({ userId: 'w1', userRole: 'walker', status: 'paid' }))
      .toEqual({ walkerId: 'w1', status: 'paid' });
  });
  test('rôle inconnu ou utilisateur absent : rien à lister (null → 403)', () => {
    expect(buildBookingListFilter({ userId: 'x', userRole: 'admin' })).toBeNull();
    expect(buildBookingListFilter({ userRole: 'owner' })).toBeNull();
    expect(buildBookingListFilter({})).toBeNull();
  });
});
