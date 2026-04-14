require('dotenv').config();
const mongoose = require('mongoose');
const Admin = require('../models/Admin');

(async () => {
  const email = process.env.ADMIN_SEED_EMAIL;
  const password = process.env.ADMIN_SEED_PASSWORD;
  if (!email || !password) {
    console.error('Missing ADMIN_SEED_EMAIL or ADMIN_SEED_PASSWORD in .env');
    process.exit(1);
  }
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    const existing = await Admin.findOne({ email: email.toLowerCase() });
    if (existing) {
      console.log(`Admin already exists: ${existing.email}`);
      process.exit(0);
    }
    const passwordHash = await Admin.hashPassword(password);
    const admin = await Admin.create({
      email: email.toLowerCase(),
      passwordHash,
      name: 'Root Admin',
    });
    console.log(`Admin created: ${admin.email}`);
  } catch (err) {
    console.error('seedAdmin failed:', err);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
})();
