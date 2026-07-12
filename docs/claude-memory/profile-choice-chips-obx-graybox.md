---
name: profile-choice-chips-obx-graybox
description: Cadre GRIS géant dans Modifier-profil = Obx(() => ChildWidget(rxList)) ne track pas → ErrorWidget release ; fix .toList()
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**Symptôme** : grand RECTANGLE GRIS plein à la place d'une section de puces sélectionnables (« Services proposés » / « Ce que vous recherchez » / « Animaux promenés ») dans les 3 écrans « Modifier le profil » (owner/sitter/walker). Reporté plusieurs fois ; un FAUX diagnostic « contraste » (inputFill==scaffold) en v444 n'a rien changé.

**Cause racine (GetX)** : `Obx(() => ProfileChoiceChips(selected: controller.maRxList, ...))`. La RxList est passée PAR RÉFÉRENCE — sa lecture (`.contains()`) se fait dans le `build()` de l'enfant `ProfileChoiceChips`, **hors du scope de tracking synchrone de l'Obx**. L'Obx builder ne lit donc AUCUN observable → GetX lève `ObxError` (« improper use of Obx/GetX, no observable ») → en **release**, une exception pendant build = **ErrorWidget gris** (en debug = écran rouge). 

**Preuve** : le sélecteur « Langue » juste au-dessus marchait — son `Obx(() { final s = controller.x; ... s.contains() ... })` lit l'observable DANS le builder. Asymétrie = confirmation.

**Fix** : forcer la lecture de la RxList DANS le builder de l'Obx → `selected: controller.maRxList.toList()` (`.toList()` itère → `length`/`[]` → `reportRead` → l'Obx track). Appliqué aux 7 call sites v445. 

**Règle générale** : ne jamais faire `Obx(() => Enfant(rx))` en passant une Rx/RxList par référence à un enfant qui la lit dans SON build. Soit lire `.value`/`.toList()`/`.length` dans le builder, soit mettre l'Obx À L'INTÉRIEUR de l'enfant autour du `.contains`. `ProfileChoiceChips` (`views/profile/widgets/profile_field_widgets.dart`) est un `Wrap` de puces — il ne PEUT pas produire un cadre gris lui-même ; le gris vient de l'ErrorWidget de l'Obx parent. Pattern sûr déjà en place : `ProfileRadiusDropdown(value: controller.x.value)` lit `.value` dans l'arg → OK.
