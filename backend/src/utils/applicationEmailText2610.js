/**
 * 2610 (ZOE, 26/10/2026 — décision de Daniel, proposition A de SAM) — TEXTE de l'e-mail
 * « candidats reçus » au propriétaire, 9 langues (fr en es de it pt ko ja pl).
 *
 *   · objet = la demande : « Hanene peut garder votre chat à Clamart · 18 €/jour » (prix du
 *     moteur unique : tarif unitaire si « dates à prévoir », total sinon) ; plusieurs nouveaux
 *     candidats : « 3 nouveaux candidats pour garder votre chat à Clamart » ;
 *   · 1 à 3 cartes : photo (ou initiale), prénom, rôle, prix, ~km, note et avis ;
 *   · « + N autres candidats » ; ligne « posez vos dates » pour une demande sans dates ;
 *   · bouton « Voir mes candidats ». Jamais « payez en 2 minutes ».
 * Toute valeur venue d'un utilisateur (prénom, ville, URL de photo) est ÉCHAPPÉE ici :
 * `candidatesHtml2610` est le seul champ HTML brut accepté par le notificationSender.
 */
const { enrichPrice620, priceData620 } = require('./applicationNewText617');

const LANGS = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const lang2 = (l) => {
  const s = String(l || '').slice(0, 2).toLowerCase();
  return LANGS.includes(s) ? s : 'en';
};

const esc = (v) => String(v == null ? '' : v)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/** Famille de service : garde (sit), visite (visit), balade (walk). */
const serviceFamily = (key) => {
  const k = String(key || '').toLowerCase();
  if (k === 'home_visit' || k.includes('visit')) return 'visit';
  if (k === 'dog_walking' || k.includes('walk')) return 'walk';
  return 'sit';
};

/** Animal : dog | dogs | cat | cats | pet | pets. */
const petKey = (post) => {
  const types = (Array.isArray(post && post.animalTypes) ? post.animalTypes : [])
    .map((t) => String(t || '').toLowerCase().trim()).filter(Boolean);
  const kinds = new Set(types.map((t) => (/(dog|chien|perro|hund|cane|cão|cao|pies)/.test(t) ? 'dog' : /(cat|chat|gato|katze|gatto|kot)/.test(t) ? 'cat' : 'pet')));
  const count = Math.max(Number(post && post.animalCount) || 0, types.length, 1);
  if (kinds.size === 1) {
    const k = [...kinds][0];
    return count > 1 ? `${k}s` : k;
  }
  return count > 1 || kinds.size > 1 ? 'pets' : 'pet';
};

const T = {
  fr: {
    choose: (n) => `Choisir ${n}`, // 2710 (SAM) — bouton direct de chaque carte
    verb: { sit: 'garder', visit: 'rendre visite à', walk: 'promener' },
    pet: { dog: 'votre chien', dogs: 'vos chiens', cat: 'votre chat', cats: 'vos chats', pet: 'votre animal', pets: 'vos animaux' },
    one: (n, v, p, c) => `${n} peut ${v} ${p}${c ? ` à ${c}` : ''}`,
    many: (k, v, p, c) => `${k} nouveaux candidats pour ${v} ${p}${c ? ` à ${c}` : ''}`,
    role: { sitter: 'Pet-sitter', walker: 'Promeneur' },
    reviews: (k) => `${k} avis`, noReviews: 'Pas encore d’avis',
    others: (k) => (k > 1 ? `+ ${k} autres candidats sur votre demande` : '+ 1 autre candidat sur votre demande'),
    dates: 'Posez vos dates pour voir le prix total de chaque candidat.',
    cta: 'Voir mes candidats',
    weekly: 'tarif semaine appliqué',
  },
  en: {
    choose: (n) => `Choose ${n}`, // 2710 (SAM) — bouton direct de chaque carte
    verb: { sit: 'look after', visit: 'visit', walk: 'walk' },
    pet: { dog: 'your dog', dogs: 'your dogs', cat: 'your cat', cats: 'your cats', pet: 'your pet', pets: 'your pets' },
    one: (n, v, p, c) => `${n} can ${v} ${p}${c ? ` in ${c}` : ''}`,
    many: (k, v, p, c) => `${k} new candidates to ${v} ${p}${c ? ` in ${c}` : ''}`,
    role: { sitter: 'Pet sitter', walker: 'Dog walker' },
    reviews: (k) => `${k} review${k > 1 ? 's' : ''}`, noReviews: 'No reviews yet',
    others: (k) => `+ ${k} more candidate${k > 1 ? 's' : ''} on your request`,
    dates: 'Set your dates to see each candidate’s total price.',
    cta: 'See my candidates',
    weekly: 'weekly rate applied',
  },
  es: {
    choose: (n) => `Elegir a ${n}`, // 2710 (SAM) — bouton direct de chaque carte
    verb: { sit: 'cuidar a', visit: 'visitar a', walk: 'pasear a' },
    pet: { dog: 'su perro', dogs: 'sus perros', cat: 'su gato', cats: 'sus gatos', pet: 'su mascota', pets: 'sus mascotas' },
    one: (n, v, p, c) => `${n} puede ${v} ${p}${c ? ` en ${c}` : ''}`,
    many: (k, v, p, c) => `${k} nuevos candidatos para ${v} ${p}${c ? ` en ${c}` : ''}`,
    role: { sitter: 'Cuidador', walker: 'Paseador' },
    reviews: (k) => `${k} opinión${k > 1 ? 'es' : ''}`.replace('opiniónes', 'opiniones'), noReviews: 'Aún sin opiniones',
    others: (k) => `+ ${k} candidato${k > 1 ? 's' : ''} más en su solicitud`,
    dates: 'Indique sus fechas para ver el precio total de cada candidato.',
    cta: 'Ver mis candidatos',
    weekly: 'tarifa semanal aplicada',
  },
  de: {
    choose: (n) => `${n} auswählen`, // 2710 (SAM) — bouton direct de chaque carte
    verb: { sit: 'betreuen', visit: 'besuchen', walk: 'ausführen' },
    pet: { dog: 'Ihren Hund', dogs: 'Ihre Hunde', cat: 'Ihre Katze', cats: 'Ihre Katzen', pet: 'Ihr Haustier', pets: 'Ihre Haustiere' },
    one: (n, v, p, c) => `${n} kann ${p}${c ? ` in ${c}` : ''} ${v}`,
    many: (k, v, p, c) => `${k} neue Bewerbungen für ${p}${c ? ` in ${c}` : ''}`,
    role: { sitter: 'Tiersitter', walker: 'Gassigeher' },
    reviews: (k) => `${k} Bewertung${k > 1 ? 'en' : ''}`, noReviews: 'Noch keine Bewertungen',
    others: (k) => `+ ${k} weitere Bewerbung${k > 1 ? 'en' : ''} auf Ihre Anfrage`,
    dates: 'Legen Sie Ihre Daten fest, um den Gesamtpreis jedes Bewerbers zu sehen.',
    cta: 'Meine Bewerber ansehen',
    weekly: 'Wochentarif angewendet',
  },
  it: {
    choose: (n) => `Scegli ${n}`, // 2710 (SAM) — bouton direct de chaque carte
    verb: { sit: 'accudire', visit: 'fare visita a', walk: 'portare a spasso' },
    pet: { dog: 'il suo cane', dogs: 'i suoi cani', cat: 'il suo gatto', cats: 'i suoi gatti', pet: 'il suo animale', pets: 'i suoi animali' },
    one: (n, v, p, c) => `${n} può ${v} ${p}${c ? ` a ${c}` : ''}`,
    many: (k, v, p, c) => `${k} nuovi candidati per ${v} ${p}${c ? ` a ${c}` : ''}`,
    role: { sitter: 'Pet sitter', walker: 'Dog walker' },
    reviews: (k) => `${k} recension${k > 1 ? 'i' : 'e'}`, noReviews: 'Ancora nessuna recensione',
    others: (k) => (k > 1 ? `+ altri ${k} candidati sulla sua richiesta` : '+ 1 altro candidato sulla sua richiesta'),
    dates: 'Indichi le date per vedere il prezzo totale di ogni candidato.',
    cta: 'Vedi i miei candidati',
    weekly: 'tariffa settimanale applicata',
  },
  pt: {
    choose: (n) => `Escolher ${n}`, // 2710 (SAM) — bouton direct de chaque carte
    verb: { sit: 'ficar com', visit: 'visitar', walk: 'passear' },
    pet: { dog: 'o seu cão', dogs: 'os seus cães', cat: 'o seu gato', cats: 'os seus gatos', pet: 'o seu animal', pets: 'os seus animais' },
    one: (n, v, p, c) => `${n} pode ${v} ${p}${c ? ` em ${c}` : ''}`,
    many: (k, v, p, c) => `${k} novos candidatos para ${v} ${p}${c ? ` em ${c}` : ''}`,
    role: { sitter: 'Pet sitter', walker: 'Passeador' },
    reviews: (k) => `${k} avaliaç${k > 1 ? 'ões' : 'ão'}`, noReviews: 'Ainda sem avaliações',
    others: (k) => `+ ${k} outro${k > 1 ? 's' : ''} candidato${k > 1 ? 's' : ''} no seu pedido`,
    dates: 'Indique as suas datas para ver o preço total de cada candidato.',
    cta: 'Ver os meus candidatos',
    weekly: 'tarifa semanal aplicada',
  },
  ko: {
    choose: (n) => `${n}님 선택`, // 2710 (SAM) — bouton direct de chaque carte
    svc: { sit: '펫시팅', visit: '방문 돌봄', walk: '산책' },
    one: (n, s, c) => `${n}님이 지원했습니다 · ${s}${c ? ` · ${c}` : ''}`,
    many: (k, s, c) => `새 지원자 ${k}명 · ${s}${c ? ` · ${c}` : ''}`,
    role: { sitter: '펫시터', walker: '산책 도우미' },
    reviews: (k) => `리뷰 ${k}개`, noReviews: '아직 리뷰 없음',
    others: (k) => `+ 요청에 지원자 ${k}명 더`,
    dates: '날짜를 정하면 지원자별 총액을 볼 수 있습니다.',
    cta: '내 지원자 보기',
    weekly: '주간 요금 적용',
  },
  ja: {
    choose: (n) => `${n}さんを選ぶ`, // 2710 (SAM) — bouton direct de chaque carte
    svc: { sit: 'ペットシッター', visit: '訪問ケア', walk: '散歩' },
    one: (n, s, c) => `${n}さんが応募しました · ${s}${c ? ` · ${c}` : ''}`,
    many: (k, s, c) => `新しい応募者${k}名 · ${s}${c ? ` · ${c}` : ''}`,
    role: { sitter: 'ペットシッター', walker: '散歩代行' },
    reviews: (k) => `レビュー${k}件`, noReviews: 'まだレビューはありません',
    others: (k) => `+ ほかに応募者${k}名`,
    dates: '日程を設定すると、各応募者の合計料金が表示されます。',
    cta: '応募者を見る',
    weekly: '週料金を適用',
  },
  pl: {
    choose: (n) => `Wybierz: ${n}`, // 2710 (SAM) — bouton direct de chaque carte
    svc: { sit: 'opieka nad zwierzęciem', visit: 'wizyty domowe', walk: 'spacer z psem' },
    one: (n, s, c) => `${n} zgłasza się: ${s}${c ? ` · ${c}` : ''}`,
    many: (k, s, c) => `Nowi kandydaci (${k}): ${s}${c ? ` · ${c}` : ''}`,
    role: { sitter: 'Opiekun', walker: 'Wyprowadzacz psów' },
    reviews: (k) => `opinie: ${k}`, noReviews: 'Brak opinii',
    others: (k) => `+ kolejni kandydaci (${k}) do Twojego zgłoszenia`,
    dates: 'Ustaw daty, aby zobaczyć cenę całkowitą każdego kandydata.',
    cta: 'Zobacz kandydatów',
    weekly: 'zastosowano stawkę tygodniową',
  },
};

const cityOfPost = (post) => String((post && post.location && post.location.city) || (post && post.city) || '').trim();

/** Phrase « <Prénom> peut garder votre chat à Clamart » (sans prix). */
function onePhrase(lang, { name, service, post }) {
  const L = T[lang2(lang)];
  const fam = serviceFamily(service);
  const city = cityOfPost(post);
  if (L.svc) return L.one(name, L.svc[fam], city);
  return L.one(name, L.verb[fam], L.pet[petKey(post)], city);
}
function manyPhrase(lang, { count, service, post }) {
  const L = T[lang2(lang)];
  const fam = serviceFamily(service);
  const city = cityOfPost(post);
  if (L.svc) return L.many(count, L.svc[fam], city);
  return L.many(count, L.verb[fam], L.pet[petKey(post)], city);
}

/** « 18 €/jour » ou « 324 € au total » depuis le bloc pricing (moteur unique) ; '' sinon. */
function priceLabel(lang, pricing) {
  if (!pricing || pricing.stale === true) return '';
  const d = enrichPrice620(priceData620(pricing), lang2(lang));
  return String(d.priceText || '').replace(/^\s*·\s*/, '');
}

const initialColor = (role) => (role === 'walker' ? '#15803D' : '#1E4FB0');

/**
 * Cartes HTML (1 à 3) — valeurs échappées.
 * @param {string} lang
 * @param {Array<{name:string, role:'sitter'|'walker', avatar?:string, pricing?:object, km?:number|null, rating?:number, reviews?:number}>} cards
 */
function cardsHtml(lang, cards) {
  const L = T[lang2(lang)];
  return cards.map((c) => {
    const name = esc(c.name || 'HoPetSit');
    const avatar = /^https:\/\//.test(String(c.avatar || ''))
      ? `<img src="${esc(c.avatar)}" width="52" height="52" alt="" style="display:block;width:52px;height:52px;border-radius:26px;object-fit:cover">`
      : `<div style="width:52px;height:52px;border-radius:26px;background:${initialColor(c.role)};color:#FFFFFF;font-size:22px;font-weight:700;line-height:52px;text-align:center">${esc(String(c.name || 'H').trim().charAt(0).toUpperCase())}</div>`;
    const reviews = Number(c.reviews) || 0;
    const rating = Number(c.rating) || 0;
    const stars = reviews > 0 && rating > 0 ? `★ ${rating.toFixed(1).replace('.', lang2(lang) === 'fr' ? ',' : '.')} · ${esc(L.reviews(reviews))}` : esc(L.noReviews);
    const meta = [esc(L.role[c.role === 'walker' ? 'walker' : 'sitter']), Number.isFinite(Number(c.km)) && c.km != null ? `~${Math.max(1, Math.round(Number(c.km)))} km` : '', stars].filter(Boolean).join(' · ');
    const price = priceLabel(lang, c.pricing);
    return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:separate;margin:0 0 10px;background:#FFF6F2;border-radius:14px"><tr>`
      + `<td width="68" style="padding:12px 0 12px 12px;vertical-align:middle">${avatar}</td>`
      + `<td style="padding:12px;vertical-align:middle"><div style="font-size:17px;font-weight:700;color:#231715">${name}</div><div style="font-size:13px;color:#6E4F48;line-height:1.4">${meta}</div></td>`
      + (price ? `<td style="padding:12px 14px 12px 0;vertical-align:middle;text-align:right;white-space:nowrap;font-size:16px;font-weight:800;color:#9E1F0B">${esc(price)}${c.pricing && c.pricing.weeklyApplied === true ? `<div style="font-size:11px;font-weight:700;color:#15803D">${esc(L.weekly)}</div>` : ''}</td>` : '')
      + '</tr>'
      // 2710 (SAM, ordre de Daniel « que les propriétaires valident et paient ») — bouton DIRECT
      // « Choisir <prénom> » : ouvre la page de ce candidat (session sans mot de passe pour les
      // contacts de la pub), où un seul geste confirme le choix et mène au paiement.
      + (/^https:\/\//.test(String(c.link || '')) ? `<tr><td colspan="${price ? 3 : 2}" style="padding:0 12px 12px"><a href="${esc(c.link)}" style="display:block;padding:12px 10px;background:#C92A12;color:#FFFFFF;text-decoration:none;border-radius:12px;font-size:16px;font-weight:800;text-align:center;font-family:sans-serif">${esc(L.choose(String(c.name || 'HoPetSit')))}</a></td></tr>` : '')
      + '</table>';
  }).join('');
}

/**
 * Données de rendu de l'e-mail (gabarit application_new_2610).
 * @param {{lang:string, post:object, cards:object[], newCount:number, totalPending:number}} p
 */
function buildEmailData({ lang, post, cards, newCount, totalPending }) {
  const l = lang2(lang);
  const L = T[l];
  const service = (Array.isArray(post && post.serviceTypes) ? post.serviceTypes[0] : post && post.serviceTypes) || '';
  const first = cards[0] || {};
  let subjectLine;
  if (newCount <= 1) {
    const price = priceLabel(l, first.pricing);
    subjectLine = `${onePhrase(l, { name: first.name || 'HoPetSit', service, post })}${price ? ` · ${price}` : ''}`;
  } else {
    subjectLine = manyPhrase(l, { count: newCount, service, post });
  }
  const others = Math.max(0, Number(totalPending || 0) - cards.length);
  const tbd = String((post && post.dateMode) || '').toLowerCase() === 'tbd'
    || (!(post && post.startDate) && !(post && post.endDate) && !(post && post.dateMode));
  return {
    subjectLine,
    candidatesHtml2610: cardsHtml(l, cards)
      + (others > 0 ? `<p style="margin:4px 0 0;font-size:14px;color:#6E4F48">${esc(L.others(others))}</p>` : '')
      + (tbd ? `<p style="margin:12px 0 0;padding:10px 12px;background:#FBE9E5;border-radius:10px;font-size:14px;font-weight:600;color:#9E1F0B">${esc(L.dates)}</p>` : ''),
    ctaLabel: L.cta,
  };
}

module.exports = { LANGS, T, lang2, esc, serviceFamily, petKey, onePhrase, manyPhrase, priceLabel, cardsHtml, buildEmailData, cityOfPost };
