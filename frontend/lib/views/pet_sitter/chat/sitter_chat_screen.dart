import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';

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
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => Get.to(() => const FriendsScreen()),
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_rounded),
              label: Text(
                'chat_new_conversation_btn'.tr,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            backgroundColor: AppColors.scaffold(context),
            body: SafeArea(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                // v18.8 — épuré : plus de backend raw message, et on
                // n'affiche l'erreur que si la liste est vide.
                // v23.1 part 225 — Daniel "longlet chat erreur api 403".
                // Meme amelioration que ChatScreen owner : on surface le
                // message backend brut sous le titre generic pour
                // pouvoir identifier quel endpoint cloche cote sitter.
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
    SitterChatConversation conversation,
    SitterChatController controller,
  ) {
    return GestureDetector(
      onTap: () {
        Get.to(
          () => SitterIndividualChatScreen(
            conversationId: conversation.id,
            contactName: conversation.contactName,
            contactImage: conversation.contactImage,
          ),
        );
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
                          memCacheWidth: 120, // v23.1 part 234 perf.
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
                // v23.1.196 — Bouton "Effacer" visible (au lieu du long-press
                // invisible) pour supprimer la conversation entiere.
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
