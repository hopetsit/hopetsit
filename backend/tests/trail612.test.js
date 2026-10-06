// 612 (PAM, 05/10/2026) — tracé de balade sans sauts GPS (capture 5 de Daniel :
// étoile autour du Mercadona, Alhama de Murcia).
const { pushTrailPoint, trailOf, cleanTrail612 } = require('../src/sockets/mapSocket');

// ~1 m en latitude = 1/111320 degré.
const M = 1 / 111320;
const BASE = [37.8500, -1.4250];
const at = (dn, de) => [BASE[0] + dn * M, BASE[1] + de * M / Math.cos(BASE[0] * Math.PI / 180)];

describe('612 — tracé de balade propre', () => {
  test('un saut de 120 m en 3 s est écarté, la marche réelle est gardée', () => {
    const s = {};
    let t = 0;
    for (let i = 0; i <= 5; i++) { const p = at(i * 12, 0); pushTrailPoint(s, p[0], p[1], t); t += 10000; }
    const jump = at(60, 120); pushTrailPoint(s, jump[0], jump[1], t - 7000);
    const next = at(72, 0); pushTrailPoint(s, next[0], next[1], t);
    expect(s.trail.length).toBe(7);
    expect(s.trail.some((p) => Math.abs(p[1] - jump[1]) < 1e-9)).toBe(false);
  });

  test('après 25 s sans point, un grand déplacement est accepté (jamais figé)', () => {
    const s = {};
    const a = at(0, 0); pushTrailPoint(s, a[0], a[1], 0);
    const b = at(150, 0); pushTrailPoint(s, b[0], b[1], 30000);
    expect(s.trail.length).toBe(2);
  });

  test('étoile (allers-retours de 40-80 m) → pics retirés par trailOf', () => {
    const s = { trail: [] };
    const pts = [at(0, 0), at(10, 0), at(60, 40), at(20, 0), at(-50, 30), at(30, 0), at(40, 0)];
    pts.forEach((p, i) => s.trail.push([p[0], p[1], i * 60000]));
    const out = trailOf(s);
    expect(out.length).toBe(5);
    // aucun point à plus de 15 m de la ligne réelle (est = 0)
    for (const p of out) {
      const east = (p[1] - BASE[1]) / (M / Math.cos(BASE[0] * Math.PI / 180));
      expect(Math.abs(east)).toBeLessThan(15);
    }
  });

  test('une marche régulière n\'est pas modifiée', () => {
    const pts = [];
    for (let i = 0; i < 20; i++) pts.push([...at(i * 10, (i % 2) * 3), i]);
    expect(cleanTrail612(pts).length).toBe(20);
  });
});
