// 633 (03/11/2026) — Daniel : la notification « je suis en direct » ne doit
// apparaître que quand on est VRAIMENT en direct. Avant : « Partage en direct
// toujours actif depuis N h » toutes les 4 h tant que la session restait en
// mémoire (24 h après le dernier signal), et « Partage en direct terminé » à
// l'échéance même pour un téléphone muet depuis des heures.
process.env.NODE_ENV = 'test';

const {
  isReallyLive633,
  shouldNotifyStillActive633,
  shouldNotifySessionEnded633,
} = require('../src/utils/liveTickNotify633');

const MIN = 60 * 1000;
const H = 60 * MIN;
const now = Date.UTC(2026, 10, 3, 12, 0, 0);

describe('633 — vraiment en direct = signal depuis moins de 10 min', () => {
  test('signal il y a 30 s → en direct ; 9 min → en direct ; 11 min → non', () => {
    expect(isReallyLive633(now - 30 * 1000, now)).toBe(true);
    expect(isReallyLive633(now - 9 * MIN, now)).toBe(true);
    expect(isReallyLive633(now - 11 * MIN, now)).toBe(false);
  });
  test('sans aucun signal connu → non', () => {
    expect(isReallyLive633(0, now)).toBe(false);
    expect(isReallyLive633(undefined, now)).toBe(false);
  });
});

describe('633 — rappel « toujours actif » (toutes les 4 h)', () => {
  test('dû ET en direct → envoyé', () => {
    expect(shouldNotifyStillActive633({
      now, lastSeenAt: now - 20 * 1000, lastStillActiveNoticeAt: now - 4 * H, dueMs: 4 * H,
    })).toBe(true);
  });
  test('pas encore dû (3 h 59) → rien, même en direct', () => {
    expect(shouldNotifyStillActive633({
      now, lastSeenAt: now - 20 * 1000, lastStillActiveNoticeAt: now - 4 * H + MIN, dueMs: 4 * H,
    })).toBe(false);
  });
  test('BUG CORRIGÉ : dû mais téléphone muet depuis 3 h (arrêt perdu) → RIEN', () => {
    expect(shouldNotifyStillActive633({
      now, lastSeenAt: now - 3 * H, lastStillActiveNoticeAt: now - 4 * H, dueMs: 4 * H,
    })).toBe(false);
  });
  test('dû pendant un silence, le signal revient → envoyé au tick suivant (rien de perdu)', () => {
    const args = { lastStillActiveNoticeAt: now - 5 * H, dueMs: 4 * H };
    expect(shouldNotifyStillActive633({ ...args, now, lastSeenAt: now - 40 * MIN })).toBe(false);
    expect(shouldNotifyStillActive633({ ...args, now: now + MIN, lastSeenAt: now + MIN - 5 * 1000 })).toBe(true);
  });
});

describe('633 — « Partage en direct terminé » à l\'échéance', () => {
  test('encore en direct à l\'échéance → prévenu', () => {
    expect(shouldNotifySessionEnded633({ now, lastSeenAt: now - 2 * MIN })).toBe(true);
  });
  test('BUG CORRIGÉ : muet depuis 50 min à l\'échéance → pas prévenu', () => {
    expect(shouldNotifySessionEnded633({ now, lastSeenAt: now - 50 * MIN })).toBe(false);
  });
});
