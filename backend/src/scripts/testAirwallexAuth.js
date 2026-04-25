/**
 * Sanity test for Airwallex credentials.
 *
 * Usage (from /backend):
 *   node src/scripts/testAirwallexAuth.js
 *
 * Reads AIRWALLEX_CLIENT_ID, AIRWALLEX_API_KEY and AIRWALLEX_BASE_URL from .env
 * (or process env on Render). Runs three checks:
 *   1. Authenticate (get bearer token).
 *   2. Create a tiny EUR 0.50 PaymentIntent (NOT confirmed → no charge).
 *   3. Retrieve the same PaymentIntent.
 *
 * Exits 0 on success, 1 on any failure.
 */
require('dotenv').config();

const airwallex = require('../services/airwallexService');

(async () => {
  const ok  = (msg) => console.log(`✅ ${msg}`);
  const ko  = (msg, err) => {
    console.error(`❌ ${msg}`);
    if (err) {
      console.error('   message:', err.message);
      if (err.status)  console.error('   status :', err.status);
      if (err.code)    console.error('   code   :', err.code);
      if (err.details) console.error('   details:', JSON.stringify(err.details, null, 2));
    }
  };

  const baseUrl = process.env.AIRWALLEX_BASE_URL || 'https://api-demo.airwallex.com';
  console.log(`\n🔧 Airwallex sanity test`);
  console.log(`   base URL : ${baseUrl}`);
  console.log(`   client id: ${(process.env.AIRWALLEX_CLIENT_ID || '').slice(0, 8)}…`);
  console.log(`   api key  : ${(process.env.AIRWALLEX_API_KEY || '').slice(0, 8)}…`);
  console.log('');

  // 1. Authenticate ─────────────────────────────────────────────────────────
  let token;
  try {
    token = await airwallex.getAccessToken();
    ok(`Authentication OK (token length: ${token.length})`);
  } catch (e) {
    ko('Authentication FAILED', e);
    process.exit(1);
  }

  // 2. Create a EUR 0.50 PaymentIntent (not confirmed, no charge) ───────────
  let intent;
  try {
    intent = await airwallex.createPlatformPaymentIntent({
      amount: 50,            // 0.50 EUR in cents
      currency: 'EUR',
      metadata: {
        type: 'sanity-test',
        ts:   String(Date.now()),
      },
    });
    ok(`PaymentIntent created — id=${intent.id} status=${intent.status} amount=${intent.amount} ${intent.currency}`);
  } catch (e) {
    ko('createPlatformPaymentIntent FAILED', e);
    process.exit(1);
  }

  // 3. Retrieve it ─────────────────────────────────────────────────────────
  try {
    const fetched = await airwallex.retrievePaymentIntent(intent.id);
    if (fetched.id === intent.id) {
      ok(`retrievePaymentIntent OK — same id, status=${fetched.status}`);
    } else {
      ko(`retrievePaymentIntent returned a different id (${fetched.id})`);
      process.exit(1);
    }
  } catch (e) {
    ko('retrievePaymentIntent FAILED', e);
    process.exit(1);
  }

  console.log('\n🎉 All checks passed. Airwallex credentials are working.\n');
  process.exit(0);
})();
