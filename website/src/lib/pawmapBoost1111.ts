// 11/11/2026 (BOB, ordre de Daniel : « ceux qui ont PawBoost doivent être visibles, leur pastille, même en
// dézoomant » ; défaut relevé par ZOE) — un profil boosté ne rentre plus dans un groupe. Mais à petit zoom il
// tombait SUR le rond du groupe de sa ville (compteur caché, boostés empilés). Ici on calcule, en pixels
// écran, un petit décalage pour que chaque boosté se pose À CÔTÉ : autour du rond le plus proche, sur un
// cercle, sans toucher ni un groupe, ni une autre pastille, ni un autre boosté. Fonction pure, même zoom +
// mêmes données = mêmes places (ordre stable par identifiant). Aucun décalage quand la place est libre.

export type Px1111 = { x: number; y: number };

/** Distance minimale entre deux centres (pastille 32 px + lueur du boost). */
export const BOOST_GAP_1111 = 36;

/**
 * @param boosted   profils boostés (identifiant + position écran)
 * @param obstacles centres des groupes et des autres pastilles déjà posées (position écran)
 * @returns décalage en px par identifiant (absent = pas de décalage)
 */
export function boostOffsets1111(
  boosted: { id: string; px: Px1111 }[],
  obstacles: Px1111[],
  gap: number = BOOST_GAP_1111,
): Map<string, Px1111> {
  const out = new Map<string, Px1111>();
  const taken: Px1111[] = obstacles.slice();
  const free = (p: Px1111) => taken.every((t) => Math.hypot(t.x - p.x, t.y - p.y) >= gap);
  const sorted = boosted.slice().sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  for (const b of sorted) {
    if (free(b.px)) { taken.push(b.px); continue; }
    // le rond le plus proche : on tourne autour de lui, en partant de la direction du boosté
    let near = taken[0];
    let best = Infinity;
    for (const t of taken) { const d = Math.hypot(t.x - b.px.x, t.y - b.px.y); if (d < best) { best = d; near = t; } }
    const a0 = best > 0.5 ? Math.atan2(b.px.y - near.y, b.px.x - near.x) : -Math.PI / 2;
    let placed: Px1111 | null = null;
    for (let ring = 1; ring <= 4 && !placed; ring++) {
      const r = gap * ring + 2;
      const n = 8 * ring;
      for (let k = 0; k < n && !placed; k++) {
        // alterne à droite puis à gauche de la direction de départ
        const step = Math.ceil(k / 2) * (k % 2 === 1 ? 1 : -1);
        const a = a0 + (step * 2 * Math.PI) / n;
        const p = { x: near.x + r * Math.cos(a), y: near.y + r * Math.sin(a) };
        if (free(p)) placed = p;
      }
    }
    const at = placed ?? b.px; // aucune place libre à 4 cercles : on le laisse à sa vraie position
    taken.push(at);
    if (placed) out.set(b.id, { x: Math.round(at.x - b.px.x), y: Math.round(at.y - b.px.y) });
  }
  return out;
}
