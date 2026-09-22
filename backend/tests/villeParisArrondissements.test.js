// 22/09/2026 — Daniel : « il faut Paris avec tous les arrondissements autour ».
//
// La comparaison de ville est ancrée au début du nom : « Paris » retrouvait
// bien « Paris 15e », mais l'inverse était faux. Une demande publiée depuis
// « Paris 11e » ne correspondait donc à AUCUN gardien écrivant « Paris » — et
// comme une demande venue du site ne porte pas de GPS, personne n'était
// prévenu. On ramène ces trois communes à leur nom de base.
// Aucun réseau, aucune base.

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test_jwt_secret_'.padEnd(64, 'x');

const { baseCityName } = require('../src/utils/geocodeCity');

describe('baseCityName', () => {
  test('les arrondissements parisiens reviennent à Paris', () => {
    for (const v of ['Paris 1er', 'Paris 11e', 'Paris 11ème', 'Paris 20eme', 'Paris 75011', 'paris 8E']) {
      expect(baseCityName(v)).toBe(v.slice(0, 5));
    }
  });

  test('Lyon et Marseille aussi', () => {
    expect(baseCityName('Lyon 3')).toBe('Lyon');
    expect(baseCityName('Marseille 9e')).toBe('Marseille');
  });

  test('Paris sans numéro ne bouge pas', () => {
    expect(baseCityName('Paris')).toBe('Paris');
  });

  test("les autres villes ne sont JAMAIS amputées, même avec un chiffre", () => {
    for (const v of ['Le Havre', 'Boulogne-Billancourt', 'Asnières-sur-Seine', 'Meaux',
                     'Clichy', 'Villemomble 2', 'Fort Worth', 'Euless']) {
      expect(baseCityName(v)).toBe(v);
    }
  });

  test('une entrée vide ou absente ne casse rien', () => {
    expect(baseCityName('')).toBe('');
    expect(baseCityName(null)).toBe('');
    expect(baseCityName(undefined)).toBe('');
  });
});
