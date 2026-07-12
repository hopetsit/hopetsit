---
name: couronne-premium-multi-sources
description: La couronne PawPremium (isPremium) est calculée à 4+ endroits indépendants (backend + web) — tous doivent compter staff + cross-rôle ; PawSpot ≠ couronne
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**Couronne 👑 = PawPremium UNIQUEMENT** (staff OU abonnement premium actif). **PawSpot ≠ couronne** (PawSpot = anneau/halo ROSE, sans couronne). Ne pas confondre quand un compte "ne montre pas la couronne".

`isPremium` (la couronne) est calculé dans **plusieurs endroits indépendants** — un bug dans un seul fait que la couronne manque à un endroit (ex. app oui / web non) :
- **backend `friendRoutes.js`** : (1) `fetchUserMini` = liste d'amis ; (2) `GET /friends/members/nearby` = membres roses sur la carte ; (3) route live-positions/diagnose = `otherIsPremium` (amis en direct) ; (4) route family members (fallback email).
- **web `map/page.tsx`** : `premiumIds` (passé à `PoiMap` → couronne sur amis/famille) + `PoiMap.makeMemberIcon(m.isPremium)` (membres roses). L'app, elle, lit `isPremium` par ami directement.

**Bugs corrigés v500 (commits c8c3b66 + d9b6ea3, backend+web, PAS de rebuild app)** — Daniel « couronne pas affichée, nouveaux comptes app-oui/web-non, anciens comptes rien » :
- **WEB** : `premiumIds` était construit **UNIQUEMENT depuis la famille** (`allFamily`) → un **ami** premium n'avait jamais de couronne sur le web. FIX : `premiumIds` = amis (`f.other.isPremium`, déjà renvoyé par le backend) + famille. + `isPremium?` ajouté au type `FriendOther`.
- **BACKEND** : `live-positions` ne comptait QUE l'abo payant (jamais `isStaff`) ; `members/nearby` lisait `isStaff` sur le seul doc. Ajout **staff + relecture cross-rôle (email/oldId)** sur les 3 routes (comme `/me/benefits`). `fetchUserMini` corrigé juste avant.

**⚠️ Si un ANCIEN compte reste sans couronne après tout ça = problème de DONNÉES**, pas de code : ses 3 fiches rôle (Owner/Sitter/Walker) ne partagent pas le même `email`/`oldId` → la propagation staff (admin v495, updateMany $or email/oldId) ET le cross-rôle ratent les docs non liés. Diagnostic = demander l'email du compte + vérifier dans l'admin (staff ? abo actif ?) et la cohérence email des 3 rôles. Le toggle staff admin propage sur les 3 rôles via `$or:[{email},{oldId}]` ([[apple-signin-fix-and-demo-account]] = autre saga email/oldId).
