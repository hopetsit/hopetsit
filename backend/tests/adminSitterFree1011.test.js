/**
 * 10/11 (BOB) — admin « un gardien est libre » : le motif d'un envoi non parti est lisible,
 * sans jamais laisser passer un texte libre (un message d'erreur peut citer une adresse).
 */
jest.mock('../src/middleware/auth', () => ({ requireAuth: (q, s, n) => n(), requireRole: () => (q, s, n) => n() }));
jest.mock('../src/middleware/auditAdmin', () => ({ auditAdmin: (q, s, n) => n() }));
jest.mock('../src/utils/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() }));

const { failureCode, foldFailures } = require('../src/routes/adminSitterFree1011');

describe('adminSitterFree1011 — motifs d\'échec', () => {
  test('un code du serveur est gardé tel quel', () => {
    expect(failureCode('email_blocked:unverified')).toBe('email_blocked:unverified');
    expect(failureCode('prefs_category_off:bookings')).toBe('prefs_category_off:bookings');
    expect(failureCode('no_email')).toBe('no_email');
  });
  test('un texte libre ne sort jamais (adresse, phrase)', () => {
    expect(failureCode('Mailbox test.fictif@exemple.test rejected')).toBe('error');
    expect(failureCode('connect ETIMEDOUT 10.0.0.1:587')).toBe('error');
    expect(failureCode('')).toBe('unknown');
    expect(failureCode(undefined)).toBe('unknown');
  });
  test('les lignes sont regroupées par motif, la plus fréquente en premier', () => {
    const out = foldFailures([
      { _id: { kind: 'question', error: 'no_email' }, n: 1 },
      { _id: { kind: 'question', error: 'email_blocked:unverified' }, n: 5 },
      { _id: { kind: 'question', error: 'Erreur A x@y.test' }, n: 2 },
      { _id: { kind: 'question', error: 'Erreur B z@y.test' }, n: 1 },
    ]);
    expect(out).toEqual([
      { kind: 'question', reason: 'email_blocked:unverified', n: 5 },
      { kind: 'question', reason: 'error', n: 3 },
      { kind: 'question', reason: 'no_email', n: 1 },
    ]);
    expect(JSON.stringify(out)).not.toMatch(/@/);
  });
  test('liste vide ou absente', () => {
    expect(foldFailures([])).toEqual([]);
    expect(foldFailures(null)).toEqual([]);
  });
});
