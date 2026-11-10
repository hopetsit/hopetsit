/**
 * 611 (PAM, 04/10/2026) — RANGS façon Waze (idée de Cam, décision BOB).
 *
 *   Découvreur → Explorateur → Guide → Ambassadeur → Légende
 *   (639, Daniel 10/11/2026 : NOMS affichés seulement — anciens noms Chiot →
 *   Jeune chien → Chien adulte → Chef de meute. Clés internes `puppy`,
 *   `young_dog`, `adult_dog`, `pack_leader`, `legend`, seuils et logique inchangés.)
 *
 * RÈGLE : le rang se calcule sur `pawPoints` = PawPoints GAGNÉS DEPUIS
 * TOUJOURS (ne baisse pas quand on dépense ; seule une contribution supprimée
 * reprend ses points, anti-abus v567). JAMAIS sur `pawPointsSpendable`.
 * Le rang est honorifique : aucun avantage payant, aucune valeur en argent.
 *
 * SEUILS fixés d'après la distribution RÉELLE mesurée en prod le 04/10/2026
 * (124 personnes réelles, hors +test / staff) : 111 à 0 point, 5 à 100
 * (profil complet), 7 à 200 (Pionnier), 1 à 300, personne au-delà. Personne
 * n'a encore de gain d'activité régulier : les seuils suivent donc le barème
 * (pawPointsCatalog607) appliqué à un usage réel :
 *   · usage actif (Balade + peluche chaque jour, séries) ≈ 70 pts / jour
 *     (35 × 7 + série 50 + série peluches 200 ≈ 495 / semaine) ;
 *   · usage modéré (Balade seule) ≈ 15 pts / jour + 50 / semaine.
 *   Explorateur   150 : profil complet + 2 Balades, ou ~5 jours de Balades.
 *   Guide         800 : ~2 semaines actives, ~1 mois modéré.
 *   Ambassadeur  3000 : ~6 semaines actives, ~4 mois modérés.
 *   Légende     10000 : ~5 mois actifs tous les jours. Rare.
 */

const LANGS = Object.freeze(['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']);

const RANKS = Object.freeze([
  {
    level: 1, key: 'puppy', min: 0, color: '#E0A045',
    texts: { fr: 'Découvreur', en: 'Newcomer', es: 'Descubridor', de: 'Entdecker', it: 'Scopritore', pt: 'Descobridor', ko: '새내기', ja: 'ビギナー', pl: 'Odkrywca' },
  },
  {
    level: 2, key: 'young_dog', min: 150, color: '#E07A2E',
    texts: { fr: 'Explorateur', en: 'Explorer', es: 'Explorador', de: 'Erkunder', it: 'Esploratore', pt: 'Explorador', ko: '탐험가', ja: '探検家', pl: 'Eksplorator' },
  },
  {
    level: 3, key: 'adult_dog', min: 800, color: '#C9442A',
    texts: { fr: 'Guide', en: 'Guide', es: 'Guía', de: 'Wegweiser', it: 'Guida', pt: 'Guia', ko: '가이드', ja: 'ガイド', pl: 'Przewodnik' },
  },
  {
    level: 4, key: 'pack_leader', min: 3000, color: '#7A3FB8',
    texts: { fr: 'Ambassadeur', en: 'Ambassador', es: 'Embajador', de: 'Botschafter', it: 'Ambasciatore', pt: 'Embaixador', ko: '앰배서더', ja: 'アンバサダー', pl: 'Ambasador' },
  },
  {
    level: 5, key: 'legend', min: 10000, color: '#C9961A',
    texts: { fr: 'Légende', en: 'Legend', es: 'Leyenda', de: 'Legende', it: 'Leggenda', pt: 'Lenda', ko: '전설', ja: 'レジェンド', pl: 'Legenda' },
  },
]);

// Textes d'explication (site + aide de l'app). Honnêtes : rien ne s'achète,
// rien ne vaut de l'argent, dépenser ne fait pas redescendre.
const TEXTS = Object.freeze({
  title: {
    fr: 'Les rangs', en: 'Ranks', es: 'Los rangos', de: 'Die Ränge', it: 'I gradi',
    pt: 'As patentes', ko: '등급', ja: 'ランク', pl: 'Rangi',
  },
  explainer: {
    fr: 'Tu commences Découvreur et tu montes avec les PawPoints gagnés depuis ton inscription : Explorateur, Guide, Ambassadeur, puis Légende. Échanger tes points ne te fait jamais redescendre.',
    en: 'You start as a Newcomer and move up with the PawPoints you have earned since you joined: Explorer, Guide, Ambassador, then Legend. Spending points never moves you down.',
    es: 'Empiezas como Descubridor y subes con los PawPoints ganados desde que te registraste: Explorador, Guía, Embajador y Leyenda. Canjear tus puntos nunca te hace bajar.',
    de: 'Du startest als Entdecker und steigst mit den PawPoints auf, die du seit deiner Anmeldung verdient hast: Erkunder, Wegweiser, Botschafter, dann Legende. Punkte einlösen lässt dich nie absteigen.',
    it: 'Inizi come Scopritore e sali con i PawPoints guadagnati dall\'iscrizione: Esploratore, Guida, Ambasciatore e poi Leggenda. Spendere i punti non ti fa mai scendere.',
    pt: 'Começas como Descobridor e sobes com os PawPoints ganhos desde a inscrição: Explorador, Guia, Embaixador e depois Lenda. Trocar os teus pontos nunca te faz descer.',
    ko: '처음엔 새내기로 시작해서, 가입 후 모은 PawPoints로 탐험가, 가이드, 앰배서더, 그리고 전설까지 올라가요. 포인트를 사용해도 등급은 내려가지 않아요.',
    ja: '最初はビギナーからスタート。登録してから貯めたPawPointsで、探検家、ガイド、アンバサダー、そしてレジェンドへと上がります。ポイントを使ってもランクは下がりません。',
    pl: 'Zaczynasz jako Odkrywca i awansujesz dzięki PawPoints zdobytym od rejestracji: Eksplorator, Przewodnik, Ambasador, a potem Legenda. Wymiana punktów nigdy nie obniża rangi.',
  },
  noMoney: {
    fr: 'Le rang est honorifique : il ne donne aucun avantage payant et ne vaut pas d\'argent.',
    en: 'Your rank is honorary: it gives no paid perks and is not worth money.',
    es: 'El rango es honorífico: no da ninguna ventaja de pago y no vale dinero.',
    de: 'Der Rang ist eine Auszeichnung: Er bringt keine bezahlten Vorteile und ist kein Geld wert.',
    it: 'Il grado è onorifico: non dà vantaggi a pagamento e non vale denaro.',
    pt: 'A patente é honorífica: não dá vantagens pagas e não vale dinheiro.',
    ko: '등급은 명예일 뿐이에요. 유료 혜택이 없고 현금 가치도 없어요.',
    ja: 'ランクは名誉です。有料の特典はなく、お金の価値もありません。',
    pl: 'Ranga jest honorowa: nie daje płatnych korzyści i nie jest warta pieniędzy.',
  },
});

const _num = (p) => {
  const v = Number(p);
  return Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
};

/** Rang public d'un total gagné : {key, level, pointsEarned, nextAt, nextKey}. */
function rankFor(points) {
  const p = _num(points);
  let cur = RANKS[0];
  for (const r of RANKS) if (p >= r.min) cur = r;
  const next = RANKS.find((r) => r.level === cur.level + 1) || null;
  return {
    key: cur.key,
    level: cur.level,
    pointsEarned: p,
    nextAt: next ? next.min : null,
    nextKey: next ? next.key : null,
  };
}

/** Une personne à plusieurs profils : le plus haut total gagné de ses profils. */
function rankOfDocs(docs) {
  const best = (docs || []).reduce((m, d) => Math.max(m, _num(d && d.pawPoints)), 0);
  return rankFor(best);
}

/** Bloc du catalogue public (GET /pawpoints/catalog → ranks611), lu par le site. */
function catalog() {
  return {
    version: 611,
    langs: LANGS,
    ranks: RANKS.map((r) => ({ level: r.level, key: r.key, min: r.min, color: r.color, texts: r.texts })),
    texts: TEXTS,
    rules: { basedOn: 'lifetimeEarned', money: false, paidPerks: false },
  };
}

module.exports = { LANGS, RANKS, TEXTS, rankFor, rankOfDocs, catalog };
