const { isTestAccountEmail } = require('../src/utils/testAccount2809');
const { encrypt } = require('../src/utils/encryption');

describe('comptes de test (+test) — 28/09', () => {
  test('une adresse +test est un compte de test, en clair ou chiffrée', () => {
    expect(isTestAccountEmail('dadaciao84+testpub1@gmail.com')).toBe(true);
    expect(isTestAccountEmail('Someone+TEST@example.com')).toBe(true);
    expect(isTestAccountEmail(encrypt('owner+test2@gmail.com'))).toBe(true);
  });
  test('une vraie adresse ne l\'est pas (ni le compte de Daniel)', () => {
    expect(isTestAccountEmail('marie.dupont@gmail.com')).toBe(false);
    expect(isTestAccountEmail('dadaciao84@gmail.com')).toBe(false);
    expect(isTestAccountEmail(encrypt('testeur@gmail.com'))).toBe(false);
    expect(isTestAccountEmail('')).toBe(false);
    expect(isTestAccountEmail(undefined)).toBe(false);
  });
});
