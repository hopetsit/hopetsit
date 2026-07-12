---
name: refonte-app-v413-build
description: "La grande refonte app (maquettes) a été buildée en 23.1.413+413 — ce qu'elle contient + le lot web restant"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**Refonte app « à la lettre » buildée le 2026-06-15 en `23.1.413+413`** (APK 93,9 Mo + AAB 67 Mo, `flutter build` exit 0, `flutter analyze` 0 erreur). Artefacts : `frontend/build/app/outputs/{flutter-apk/app-release.apk, bundle/release/app-release.aab}`.

Contenu (Phases 1‑6) : fiche animal 4 onglets (À propos/Santé/Habitudes/Galerie) + Mes animaux badges sexe/vaccin ; profils owner/sitter/walker en onglets Profil/Préférences/Sécurité (5 toggles `preferences`, 2FA, suppression compte) ; **inscriptions = wizard 5 étapes** (`signup_wizard_screen.dart` ; l'ancien `sign_up_screen.dart` reste mais N'EST PLUS référencé — `sign_up_as` + route nommée → wizard) ; publier toggle `showAnimalCharacter` ; Postuler carte « gain estimé » (commission RÉELLE 20%/15% déduite de totalPrice−netPayout, PAS le 10% des maquettes) ; feed onglets déjà existant (CustomSegmentedControl). i18n : 187 clés pet_*/profile_*/signup_*/day_* × 6 langues ajoutées (script idempotent, voir git).

Backend déployé jusqu'à **v412** : modération robuste (phrases+blocs, [[fcm-multiprofile-token-fragmentation]] pour push+badge suivi), bandeau notif web (compact repliable + effacer/clear DELETE /notifications/my/:id|/clear + deep-link onItemClick), cadre orange site traduit, fix promo destinataires (loadPromotions recharge toujours) + payout label IBAN/Airwallex.

**LOT WEB RESTANT (demandé, pas encore fait — déployable sans build app)** : chat web → bouton « demander à suivre l'animal » (POST requestLiveTrackingByConversation) + cartes pawfollow_request accepter/refuser + « voir carte/itinéraire » (PawMap) ; photos dans le chat web ; PawFamily page d'ajout jusqu'à 5 membres (friendRoutes family/invite-member). Commission décidée : **garder 20% (15% Top)**, afficher le vrai taux.
