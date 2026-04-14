const {
  resolveCountry,
  ibanToCountry,
  SUPPORTED_STRIPE_COUNTRIES,
} = require('../src/utils/stripeCountry');

describe('stripeCountry helpers', () => {
  test('SUPPORTED_STRIPE_COUNTRIES contains the sprint-2 list', () => {
    for (const c of ['FR', 'ES', 'PT', 'IT', 'DE', 'BE', 'LU', 'CH', 'GB', 'US']) {
      expect(SUPPORTED_STRIPE_COUNTRIES).toContain(c);
    }
  });

  test('ibanToCountry reads the 2-letter prefix', () => {
    expect(ibanToCountry('FR1420041010050500013M02606')).toBe('FR');
    expect(ibanToCountry('gb82 west 1234 5698 7654 32')).toBe('GB');
    expect(ibanToCountry('')).toBe(null);
  });

  test('resolveCountry priority: explicit > sitter > IBAN > header', () => {
    expect(
      resolveCountry({
        explicit: 'DE',
        sitterCountry: 'FR',
        ibanCountry: 'ES',
        acceptLanguage: 'it-IT',
      })
    ).toBe('DE');

    expect(
      resolveCountry({ sitterCountry: 'ES', ibanCountry: 'FR' })
    ).toBe('ES');

    expect(resolveCountry({ ibanCountry: 'PT' })).toBe('PT');

    expect(resolveCountry({ acceptLanguage: 'fr-FR' })).toBe('FR');
  });

  test('resolveCountry returns null when none match supported list', () => {
    expect(resolveCountry({})).toBe(null);
    expect(resolveCountry({ explicit: 'ZZ' })).toBe(null);
  });
});
