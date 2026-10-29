// 628 (PAM, 29/10/2026) — `isBoosted` sur chaque candidature (sitter / walker peuplé) :
// même calcul que sitterController (boostExpiry > maintenant). L'app met les boostés en tête.
const { sanitizeApplication } = require('../src/utils/sanitize');
const { Types } = require('mongoose');

const doc = (provider, key) => ({
  toObject() { return this; },
  _id: new Types.ObjectId(),
  postId: new Types.ObjectId(),
  status: 'pending',
  [key]: { _id: new Types.ObjectId(), name: 'Test', email: 'x@y.z', ...provider },
  pricing: { totalPrice: 72, appliedRate: 20 },
});

describe('628 — isBoosted sur la candidature', () => {
  test('gardien boosté (boostExpiry futur) → true ; expiré → false ; absent → false', () => {
    const future = new Date(Date.now() + 86400000);
    const past = new Date(Date.now() - 86400000);
    expect(sanitizeApplication(doc({ boostExpiry: future }, 'sitterId')).sitter.isBoosted).toBe(true);
    expect(sanitizeApplication(doc({ boostExpiry: past }, 'sitterId')).sitter.isBoosted).toBe(false);
    expect(sanitizeApplication(doc({}, 'sitterId')).sitter.isBoosted).toBe(false);
  });
  test('promeneur boosté → walker.isBoosted true', () => {
    const a = sanitizeApplication(doc({ boostExpiry: new Date(Date.now() + 3600000) }, 'walkerId'));
    expect(a.walker.isBoosted).toBe(true);
    expect(a.sitter).toBeUndefined();
  });
});
