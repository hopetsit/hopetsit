// v601 — barre de droite personnalisable : l'ordre et le choix des boutons
// sont retenus sur le compte, comme la barre de gauche.
const { normalizeMapPrefs } = require('../src/controllers/mapPrefsController');

describe('mapPrefs · capsule (barre de droite)', () => {
  test('ordre et choix conservés, doublons et ids invalides retirés', () => {
    const out = normalizeMapPrefs({}, { capsule: ['balade', 'satellite', 'balade', 'X-bad', 'eye'] });
    expect(out.capsule).toEqual(['balade', 'satellite', 'eye']);
  });
  test('liste vide = tout masqué (autorisé)', () => {
    expect(normalizeMapPrefs({}, { capsule: [] }).capsule).toEqual([]);
  });
  test('absent du patch : la valeur du compte est gardée ; la gauche n\'est pas touchée', () => {
    const out = normalizeMapPrefs({ capsule: ['eye'], rail: ['around'] }, { nightMode: true });
    expect(out.capsule).toEqual(['eye']);
    expect(out.rail).toEqual(['around']);
  });
});
