/**
 * 11/11/2026 (BOB, ordre de Daniel : « les annonces finies s'effacent sous 48 h, mais avec une liste
 * d'historique ») — copie réduite d'une demande, écrite juste AVANT son effacement automatique.
 * Lue seulement par l'admin (GET /admin/posts-history-1111/list). Jamais d'e-mail ni de téléphone :
 * prénom, ville, services, dates, nombre de candidatures, et si elle avait été réservée.
 */
const mongoose = require('mongoose');

const schema = new mongoose.Schema(
  {
    postId: { type: mongoose.Schema.Types.ObjectId, required: true, unique: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, default: null, index: true },
    ownerFirstName: { type: String, default: '' },
    city: { type: String, default: '' },
    serviceTypes: { type: [String], default: [] },
    dateMode: { type: String, default: null },
    startDate: { type: Date, default: null },
    endDate: { type: Date, default: null },
    body: { type: String, default: '' }, // 120 premiers caractères seulement
    status: { type: String, default: '' },
    closedAt: { type: Date, default: null },
    bookingId: { type: mongoose.Schema.Types.ObjectId, default: null },
    applicationsCount: { type: Number, default: 0 },
    postCreatedAt: { type: Date, default: null },
    // 'service_termine' (réservation terminée) | 'date_passee' (période finie sans suite)
    reason: { type: String, default: 'date_passee' },
    isTest: { type: Boolean, default: false },
    archivedAt: { type: Date, default: Date.now, index: true },
  },
  { minimize: false },
);

module.exports = mongoose.models.PostArchive1111 || mongoose.model('PostArchive1111', schema);
