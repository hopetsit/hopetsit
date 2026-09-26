// v590 — tracé de la balade en mémoire vive (mapSocket.pushTrailPoint).
const { pushTrailPoint, trailOf, TRAIL_MAX } = require('../src/sockets/mapSocket');

describe('v590 — tracé de balade', () => {
  test('ignore les points à moins de 8 m, garde les autres', () => {
    const s = {};
    pushTrailPoint(s, -35, -30, 1);
    pushTrailPoint(s, -35.00001, -30, 2); // ~1 m
    pushTrailPoint(s, -35.0002, -30, 3); // ~22 m
    expect(trailOf(s)).toEqual([[-35, -30], [-35.0002, -30]]);
  });
  test(`plafonné à ${TRAIL_MAX} points (les plus anciens tombent)`, () => {
    const s = {};
    for (let i = 0; i < TRAIL_MAX + 20; i += 1) pushTrailPoint(s, -35 + i * 0.001, -30, i);
    const t = trailOf(s);
    expect(t.length).toBe(TRAIL_MAX);
    expect(t[0][0]).toBeCloseTo(-35 + 20 * 0.001, 6);
  });
  test('session absente → tracé vide', () => {
    expect(trailOf(null)).toEqual([]);
  });
});
