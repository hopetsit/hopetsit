---
name: multirole-login-precedence-gotcha
description: "Email multi-rôles se connecte TOUJOURS owner>sitter>walker (findAccountByEmail ordre fixe) ; fix v425 login honore un `role` préféré + edit animal hauteur obligatoire"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

v425 — Daniel : « j'ai créé promeneur, ça m'a ouvert sitter ».

CAUSE : `backend/src/controllers/authController.js` `findAccountByEmail()` cherche le compte par email dans l'ordre FIXE **Owner → Sitter → Walker** et renvoie le PREMIER trouvé. `login()` l'utilisait tel quel → un email qui a DÉJÀ un compte sitter et s'inscrit ensuite promeneur se reconnecte toujours en **sitter** (priorité). Le JWT est signé avec ce rôle → l'app ouvre l'interface sitter. (Daniel teste tout avec dadaciao84@gmail.com, donc multi-rôles.)

FIX v425 (4 couches) :
- backend `login` accepte un `role` optionnel dans le body : si fourni + compte existe pour CE rôle → connexion dessus (sinon fallback ordre fixe). Inchangé pour un login normal sans `role`.
- `auth_repository.login({role})` ajoute `role` au body si non vide.
- `AuthController.login({preferredRole, skipFormValidation})` passe le rôle ; `skipFormValidation` car le formulaire de login n'est pas monté pendant l'auto-login post-inscription.
- `otp_verification_controller._retryLoginAfterVerification` mappe `userType` (pet_walker/pet_sitter/pet_owner → walker/sitter/owner) et le passe à login. Routage par rôle ensuite : owner→BottomNavWrapper, sitter→SitterNavWrapper, walker→WalkerNavWrapper. Voir [[walker-signup-acceptedpettypes-crash]].

MÊME build, bug séparé « Mes animaux pas modifier » : `edit_pet_controller.validateAndUpdateProfile` rendait la **hauteur OBLIGATOIRE** (« hauteur requise » → return false) alors que le wizard de création ne la collecte pas → éditer un animal sans hauteur = impossible. Fix : hauteur optionnelle (validée >0 seulement si renseignée). Le validator du champ passait déjà à vide ; c'était la vérif explicite du contrôleur le bloqueur.
