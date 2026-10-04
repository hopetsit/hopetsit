/**
 * 611 (PAM, 04/10/2026) — RANGS façon Waze (idée de Cam, décision BOB).
 *
 *   Chiot → Jeune chien → Chien adulte → Chef de meute → Légende
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
 *   Jeune chien   150 : profil complet + 2 Balades, ou ~5 jours de Balades.
 *   Chien adulte  800 : ~2 semaines actives, ~1 mois modéré.
 *   Chef de meute 3000 : ~6 semaines actives, ~4 mois modérés.
 *   Légende     10000 : ~5 mois actifs tous les jours. Rare.
 */

const LANGS = Object.freeze(['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']);

const RANKS = Object.freeze([
  {
    level: 1, key: 'puppy', min: 0, color: '#E0A045',
    texts: { fr: 'Chiot', en: 'Puppy', es: 'Cachorro', de: 'Welpe', it: 'Cucciolo', pt: 'Cachorrinho', ko: '강아지', ja: '子犬', pl: 'Szczeniak' },
  },
  {
    level: 2, key: 'young_dog', min: 150, color: '#E07A2E',
    texts: { fr: 'Jeune chien', en: 'Young dog', es: 'Perro joven', de: 'Junghund', it: 'Cane giovane', pt: 'Cão jovem', ko: '청소년견', ja: '若犬', pl: 'Młody pies' },
  },
  {
    level: 3, key: 'adult_dog', min: 800, color: '#C9442A',
    texts: { fr: 'Chien adulte', en: 'Grown dog', es: 'Perro adulto', de: 'Erwachsener Hund', it: 'Cane adulto', pt: 'Cão adulto', ko: '성견', ja: '成犬', pl: 'Dorosły pies' },
  },
  {
    level: 4, key: 'pack_leader', min: 3000, color: '#7A3FB8',
    texts: { fr: 'Chef de meute', en: 'Pack leader', es: 'Líder de la manada', de: 'Rudelführer', it: 'Capobranco', pt: 'Líder da matilha', ko: '무리의 리더', ja: '群れのリーダー', pl: 'Przywódca stada' },
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
    fr: 'Tu commences Chiot et tu montes avec les PawPoints gagnés depuis ton inscription : Jeune chien, Chien adulte, Chef de meute, puis Légende. Échanger tes points ne te fait jamais redescendre.',
    en: 'You start as a Puppy and move up with the PawPoints you have earned since you joined: Young dog, Grown dog, Pack leader, then Legend. Spending points never moves you down.',
    es: 'Empiezas como Cachorro y subes con los PawPoints ganados desde que te registraste: Perro joven, Perro adulto, Líder de la manada y Leyenda. Canjear tus puntos nunca te hace bajar.',
    de: 'Du startest als Welpe und steigst mit den PawPoints auf, die du seit deiner Anmeldung verdient hast: Junghund, Erwachsener Hund, Rudelführer, dann Legende. Punkte einlösen lässt dich nie absteigen.',
    it: 'Inizi come Cucciolo e sali con i PawPoints guadagnati dall\'iscrizione: Cane giovane, Cane adulto, Capobranco e poi Leggenda. Spendere i punti non ti fa mai scendere.',
    pt: 'Começas como Cachorrinho e sobes com os PawPoints ganhos desde a inscrição: Cão jovem, Cão adulto, Líder da matilha e depois Lenda. Trocar os teus pontos nunca te faz descer.',
    ko: '처음엔 강아지로 시작해서, 가입 후 모은 PawPoints로 청소년견, 성견, 무리의 리더, 그리고 전설까지 올라가요. 포인트를 사용해도 등급은 내려가지 않아요.',
    ja: '最初は子犬からスタート。登録してから貯めたPawPointsで、若犬、成犬、群れのリーダー、そしてレジェンドへと上がります。ポイントを使ってもランクは下がりません。',
    pl: 'Zaczynasz jako Szczeniak i awansujesz dzięki PawPoints zdobytym od rejestracji: Młody pies, Dorosły pies, Przywódca stada, a potem Legenda. Wymiana punktów nigdy nie obniża rangi.',
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
