require('dotenv').config();
const mongoose = require('mongoose');

const COLLECTIONS = ['owners', 'sitters'];
const INDEX_CANDIDATES = ['mobile_1', 'phone_1', 'countryCode_1_mobile_1'];

(async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;
    for (const coll of COLLECTIONS) {
      const indexes = await db.collection(coll).indexes().catch(() => []);
      for (const idx of indexes) {
        if (INDEX_CANDIDATES.includes(idx.name) && idx.unique) {
          await db.collection(coll).dropIndex(idx.name);
          console.log(`[${coll}] dropped unique index: ${idx.name}`);
        }
      }
    }
    console.log('done');
  } catch (e) {
    console.error('migration failed:', e);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
})();
