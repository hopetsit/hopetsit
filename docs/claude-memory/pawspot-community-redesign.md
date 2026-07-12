---
name: pawspot-community-redesign
description: "v353 — PawSpot n'est PLUS le map boost à halos ; c'est un abonnement communautaire (spots tagués + PawPoints + badges + empreinte dorée)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Depuis v23.1.353 (11 juin 2026), **PawSpot = produit communautaire**, décision de Daniel : « les pawspot dorés (halos boost) n'ont aucun intérêt car chaque utilisateur a déjà son halo coloré ».

**Why:** l'ancien "map boost" (paliers bronze/silver/gold/platinum, halos payants sur la PawMap) est RETIRÉ de toute l'UI (app/site/admin). Le backend mapBoost (routes/champs) existe encore en legacy — ne pas le re-exposer.

**How to apply:**
- Nouveau produit : spots pet-friendly tagués sur la PawMap (6 types), PawPoints (+10 spot/+5 photo/+10 validé/+2 commentaire/+1 signalement confirmé/+25 populaire), badges 🥉100/🥈500/🥇1500/👑5000, Gold Creator ≥1000 pts → empreinte DORÉE 🐾, classements ville/pays/Europe, récompenses (feature 7j 50pts, couleur badge 100, bannière 150, cadre doré 200).
- Abonnement : 4,99 €/mois · 39,99 €/an · essai 7 j (une fois) ; gratuit = 3 spots max. Champ `UserSubscription.pawspotExpiry` (+`pawspotTrialUsedAt`, `pawspotHistory` pour l'idempotence paiement) — INDÉPENDANT de currentPeriodEnd (PawFollow) et familyExpiry (PawFamily).
- Backend : `models/PawSpot.js`, `services/pawPointsService.js`, `routes/pawSpotRoutes.js` (mount `/pawspots`), activation webhook kind `pawspot_purchase`, pricing catégorie `pawspot` (admin-éditable, PRICING_VERSION bumpé v23.1.353).
- Itinéraire « Y aller » (POIs + spots) : GET `/pawspots/directions` (proxy OSRM piéton, fallback ligne droite) — depuis v361 (décision Daniel) : PAS gratuit, inclus dans les TROIS abos PawFollow/PawFamily/**PawSpot** (gate 402 PAWFOLLOW_REQUIRED = hasTrackingSubscription OU hasActivePawSpot).
- Depuis v361 : le marqueur des spots GOLDEN = la PIÈCE DORÉE officielle (emoji fourni par Daniel — médaille or + patte + pointe-pin dans le coussinet), reproduite en canvas app (`_buildGoldenCoinBitmap`) et SVG inline site (GOLDEN_COIN_SVG dans PoiMap) ; le staff est Gold Creator d'office (ses spots sont dorés, enrichi aussi à la lecture).
- Depuis v360 : création de spot via mode VISEUR (pin central + Valider/Annuler), validation communautaire à 10 ❤️, légende des 6 types quand la couche est ON, grille 2×2 PawFollow|PawSpot / Taguer|Voir les spots.
- App : chip doré « PawSpot 🐾 » dans la barre de filtres PawMap (à côté de Rien, une ligne, gate abo → CoinShop tab 2) ; onglet boutique 3 réécrit ; accent doré = 0xFFE8A00A (remplace le bleu 3B82F6 produit).
- Canon couleurs produits depuis v354 (Daniel) : **PawFollow = VIOLET 0xFF7C3AED** (plus de doré/orange FF9500-F5A623), PawFamily = violet clair 8B5CF6, **PawSpot = DORÉ E8A00A**, Boost profil = garde ses tiers or/argent. Appliqué app + map + site (tailwind violet-600/700, amber-600).
- v354 aussi : la 2e confirmation (fin de service) ne sort sur le bandeau que 30 min avant la fin (`_serviceEndAt` app ↔ `resolveBookingEndDate` backend, heure de fin du timeSlot) + notif push/mail `service_end_soon` via processServiceEndReminders (tick payoutScheduler).
- Liens : [[payment-escrow-mechanism]] (même pattern staff bypass/wallet/Airwallex que chatAddon).
