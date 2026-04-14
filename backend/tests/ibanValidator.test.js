const { validateIBAN, cleanIban } = require('../src/utils/ibanValidator');

describe('IBAN validator (ISO 13616 mod-97)', () => {
  test('accepts a valid French IBAN', () => {
    expect(validateIBAN('FR1420041010050500013M02606')).toEqual({
      valid: true,
      country: 'FR',
    });
  });

  test('accepts a valid GB IBAN with spaces', () => {
    expect(validateIBAN('GB82 WEST 1234 5698 7654 32')).toEqual({
      valid: true,
      country: 'GB',
    });
  });

  test('rejects wrong country-specific length (ES needs 24)', () => {
    const result = validateIBAN('ES12345'); // too short
    expect(result.valid).toBe(false);
  });

  test('rejects invalid format', () => {
    expect(validateIBAN('not an iban').valid).toBe(false);
  });

  test('rejects wrong checksum', () => {
    // Replace last char to break the mod 97 checksum.
    const result = validateIBAN('FR1420041010050500013M02607');
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('checksum');
  });

  test('cleanIban normalizes whitespace and case', () => {
    expect(cleanIban('  gb82 west 1234  ')).toBe('GB82WEST1234');
  });
});
