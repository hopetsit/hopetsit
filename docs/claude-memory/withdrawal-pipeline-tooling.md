---
name: withdrawal-pipeline-tooling
description: "Retraits IBAN — outillage de diagnostic admin (bouton Traiter maintenant, erreurs horodatées) + gotchas Airwallex (id bénéficiaire pas à la racine, postcode obligatoire)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

Pipeline retraits wallet (débogué v378→v385, 12/06/2026) :

**Gotchas Airwallex** (createBeneficiary PERSONAL, `airwallexService.js`) :
- `beneficiary.address` est OBLIGATOIRE (street_address+city+country_code) **et le `postcode` aussi** pour l'UE — toujours envoyé, candidat validé par regex pays (ZIP_RE), repli DEFAULT_ZIP.
- La réponse 2xx de POST /beneficiaries/create peut arriver **sans `id` à la racine** — normalisé depuis `beneficiary_id` ou `beneficiary.id` (c'était le dernier maillon qui bloquait les 4 retraits pending de 3 jours).

**Outillage admin (page Paiements)** :
- Bouton **▶️ Traiter maintenant** → POST `/admin/withdrawals/process-now` : exécute processPendingWithdrawals('manual') et affiche la trace pas-à-pas par transaction + `lastSchedulerRunAt` (null = scheduler jamais passé depuis le boot). C'est L'OUTIL pour tout retrait figé — plus besoin des logs Render.
- `failureReason` horodatée `[JJ/MM HH:mm]` sur TOUS les chemins (création bénéficiaire, IBAN absent/indéchiffrable/titulaire manquant/non vérifié, échec du virement) et **effacée au succès**. Une erreur sans horodatage = fossile d'avant v383.
- Self-heal au tick : bénéficiaire recréé depuis l'IBAN chiffré si absent, et `ibanVerified` forcé à true quand Airwallex accepte l'IBAN.
- Carte « Payouts prestataires (versés) » = completed uniquement (plus le total brut qui comptait failed/held).

**Sync des statuts (v386) — il n'existe AUCUN webhook transfers Airwallex** : les statuts sont synchronisés par polling GET /transfers/{id} (retrievePayout, x-api-version 2024-09-27). Sweeps société : sync-à-la-lecture dans GET /admin/sweep-history et /company-sweeps (syncInitiatedSweeps, adminRoutes). Retraits prestataires `processing` : sync à chaque tick du scheduler (fin de processPendingWithdrawals) → completed + notif withdrawal_completed, ou failed horodaté si rejet bancaire (PAS de re-crédit auto du wallet — décision admin). Un statut « En cours/processing à vie » = symptôme que cette sync ne tourne pas.

**Pourquoi :** chaque panne précédente était invisible (chemins silencieux, erreurs périmées affichées, statuts jamais relus). **Comment l'appliquer :** si Daniel dit « retrait bloqué/pending », lui faire cliquer ▶️ Traiter maintenant et lire la trace — elle donne la cause exacte. Voir [[payment-escrow-mechanism]].
