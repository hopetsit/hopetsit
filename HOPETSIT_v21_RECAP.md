# HoPetSit v21.0.0+42 — Récap de session

**Date** : 25 avril 2026
**Build** : 21.0.0+42
**Auteur** : Daniel Cardelli — CARDELLI HERMANOS LIMITED (HK CR 2671528)

---

## 🎯 Mission accomplie aujourd'hui

Migration **Stripe → Airwallex** lancée + site web **hopetsit.com** mis en ligne + grosse revue UX/i18n + multiples fixes. C'est la session la plus dense depuis le début du projet.

---

## ✅ Site web hopetsit.com — LIVE

- **DNS** : Wix → Vercel (A + CNAME) ✅
- **HTTPS** : Let's Encrypt auto ✅
- **6 langues** : EN/FR/ES/DE/IT/PT ✅
- **Logo officiel** orange (mascotte avec pattes colorées) ✅
- **APK Android** téléchargeable directement (`/HoPetSit.apk`, 93MB) ✅
- **Login email/password + Google Sign-In** ✅
- **Persistance auth** : avatar coloré + nom dans le header après login ✅
- **Pages légales** : Terms, Privacy, Refund, Imprint (avec CARDELLI HERMANOS LIMITED) ✅
- **Footer + Contact + FAQ + PawMap + Pricing** ✅
- **Formulaire contact opérationnel** : envoie via Resend → contact@hopetsit.com ✅
- **PayPal totalement viré** : 15 mentions effacées sur le site ✅
- **Bridge `/pay`** pour Airwallex Hosted Payment Page (webview app) ✅

---

## ✅ Airwallex — Configuré et opérationnel

- **Compte CARDELLI HERMANOS LIMITED en LIVE** ✅
- **Compliance reviewed** ✅
- **Wallet multi-devises** : EUR / CNY / GBP / HKD ✅
- **IBAN société** : DK 8900-0023663745 ✅
- **Carte corporate Visa** émise ✅
- **9 modes de paiement actifs** : Visa, Mastercard, American Express, JCB, Diners Club, Klarna, Apple Pay, Google Pay, Virement bancaire ✅
- **API key Live** générée et installée sur Render ✅
- **Bridge web `/pay` + `/pay/done`** sur hopetsit.com (Hosted Payment Page) ✅

---

## ✅ Backend Render — Migration dual-provider

5 endpoints migrés avec **switch via env var `PAYMENT_PROVIDER`** (stripe par défaut, airwallex si défini) :

| Endpoint | Stripe | Airwallex |
|---|---|---|
| `/donations/create-intent` | ✅ | ✅ TESTÉ LIVE |
| `/boost/...` | ✅ | ✅ |
| `/subscriptions/subscribe` (Premium) | ✅ | ✅ |
| `/map-boost/...` | ✅ | ✅ |
| `/chat-addon/...` | ✅ | ✅ |
| `/bookings/...` (réservation marketplace) | ✅ | ⏳ v21.1 (Beneficiaries + Payouts) |

Le test live de la **donation 2 €** via Airwallex a réussi (transaction visible sur Activité de paiement, "Cardelli Hermanos" sur le relevé bancaire).

### Code ajouté
- `backend/src/services/airwallexService.js` — 11 méthodes (auth + PI + refund + customer + webhook)
- `backend/src/scripts/testAirwallexAuth.js` — script de sanity test
- `.env.example` — doc des nouvelles vars Airwallex

---

## ✅ App mobile Flutter v21.0.0+42

### Nettoyage Stripe / PayPal (244 strings cleaned across 6 langues)
- 🇬🇧 EN : 44 strings + 5 nouvelles clés payment_chat
- 🇫🇷 FR : 41 strings + apostrophe fix `l'identité`
- 🇪🇸 ES : 35 strings
- 🇩🇪 DE : 39 strings
- 🇮🇹 IT : 40 strings
- 🇵🇹 PT : 45 strings

Plus aucune mention "Stripe" ou "PayPal" visible côté utilisateur.

### "Gérer mes paiements" walker/sitter — refonte
- ❌ Vire "Compte de paiement" (Stripe Connect)
- ❌ Vire "PayPal"
- ✅ Garde IBAN / Carte CB / Historique / Donation
- ✅ Quick status row simplifié : Carte + IBAN

### Auto-open chat après paiement (BUG FIX critique)
- Backend OK déjà (webhook crée la conversation auto)
- **Frontend FIXÉ** : `payment_result_screen.dart` ouvre maintenant le chat avec sitter/walker dès le paiement réussi
- Bouton primary devient "Discuter avec ton sitter/walker" + bouton secondary "Retour à l'accueil"

### Photo de profil signup (BUG FIX critique)
- **Bug** : la photo sélectionnée pendant l'inscription n'était jamais uploadée au serveur (rester vide en prod)
- **Fix** : SignUpController persiste le path en GetStorage, OtpVerificationController upload via `/users/me/profile-picture` une fois le token reçu après vérif OTP

### Inscription modernisée par couleur de rôle
- Header band avec gradient role-color (orange/bleu/vert)
- Hint banners spécifiques : "On te demandera ton IBAN" pour sitter/walker, "Tu pourras ajouter tes pets" pour owner
- Submit button + checkbox + spinner colorés selon le rôle
- 4 nouvelles clés i18n ajoutées dans 6 langues

### Sign-in / Login modernisé
- Greeting card avec logo
- Inputs outlined modernes (24r, focus border orange)
- Bouton Google blanc avec border subtle
- Bouton Apple noir
- "OR continue with" divider propre
- Footer "Don't have account? Sign up" (lien orange)

### PawMap modernisé
- Search bar pill-shaped (24r, shadow)
- Drag handles sur les modal sheets
- Catégories chips avec shadows
- 2 nouvelles clés i18n

### Vérifications
- ✅ Audit pricing 20% : commission owner-only confirmée partout (publication + demande directe + display)
- ✅ Audit admin dashboard : **24/24 tabs fonctionnels**, 0 endpoint cassé
- ✅ Email confirmation signup : envoyé via Nodemailer/SMTP, template HTML pro
- ✅ Logo Android + iOS à jour via `flutter_launcher_icons`

---

## 📊 Statistiques de la session

- **Durée** : 1 journée intense
- **Files modified** : ~80
- **Lines changed** : ~3500
- **Subagents lancés** : 12+
- **Bugs critiques fixés** : 8
- **Migrations majeures** : 5 controllers Stripe→Airwallex + UI mobile dual-provider
- **Tests live réussis** : 1 (donation 2 € via Airwallex)

---

## 🎯 État final

### ✅ Production-ready
- Site web hopetsit.com fully live
- Airwallex Payments Acceptance opérationnel
- Backend Render rebuild auto sur push
- App APK v21.0.0+42 prête à installer

### ⏳ Prochaines sessions (v21.1+)
- **booking marketplace flow** (Airwallex Beneficiaries + Payouts pour split sitter 80/20)
- Suppression complète du code Stripe quand v21.1 testée
- Suppression complète du code PayPal
- Profile screens harmonisation walker/sitter (similaire)
- Owner profile light modernization
- Stripe Identity → alternative KYC
- iOS build (à faire sur Mac)
- Audit final design (5 issues 🔴 / 10 🟡 / 7 🟢 identifiés)

---

## 🔐 Données sensibles à sauvegarder

À garder dans **un coffre-fort** (1Password, Bitwarden, etc.) :

- **Airwallex Client ID** : `CO3hyIr9...` (récupérable sur dashboard)
- **Airwallex API Key** : `0eacfc4c...` (sensible — régénérer si fuite)
- **Resend API Key** : `re_2dq...` (à régénérer une fois depuis première fuite)
- **Render env vars** : MONGODB_URI, JWT_SECRET, ENCRYPTION_KEY, FIREBASE_PRIVATE_KEY
- **Vercel env vars** : NEXT_PUBLIC_FIREBASE_*, RESEND_API_KEY, CONTACT_TO

---

## 📞 Contacts

- **Société** : CARDELLI HERMANOS LIMITED (HK CR 2671528)
- **Adresse légale** : Flat/Rm A, 12/F, ZJ 300, 300 Lockhart Road, Wan Chai, Hong Kong
- **Director** : Daniel Cardelli
- **Email pro** : contact@hopetsit.com (via Wix)
- **Email perso** : dadaciao84@gmail.com

---

🚀 **HoPetSit v21 est prête à être testée live !**
