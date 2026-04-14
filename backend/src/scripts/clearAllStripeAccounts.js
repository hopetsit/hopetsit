/**
 * Clear ALL Stripe Connect account IDs from sitters
 * Use this if Stripe Connect platform is not configured or you want to reset all accounts
 * 
 * Usage: node src/scripts/clearAllStripeAccounts.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Sitter = require('../models/Sitter');

async function clearAllStripeAccounts() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');

    // Find all sitters with Stripe Connect account IDs
    const sitters = await Sitter.find({
      stripeConnectAccountId: { $ne: null },
    });

    console.log(`📊 Found ${sitters.length} sitters with Stripe Connect accounts\n`);

    if (sitters.length === 0) {
      console.log('✅ No sitters with Stripe Connect accounts found!');
      await mongoose.connection.close();
      return;
    }

    // Clear all Stripe Connect account IDs
    const result = await Sitter.updateMany(
      { stripeConnectAccountId: { $ne: null } },
      {
        $set: {
          stripeConnectAccountId: null,
          stripeConnectAccountStatus: 'not_connected',
        },
      }
    );

    console.log(`\n✅ Cleared Stripe Connect accounts from ${result.modifiedCount} sitters`);
    console.log(`\n💡 All sitters can now create new Stripe Connect accounts when needed.\n`);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
  } catch (error) {
    console.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run the script
clearAllStripeAccounts();

