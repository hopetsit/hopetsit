// 639 (BOB, lot D — décision de Daniel du 10/11/2026) — RANGS PawPoints, série 1 :
// seuls les NOMS affichés changent (9 langues). Clés internes, seuils, couleurs et
// logique sont inchangés. Test pur : aucune base, aucun réseau.
const ranks = require('../src/services/ranks611');

const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
// Tableau figé des contrats (CONTRATS.md §4).
const EXPECTED = {
  puppy: { fr: 'Découvreur', en: 'Newcomer', es: 'Descubridor', de: 'Entdecker', it: 'Scopritore', pt: 'Descobridor', ko: '새내기', ja: 'ビギナー', pl: 'Odkrywca' },
  young_dog: { fr: 'Explorateur', en: 'Explorer', es: 'Explorador', de: 'Erkunder', it: 'Esploratore', pt: 'Explorador', ko: '탐험가', ja: '探検家', pl: 'Eksplorator' },
  adult_dog: { fr: 'Guide', en: 'Guide', es: 'Guía', de: 'Wegweiser', it: 'Guida', pt: 'Guia', ko: '가이드', ja: 'ガイド', pl: 'Przewodnik' },
  pack_leader: { fr: 'Ambassadeur', en: 'Ambassador', es: 'Embajador', de: 'Botschafter', it: 'Ambasciatore', pt: 'Embaixador', ko: '앰배서더', ja: 'アンバサダー', pl: 'Ambasador' },
  // Légende : inchangé dans chaque langue
  legend: { fr: 'Légende', en: 'Legend', es: 'Leyenda', de: 'Legende', it: 'Leggenda', pt: 'Lenda', ko: '전설', ja: 'レジェンド', pl: 'Legenda' },
};
// Anciens noms (avant 639), dans les 9 langues : plus aucun ne doit sortir du serveur.
const OLD = [
  'Chiot', 'Puppy', 'Cachorro', 'Welpe', 'Cucciolo', 'Cachorrinho', '강아지', '子犬', 'Szczeniak',
  'Jeune chien', 'Young dog', 'Perro joven', 'Junghund', 'Cane giovane', 'Cão jovem', '청소년견', '若犬', 'Młody pies',
  'Chien adulte', 'Grown dog', 'Perro adulto', 'Erwachsener Hund', 'Cane adulto', 'Cão adulto', '성견', '成犬', 'Dorosły pies',
  'Chef de meute', 'Pack leader', 'Líder de la manada', 'Rudelführer', 'Capobranco', 'Líder da matilha', '무리의 리더', '群れのリーダー', 'Przywódca stada',
];

describe('639 — noms des rangs, série 1', () => {
  test('les 9 langues du serveur, dans l’ordre attendu', () => {
    expect([...ranks.LANGS]).toEqual(LANGS);
  });

  test('clés internes, niveaux, seuils et couleurs INCHANGÉS', () => {
    expect(ranks.RANKS.map((r) => r.key)).toEqual(['puppy', 'young_dog', 'adult_dog', 'pack_leader', 'legend']);
    expect(ranks.RANKS.map((r) => r.level)).toEqual([1, 2, 3, 4, 5]);
    expect(ranks.RANKS.map((r) => r.min)).toEqual([0, 150, 800, 3000, 10000]);
    expect(ranks.RANKS.map((r) => r.color)).toEqual(['#E0A045', '#E07A2E', '#C9442A', '#7A3FB8', '#C9961A']);
  });

  test.each(Object.keys(EXPECTED))('rang %s : libellé exact du contrat dans les 9 langues', (key) => {
    const r = ranks.RANKS.find((x) => x.key === key);
    expect(r).toBeDefined();
    expect(Object.keys(r.texts).sort()).toEqual([...LANGS].sort());
    for (const l of LANGS) expect(r.texts[l]).toBe(EXPECTED[key][l]);
  });

  test('le calcul du rang ne bouge pas : mêmes paliers, nouveaux noms', () => {
    const at = (pts) => ranks.rankFor(pts);
    expect(at(0).key).toBe('puppy');
    expect(at(149).key).toBe('puppy');
    expect(at(150).key).toBe('young_dog');
    expect(at(799).key).toBe('young_dog');
    expect(at(800).key).toBe('adult_dog');
    expect(at(2999).key).toBe('adult_dog');
    expect(at(3000).key).toBe('pack_leader');
    expect(at(9999).key).toBe('pack_leader');
    expect(at(10000).key).toBe('legend');
    expect(at(10 ** 7).key).toBe('legend');
    expect(at(150)).toEqual({ key: 'young_dog', level: 2, pointsEarned: 150, nextAt: 800, nextKey: 'adult_dog' });
    expect(at(10000).nextAt).toBeNull();
  });

  test('texte d’explication : cite les nouveaux noms de la langue, dans les 9 langues', () => {
    for (const l of LANGS) {
      const txt = ranks.TEXTS.explainer[l];
      expect(typeof txt).toBe('string');
      for (const key of Object.keys(EXPECTED)) expect(txt).toContain(EXPECTED[key][l]);
    }
  });

  test('plus AUCUN ancien nom dans ce que le serveur renvoie (rangs, textes, catalogue)', () => {
    // Uniquement les TEXTES affichés (les clés internes `puppy`, `pack_leader`… restent, c'est voulu).
    const c = ranks.catalog();
    const shown = [
      ...ranks.RANKS.flatMap((r) => Object.values(r.texts)),
      ...c.ranks.flatMap((r) => Object.values(r.texts)),
      ...Object.values(ranks.TEXTS).flatMap((t) => Object.values(t)),
      ...Object.values(c.texts).flatMap((t) => Object.values(t)),
    ].join(' | ');
    for (const old of OLD) expect(shown).not.toContain(old);
    // sans tenir compte de la casse non plus (« chef de meute », « pack leader »…)
    const low = shown.toLowerCase();
    for (const old of OLD) expect(low).not.toContain(old.toLowerCase());
  });

  test('le catalogue public porte les nouveaux noms et les mêmes seuils', () => {
    const c = ranks.catalog();
    const flat = JSON.stringify(c);
    for (const key of Object.keys(EXPECTED)) for (const l of LANGS) expect(flat).toContain(EXPECTED[key][l]);
    for (const n of [150, 800, 3000, 10000]) expect(flat).toContain(String(n));
  });
});
