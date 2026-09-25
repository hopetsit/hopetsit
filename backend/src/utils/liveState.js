/**
 * v584 (révision PawMap du 25/09) — ÉTAT VRAI du suivi en direct d'un ami.
 *
 * Daniel : « des positions d'amis vieilles d'une semaine affichées comme
 * “en direct” ». Avant, /friends/live-positions renvoyait la dernière
 * position connue (< 24 h) de chaque ami traçable, et l'app comme le site la
 * traitaient comme un direct dès qu'elle existait. Or `location.updatedAt`
 * bouge à chaque ouverture de l'app (rafraîchissement GPS du profil), pas
 * seulement pendant un partage.
 *
 * Règle unique, pure, partagée par la route et les tests :
 *   · `live`  : le PARTAGE est actif ET le dernier signe de vie date de
 *               moins de 2 min ;
 *   · `lost`  : partage actif mais entre 2 et 10 min sans signal
 *               (« signal perdu ») ;
 *   · `seen`  : tout le reste — pas de partage actif, ou plus de 10 min :
 *               on montre « vu il y a X », jamais « en direct », et aucun
 *               suivi n'est proposé.
 */
const LIVE_FRESH_MS = 2 * 60 * 1000;
const LIVE_LOST_MS = 10 * 60 * 1000;

/**
 * @param {object} o
 * @param {boolean} o.sharing      un partage est actif (session RAM ou drapeau `liveShareActive`)
 * @param {Date|number|string|null} o.lastSeenAt  dernier signe de vie
 * @param {number} [o.now]
 * @returns {'live'|'lost'|'seen'}
 */
function liveState({ sharing, lastSeenAt, now = Date.now() } = {}) {
  if (!sharing || !lastSeenAt) return 'seen';
  const t = new Date(lastSeenAt).getTime();
  if (!Number.isFinite(t)) return 'seen';
  const age = now - t;
  if (age < 0) return 'live';
  if (age <= LIVE_FRESH_MS) return 'live';
  if (age <= LIVE_LOST_MS) return 'lost';
  return 'seen';
}

module.exports = { liveState, LIVE_FRESH_MS, LIVE_LOST_MS };
