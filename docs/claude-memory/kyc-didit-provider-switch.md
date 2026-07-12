---
name: kyc-didit-provider-switch
description: "KYC — Didit remplace Persona par simple bascule d'env vars (v510), app inchangée ; WebView app se ferme sur URL contenant « complete »"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**v510 (07/07/2026)** : la vérification d'identité (KYC sitters/walkers, 3 € Airwallex/wallet) passe de **Persona à Didit** SANS rebuild de l'app.

- **Bascule automatique** : `kycController._useDidit()` = présence de `DIDIT_API_KEY` + `DIDIT_WORKFLOW_ID` sur Render → Didit ; sinon Persona continue (fallback intact). Autres env vars : `DIDIT_WEBHOOK_SECRET`, `DIDIT_CALLBACK_URL` (défaut `https://hopetsit.com/kyc-complete`).
- **Pourquoi ça marche sans rebuild** : l'app appelle `POST /kyc/start` et ouvre `oneTimeLink` dans une WebView — le format de réponse `{ inquiryId, oneTimeLink, kycStatus }` est conservé, seule l'URL change (session Didit v3).
- **⚠️ Contrainte WebView app** (`kyc_verification_screen.dart`) : elle se ferme sur toute navigation dont l'URL contient `complete`, `cancelled` ou `failed` → le callback Didit DOIT contenir « complete » (page `website /kyc-complete`, créée v510).
- **API Didit v3** : `POST https://verification.didit.me/v3/session/` (header `x-api-key`, body `workflow_id`+`vendor_data`+`callback`) → `{ session_id, url }` ; `GET /v3/session/{id}/decision/` ; webhook `X-Signature` = HMAC-SHA256 des bytes bruts + `X-Timestamp` (±5 min). `vendor_data = role_userId` (même convention que le reference-id Persona).
- **Mapping statuts** (`diditService.mapStatus`) : Approved→verified ; Declined/Expired/Kyc Expired→rejected ; In Review/In Progress/Abandoned/etc.→pending (pas de changement). Le webhook ne rétrograde JAMAIS un compte `verified`.
- **kycApplicantId** réutilisé pour l'id de session Didit ; les vieux ids Persona (`inq_...`) sont détectés et ignorés.
- Filet de sécurité : poll Didit dans `GET /kyc/status` (throttle 30 s) si le webhook rate — même pattern que Persona.
- **Restes cosmétiques** : les textes de l'app disent encore « Persona » (`kyc_launch_persona_btn`…) → à renommer « Didit » ou neutre au prochain build. L'admin garde le badge « Persona » sur les vérifs historiques.
- Webhook à configurer côté Daniel dans la console Didit : `https://hopetsit-backend.onrender.com/webhooks/didit`.
