// v23.1 part 109 — Daniel : "le boost marche pas".
// Le bug : après l'achat de Boost / PawSpot / Premium, le shop tab
// rafraichissait son propre status (boost actif), MAIS les autres
// écrans (profile, map, sitter cards) lisaient une version cachée du
// user qui n'avait pas le flag isBoosted=true → résultat : Daniel
// payait, voyait "✓ Active" dans le shop, mais nulle part d'autre
// l'effet du boost.
//
// Ce helper centralise le refresh de TOUS les écrans dépendants après
// un achat boutique. À appeler après chaque /confirm réussi (boost,
// map-boost, premium, chat-addon).

import 'package:get/get.dart';

import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/controllers/user_controller.dart';

/// Re-fetch all profile-related state to surface boost / premium / pawspot
/// flags freshly across the app. Best-effort : si un controller n'est
/// pas registered (parce qu'on est sur un onglet où il n'a jamais été
/// utilisé), on l'ignore silencieusement.
Future<void> refreshAfterPurchase() async {
  // 1) UserController : le user object source de vérité (isPremium,
  //    boostExpiry, mapBoostExpiry pour le user connecté).
  if (Get.isRegistered<UserController>()) {
    try {
      await Get.find<UserController>().loadMyProfile();
    } catch (_) {/* best-effort */}
  }

  // 2) ProfileController : owner profile screen.
  if (Get.isRegistered<ProfileController>()) {
    try {
      await Get.find<ProfileController>().loadMyProfile();
    } catch (_) {/* best-effort */}
  }

  // 3) SitterProfileController : sitter/walker profile screen.
  if (Get.isRegistered<SitterProfileController>()) {
    try {
      await Get.find<SitterProfileController>().loadMyProfile();
    } catch (_) {/* best-effort */}
  }

  // Note : PawMapController.loadNearby() requires a center LatLng, donc
  // on ne le déclenche pas ici — la map se rechargera au prochain
  // mouvement de caméra et lira les flags fraîchement depuis l'API.
}
