import 'package:get/get.dart';

/// v465 — état partagé « carte PawMap agrandie ».
///
/// Quand l'utilisateur agrandit la PawMap, on masque la barre de navigation du
/// bas (StackedNavigationWrapper) pour que la carte soit vraiment plein écran
/// et que le bouton « Signaler », le bouton « Tag Spot » et les bandeaux de
/// validation ne soient plus cachés derrière le menu / la barre système Samsung.
///
/// PawMapScreen écrit cette valeur ; le wrapper l'observe (Obx) pour afficher
/// ou masquer le menu. Top-level → pas de couplage entre les deux widgets.
final RxBool pawMapExpanded = false.obs;
