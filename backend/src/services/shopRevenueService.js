'use strict';

/**
 * v566 — Revenus boutique par CANAL de vente (App Store · Google Play ·
 * carte/PayPal · offerts) et par PRODUIT. Daniel (18/09) : « je vois les
 * chiffres boutique Apple et Play Store, et que tout soit synchronisé dans la
 * comptabilité, l'onglet revenus aussi ».
 *
 * Module PUR (aucun accès base, aucun require de modèle) : il reçoit les
 * lignes d'achat déjà aplaties par adminRoutes.collectShopPurchases() et
 * renvoie les agrégats. C'est LE calcul unique réutilisé par le tableau de
 * bord, Mes revenus, la Comptabilité et l'Activité boutique — aucune formule
 * n'est dupliquée dans admin_dashboard.html.
 *
 * Règles (pas d'invention) :
 *  - montant ENREGISTRÉ sur l'achat → pris tel quel ;
 *  - Apple / Google Play : le montant enregistré est le prix CATALOGUE EUR
 *    (appleIapService.PRODUCT_MAP), pas le prix réellement payé dans la
 *    devise du store → ligne marquée « estimé » tant que la vraie valeur
 *    n'est pas stockée (champ `amountSource: 'store'`) ;
 *  - prestataire historique `stripe` = carte Airwallex, plein tarif enregistré
 *    même en cas de réduction → « estimé » ;
 *  - achat payant sans montant (webhook Airwallex : amount 0 / history sans
 *    montant) → prix catalogue COURANT du produit, « estimé » (le catalogue
 *    n'est pas historisé : il n'existe pas de prix « à la date de l'achat ») ;
 *  - ni montant ni prix catalogue → « non tracé » (compté, 0 €) ;
 *  - offerts (promo, cadeau admin, staff, crédit Premium, PawPoints) = 0 €,
 *    avec la valeur catalogue offerte à titre indicatif ;
 *  - aucune conversion de devise : les totaux principaux sont en EUR, les
 *    autres devises sont listées à part.
 */

const CHANNELS = ['apple', 'google_play', 'airwallex', 'paypal', 'promo', 'autre'];

// Commission du store, en fraction du brut. Apple 15 % = App Store Small
// Business Program ; Google Play 15 % = 1er million USD / abonnements.
// Carte / PayPal : 0 % ici (les frais bancaires ne sont pas une commission de
// store et ne sont pas connus par achat).
const DEFAULT_STORE_FEES = Object.freeze({
  apple: 0.15,
  google_play: 0.15,
  airwallex: 0,
  paypal: 0,
  promo: 0,
  autre: 0,
});

const MAIN_CURRENCY = 'EUR';

const round2 = (n) => Math.round((Number(n) || 0) * 100) / 100;

function channelOf(purchase) {
  const provider = String((purchase && purchase.paymentProvider) || '').trim().toLowerCase();
  const paymentId = String((purchase && purchase.paymentId) || '');
  // Abonnement payé avec le portefeuille HoPetSit : l'activation passe par le
  // chemin « webhook » qui étiquette `airwallex` par défaut, mais l'identifiant
  // commence par `wallet_`.
  if (/^wallet_/.test(paymentId)) return 'autre';
  // Même mécanique pour un abonnement offert au staff ou par l'admin.
  if (/^(staff_free_|gift_)/.test(paymentId)) return 'promo';
  if (['apple_iap', 'apple', 'app_store', 'appstore', 'storekit'].includes(provider)) return 'apple';
  if (['google_play', 'googleplay', 'google', 'play', 'play_billing', 'play_store'].includes(provider)) return 'google_play';
  if (['airwallex', 'stripe', 'card', 'carte'].includes(provider)) return 'airwallex';
  if (provider === 'paypal') return 'paypal';
  if (['promo', 'admin_gift', 'staff_free', 'premium_credit', 'pawpoints', 'trial', 'free', 'gift'].includes(provider)) return 'promo';
  return 'autre';
}

/** Plateforme d'origine quand elle est connue (sinon 'unknown'). */
function platformOf(purchase, channel) {
  const raw = String((purchase && purchase.platform) || '').trim().toLowerCase();
  if (['ios', 'android', 'web'].includes(raw)) return raw;
  if (channel === 'apple') return 'ios';
  if (channel === 'google_play') return 'android';
  return 'unknown';
}

const normPlan = (p) =>
  String(p || '').toLowerCase().replace('famille', 'family').replace(/^solo$/, 'monthly');

/** Produit « comptable » (plus fin que `product` de l'Activité boutique). */
function shopProductOf(purchase) {
  const product = String((purchase && purchase.product) || '');
  const plan = normPlan(purchase && purchase.tier);
  if (product === 'profile_boost') return 'pawboost';
  if (product === 'map_boost') return 'pawspot_boost';
  if (product === 'pawspot_sub') return 'pawspot';
  if (product === 'pawpremium') return 'pawpremium';
  if (product === 'premium') {
    if (/^premium_/.test(plan)) return 'pawpremium';
    if (/^pawspot_/.test(plan)) return 'pawspot';
    if (/^family/.test(plan)) return 'pawfamily';
    return 'pawfollow';
  }
  if (product === 'chat_addon') return 'chat_addon';
  if (product === 'kyc') return 'kyc';
  if (product === 'donation') return 'donation';
  return 'autre';
}

/**
 * Prix catalogue d'une ligne, ou null si inconnu.
 * @param {object} purchase  ligne aplatie (product, tier, days, currency)
 * @param {string} channel
 * @param {{pricing?: object, apple?: object}} catalog
 *        pricing = pricingService.getAll() ; apple = appleIapService.PRODUCT_MAP
 */
function catalogPrice(purchase, channel, catalog) {
  const cat = catalog || {};
  const shopProduct = shopProductOf(purchase);
  const tier = String((purchase && purchase.tier) || '').toLowerCase();
  const plan = normPlan(tier);
  const days = Number(purchase && purchase.days) || 0;
  const yearly = /yearly/.test(plan) || days >= 365;

  if (channel === 'apple' || channel === 'google_play') {
    const entries = Object.values(cat.apple || {});
    let hit = null;
    if (shopProduct === 'pawboost') {
      hit = entries.find((e) => e.kind === 'boost' && e.tier === tier);
    } else if (shopProduct === 'pawspot') {
      hit = entries.find((e) => e.kind === 'pawspot' && (Number(e.days) >= 365) === yearly);
    } else if (['pawfollow', 'pawfamily', 'pawpremium'].includes(shopProduct)) {
      hit = entries.find((e) => e.kind === 'subscription' && normPlan(e.plan) === plan);
    }
    const price = hit && Number(hit.price);
    return price > 0 ? { amount: price, currency: MAIN_CURRENCY } : null;
  }

  const pricing = cat.pricing || {};
  const currency = String((purchase && purchase.currency) || MAIN_CURRENCY).toUpperCase();
  const row = (category) => {
    const c = pricing[category] || {};
    return c[currency] || null;
  };
  let price = null;
  if (shopProduct === 'pawboost') price = (row('boost') || {})[tier];
  else if (shopProduct === 'pawspot_boost') price = (row('mapBoost') || {})[tier];
  else if (shopProduct === 'pawspot') price = (row('pawspot') || {})[yearly ? 'yearly' : 'monthly'];
  else if (['pawfollow', 'pawfamily', 'pawpremium'].includes(shopProduct)) price = (row('premium') || {})[plan];
  else if (shopProduct === 'chat_addon') price = (row('chat') || {}).monthly;
  price = Number(price);
  return price > 0 ? { amount: price, currency } : null;
}

/**
 * Enrichit UNE ligne : canal, produit, brut retenu, commission du store, net,
 * drapeaux « estimé » / « non tracé ».
 */
function enrichPurchase(purchase, { rates, catalog } = {}) {
  const fees = { ...DEFAULT_STORE_FEES, ...(rates || {}) };
  const channel = channelOf(purchase);
  const provider = String((purchase && purchase.paymentProvider) || '').toLowerCase();
  const recorded = Number(purchase && purchase.amount) || 0;
  const currency = String((purchase && purchase.currency) || MAIN_CURRENCY).toUpperCase();
  const realAmount =
    purchase && (purchase.amountReal === true || ['store', 'real', 'psp'].includes(String(purchase.amountSource || '')));
  const cat = catalogPrice(purchase, channel, catalog);

  let gross = 0;
  let grossCurrency = currency;
  let estimated = false;
  let untraced = false;
  let amountBasis = 'recorded'; // recorded | catalog | none | gift
  let giftedValue = 0;

  if (channel === 'promo') {
    amountBasis = 'gift';
    giftedValue = cat && cat.currency === MAIN_CURRENCY ? cat.amount : 0;
  } else if (recorded > 0) {
    gross = recorded;
    // Apple / Play : prix catalogue EUR, pas le prix payé dans le store.
    // `stripe` historique : plein tarif même quand une réduction s'appliquait.
    estimated = !realAmount && (channel === 'apple' || channel === 'google_play' || provider === 'stripe');
  } else if (cat) {
    gross = cat.amount;
    grossCurrency = cat.currency;
    estimated = true;
    amountBasis = 'catalog';
  } else {
    untraced = true;
    amountBasis = 'none';
  }

  // Achat Sandbox (review Apple, tests) ou remboursé : la ligne reste
  // visible dans l'activité mais ne compte dans AUCUN revenu.
  const excluded = !!(purchase && purchase.excludedFromRevenue === true);
  const refunded = !!(purchase && purchase.refundedAt);
  if (excluded || refunded) {
    gross = 0;
    estimated = false;
    untraced = false;
  }

  const feeRate = Number(fees[channel]) || 0;
  const storeFee = round2(gross * feeRate);
  return {
    ...purchase,
    channel,
    platform: platformOf(purchase, channel),
    shopProduct: shopProductOf(purchase),
    amountRecorded: recorded,
    amount: round2(gross),
    currency: grossCurrency,
    gross: round2(gross),
    storeFeeRate: feeRate,
    storeFee,
    net: round2(gross - storeFee),
    estimated,
    untraced,
    amountBasis,
    giftedValue: round2(giftedValue),
    excluded,
    refunded,
  };
}

function emptyBucket() {
  return {
    count: 0, // toutes lignes (payantes + offertes)
    paidCount: 0,
    giftedCount: 0,
    estimatedCount: 0,
    untracedCount: 0,
    excludedCount: 0, // Sandbox — hors revenus
    refundedCount: 0, // remboursés — hors revenus
    gross: 0, // EUR
    recordedGross: 0, // EUR — part réellement enregistrée sur l'achat
    estimatedGross: 0, // EUR — part des lignes « estimé »
    storeFee: 0, // EUR
    net: 0, // EUR
    giftedValue: 0, // EUR — valeur catalogue des offerts (indicatif)
    otherCurrencies: {}, // { USD: { count, gross, storeFee, net } }
  };
}

function addToBucket(bucket, line) {
  bucket.count += 1;
  if (line.channel === 'promo') {
    bucket.giftedCount += 1;
    bucket.giftedValue = round2(bucket.giftedValue + (line.giftedValue || 0));
    return;
  }
  if (line.excluded || line.refunded) {
    if (line.refunded) bucket.refundedCount += 1;
    else bucket.excludedCount += 1;
    return;
  }
  bucket.paidCount += 1;
  if (line.untraced) bucket.untracedCount += 1;
  if (line.estimated) bucket.estimatedCount += 1;
  if (line.currency === MAIN_CURRENCY) {
    bucket.gross = round2(bucket.gross + line.gross);
    bucket.storeFee = round2(bucket.storeFee + line.storeFee);
    bucket.net = round2(bucket.net + line.net);
    if (line.estimated) bucket.estimatedGross = round2(bucket.estimatedGross + line.gross);
    if (line.amountBasis === 'recorded') bucket.recordedGross = round2(bucket.recordedGross + line.gross);
  } else {
    const o = bucket.otherCurrencies[line.currency] || { count: 0, gross: 0, storeFee: 0, net: 0 };
    o.count += 1;
    o.gross = round2(o.gross + line.gross);
    o.storeFee = round2(o.storeFee + line.storeFee);
    o.net = round2(o.net + line.net);
    bucket.otherCurrencies[line.currency] = o;
  }
}

/** Somme de plusieurs cases (ex. carte + PayPal pour la carte du tableau de bord). */
function mergeBuckets(buckets) {
  const out = emptyBucket();
  for (const b of buckets) {
    if (!b) continue;
    for (const k of ['count', 'paidCount', 'giftedCount', 'estimatedCount', 'untracedCount', 'excludedCount', 'refundedCount']) out[k] += b[k] || 0;
    for (const k of ['gross', 'recordedGross', 'estimatedGross', 'storeFee', 'net', 'giftedValue']) {
      out[k] = round2(out[k] + (b[k] || 0));
    }
    for (const [cur, o] of Object.entries(b.otherCurrencies || {})) {
      const t = out.otherCurrencies[cur] || { count: 0, gross: 0, storeFee: 0, net: 0 };
      t.count += o.count || 0;
      t.gross = round2(t.gross + (o.gross || 0));
      t.storeFee = round2(t.storeFee + (o.storeFee || 0));
      t.net = round2(t.net + (o.net || 0));
      out.otherCurrencies[cur] = t;
    }
  }
  return out;
}

function inRange(date, from, to) {
  if (!from && !to) return true;
  if (!date) return false;
  const d = new Date(date).getTime();
  if (Number.isNaN(d)) return false;
  if (from && d < new Date(from).getTime()) return false;
  if (to && d > new Date(to).getTime()) return false;
  return true;
}

/**
 * Agrège des lignes ENRICHIES sur une fenêtre [from, to] (bornes optionnelles).
 * Les canaux sont toujours tous présents (Google Play à 0 = « aucune vente »,
 * jamais un chiffre inventé).
 */
function aggregate(lines, { from = null, to = null } = {}) {
  const totals = emptyBucket();
  const byChannel = {};
  for (const c of CHANNELS) byChannel[c] = { ...emptyBucket(), byProduct: {} };
  const byProduct = {};
  const matrix = {};

  for (const line of lines || []) {
    if (!inRange(line.purchasedAt, from, to)) continue;
    addToBucket(totals, line);
    const ch = byChannel[line.channel] || (byChannel[line.channel] = { ...emptyBucket(), byProduct: {} });
    addToBucket(ch, line);
    const chProd = ch.byProduct[line.shopProduct] || (ch.byProduct[line.shopProduct] = emptyBucket());
    addToBucket(chProd, line);
    const prod = byProduct[line.shopProduct] || (byProduct[line.shopProduct] = emptyBucket());
    addToBucket(prod, line);
    const key = `${line.channel}|${line.shopProduct}`;
    const cell = matrix[key] || (matrix[key] = { channel: line.channel, product: line.shopProduct, ...emptyBucket() });
    addToBucket(cell, line);
  }

  return {
    from: from ? new Date(from).toISOString() : null,
    to: to ? new Date(to).toISOString() : null,
    currency: MAIN_CURRENCY,
    totals,
    byChannel,
    // Les 4 cartes du tableau de bord : App Store · Google Play ·
    // Carte/PayPal · Offerts (+ « autre » = portefeuille HoPetSit).
    groups: {
      app_store: mergeBuckets([byChannel.apple]),
      google_play: mergeBuckets([byChannel.google_play]),
      card: mergeBuckets([byChannel.airwallex, byChannel.paypal]),
      gifted: mergeBuckets([byChannel.promo]),
      other: mergeBuckets([byChannel.autre]),
    },
    byProduct,
    rows: Object.values(matrix).sort(
      (a, b) => CHANNELS.indexOf(a.channel) - CHANNELS.indexOf(b.channel) || a.product.localeCompare(b.product),
    ),
  };
}

/** Nettoie des taux venus de l'admin / de la query (fraction 0 → 0,5). */
function sanitizeRates(input) {
  const out = {};
  for (const key of ['apple', 'google_play']) {
    if (!input || input[key] == null || input[key] === '') continue;
    let v = Number(input[key]);
    if (!Number.isFinite(v)) continue;
    if (v > 1) v /= 100; // « 15 » saisi pour 15 %
    out[key] = Math.min(0.5, Math.max(0, Math.round(v * 10000) / 10000));
  }
  return out;
}

/**
 * Rapport complet : fenêtre demandée + périodes fixes du tableau de bord.
 * @param {Array} purchases lignes aplaties BRUTES (non enrichies)
 */
function buildReport(purchases, { from = null, to = null, rates, catalog, now = new Date() } = {}) {
  const fees = { ...DEFAULT_STORE_FEES, ...sanitizeRates(rates) };
  const lines = (purchases || []).map((p) => enrichPurchase(p, { rates: fees, catalog }));
  const n = new Date(now);
  const monthStart = new Date(n.getFullYear(), n.getMonth(), 1);
  const last30 = new Date(n.getTime() - 30 * 86400000);
  const last7 = new Date(n.getTime() - 7 * 86400000);
  return {
    rates: fees,
    channels: CHANNELS,
    lines,
    range: aggregate(lines, { from, to }),
    periods: {
      allTime: aggregate(lines),
      thisMonth: aggregate(lines, { from: monthStart }),
      last30d: aggregate(lines, { from: last30 }),
      last7d: aggregate(lines, { from: last7 }),
    },
  };
}

module.exports = {
  CHANNELS,
  DEFAULT_STORE_FEES,
  MAIN_CURRENCY,
  channelOf,
  platformOf,
  shopProductOf,
  catalogPrice,
  enrichPurchase,
  aggregate,
  sanitizeRates,
  buildReport,
};
