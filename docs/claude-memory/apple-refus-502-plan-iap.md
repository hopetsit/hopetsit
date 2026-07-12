---
name: apple-refus-502-plan-iap
description: "Refus Apple build 502 (2.1(b) modèle éco + 2.1(a) comptes démo sitter/walker) ; DÉCISION Daniel : abonnements AFFICHÉS et vendus sur iOS → chantier Apple IAP (StoreKit) ; PDF plan complet dans Downloads"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**06/07/2026 — Apple refuse le build iOS 502** (Submission adbddfb4-3f01-40a3-bf72-c2923e11e41e, iPad Air M3) : (1) **2.1(b)** questions sur le modèle éco — cause réelle = boutique d'abonnements payée par carte Airwallex dans l'app iOS (viole 3.1.1) ; (2) **2.1(a)** comptes démo **pet sitter + dog walker** manquants dans App Review Information.

**DÉCISION Daniel : « je veux que les abonnements s'affichent »** → PAS de masquage boutique iOS ; il faut le **paiement intégré Apple (IAP)**. Plan complet dans `Downloads/HoPetSit_Plan_Apple_IAP_v503.pdf` :
- **A (Daniel, App Store Connect)** : Small Business Program (15 %) + groupe d'abos « HoPetSit » avec Product IDs `hopetsit_pawfollow_monthly/_yearly` (4,99/49,99), `hopetsit_pawfamily_*` (9,99/69,99), `hopetsit_pawspot_*` (4,99/39,99), `hopetsit_pawpremium_*` (7,99/59,99) + consommables `hopetsit_pawboost_t1/t2/t3` (3,99/9,99/19,99) + clé App Store Server API (.p8 + KeyID + IssuerID → env Render APPLE_IAP_*).
- **B (backend, faisable depuis le PC)** : `appleIapRoutes` — POST /apple-iap/validate (requireAuth, vérifie la transaction via App Store Server API, map productId→plan, crédite UserSubscription comme purchaseActivationController/Airwallex, idempotent transactionId, provider 'apple_iap') + POST /webhooks/apple-iap (Server Notifications V2, renouvellements/remboursements).
- **C (Mac, Flutter)** : package `in_app_purchase`, `apple_iap_service.dart` (queryProductDetails, buy, purchaseStream→validate backend, restorePurchases OBLIGATOIRE), coin_shop_screen : si `Platform.isIOS` achat via StoreKit + prix localisés Apple + bouton « Restaurer mes achats » ; Android/web = Airwallex INCHANGÉ ; réservations par carte inchangées (3.1.5(a) service réel). Capability In-App Purchase dans Xcode. Build 503.
- **D** : réponse aux 6 questions d'Apple (texte EN prêt dans le PDF).
- **E** : comptes démo email+mdp demo.sitter@ + demo.walker@ dans App Review Information (+ note « Switch to » 3 rôles).

**Why:** 3.1.1 = digital dans l'app iOS → IAP obligatoire ; seules exceptions utilisées : réservations + vérif identité 3 € (services réels hors app, 3.1.5(a)).
**How to apply:** l'étape B peut être faite depuis CE PC (backend git push) dès que Daniel fournit la clé .p8/KeyID/IssuerID ; C se fait sur le Mac (bundle com.hopetsit.app, correctifs Apple Sign-In locaux à ne pas écraser). Lié : [[apple-signin-fix-and-demo-account]], [[chat-gate-payment-required-v500]].
