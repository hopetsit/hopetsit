// 17/10/2026 (SAM, ordre de Daniel : « il faut respecter la devise du pays »)
// Correction UNE FOIS au démarrage (marqueur `migrations`, non bloquante) :
//   1. comptes réels SANS pays → pays déduit (indicatif téléphonique, sinon ville
//      géocodée), table data/v618_country_fix.json (79 comptes, 20 new-yorkais) ;
//   2. tout compte dont la devise ne suit pas son pays → devise du pays
//      (ex. gardien de New York en EUR → USD ; le montant du tarif ne change pas).
// Pourquoi : depuis le 16/10 une candidature est refusée si la devise du
// prestataire ≠ celle du propriétaire → 9 gardiens new-yorkais sur 11 étaient
// injoignables pour un propriétaire new-yorkais en USD.
const path = require('path');
const { COUNTRY_CURRENCY } = require('../utils/countryCurrency');

async function runFixCountryCurrency618(db, logger = console) {
  const KEY = 'v618_country_currency';
  try {
    const mig = db.collection('migrations');
    if (await mig.findOne({ _id: KEY })) return;
    const table = require(path.join(__dirname, '..', 'data', 'v618_country_fix.json'));
    const models = { owner: require('../models/Owner'), sitter: require('../models/Sitter'), walker: require('../models/Walker') };
    const stats = {};
    for (const [role, Model] of Object.entries(models)) {
      let paysPoses = 0;
      for (const [id, info] of Object.entries(table[role] || {})) {
        const cc = String(info.country || '').toUpperCase();
        if (!/^[A-Z]{2}$/.test(cc)) continue;
        const r = await Model.updateOne({ _id: id, $or: [{ country: '' }, { country: null }, { country: { $exists: false } }] }, { $set: { country: cc } });
        paysPoses += r.modifiedCount || 0;
      }
      let devisesCorrigees = 0;
      for (const [cc, cur] of Object.entries(COUNTRY_CURRENCY)) {
        const r = await Model.updateMany({ country: cc, currency: { $ne: cur } }, { $set: { currency: cur } });
        devisesCorrigees += r.modifiedCount || 0;
      }
      stats[role] = { paysPoses, devisesCorrigees };
    }
    await mig.insertOne({ _id: KEY, at: new Date(), stats });
    logger.info(`[boot] migration ${KEY}: ${JSON.stringify(stats)}`);
  } catch (e) {
    logger.error(`[boot] migration ${KEY} failed (non-fatal)`, e);
  }
}

module.exports = { runFixCountryCurrency618 };
