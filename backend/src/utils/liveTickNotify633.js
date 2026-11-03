// 633 (03/11/2026) — Daniel : « vérifie que la notification "je suis en
// direct" apparaisse bien uniquement quand t'es vraiment en direct ».
//
// Le tick du direct (sockets/mapSocket.js, toutes les 60 s) envoyait au
// diffuseur « Partage en direct toujours actif 📍 depuis N h » toutes les 4 h
// tant que sa session restait en mémoire — et une session y reste 24 h après
// le DERNIER signal. Une balade dont l'arrêt s'est perdu (réseau faible, app
// tuée) faisait donc recevoir « toujours actif » à quelqu'un qui n'était plus
// en direct depuis des heures. Même chose pour « Partage en direct terminé »
// à l'échéance d'une durée choisie, alors que le téléphone s'était tu depuis
// longtemps.
//
// Règle unique, la même que « En direct · autre téléphone » (liveDevices589) :
// une personne est VRAIMENT en direct si son téléphone a donné signe de vie
// depuis moins de LIVE_ELSEWHERE_MAX_SILENCE_MS (10 min). Sinon, aucune
// notification au diffuseur ; la session, elle, suit son cours (fin à
// l'échéance, oubli après 24 h). Le rappel « toujours actif » qui était dû
// pendant un silence partira dès que le signal revient (il n'est pas
// consommé), et dira alors vrai.
'use strict';

const { LIVE_ELSEWHERE_MAX_SILENCE_MS } = require('./liveDevices589');

/** Vrai si le diffuseur a donné signe de vie depuis moins de 10 min. */
function isReallyLive633(lastSeenAt, now = Date.now()) {
  const seen = Number(lastSeenAt || 0);
  if (!seen) return false;
  return now - seen <= LIVE_ELSEWHERE_MAX_SILENCE_MS;
}

/**
 * Faut-il envoyer « toujours actif » maintenant ?
 * [dueMs] = intervalle du rappel (4 h). Pure.
 */
function shouldNotifyStillActive633({ now, lastSeenAt, lastStillActiveNoticeAt, dueMs }) {
  if (now - Number(lastStillActiveNoticeAt || 0) < dueMs) return false;
  return isReallyLive633(lastSeenAt, now);
}

/** Faut-il prévenir le diffuseur que sa durée choisie est écoulée ? Pure. */
function shouldNotifySessionEnded633({ now, lastSeenAt }) {
  return isReallyLive633(lastSeenAt, now);
}

module.exports = {
  isReallyLive633,
  shouldNotifyStillActive633,
  shouldNotifySessionEnded633,
};
