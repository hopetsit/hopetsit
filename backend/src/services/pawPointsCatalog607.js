'use strict';

/**
 * 607 (ZOE, 02/10/2026) — CATALOGUE PawPoints UNIQUE (app, site, admin).
 *
 * Décision de Daniel (02/10) : « mets à jour la page PawPoints partout ».
 * Règles :
 *   • tout se gagne par l'ACTIVITÉ dans l'app (jamais en payant) ;
 *   • une récompense = ce que le SERVEUR accorde lui-même, pareil partout :
 *     jours offerts (PawFollow / Paw Premium), PawBoost offert, cadre doré
 *     d'avatar, collection de peluches ;
 *   • plus AUCUNE réduction en pourcentage (impossible dans les achats Apple,
 *     même motif 3.1.1 que les codes) ; jamais d'argent, aucune promesse de
 *     revenus.
 * Les anciennes réductions (-10 / -25 / -50 %) déjà échangées restent
 * valables (leur définition vit dans la trace d'échange, `snapshot`) ;
 * elles ne s'échangent plus (LEGACY_DISCOUNT_IDS → 410).
 *
 * Ce fichier ne lit pas la base : constantes + textes 9 langues.
 */

const LANGS = Object.freeze(['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']);

// ── GAINS ──────────────────────────────────────────────────────────────────
// limit : 'each' (à chaque fois) | 'once' (une fois par personne) |
//         'daily' (une fois par jour et par personne) | 'streak' (chaque série)
const EARN_RULES = Object.freeze([
  { key: 'spotCreated', points: 10, icon: '📍', limit: 'each', since: 416, t: {
    fr: 'Ajouter un PawSpot', en: 'Add a PawSpot', es: 'Añadir un PawSpot', de: 'Einen PawSpot hinzufügen',
    it: 'Aggiungere un PawSpot', pt: 'Adicionar um PawSpot', ko: 'PawSpot 추가하기', ja: 'PawSpotを追加する', pl: 'Dodaj PawSpot' } },
  { key: 'photoAdded', points: 5, icon: '📷', limit: 'each', since: 416, t: {
    fr: 'Ajouter une photo à un PawSpot', en: 'Add a photo to a PawSpot', es: 'Añadir una foto a un PawSpot',
    de: 'Ein Foto zu einem PawSpot hinzufügen', it: 'Aggiungere una foto a un PawSpot', pt: 'Adicionar uma foto a um PawSpot',
    ko: 'PawSpot에 사진 추가하기', ja: 'PawSpotに写真を追加する', pl: 'Dodaj zdjęcie do PawSpotu' } },
  { key: 'spotValidated', points: 10, icon: '✅', limit: 'each', since: 416, t: {
    fr: 'Ton spot validé par la communauté', en: 'Your spot approved by the community', es: 'Tu spot validado por la comunidad',
    de: 'Dein Spot von der Community bestätigt', it: 'Il tuo spot convalidato dalla community', pt: 'O teu spot validado pela comunidade',
    ko: '커뮤니티가 내 스팟을 인증', ja: 'あなたのスポットがコミュニティに認められる', pl: 'Twój spot zatwierdzony przez społeczność' } },
  { key: 'usefulComment', points: 2, icon: '💬', limit: 'each', since: 416, t: {
    fr: 'Commentaire utile sur un spot', en: 'Helpful comment on a spot', es: 'Comentario útil en un spot',
    de: 'Hilfreicher Kommentar zu einem Spot', it: 'Commento utile su uno spot', pt: 'Comentário útil num spot',
    ko: '스팟에 유용한 댓글', ja: 'スポットへの役立つコメント', pl: 'Pomocny komentarz do spotu' } },
  { key: 'correctReport', points: 1, icon: '🚧', limit: 'each', since: 416, t: {
    fr: 'Signalement confirmé sur la carte', en: 'Map report confirmed', es: 'Aviso confirmado en el mapa',
    de: 'Bestätigte Meldung auf der Karte', it: 'Segnalazione confermata sulla mappa', pt: 'Alerta confirmado no mapa',
    ko: '지도 신고 확인됨', ja: 'マップの報告が確認される', pl: 'Potwierdzone zgłoszenie na mapie' } },
  { key: 'spotPopular', points: 25, icon: '⭐', limit: 'each', since: 416, t: {
    fr: 'Spot très populaire (50 ❤️)', en: 'Very popular spot (50 ❤️)', es: 'Spot muy popular (50 ❤️)',
    de: 'Sehr beliebter Spot (50 ❤️)', it: 'Spot molto popolare (50 ❤️)', pt: 'Spot muito popular (50 ❤️)',
    ko: '인기 스팟 (❤️ 50개)', ja: '大人気スポット（❤️ 50）', pl: 'Bardzo popularny spot (50 ❤️)' } },
  { key: 'plushCaught', points: 20, icon: '🧸', limit: 'daily', since: 607, t: {
    fr: 'Attraper une peluche pendant une Balade', en: 'Catch a plush toy during a Walk', es: 'Atrapar un peluche durante un Paseo',
    de: 'Ein Plüschtier bei einem Spaziergang fangen', it: 'Prendere un peluche durante una Passeggiata', pt: 'Apanhar um peluche durante um Passeio',
    ko: '산책 중 인형 잡기', ja: 'お散歩中にぬいぐるみをつかまえる', pl: 'Złap pluszaka podczas Spaceru' } },
  { key: 'plushGolden', points: 200, icon: '🌟', limit: 'each', since: 607, t: {
    fr: 'Peluche dorée (une par ville et par semaine) : +24 h de PawBoost en plus', en: 'Golden plush (one per city each week): plus 24 h of PawBoost',
    es: 'Peluche dorado (uno por ciudad y semana): +24 h de PawBoost', de: 'Goldenes Plüschtier (eins pro Stadt und Woche): dazu 24 Std. PawBoost',
    it: 'Peluche dorato (uno per città a settimana): +24 h di PawBoost', pt: 'Peluche dourado (um por cidade por semana): +24 h de PawBoost',
    ko: '황금 인형 (도시별 주 1개): PawBoost 24시간 추가', ja: '金のぬいぐるみ（各都市で週1つ）：PawBoost 24時間つき', pl: 'Złoty pluszak (jeden na miasto w tygodniu): +24 h PawBoost' } },
  { key: 'plushCollector', points: 500, icon: '🏅', limit: 'once', since: 607, t: {
    fr: 'Collection complète des 5 peluches : badge « Collectionneur »', en: 'Full collection of the 5 plush toys: “Collector” badge',
    es: 'Colección completa de los 5 peluches: insignia «Coleccionista»', de: 'Alle 5 Plüschtiere gesammelt: Abzeichen „Sammler“',
    it: 'Collezione completa dei 5 peluche: badge «Collezionista»', pt: 'Coleção completa dos 5 peluches: distintivo «Colecionador»',
    ko: '인형 5종 모두 모으기: ‘컬렉터’ 배지', ja: 'ぬいぐるみ5種コンプリート：「コレクター」バッジ', pl: 'Cała kolekcja 5 pluszaków: odznaka „Kolekcjoner”' } },
  { key: 'plushStreak7', points: 200, icon: '📅', limit: 'streak', since: 607, t: {
    fr: '7 jours de suite avec une peluche attrapée', en: '7 days in a row catching a plush toy', es: '7 días seguidos atrapando un peluche',
    de: '7 Tage am Stück ein Plüschtier gefangen', it: '7 giorni di fila con un peluche preso', pt: '7 dias seguidos a apanhar um peluche',
    ko: '7일 연속 인형 잡기', ja: '7日連続でぬいぐるみをつかまえる', pl: '7 dni z rzędu ze złapanym pluszakiem' } },
  { key: 'walkCompleted', points: 15, icon: '🚶', limit: 'daily', since: 607, t: {
    fr: 'Terminer une Balade (10 min et 300 m minimum)', en: 'Finish a Walk (at least 10 min and 300 m)',
    es: 'Terminar un Paseo (mínimo 10 min y 300 m)', de: 'Einen Spaziergang beenden (mind. 10 Min. und 300 m)',
    it: 'Terminare una Passeggiata (almeno 10 min e 300 m)', pt: 'Terminar um Passeio (mínimo 10 min e 300 m)',
    ko: '산책 마치기 (최소 10분, 300m)', ja: 'お散歩を終える（10分・300m以上）', pl: 'Zakończ Spacer (min. 10 min i 300 m)' } },
  { key: 'firstReviewReceived', points: 50, icon: '🌟', limit: 'once', since: 607, t: {
    fr: 'Recevoir ton premier avis', en: 'Receive your first review', es: 'Recibir tu primera reseña',
    de: 'Deine erste Bewertung erhalten', it: 'Ricevere la tua prima recensione', pt: 'Receber a tua primeira avaliação',
    ko: '첫 리뷰 받기', ja: '初めてのレビューを受け取る', pl: 'Otrzymaj swoją pierwszą opinię' } },
  { key: 'profileComplete', points: 100, icon: '🪪', limit: 'once', since: 607, t: {
    fr: 'Profil complété à 100 %', en: 'Profile 100% complete', es: 'Perfil completo al 100 %',
    de: 'Profil zu 100 % ausgefüllt', it: 'Profilo completo al 100%', pt: 'Perfil 100% completo',
    ko: '프로필 100% 완성', ja: 'プロフィールを100％完成', pl: 'Profil uzupełniony w 100%' } },
  { key: 'pioneer', points: 200, icon: '🚩', limit: 'once', since: 607, t: {
    fr: 'Pionnier : premier gardien ou promeneur de ta zone (25 km)', en: 'Pioneer: first sitter or walker in your area (25 km)',
    es: 'Pionero: primer cuidador o paseador de tu zona (25 km)', de: 'Pionier: erster Sitter oder Gassigeher in deiner Gegend (25 km)',
    it: 'Pioniere: primo pet sitter o dog walker della tua zona (25 km)', pt: 'Pioneiro: primeiro cuidador ou passeador da tua zona (25 km)',
    ko: '개척자: 내 지역(25km) 첫 시터 또는 워커', ja: 'パイオニア：あなたの地域（25km）で最初のシッター／ウォーカー', pl: 'Pionier: pierwsza opiekunka lub wyprowadzacz w okolicy (25 km)' } },
  { key: 'streak7', points: 50, icon: '🔥', limit: 'streak', since: 607, t: {
    fr: '7 jours d\'activité de suite', en: '7 days of activity in a row', es: '7 días de actividad seguidos',
    de: '7 Tage Aktivität am Stück', it: '7 giorni di attività di fila', pt: '7 dias de atividade seguidos',
    ko: '7일 연속 활동', ja: '7日連続でアクティブ', pl: '7 dni aktywności z rzędu' } },
]);

// ── RÉCOMPENSES (échange de points dépensables) ─────────────────────────────
// kind : 'free_days' (plan + days, grantFreePeriod) | 'pawboost' (days,
//        boostExpiry) | 'avatar_frame' (pawGoldFrame). once = 1 fois par personne.
const REWARDS = Object.freeze([
  // Petites récompenses (BOB 02/10) : atteignables en 1 à 3 semaines d'activité, répétables.
  { id: 'perk_boost_24h', tier: 1, cost: 500, kind: 'pawboost', days: 1, boostTier: 'bronze', once: false, icon: '🚀', t: {
    fr: '24 h de PawBoost : mis en avant sur la carte', en: '24 h of PawBoost: featured on the map',
    es: '24 h de PawBoost: destacado en el mapa', de: '24 Std. PawBoost: hervorgehoben auf der Karte',
    it: '24 h di PawBoost: in evidenza sulla mappa', pt: '24 h de PawBoost: em destaque no mapa',
    ko: 'PawBoost 24시간: 지도에서 돋보이기', ja: 'PawBoost 24時間：マップで目立つ', pl: '24 h PawBoost: wyróżnienie na mapie' } },
  { id: 'perk_gold_frame', tier: 2, cost: 1000, kind: 'avatar_frame', once: true, icon: '🖼️', t: {
    fr: 'Cadre doré autour de ta photo', en: 'Gold frame around your photo', es: 'Marco dorado alrededor de tu foto',
    de: 'Goldener Rahmen um dein Foto', it: 'Cornice dorata intorno alla tua foto', pt: 'Moldura dourada à volta da tua foto',
    ko: '프로필 사진 금색 테두리', ja: 'プロフィール写真の金色フレーム', pl: 'Złota ramka wokół zdjęcia' } },
  { id: 'sub_days_pf_3', tier: 3, cost: 1500, kind: 'free_days', days: 3, plan: 'monthly', once: false, icon: '🐾', t: {
    fr: '3 jours de PawFollow offerts', en: '3 days of PawFollow free', es: '3 días de PawFollow gratis',
    de: '3 Tage PawFollow geschenkt', it: '3 giorni di PawFollow in regalo', pt: '3 dias de PawFollow grátis',
    ko: 'PawFollow 3일 무료', ja: 'PawFollow 3日間無料', pl: '3 dni PawFollow gratis' } },
  { id: 'sub_days_ps_7', tier: 4, cost: 4000, kind: 'free_days', days: 7, plan: 'pawspot', once: false, icon: '📍', t: {
    fr: '7 jours de PawSpot offerts', en: '7 days of PawSpot free', es: '7 días de PawSpot gratis',
    de: '7 Tage PawSpot geschenkt', it: '7 giorni di PawSpot in regalo', pt: '7 dias de PawSpot grátis',
    ko: 'PawSpot 7일 무료', ja: 'PawSpot 7日間無料', pl: '7 dni PawSpot gratis' } },
  { id: 'perk_boost_3d', tier: 5, cost: 5000, kind: 'pawboost', days: 3, boostTier: 'bronze', once: false, icon: '🚀', t: {
    fr: '3 jours de PawBoost : mis en avant sur la carte', en: '3 days of PawBoost: featured on the map',
    es: '3 días de PawBoost: destacado en el mapa', de: '3 Tage PawBoost: hervorgehoben auf der Karte',
    it: '3 giorni di PawBoost: in evidenza sulla mappa', pt: '3 dias de PawBoost: em destaque no mapa',
    ko: 'PawBoost 3일: 지도에서 돋보이기', ja: 'PawBoost 3日間：マップで目立つ', pl: '3 dni PawBoost: wyróżnienie na mapie' } },
  // Grandes récompenses (une fois par personne).
  { id: 'sub_days_pp_7', tier: 6, cost: 50000, kind: 'free_days', days: 7, plan: 'premium_monthly', once: true, icon: '👑', t: {
    fr: '7 jours de Paw Premium offerts', en: '7 days of Paw Premium free', es: '7 días de Paw Premium gratis',
    de: '7 Tage Paw Premium geschenkt', it: '7 giorni di Paw Premium in regalo', pt: '7 dias de Paw Premium grátis',
    ko: 'Paw Premium 7일 무료', ja: 'Paw Premium 7日間無料', pl: '7 dni Paw Premium gratis' } },
  { id: 'sub_days_pp_14', tier: 7, cost: 100000, kind: 'free_days', days: 14, plan: 'premium_monthly', once: true, icon: '👑', t: {
    fr: '14 jours de Paw Premium offerts', en: '14 days of Paw Premium free', es: '14 días de Paw Premium gratis',
    de: '14 Tage Paw Premium geschenkt', it: '14 giorni di Paw Premium in regalo', pt: '14 dias de Paw Premium grátis',
    ko: 'Paw Premium 14일 무료', ja: 'Paw Premium 14日間無料', pl: '14 dni Paw Premium gratis' } },
  { id: 'sub_free_pf_1m', tier: 8, cost: 200000, kind: 'free_days', days: 30, plan: 'monthly', once: true, icon: '🟣', t: {
    fr: '30 jours de PawFollow offerts', en: '30 days of PawFollow free', es: '30 días de PawFollow gratis',
    de: '30 Tage PawFollow geschenkt', it: '30 giorni di PawFollow in regalo', pt: '30 dias de PawFollow grátis',
    ko: 'PawFollow 30일 무료', ja: 'PawFollow 30日間無料', pl: '30 dni PawFollow gratis' } },
  { id: 'sub_free_pp_1m', tier: 9, cost: 500000, kind: 'free_days', days: 30, plan: 'premium_monthly', once: true, icon: '🟡', t: {
    fr: '30 jours de Paw Premium offerts', en: '30 days of Paw Premium free', es: '30 días de Paw Premium gratis',
    de: '30 Tage Paw Premium geschenkt', it: '30 giorni di Paw Premium in regalo', pt: '30 dias de Paw Premium grátis',
    ko: 'Paw Premium 30일 무료', ja: 'Paw Premium 30日間無料', pl: '30 dni Paw Premium gratis' } },
  { id: 'sub_free_pp_3m', tier: 10, cost: 1000000, kind: 'free_days', days: 90, plan: 'premium_monthly', once: true, icon: '🌸', t: {
    fr: '90 jours de Paw Premium offerts', en: '90 days of Paw Premium free', es: '90 días de Paw Premium gratis',
    de: '90 Tage Paw Premium geschenkt', it: '90 giorni di Paw Premium in regalo', pt: '90 dias de Paw Premium grátis',
    ko: 'Paw Premium 90일 무료', ja: 'Paw Premium 90日間無料', pl: '90 dni Paw Premium gratis' } },
]);

// Anciennes réductions en % (v416) : plus échangeables depuis le 607.
const LEGACY_DISCOUNT_IDS = Object.freeze(['sub_disc_10', 'sub_disc_25', 'sub_disc_50']);

// Libellés des niveaux (les seuils et couleurs restent dans pawPointsService.LEVELS).
const LEVEL_TEXTS = Object.freeze({
  explorer: { fr: 'Explorateur', en: 'Explorer', es: 'Explorador', de: 'Entdecker', it: 'Esploratore', pt: 'Explorador', ko: '탐험가', ja: 'エクスプローラー', pl: 'Odkrywca' },
  contributor: { fr: 'Contributeur', en: 'Contributor', es: 'Colaborador', de: 'Mitwirkender', it: 'Contributore', pt: 'Colaborador', ko: '기여자', ja: 'コントリビューター', pl: 'Współtwórca' },
  expert: { fr: 'Expert', en: 'Expert', es: 'Experto', de: 'Experte', it: 'Esperto', pt: 'Especialista', ko: '전문가', ja: 'エキスパート', pl: 'Ekspert' },
  ambassador: { fr: 'Ambassadeur', en: 'Ambassador', es: 'Embajador', de: 'Botschafter', it: 'Ambasciatore', pt: 'Embaixador', ko: '앰배서더', ja: 'アンバサダー', pl: 'Ambasador' },
  pawmaster: { fr: 'PawMaster', en: 'PawMaster', es: 'PawMaster', de: 'PawMaster', it: 'PawMaster', pt: 'PawMaster', ko: 'PawMaster', ja: 'PawMaster', pl: 'PawMaster' },
  legend: { fr: 'Légendaire', en: 'Legendary', es: 'Legendario', de: 'Legendär', it: 'Leggendario', pt: 'Lendário', ko: '전설', ja: 'レジェンド', pl: 'Legendarny' },
  paw_legend: { fr: 'Paw Legend', en: 'Paw Legend', es: 'Paw Legend', de: 'Paw Legend', it: 'Paw Legend', pt: 'Paw Legend', ko: 'Paw Legend', ja: 'Paw Legend', pl: 'Paw Legend' },
});

// Avantages RÉELS d'un niveau (aucune promesse que le serveur ne tient pas).
const PERK_TEXTS = Object.freeze({
  badge: { fr: 'Badge de niveau dans le classement', en: 'Level badge in the leaderboard', es: 'Insignia de nivel en la clasificación', de: 'Level-Abzeichen in der Rangliste', it: 'Badge di livello in classifica', pt: 'Distintivo de nível na classificação', ko: '랭킹에 레벨 배지', ja: 'ランキングにレベルバッジ', pl: 'Odznaka poziomu w rankingu' },
  bonus_5: { fr: '+5 % de points sur chaque gain', en: '+5% points on every gain', es: '+5 % de puntos en cada ganancia', de: '+5 % Punkte auf jeden Gewinn', it: '+5% di punti su ogni guadagno', pt: '+5% de pontos em cada ganho', ko: '모든 획득 포인트 +5%', ja: '獲得ポイント+5％', pl: '+5% punktów za każdą aktywność' },
  bonus_10: { fr: '+10 % de points sur chaque gain', en: '+10% points on every gain', es: '+10 % de puntos en cada ganancia', de: '+10 % Punkte auf jeden Gewinn', it: '+10% di punti su ogni guadagno', pt: '+10% de pontos em cada ganho', ko: '모든 획득 포인트 +10%', ja: '獲得ポイント+10％', pl: '+10% punktów za każdą aktywność' },
  bonus_15: { fr: '+15 % de points sur chaque gain', en: '+15% points on every gain', es: '+15 % de puntos en cada ganancia', de: '+15 % Punkte auf jeden Gewinn', it: '+15% di punti su ogni guadagno', pt: '+15% de pontos em cada ganho', ko: '모든 획득 포인트 +15%', ja: '獲得ポイント+15％', pl: '+15% punktów za każdą aktywność' },
});
// Avantages par niveau (607). Les anciennes clés (coffres, PawBoost gratuit,
// visibilité…) n'étaient accordées par aucun code : retirées.
const LEVEL_PERKS_607 = Object.freeze({
  explorer: ['badge'], contributor: ['badge'], expert: ['badge', 'bonus_5'],
  ambassador: ['badge', 'bonus_10'], pawmaster: ['badge', 'bonus_10'],
  legend: ['badge', 'bonus_10'], paw_legend: ['badge', 'bonus_15'],
});
// Pour les apps ≤ 606 (elles ne connaissent pas `bonus_15`).
const LEVEL_PERKS_LEGACY = Object.freeze({ ...LEVEL_PERKS_607, paw_legend: ['badge', 'bonus_10'] });

const COLLECTION = Object.freeze({
  key: 'plush',
  icon: '🧸',
  t: {
    title: { fr: 'Collection de peluches', en: 'Plush collection', es: 'Colección de peluches', de: 'Plüschtier-Sammlung', it: 'Collezione di peluche', pt: 'Coleção de peluches', ko: '인형 컬렉션', ja: 'ぬいぐるみコレクション', pl: 'Kolekcja pluszaków' },
    detail: {
      fr: 'Chaque peluche attrapée pendant une Balade rejoint ta collection.',
      en: 'Every plush toy you catch during a Walk joins your collection.',
      es: 'Cada peluche que atrapas durante un Paseo se une a tu colección.',
      de: 'Jedes Plüschtier, das du bei einem Spaziergang fängst, kommt in deine Sammlung.',
      it: 'Ogni peluche preso durante una Passeggiata entra nella tua collezione.',
      pt: 'Cada peluche apanhado durante um Passeio junta-se à tua coleção.',
      ko: '산책 중 잡은 인형은 모두 내 컬렉션에 들어가요.',
      ja: 'お散歩中につかまえたぬいぐるみはコレクションに追加されます。',
      pl: 'Każdy pluszak złapany podczas Spaceru trafia do Twojej kolekcji.',
    },
  },
});

// Règles affichées (honnêteté) : 9 langues.
const NOTES = Object.freeze({
  activityOnly: {
    fr: 'Les PawPoints se gagnent uniquement par ton activité dans l\'app. Ils ne s\'achètent pas et ne se changent jamais en argent.',
    en: 'PawPoints are earned only through your activity in the app. They can\'t be bought and are never exchanged for money.',
    es: 'Los PawPoints solo se ganan con tu actividad en la app. No se compran y nunca se cambian por dinero.',
    de: 'PawPoints sammelst du nur durch deine Aktivität in der App. Man kann sie nicht kaufen und nie in Geld tauschen.',
    it: 'I PawPoints si guadagnano solo con la tua attività nell\'app. Non si comprano e non si convertono mai in denaro.',
    pt: 'Os PawPoints ganham-se apenas com a tua atividade na app. Não se compram e nunca se trocam por dinheiro.',
    ko: 'PawPoints는 앱 활동으로만 얻을 수 있어요. 구매할 수 없으며 현금으로 바꿀 수 없어요.',
    ja: 'PawPointsはアプリでの活動でのみ貯まります。購入はできず、お金に交換されることはありません。',
    pl: 'PawPoints zdobywasz wyłącznie dzięki aktywności w aplikacji. Nie można ich kupić ani wymienić na pieniądze.',
  },
  premiumDouble: {
    fr: 'Avec Paw Premium actif, chaque gain compte double.',
    en: 'With an active Paw Premium, every gain counts double.',
    es: 'Con Paw Premium activo, cada ganancia cuenta doble.',
    de: 'Mit aktivem Paw Premium zählt jeder Gewinn doppelt.',
    it: 'Con Paw Premium attivo, ogni guadagno vale doppio.',
    pt: 'Com o Paw Premium ativo, cada ganho conta a dobrar.',
    ko: 'Paw Premium 이용 중에는 모든 획득 포인트가 2배예요.',
    ja: 'Paw Premium利用中は、獲得ポイントが2倍になります。',
    pl: 'Z aktywnym Paw Premium każdy zdobyty punkt liczy się podwójnie.',
  },
  lifetimeLevel: {
    fr: 'Ton niveau dépend des points gagnés à vie : échanger une récompense ne te fait jamais descendre de niveau.',
    en: 'Your level depends on lifetime points: redeeming a reward never lowers your level.',
    es: 'Tu nivel depende de los puntos ganados en total: canjear una recompensa nunca te baja de nivel.',
    de: 'Dein Level hängt von deinen insgesamt gesammelten Punkten ab: Eine Belohnung einzulösen senkt es nie.',
    it: 'Il tuo livello dipende dai punti guadagnati in totale: riscattare un premio non ti fa mai scendere di livello.',
    pt: 'O teu nível depende dos pontos ganhos no total: trocar uma recompensa nunca te faz descer de nível.',
    ko: '레벨은 누적 획득 포인트로 정해져요. 보상을 교환해도 레벨은 내려가지 않아요.',
    ja: 'レベルは累計獲得ポイントで決まります。特典と交換してもレベルは下がりません。',
    pl: 'Poziom zależy od punktów zdobytych łącznie: wymiana nagrody nigdy go nie obniża.',
  },
});

const rewardById = (id) => REWARDS.find((r) => r.id === id) || null;
const earnRuleByKey = (k) => EARN_RULES.find((r) => r.key === k) || null;
const isLegacyDiscountId = (id) => LEGACY_DISCOUNT_IDS.includes(String(id || ''));

/** Points d'un gain (0 si inconnu). */
const pointsFor = (key) => {
  const r = earnRuleByKey(key);
  return r ? r.points : 0;
};

/**
 * Contrat public 607 (voir ~/hopetsit-social/CONTRAT_607_pawpoints.md).
 * `levels` vient de pawPointsService (seuils/couleurs) pour éviter un cycle.
 */
function buildCatalog607(levels = []) {
  return {
    version: 607,
    langs: [...LANGS],
    earn: EARN_RULES.map((r) => ({
      key: r.key, points: r.points, icon: r.icon, limit: r.limit, since: r.since, texts: { ...r.t },
    })),
    levels: levels.map((l) => ({
      index: l.index, key: l.key, min: l.min, emoji: l.emoji, color: l.color, bonusPct: l.bonusPct,
      perks: [...(LEVEL_PERKS_607[l.key] || ['badge'])],
      texts: { ...(LEVEL_TEXTS[l.key] || {}) },
    })),
    perkTexts: JSON.parse(JSON.stringify(PERK_TEXTS)),
    rewards: REWARDS.map((r) => ({
      id: r.id, tier: r.tier, cost: r.cost, kind: r.kind, icon: r.icon, once: r.once,
      ...(r.days ? { days: r.days } : {}),
      ...(r.plan ? { plan: r.plan } : {}),
      texts: { ...r.t },
    })),
    collection: { key: COLLECTION.key, icon: COLLECTION.icon, texts: JSON.parse(JSON.stringify(COLLECTION.t)) },
    notes: JSON.parse(JSON.stringify(NOTES)),
    rules: { activityOnly: true, money: false, percentDiscounts: false, premiumDoubles: true },
  };
}

module.exports = {
  LANGS,
  EARN_RULES,
  REWARDS,
  LEGACY_DISCOUNT_IDS,
  LEVEL_TEXTS,
  PERK_TEXTS,
  LEVEL_PERKS_607,
  LEVEL_PERKS_LEGACY,
  COLLECTION,
  NOTES,
  rewardById,
  earnRuleByKey,
  isLegacyDiscountId,
  pointsFor,
  buildCatalog607,
};
