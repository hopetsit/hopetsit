const { encrypt, decrypt, isEncrypted, maskTail4, maskEmail } =
  require('../src/utils/encryption');

describe('encryption utility', () => {
  test('encrypts and decrypts round-trip', () => {
    const ct = encrypt('hello world');
    expect(isEncrypted(ct)).toBe(true);
    expect(ct).not.toBe('hello world');
    expect(decrypt(ct)).toBe('hello world');
  });

  test('decrypt passes through legacy cleartext unchanged', () => {
    expect(decrypt('plain text')).toBe('plain text');
    expect(decrypt('')).toBe('');
    expect(decrypt(null)).toBe(null);
  });

  test('encrypt is idempotent for already-encrypted values', () => {
    const ct = encrypt('FR1420041010050500013M02606');
    expect(encrypt(ct)).toBe(ct);
  });

  test('maskTail4 keeps only the last 4 chars', () => {
    expect(maskTail4('4242424242424242')).toBe('****4242');
    expect(maskTail4('abc')).toBe('***');
  });

  test('maskEmail preserves domain', () => {
    expect(maskEmail('john.doe@example.com')).toBe('j***@example.com');
    expect(maskEmail('invalid')).toBe('');
  });
});
