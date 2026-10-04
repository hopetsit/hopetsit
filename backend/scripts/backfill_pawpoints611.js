/**
 * 611 (PAM, 04/10/2026) — RANGS : contrôle (et réparation optionnelle) du
 * total GAGNÉ `pawPoints` sur lequel se calcule le rang.
 *
 * Mesuré le 04/10 : le total « gagné depuis toujours » EXISTE déjà
 * (`pawPoints`, distinct du solde `pawPointsSpendable`, v416), dépenser ne le
 * baisse pas. Aucun rétro-calcul n'est nécessaire. Seul défaut relevé : des
 * profils anciens n'ont PAS le champ (26 profils réels vus par l'admin) ; le
 * serveur les traite comme 0 (Chiot) partout, mais une fiche publique sans
 * le champ n'affiche aucune pastille.
 *
 * Ce script, IDEMPOTENT :
 *   · par défaut (lecture seule) : compte les profils sans `pawPoints`, ceux
 *     dont le solde dépasse le total (incohérence), la répartition par rang ;
 *   · avec --apply : pose `pawPoints: 0` (et `pawPointsSpendable: 0`) là où
 *     le champ MANQUE, et rien d'autre. Relancer ne change plus rien.
 *
 *   MONGO_URI=… node scripts/backfill_pawpoints611.js          # lecture
 *   MONGO_URI=… node scripts/backfill_pawpoints611.js --apply  # écriture (feu vert BOB)
 */
const mongoose = require('mongoose');
const ranks = require('../src/services/ranks611');

const MONGO = process.env.MONGO_URI || process.env.MONGODB_URI || '';
const APPLY = process.argv.includes('--apply');

async function main() {
  if (!MONGO) {
    console.error('MONGO_URI (ou MONGODB_URI) manquant.');
    process.exit(1);
  }
  await mongoose.connect(MONGO);
  const out = { apply: APPLY, missing: {}, incoherent: 0, byRank: {}, written: 0 };
  for (const name of ['Owner', 'Sitter', 'Walker']) {
    const M = require(`../src/models/${name}`);
    out.missing[name] = await M.countDocuments({ pawPoints: { $exists: false } });
    out.incoherent += await M.countDocuments({ $expr: { $gt: ['$pawPointsSpendable', '$pawPoints'] } });
    const docs = await M.find({}).select('pawPoints').lean();
    for (const d of docs) {
      const k = ranks.rankFor(d.pawPoints).key;
      out.byRank[k] = (out.byRank[k] || 0) + 1;
    }
    if (APPLY && out.missing[name]) {
      const r = await M.updateMany(
        { pawPoints: { $exists: false } },
        [{ $set: { pawPoints: 0, pawPointsSpendable: { $ifNull: ['$pawPointsSpendable', 0] } } }],
      );
      out.written += r.modifiedCount || 0;
    }
  }
  console.log(JSON.stringify(out, null, 2));
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
