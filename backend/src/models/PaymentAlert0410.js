'use strict';

const mongoose = require('mongoose');

/**
 * 04/10/2026 (FLO, demande de Daniel) — registre des e-mails internes
 * « 💰 Paiement reçu » / « ↩️ Remboursement » envoyés à contact@hopetsit.com.
 *
 * Une ligne = un paiement (ou un remboursement). La clé est UNIQUE : un
 * webhook rejoué, le chemin /confirm qui arrive après le webhook ou un
 * deuxième save() de la même réservation tombent sur la même clé et
 * n'envoient JAMAIS un second e-mail.
 *
 * Clés : `booking-paid:<bookingId>`, `booking-refund:<bookingId>`,
 * `pi:<paymentIntentId>` (boutique carte/PayPal via Airwallex),
 * `wallet:<référence>` (boutique payée avec le portefeuille),
 * `apple:<transactionId>`, `apple-refund:<transactionId>`.
 */
const paymentAlertSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true },
    kind: { type: String, enum: ['payment', 'refund'], required: true },
    status: {
      type: String,
      enum: ['pending', 'sent', 'failed', 'skipped'],
      default: 'pending',
      index: true,
    },
    to: { type: String, default: '' },
    subject: { type: String, default: '' },
    reason: { type: String, default: '' },
    error: { type: String, default: '' },
    sentAt: { type: Date, default: null },
  },
  { timestamps: true, versionKey: false },
);

module.exports = mongoose.models.PaymentAlert0410
  || mongoose.model('PaymentAlert0410', paymentAlertSchema);
