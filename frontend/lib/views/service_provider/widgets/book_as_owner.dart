// v586 (point 8 de Daniel, 25/09/2026) — « Réserver » et « Message » depuis
// la fiche d'un gardien / promeneur quand on est soi-même gardien ou
// promeneur : la réservation (et la première prise de contact) se fait avec
// le PROFIL PROPRIÉTAIRE.
//
// Parcours : dialogue maison « Tu réserves avec ton profil propriétaire »
// → Continuer → `AuthController.switchRole(targetRole: 'owner')` (même
// mécanisme que « Mes profils » ; le serveur crée le profil propriétaire s'il
// n'existe pas) → `switchRole` remplace toute la pile par l'accueil
// propriétaire (`Get.offAll`) → PUIS on pousse l'écran demandé ([then]) :
// la demande de réservation pré-remplie ou la conversation.
//
// Pourquoi « Message » passe aussi par là : côté serveur,
// `/conversations/start` est réservé aux propriétaires (403) et
// `start-by-sitter|walker` n'ouvre une conversation qu'avec un propriétaire ;
// gardien → gardien n'existe que pour des AMIS (`/conversations/friend`).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Rôle actif du spectateur ('' si invité / inconnu).
String viewerRoleNow() {
  final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
  return (auth?.userRole.value ?? '').toLowerCase();
}

/// Exécute [then] avec le profil PROPRIÉTAIRE actif.
///
/// Propriétaire (ou invité, géré en amont par le mur d'inscription) : [then]
/// tout de suite. Gardien / promeneur : dialogue, bascule, puis [then].
Future<void> runAsOwner(
  BuildContext context, {
  required String providerName,
  required bool forMessage,
  required VoidCallback then,
}) async {
  final String role = viewerRoleNow();
  if (role.isEmpty || role == 'owner') {
    then();
    return;
  }
  final String name = providerName.trim().isEmpty ? 'common_user'.tr : providerName.trim();
  await showAppConfirmDialog(
    context,
    title: forMessage
        ? 'pawmap586b_message_as_owner_title'.tr
        : 'pawmap586b_book_as_owner_title'.tr,
    message: (forMessage
            ? 'pawmap586b_message_as_owner_body'
            : 'pawmap586b_book_as_owner_body')
        .trParams({'name': name}),
    busyMessage: 'pawmap586b_switching'.tr,
    confirmLabel: 'pawmap586b_continue'.tr,
    cancelLabel: 'common_cancel'.tr,
    icon: forMessage ? Icons.chat_bubble_rounded : Icons.event_available_rounded,
    accent: AppColors.ownerAccent,
    barrierDismissible: false,
    onConfirm: () async {
      final auth = Get.find<AuthController>();
      await auth.switchRole(targetRole: 'owner');
      // `switchRole` a déjà remplacé la pile par l'accueil propriétaire :
      // l'écran demandé se pose PAR-DESSUS. Échec (réseau…) : le message
      // d'erreur est déjà affiché par `switchRole`, on ne pousse rien.
      if ((auth.userRole.value ?? '').toLowerCase() == 'owner') {
        then();
      }
    },
  );
}

/// Ouvre (ou reprend) la conversation propriétaire → prestataire, après une
/// bascule vers le profil propriétaire. Même route que le bouton Message d'un
/// propriétaire (`/conversations/start`) ; l'écran d'origine n'existe plus
/// (pile remplacée), donc aucune dépendance à son contrôleur.
Future<void> openOwnerChatWithProvider({
  required String providerId,
  required String providerRole,
  required String providerName,
  String providerAvatar = '',
}) async {
  try {
    if (!Get.isRegistered<OwnerRepository>()) throw StateError('OwnerRepository');
    final repo = Get.find<OwnerRepository>();
    final res = providerRole == 'walker'
        ? await repo.startConversation(walkerId: providerId)
        : await repo.startConversation(sitterId: providerId);
    final conv = res['conversation'] as Map<String, dynamic>?;
    final convId = (conv?['id'] ?? conv?['_id'] ?? '').toString();
    if (convId.isEmpty) throw StateError('conversation id missing');
    Get.to(() => IndividualChatScreen(
          conversationId: convId,
          contactName: providerName,
          contactImage: providerAvatar,
        ));
  } catch (e) {
    AppLogger.logError('owner chat after role switch failed', error: e);
    CustomSnackbar.showError(
      title: 'common_error'.tr,
      message: 'sitter_detail_start_chat_failed'.tr,
    );
  }
}
