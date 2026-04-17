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

                if (controller.errorMessage.value.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PoppinsText(
                          text: 'chat_error_loading_conversations'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context),
                        ),
                        SizedBox(height: 8.h),
                        PoppinsText(
                          text: controller.errorMessage.value,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary(context),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: () => controller.reloadConversations(),
                          child: Text('chat_retry'.tr),
                        ),
                      ],
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

            // Time
            InterText(
              text: controller.formatTime(conversation.lastMessageTime),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
