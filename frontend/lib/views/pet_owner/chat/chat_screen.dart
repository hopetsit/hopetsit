import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';

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
            backgroundColor: AppColors.scaffold(context),
            body: SafeArea(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                // v18.8 — affichage d'erreur épuré : on ne montre plus le
                // raw backend message en dessous (il polluait l'UI avec
                // "ApiException(statusCode 500)" etc.). Si la liste est
                // déjà peuplée, on n'interrompt même pas l'UI : on laisse
                // l'ancien état.
                // v23.1 part 225 — Daniel : "dans l'onglet chat erreur api
                // 403". On surface desormais le message backend brut sous
                // le generic (en petit, gris) pour pouvoir diagnostiquer.
                // requireRole backend renvoie deja path + role attendu vs
                // role courant dans `details` (ex: "GET /conversations/X
                // requires role(s): sitter (you are: owner)"). _extractError
                // ApiClient prend en charge ce champ donc errorMessage.value
                // contient deja le bon texte. On ajoute aussi un bouton
                // "Reconnecter" qui force un re-login (cas du JWT stale).
                if (controller.errorMessage.value.isNotEmpty &&
                    controller.conversations.isEmpty) {
                  final raw = controller.errorMessage.value;
                  final is403 = raw.toLowerCase().contains('403') ||
                      raw.toLowerCase().contains('permission') ||
                      raw.toLowerCase().contains('forbidden');
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            is403
                                ? Icons.lock_outline_rounded
                                : Icons.wifi_off_rounded,
                            size: 48.sp,
                            color: is403 ? Colors.orange : AppColors.greyColor,
                          ),
                          SizedBox(height: 12.h),
                          PoppinsText(
                            text: is403
                                ? 'chat_error_403_title'.tr
                                : 'chat_error_loading_conversations'.tr,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                            textAlign: TextAlign.center,
                          ),
                          // Raw backend message (path + role mismatch quand
                          // c'est un 403). Indispensable pour diagnostiquer.
                          SizedBox(height: 8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: PoppinsText(
                              text: raw,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.greyText,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          OutlinedButton(
                            onPressed: () => controller.reloadConversations(),
                            child: Text('chat_retry'.tr),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (controller.conversations.isEmpty) {
                  return Center(
                    child: PoppinsText(
                      text: 'chat_no_conversations'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary(context),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 100.h),
                  itemCount: controller.conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = controller.conversations[index];
                    return _buildConversationItem(
                      context,
                      conversation,
                      controller,
                    );
                  },
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationItem(
    BuildContext context,
    ChatConversation conversation,
    ChatController controller,
  ) {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => IndividualChatScreen(
            conversationId: conversation.id,
            contactName: conversation.contactName,
            contactImage: conversation.contactImage,
          ),
        );
      },
      // v23.1.195 — Daniel : "dans le message chat ajouter effacer pour
      // effacer la conversation en entier". Long-press → dialog
      // confirm definitive → hard delete (conv + tous messages) cote
      // backend, retrait optimistic de la liste.
      onLongPress: () async {
        final confirmed = await Get.dialog<bool>(
          AlertDialog(
            title: Text('chat_delete_conv_title'.tr),
            content: Text('chat_delete_conv_msg'
                .trParams({'name': conversation.contactName})),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('common_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text(
                  'chat_delete_conv_confirm'.tr,
                  style: TextStyle(color: AppColors.errorColor),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.deleteConversation(conversation.id);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                conversation.contactImage.startsWith('http://') ||
                        conversation.contactImage.startsWith('https://')
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: conversation.contactImage,
                          width: 40.r,
                          height: 40.r,
                          memCacheWidth: 120, // v23.1 part 234.
                          fit: BoxFit.cover,
                          placeholder: (context, url) => CircleAvatar(
                            radius: 20.r,
                            backgroundColor: AppColors.lightGreyColor,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 20.r,
                            backgroundColor: AppColors.lightGreyColor,
                            child: Icon(
                              Icons.person,
                              size: 16.sp,
                              color: AppColors.greyColor,
                            ),
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 20.r,
                        backgroundColor: AppColors.lightGreyColor,
                        backgroundImage:
                            conversation.contactImage.isNotEmpty &&
                                (conversation.contactImage.startsWith(
                                      'http://',
                                    ) ||
                                    conversation.contactImage.startsWith(
                                      'https://',
                                    ))
                            ? CachedNetworkImageProvider(
                                conversation.contactImage,
                              )
                            : null,
                        child:
                            conversation.contactImage.isEmpty ||
                                (!conversation.contactImage.startsWith(
                                      'http://',
                                    ) &&
                                    !conversation.contactImage.startsWith(
                                      'https://',
                                    ))
                            ? Icon(
                                Icons.person,
                                size: 16.sp,
                                color: AppColors.greyColor,
                              )
                            : null,
                      ),
                if (conversation.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12.w,
                      height: 12.h,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.whiteColor,
                          width: 2.w,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(width: 12.w),

            // Conversation details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact name
                  PoppinsText(
                    text: conversation.contactName,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary(context),
                  ),

                  SizedBox(height: 4.h),

                  // Last message
                  PoppinsText(
                    text: conversation.lastMessage,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Time + bouton Effacer visible (v23.1.196).
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                InterText(
                  text: controller.formatTime(conversation.lastMessageTime),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
                SizedBox(height: 6.h),
                // v23.1.196 — Daniel : "photo 14 aucun bouton effacer".
                // Le long-press (v195) etait invisible. Maintenant bouton
                // visible avec icone trash + texte "Effacer" rouge.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10.r),
                    onTap: () async {
                      final confirmed = await Get.dialog<bool>(
                        AlertDialog(
                          title: Text('chat_delete_conv_title'.tr),
                          content: Text('chat_delete_conv_msg'.trParams(
                              {'name': conversation.contactName})),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(result: false),
                              child: Text('common_cancel'.tr),
                            ),
                            TextButton(
                              onPressed: () => Get.back(result: true),
                              child: Text(
                                'chat_delete_conv_confirm'.tr,
                                style: TextStyle(color: AppColors.errorColor),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await controller.deleteConversation(conversation.id);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 12.sp, color: Colors.red),
                          SizedBox(width: 3.w),
                          InterText(
                            text: 'chat_delete_short'.tr,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
