import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/views/chat_shared/chat_list_body.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/new_conversation_button.dart';

class SitterChatScreen extends StatelessWidget {
  const SitterChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize or reuse the controllers
    final chatRepository = Get.find<ChatRepository>();
    final SitterChatController chatController =
        Get.isRegistered<SitterChatController>()
            ? Get.find<SitterChatController>()
            : Get.put(SitterChatController(chatRepository));
    final profileController = Get.put(SitterProfileController());

    // Always refresh conversations when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatController.reloadConversations();
    });

    return GetBuilder<SitterChatController>(
      builder: (controller) {
        return Obx(
          () => Scaffold(
            appBar: CustomAppBar(
              // v553 — flèche retour quand l'écran est ouvert depuis la PawMap.
              automaticallyImplyLeading: Navigator.of(context).canPop(),
              userName: profileController.userName.value.isNotEmpty
                  ? profileController.userName.value
                  : 'home_default_user_name'.tr,
              userImage: profileController.profileImageUrl.value.isNotEmpty
                  ? profileController.profileImageUrl.value
                  : '',
              showNotificationIcon:
                  false, // Hide notification icon on chat screen
              onProfileTap: () {
                // Handle profile tap
                // debug removed
              },
            ),
            // v23.1 part 244c — FAB "Nouvelle conversation" (Daniel feedback).
            // Voir note dans chat_screen.dart owner pour la logique :
            // ouvre FriendsScreen onglet Mes amis -> tap 💬 pour demarrer.
            // v470 — Daniel : « bouton nouvelle conversation trop bas encore ».
            // Le FAB sitter/walker n'avait PAS le Padding (contrairement à
            // l'owner) → il passait derrière la barre de menu pleine largeur.
            // On le remonte au-dessus du menu (~80) + inset Samsung, comme owner.
            // v566 — liste vide : le grand bouton centré « Démarrer une
            // conversation » remplace le bouton flottant (pas de doublon).
            floatingActionButton: controller.conversations.isEmpty
                ? null
                : Padding(
              padding: EdgeInsets.only(
                  // v488 — Daniel : « nouvelle conversation toujours trop bas »
                  // → remonté nettement au-dessus du menu flottant.
                  bottom: 120.h + MediaQuery.of(context).viewPadding.bottom),
              // v565 — bouton modernisé (pilule à la couleur du rôle).
              // v566 — rond 56 qui s'étend en pilule à l'arrêt / en haut de
              // liste et se replie pendant le défilement.
              child: NewConversationButton(
                theme: ChatRoleTheme.forRole(controller.myRole),
                expanded: controller.newChatExpanded,
                onTap: () => Get.to(() => const FriendsScreen()),
              ),
            ),
            backgroundColor: AppColors.scaffold(context),
            // v565 — points 16 + 36 : liste modernisée partagée (avatar +
            // point vert, aperçu, heure, non-lus, glisser pour supprimer,
            // états vide / chargement / erreur) — views/chat_shared/.
            body: SafeArea(
              child: ChatListBody(
                session: controller,
                theme: ChatRoleTheme.forRole(controller.myRole),
                onNewConversation: () => Get.to(() => const FriendsScreen()),
                onOpen: (conversation) {
                  Get.to(
                    () => SitterIndividualChatScreen(
                      conversationId: conversation.id,
                      contactName: conversation.contactName,
                      contactImage: conversation.contactImage,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
