---
name: site-parity-and-promo-v402
description: "Chantiers v402/v403 — parité site web (vérif email, switch rôle, annonces, messagerie) + système de codes promo (admin prêt, redemption app à venir)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Deux gros chantiers livrés (juin 2026), **règle absolue : zéro impact app / pas de rebuild app**. Tout est additif (site-only ou backend additif).

**Chantier 1 — Site = parité app (100% website/, endpoints backend déjà existants) :**
- Vérif email web : page `/verify-email` (code 6 chiffres) → `POST /auth/verify?email=X {code}` renvoie le JWT ; `/auth/resend-code`. Le signup web redirige vers /verify-email ; le login 403 (non vérifié) aussi.
- Changer de rôle : cadre orange du dashboard → `POST /users/switch-role {targetRole}`. Le backend **migre déjà les abos** (premium/pawfollow/family/pawspot, max des compteurs) + renvoie un nouveau token (persité). Détruit l'ancien doc rôle (même comportement que l'app).
- Annonces : owner publie via `/posts/create` (`POST /posts`) + « Mes annonces » (`/posts/my`, delete) ; walker/sitter voient `/posts` (`GET /posts/requests`, filtré par rôle backend : walker=dog_walking only, sitter=exclut dog_walking) + Contacter (`/conversations/start-by-sitter|walker?ownerId=`) → `/chat?c=<id>` (deep-link ajouté). Chat soumis au **même gate 402** (booking payé OU Premium/Chat add-on) → upsell.
- serviceTypes canoniques : `house_sitting`, `day_care`, `dog_walking`.
- Profil `/profile` : chips jours-restants par abo (getSubscriptionStatus → premiumExpiry/familyExpiry/pawspotExpiry/currentPeriodEnd).
- Footer : Instagram/TikTok/YouTube/Facebook + JSON-LD `sameAs` (layout.tsx). Favicon : Google ignore le SVG → j'ai rasterisé le logo en `favicon.ico` + PNG (public/) via Edge headless + PIL ; metadata.icons pointe le .ico.

**Chantier 2 — Codes promo (v403). ADMIN PRÊT, redemption app PLUS TARD (rebuild après vidéo) :**
- Modèles `PromoCode` + `PromoCodeRedemption` (nouvelles collections). rewardType: free_subscription | percent_discount ; plan: monthly/yearly/family/family_yearly/premium_monthly/premium_yearly/pawspot/pawboost(+boostTier) ; maxUses (0=illimité).
- Admin (`/admin/promo/generate|list|revoke|send-campaign`) + onglet 🎟️ Promotions dans admin_dashboard.html (générer codes, tableau, campagne email avec liste clients cochable).
- `/promo/check` + `/promo/redeem` (requireAuth) existent — **l'app ne les appelle PAS encore**. Le grant réplique la logique de timers de `purchaseActivationController.activateSubscriptionFromWebhook` SANS toucher le webhook de paiement.
- Email campagne : `emailService.sendCampaignEmail` — envoi depuis l'adresse de marque (SPF/DKIM OK), **Reply-To = adresse choisie par Daniel** (décision : pas d'expéditeur arbitraire = anti-spam). sendEmail accepte désormais `opts.replyTo`.
**À FAIRE ensemble dans la SESSION PRÉ-VIDÉO (Daniel rebuild l'app avant la vidéo du vidéaste — on attend ce moment, NE PAS construire avant) :**
1. **App — onglet « Offre / code promo »** dans le profil owner/sitter/walker → champ code → `POST /promo/redeem` → l'abo s'active (backend déjà prêt).
2. **Site — « Postuler à l'annonce » complet (parité app)** : bouton Postuler côté prestataire sur une annonce request (le formulaire `POST /applications` veut serviceType `home_visit|dog_walking|overnight_stay|long_stay` + durée + dates + prix dérivé ; ⚠️ mapping à clarifier depuis les serviceTypes du post `house_sitting|day_care|dog_walking`) → owner voit les candidatures (`GET /applications`) → accepte (`POST /applications/:id/respond`) → booking → owner paie. Aujourd'hui le site n'a que « Contacter » (chat) + la réservation directe owner→prestataire (/search→/book→/pay).

Voir [[chat-badge-three-sources]] (badge chat) et [[git-deploy-remote-gotcha]] (push origin).
