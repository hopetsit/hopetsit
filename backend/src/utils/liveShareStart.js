/**
 * v587 — HEURE DE DÉPART DU DIRECT (`location.liveShareStartedAt`).
 *
 * Le site affiche « En direct · X min » : il lui faut l'heure où le partage a
 * commencé, pas celle de la dernière position (`location.updatedAt`, réécrite
 * toutes les ~10 s). Règle :
 *   · posée UNE fois quand un partage démarre — le direct était éteint, ou
 *     l'heure est absente, ou la dernière position date de plus de 10 min
 *     (session précédente jamais arrêtée proprement : on repart de zéro) ;
 *   · effacée (null) à chaque arrêt, en même temps que `liveShareActive`.
 * Renvoyée telle quelle dans /users/me/profile (`profile.location`).
 */
const FIELD = 'location.liveShareStartedAt';
const STALE_MS = 10 * 60 * 1000; // même fenêtre que liveState / personMapPosition

/** Filtre : « ce document ne porte pas de direct en cours ». */
function startFilter(id, now = new Date()) {
  return {
    _id: id,
    $or: [
      { 'location.liveShareActive': { $ne: true } },
      { [FIELD]: null },
      { 'location.updatedAt': { $lt: new Date(now.getTime() - STALE_MS) } },
    ],
  };
}

/**
 * À appeler AVANT l'écriture `liveShareActive: true`. Ne touche à rien si un
 * direct est déjà en cours (l'heure de départ est conservée).
 */
async function markLiveShareStarted(Model, id, now = new Date()) {
  if (!Model || !id) return null;
  return Model.updateOne(startFilter(id, now), { $set: { [FIELD]: now } });
}

/** Champs à poser à l'arrêt du direct. */
const LIVE_STOP_SET = Object.freeze({
  'location.liveShareActive': false,
  [FIELD]: null,
});

module.exports = { LIVE_STARTED_FIELD: FIELD, STALE_MS, startFilter, markLiveShareStarted, LIVE_STOP_SET };
