# Handoff : Bouton « Balade en direct » (petsitting)

## ⚠ Consigne principale — à lire en premier
**Changer UNIQUEMENT le design (l'apparence) du bouton « Balade en direct » déjà présent dans l'app.**

- **Garder exactement la taille actuelle du bouton dans l'app.** Ne pas reprendre les dimensions en pixels du prototype : elles servent seulement de proportions. Tout mettre à l'échelle par rapport au diamètre existant (voir « Proportions » ci-dessous).
- Ne pas modifier la position du bouton, sa zone tactile, les marges ni la mise en page de l'écran autour.
- Ne pas modifier la logique existante (démarrage/arrêt de la balade, chronomètre, navigation, appels réseau). Brancher le nouveau visuel sur l'état et le chrono déjà en place.
- Les décorations autour (feuilles, pattes) ne doivent pas décaler les éléments voisins : les dessiner en superposition (overlay, sans impact sur le layout). Si elles débordent ou gênent, les réduire ou les omettre plutôt que d'agrandir le bouton.
- Ne toucher à aucun autre écran ou composant.

## Overview
Bouton rond principal d'une app mobile de petsitting. Quand la balade est en direct, il affiche un chien, le statut « En direct », les minutes (gros) et les secondes (petit), avec des feuilles flottantes et des pattes qui orbitent autour. Hors ligne, les décorations disparaissent.

## About the Design Files
Les fichiers de ce dossier sont des **références de design réalisées en HTML** (prototype montrant l'apparence et le comportement visuel attendus), pas du code de production à copier tel quel. La tâche est de **recréer ce visuel dans le composant existant de l'app**, avec son framework et ses conventions.

`Bouton Balade en direct.dc.html` s'ouvre dans un navigateur (avec `support.js` à côté) pour voir le rendu et les animations.

## Fidelity
**Haute fidélité** pour les couleurs, dégradés, ombres, typographie et animations. Les **dimensions sont relatives** : le prototype utilise un bouton de 144 px, à convertir proportionnellement vers la taille réelle du bouton dans l'app.

## Proportions (D = diamètre actuel du bouton dans l'app)
Valeurs du prototype pour D = 144 px ; multiplier par D/144.

- Pastille violette du chien : 50 px (≈ 0,35 D)
- Chien (SVG) : 50 px, déborde légèrement de la pastille (overflow visible)
- Capsule de statut : texte 8,5 px, padding 3px 9px 3px 7px, marge haute 8 px, marge basse 2 px
- Minutes : 28 px (≈ 0,19 D) ; unité « MIN » : 10 px ; secondes : 10 px
- Relief (ombre dure sous le bouton) : 8 px (≈ 0,055 D)
- Rayon d'orbite des pattes : 102 px depuis le centre (≈ 0,71 D)
- Rayon de placement des feuilles : 114 px depuis le centre (≈ 0,79 D)
- Pattes : 16 px et 12 px ; feuilles : 26, 22, 20, 18 px

Si le texte devient illisible à la taille de l'app (moins de ~9 px), garder des tailles de texte lisibles et réduire plutôt le chien.

## Composant

### Bouton (cercle)
- Fond : `radial-gradient(circle at 35% 25%, #95F0A4 0%, #48CB68 40%, #28A04A 100%)`
- Ombres : `inset 0 -7px 0 rgba(0,0,0,.14), inset 0 3px 0 rgba(255,255,255,.45), 0 8px 0 #1E7A38, 0 22px 36px rgba(42,160,75,.45)`
- Contenu en colonne, centré, `gap: 1px`, contenu rogné au cercle
- **Hover** : `translateY(3px)`, ombre dure `0 5px 0 #1E7A38`, portée `0 15px 26px rgba(42,160,75,.45)`
- **Pressé** : `translateY(8px)`, ombre dure `0 0 0`, portée `0 4px 12px rgba(42,160,75,.3)`, inset bas `-4px`
- Transition : `transform .15s, box-shadow .15s`

### Pastille violette (cercle)
- Fond : `radial-gradient(circle at 40% 30%, #E9D5FF 0%, #9B5CF6 58%, #7C3AED 100%)`
- Ombre : `0 4px 0 #5B21B6, 0 9px 14px rgba(0,0,0,.2), inset 0 2px 0 rgba(255,255,255,.75), 0 0 0 3px rgba(255,255,255,.35)`

### Chien (SVG, viewBox 0 0 48 48)
Paths exacts dans le fichier HTML (bloc `const dog`). Couleurs :
- Tête : dégradé radial `#FFE0B0 → #F0A455`
- Oreilles tombantes : dégradé vertical `#B9713F → #7E4522`
- Tache sur l'œil droit : `#D98A45` à 75 %
- Liste sur le front : `#FFF6E6`
- Museau : dégradé radial `#FFFFFF → #FFE9CC`
- Yeux, truffe, bouche : `#3A2318` ; reflets blancs
- Sourcils : `#7E4522`
- Joues : `#FF8FA8` à 60 % ; langue `#FF6B8A`, trait `#E04A6C`
- Animation (en direct) : balancement −8° ↔ +8°, 0,9 s, ease-in-out, infini, origine `50% 85%`

### Capsule de statut
- Fond `#17692F`, rayon 999 px, ombre `inset 0 1px 0 rgba(0,0,0,.25), 0 1px 0 rgba(255,255,255,.25)`
- Texte : Nunito 900, majuscules, letter-spacing 1,6 px, blanc. Copie : « EN DIRECT » / « HORS LIGNE »
- Point : 7 px, `#C9A8FF` + halo `0 0 0 2px rgba(201,168,255,.35)`, animation scale 1 → 0,5 et opacité 1 → 0,5, 1,1 s, infinie. Hors ligne : `#ECFFE4`, fixe.

### Compteur
- Ligne minutes : alignement baseline, `gap: 4px`
  - Minutes : Nunito 900, letter-spacing −1 px, blanc, `text-shadow: 0 2px 0 rgba(0,0,0,.2)`, chiffres tabulaires. Hors ligne : « — »
  - Unité : Nunito 800, letter-spacing 0,8 px, majuscules, `#E3FBDA`. Copie : « MIN »
- Secondes : marge haute 1 px, Nunito 800, letter-spacing 0,6 px, `#E3FBDA`, format `SS s` sur 2 chiffres (ex. « 07 s »)

### Feuilles (en direct uniquement, 4)
- SVG 24×24 : `M3 21c0-9 7-16 18-18-1 11-8 18-18 18z` + nervure `M4 20L19 5` blanc 60 %, épaisseur 1,3 ; `drop-shadow(0 3px 4px rgba(30,122,56,.25))`
- Sur un cercle centré sur le bouton, aux angles 225°, 315°, 45°, 135° :
  - 225° : `#6FD98A`, rotation −25°
  - 315° : `#9B5CF6`, rotation 40°
  - 45° : `#8EEB9E`, rotation 120°
  - 135° : `#B388FF`, rotation −110°
- Animation : translateY 0 → −6 px, 3 à 5 s selon la feuille, ease-in-out, infinie, décalées

### Pattes en orbite (en direct uniquement, 4)
- SVG 24×24 : ellipse (12,14 rx 3,2 ry 3,6) + cercles (7,9.5 r1,9), (17,9.5 r1,9), (9.5,5.5 r1,8), (14.5,5.5 r1,8) ; opacité 0,9
- Angles de départ 0°, 90°, 180°, 270° ; couleurs `#6FD98A`, `#9B5CF6`, `#8EEB9E`, `#B388FF`
- Animation : rotation 360° autour du centre du bouton, 18 s (grandes) / 21 s (petites), linéaire, infinie

## États
- **En direct** : chien qui se balance, point clignotant, feuilles, pattes, compteur affiché.
- **Hors ligne** : décorations masquées, statut « HORS LIGNE », minutes « — », unité et secondes vides.
- Le prototype bascule au tap et compte en local uniquement pour la démo : **utiliser l'état et le chrono existants de l'app.**
- Respecter la préférence système de réduction des animations (couper les animations infinies).

## Design Tokens
**Couleurs**
- Verts bouton : `#95F0A4`, `#48CB68`, `#28A04A`, relief `#1E7A38`, capsule `#17692F`
- Verts décor : `#6FD98A`, `#8EEB9E`
- Violets : `#E9D5FF`, `#C9A8FF`, `#B388FF`, `#9B5CF6`, `#7C3AED`, `#5B21B6`
- Textes : blanc, `#E3FBDA`, `#ECFFE4`
- Chien : `#FFE0B0`, `#F0A455`, `#D98A45`, `#B9713F`, `#7E4522`, `#3A2318`, `#FFF6E6`, `#FFE9CC`
- Roses : `#FF8FA8`, `#FF6B8A`, `#E04A6C`

**Typographie** : Nunito, graisses 800 et 900 (si l'app a déjà une police arrondie équivalente, la conserver).

**Durées** : 150 ms (états), 0,9 s (chien), 1,1 s (point), 3–5 s (feuilles), 18–21 s (pattes).

## Assets
Aucun bitmap. Chien, feuille et patte sont des SVG dont les paths sont dans le fichier HTML.

## Files
- `Bouton Balade en direct.dc.html` — prototype (markup, logique de démo, animations)
- `support.js` — runtime pour ouvrir le prototype dans un navigateur (ne pas réutiliser en production)
