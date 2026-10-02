// 609 (PAM, 02/10/2026) — badge « Identité vérifiée » sur la PawMap :
// identityVerified = vraie vérification d'identité (kycStatus verified ou
// validation admin), JAMAIS un simple e-mail vérifié (`verified: true`).
const { pinFlags, isKycVerified } = require('../src/utils/mapVisibility');

test('KYC vérifié → identityVerified', () => {
  expect(pinFlags({ kycStatus: 'verified' }).identityVerified).toBe(true);
  expect(pinFlags({ identityVerification: { status: 'verified' } }).identityVerified).toBe(true);
});

test('e-mail vérifié seul → PAS vérifié', () => {
  expect(pinFlags({ verified: true, emailVerified: true }).identityVerified).toBe(false);
  expect(pinFlags({ verified: true, kycStatus: 'pending_verification' }).identityVerified).toBe(false);
  expect(isKycVerified({ verified: true })).toBe(false);
});

test('toujours un booléen (clé présente dans le JSON)', () => {
  const f = pinFlags({});
  expect(Object.prototype.hasOwnProperty.call(f, 'identityVerified')).toBe(true);
  expect(f.identityVerified).toBe(false);
});
