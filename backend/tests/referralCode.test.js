const { generateReferralCode } = require('../src/utils/referralCode');

describe('referralCode generator', () => {
  test('returns a string of the requested length (default 8)', () => {
    const code = generateReferralCode();
    expect(code).toHaveLength(8);
  });

  test('uses only unambiguous alphanumeric characters', () => {
    for (let i = 0; i < 50; i += 1) {
      const code = generateReferralCode(8);
      expect(code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    }
  });

  test('is sufficiently random (low collision rate in 1000 draws)', () => {
    const set = new Set();
    for (let i = 0; i < 1000; i += 1) set.add(generateReferralCode(8));
    // 8 chars over 32-char alphabet = 32^8 ≈ 10^12 space; collisions expected ~0.
    expect(set.size).toBeGreaterThan(995);
  });
});
