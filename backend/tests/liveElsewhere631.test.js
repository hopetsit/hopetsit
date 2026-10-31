// 631 (PAM, 31/10/2026) — « En direct · autre téléphone » seulement si l'autre
// appareil a donné signe de vie depuis moins de 10 min.
const { isSessionLiveElsewhere, LIVE_ELSEWHERE_MAX_SILENCE_MS } = require('../src/utils/liveDevices589');

describe('isSessionLiveElsewhere (631)', () => {
  const now = Date.UTC(2026, 9, 31, 12, 7);
  test('session fraîche, pas d\'arrêt → ailleurs', () => {
    expect(isSessionLiveElsewhere({ lastSeenAt: now - 30 * 1000 }, null, now)).toBe(true);
  });
  test('session muette depuis > 10 min (téléphone resté à la maison hier) → plus « ailleurs »', () => {
    expect(isSessionLiveElsewhere({ lastSeenAt: now - LIVE_ELSEWHERE_MAX_SILENCE_MS - 1 }, null, now)).toBe(false);
    expect(isSessionLiveElsewhere({ lastSeenAt: now - 20 * 60 * 60 * 1000 }, null, now)).toBe(false);
  });
  test('arrêt voulu noté → jamais « ailleurs », même session fraîche', () => {
    expect(isSessionLiveElsewhere({ lastSeenAt: now }, new Date(now - 1000), now)).toBe(false);
  });
  test('aucune session → faux', () => {
    expect(isSessionLiveElsewhere(null, null, now)).toBe(false);
  });
});
