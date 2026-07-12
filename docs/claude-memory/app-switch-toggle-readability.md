---
name: app-switch-toggle-readability
description: "Tous les toggles on/off de l'app passent par AppSwitch partagé (sauf bannière live PawMap)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v441 — Daniel : « les boutons on/off full orange, on distingue pas l'état ». Le `Switch` Material avec seulement `activeTrackColor: accent` rendait une pastille pleine sans pouce visible.

Fix : widget partagé `frontend/lib/widgets/app_switch.dart` `AppSwitch(value, onChanged, accent)` — OFF = piste grise + pouce blanc, ON = piste accent + pouce blanc (contraste fort), contour léger. Drop-in pour `Switch(...)`.

Remplacé partout : profile_settings_tabs (préférences ×1 + 2FA), signup_wizard, petsitter_onboarding, publish_reservation_request, paw_map (helper `_buildToggle`), friends_screen.

**Exception volontaire** : le toggle « blanc sur vert » de la bannière live PawMap (`paw_map_screen.dart` ~3630, `activeTrackColor: Colors.white` + thumb vert) est laissé tel quel — c'est un design dédié déjà lisible sur fond vert ; le convertir mettrait une piste verte sur bannière verte = invisible.

**How to apply** : nouveau toggle → utiliser AppSwitch, jamais `Switch` brut.
