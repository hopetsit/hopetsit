// 29/09/2026 (NEO) — garde-fou « ville = adresse e-mail » (relevé admin du 29/09 :
// un propriétaire Google/Android 598 enregistré avec « x@gmail.com » pour ville).
const { cleanCity } = require('../src/utils/cleanCity2909');

describe('cleanCity2909', () => {
  test('une vraie ville passe inchangée (accents, tirets, arrondissement)', () => {
    expect(cleanCity('Paris')).toBe('Paris');
    expect(cleanCity('  Saint-Germain-en-Laye ')).toBe('Saint-Germain-en-Laye');
    expect(cleanCity("L'Haÿ-les-Roses")).toBe("L'Haÿ-les-Roses");
    expect(cleanCity('Paris 11e')).toBe('Paris 11e');
    expect(cleanCity('Chelles')).toBe('Chelles');
  });
  test('une adresse e-mail, ou tout texte avec @, devient vide', () => {
    expect(cleanCity('dadaniecka@gmail.com')).toBe('');
    expect(cleanCity(' someone@example.org ')).toBe('');
    expect(cleanCity('@paris')).toBe('');
  });
  test('vide, null, undefined et non-chaînes → chaîne vide', () => {
    expect(cleanCity('')).toBe('');
    expect(cleanCity('   ')).toBe('');
    expect(cleanCity(null)).toBe('');
    expect(cleanCity(undefined)).toBe('');
    expect(cleanCity(42)).toBe('42');
  });
});

describe('authController : hasCity et création de compte refusent une ville e-mail', () => {
  test('les 4 affectations de ville et hasCity passent par cleanCity', () => {
    const fs = require('fs');
    const src = fs.readFileSync(require.resolve('../src/controllers/authController.js'), 'utf8');
    expect(src).toContain("require('../utils/cleanCity2909')");
    expect(src).toMatch(/const hasCity = \(user\) =>\s*!!\(cleanCity\(user\?\.city\) \|\| cleanCity\(user\?\.location\?\.city\)\)/);
    const occ = src.match(/city: cleanCity\(/g) || [];
    expect(occ.length).toBeGreaterThanOrEqual(4);
    // Aucune affectation « city: (user… ).trim() » brute ne subsiste.
    expect(src).not.toMatch(/city: \(user\??\.city \|\| user\??\.location\?\.city \|\| ''\)\.toString\(\)\.trim\(\)/);
  });
});
