// v565 — points 16 + 36 : liste des conversations modernisée, commune aux
// écrans owner (ChatScreen) et sitter/walker (SitterChatScreen).
// Avatar + point vert, aperçu, heure, badge non-lus, glisser pour supprimer,
// états chargement / vide / erreur, tirer pour rafraîchir.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_states.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ChatListBody extends StatelessWidget {
  const ChatListBody({
    super.key,
    required this.session,
    required this.theme,
    required this.onOpen,
    this.onNewConversation,
  });

  final ChatSession session;
  final ChatRoleTheme theme;
  final void Function(ChatConversationBase conversation) onOpen;
  final VoidCallback? onNewConversation;

  Future<bool> _confirmDelete(
      BuildContext context, ChatConversationBase c) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text('chat_delete_conv_title'.tr),
        content: Text('chat_delete_conv_msg'.trParams({'name': c.contactName})),
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
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = session.isLoading.value;
      final error = session.errorMessage.value;
      final items = session.conversationsRx;
      if (loading && items.isEmpty) {
        return ChatLoadingState(theme: theme);
      }
      if (error.isNotEmpty && items.isEmpty) {
        final low = error.toLowerCase();
        final locked = low.contains('403') ||
            low.contains('permission') ||
            low.contains('forbidden');
        return ChatErrorState(
          theme: theme,
          locked: locked,
          title: locked
              ? 'chat_error_403_title'.tr
              : 'chat_error_loading_conversations'.tr,
          detail: error,
          onRetry: session.reloadConversations,
        );
      }
      if (items.isEmpty) {
        return ChatEmptyState(
          theme: theme,
          icon: Icons.forum_rounded,
          title: 'cs_list_empty_title'.tr,
          body: 'cs_list_empty_body'.tr,
          action: onNewConversation,
          actionLabel:
              onNewConversation == null ? null : 'chat_new_conversation_btn'.tr,
        );
      }
      return RefreshIndicator(
        color: theme.accent,
        onRefresh: session.reloadConversations,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 140.h),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final c = items[index];
            return Dismissible(
              key: ValueKey('conv_${c.id}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(context, c),
              onDismissed: (_) => session.deleteConversation(c.id),
              background: Container(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 22.w),
                decoration: BoxDecoration(
                  color: AppColors.errorColor,
                  borderRadius: BorderRadius.circular(22.r),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.white, size: 22.sp),
                    SizedBox(height: 2.h),
                    InterText(
                      text: 'cs_swipe_delete'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              child: _ConversationTile(
                conversation: c,
                theme: theme,
                onTap: () => onOpen(c),
                onLongPress: () async {
                  if (await _confirmDelete(context, c)) {
                    await session.deleteConversation(c.id);
                  }
                },
              ),
            );
          },
        ),
      );
    });
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.theme,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatConversationBase conversation;
  final ChatRoleTheme theme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.unreadCount > 0;
    return Material(
      color: AppColors.card(context),
      borderRadius: BorderRadius.circular(22.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(22.r),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.r),
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Row(
            children: [
              ChatAvatar(
                imageUrl: c.contactImage,
                size: 52,
                online: c.isOnline,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PoppinsText(
                            text: c.contactName,
                            fontSize: 15.sp,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        InterText(
                          text: chatListTime(context, c.lastMessageTime),
                          fontSize: 11.sp,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: unread
                              ? theme.accent
                              : AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Expanded(
                          child: InterText(
                            text: c.lastMessage.isNotEmpty
                                ? c.lastMessage
                                : chatPresenceLabel(c.isOnline, c.lastSeenAt),
                            fontSize: 12.5.sp,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.w400,
                            color: unread
                                ? AppColors.textPrimary(context)
                                : AppColors.textSecondary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unread) ...[
                          SizedBox(width: 8.w),
                          Container(
                            constraints: BoxConstraints(minWidth: 22.w),
                            padding: EdgeInsets.symmetric(
                                horizontal: 7.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: theme.accent,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
