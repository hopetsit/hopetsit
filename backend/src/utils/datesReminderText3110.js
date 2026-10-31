/**
 * 3110 (ADA, ordre de Daniel via BOB du 31/10 soir « règle tout, que les propriétaires revenus
 * PAIENT ») — TEXTES, 9 langues (fr en es de it pt ko ja pl) :
 *   · l'e-mail « N gardiens sont prêts — posez vos dates » (services/datesReminder3110) ;
 *   · la mention « fêtes » (dates qui touchent le 15/12 → 06/01), reprise aussi par l'e-mail
 *     « candidats reçus » 2610 et donc par la relance 2810.
 * Même registre que l'e-mail 2610 (vouvoiement, mêmes mots pour l'animal et le service).
 * Aucune valeur chiffrée inventée : le nombre de gardiens est compté, les tarifs sont ceux des
 * candidatures (moteur unique), « 72 h » est la règle d'annulation réelle (self-cancel 2910).
 */
const base = require('./applicationEmailText2610');

const HOLIDAY = {
  fr: 'Les gardiens se réservent tôt pour les fêtes.',
  en: 'Sitters get booked early for the holidays.',
  es: 'Los cuidadores se reservan pronto para las fiestas.',
  de: 'Tiersitter werden für die Feiertage früh gebucht.',
  it: 'Per le feste i pet sitter vengono prenotati presto.',
  pt: 'Para as festas, os cuidadores são reservados cedo.',
  ko: '연휴에는 펫시터 예약이 일찍 이루어집니다.',
  ja: '年末年始はペットシッターの予約が早めに入ります。',
  pl: 'Na święta opiekunowie są rezerwowani wcześnie.',
};

const DAY = 24 * 3600 * 1000;
/** Les dates de la demande touchent-elles la période des fêtes (15/12 → 06/01 inclus, toute année) ? */
function touchesHolidays(post) {
  const s = post && post.startDate ? new Date(post.startDate).getTime() : NaN;
  if (!Number.isFinite(s)) return false;
  const e0 = post && post.endDate ? new Date(post.endDate).getTime() : NaN;
  const e = Number.isFinite(e0) && e0 >= s ? e0 : s;
  const y0 = new Date(s).getUTCFullYear() - 1;
  const y1 = new Date(e).getUTCFullYear();
  for (let y = y0; y <= y1; y += 1) {
    const from = Date.UTC(y, 11, 15);
    const to = Date.UTC(y + 1, 0, 6) + DAY - 1;
    if (s <= to && e >= from) return true;
  }
  return false;
}

/** Ligne HTML « fêtes » (déjà échappée) ou ''. */
function holidayHtml(lang, post) {
  if (!touchesHolidays(post)) return '';
  const l = base.lang2(lang);
  return `<p style="margin:12px 0 0;padding:10px 12px;background:#FFF4D6;border-radius:10px;font-size:14px;font-weight:700;color:#7A4B00">${base.esc(HOLIDAY[l] || HOLIDAY.en)}</p>`;
}

const D = {
  fr: {
    ready: (k, fam, v, p, c) => {
      const who = fam === 'walk' ? (k > 1 ? 'promeneurs' : 'promeneur') : (k > 1 ? 'gardiens' : 'gardien');
      return `${k} ${who} ${k > 1 ? 'sont prêts' : 'est prêt'} à ${v} ${p}${c ? ` à ${c}` : ''}`;
    },
    lead: 'Posez vos dates : vous verrez leur prix total et vous pourrez choisir et payer — annulation gratuite jusqu’à 72 h avant.',
    note: 'Tarifs indicatifs : le prix total s’affiche dès que vos dates sont posées.',
    cta: 'Poser mes dates',
  },
  en: {
    ready: (k, fam, v, p, c) => {
      const who = fam === 'walk' ? (k > 1 ? 'dog walkers' : 'dog walker') : (k > 1 ? 'sitters' : 'sitter');
      return `${k} ${who} ${k > 1 ? 'are' : 'is'} ready to ${v} ${p}${c ? ` in ${c}` : ''}`;
    },
    lead: 'Set your dates: you’ll see their total price and can choose and pay — free cancellation up to 72 h before.',
    note: 'Indicative rates: the total price appears as soon as your dates are set.',
    cta: 'Set my dates',
  },
  es: {
    ready: (k, fam, v, p, c) => {
      const who = fam === 'walk' ? (k > 1 ? 'paseadores' : 'paseador') : (k > 1 ? 'cuidadores' : 'cuidador');
      return `${k} ${who} ${k > 1 ? 'están listos' : 'está listo'} para ${v} ${p}${c ? ` en ${c}` : ''}`;
    },
    lead: 'Indique sus fechas: verá su precio total y podrá elegir y pagar — cancelación gratuita hasta 72 h antes.',
    note: 'Tarifas orientativas: el precio total aparece en cuanto indique sus fechas.',
    cta: 'Indicar mis fechas',
  },
  de: {
    ready: (k, fam, v, p, c) => {
      const who = fam === 'walk' ? 'Gassigeher' : 'Tiersitter';
      const zu = v === 'ausführen' ? 'auszuführen' : `zu ${v}`;
      return `${k} ${who} ${k > 1 ? 'sind' : 'ist'} bereit, ${p}${c ? ` in ${c}` : ''} ${zu}`;
    },
    lead: 'Legen Sie Ihre Daten fest: Sie sehen dann den Gesamtpreis und können auswählen und bezahlen – kostenlose Stornierung bis 72 Std. vorher.',
    note: 'Richtpreise: Der Gesamtpreis erscheint, sobald Ihre Daten feststehen.',
    cta: 'Meine Daten festlegen',
  },
  it: {
    ready: (k, fam, v, p, c) => {
      const who = fam === 'walk' ? 'dog walker' : 'pet sitter';
      const a = /^[aeiou]/i.test(v) ? 'ad' : 'a';
      return `${k} ${who} ${k > 1 ? 'sono pronti' : 'è pronto'} ${a} ${v} ${p}${c ? ` a ${c}` : ''}`;
    },
    lead: 'Indichi le date: vedrà il prezzo totale e potrà scegliere e pagare — cancellazione gratuita fino a 72 h prima.',
    note: 'Tariffe indicative: il prezzo totale compare appena indica le date.',
    cta: 'Indicare le mie date',
  },
  pt: {
    ready: (k, fam, v, p, c) => {
      const who = fam === 'walk' ? (k > 1 ? 'passeadores' : 'passeador') : (k > 1 ? 'cuidadores' : 'cuidador');
      return `${k} ${who} ${k > 1 ? 'estão prontos' : 'está pronto'} para ${v} ${p}${c ? ` em ${c}` : ''}`;
    },
    lead: 'Indique as suas datas: verá o preço total e poderá escolher e pagar — cancelamento gratuito até 72 h antes.',
    note: 'Tarifas indicativas: o preço total aparece assim que indicar as datas.',
    cta: 'Indicar as minhas datas',
  },
  ko: {
    ready: (k, fam, s, c) => `${fam === 'walk' ? '산책 도우미' : '펫시터'} ${k}명이 기다리고 있습니다 · ${s}${c ? ` · ${c}` : ''}`,
    lead: '날짜를 정하면 총액을 확인하고 선택해 결제할 수 있습니다. 72시간 전까지 무료 취소.',
    note: '표시된 요금은 참고용이며, 날짜를 정하면 총액이 표시됩니다.',
    cta: '날짜 정하기',
  },
  ja: {
    ready: (k, fam, s, c) => `${fam === 'walk' ? '散歩代行' : 'ペットシッター'}${k}名が対応できます · ${s}${c ? ` · ${c}` : ''}`,
    lead: '日程を設定すると合計料金を確認し、選んで支払うことができます。72時間前まで無料キャンセル。',
    note: '料金は目安です。日程を設定すると合計料金が表示されます。',
    cta: '日程を設定する',
  },
  pl: {
    ready: (k, fam, s, c) => `${fam === 'walk' ? 'Wyprowadzacze psów' : 'Opiekunowie'} gotowi do pomocy (${k}): ${s}${c ? ` · ${c}` : ''}`,
    lead: 'Ustaw daty, aby zobaczyć cenę całkowitą, wybrać opiekuna i zapłacić — bezpłatne anulowanie do 72 h przed.',
    note: 'Stawki orientacyjne: cena całkowita pojawi się po ustawieniu dat.',
    cta: 'Ustaw daty',
  },
};

/** Phrase « 3 gardiens sont prêts à garder votre chat à Clamart ». */
function readyPhrase(lang, { count, service, post }) {
  const l = base.lang2(lang);
  const L = base.T[l];
  const fam = base.serviceFamily(service);
  const city = base.cityOfPost(post);
  const k = Math.max(1, Number(count) || 1);
  if (L.svc) return D[l].ready(k, fam, L.svc[fam], city);
  return D[l].ready(k, fam, L.verb[fam], L.pet[base.petKey(post)], city);
}

/**
 * Données du gabarit `application_new_2610` (objet + HTML serveur + libellé du bouton) pour la
 * relance « posez vos dates ». Cartes SANS bouton propre : le seul bouton est « Poser mes dates ».
 */
function buildEmailData({ lang, post, cards, totalPending }) {
  const l = base.lang2(lang);
  const T = D[l];
  const esc = base.esc;
  const service = (Array.isArray(post && post.serviceTypes) ? post.serviceTypes[0] : post && post.serviceTypes) || '';
  const subjectLine = readyPhrase(l, { count: totalPending, service, post });
  const others = Math.max(0, Number(totalPending || 0) - cards.length);
  const L = base.T[l];
  return {
    subjectLine,
    candidatesHtml2610:
      `<p style="margin:0 0 14px;font-size:16px;line-height:1.5;color:#231715">${esc(T.lead)}</p>`
      + base.cardsHtml(l, cards.map((c) => ({ ...c, link: '' })))
      + (others > 0 ? `<p style="margin:4px 0 0;font-size:14px;color:#6E4F48">${esc(L.others(others))}</p>` : '')
      + `<p style="margin:8px 0 0;font-size:13px;color:#6E4F48">${esc(T.note)}</p>`
      + holidayHtml(l, post),
    ctaLabel: T.cta,
  };
}

module.exports = { HOLIDAY, D, touchesHolidays, holidayHtml, readyPhrase, buildEmailData };
