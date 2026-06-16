import 'package:get/get.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';

/// Single source of truth for the PawMap report premium gate.
///
/// Règle produit (cf. "signaux premium débloqués si un abo actif") : un
/// utilisateur a accès aux signalements Premium dès qu'il a N'IMPORTE QUEL
/// abonnement actif. Deux drapeaux coexistent côté client :
///   • [SubscriptionController.isPremium] — abo classique (status.isPremium).
///   • [PawSpotController.premiumActive]  — Paw Premium (GET /users/me/benefits).
///
/// Avant ce helper, le report sheet ne lisait QUE `SubscriptionController`,
/// donc un utilisateur Paw Premium (premiumActive=true) était bloqué avec
/// « il me faut un abonnement ». On combine les deux ici, avec un garde
/// `Get.isRegistered` (false = défaut sûr si un controller n'est pas encore
/// enregistré).
abstract final class ReportPremiumHelper {
  const ReportPremiumHelper._();

  /// True si N'IMPORTE QUEL abonnement actif débloque les signalements
  /// Premium de la PawMap.
  static bool get isUnlocked {
    final sub = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : null;
    if (sub?.isPremium ?? false) return true;

    final pawspot = Get.isRegistered<PawSpotController>()
        ? Get.find<PawSpotController>()
        : null;
    if (pawspot?.premiumActive.value ?? false) return true;

    return false;
  }
}
