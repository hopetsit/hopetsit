# RAPPORT AUTH — Google & Apple Sign-In

**Date** : 2026-04-14
**Sprint** : 2 / Étape 3
**Périmètre** : état du code d'authentification sociale (Google + Apple) et actions manuelles requises hors code.

---

## 1. État du code après sprint2/step3

### ✅ En place

- **Backend** `backend/src/controllers/authController.js`
  - `POST /auth/google` (ligne 302) — valide l'`idToken` via `firebaseAdmin.auth().verifyIdToken(idToken)`
  - `POST /auth/apple` (ligne 531) — même mécanisme
  - Extraction correcte de `uid`, `email`, `name`, `picture`, `firebase.sign_in_provider`
  - Stratégie login-ou-signup selon présence email, `role` optionnel dans le body pour les nouveaux utilisateurs
  - Retourne `{ token, role, user, existingUser }`
- **Frontend**
  - `firebase_auth: ^6.1.0`
  - `google_sign_in: ^7.2.0` (API v7, `authenticate()` / `authenticationEvents`)
  - `frontend/android/app/google-services.json` présent
  - `frontend/ios/Runner/GoogleService-Info.plist` présent
  - `firebase_options.dart` auto-généré
  - `auth_repository.dart` → `googleSignInWithIdToken` / `appleSignInWithIdToken` envoient `{ idToken, role? }`
- **Corrections apportées dans ce commit** :
  - Suppression des `print("object22/33/44/55")` (debug oublié)
  - Suppression du paramètre `accessToken: idToken` erroné passé à `GoogleAuthProvider.credential` (l'idToken seul suffit avec Firebase Auth)

### ⚠️ Points d'attention

- **`the_apple_sign_in: ^1.1.1` est discontinué** (dernière mise à jour en 2020, avant la migration null-safety stable). Il fonctionne encore à l'exécution mais :
  - Ne supporte pas officiellement les nouvelles versions de Flutter
  - N'est pas compatible Android (Sign in with Apple sur Android web flow n'existe pas dans ce package)
  - **Migration recommandée** vers `sign_in_with_apple: ^6.x` (voir §3 plan de migration)
- **`auth_controller.dart` n'affiche pas encore de message localisé si Firebase rejette le token** — l'UX pourrait distinguer "token expiré" vs "réseau" vs "compte désactivé", mais c'est une amélioration UX, pas un bug bloquant.

---

## 2. Actions manuelles requises (hors code)

Ces actions ne peuvent pas être effectuées depuis le code. Elles doivent être réalisées dans les consoles Firebase / Google Cloud / Apple Developer.

### 2.1 Firebase Console — projet `hopetsit`

URL : https://console.firebase.google.com/project/hopetsit

#### Android

1. **Project settings → Your apps → Android app** : vérifier que le package est bien `com.hopetsit.app` (ou celui défini dans `android/app/build.gradle`).
2. **SHA-1 / SHA-256 fingerprints** — nécessaires pour que Google Sign-In fonctionne sur Android :
   - Obtenir les empreintes :
     ```bash
     # SHA-1 debug (clé locale dev)
     cd frontend/android
     ./gradlew signingReport

     # Ou directement :
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
   - Ajouter les empreintes **debug** et **release** dans *Project settings → Android app → Add fingerprint*.
   - Si tu utilises Play App Signing, ajouter aussi la **SHA-1 de la clé d'upload** ET la **SHA-1 fournie par Play Console** (App signing key certificate).
3. **Re-télécharger `google-services.json`** après ajout des empreintes et écraser le fichier dans `frontend/android/app/`.

#### iOS

1. **Project settings → Your apps → iOS app** : vérifier le Bundle ID (ex. `com.hopetsit.app`).
2. **Authentication → Sign-in methods** :
   - **Google** : activé, vérifier que le **Web SDK configuration** contient un *Client ID* et un *Client secret* (obligatoire pour Apple, optionnel pour Google côté iOS mais utile pour le revoke API).
   - **Apple** : activé. Renseigner :
     - **Services ID** (ex. `com.hopetsit.signin`) — créé sur https://developer.apple.com/account/resources/identifiers/list/serviceId
     - **Apple team ID**
     - **Key ID** + **Private key** (fichier `.p8` téléchargeable une seule fois depuis Apple Developer → Keys)
3. **Authorized domains** : ajouter le domaine du backend (`petinsta-backend-g7jn.onrender.com`, `api.hopetsit.com`).
4. **Re-télécharger `GoogleService-Info.plist`** et écraser dans `frontend/ios/Runner/`.

### 2.2 Android — Google Services

- Ouvrir `frontend/android/app/google-services.json` et vérifier :
  - `project_info.project_id` = `hopetsit`
  - `client[].client_info.android_client_info.package_name` correspond au package dans `AndroidManifest.xml`
  - `client[].oauth_client[]` contient bien les OAuth client IDs pour Android (type=1) et pour Web (type=3)
- Le **Web client ID** est celui passé à `google_sign_in` comme `serverClientId` dans le code :
  ```dart
  // auth_controller.dart:200
  await _googleSignIn.initialize(
    clientId: "470089536255-sedqnlp3c54m3jv0g21mcoq7a23i6487.apps.googleusercontent.com",
    serverClientId: "470089536255-q9nrquiekrp6vmjdua2gio42r19fsrd4.apps.googleusercontent.com",
  );
  ```
  → Ces IDs doivent **exister dans le même projet GCP** (`hopetsit`) et être marqués **Active**. À vérifier sur https://console.cloud.google.com/apis/credentials?project=hopetsit

### 2.3 iOS — Xcode & Apple Developer

1. **Xcode → Runner target → Signing & Capabilities** :
   - Ajouter la capability **Sign in with Apple**
   - Vérifier que le Team ID correspond à celui configuré sur Firebase
2. **`frontend/ios/Runner/Info.plist`** :
   - `CFBundleURLTypes` doit contenir une entrée avec le `REVERSED_CLIENT_ID` de `GoogleService-Info.plist` (ex. `com.googleusercontent.apps.470089536255-xxxxx`) pour le retour du flow Google.
   - Ex. :
     ```xml
     <key>CFBundleURLTypes</key>
     <array>
       <dict>
         <key>CFBundleURLSchemes</key>
         <array>
           <string>com.googleusercontent.apps.470089536255-xxxxx</string>
         </array>
       </dict>
     </array>
     ```
3. **Apple Developer Portal** (https://developer.apple.com/account/resources) :
   - **Identifiers** : l'App ID du projet doit avoir **Sign in with Apple** activé
   - **Services ID** : créer une Service ID dédiée au sign-in si utilisation Web/Android (pas strictement nécessaire pour iOS natif, mais requise pour Firebase Apple provider)
   - **Return URL** : https://hopetsit.firebaseapp.com/__/auth/handler (ou le domaine custom si configuré)
4. **Entitlements** : vérifier `ios/Runner/Runner.entitlements` contient :
   ```xml
   <key>com.apple.developer.applesignin</key>
   <array><string>Default</string></array>
   ```

---

## 3. Plan recommandé : migration `the_apple_sign_in` → `sign_in_with_apple`

**Pourquoi** : `the_apple_sign_in` n'est plus maintenu et peut se casser à tout moment lors d'une mise à jour Flutter/Xcode. `sign_in_with_apple` (6.x) est le package de référence, maintenu activement.

**Changements nécessaires** (non appliqués dans ce commit — décision à prendre) :

1. `pubspec.yaml` :
   ```diff
   - the_apple_sign_in: ^1.1.1
   + sign_in_with_apple: ^6.0.0
   ```
2. `auth_controller.dart`, remplacer l'import :
   ```diff
   - import 'package:the_apple_sign_in/the_apple_sign_in.dart';
   + import 'package:sign_in_with_apple/sign_in_with_apple.dart';
   ```
3. Réécrire `loginWithApple()` :
   ```dart
   final credential = await SignInWithApple.getAppleIDCredential(
     scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
   );
   final oauthCredential = OAuthProvider('apple.com').credential(
     idToken: credential.identityToken,
     accessToken: credential.authorizationCode,
   );
   await _auth.signInWithCredential(oauthCredential);
   ```
4. Aucun changement backend (le flux Firebase ID token reste identique).
5. Tester sur iOS physique (simulateur iOS supporte Sign in with Apple depuis iOS 13+).

**Estimation** : ~1-2h de travail, principalement test manuel.

---

## 4. Checklist de tests manuels

Après avoir complété §2, tester les 4 scénarios :

- [ ] **Google — nouveau compte owner** : sign-up, redirection vers `ChooseServiceScreen`, création owner en DB
- [ ] **Google — compte existant** : connexion, redirection home directement
- [ ] **Google — nouveau compte sitter** : sign-up avec role=sitter, création sitter en DB
- [ ] **Apple — nouveau compte** : sign-up, email relay Apple (`privaterelay.appleid.com`), création utilisateur
- [ ] **Apple — compte existant** : connexion, récupération par `firebaseUid`
- [ ] **Google sur iOS physique** : ouverture du sheet natif, retour app, token valide
- [ ] **Apple sur iOS physique** : écran noir Apple natif, Face/Touch ID, retour app
- [ ] **Google sur Android physique** (debug keystore) : sélecteur de compte, consentement, retour app
- [ ] **Google sur Android release** (Play Store internal test) : SHA de la clé release bien enregistrée
- [ ] **Backend** : `/auth/google` et `/auth/apple` renvoient bien `{token, role, existingUser}`
- [ ] **Rate limit** : enchaîner 6 appels `/auth/google` → le 6ème renvoie 429 (authLimiter appliqué)

---

## 5. Erreurs courantes et résolution

| Symptôme | Cause probable | Résolution |
|---------|---------------|-----------|
| Google sign-in → `PlatformException(sign_in_failed, 10)` | SHA-1 pas enregistré dans Firebase | Ajouter SHA et re-télécharger `google-services.json` |
| Google sign-in → `PlatformException(sign_in_failed, 12500)` | Play Services manquant / outdated sur l'émulateur | Utiliser une image Play Store, pas AOSP |
| Apple sign-in → `AuthorizationStatus.error` invalid_client | Service ID ou clé privée Apple mal configurée sur Firebase | Revérifier Services ID + Key ID + fichier `.p8` |
| Backend répond 400 `Invalid token` | JWT Firebase pas lié au projet `hopetsit` | Vérifier `FIREBASE_PROJECT_ID` dans `.env` |
| Backend répond 500 `FIREBASE_PRIVATE_KEY is not configured` | `\n` pas interprétés dans la clé privée | Vérifier l'échappement : `"-----BEGIN…\nKEY\n-----END…\n"` |
| iOS Apple sign-in → écran blanc | Capability "Sign in with Apple" absente | Xcode → Signing & Capabilities → + Capability |

---

## Références

- Firebase Auth (Flutter) : https://firebase.google.com/docs/auth/flutter/federated-auth
- `google_sign_in` v7 migration : https://pub.dev/packages/google_sign_in/versions/7.2.0
- `sign_in_with_apple` : https://pub.dev/packages/sign_in_with_apple
- Apple Service ID setup : https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_js/configuring_your_webpage_for_sign_in_with_apple
