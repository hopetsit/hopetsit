import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/report_dialog.dart';

class IndividualChatScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;
  final String contactImage;

  const IndividualChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    required this.contactImage,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  late ChatController chatController;
  late TextEditingController _localMessageController;
  VoidCallback? _sharedControllerListener;

  @override
  void initState() {
    super.initState();

    // Ensure ChatController is properly initialized
    if (!Get.isRegistered<ChatController>()) {
      final chatRepository = Get.find<ChatRepository>();
      final storage = Get.find<GetStorage>();
      Get.put(ChatController(chatRepository, storage: storage));
    }

    chatController = Get.find<ChatController>();

    // Create a local controller that syncs with the shared one
    // Use a safe approach to get initial text
    String initialText = '';
    try {
      initialText = chatController.messageController.text;
    } catch (e) {
      // Controller might be disposed, use empty string
      initialText = '';
    }

    _localMessageController = TextEditingController(text: initialText);

    // Sync changes from local to shared controller
    _localMessageController.addListener(() {
      if (mounted) {
        try {
          if (chatController.messageController.text !=
              _localMessageController.text) {
            chatController.messageController.text =
                _localMessageController.text;
          }
        } catch (e) {
          // Controller might be disposed, ignore
        }
      }
    });

    // Sync changes from shared to local controller (when cleared after sending)
    _sharedControllerListener = () {
      if (mounted) {
        try {
          if (chatController.messageController.text.isEmpty &&
              _localMessageController.text.isNotEmpty) {
            _localMessageController.clear();
          }
        } catch (e) {
          // Controller might be disposed, ignore
        }
      }
    };

    // Only add listener if controller is still valid
    try {
      chatController.messageController.addListener(_sharedControllerListener!);
    } catch (e) {
      // If adding listener fails, controller is disposed - we'll work with local controller only
      _sharedControllerListener = null;
    }
    // Set contact information in controller
    chatController.setContactInfo(widget.contactName, widget.contactImage);
    // Load messages after the build is complete to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Always reload messages when entering the screen to ensure fresh data
        chatController.loadChatMessages(
          widget.conversationId,
          contactName: widget.contactName,
          contactImage: widget.contactImage,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload messages when screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          chatController.currentChatId.value != widget.conversationId) {
        chatController.setContactInfo(widget.contactName, widget.contactImage);
        chatController.loadChatMessages(
          widget.conversationId,
          contactName: widget.contactName,
          contactImage: widget.contactImage,
        );
      }
    });
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    if (_sharedControllerListener != null) {
      try {
        chatController.messageController.removeListener(
          _sharedControllerListener!,
        );
      } catch (e) {
        // Controller might already be disposed, ignore
      }
    }
    _localMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.appBar(context),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.primaryColor,
            size: 24.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Contact Avatar
            Container(
              width: 42.w,
              height: 42.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.r),
                color: AppColors.grey300Color,
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.contactImage.isNotEmpty &&
                      (widget.contactImage.startsWith('http://') ||
                          widget.contactImage.startsWith('https://'))
                  ? CachedNetworkImage(
                      imageUrl: widget.contactImage,
                      width: 42.w,
                      height: 42.h,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        size: 20.sp,
                        color: AppColors.greyColor,
                      ),
                    )
                  : Icon(Icons.person, size: 20.sp, color: AppColors.greyColor),
            ),
            SizedBox(width: 12.w),
            // Contact Name
            Expanded(
              child: PoppinsText(
                text: widget.contactName,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (chatController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // v18.8 — on n'interrompt plus la vue avec l'erreur + backend raw.
        // Si la conversation a déjà des messages en cache, on les garde.
        // Si elle est vide ET qu'il y a erreur, on montre le message épuré.
        if (chatController.errorMessage.value.isNotEmpty &&
            chatController.currentChatMessages.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 42.sp, color: AppColors.greyColor),
                  SizedBox(height: 10.h),
                  InterText(
                    text: 'chat_error_loading_messages'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            children: [
              // Messages List
              Expanded(
                child: chatController.currentChatMessages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.w),
                          child: InterText(
                            text: 'chat_no_messages'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 16.h,
                        ),
                        itemCount: chatController.currentChatMessages.length,
                        reverse: true,
                        itemBuilder: (context, index) {
                          final message = chatController
                              .currentChatMessages
                              .reversed
                              .toList()[index];
                          return _buildMessageItem(message, chatController);
                        },
                      ),
              ),

              // Message Input
              chatController.isChatLocked.value
                  ? _buildChatLockedNotice()
                  : _buildMessageInput(chatController),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMessageItem(ChatMessage message, ChatController controller) {
    return GestureDetector(
      // Long-press a message (own or received) to open "Signaler" dialog.
      onLongPress: message.isFromCurrentUser
          ? null
          : () {
              ReportDialog.show(
                context: context,
                targetType: 'message',
                targetId: message.id,
                conversationId: widget.conversationId,
                snapshot: message.message,
              );
            },
      child: Container(
      margin: EdgeInsets.only(bottom: 15.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender info and timestamp
          Row(
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppColors.grey300Color,
                backgroundImage:
                    message.senderImage.isNotEmpty &&
                        (message.senderImage.startsWith('http://') ||
                            message.senderImage.startsWith('https://'))
                    ? CachedNetworkImageProvider(message.senderImage)
                    : null,
                child:
                    message.senderImage.isEmpty ||
                        (!message.senderImage.startsWith('http://') &&
                            !message.senderImage.startsWith('https://'))
                    ? Icon(
                        Icons.person,
                        size: 16.sp,
                        color: AppColors.greyColor,
                      )
                    : null,
              ),
              SizedBox(width: 8.w),
              InterText(
                text: message.senderName,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(width: 8.w),
              InterText(
                text: '• ${controller.formatMessageTime(message.timestamp)}',
                fontSize: 12.sp,
                fontWeight: FontWeight.w300,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),

          // Attachments (images/videos)
          if (message.attachments.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 41.w, bottom: 8.h),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: message.attachments.map((attachmentUrl) {
                  return GestureDetector(
                    onTap: () {
                      // TODO: Open full screen image viewer
                    },
                    onLongPress: () {
                      ReportDialog.show(
                        context: context,
                        targetType: 'photo',
                        targetId: message.id,
                        conversationId: widget.conversationId,
                        photoUrl: attachmentUrl,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: CachedNetworkImage(
                        imageUrl: attachmentUrl,
                        width: 150.w,
                        height: 150.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 150.w,
                          height: 150.h,
                          color: AppColors.grey300Color,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 150.w,
                          height: 150.h,
                          color: AppColors.grey300Color,
                          child: Icon(
                            Icons.broken_image,
                            size: 40.sp,
                            color: AppColors.greyColor,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Message text
          if (message.message.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 41.w),
              child: InterText(
                text: message.message,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary(context),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildMessageInput(ChatController controller) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(() {
        if (controller.isPaymentRequired.value) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  'chat_payment_required_banner'.tr,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.grey700Color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: Text(
                  'chat_pay_now_button'.tr,
                  style: TextStyle(
                    color: AppColors.whiteColor,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show selected attachments
          Obx(() {
            if (controller.selectedAttachments.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              height: 80.h,
              margin: EdgeInsets.only(bottom: 12.h),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.selectedAttachments.length,
                itemBuilder: (context, index) {
                  final file = controller.selectedAttachments[index];
                  return Container(
                    width: 80.w,
                    height: 80.h,
                    margin: EdgeInsets.only(right: 8.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppColors.greyColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.file(
                            file,
                            width: 80.w,
                            height: 80.h,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4.h,
                          right: 4.w,
                          child: GestureDetector(
                            onTap: () => controller.removeAttachment(index),
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16.sp,
                                color: AppColors.whiteColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }),
          Row(
            children: [
              // Add attachment button
              GestureDetector(
                onTap: () {
                  chatController.pickAttachments();
                },
                child: Container(
                  width: 30.w,
                  height: 32.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.textFieldBorder),
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppColors.primaryColor,
                    size: 28.sp,
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // Message input field
              Expanded(
                child: Container(
                  height: 55.h,

                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill(context),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: TextField(
                    controller: _localMessageController,
                    decoration: InputDecoration(
                      hintText: 'chat_input_hint'.tr,
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (value) {
                      if (mounted &&
                          _localMessageController.text.trim().isNotEmpty) {
                        try {
                          // Sync local controller to shared controller before sending
                          chatController.messageController.text =
                              _localMessageController.text;
                          controller.sendMessage();
                        } catch (e) {
                          // Controller might be disposed, skip sending
                          // User can try again when controller is reinitialized
                        }
                      }
                    },
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // Send button
              GestureDetector(
                onTap: () {
                  if (mounted &&
                      _localMessageController.text.trim().isNotEmpty) {
                    try {
                      // Sync local controller to shared controller before sending
                      chatController.messageController.text =
                          _localMessageController.text;
                      controller.sendMessage();
                    } catch (e) {
                      // Controller might be disposed, skip sending
                      // User can try again when controller is reinitialized
                    }
                  }
                },
                child: Image.asset(AppImages.sendIcon),
              ),
            ],
          ),
        ],
      );
      }),
    );
  }

  Widget _buildChatLockedNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(
            color: AppColors.divider(context),
            width: 1.w,
          ),
        ),
      ),
      child: InterText(
        text: 'chat_locked_after_payment'.tr,
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary(context),
      ),
    );
  }
}
