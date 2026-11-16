// 17/11/2026 (BOB) — vérification d'identité offerte aux gardiens et promeneurs.
const kycFree = require('../src/utils/kycFree1711');

const ON = {};
const OFF = { KYC_FREE_1711: 'off' };

describe('kycFree1711 — interrupteur', () => {
  test('allumé par défaut, éteint seulement par KYC_FREE_1711=off', () => {
    expect(kycFree.isFreeEnabled(ON)).toBe(true);
    expect(kycFree.isFreeEnabled({ KYC_FREE_1711: 'on' })).toBe(true);
    expect(kycFree.isFreeEnabled(OFF)).toBe(false);
    expect(kycFree.isFreeEnabled({ KYC_FREE_1711: ' OFF ' })).toBe(false);
  });
  test('prix affiché par l\'app : 0 si offert, 3 sinon', () => {
    expect(kycFree.displayedPrice(3, ON)).toBe(0);
    expect(kycFree.displayedPrice(3, OFF)).toBe(3);
  });
});

describe('kycFree1711 — qui passe en offert', () => {
  test('compte neuf ou arrêté au paiement → offert', () => {
    expect(kycFree.shouldGrantFree({ kycStatus: 'none' }, ON)).toBe(true);
    expect(kycFree.shouldGrantFree({}, ON)).toBe(true);
    expect(kycFree.shouldGrantFree({ kycStatus: 'pending_payment', kycPaymentIntentId: 'int_abc' }, ON)).toBe(true);
  });
  test('jamais : déjà payé, déjà en cours, vérifié, refusé, ou interrupteur éteint', () => {
    expect(kycFree.shouldGrantFree({ kycStatus: 'pending_payment', kycPaidAt: new Date() }, ON)).toBe(false);
    expect(kycFree.shouldGrantFree({ kycStatus: 'pending_verification' }, ON)).toBe(false);
    expect(kycFree.shouldGrantFree({ kycStatus: 'verified' }, ON)).toBe(false);
    expect(kycFree.shouldGrantFree({ kycStatus: 'rejected' }, ON)).toBe(false);
    expect(kycFree.shouldGrantFree({ kycStatus: 'none' }, OFF)).toBe(false);
    expect(kycFree.shouldGrantFree(null, ON)).toBe(false);
  });
});

describe('kycFree1711 — droit de lancer la vérification', () => {
  const ref = kycFree.newFreeRef(1794870000000);
  test('la référence offerte est reconnaissable et ne ressemble ni à un paiement carte ni au portefeuille', () => {
    expect(ref).toBe('free_1711_1794870000000');
    expect(kycFree.isFreeRef({ kycPaymentIntentId: ref })).toBe(true);
    expect(kycFree.isFreeRef({ kycPaymentIntentId: 'wallet_1794870000000' })).toBe(false);
    expect(kycFree.isFreeRef({ kycPaymentIntentId: 'int_abc' })).toBe(false);
    expect(kycFree.isFreeRef({})).toBe(false);
  });
  test('payé OU offert peut lancer ; ni l\'un ni l\'autre ne peut pas', () => {
    expect(kycFree.canStartVerification({ kycStatus: 'pending_verification', kycPaidAt: new Date() })).toBe(true);
    expect(kycFree.canStartVerification({ kycStatus: 'pending_verification', kycPaymentIntentId: ref })).toBe(true);
    expect(kycFree.canStartVerification({ kycStatus: 'pending_verification' })).toBe(false);
    expect(kycFree.canStartVerification({ kycStatus: 'pending_payment', kycPaymentIntentId: ref })).toBe(false);
    expect(kycFree.canStartVerification({ kycStatus: 'none' })).toBe(false);
  });
  test('un compte offert garde son droit même si l\'interrupteur est ensuite éteint', () => {
    expect(kycFree.canStartVerification({ kycStatus: 'pending_verification', kycPaymentIntentId: ref })).toBe(true);
  });
  test('offert = jamais de date de paiement (les revenus de l\'admin filtrent sur kycPaidAt)', () => {
    const u = { kycStatus: 'pending_verification', kycPaymentIntentId: ref, kycPaidAt: null };
    expect(!!u.kycPaidAt).toBe(false);
    expect(kycFree.canStartVerification(u)).toBe(true);
  });
});
