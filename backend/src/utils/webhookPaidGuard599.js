'use strict';
// v599 — FLO (29/09/2026). Webhook Airwallex : un événement
// `payment_intent.failed` / `payment_intent.cancelled` qui arrive EN RETARD
// (retry réseau, relivraison) ne doit jamais écraser une réservation déjà
// payée. Retourne le nouveau paymentStatus à écrire, ou null s'il ne faut
// rien toucher.
const failedEventStatus = (booking, eventName) => {
  if (!booking) return null;
  if (booking.paymentStatus === 'paid' || booking.status === 'paid') return null;
  const name = String(eventName || '');
  if (name.endsWith('.failed')) return 'failed';
  if (name.endsWith('.cancelled')) return 'cancelled';
  return null;
};
module.exports = { failedEventStatus };
