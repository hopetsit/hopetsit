# 🚪 Spec — Onboarding ouvert (« guest mode ») — PRIORITÉ N°1

> **Contexte (15/08/2026, décision Daniel)** : la pub livre des installs à
> 1,05 € (425 installs / 30 j) mais **~2 % seulement créent un compte**
> (9 inscriptions, tests inclus). La norme du secteur est 25-40 %. Réparer
> cet entonnoir est LE levier n°1 — ×10 de résultats à budget publicitaire
> constant. La pub Paris est réduite à 5 €/j en attendant ce chantier.

## Le principe (une phrase)

**On montre la valeur AVANT de demander un compte** : à l'ouverture, l'app
s'explore librement (carte, profils, prix) ; l'inscription n'est demandée
qu'au moment où l'utilisateur veut AGIR (contacter, réserver, publier).

## P0 — À vérifier d'abord (PC/équipe, 10 min)

Documenter le parcours actuel de première ouverture : sur quel écran
atterrit un nouvel utilisateur ? Y a-t-il un mur login/signup avant tout
contenu ? Combien d'écrans/étapes jusqu'au compte créé (rôle, OTP email,
date de naissance, etc.) ? → Coller des captures dans ce dossier.
Hypothèse à confirmer : mur d'inscription immédiat + tunnel trop long.

## P1 — Guest mode (le gros du gain)

1. **Ouverture → contenu, pas login.** Un nouvel utilisateur arrive sur la
   découverte : PawMap + liste des sitters/walkers proches (lecture seule),
   SANS compte. Réutiliser les écrans existants en mode non authentifié
   (endpoints publics en lecture : profils publics, spots PawMap — vérifier
   ce que le backend expose déjà au site web public, qui sait déjà le faire).
2. **Le mur devient contextuel.** Boutons « Contacter », « Réserver »,
   « Publier », « Taguer un spot » → bottom-sheet d'inscription : « Crée ton
   compte pour contacter Marie » (l'intention est déjà là, la conversion est
   ×5 à ce moment).
3. **Onboarding d'accueil : 3 écrans max**, optionnels (skippable), qui
   montrent la promesse (sitters vérifiés / GPS live / paiement sécurisé).

## P2 — Inscription 30 secondes

- **Un seul écran** : Google / Apple / email+mdp. PAS de choix de rôle
  bloquant : rôle « propriétaire » par défaut, modifiable ensuite (« Tu veux
  proposer tes services ? » → bascule sitter/walker dans le profil).
- **OTP email : non bloquant.** Compte utilisable immédiatement ; la
  vérification e-mail est exigée seulement pour réserver/être payé
  (bannière de rappel douce).
- **Date de naissance (18+)** : conservée (exigence stores/legal) mais SEULE
  question supplémentaire de l'écran — tout le reste (photo, bio, adresse,
  animaux) se remplit APRÈS, au fil de l'usage.

## P3 — Instrumentation (mesurer, sinon on pilote à l'aveugle)

Ajouter dans `firebase_analytics_service.dart` (pattern logSignUp existant) :
- `onboarding_view` (par écran), `guest_browse` (1er écran découverte),
  `signup_wall_shown` {trigger: contact|booking|publish|spot},
  `signup_start`, `signup_abandon` {step}, et le `sign_up` existant.
KPI hebdo (GA4) : **sign_up / first_open** — objectif ≥ 25 % (aujourd'hui ~2 %).

## Garde-fous

- Ne rien casser pour les comptes existants (le guest mode ne concerne que
  les non-connectés).
- Modération/anti-scraping : les endpoints publics en lecture limitent les
  champs (pas d'email/téléphone), rate-limités.
- Respecter la règle GetX (pas d'Obx→Builder) et le trio de version.

## Phasage proposé

| Phase | Contenu | Impact attendu |
|---|---|---|
| P0 | Audit du parcours actuel (captures) | — |
| P1 | Guest mode + mur contextuel | 2 % → 15-25 % |
| P2 | Inscription 1 écran + OTP différé | +5-10 pts |
| P3 | Événements funnel | pilotage data |

Une fois P1-P2 livrés dans un build : on remonte la pub Paris et on mesure
le nouveau taux réel avant de scaler. — Spec rédigée par le Claude du Mac,
sur décision de Daniel (« baisse la pub et fais la spec »).
