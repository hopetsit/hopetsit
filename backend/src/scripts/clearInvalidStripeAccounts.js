/**
 * Clear invalid Stripe Connect account IDs from sitters
 * This script removes Stripe Connect account IDs that don't exist in Stripe
 * 
 * Usage: node src/scripts/clearInvalidStripeAccounts.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Sitter = require('../models/Sitter');
const { getAccountStatus } = require('../services/stripeService');

async function clearInvalidStripeAccounts() {
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

    let clearedCount = 0;
    let validCount = 0;
    let errorCount = 0;

    for (const sitter of sitters) {
      try {
        // Try to get account status from Stripe
        const accountStatus = await getAccountStatus(sitter.stripeConnectAccountId);
        
        // If we get here, account exists - check if it's valid
        if (accountStatus) {
          console.log(`  ✅ Sitter ${sitter._id}: Account ${sitter.stripeConnectAccountId} is valid`);
          validCount++;
        }
      } catch (error) {
        // Account doesn't exist or is invalid
        // Also handle case where Stripe Connect platform is not set up
        if (
          error.code === 'resource_missing' || 
          error.statusCode === 404 || 
          error.statusCode === 400 ||
          error.message?.includes('Only Stripe Connect platforms') ||
          error.message?.includes('Stripe Connect platform')
        ) {
          console.log(`  🗑️  Sitter ${sitter._id}: Account ${sitter.stripeConnectAccountId} is invalid or Connect not configured - clearing`);
          
          // Clear the invalid account ID
          sitter.stripeConnectAccountId = null;
          sitter.stripeConnectAccountStatus = 'not_connected';
          await sitter.save();
          
          clearedCount++;
        } else {
          console.error(`  ❌ Error checking sitter ${sitter._id}:`, error.message);
          errorCount++;
        }
      }
    }

    console.log(`\n✅ Clear invalid accounts complete!`);
    console.log(`   - Valid accounts: ${validCount}`);
    console.log(`   - Cleared invalid accounts: ${clearedCount}`);
    console.log(`   - Errors: ${errorCount}`);
    console.log(`\n💡 Sitters with invalid accounts can now create new Stripe Connect accounts.\n`);

    await mongoose.connection.close();
    console.log('✅ Database connection closed');
  } catch (error) {
    console.error('❌ Error:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

// Run the script
clearInvalidStripeAccounts();

