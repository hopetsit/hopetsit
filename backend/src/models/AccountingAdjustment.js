const mongoose = require('mongoose');

// v522 — Ajustements comptables du solde retirable HoPetSit.
// PROBLÈME résolu (Daniel : « mes 7 € de commission n'apparaissent pas dans
// le retirable ») : la formule retirable = revenus − retraits casse quand on
// SUPPRIME des paiements de test APRÈS avoir retiré l'argent — les retraits
// restent comptés mais les revenus qui les justifiaient disparaissent → le
// solde écrase injustement les nouveaux revenus.
// Deux sources d'ajustement :
//   - 'cleanup' : créé AUTOMATIQUEMENT par /admin/cleanup-test-data quand des
//     réservations payées sont supprimées (re-crédite leur commission).
//   - 'manual'  : saisi par l'admin (reconstitution d'historique, correction).
//   - 'orphan_payment' : créé AUTOMATIQUEMENT par le webhook Airwallex quand
//     un paiement KYC aboutit alors que le compte n'existe plus (supprimé/
//     recréé) ou est déjà vérifié : l'argent est encaissé sur Airwallex mais
//     aucun doc user ne peut le porter → on le comptabilise ici (12/07/2026,
//     cas réel : Daniel a payé 3 EUR depuis une session sitter supprimée).
const accountingAdjustmentSchema = new mongoose.Schema(
  {
    amount: { type: Number, required: true }, // EUR — peut être négatif
    note: { type: String, default: '', trim: true },
    source: { type: String, enum: ['manual', 'cleanup', 'orphan_payment'], default: 'manual' },
    createdBy: { type: String, default: '' },
    // v525 — idempotence des ajustements automatiques : id du PaymentIntent
    // Airwallex à l'origine (les webhooks peuvent être rejoués).
    ref: { type: String, default: null },
  },
  { timestamps: true },
);

module.exports = mongoose.model('AccountingAdjustment', accountingAdjustmentSchema);
