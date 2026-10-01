// v607 (PAM, 01/10) — bouton rose « tout le monde » : afficher / masquer tous
// les membres, retenu sur le compte (`pawMap.layers.everyone`), lu par l'app
// et le site.
const { normalizeMapPrefs } = require('../src/controllers/mapPrefsController');

describe('mapPrefs · layers.everyone (607)', () => {
  test('masqué puis réaffiché : le booléen est gardé tel quel', () => {
    expect(normalizeMapPrefs({}, { layers: { everyone: false } }).layers).toEqual({ everyone: false });
    expect(normalizeMapPrefs({ layers: { everyone: false } }, { layers: { everyone: true } }).layers.everyone).toBe(true);
  });
  test('une app ≤ 606 qui renvoie ses calques n\'efface pas le réglage', () => {
    const out = normalizeMapPrefs(
      { layers: { everyone: false, friends: true } },
      { layers: { places: true, reports: true, members: true, pawspots: false, live: true, requests: true, friends: true, premium: true } },
    );
    expect(out.layers.everyone).toBe(false);
    expect(out.layers.places).toBe(true);
  });
  test('valeur non booléenne refusée ; clé inconnue toujours ignorée', () => {
    const out = normalizeMapPrefs({}, { layers: { everyone: 'non', bidon: true } });
    expect(out.layers).toBeUndefined();
  });
});
