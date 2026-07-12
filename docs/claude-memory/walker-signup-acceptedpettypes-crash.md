---
name: walker-signup-acceptedpettypes-crash
description: "L'inscription PROMENEUR plantait — Walker.acceptedPetTypes avait un enum strict incompatible avec les clés du wizard"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v417/v418 — Daniel : capture "Échec de l'inscription [ValidationError] Validation failed on: acceptedPetTypes.0. Walker validation failed". L'inscription **promeneur** était **impossible** (crash au step 5 "Créer mon profil").

CAUSE : `backend/src/models/Walker.js` `acceptedPetTypes` avait `enum: ['dog_small','dog_medium','dog_large','cat','other']`. Or le wizard (`signup_wizard_screen.dart` `_stepProviderLocation`, options walker) envoie les **clés de catégorie** `['dog','cat','small','nac']` → `dog` (index 0) hors enum → validation Mongoose échoue. `Sitter.acceptedPetTypes` n'a PAS d'enum (`[{type:String}]`) → c'est pourquoi sitter passait et walker non.

FIX : retiré l'enum de Walker.acceptedPetTypes (chaînes libres, default `['dog']`). **Deploy-only** → débloque l'app déjà installée sans rebuild.

Leçon : tout champ enum côté modèle DOIT matcher EXACTEMENT les valeurs envoyées par le wizard Flutter ; vérifier les deux côtés ensemble. Autres correctifs même build : langues d'inscription 3→6 (était `['English','Urdu','French']`, défaut 'Français') + aperçu step 5 enrichi (services+tarifs). Voir [[refonte-app-v413-build]].

**v422 — bug ÉNORME du circuit d'inscription** : après « Créer mon compte » (sitter/walker), une page OWNER (garderie/promenades + ajouter animal) réapparaissait, perdait le bleu et basculait l'user en propriétaire. CAUSE : `otp_verification_controller.handleVerificationWithNavigation` routait TOUS les inscrits vers `ChooseServiceScreen` (ancien onboarding owner), redondant avec le wizard 5 étapes qui collecte déjà tout. FIX : `handleWizardSignUp` (sign_up_controller) pré-remplit `AuthController.emailController/passwordController` (le wizard a ses propres champs) ; l'OTP signup appelle ensuite `_retryLoginAfterVerification()` (auto-login + route par rôle : owner→BottomNavWrapper, sitter→SitterNavWrapper, walker→WalkerNavWrapper). Plus de ChooseServiceScreen. La photo de profil en attente s'upload toujours dans `verifyCode()` (token /auth/verify). ⚠️ `ChooseServiceScreen` est désormais MORT pour l'inscription — ne pas le re-câbler.
