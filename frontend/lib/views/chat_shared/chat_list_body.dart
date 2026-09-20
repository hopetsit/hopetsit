// v565 — points 16 + 36 : liste des conversations modernisée, commune aux
// écrans owner (ChatScreen) et sitter/walker (SitterChatScreen).
// Avatar + point vert, aperçu, heure, badge non-lus, glisser pour supprimer,
// états chargement / vide / erreur, tirer pour rafraîchir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_delete_sheet.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_receipt_ticks.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_states.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class ChatListBody extends StatefulWidget {
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

  @override
  State<ChatListBody> createState() => _ChatListBodyState();
}

class _ChatListBodyState extends State<ChatListBody> {
  ChatSession get session => widget.session;
  ChatRoleTheme get theme => widget.theme;
  void Function(ChatConversationBase conversation) get onOpen => widget.onOpen;
  VoidCallback? get onNewConversation => widget.onNewConversation;

  // v566 — bouton « Nouvelle conversation » : pilule quand la liste est en
  // haut ou à l'arrêt, rond pendant le défilement.
  Timer? _idle;

  void _setExpanded(bool v) {
    if (session.newChatExpanded.value != v) session.newChatExpanded.value = v;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final atTop = n.metrics.pixels <= 4;
    if (n is ScrollEndNotification) {
      _idle?.cancel();
      _idle = Timer(const Duration(milliseconds: 250), () {
        if (mounted) _setExpanded(true);
      });
    } else if (n is ScrollUpdateNotification && n.dragDetails != null ||
        n is ScrollStartNotification && n.dragDetails != null) {
      _idle?.cancel();
      _setExpanded(atTop);
    } else if (atTop) {
      _setExpanded(true);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // Après la frame : jamais de notification pendant un build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setExpanded(true);
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  // v569 — confirmation dans une FEUILLE DU BAS moderne (plus d'AlertDialog
  // brut) : avatar + nom, titre, phrase honnête sur l'effet réel côté serveur.
  // Retour haptique dès que le geste déclenche la feuille (glisser ou appui
  // long), comme dans les apps de messagerie.
  Future<bool> _confirmDelete(
      BuildContext context, ChatConversationBase c) async {
    HapticFeedback.mediumImpact();
    return showChatDeleteSheet(
      context,
      contactName: c.contactName,
      contactImage: c.contactImage,
      theme: theme,
      isOnline: c.isOnline,
    );
  }

  /// Suppression OPTIMISTE : le contrôleur retire la ligne tout de suite puis
  /// appelle le serveur ; en cas d'échec il la remet (et affiche l'erreur).
  /// Ici on n'ajoute que la bannière de succès.
  Future<void> _delete(ChatConversationBase c) async {
    final ok = await session.deleteConversation(c.id);
    if (!ok) return;
    CustomSnackbar.showSuccess(
      title: 'chatdel569_deleted_title'.tr,
      message: 'chatdel569_deleted_body'.tr,
    );
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
              onNewConversation == null ? null : 'cs_start_conversation'.tr,
        );
      }
      return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
        color: theme.accentOn(context),
        onRefresh: session.reloadConversations,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          // v569 — dégagement sous la pilule du menu : sur le Samsung de
          // Daniel le SafeArea parent n'applique rien, la dernière
          // conversation finissait sous le menu + la barre système.
          padding: EdgeInsets.fromLTRB(
              16.w, 6.h, 16.w, 140.h + appBottomInsetInsideSafeArea(context)),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) {
            final c = items[index];
            return Dismissible(
              key: ValueKey('conv_${c.id}'),
              direction: DismissDirection.endToStart,
              // v569 — le geste doit être franc (pas de suppression au frôlement).
              dismissThresholds: const {DismissDirection.endToStart: 0.35},
              confirmDismiss: (_) => _confirmDelete(context, c),
              onDismissed: (_) => _delete(c),
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
                // Appui long → EXACTEMENT la même feuille que le glissement.
                onLongPress: () async {
                  if (await _confirmDelete(context, c)) {
                    await _delete(c);
                  }
                },
              ),
            );
          },
        ),
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
    // v566 — coches devant l'aperçu quand le dernier message est le mien
    // (le préfixe « Vous : » devient alors redondant).
    final status = c.lastMessageMine && c.lastMessage.isNotEmpty
        ? c.lastMessageStatus
        : null;
    var preview = c.lastMessage;
    if (status != null) {
      final youPrefix = '${'cs_you'.tr}: ';
      if (preview.startsWith(youPrefix)) {
        preview = preview.substring(youPrefix.length);
      }
    }
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
                          // Heure d'une conversation non lue : accent posé sur
                          // la carte → version éclaircie en mode sombre.
                          color: unread
                              ? theme.accentOn(context)
                              : AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        if (status != null) ...[
                          ChatReceiptTicks(
                            status: status,
                            greyColor: AppColors.textSecondary(context),
                            size: 15,
                          ),
                          SizedBox(width: 4.w),
                        ],
                        Expanded(
                          child: InterText(
                            text: c.lastMessage.isNotEmpty
                                ? preview
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
