import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/views/chat_shared/chat_list_body.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/new_conversation_button.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize or reuse the controllers
    final chatRepository = Get.find<ChatRepository>();
    final storage = Get.find<GetStorage>();
    final ChatController chatController = Get.isRegistered<ChatController>()
        ? Get.find<ChatController>()
        : Get.put(ChatController(chatRepository, storage: storage));
    final profileController = Get.put(ProfileController());

    // Always refresh conversations when entering this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatController.reloadConversations();
    });

    return GetBuilder<ChatController>(
      builder: (controller) {
        return Obx(
          () => Scaffold(
            appBar: CustomAppBar(
              // v553 — Daniel : « quand je rentre dans le chat il n'y a pas de
              // retour ». L'écran est aussi ouvert DEPUIS la PawMap (bouton
              // « Chat du cercle ») : dans ce cas il est empilé et doit
              // afficher la flèche. En onglet racine, la pile est vide donc
              // Flutter n'affiche rien — le comportement reste identique.
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
            // v23.1 part 244c — Daniel : "dans chat rajote en bas a droite
            // un bouton nouvelle conversation". FAB extended qui ouvre la
            // FriendsScreen sur l'onglet Mes amis (index 0) : l'user pick
            // un ami et tap le 💬 a cote du nom pour demarrer une conv.
            // v465 — Daniel : le bouton « Nouvelle conversation » était caché
            // derrière le menu du bas flottant. On le remonte (marge basse)
            // pour qu'il flotte AU-DESSUS du menu, toujours cliquable.
            // v566 — liste vide : le grand bouton centré « Démarrer une
            // conversation » remplace le bouton flottant (pas de doublon).
            floatingActionButton: controller.conversations.isEmpty
                ? null
                : Padding(
              // v468 — au-dessus de la barre de menu PLEINE LARGEUR (~80) +
              // l'inset Samsung, sinon le bouton passe derrière.
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
                    () => IndividualChatScreen(
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
