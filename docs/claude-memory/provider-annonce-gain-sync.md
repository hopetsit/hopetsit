---
name: provider-annonce-gain-sync
description: « Votre gain estimé » prestataire = estimatePostPrice (mirror backend pricing.js) − commission 10%
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Détail annonce vu par walker (tout vert #16A34A) / sitter (tout bleu #2563EB) = `PetPostCard` en `viewerRole` (owner=orange). Grille rôle-aware : walker = Dates/Lieu/Durée/Fréquence, sitter = Dates/Lieu/Animaux/Service. Owner PAS noté → on affiche « À propos de moi » (ownerBio) au lieu des avis/étoiles.

**Gain estimé synchronisé au paiement** : `frontend/lib/utils/post_price_estimator.dart` `estimatePostPrice` est le miroir client de `backend/src/utils/pricing.js` `calculatePricingBreakdown`. La carte prend `PostPriceEstimate.brut` (= `ownerTotal` backend = ce que le client paie vraiment) puis affiche : Client paie {brut} → Commission PawMap (10%) −{0.1×brut} → Vous recevez {0.9×brut}. NE PAS recréer une 2ᵉ formule — réutiliser l'estimateur partagé. (Vérifié : 18→16,20 ; 120→108.)

Le feed prestataire (`sitter_homescreen`, partagé walker+sitter via nav wrapper ; `walker_homescreen.dart` est un placeholder mort) passe `priceEstimate`+`viewerRole`+`onSendRequest` → la carte rend le design + Postuler. `notification_post_view_screen` (post ouvert depuis une notif) affiche la carte mais SANS Postuler (flux apply non recâblé là — feed = lieu d'apply).
