// 619 (BOB, 19/10/2026) — Daniel : le frère de Daniel (Espagne) sortait « USA »
// dans le classement Pays parce que son indicatif était +1 (Canada). Le pays
// vient désormais de l'ADRESSE du profil (`country`), l'indicatif en secours.
const {
  countryFromPhone,
  countryFromIso,
  countryOfProfile,
  countryFilter,
} = require('../src/utils/countryFromPhone');

describe('pays du classement (619)', () => {
  test("l'adresse l'emporte sur l'indicatif", () => {
    expect(countryOfProfile({ country: 'ES', countryCode: '+1' }).iso).toBe('ES');
    expect(countryOfProfile({ country: 'fr', countryCode: '+34' }).iso).toBe('FR');
  });

  test("sans adresse, l'indicatif sert de secours", () => {
    expect(countryOfProfile({ country: '', countryCode: '+34' }).iso).toBe('ES');
    expect(countryOfProfile({ countryCode: '+1' }).iso).toBe('US');
    expect(countryOfProfile({})).toBeNull();
  });

  test('pays hors liste : drapeau calculé', () => {
    const br = countryFromIso('BR');
    expect(br.iso).toBe('BR');
    expect(br.flag).toBe('🇧🇷');
    expect(countryFromIso('CA').name).toBe('Canada');
    expect(countryFromIso('X')).toBeNull();
  });

  test('filtre Pays : adresse, ou indicatif si pas d’adresse', () => {
    const f = countryFilter('ES');
    expect(f.$or[0]).toEqual({ country: 'ES' });
    expect(f.$or[1].country).toEqual({ $in: ['', null] });
    expect(f.$or[1].countryCode.test('+34')).toBe(true);
    expect(f.$or[1].countryCode.test(' 34 ')).toBe(true);
    expect(f.$or[1].countryCode.test('+341')).toBe(false);
    // Pays sans indicatif connu : adresse seulement.
    expect(countryFilter('BR').$or).toHaveLength(1);
  });

  test("l'ancienne lecture par indicatif reste intacte", () => {
    expect(countryFromPhone('+351').iso).toBe('PT');
    expect(countryFromPhone('+33').iso).toBe('FR');
  });
});
