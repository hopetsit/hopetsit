const {
  channelOf,
  shopProductOf,
  enrichPurchase,
  aggregate,
  sanitizeRates,
  buildReport,
  DEFAULT_STORE_FEES,
} = require('../src/services/shopRevenueService');

// Catalogue minimal, même forme que pricingService.getAll() et
// appleIapService.PRODUCT_MAP.
const catalog = {
  pricing: {
    boost: { EUR: { bronze: 3.99, silver: 7.99 }, USD: { bronze: 4.39 } },
    mapBoost: { EUR: { bronze: 1.99 } },
    premium: { EUR: { monthly: 6.99, yearly: 49.99, family: 9.99, premium_monthly: 7.99 } },
    pawspot: { EUR: { monthly: 4.99, yearly: 39.99 } },
    chat: { EUR: { monthly: 2.99 } },
  },
  apple: {
    hopetsit_pawfollow_monthly: { kind: 'subscription', plan: 'monthly', price: 4.99 },
    hopetsit_pawspot_monthly: { kind: 'pawspot', days: 30, price: 4.99 },
    hopetsit_pawboost_t1: { kind: 'boost', tier: 'bronze', price: 3.99 },
  },
};

const NOW = new Date('2026-09-18T12:00:00Z');
const day = (n) => new Date(NOW.getTime() - n * 86400000).toISOString();

describe('shopRevenueService — canal et produit', () => {
  test('prestataire → canal', () => {
    expect(channelOf({ paymentProvider: 'apple_iap' })).toBe('apple');
    expect(channelOf({ paymentProvider: 'apple' })).toBe('apple');
    expect(channelOf({ paymentProvider: 'google_play' })).toBe('google_play');
    expect(channelOf({ paymentProvider: 'airwallex' })).toBe('airwallex');
    // « stripe » historique = carte Airwallex.
    expect(channelOf({ paymentProvider: 'stripe' })).toBe('airwallex');
    expect(channelOf({ paymentProvider: 'paypal' })).toBe('paypal');
    for (const p of ['promo', 'admin_gift', 'staff_free', 'premium_credit', 'pawpoints']) {
      expect(channelOf({ paymentProvider: p })).toBe('promo');
    }
    expect(channelOf({ paymentProvider: 'wallet' })).toBe('autre');
    expect(channelOf({ paymentProvider: '' })).toBe('autre');
  });

  test("l'identifiant de paiement prime sur l'étiquette par défaut", () => {
    expect(channelOf({ paymentProvider: 'airwallex', paymentId: 'wallet_1758_monthly' })).toBe('autre');
    expect(channelOf({ paymentProvider: 'airwallex', paymentId: 'staff_free_1758_pawspot' })).toBe('promo');
    expect(channelOf({ paymentProvider: 'admin_gift', paymentId: 'gift_1758_Owner' })).toBe('promo');
  });

  test('produit comptable', () => {
    expect(shopProductOf({ product: 'profile_boost' })).toBe('pawboost');
    expect(shopProductOf({ product: 'premium', tier: 'monthly' })).toBe('pawfollow');
    expect(shopProductOf({ product: 'premium', tier: 'famille' })).toBe('pawfamily');
    expect(shopProductOf({ product: 'premium', tier: 'family_yearly' })).toBe('pawfamily');
    expect(shopProductOf({ product: 'pawpremium', tier: 'premium_yearly' })).toBe('pawpremium');
    expect(shopProductOf({ product: 'pawspot_sub', tier: 'pawspot_monthly' })).toBe('pawspot');
    expect(shopProductOf({ product: 'chat_addon' })).toBe('chat_addon');
  });
});

describe('shopRevenueService — une ligne', () => {
  test('Apple : montant catalogue enregistré → estimé, commission 15 %', () => {
    const l = enrichPurchase(
      { product: 'pawspot_sub', tier: 'pawspot_monthly', amount: 4.99, currency: 'EUR', paymentProvider: 'apple_iap' },
      { catalog },
    );
    expect(l.channel).toBe('apple');
    expect(l.platform).toBe('ios');
    expect(l.gross).toBe(4.99);
    expect(l.estimated).toBe(true);
    expect(l.storeFee).toBe(0.75);
    expect(l.net).toBe(4.24);
  });

  test('Apple avec montant réel du store → plus « estimé »', () => {
    const l = enrichPurchase(
      { product: 'premium', tier: 'monthly', amount: 5.49, currency: 'EUR', paymentProvider: 'apple_iap', amountSource: 'store' },
      { catalog },
    );
    expect(l.estimated).toBe(false);
    expect(l.gross).toBe(5.49);
  });

  test('carte Airwallex sans montant (webhook) → prix catalogue, estimé, 0 % de commission', () => {
    const l = enrichPurchase(
      { product: 'profile_boost', tier: 'silver', amount: 0, currency: 'EUR', paymentProvider: 'airwallex' },
      { catalog },
    );
    expect(l.gross).toBe(7.99);
    expect(l.estimated).toBe(true);
    expect(l.amountBasis).toBe('catalog');
    expect(l.storeFee).toBe(0);
    expect(l.net).toBe(7.99);
    expect(l.platform).toBe('unknown');
  });

  test('« stripe » historique : plein tarif enregistré → estimé', () => {
    const l = enrichPurchase(
      { product: 'premium', tier: 'monthly', amount: 6.99, currency: 'EUR', paymentProvider: 'stripe' },
      { catalog },
    );
    expect(l.channel).toBe('airwallex');
    expect(l.gross).toBe(6.99);
    expect(l.estimated).toBe(true);
  });

  test('carte avec vrai montant enregistré → ni estimé ni non tracé', () => {
    const l = enrichPurchase(
      { product: 'premium', tier: 'monthly', amount: 5.59, currency: 'EUR', paymentProvider: 'airwallex' },
      { catalog },
    );
    expect(l.estimated).toBe(false);
    expect(l.untraced).toBe(false);
    expect(l.gross).toBe(5.59);
  });

  test('ni montant ni prix catalogue → non tracé, 0 €, jamais inventé', () => {
    const l = enrichPurchase(
      { product: 'profile_boost', tier: 'inconnu', amount: 0, currency: 'EUR', paymentProvider: 'airwallex' },
      { catalog },
    );
    expect(l.untraced).toBe(true);
    expect(l.gross).toBe(0);
    expect(l.estimated).toBe(false);
  });

  test('offert : 0 € de brut, valeur catalogue indicative', () => {
    const l = enrichPurchase(
      { product: 'pawpremium', tier: 'premium_monthly', amount: 0, currency: 'EUR', paymentProvider: 'promo' },
      { catalog },
    );
    expect(l.channel).toBe('promo');
    expect(l.gross).toBe(0);
    expect(l.net).toBe(0);
    expect(l.giftedValue).toBe(7.99);
    expect(l.untraced).toBe(false);
  });

  test('taux modifiable', () => {
    const l = enrichPurchase(
      { product: 'profile_boost', tier: 'bronze', amount: 3.99, paymentProvider: 'apple_iap' },
      { catalog, rates: { apple: 0.3 } },
    );
    expect(l.storeFee).toBe(1.2);
    expect(l.net).toBe(2.79);
  });
});

describe('shopRevenueService — agrégation', () => {
  const purchases = [
    { product: 'pawspot_sub', tier: 'pawspot_monthly', amount: 4.99, currency: 'EUR', paymentProvider: 'apple_iap', purchasedAt: day(2) },
    { product: 'premium', tier: 'monthly', amount: 4.99, currency: 'EUR', paymentProvider: 'apple_iap', purchasedAt: day(40) },
    { product: 'premium', tier: 'monthly', amount: 6.99, currency: 'EUR', paymentProvider: 'stripe', purchasedAt: day(10) },
    { product: 'profile_boost', tier: 'silver', amount: 0, currency: 'EUR', paymentProvider: 'airwallex', purchasedAt: day(5) },
    { product: 'profile_boost', tier: 'bronze', amount: 4.39, currency: 'USD', paymentProvider: 'airwallex', purchasedAt: day(3) },
    { product: 'premium', tier: 'monthly', amount: 0, currency: 'EUR', paymentProvider: 'staff_free', purchasedAt: day(1) },
    { product: 'kyc', tier: null, amount: 3, currency: 'EUR', paymentProvider: 'airwallex', purchasedAt: day(6) },
  ];

  test('totaux par canal, Google Play présent à zéro', () => {
    const r = buildReport(purchases, { catalog, now: NOW });
    const all = r.periods.allTime;

    expect(all.byChannel.apple.paidCount).toBe(2);
    expect(all.byChannel.apple.gross).toBe(9.98);
    expect(all.byChannel.apple.storeFee).toBe(1.5);
    expect(all.byChannel.apple.net).toBe(8.48);
    expect(all.byChannel.apple.estimatedCount).toBe(2);

    // Aucun Google Play Billing : le canal existe, à 0 — jamais inventé.
    expect(all.byChannel.google_play.count).toBe(0);
    expect(all.byChannel.google_play.gross).toBe(0);

    // Carte : 6,99 (stripe) + 7,99 (catalogue) + 3 (KYC) en EUR ; l'USD à part.
    expect(all.byChannel.airwallex.gross).toBe(17.98);
    expect(all.byChannel.airwallex.storeFee).toBe(0);
    expect(all.byChannel.airwallex.recordedGross).toBe(9.99);
    expect(all.byChannel.airwallex.estimatedGross).toBe(14.98);
    expect(all.byChannel.airwallex.otherCurrencies.USD).toEqual({ count: 1, gross: 4.39, storeFee: 0, net: 4.39 });

    // Carte du tableau de bord « Carte / PayPal » = airwallex + paypal.
    expect(all.groups.card.gross).toBe(17.98);
    expect(all.groups.app_store.net).toBe(8.48);
    expect(all.groups.gifted.giftedCount).toBe(1);

    expect(all.byChannel.promo.giftedCount).toBe(1);
    expect(all.byChannel.promo.gross).toBe(0);
    expect(all.byChannel.promo.giftedValue).toBe(6.99);

    expect(all.totals.count).toBe(7);
    expect(all.totals.paidCount).toBe(6);
    expect(all.totals.gross).toBe(27.96);
    expect(all.totals.storeFee).toBe(1.5);
    expect(all.totals.net).toBe(26.46);
  });

  test('le total est la somme des canaux et des produits', () => {
    const all = buildReport(purchases, { catalog, now: NOW }).periods.allTime;
    const sum = (obj, k) => Math.round(Object.values(obj).reduce((s, b) => s + b[k], 0) * 100) / 100;
    expect(sum(all.byChannel, 'gross')).toBe(all.totals.gross);
    expect(sum(all.byProduct, 'gross')).toBe(all.totals.gross);
    expect(sum(all.byChannel, 'net')).toBe(all.totals.net);
    expect(Math.round(all.rows.reduce((s, r) => s + r.gross, 0) * 100) / 100).toBe(all.totals.gross);
  });

  test('périodes : 30 jours exclut la vente Apple de J-40', () => {
    const r = buildReport(purchases, { catalog, now: NOW });
    expect(r.periods.last30d.byChannel.apple.paidCount).toBe(1);
    expect(r.periods.last30d.byChannel.apple.gross).toBe(4.99);
    expect(r.periods.last7d.byChannel.airwallex.gross).toBe(10.99); // boost 7,99 + KYC 3
  });

  test('fenêtre from/to et lignes sans date', () => {
    const lines = buildReport([...purchases, { product: 'kyc', amount: 3, paymentProvider: 'airwallex' }], { catalog, now: NOW }).lines;
    const win = aggregate(lines, { from: day(7), to: day(4) });
    expect(win.totals.paidCount).toBe(2); // boost J-5 + KYC J-6
    // Sans fenêtre, la ligne non datée compte ; avec fenêtre, non.
    expect(aggregate(lines).totals.paidCount).toBe(7);
  });

  test('taux venus de l\'admin', () => {
    expect(sanitizeRates({ apple: 30, google_play: '0.12' })).toEqual({ apple: 0.3, google_play: 0.12 });
    expect(sanitizeRates({ apple: 'abc', google_play: -1 })).toEqual({ google_play: 0 });
    expect(sanitizeRates({ apple: 0.9 })).toEqual({ apple: 0.5 });
    expect(sanitizeRates({ airwallex: 0.2 })).toEqual({});
    expect(DEFAULT_STORE_FEES.apple).toBe(0.15);
    expect(DEFAULT_STORE_FEES.google_play).toBe(0.15);
    const r = buildReport(purchases, { catalog, now: NOW, rates: { apple: 30 } });
    expect(r.rates.apple).toBe(0.3);
    // Arrondi PAR LIGNE (2 × 1,50) : le total est toujours la somme des lignes du CSV.
    expect(r.periods.allTime.byChannel.apple.storeFee).toBe(3);
  });
});
