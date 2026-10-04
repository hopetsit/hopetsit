const mongoose = require('mongoose');

/**
 * 610 (ZOE, 04/10/2026) — registre des signalements de CONFORT créés.
 * Le quota « 1 par 7 jours, par personne » compte les signalements CRÉÉS,
 * pas ceux encore en ligne : supprimer son signalement (DELETE /map-reports/:id
 * efface le document) ne rend pas le droit d'en poster un autre dans la semaine.
 * Une ligne par création, jamais modifiée ; purgée après 30 jours.
 */
const comfortReportLogSchema = new mongoose.Schema({
  reporterId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  reportId: { type: mongoose.Schema.Types.ObjectId, required: true },
  type: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, expires: 30 * 24 * 3600 },
});
comfortReportLogSchema.index({ reporterId: 1, createdAt: -1 });

module.exports = mongoose.model('ComfortReportLog', comfortReportLogSchema);
