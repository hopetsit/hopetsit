import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';

/// v568 — « Ajouter une carte » (menu Profil).
///
/// CAUSE RACINE corrigée : cet écran affichait un formulaire maison
/// (titulaire / numéro / expiration / CVC) qui envoyait le NUMÉRO DE CARTE et
/// le CVC à notre serveur (`PUT /users/me/card`). Rien n'était transmis à
/// Airwallex : la carte n'existait donc nulle part au moment de payer — d'où
/// « elle ne reste pas enregistrée quand je veux payer ou faire le don ». En
/// prime, stocker un CVC est interdit (PCI-DSS).
///
/// L'écran renvoie désormais vers le SEUL parcours valable : « Mes cartes »,
/// qui ouvre la page sécurisée Airwallex (vérification 0,50 € remboursée
/// aussitôt). La carte enregistrée là est ensuite proposée à chaque paiement,
/// sur les 3 profils du compte.
class AddCardScreen extends StatelessWidget {
  final String userType;

  const AddCardScreen({super.key, this.userType = 'pet_owner'});

  @override
  Widget build(BuildContext context) {
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'add_card_title'.tr,
      accent: accent,
      scroll: false,
      bottom: ProfilePrimaryButton(
        label: 'cards568_add_open'.tr,
        accent: accent,
        icon: Icons.add_card_rounded,
        onTap: () => Get.off(() => const SavedCardsScreen()),
      ),
      body: ProfileEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'add_card_title'.tr,
        message:
            '${'cards568_add_explain'.tr}\n\n${'cards568_security_note'.tr}',
        accent: accent,
      ),
    );
  }
}
