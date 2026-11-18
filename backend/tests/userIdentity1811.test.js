// 18/11/2026 (BOB, demande de Daniel) — tableau de bord : nombre d'identités vérifiées,
// dont offertes (gratuité du 17/11) et payées 3 €.
const { summarizeMembers, countUsers } = require('../src/utils/userCounts');

const now = new Date('2026-11-18T12:00:00Z');
const ago = (days) => new Date(now.getTime() - days * 86400000);

describe('summarizeMembers — identity', () => {
  const accounts = [
    { role: 'sitter', email: 'a@x.fr', kycStatus: 'verified', kycFree: true, kycVerifiedAt: ago(0.2) },
    { role: 'walker', email: 'b@x.fr', kycStatus: 'verified', kycPaid: true, kycVerifiedAt: ago(40) },
    { role: 'owner', email: 'c@x.fr', kycStatus: 'verified', kycVerifiedAt: ago(3) },
    { role: 'sitter', email: 'd@x.fr', kycStatus: 'verified', kycFree: true, kycPaid: true, kycVerifiedAt: ago(5) },
    { role: 'sitter', email: 'e@x.fr', kycStatus: 'pending_payment' },
    { role: 'walker', email: 'f@x.fr', kycStatus: 'pending_verification' },
    { role: 'owner', email: 'g@x.fr', kycStatus: 'none' },
    { role: 'owner', email: 'h@x.fr' },
    { role: 'sitter', email: 'dadaciao84+testsitter@gmail.com', kycStatus: 'verified', kycFree: true, kycVerifiedAt: ago(0.1) },
  ];
  const id = summarizeMembers({ accounts, now }).identity;

  test('vérifiées : comptes de test exclus', () => { expect(id.verified).toBe(4); });
  test('offertes, payées, validées à la main : chaque compte une seule fois', () => {
    expect(id.free).toBe(2); // « free_ » l'emporte même si une ancienne date de paiement existe
    expect(id.paid).toBe(1);
    expect(id.other).toBe(1);
    expect(id.free + id.paid + id.other).toBe(id.verified);
  });
  test('par rôle', () => { expect(id.byRole).toEqual({ owners: 1, sitters: 2, walkers: 1 }); });
  test('en cours et arrêtées au paiement', () => {
    expect(id.inProgress).toBe(1);
    expect(id.stoppedAtPayment).toBe(1);
  });
  test('depuis 24 h et 7 jours', () => { expect(id.d1).toBe(1); expect(id.d7).toBe(3); });
  test('sans aucun compte : zéros, pas d\'erreur', () => {
    expect(summarizeMembers({ now }).identity).toMatchObject({ verified: 0, free: 0, paid: 0, other: 0, d1: 0, d7: 0 });
  });
});

describe('countUsers — lit les champs KYC en base', () => {
  const model = (rows) => ({ find: () => ({ select: (f) => { model.fields = f; return { lean: async () => rows }; } }) });
  test('free_… = offerte, kycPaidAt = payée', async () => {
    const out = await countUsers({
      Owner: model([]),
      Sitter: model([{ email: 's@x.fr', kycStatus: 'verified', kycPaymentIntentId: 'free_1711_1', kycVerifiedAt: ago(1) }]),
      Walker: model([{ email: 'w@x.fr', kycStatus: 'verified', kycPaymentIntentId: 'int_abc', kycPaidAt: ago(30), kycVerifiedAt: ago(30) }]),
      decrypt: (v) => v, now,
    });
    expect(model.fields).toMatch(/kycStatus/);
    expect(out.members.identity).toMatchObject({ verified: 2, free: 1, paid: 1, other: 0, d7: 1 });
  });
});
