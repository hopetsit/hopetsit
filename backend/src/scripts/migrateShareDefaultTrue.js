/**
 * v555 — option C : partage de position en direct ALLUMÉ par défaut entre
 * amis. Bascule à true les drapeaux requesterSharesPosition /
 * addresseeSharesPosition encore à false (valeur par défaut de l'ancien
 * schéma — pas un choix des utilisateurs : l'interrupteur par ami n'a jamais
 * pu produire d'effet, cf. mapSocket v555).
 *
 *   node src/scripts/migrateShareDefaultTrue.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Friendship = require('../models/Friendship');

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const before = await Friendship.countDocuments({
    $or: [{ requesterSharesPosition: false }, { addresseeSharesPosition: false }],
  });
  const r1 = await Friendship.updateMany(
    { requesterSharesPosition: { $ne: true } },
    { $set: { requesterSharesPosition: true } },
  );
  const r2 = await Friendship.updateMany(
    { addresseeSharesPosition: { $ne: true } },
    { $set: { addresseeSharesPosition: true } },
  );
  const total = await Friendship.countDocuments({});
  console.log(JSON.stringify({
    friendships: total,
    hadAtLeastOneFalse: before,
    requesterFixed: r1.modifiedCount,
    addresseeFixed: r2.modifiedCount,
  }));
  await mongoose.disconnect();
})().catch((e) => { console.error(e); process.exit(1); });
