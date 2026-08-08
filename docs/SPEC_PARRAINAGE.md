# 🎁 Spec — Programme de parrainage HoPetSit (proposé le 09/08/2026)

> Objectif : transformer chaque utilisateur en canal d'acquisition. C'est le
> canal le moins cher qui existe, et 90 % de l'infrastructure EXISTE DÉJÀ
> (codes promo + wallet + PawPoints). Décidé avec Daniel (« fait tout »,
> session Mac du 08-09/08) — à implémenter au prochain cycle app.

## Le principe (simple pour l'utilisateur)

1. Chaque utilisateur a un **code de parrainage personnel** (ex. `DANIEL42`)
   visible dans son profil, avec un bouton « Inviter un ami » (share sheet
   natif → WhatsApp/SMS, texte pré-rempli + lien hopetsit.com/download).
2. Le filleul saisit le code **à l'inscription** (champ optionnel « Code de
   parrainage ») ou dans la boutique.
3. Récompense **des deux côtés, après action qualifiante** (pas à la simple
   inscription — sinon fraude facile) :
   - Filleul : bonus de bienvenue (ex. 200 PawPoints) crédité à l'inscription.
   - Parrain : récompense (ex. 3 € wallet OU 500 PawPoints) créditée quand le
     filleul complète sa **première réservation payée** (ou 1re vérification
     d'identité payée pour un sitter/walker).

## Ce qui existe déjà (à réutiliser, PAS réinventer)

- **Codes promo** : `promoRoutes.js` + écran `promo_code_screen.dart` — la
  saisie/validation de codes existe de bout en bout.
- **Wallet** : `walletService.js` (`creditWallet`, idempotence par référence).
- **PawPoints** : système de points + récompenses côté PawSpot/PawMap.
- **Partage natif** : `share_plus` déjà dans le pubspec (partage de profil
  prestataire v530).

## Ce qu'il faut construire

### Backend (déployable sans rebuild — étape 1)
- `Referral` model : `{ code, ownerUserId, ownerRole, uses: [{userId, role,
  signedUpAt, qualifiedAt, rewardPaidAt}] }`.
- Génération du code au premier GET `/referral/me` (slug depuis le prénom + 2
  chiffres, collision → retry).
- `POST /referral/redeem` (auth, filleul) : valide le code, anti-fraude
  (self-referral interdit — même email/device/IP à vérifier, 1 code max par
  compte, code saisi ≤ 7 jours après inscription).
- Hook dans la confirmation de réservation payée (là où la commission est
  calculée) : si le payeur a un parrainage `pending` → créditer le parrain
  (wallet, idempotent `referral_<id>`), marquer `rewardPaidAt`, notifier les
  deux (types de notif existants).
- Dashboard admin : bloc « Parrainages » (total, en attente, payés, top
  parrains) dans l'onglet Mes revenus.

### App (prochain build — étape 2)
- Profil : carte « 🎁 Parraine tes amis » → code + bouton partage (share_plus,
  texte i18n 6 langues).
- Inscription : champ optionnel « Code de parrainage » (3 rôles).
- Écran récap : « X amis invités · Y récompenses gagnées ».

## Montants — DÉCISION DANIEL (09/08/2026) : version 100 % PawPoints, 0 € de cash
| Qui | Quoi | Quand |
|---|---|---|
| Filleul | 200 PawPoints | À l'inscription avec code |
| Parrain | 500 PawPoints | 1re réservation payée du filleul |

(Aucune récompense en euros/wallet — coût monétaire nul pour HoPetSit.
Implémentation reportée à plus tard, à la demande de Daniel.)

Coût d'acquisition résultant : ~3 € par utilisateur ACTIF (vs 1,18 €/install
non qualifié en pub payante — mais ici l'utilisateur a déjà réservé, donc la
comparaison réelle est très favorable).

## Anti-fraude minimum (v1)
- Self-referral bloqué (email normalisé + deviceId).
- Récompense parrain UNIQUEMENT après paiement réel (pas à l'install).
- Cap : 20 filleuls récompensés / parrain / mois.
- Tout passe par le wallet (traçable, révocable par ajustement).
