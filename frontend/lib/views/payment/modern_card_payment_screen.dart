import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

/// v21.1.1 — Stripe purgé. Cet écran était l'ancien CardFormField Stripe
/// pour saisir une carte sans saved-card. Avec Airwallex tout passe par
/// l'HPP (webview) — donc cet écran ne devrait plus être atteint.
///
/// On garde le fichier comme stub pour ne pas casser d'éventuels imports
/// résiduels. Si jamais quelqu'un le push, il affiche un message clair
/// et permet de revenir en arrière.
class ModernCardPaymentScreen extends StatelessWidget {
  final String? clientSecret;
  final double? amount;
  final String? currency;
  final String? productLabel;
  final String? productSubtitle;
  final List<Map<String, dynamic>>? savedPaymentMethods;

  const ModernCardPaymentScreen({
    super.key,
    this.clientSecret,
    this.amount,
    this.currency,
    this.productLabel,
    this.productSubtitle,
    this.savedPaymentMethods,
  });

  @override
  Widget build(BuildContext context) {
    // v565 — stub modernisé (kit Profil), « Retour » en clé traduite.
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'payment_title'.tr,
      accent: accent,
      scroll: false,
      bottom: ProfilePrimaryButton(
        label: 'v565_pay_back'.tr,
        accent: accent,
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Get.back(result: false),
      ),
      body: ProfileEmptyState(
        icon: Icons.info_outline_rounded,
        title: 'payment_airwallex_title'.tr,
        message: 'payment_airwallex_hint'.tr,
        accent: accent,
      ),
    );
  }
}
