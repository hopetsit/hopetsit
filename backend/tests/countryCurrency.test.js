const { countryToCurrency } = require('../src/utils/countryCurrency');

describe('countryToCurrency', () => {
  test('EUR zone returns EUR', () => {
    for (const c of ['FR', 'DE', 'ES', 'IT', 'PT', 'BE', 'NL']) {
      expect(countryToCurrency(c)).toBe('EUR');
    }
  });

  test('GB returns GBP, CH returns CHF, US returns USD', () => {
    expect(countryToCurrency('GB')).toBe('GBP');
    expect(countryToCurrency('CH')).toBe('CHF');
    expect(countryToCurrency('US')).toBe('USD');
  });

  test('unknown country defaults to EUR', () => {
    expect(countryToCurrency('ZZ')).toBe('EUR');
    expect(countryToCurrency('')).toBe('EUR');
    expect(countryToCurrency(undefined)).toBe('EUR');
  });

  test('is case-insensitive', () => {
    expect(countryToCurrency('fr')).toBe('EUR');
  });
});
