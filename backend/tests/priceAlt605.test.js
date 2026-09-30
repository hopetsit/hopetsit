// v605 — repli semaine / mois dans un champ séparé (priceAlt), priceFrom inchangé.
const { rolePriceFrom604, rolePriceAlt605 } = require('../src/routes/friendRoutes');

describe('priceAlt605', () => {
  test('gardien semaine + mois seulement (cas GIRMA) : priceFrom 0, priceAlt semaine', () => {
    const d = { hourlyRate: 0, dailyRate: 0, weeklyRate: 100, monthlyRate: 350 };
    const pf = rolePriceFrom604(d, 'sitter');
    expect(pf).toBe(0);
    expect(rolePriceAlt605(d, 'sitter', pf)).toEqual({ amount: 100, unit: 'week' });
  });
  test('gardien mois seulement : priceAlt mois', () => {
    const d = { monthlyRate: 350 };
    expect(rolePriceAlt605(d, 'sitter', rolePriceFrom604(d, 'sitter'))).toEqual({ amount: 350, unit: 'month' });
  });
  test('gardien avec un tarif à la journée : pas de repli', () => {
    const d = { dailyRate: 30, weeklyRate: 100 };
    const pf = rolePriceFrom604(d, 'sitter');
    expect(pf).toBe(30);
    expect(rolePriceAlt605(d, 'sitter', pf)).toBeNull();
  });
  test('promeneur et propriétaire : jamais de repli', () => {
    expect(rolePriceAlt605({ weeklyRate: 100 }, 'walker', 0)).toBeNull();
    expect(rolePriceAlt605({ weeklyRate: 100 }, 'owner', 0)).toBeNull();
  });
  test('aucun tarif : null', () => {
    expect(rolePriceAlt605({}, 'sitter', 0)).toBeNull();
  });
});
