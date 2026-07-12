---
name: getstorage-userprofile-stale-gotcha
description: "Photo grise sur la map + profil pas à jour = GetStorage userProfile écrit SEULEMENT au login, jamais rafraîchi ; fix v424 _persistFreshProfile"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v424 — Daniel : « la photo de profil ne s'affiche pas sur la map, photo grise » ET « profil pas à jour dans les onglets ». **MÊME cause racine.**

`StorageKeys.userProfile` (GetStorage, format PLAT `{id,name,email,mobile,avatar:{url,publicId},role}`) n'était écrit qu'au **login/signup** (`auth_controller` ~l.224). `UserController.loadMyProfile()` et `ProfileController.uploadProfilePicture()` rafraîchissaient les contrôleurs en mémoire (`profile.value`, `profileImageUrl`) mais **n'écrivaient jamais** dans GetStorage. Donc le profil persistant restait figé à l'état du login.

- **Marqueur PawMap** : `paw_map_screen._buildMarkers()` lit l'avatar via `GetStorage().read(userProfile)['avatar']['url']` → vide/périmé → `FriendMarkerService._paintFallback` (cercle gris #E2E8F0 + 👤). C'est ÇA la « photo grise ».
- **Onglets profil** + autres écrans lisant GetStorage userProfile → données périmées.

FIX v424 : `ProfileController._persistFreshProfile(ProfileModel)` réécrit name/email/mobile/avatar (format `{url,publicId}` via `avatar.toJson()`) dans GetStorage userProfile, appelé à la fin de `loadMyProfile()`. Comme `uploadProfilePicture`, les éditions de profil et l'onInit appellent tous `loadMyProfile()`, un seul fix couvre tout. Durcissement bonus `FriendMarkerService` : header User-Agent navigateur (certains CDN renvoient 403 au UA Dart → bytes null → gris) + ne PAS cacher le fallback sur échec réseau transitoire (retry ×3 via bump `rev`). Voir [[live-tracking-background-gotcha]].
