'use strict';

const mongoose = require('mongoose');

/**
 * v23.1.321 — Daniel (scale) : idempotence des webhooks. Airwallex/Persona
 * peuvent RE-livrer le même événement (retries réseau, timeouts). Sans garde,
 * un événement rejoué = double crédit / double notification / double activation.
 *
 * On enregistre l'eventId (unique). Le handler tente de l'insérer AVANT de
 * traiter ; si E11000 (déjà présent) → événement déjà traité → on skip.
 * TTL 30j pour auto-nettoyer (les retries Airwallex sont sur quelques heures).
 */
const processedWebhookSchema = new mongoose.Schema(
  {
    eventId:   { type: String, required: true, unique: true },
    source:    { type: String, default: 'airwallex', index: true },
    eventName: { type: String, default: '' },
    createdAt: { type: Date, default: Date.now, expires: '30d' },
  },
  { versionKey: false },
);

module.exports = mongoose.model('ProcessedWebhook', processedWebhookSchema);
