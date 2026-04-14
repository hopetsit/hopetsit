/**
 * Idempotent migration: encrypt existing cleartext values for
 * Sitter.paypalEmail, Sitter.ibanNumber, Owner.card.number, Owner.card.cvc.
 * Safe to re-run. Already-encrypted values (prefix "gcm:") are skipped.
 *
 * Usage: node src/scripts/encryptSensitiveFields.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Sitter = require('../models/Sitter');
const Owner = require('../models/Owner');
const { encrypt, isEncrypted } = require('../utils/encryption');

const migrateSitters = async () => {
  const cursor = Sitter.find({
    $or: [
      { paypalEmail: { $exists: true, $ne: '' } },
      { ibanNumber: { $exists: true, $ne: '' } },
    ],
  }).cursor();

  let count = 0;
  for (let doc = await cursor.next(); doc != null; doc = await cursor.next()) {
    const update = {};
    if (doc.paypalEmail && !isEncrypted(doc.paypalEmail)) {
      update.paypalEmail = encrypt(doc.paypalEmail);
    }
    if (doc.ibanNumber && !isEncrypted(doc.ibanNumber)) {
      update.ibanNumber = encrypt(doc.ibanNumber);
    }
    if (Object.keys(update).length) {
      await Sitter.updateOne({ _id: doc._id }, { $set: update });
      count++;
    }
  }
  console.log(`Sitters updated: ${count}`);
};

const migrateOwners = async () => {
  const cursor = Owner.find({
    $or: [{ 'card.number': { $exists: true, $ne: '' } }, { 'card.cvc': { $exists: true, $ne: '' } }],
  }).cursor();

  let count = 0;
  for (let doc = await cursor.next(); doc != null; doc = await cursor.next()) {
    if (!doc.card) continue;
    const update = {};
    if (doc.card.number && !isEncrypted(doc.card.number)) {
      // Backfill last4 before encrypting, so sanitizeCard keeps working.
      if (!doc.card.last4) update['card.last4'] = String(doc.card.number).slice(-4);
      update['card.number'] = encrypt(doc.card.number);
    }
    if (doc.card.cvc && !isEncrypted(doc.card.cvc)) {
      update['card.cvc'] = encrypt(doc.card.cvc);
    }
    if (Object.keys(update).length) {
      await Owner.updateOne({ _id: doc._id }, { $set: update });
      count++;
    }
  }
  console.log(`Owners updated: ${count}`);
};

// Sprint 6.5 step 5 — expose function for runAllMigrations.
const encryptSensitiveFields = async () => {
  await migrateSitters();
  await migrateOwners();
  console.log('[encryptSensitiveFields] done.');
};

module.exports = { encryptSensitiveFields };

if (require.main === module) {
  (async () => {
    try {
      await mongoose.connect(process.env.MONGODB_URI);
      await encryptSensitiveFields();
    } catch (e) {
      console.error('migration failed:', e);
      process.exitCode = 1;
    } finally {
      await mongoose.disconnect();
    }
  })();
}
