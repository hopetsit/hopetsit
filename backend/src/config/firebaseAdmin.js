const admin = require('firebase-admin');

let firebaseApp;

/**
 * Initialize Firebase Admin SDK as a singleton.
 * Uses environment variables:
 * - FIREBASE_PROJECT_ID
 * - FIREBASE_CLIENT_EMAIL
 * - FIREBASE_PRIVATE_KEY (with escaped newlines: replace(/\\n/g, "\n"))
 */
const getFirebaseAdmin = () => {
  if (firebaseApp) {
    return admin;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const rawPrivateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || !clientEmail || !rawPrivateKey) {
    throw new Error(
      'Firebase Admin environment variables are not fully configured. ' +
        'Please set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY.'
    );
  }

  const privateKey = rawPrivateKey.replace(/\\n/g, '\n');

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      clientEmail,
      privateKey,
    }),
  });

  return admin;
};

module.exports = getFirebaseAdmin();


