// Firebase Web client — used only for social sign-in (Google for now).
// The backend then verifies the Firebase ID token via firebase-admin.
//
// Set the public env vars below in `.env.local`:
//   NEXT_PUBLIC_FIREBASE_API_KEY=...
//   NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
//   NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
//   NEXT_PUBLIC_FIREBASE_APP_ID=...
//   NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=...
// (Same Firebase project as the mobile app — copy from Firebase Console
// → Project Settings → General → Your apps → Web.)

import { initializeApp, getApps, FirebaseApp } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  Auth,
} from "firebase/auth";

const config = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain:        process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
};

export function isFirebaseConfigured(): boolean {
  return Boolean(config.apiKey && config.projectId && config.appId);
}

let _app: FirebaseApp | null = null;
let _auth: Auth | null = null;

function ensureApp(): FirebaseApp {
  if (_app) return _app;
  if (!isFirebaseConfigured()) {
    throw new Error(
      "Firebase Web is not configured. Add NEXT_PUBLIC_FIREBASE_* env vars to .env.local.",
    );
  }
  _app = getApps()[0] || initializeApp(config as Record<string, string>);
  return _app;
}

function ensureAuth(): Auth {
  if (_auth) return _auth;
  _auth = getAuth(ensureApp());
  return _auth;
}

/**
 * Open the Google popup, return the Firebase ID token (JWT) ready to send to
 * `POST /api/v1/auth/google`. Throws on cancellation or popup-blocked errors.
 */
export async function signInWithGooglePopup(): Promise<string> {
  const auth = ensureAuth();
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: "select_account" });
  const cred = await signInWithPopup(auth, provider);
  const idToken = await cred.user.getIdToken();
  return idToken;
}
