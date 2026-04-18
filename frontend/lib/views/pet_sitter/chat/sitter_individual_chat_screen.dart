import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

class SitterIndividualChatScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;
  final String contactImage;

  const SitterIndividualChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    required this.contactImage,
  });

  @override
  State<SitterIndividualChatScreen> createState() =>
      _SitterIndividualChatScreenState();
}

class _SitterIndividualChatScreenState
    extends State<SitterIndividualChatScreen> {
  late SitterChatController chatController;
  late TextEditingController _localMessageController;
  VoidCallback? _sharedControllerListener;

  @override
  void initState() {
    super.initState();
    chatController = Get.find<SitterChatController>();
    // Create a local controller that syncs with the shared one
    _localMessageController = TextEditingController(
      text: chatController.messageController.text,
    );
    // Sync changes from local to shared controller
    _localMessageController.addListener(() {
      if (mounted &&
          chatController.messageController.text !=
              _localMessageController.text) {
        chatController.messageController.text = _localMessageController.text;
      }
    });
    // Sync changes from shared to local controller (when cleared after sending)
    _sharedControllerListener = () {
      if (mounted &&
          chatController.messageController.text.isEmpty &&
          _localMessageController.text.isNotEmpty) {
        _localMessageController.clear();
      }
    };
    chatController.messageController.addListener(_sharedControllerListener!);
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
      chatController.messageController.removeListener(
        _sharedControllerListener!,
      );
    }
    _localMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
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

        if (chatController.errorMessage.value.isNotEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InterText(
                    text: 'chat_error_loading_messages'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                  ),
                  SizedBox(height: 8.h),
                  InterText(
                    text: chatController.errorMessage.value,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary(context),
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

  Widget _buildMessageItem(
    SitterChatMessage message,
    SitterChatController controller,
  ) {
    return Container(
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
    );
  }

  Widget _buildMessageInput(SitterChatController controller) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sprint 3 step 6 — Share my phone (sitter only, post-payment).
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.sharePhone(),
              icon: Icon(Icons.phone, size: 18.sp, color: AppColors.primaryColor),
              label: Text(
                'chat_share_phone_button'.tr,
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
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
                    borderRadius: BorderRadius.circular(10.r),
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
                      if (mounted) {
                        // Sync local controller to shared controller before sending
                        chatController.messageController.text =
                            _localMessageController.text;
                        controller.sendMessage();
                      }
                    },
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // Send button
              GestureDetector(
                onTap: () {
                  if (mounted) {
                    // Sync local controller to shared controller before sending
                    chatController.messageController.text =
                        _localMessageController.text;
                    controller.sendMessage();
                  }
                },
                child: Image.asset(AppImages.sendIcon),
              ),
            ],
          ),
        ],
      ),
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
