---
name: web-profile-save-route-gotcha
description: "Le site PUT /users/me/profile tombait sur /:id/profile (id='me' → CastError 400) ; route PUT /me/profile ajoutée v414"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v414 — la sauvegarde de profil depuis le SITE était **silencieusement cassée**. `updateMyProfile` (web) fait `PUT /users/me/profile`, mais il n'existait PAS de route `PUT /me/profile` → ça tombait sur `router.put('/:id/profile', updateProfile)` avec `id='me'` → `Owner.findByIdAndUpdate('me')` → CastError → 400 "Invalid user id".

FIX (`userRoutes.js`) : ajout `router.put('/me/profile', requireAuth, (req,res,next)=>{ req.params.id=req.user.id; return updateProfile(...) })` (role-agnostic). Et `GET /me/profile` rendu role-agnostic aussi (avant `requireRole('owner')` → sitters/walkers ne pouvaient même pas CHARGER leur profil web) : `getOwnerProfile` renvoie un profil léger (sanitizeUser) pour non-owners.

`updateProfile` persiste déjà `preferences` + `twoFactorEnabled` (champs additifs v405). Section Préférences (5 toggles) + 2FA ajoutée à `/profile` du site (synchro app↔web via `updateProfile` + `syncSharedFields`). Voir [[getsitterprofile-manual-response-gotcha]] pour l'autre gotcha de réponse profil hand-built.
