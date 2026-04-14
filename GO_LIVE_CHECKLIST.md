# GO LIVE CHECKLIST — HopeTSIT

Pas-à-pas pour passer HopeTSIT en production. Coche chaque case en progressant.
Ordre recommandé : § 1 → § 12.

---

## 1. Génération des secrets locaux

- [ ] **Générer `ENCRYPTION_KEY` + `JWT_SECRET` forts (64 caractères hex)**

  ```bash
  cd backend
  node src/scripts/generateSecrets.js
  ```

  Le script n'écrit **pas** automatiquement dans `.env`. Il affiche les nouvelles valeurs.
  - Copie chaque ligne affichée dans `backend/.env` (remplace les placeholders).
  - Garde ces valeurs sous le coude : tu en auras besoin à l'étape § 5 (Render).

  Sécurité : ne commit jamais `backend/.env` (déjà dans `.gitignore`). Ne partage jamais ces secrets par email/Slack non chiffrés.

---

## 2. Rotation des secrets externes (tous compromis)

Tous les secrets livrés dans `backend/.env` à la passation sont à considérer comme **publics**. Roter dans l'ordre du tableau.

| # | Provider | URL console | Étapes | Où coller la nouvelle valeur |
|---|----------|-------------|--------|------------------------------|
| 2.1 | **Firebase Admin SDK** | https://console.firebase.google.com/project/hopetsit/settings/serviceaccounts/adminsdk | 1. IAM & Admin → Service Accounts → `firebase-adminsdk-fbsvc@…`<br>2. Onglet *Keys* → supprimer l'ancienne<br>3. *Add Key* → *Create new key* → JSON<br>4. Dans le JSON : copier `client_email` et `private_key` | `backend/.env` : `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY` (attention : échapper les `\n`) + Render |
| 2.2 | **Stripe secret + webhook** | https://dashboard.stripe.com/apikeys | 1. *Roll* la secret key (`sk_test_...`)<br>2. Developers → Webhooks → endpoint HopeTSIT → *Roll secret* | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `Stripe_publish_key` (et `STRIPE_PUBLISHABLE_KEY` côté `frontend/.env`) + Render |
| 2.3 | **PayPal** | https://developer.paypal.com/dashboard/applications | App HopeTSIT → *Show* secret → *Regenerate* | `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET` + Render |
| 2.4 | **MongoDB Atlas** | https://cloud.mongodb.com | 1. Database Access → utilisateur `petinstauser` → *Edit Password*<br>2. Network Access → whitelister les IP Render (retirer `0.0.0.0/0` si présent) | `MONGODB_URI` + Render |
| 2.5 | **Cloudinary** | https://console.cloudinary.com/settings/api-keys | *Generate New API Key* puis désactiver l'ancienne | `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` + Render |
| 2.6 | **Gmail SMTP (app password)** | https://myaccount.google.com/apppasswords (compte `testinguser652@gmail.com`) | 1. Révoquer l'app password compromis<br>2. Créer un nouveau "App Password"<br>3. **Recommandé** : migrer vers SendGrid/Postmark à terme | `SMTP_PASS` + Render |
| 2.7 | **Admin seed** | N/A (local) | Définir un email + mot de passe admin forts (12+ caractères, symboles) | `ADMIN_SEED_EMAIL`, `ADMIN_SEED_PASSWORD` dans `backend/.env`. Sera utilisé par `seedAdmin` à l'étape § 6 |

Après avoir tout rotaté, revérifie dans `backend/.env` que plus aucune ligne ne contient de valeur de type `hopetsit_…` ou `sk_test_51RLRwf…` (les placeholders d'origine).

---

## 3. Firebase Console — SHA-1 & SHA-256 Android

- [ ] **Obtenir les empreintes du keystore debug**

  ```bash
  # Debug (clé utilisée par flutter run / tests locaux)
  keytool -list -v -keystore $HOME/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```

  Sur Windows PowerShell :

  ```powershell
  keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
  ```

  Note les lignes `SHA1:` et `SHA256:`.

- [ ] **Obtenir les empreintes release** (si tu as déjà une `keystore` release)

  ```bash
  keytool -list -v -keystore path/to/release.keystore -alias YOUR_ALIAS
  ```

- [ ] **Les ajouter dans Firebase**

  Firebase Console → Project settings → Your apps → Android → **Add fingerprint** : coller SHA-1 puis SHA-256, debug + release.

- [ ] **Si Play App Signing activé** : récupérer aussi la SHA depuis Play Console → *Release → Setup → App signing* et l'ajouter dans Firebase.

- [ ] **Re-télécharger `google-services.json`** et écraser `frontend/android/app/google-services.json`.

---

## 4. Apple Developer — Sign in with Apple

Pré-requis : compte Apple Developer payant et accès à `developer.apple.com`.

- [ ] **App ID** (https://developer.apple.com/account/resources/identifiers/list) → éditer l'App ID HopeTSIT → cocher **Sign In with Apple**.

- [ ] **Service ID** (si auth via web/Android) → créer un Identifier de type *Services ID*, activer Sign In with Apple, configurer le domaine et le Return URL Firebase : `https://hopetsit.firebaseapp.com/__/auth/handler`.

- [ ] **Key** → https://developer.apple.com/account/resources/authkeys/list → créer une clé avec *Sign in with Apple* activé → télécharger le fichier `.p8` (un seul téléchargement possible !).

- [ ] **Firebase Console → Authentication → Sign-in methods → Apple** :
  - Services ID : l'ID créé à l'étape précédente
  - Apple team ID
  - Key ID + contenu du `.p8`

- [ ] **Xcode → Runner target → Signing & Capabilities** : ajouter la capability *Sign In with Apple*.

- [ ] **`frontend/ios/Runner/Runner.entitlements`** : vérifier la présence de

  ```xml
  <key>com.apple.developer.applesignin</key>
  <array><string>Default</string></array>
  ```

- [ ] **`frontend/ios/Runner/Info.plist`** : `CFBundleURLTypes` doit contenir le `REVERSED_CLIENT_ID` de `GoogleService-Info.plist` (pour le retour du flow Google).

---

## 5. Hébergeur backend (Render) — variables d'environnement

Depuis le dashboard Render → service backend → *Environment* → *Add Environment Variable*. Ajouter exactement :

```
CLOUDINARY_CLOUD_NAME=<rotated at §2.5>
CLOUDINARY_API_KEY=<rotated at §2.5>
CLOUDINARY_API_SECRET=<rotated at §2.5>
FIREBASE_PROJECT_ID=hopetsit
FIREBASE_CLIENT_EMAIL=<rotated at §2.1>
FIREBASE_PRIVATE_KEY="<rotated at §2.1 — échapper les \n>"
FIREBASE_API_KEY=<regen ou laisse l'ancienne si restreinte>
JWT_SECRET=<generated at §1>
ENCRYPTION_KEY=<generated at §1>
ADMIN_SEED_EMAIL=<chosen at §2.7>
ADMIN_SEED_PASSWORD=<chosen at §2.7>
MONGODB_URI=<rotated at §2.4>
NODE_ENV=production
PORT=10000  # ou ce que Render exige
ALLOWED_ORIGINS=https://hopetsit.com,https://api.hopetsit.com,https://admin.hopetsit.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=<Gmail account>
SMTP_PASS=<rotated at §2.6>
SMTP_FROM="HopeTSIT <no-reply@hopetsit.com>"
STRIPE_SECRET_KEY=<rotated at §2.2>
STRIPE_WEBHOOK_SECRET=<rotated at §2.2>
Stripe_publish_key=<rotated at §2.2>
STRIPE_CONNECT_REFRESH_URL=https://api.hopetsit.com/stripe-connect/refresh
STRIPE_CONNECT_RETURN_URL=https://api.hopetsit.com/stripe-connect/return
PAYPAL_CLIENT_ID=<rotated at §2.3>
PAYPAL_CLIENT_SECRET=<rotated at §2.3>
PAYPAL_MODE=live  # ou 'sandbox' pour tests
TRANSLATION_API_PROVIDER=none  # ou 'deepl'/'google' si souscrit
TERMS_VERSION=v1.0
```

- [ ] Toutes les variables ci-dessus sont définies sur Render.
- [ ] Un **Manual Deploy** est déclenché après l'ajout.

---

## 5.1 Sentry (optionnel, recommandé)

- [ ] Créer un compte sur https://sentry.io (gratuit jusqu'à 5k events/mois).
- [ ] Créer **2 projets** : `hopetsit-backend` (Node.js) et `hopetsit-frontend` (Flutter).
- [ ] Récupérer les DSN des 2 projets.
- [ ] Backend : coller le DSN dans `SENTRY_DSN_BACKEND` (`backend/.env` + variables Render).
- [ ] Frontend : coller le DSN dans `SENTRY_DSN_FRONTEND` (`frontend/.env`).
- [ ] Optionnel : régler `SENTRY_TRACES_SAMPLE_RATE` entre `0` et `1` (`0.1` = 10 % des transactions tracées).
- [ ] Déclencher une erreur de test en staging pour vérifier la réception.

## 5.2 Swagger en production

- [ ] Générer un token fort pour `SWAGGER_AUTH_TOKEN` (Render) :
      ```bash
      node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
      ```
- [ ] Tester que `/api-docs` en prod renvoie 401 sans header, 200 avec `X-Swagger-Auth: <token>`.

## 6. Exécution des scripts de migration DB

Une fois les variables d'env en place **localement** (`backend/.env` à jour), exécuter :

```bash
cd backend
node src/scripts/runAllMigrations.js
```

Ce script enchaîne :
1. `dropMobileUniqueIndex` — retire l'index unique sur `mobile` si hérité.
2. `encryptSensitiveFields` — chiffre IBAN / PayPal email / carte (idempotent).
3. `seedAdmin` — crée le premier admin à partir de `ADMIN_SEED_EMAIL/PASSWORD`.

- [ ] Sortie : `All migrations finished successfully.`

---

## 7. Frontend — build Flutter

- [ ] **Windows PowerShell** :

  ```powershell
  .\setup_frontend.ps1
  ```

- [ ] **Linux/macOS** :

  ```bash
  cd frontend
  flutter pub get
  flutter build apk --release
  flutter build ios --release  # macOS uniquement
  ```

- [ ] APK généré : `frontend/build/app/outputs/flutter-apk/app-release.apk`

---

## 8. QA visuel — checklist des écrans

Tester sur **un appareil physique** (émulateur pour backup). Compte de test : un owner + un sitter déjà créés.

### Mode clair + mode sombre (Settings → Theme)

- [ ] Splash, Login, Sign up (owner), Sign up (sitter)
- [ ] Connexion Google (Android)
- [ ] Connexion Apple (iOS uniquement)
- [ ] Home owner (carte sitters + bouton "Près de chez moi" + slider)
- [ ] Home sitter
- [ ] Création pet profile (sections dépliables : age, vaccinations, behavior, vétérinaires, urgence + texte légal)
- [ ] Édition pet profile (mêmes sections)
- [ ] Publication demande de réservation (radio "Chez toi / Chez moi / Les deux")
- [ ] Profil owner : toggles "Chez toi" / "Chez moi"
- [ ] Profil sitter : bouton "Mon calendrier de disponibilité" (TableCalendar)
- [ ] Profil sitter : bouton "Vérifier mon identité" (upload photo)
- [ ] Card sitter côté owner : badge "Identité vérifiée" visible si sitter vérifié
- [ ] Booking agreement → bouton Stripe
- [ ] PaymentSheet Stripe (carte de test `4242 4242 4242 4242`)
- [ ] Post-paiement : chat débloqué, bouton "Partager mon numéro" (sitter)
- [ ] Chat avant paiement : bannière "Le chat s'ouvre après confirmation du paiement"
- [ ] Notifications in-app (badge cloche + bottom nav chat/bookings)
- [ ] Notification push reçue (FCM) avec app en arrière-plan
- [ ] Email reçu lors d'un event (vérifier boîte de réception + dossier spam)
- [ ] Walk tracking : sitter démarre → owner suit en temps réel sur map
- [ ] Visit report : sitter soumet avec photos → owner voit la galerie
- [ ] CGU accessible depuis profil + signup

### Multi-langue

- [ ] Settings → Language → switch FR/EN/ES/DE/IT/PT. Vérifier que l'UI traduit.

---

## 9. Test sur téléphone Android

- [ ] Installer `app-release.apk` sur un Android physique (hors émulateur).
- [ ] Login Google fonctionne (SHA-1 release bien enregistrée).
- [ ] Notifications push reçues avec app fermée.
- [ ] Paiement Stripe en mode test réussit.
- [ ] Géolocalisation détectée (permission demandée correctement).

---

## 10. Test sur simulateur iOS / iPhone physique

- [ ] Build et installer via Xcode (`flutter build ios --release` → ouvrir Xcode → archive → export).
- [ ] Login Apple fonctionne (capability + Service ID OK).
- [ ] PaymentSheet Apple Pay si activé dans Stripe.
- [ ] Notifications push (APNs) reçues.

---

## 11. Soumission Play Store

- [ ] Compte Google Play Console actif ($25 one-time).
- [ ] Créer l'app, remplir fiche (descriptions × 6 langues, captures, icônes, politique de confidentialité).
- [ ] Uploader `app-release.aab` (bundle préféré à APK) : `flutter build appbundle --release`
- [ ] Review Content rating + Target audience.
- [ ] Soumettre en *Internal testing* d'abord → *Closed* → *Production*.

---

## 12. Soumission App Store

- [ ] Compte Apple Developer actif ($99/an).
- [ ] Créer l'app sur App Store Connect.
- [ ] Fiches (descriptions × 6 langues, captures iPhone/iPad, icône, politique de confidentialité).
- [ ] Archive via Xcode → Distribute App → App Store Connect.
- [ ] Remplir section *App Privacy* (important : données collectées, usage, tracking).
- [ ] Soumettre à la review. Délai moyen : 24-72 h.

---

## Annexes

- **Anciens docs archivés** : `archives/SECRETS_ROTATION.md`, `archives/RAPPORT_AUTH.md` (à consulter pour contexte historique).
- **Audit initial** : `AUDIT_v3.md`.
- **Scripts** :
  - `backend/src/scripts/generateSecrets.js`
  - `backend/src/scripts/runAllMigrations.js`
  - `backend/src/scripts/dropMobileUniqueIndex.js`
  - `backend/src/scripts/encryptSensitiveFields.js`
  - `backend/src/scripts/seedAdmin.js`
  - `setup_frontend.ps1`
