# Fix: "Invalid or expired Firebase ID token" (401)

## Cause
- **App** uses Firebase project: **hopetsit**
- **Backend** verifies tokens with Firebase project: **petinsta-bb835**

Tokens from one project cannot be verified by the other, so the backend returns 401.

---

## Option 1: Use backend’s Firebase project in the app (recommended)

Make the app use the **same** project as the backend: **petinsta-bb835**.

### Steps

1. **Firebase Console**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Open project **petinsta-bb835** (the one your backend uses).

2. **Android**
   - In **petinsta-bb835**, go to Project settings → Your apps.
   - Add an Android app with package name **`com.hopetsit.app`** (or use existing if already added).
   - Download the **google-services.json** for this app.
   - Replace your app’s file:
     - **Replace:** `android/app/google-services.json`  
     - with the downloaded file from **petinsta-bb835**.

3. **iOS**
   - In **petinsta-bb835**, add an iOS app with bundle ID **`com.hopetsit.app`** (or use existing).
   - Download **GoogleService-Info.plist**.
   - Replace your app’s file:
     - **Replace:** `ios/Runner/GoogleService-Info.plist`  
     - with the downloaded file from **petinsta-bb835**.

4. **Google Sign-In (petinsta-bb835)**
   - In **petinsta-bb835**, enable **Authentication** → **Sign-in method** → **Google**.
   - For Android: add your app’s SHA-1 in Firebase (Project settings → Your apps → Android app → Add fingerprint).
   - Ensure OAuth consent and client IDs are set for the same package/bundle ID.

5. **Rebuild**
   - Clean and rebuild:
     - `flutter clean && flutter pub get`
   - Run the app and try Google sign-in again.

After this, the app will issue ID tokens for **petinsta-bb835**, and the backend will accept them.

---

## Option 2: Use app’s Firebase project on the backend

Keep the app on **hopetsit** and change the backend to verify **hopetsit** tokens.

1. In Firebase Console, open project **hopetsit**.
2. Project settings → Service accounts → Generate new private key.
3. On the backend, configure Firebase Admin SDK with this **hopetsit** service account JSON (replace the current petinsta-bb835 credentials).
4. Redeploy the backend.

Then the backend will accept tokens from your current app without changing the app.

---

## Security note

If you shared your backend service account JSON (including the private key) in a chat or repo, treat it as compromised:

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → **petinsta-bb835** → IAM & Admin → Service accounts.
2. Open the key used in that JSON and delete it (or create a new key and delete the old one).
3. Update the backend with the new key/JSON.

Never commit or paste full service account JSON (with `private_key`) in chat or version control.
