require('dotenv').config();
const admin = require('firebase-admin');
const https = require('https'); 
const logger = require('../utils/logger');
/**
 * Script to generate Firebase ID token for testing Google login in Postman
 * 
 * Usage:
 *   node src/scripts/generateFirebaseToken.js <email> <role>
 * 
 * Example:
 *   node src/scripts/generateFirebaseToken.js test@example.com owner
 */

// Initialize Firebase Admin
const projectId = process.env.FIREBASE_PROJECT_ID;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
const rawPrivateKey = process.env.FIREBASE_PRIVATE_KEY;

if (!projectId || !clientEmail || !rawPrivateKey) {
  logger.error('❌ Firebase Admin environment variables are not configured.');
  logger.error('   Please set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY in your .env file.');
  process.exit(1);
}

const privateKey = rawPrivateKey.replace(/\\n/g, '\n');

try {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    }),
  });
  logger.info('✅ Firebase Admin initialized');
} catch (error) {
  logger.error('❌ Failed to initialize Firebase Admin:', error.message);
  process.exit(1);
}

async function generateFirebaseToken(email, role = 'owner') {
  try {
    logger.info(`\n📧 Email: ${email}`);
    logger.info(`👤 Role: ${role}`);
    logger.info('\n🔄 Creating/getting user in Firebase...');

    let userRecord;
    try {
      // Try to get existing user
      userRecord = await admin.auth().getUserByEmail(email);
      logger.info('   ✅ User already exists in Firebase');
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // Create new user
        userRecord = await admin.auth().createUser({
          email: email,
          emailVerified: true,
          displayName: `Test ${role}`,
        });
        logger.info('   ✅ Created new user in Firebase');
      } else {
        throw error;
      }
    }

    // Create custom token
    logger.info('\n🔑 Generating custom token...');
    const customToken = await admin.auth().createCustomToken(userRecord.uid, {
      email: email,
      role: role,
    });
    logger.info('   ✅ Custom token generated');

    // Exchange custom token for ID token using Firebase REST API
    logger.info('\n🔄 Exchanging custom token for ID token...');
    
    const apiKey = process.env.FIREBASE_API_KEY || process.env.FIREBASE_WEB_API_KEY;
    
    if (!apiKey) {
      logger.info('\n⚠️  FIREBASE_API_KEY not found in .env');
      logger.info('   You can still use the custom token, but you need to exchange it manually.');
      logger.info('\n📋 Custom Token (use this in Firebase client SDK):');
      logger.info('─'.repeat(80));
      logger.info(customToken);
      logger.info('─'.repeat(80));
      logger.info('\n💡 To get ID token:');
      logger.info('   1. Use Firebase client SDK to sign in with custom token');
      logger.info('   2. Call user.getIdToken() to get the ID token');
      logger.info('   3. Use that ID token in Postman');
      return;
    }

    // Exchange custom token for ID token using Firebase REST API
    const exchangeUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`;
    const postData = JSON.stringify({
      token: customToken,
      returnSecureToken: true,
    });

    const tokenData = await new Promise((resolve, reject) => {
      const url = new URL(exchangeUrl);
      const options = {
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData),
        },
      };

      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });
        res.on('end', () => {
          try {
            const jsonData = JSON.parse(data);
            if (res.statusCode !== 200) {
              reject(new Error(jsonData.error?.message || `HTTP ${res.statusCode}: ${data}`));
            } else {
              resolve(jsonData);
            }
          } catch (error) {
            reject(new Error(`Failed to parse response: ${error.message}`));
          }
        });
      });

      req.on('error', (error) => {
        reject(new Error(`Request failed: ${error.message}`));
      });

      req.write(postData);
      req.end();
    });

    const idToken = tokenData.idToken;

    logger.info('   ✅ ID token generated successfully!');
    
    logger.info('\n' + '='.repeat(80));
    logger.info('📋 FIREBASE ID TOKEN (Use this in Postman):');
    logger.info('='.repeat(80));
    logger.info(idToken);
    logger.info('='.repeat(80));

    logger.info('\n📝 Postman Request Details:');
    logger.info('─'.repeat(80));
    logger.info('Method: POST');
    logger.info('URL: http://localhost:5000/auth/google');
    logger.info('Headers:');
    logger.info('  Content-Type: application/json');
    logger.info('Body (JSON):');
    logger.info(JSON.stringify({
      idToken: idToken,
      role: role
    }, null, 2));
    logger.info('─'.repeat(80));

    logger.info('\n⏰ Note: This token expires in 1 hour. Generate a new one when needed.');
    logger.info('✅ Done!\n');

    return idToken;
  } catch (error) {
    logger.error('\n❌ Error generating token:', error.message);
    if (error.code) {
      logger.error('   Error code:', error.code);
    }
    process.exit(1);
  }
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0) {
  logger.info('📖 Usage: node src/scripts/generateFirebaseToken.js <email> [role]');
  logger.info('\nExamples:');
  logger.info('  node src/scripts/generateFirebaseToken.js test@example.com owner');
  logger.info('  node src/scripts/generateFirebaseToken.js test@example.com sitter');
  logger.info('\nNote: Make sure FIREBASE_API_KEY is set in your .env file for automatic ID token generation.');
  process.exit(0);
}

const email = args[0];
const role = args[1] || 'owner';

if (!email || !email.includes('@')) {
  logger.error('❌ Invalid email address');
  process.exit(1);
}

if (role !== 'owner' && role !== 'sitter') {
  logger.error('❌ Role must be either "owner" or "sitter"');
  process.exit(1);
}

generateFirebaseToken(email, role);
