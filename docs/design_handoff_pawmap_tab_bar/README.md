# Handoff : Barre de navigation « PawMap » (variante 12d) + écran de lancement

## Overview
Deux livrables : (1) la barre d'onglets, (2) l'écran de lancement (splash) qui remplace la tuile-icône actuelle par la même patte-pin, animée : le coussinet apparaît, puis les 4 doigts sortent en cascade, puis le titre.

Barre d'onglets mobile (bottom tab bar) pour l'app HoPetSit. 5 destinations : Accueil, Chat, **PawMap** (action centrale), Réservations, Profil. PawMap est un bouton central surélevé en forme de **patte de chien** : un coussinet noir en forme d'épingle de carte contenant l'œil du logo, et 4 doigts aux couleurs des billes du logo qui **sortent du coussinet quand PawMap est l'onglet actif** et s'y rétractent sinon.

## About the Design Files
`PawMap Tab Bar.dc.html` est une **référence de design réalisée en HTML** (prototype montrant l'aspect et le comportement attendus), pas du code de production à copier. Le travail consiste à **recréer ce design dans l'environnement existant de l'app** (React Native, Flutter, SwiftUI, Compose…) avec ses composants et conventions. Si aucun environnement n'existe, choisir le framework le plus adapté au projet.

## Fidelity
**Hi-fi.** Couleurs, dimensions, typographie, rayons, ombres et timings sont finaux. Reproduire au pixel avec les outils du codebase (le rendu de la barre est fluide en largeur ; les mesures ci-dessous sont pour une largeur d'écran de 390 px).

## Screens / Views

### Barre de navigation
**Purpose** : navigation principale, PawMap mis en avant.

**Layout (largeur écran 390 px)**
- Conteneur barre : `position:absolute; left:16; right:16; bottom:24` (au-dessus de la safe area) ; hauteur **70** ; `border-radius:35`.
- Fond : `linear-gradient(180deg, #D83C28, #B92425)`.
- Ombres : `inset 0 1px 0 rgba(255,255,255,.3)` (liseré haut) + `0 18px 40px rgba(216,60,40,.4)`.
- Padding horizontal interne : **8**. Contenu en `flex; align-items:center`.
- Ordre des enfants : [Accueil][Chat][**slot central 84 px**][Réservations][Profil]. Les 4 onglets ont `flex:1`, le slot central est fixe (`width:84; flex:none`).

**Onglet standard** (×4)
- Bouton `height:60`, colonne centrée, `gap:4`.
- Icône : trait 23×23, `stroke-width` 1.8 (inactif) / 2.2 (actif), `stroke-linecap/linejoin: round`. Icônes : patte (Accueil), bulle avec 3 points (Chat), calendrier (Réservations), silhouette (Profil) — utiliser les icônes existantes de l'app si disponibles.
- Libellé : Manrope 800, **8.5 px**, uppercase, `white-space:nowrap`.
- Couleur : actif `#FFFFFF` ; inactif `rgba(255,255,255,.7)`. Transition `color .3s`.

**Indicateur point blanc**
- 6×6, `border-radius:3`, `#FFF`, `box-shadow:0 0 8px rgba(255,255,255,.8)`.
- `position:absolute; bottom:6` dans la barre, centré horizontalement sous l'onglet actif.
- Formule de la position (left) pour l'onglet d'index i ∈ {0,1,2,3} parmi les 4 latéraux : `8 + i*(barWidth-16-84)/4 + (i>=2 ? 84 : 0) + (barWidth-16-84)/8 - 3` px.
- Transition `left .45s cubic-bezier(.3,1.4,.4,1)`. Quand PawMap est actif : `opacity:0` (transition `.25s`).

**Slot central (84 px)** — contient uniquement l'étiquette :
- Étiquette « PawMap » : Manrope 800, **8 px**, uppercase, `letter-spacing:.06em`, `padding:4px 9px`, `border-radius:10`, alignée en bas du slot avec `padding-bottom:11` (soit ~11 px au-dessus du bord bas de la barre).
- Inactif : fond transparent, texte `rgba(255,255,255,.7)`.
- Actif : fond `#17151A`, texte `#FFF`, `box-shadow:0 4px 12px rgba(0,0,0,.35)`, `translateY(-2px)`.
- Transitions : `background/color/box-shadow .35s`, `transform .45s cubic-bezier(.3,1.5,.4,1)`.

**Bouton PawMap (patte)**
- Zone tactile : **84×84**, centrée horizontalement, `bottom:68` (mesuré depuis le bas de l'écran, soit ~44 px au-dessus du bas de la barre ; le coussinet dépasse de la barre de ~26 px).
- Actif : tout le bouton `translateY(-7px)`, transition `.45s cubic-bezier(.3,1.5,.4,1)`.
- **Coussinet (pin)** : 48×48, ancré en bas-centre de la zone. Forme épingle = carré `border-radius:50% 50% 50% 0` tourné de **−45°**. Fond `linear-gradient(135deg,#3A363F,#17151A)`. Bordure `3px solid #FFF`. Ombres `inset 0 1px 0 rgba(255,255,255,.2)` + `0 14px 30px rgba(23,21,26,.5)`. `overflow:hidden`.
- **Œil du logo** au centre du coussinet : cercle 32 px (`border-radius:16`, `overflow:hidden`, fond `#17151A`, `box-shadow:0 2px 6px rgba(0,0,0,.35)`), contre-tourné de +45°. À l'intérieur, l'icône app `HoPetSit_logo.png` affichée à **80×80** décalée de `-24px` en x et y (recadrage sur l'œil central du logo). Équivalent natif : recadrer l'image sur son centre à 40 % de sa taille.
- **4 doigts** : cercles avec `border:2.5px solid #FFF`, `box-shadow:0 4px 10px rgba(23,21,26,.4)`. Positions dans la zone 84×84 (coin haut-gauche de chaque cercle) et couleurs (`radial-gradient(circle at 35% 30%, clair, foncé)`) :

  | # | left | top | taille | clair → foncé |
  |---|------|-----|--------|---------------|
  | 1 | 4.1 | 33.9 | 13 | #FF7A66 → #D83C28 (rouge) |
  | 2 | 22.0 | 17.0 | 16 | #6FA0FF → #2F6FD6 (bleu) |
  | 3 | 46.0 | 17.0 | 16 | #7FD66F → #3FA33A (vert) |
  | 4 | 66.9 | 33.9 | 13 | #B57FE6 → #7A3FB0 (violet) |

  Géométrie : centres sur un arc de rayon **37 px** autour du centre du coussinet (42, 60), aux angles **−58°, −19°, +19°, +58°** par rapport à la verticale. Symétrie miroir parfaite ; doigts intérieurs plus grands (16) que les extérieurs (13).

### Écran de lancement (Splash)
**Purpose** : remplace la page actuelle (tuile icône + « HoPetSit » + loader) pendant le chargement.

**Layout (390×844)**
- Fond : `linear-gradient(165deg, #F26A46 0%, #DD4430 45%, #C7311F 100%)`, plein écran.
- Patte : zone **210×210**, centrée horizontalement, `top:250` (centre vertical ≈ 355 px).
  - Coussinet 120×120, ancré bas-centre, même forme épingle (`border-radius:50% 50% 50% 0`, rotation −45°), fond `linear-gradient(135deg,#3A363F,#17151A)`, bordure `6px solid #FFF`, ombre `0 30px 60px rgba(90,15,8,.5)` + `inset 0 2px 0 rgba(255,255,255,.2)`.
  - Œil : cercle 80 px, logo affiché à 200×200 décalé de −60/−60 (même recadrage 40 % que la barre).
  - Doigts (mêmes angles ±19°/±58°, rayon **92 px** autour du centre du coussinet (105,150)), bordure `5px solid #FFF`, ombre `0 10px 24px rgba(120,20,10,.35)` :

    | # | left | top | taille | couleur |
    |---|------|-----|--------|---------|
    | 1 | 10 | 84.2 | 34 | rouge #FF7A66→#D83C28 |
    | 2 | 55 | 43 | 40 | bleu #6FA0FF→#2F6FD6 |
    | 3 | 115 | 43 | 40 | vert #7FD66F→#3FA33A |
    | 4 | 166 | 84.2 | 34 | violet #B57FE6→#7A3FB0 |

- Titre « HoPetSit » : Manrope 800, **44 px**, `letter-spacing:-.02em`, `#FFF`, `top:500`.
- Sous-titre « Home Pets Sitting » : Manrope 500, **17 px**, `letter-spacing:.06em`, `rgba(255,255,255,.8)`, 10 px sous le titre.
- Loader : anneau 34 px, bordure 3 px `rgba(255,255,255,.3)` avec segment haut `#FFF`, `bottom:110`, rotation `.9s linear infinite`.

**Séquence d'animation (t = 0 à l'affichage)**
1. **0 → 0.7 s** — coussinet : `scale(.5) → 1`, `opacity 0 → 1`, easing `cubic-bezier(.3,1.5,.4,1)`.
2. **Doigts** : chacun part du centre du coussinet (`translate(cx−x, cy−y) scale(.25)`, opacity 0) vers sa position (`translate(0) scale(1)`, opacity 1), durée .65 s, même easing, délais **0.55 / 0.65 / 0.75 / 0.85 s** (doigt 1→4). Transforms de départ : 1 `translate(78px,48.8px)`, 2 `translate(30px,87px)`, 3 `translate(−30px,87px)`, 4 `translate(−78px,48.8px)`.
3. **1.1 s** — titre + sous-titre : `translateY(14px) → 0`, opacity 0 → 1, .6 s ease-out.
4. **1.5 s** — loader apparaît (même fade-up, .5 s).
5. **À partir de 1.6 s** — la patte entière flotte : `translateY(0 → −8px → 0)`, 3.2 s ease-in-out, en boucle, jusqu'à la fin du chargement.

Transition vers l'app : fondu de sortie court (~.3 s) recommandé ; la patte du splash et le bouton PawMap de la barre partagent la même forme, un morphing (shared element) est possible si le framework le permet.

## Interactions & Behavior
- Tap sur un onglet latéral → devient actif : couleur blanche, trait 2.2, point blanc glisse sous lui (`.45s cubic-bezier(.3,1.4,.4,1)`). PawMap repasse inactif : la patte redescend, l'étiquette redevient transparente, les doigts se **rétractent** dans le coussinet.
- Tap sur la patte → PawMap actif : point blanc disparaît (`opacity 0`, .25s), étiquette noire apparaît, la patte monte de 7 px, les doigts **sortent** avec un délai en cascade.
- **Doigts — état rétracté (PawMap inactif)** : `opacity:0` + transform vers le centre du coussinet et `scale(.25)` :
  - 1 : `translate(31.4px,19.6px) scale(.25)`
  - 2 : `translate(12px,35px) scale(.25)`
  - 3 : `translate(-12px,35px) scale(.25)`
  - 4 : `translate(-31.4px,19.6px) scale(.25)`
- **Doigts — état sorti (PawMap actif)** : `opacity:1` + léger déplacement radial de 4 px :
  - 1 : `translate(-3.4px,-2.1px)` · 2 : `translate(-1.3px,-3.8px)` · 3 : `translate(1.3px,-3.8px)` · 4 : `translate(3.4px,-2.1px)`
- Transition des doigts : `transform .5s cubic-bezier(.3,1.5,.4,1)` avec délai **0 / 40 / 80 / 120 ms** (doigt 1→4), `opacity .3s`.
- Aucun hover (mobile). Prévoir un feedback d'appui natif léger (scale .96) si le framework le propose.
- Safe area : la barre est à 24 px du bas sur un écran sans encoche ; sur iOS ajouter la safe-area inset au `bottom`.

## State Management
- `activeTab: 0 | 1 | 2 | 3 | 4` (2 = PawMap). Défaut selon l'écran courant.
- Dérivés : `isPawMapActive = activeTab === 2` pilote : opacité du point, style de l'étiquette, translation de la patte, transform/opacité des doigts.

## Design Tokens
- Rouge principal `#D83C28` · rouge foncé `#B92425` (dégradé barre)
- Noir UI `#17151A` · noir clair `#3A363F` (dégradé coussinet)
- Blanc `#FFFFFF` · blanc 70 % `rgba(255,255,255,.7)`
- Billes logo : rouge `#FF7A66/#D83C28`, bleu `#6FA0FF/#2F6FD6`, vert `#7FD66F/#3FA33A`, violet `#B57FE6/#7A3FB0`
- Fond écran (référence) `#F2EEE4`
- Typo : **Manrope** 800 (libellés 8.5 px uppercase ; étiquette 8 px uppercase, tracking .06em)
- Rayons : barre 35 · étiquette 10 · coussinet 50%/50%/50%/0 · doigts 50%
- Ombres : barre `0 18px 40px rgba(216,60,40,.4)` · coussinet `0 14px 30px rgba(23,21,26,.5)` · doigts `0 4px 10px rgba(23,21,26,.4)` · étiquette `0 4px 12px rgba(0,0,0,.35)`
- Easings : glissement `cubic-bezier(.3,1.4,.4,1)` · rebond `cubic-bezier(.3,1.5,.4,1)`

## Assets
- `HoPetSit_logo.png` — icône app 512×512 fournie par le client, recadrée sur l'œil central dans le coussinet.
- Icônes d'onglets : traits 24×24 (chemins SVG dans le fichier HTML) ; remplacer par le set d'icônes de l'app si existant.

## Files
- `PawMap Tab Bar.dc.html` — prototype interactif (cliquer sur les onglets / la patte pour voir les états).
- `Splash Screen.dc.html` — écran de lancement animé (bouton « Rejouer l'animation » sous l'écran).
- `HoPetSit_logo.png` — logo.
