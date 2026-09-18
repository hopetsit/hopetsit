// v21.1.1 — Stripe purgé.
// Cet écran était l'ancien CardFormField Stripe pour ajouter une carte
// via SetupIntent. Stripe n'est plus utilisé : le screen owner_payments
// est désactivé avec un message friendly. Ce fichier reste comme stub
// pour ne pas casser les imports résiduels.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

class AddCardScreen extends StatelessWidget {
  final String? setupIntentClientSecret;
  final String? publishableKey;

  const AddCardScreen({
    super.key,
    this.setupIntentClientSecret,
    this.publishableKey,
  });

  @override
  Widget build(BuildContext context) {
    // v565 — stub modernisé (kit Profil) : explique que la carte est
    // enregistrée automatiquement au premier paiement Airwallex, et propose
    // d'ouvrir « Mes cartes » (flux d'ajout 0,50 € remboursé) au lieu d'un
    // simple « Retour » en dur.
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'add_card_title'.tr,
      accent: accent,
      scroll: false,
      bottom: ProfileSecondaryButton(
        label: 'v565_pay_back'.tr,
        accent: accent,
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: () => Get.back(result: false),
      ),
      body: ProfileEmptyState(
        icon: Icons.credit_card_rounded,
        title: 'add_card_auto_saved'.tr,
        message: 'add_card_airwallex_hint'.tr,
        accent: accent,
        actionLabel: 'saved_cards_add_button'.tr,
        onAction: () => Get.off(() => const SavedCardsScreen()),
      ),
    );
  }
}
