---
name: pawpoints-rewards-system
description: "Récompenses PawPoints éditables depuis l'admin sans rebuild — app + site lisent /pawpoints/catalog"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v414/v415 — système de **récompenses PawPoints** ajouté (Daniel : "gérer les offres et récompenses depuis l'admin sans rebuild" + "PawPoints visible sur le web").

Modèles backend : `PawReward` (title, icon, cost, kind∈discount/subscription/boost/badge/goodie, valueLabel, stock, isActive, sortOrder) + `PawRewardRedemption` (qui a échangé quoi, status pending/fulfilled/cancelled).

Routes :
- **Public** `GET /pawpoints/catalog` → récompenses actives + earnRules (miroir de pawPointsService.POINTS) + badges. **L'app ET le site lisent ça** → modifier une récompense dans l'admin est visible INSTANTANÉMENT, sans rebuild.
- `GET /pawpoints/me` (role-agnostic, auth) → points + badge + nextBadge.
- `POST /pawpoints/redeem/:id` → débit ATOMIQUE conditionné au solde (`findOneAndUpdate({pawPoints:{$gte:cost}})`).
- Admin CRUD : `/admin/pawpoints/rewards` (GET/POST/PUT/DELETE) + `/admin/pawpoints/redemptions` (GET + PUT status). Onglet PawPoints admin = classement (déjà là) + table récompenses + échanges.

UI : app = bouton "🎁 Voir les récompenses" dans l'en-tête doré de `pawspot_leaderboard_screen.dart` → `_RewardsSheet` (bottom sheet). Site = nouvelle page `/pawpoints` (NavCard dashboard). Accent doré E8A00A partout. Voir [[pawspot-community-redesign]].

**v416/v417 — refonte niveaux + récompenses abo (design Daniel)** :
- **2 compteurs** : `pawPoints` (à vie = NIVEAU, ne baisse jamais) + `pawPointsSpendable` (dépensable, baisse à l'échange ; backfill paresseux = pawPoints pour les anciens comptes). Schémas Owner/Sitter/Walker.
- **7 niveaux** (pawPointsService.LEVELS) : Explorateur 1k, Contributeur 5k, Expert 10k (+5% bonus), Ambassadeur 20k (+10%), PawMaster 50k, Légendaire 200k, Paw Legend 1M (+15%). `awardPoints` applique le bonus % du niveau À VIE.
- **6 récompenses abo** (pawPointsService.SUBSCRIPTION_REWARDS, ids `sub_*`) : 20k -10% (PawFollow/PawSpot), 50k -25% (Premium), 100k -50% (Premium), 200k 1 mois gratuit PawFollow/PawSpot, 500k 1 mois Premium, 1M 3 mois Premium. **Auto-appliquées, 1×/user** (garde `rewardKey` dans PawRewardRedemption) : mois gratuit → `subscriptionGrantService.grantFreePeriod` (crédit immédiat, remboursement si échec) ; réduction → reste `pending`, consommée au prochain `/subscriptions/subscribe` OU `/pawspots/subscribe` (sentinelle `pawspot` dans snapshot.plans).
- `GET /pawpoints/catalog` (levels+earnRules+subscriptionRewards+rewards admin) ; `GET /pawpoints/me` (lifetime, spendable, level, nextLevel, bonusPct, contributions=nb signalements, spotsLiked=likes, claimedRewardKeys). `redeemPawReward(id, plan?)` gère sub_* et ObjectId admin.
- Site `/pawpoints` refait (stats, barre niveau, récompenses, timeline 7 niveaux, objectif Paw Legend) + lien dans la boutique + encart PawPoints sous PawSpot sur `/pawmap`. App `_RewardsSheet` refait pareil (i18n ×6, clés `pawpoints_*`).
- Admin pages de droite : libellés EN traduits en FR (Name→Nom, Amount→Montant, Status→Statut, Owner→Propriétaire, Sitter→Pet-sitter, Role→Rôle, Payment→Paiement, Edit/Delete).
