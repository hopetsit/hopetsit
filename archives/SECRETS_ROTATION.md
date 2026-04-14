# SECRETS ROTATION — HopeTSIT

**Date** : 2026-04-14
**Contexte** : Les secrets listés ci-dessous ont été exposés en clair dans `backend/.env` et `frontend/.env` livrés avec le projet. Ils doivent **tous être considérés comme compromis** et faire l'objet d'une rotation immédiate, même si le dépôt n'a pas encore été poussé en remote public : le fichier a circulé dans des archives de livraison.

Après rotation, les nouvelles valeurs doivent être stockées dans un gestionnaire de secrets (AWS Secrets Manager, Google Secret Manager, HashiCorp Vault, Doppler, Render/Vercel env UI) — **jamais dans le repo git**.

---

## Priorité

| Priorité | Critère |
|----------|---------|
| 🔴 P0 | Impact financier direct (paiement, payout) ou accès admin total |
| 🟠 P1 | Accès données utilisateurs (DB, email, push) |
| 🟡 P2 | Sessions utilisateurs en cours (invalidation = attendue) |

---

## 1. 🔴 P0 — Stripe

**Variables** : `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `Stripe_publish_key` (backend/.env), `STRIPE_PUBLISHABLE_KEY` (frontend/.env)

**Console** : https://dashboard.stripe.com/apikeys

**Procédure** :
1. Dashboard Stripe → Developers → API keys → *Roll* la clé secrète actuelle (`sk_test_51RLRwf…`).
2. Developers → Webhooks → sélectionner l'endpoint HopeTSIT → *Click to reveal* → *Roll secret*.
3. Si une clé **live** existe (mode production), la rouler également.
4. Mettre à jour les variables dans le secret manager de l'environnement (Render, etc.).
5. Redéployer le backend.

**Note** : la clé publishable n'est pas sensible techniquement, mais doit être alignée avec la nouvelle paire secrète pour éviter les erreurs.

---

## 2. 🔴 P0 — PayPal

**Variables** : `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET`, `PAYPAL_MODE`

**⚠️ Statut** : non présentes dans `backend/.env` actuel — à vérifier si stockées sur Render / dans une autre source. Le code `backend/src/services/paypalService.js` en dépend.

**Console** : https://developer.paypal.com/dashboard/applications/

**Procédure** :
1. Sélectionner l'application HopeTSIT.
2. Cliquer sur *Show* pour le client secret → *Regenerate*.
3. Mettre à jour dans le secret manager.
4. Redéployer.

---

## 3. 🔴 P0 — Admin Secret

**Variable** : `ADMIN_SECRET`
**Valeur exposée** : `hopetsit_admin_2026_Daniel_K9mP2vL8qR5nX3wB7tY4hJ6`

**Action** : sera **supprimée à l'étape 4** du sprint 1 (remplacement par JWT avec `role='admin'`).
En attendant, générer une valeur aléatoire temporaire :
```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

---

## 4. 🟠 P1 — Firebase Admin SDK

**Variables** : `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PROJECT_ID`, `FIREBASE_API_KEY`

**Impact** : accès admin total au projet Firebase (FCM, Auth users). La private key exposée permet d'impersonner le service account.

**Console** : https://console.firebase.google.com → Project settings → Service accounts → "Manage service account keys" (ouvre GCP IAM).

**Procédure** :
1. GCP Console → IAM & Admin → Service Accounts → `firebase-adminsdk-fbsvc@hopetsit.iam.gserviceaccount.com`.
2. Onglet *Keys* → identifier la clé compromise par son key ID → *Delete*.
3. *Add Key* → *Create new key* → JSON.
4. Extraire `client_email` et `private_key` du JSON téléchargé.
5. Stocker dans le secret manager (la `private_key` contient des `\n` à échapper selon le loader).
6. Supprimer le JSON local après import.

**Pour `FIREBASE_API_KEY`** (clé web API, usage côté client) : Firebase Console → Project settings → General → Web API Key. Si la clé est restreinte par origine/bundle ID (à vérifier dans GCP → APIs & Services → Credentials), le risque est limité. Sinon, la régénérer et appliquer des restrictions.

---

## 5. 🟠 P1 — MongoDB Atlas

**Variable** : `MONGODB_URI`
**Valeur exposée** : `mongodb+srv://petinstauser:abcd123786@petinsta.bbibplp.mongodb.net/Petinsta`

**Impact** : accès complet en lecture/écriture à la base de production.

**Console** : https://cloud.mongodb.com

**Procédure** :
1. Atlas → Database Access → utilisateur `petinstauser` → *Edit* → *Edit Password* (générer un mot de passe fort).
2. Atlas → Network Access → restreindre à la plage IP du backend (Render publie ses IP statiques, sinon utiliser le peering VPC si dispo). Retirer `0.0.0.0/0` si présent.
3. Mettre à jour `MONGODB_URI` dans le secret manager.
4. Redéployer.

**Recommandation** : créer des utilisateurs distincts read-only pour les dashboards/analytics.

---

## 6. 🟠 P1 — Cloudinary

**Variables** : `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `CLOUDINARY_CLOUD_NAME`

**Impact** : upload/suppression d'assets média, consommation de quota.

**Console** : https://console.cloudinary.com/settings/api-keys

**Procédure** :
1. Settings → API Keys → *Generate New API Key*.
2. Désactiver l'ancienne clé après vérification du déploiement.
3. Mettre à jour dans le secret manager.

---

## 7. 🟠 P1 — SMTP Gmail (mot de passe d'application)

**Variables** : `SMTP_USER`, `SMTP_PASS`
**Valeur exposée** : `SMTP_PASS="wmfm qopy wqad czdn"` (app password Gmail pour `testinguser652@gmail.com`)

**Impact** : envoi d'email en tant que l'adresse configurée → phishing potentiel au nom du service.

**Console** : https://myaccount.google.com/apppasswords (avec le compte `testinguser652@gmail.com`)

**Procédure** :
1. My Google Account → Security → 2-Step Verification → App passwords.
2. Révoquer le mot de passe d'application `wmfm qopy wqad czdn`.
3. Créer un nouvel app password.
4. Mettre à jour dans le secret manager.

**Recommandation** : migrer vers un provider transactionnel (SendGrid, Postmark, Mailgun) avec domaine vérifié HopeTSIT pour un DKIM/SPF propre.

---

## 8. 🟡 P2 — JWT Secret

**Variable** : `JWT_SECRET`
**Valeur exposée** : `hopetsit_jwt_K9mP2vL8qR5nX3wB7tY4hJ6cF1aZ0eD`

**Impact** : un attaquant peut forger des JWT valides → authentification contournée.

**Procédure** :
1. Générer une nouvelle valeur :
   ```bash
   node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
   ```
2. Mettre à jour dans le secret manager.
3. **Conséquence** : tous les utilisateurs actuellement connectés seront déconnectés (JWT existants invalides). C'est le comportement attendu et acceptable post-incident.

---

## Checklist post-rotation

- [ ] Stripe (secret + webhook + publishable) roulés
- [ ] PayPal client secret regénéré
- [ ] Firebase service account key révoquée + nouvelle clé déployée
- [ ] Firebase Web API key régénérée et restreinte (ou restrictions ajoutées)
- [ ] MongoDB password rotaté + IP whitelist activée
- [ ] Cloudinary API key rotatée
- [ ] SMTP app password révoqué + nouveau
- [ ] JWT_SECRET régénéré
- [ ] ADMIN_SECRET temporairement rotaté (supprimé définitivement à sprint1/step4)
- [ ] Tous les secrets migrés vers le secret manager (plus jamais dans `.env` committé)
- [ ] Le fichier `backend/.env` local est ignoré par git (vérifié via `git check-ignore backend/.env`)
- [ ] Rebuild + redeploy du backend
- [ ] Rebuild + redeploy du frontend (clés publiques)
- [ ] Smoke test : login, booking, paiement Stripe, webhook Stripe, notification FCM, email de vérification
