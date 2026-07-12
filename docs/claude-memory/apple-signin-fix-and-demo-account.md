---
name: apple-signin-fix-and-demo-account
description: "Correctif « Sign in with Apple » (iOS, 3 causes) + RÈGLE compte démo store = email+mot de passe (OAuth n'a pas de mot de passe → refus Apple ET Google)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Session MAC du **25/06/2026** (CARDELLI HERMANOS LIMITED), résumée dans `Downloads/HoPetSit_Fix_SignInApple_Resume.pdf`. ⚠️ Ces correctifs iOS ont été faits sur le **Mac, en LOCAL non commité** (patch `HoPetSit_modifs_locales_20260625.patch` dans Downloads) → ils ne sont **PAS forcément dans le repo Windows `HopeTSIT_FINAL_FIXED` ni sur origin**. iOS se build sur Mac uniquement.

**« Sign in with Apple » plantait → refus Apple (Guideline 2.1a).** Google + email marchaient, seul Apple échouait. 3 causes empilées :
1. **Erreur 1000** : `CODE_SIGN_ENTITLEMENTS` ABSENT du projet Xcode → l'entitlement Apple (présent dans Runner.entitlements) jamais appliqué. FIX : ajouter `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` aux **3 configs** du target Runner dans `ios/Runner.xcodeproj/project.pbxproj`.
2. **invalid-credential / « Invalid OAuth response from apple.com »** : le credential Firebase n'envoyait pas l'accessToken. FIX dans `loginWithApple` (`lib/controllers/auth_controller.dart`) : `OAuthProvider('apple.com').credential(idToken:…, rawNonce:…, accessToken: appleCredential.authorizationCode)` ← LE FIX. (FlutterFire #13242). La config Firebase Console (Services ID/clé OAuth) est ignorée pour iOS natif → pas le pb.
3. **Lib obsolète** : `the_apple_sign_in` → remplacée par `sign_in_with_apple` v8 + `crypto` ; `loginWithApple` réécrit avec nonce (brut + SHA-256, exigé par firebase_auth 6.x).
Annexes : `sign_up_as.dart` boutons « Se connecter » + flèche retour réparés (Get.back sur pile vide quand on arrive via Apple/Google). Backend `friendRoutes.js` « point 3 » (couronne premium pour staff de famille) — **À DÉPLOYER sur Render** (peut-être déjà couvert par mes push v495/v497, à vérifier). iOS build **502** resoumis « In Review ».

**🔑 RÈGLE COMPTE DÉMO STORE (cause du refus Apple ET du refus Google) :** un compte créé via **Google/Apple (OAuth) n'a PAS de mot de passe** → impossible de se connecter ensuite en email+mot de passe. Daniel avait donné `dadaciao84@gmail.com` (compte Google + 2FA sur son Galaxy S22+) comme identifiant de test → le testeur Apple/Google **ne peut pas se connecter** (« Sign Up Failed » + bloqué sur la 2-Step Verification). **FIX = créer un compte démo dédié EMAIL + MOT DE PASSE** (email vérifié, sans 2FA), le tester (déconnexion/reconnexion), et le fournir dans la console store → **Play Console : Contenu de l'application → Accès à l'application** (et l'équivalent App Store Connect). Réutiliser le MÊME compte démo email+mdp pour Apple et Google.

**À surveiller (Apple règle 3.1.1)** : paiements carte Airwallex au lieu d'achat intégré Apple → risque de refus ; plan B = masquer la boutique sur iOS.

Contexte : bundle iOS/Android `com.cardellihermanos.hopetsit` ([[v498-package-rename]]) · Apple Team 49C67YDPJ5 · Firebase hopetsit (470089536255) · App Store ID 6763645719 · Render plan payant (toujours allumé).
