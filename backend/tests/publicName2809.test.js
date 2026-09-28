const { publicNameFields, applyPublicName } = require('../src/utils/publicName2809');

describe('nom public = prénom + initiale (28/09)', () => {
  test('prénom et nom séparés', () => {
    expect(publicNameFields({ name: 'Thibault Miguet', firstName: 'Thibault', lastName: 'Miguet' }))
      .toEqual({ name: 'Thibault M.', firstName: 'Thibault', lastName: 'M.' });
  });
  test('ancien compte avec seulement name', () => {
    expect(publicNameFields({ name: 'Caron Weber Béatrice' }))
      .toEqual({ name: 'Caron W.', firstName: 'Caron', lastName: 'W.' });
  });
  test('sans nom de famille : prénom seul', () => {
    expect(publicNameFields({ name: 'Sasha', firstName: 'Sasha', lastName: '' }))
      .toEqual({ name: 'Sasha', firstName: 'Sasha', lastName: '' });
  });
  test('initiale accentuée et en majuscule', () => {
    expect(publicNameFields({ firstName: 'Léa', lastName: 'élise' }).name).toBe('Léa É.');
  });
  test('applyPublicName garde les autres champs', () => {
    const p = { name: 'Ana Ro', firstName: 'Ana', lastName: 'Ro', dailyRate: 35 };
    applyPublicName(p);
    expect(p).toEqual({ name: 'Ana R.', firstName: 'Ana', lastName: 'R.', dailyRate: 35 });
  });
});
