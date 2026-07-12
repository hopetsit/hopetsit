---
name: allomoteur-wix-header-langues
description: Site Wix Allomoteur.com (2e projet de Daniel) — header custom iframe
metadata: 
  node_type: memory
  type: project
  originSessionId: 62e9a225-515f-4d1e-bff6-2aaba9fd1e42
---

Daniel gère aussi **Allomoteur.com** (moteurs/boîtes d'occasion), site **Wix** avec header/footer custom en éléments « Intégrer HTML » (iframes).

Faits clés (juillet 2026) :
- **Header = élément #html10** dans l'éditeur Wix (site "Allomoteur.com", metaSiteId d0e59a79-8e71-4acd-8836-f4fda62a684e). Du code Velo page Accueil poste `cartCount` vers `#html11` (ID pas encore aligné).
- **PIÈGE : l'iframe du header fait ~113 px de haut** → tout menu déroulant qui s'ouvre SOUS la barre est coupé/incliquable. Solution appliquée : les 6 langues (Français/English/Español/Deutsch/Português/Italiano) se déploient **horizontalement DANS la barre**, à gauche du bouton FR (noms complets desktop, codes FR/EN… <900px).
- **Wix Multilingual = préfixes d'URL** `/en /es /de /pt /it` (+ `/nl /da /ga` existent aussi, non affichés à la demande de Daniel). Même slug de page dans toutes les langues.
- **Le referrer est tronqué à l'origine** dans les iframes Wix → impossible de détecter la page/langue courante ; le header mémorise la langue cliquée en `localStorage('am_lang')` (origine partagée filesusr.com).
- **Workflow d'édition automatisé** : éditeur Wix via https://www.wix.com/editor/{metaSiteId} → sélectionner l'élément → « Modifier code » → le panneau utilise **CodeMirror** (`document.querySelector('.CodeMirror').CodeMirror.setValue(...)` fonctionne, le bouton devient « Mettre à jour ») → cliquer le bouton `button[class*="html-code-input-form-but"]` → « Publier ».
- **Sync par page (v2, juil. 2026)** : `masterPage.js` envoie `{type:'pageUrl', url}` + `{type:'cartCount', count}` à `$w('#html10')` (onReady + réponse au `headerReady` du header + `wixEcomFrontend.onCartChange`) → changer de langue depuis une fiche produit garde LA MÊME fiche (slugs identiques dans les 6 langues, vérifié) et le badge panier fonctionne. Import : `wixEcomFrontend from 'wix-ecom-frontend'` (getCurrentCart/onCartChange). masterPage.js éditable via `monaco.editor.getModels()` (uri …/masterPage.js) + setValue ; vérifier `monaco.editor.getModelMarkers`. Le vieux code page Accueil qui poste vers `#html11` est un fossile inoffensif.
- **Version finale validée par Daniel (8 juil. 2026)** : desktop = 6 noms complets en ligne horizontale à GAUCHE du bouton + **ouverture au survol** (hover:hover) ; mobile = codes FR EN ES DE PT IT **SOUS le bouton alignés à droite** (l'ouverture à gauche débordait de l'écran) ; toggle sur `pointerdown` (pas `click`, qui se perdait dans l'iframe) ; fermeture seulement si appui hors du composant. Gotcha éditeur : le bouton « Mettre à jour » (`button[data-hook="html-component-submit-button"]`) n'apparaît qu'après un change d'origine `+input` dans CodeMirror, et la modale « Félicitations » post-publication bloque le panneau tant qu'on ne clique pas Terminer/X.
- Code final : scratchpad `allomoteur-header-v3.html` (aussi collé dans la conversation). Footer : badges App Store/Google Play ajoutés (liens id6455540699 / allomoteur.allomoteur.app).
- **RÈGLE Daniel** : ne rien modifier/publier sur Wix sans lui demander confirmation d'abord.
