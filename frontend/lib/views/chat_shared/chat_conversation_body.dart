// v565 — corps de l'écran de discussion, commun owner / sitter / walker :
// états chargement / erreur / vide, liste des messages avec séparateurs de
// jour, cartes spéciales (PawFollow, numéro, adresse, système), défilement
// vers le message cité, et la zone du bas fournie par l'écran (saisie ou
// verrous paiement).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/chat_shared/chat_bubble.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_receipt_ticks.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_states.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/chat_time.dart';
import 'package:hopetsit/widgets/address_share_card.dart';
import 'package:hopetsit/widgets/phone_share_card.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

class ChatConversationBody extends StatefulWidget {
  const ChatConversationBody({
    super.key,
    required this.session,
    required this.theme,
    required this.conversationId,
    required this.contactName,
    required this.specialCardBuilder,
    required this.bottomBuilder,
  });

  final ChatSession session;
  final ChatRoleTheme theme;
  final String conversationId;
  final String contactName;

  /// Rendu des cartes propres au rôle (demande PawFollow) ; null = bulle.
  final Widget? Function(ChatMessageBase message) specialCardBuilder;

  /// Zone du bas (saisie, ou panneau « paiement requis » / « verrouillé »).
  final Widget Function() bottomBuilder;

  @override
  State<ChatConversationBody> createState() => _ChatConversationBodyState();
}

class _ChatConversationBodyState extends State<ChatConversationBody>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  String? _highlightId;

  /// v569 — la conversation affichée vient d'être supprimée (ici ou sur un
  /// autre de mes appareils) → on ferme l'écran de discussion.
  Worker? _deletedWatch;

  // v566 — « lu » façon WhatsApp : la conversation n'est LUE que tant que cet
  // écran est affiché et l'app au premier plan. (currentChatId du contrôleur
  // n'est jamais remis à zéro au retour à la liste : il ne suffit pas.)
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.setChatVisible(widget.conversationId, true);
    _deletedWatch = ever<String>(widget.session.deletedConversationId, (id) {
      if (!mounted || id != widget.conversationId) return;
      // Après la frame : jamais de pop pendant un build / une notification.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.session
          .setChatVisible(widget.conversationId, true, markRead: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.session.setChatVisible(widget.conversationId, false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.setChatVisible(widget.conversationId, false);
    _deletedWatch?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Tap sur une citation → défile vers l'original et le surligne.
  Future<void> _scrollToMessage(String id) async {
    final list = widget.session.messagesRx;
    final idx = list.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    // Liste inversée : l'index visuel compte depuis le bas.
    final reversedIndex = list.length - 1 - idx;
    Future<bool> tryEnsure() async {
      final ctx = _keyFor(id).currentContext;
      if (ctx == null) return false;
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      return true;
    }

    if (!await tryEnsure() && _scroll.hasClients) {
      final target = (reversedIndex * 96.0)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      await _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await tryEnsure();
    }
    if (!mounted) return;
    setState(() => _highlightId = id);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _highlightId == id) setState(() => _highlightId = null);
    });
  }

  Widget _daySeparator(BuildContext context, DateTime d) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.card(context).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            chatDayLabel(context, d),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _systemBubble(BuildContext context, ChatMessageBase m) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 24.w),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            // Audit mode sombre — le gris clair d'origine donnait une pastille
            // laiteuse sous un texte clair au milieu de la conversation.
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.grey300Color.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Text(
            m.systemDisplayText,
            style: TextStyle(
              fontSize: 12.sp,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, ChatMessageBase m, ChatMessageBase? older,
      ChatMessageBase? newer, {bool showReadLabel = false}) {
    Widget content;
    final special = widget.specialCardBuilder(m);
    if (special != null) {
      content = special;
    } else if (m.isAddressShare) {
      content = AddressShareCard(
        address: m.addressShareAddress,
        city: m.addressShareCity,
        lat: m.addressShareLat,
        lng: m.addressShareLng,
        isFromCurrentUser: m.isFromCurrentUser,
      );
    } else if (m.isPhoneShare) {
      content = PhoneShareCard(
        phone: m.phoneShareNumber,
        isFromCurrentUser: m.isFromCurrentUser,
      );
    } else if (m.isSystem) {
      content = _systemBubble(context, m);
    } else {
      // Avatar seulement sur le dernier message d'une suite reçue.
      final showAvatar = newer == null ||
          newer.isFromCurrentUser != m.isFromCurrentUser ||
          newer.isSystem;
      content = ChatMessageBubble(
        message: m,
        session: widget.session,
        theme: widget.theme,
        conversationId: widget.conversationId,
        contactName: widget.contactName,
        onQuoteTap: _scrollToMessage,
        highlighted: _highlightId == m.id,
        showAvatar: showAvatar,
        showReadLabel: showReadLabel,
      );
    }
    // v566 — cartes (adresse, numéro, PawFollow) : « Lu · heure » posé dessous.
    if (showReadLabel && m.readAt != null && content is! ChatMessageBubble) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [content, ChatReadLabel(readAt: m.readAt!)],
      );
    }
    final needsDay = older == null || !chatSameDay(older.timestamp, m.timestamp);
    return KeyedSubtree(
      key: _keyFor(m.id),
      child: needsDay
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_daySeparator(context, m.timestamp), content],
            )
          : content,
    );
  }

  /// Clavier visible ? `MediaQuery.viewInsets` est remis à 0 par le Scaffold
  /// (`resizeToAvoidBottomInset`), on interroge donc la fenêtre elle-même.
  bool _keyboardOpen(BuildContext context) {
    final view = View.of(context);
    return view.viewInsets.bottom > 0;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final t = widget.theme;
    return Container(
      color: t.background(context),
      child: Obx(() {
        final msgs = s.messagesRx;
        final loading = s.isMessagesLoading.value;
        final error = s.errorMessage.value;
        // Lectures pour que l'Obx suive aussi ces états (règle GetX).
        final paymentRequired = s.isPaymentRequired.value;
        final locked = s.isChatLocked.value;

        if (loading && msgs.isEmpty) {
          return ChatLoadingState(theme: t, label: 'cs_loading_messages'.tr);
        }
        if (error.isNotEmpty && msgs.isEmpty && !paymentRequired) {
          final low = error.toLowerCase();
          final is403 = low.contains('403') ||
              low.contains('permission') ||
              low.contains('forbidden') ||
              low.contains('not a chat participant') ||
              low.contains('payment required');
          return ChatErrorState(
            theme: t,
            locked: is403,
            title: is403
                ? 'chat_error_403_title'.tr
                : 'chat_error_loading_messages'.tr,
            detail: error,
            onRetry: () {
              s.errorMessage.value = '';
              s.loadChatMessages(widget.conversationId);
            },
          );
        }
        // v566 — « Lu · heure » sous le DERNIER de mes messages lus.
        String lastReadId = '';
        for (var k = msgs.length - 1; k >= 0; k--) {
          final x = msgs[k];
          if (x.isFromCurrentUser && !x.isDeleted && x.readAt != null) {
            lastReadId = x.id;
            break;
          }
        }
        return SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: msgs.isEmpty
                    ? ChatEmptyState(
                        theme: t,
                        icon: locked || paymentRequired
                            ? Icons.lock_outline_rounded
                            : Icons.waving_hand_rounded,
                        title: 'cs_empty_title'.tr,
                        body: 'cs_empty_body'.tr,
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
                        itemCount: msgs.length,
                        itemBuilder: (context, index) {
                          final i = msgs.length - 1 - index;
                          final m = msgs[i];
                          final older = i > 0 ? msgs[i - 1] : null;
                          final newer = i < msgs.length - 1 ? msgs[i + 1] : null;
                          return _item(context, m, older, newer,
                              showReadLabel: m.id == lastReadId);
                        },
                      ),
              ),
              // v569 — le SafeArea ne protège pas le bas sur le Samsung de
              // Daniel (inset annoncé à 0) : la zone de saisie (micro, « + »,
              // envoyer) finissait sous la barre système. Clavier ouvert, le
              // Scaffold a déjà consommé `viewInsets` : on lit la fenêtre
              // brute pour ne pas laisser un trou au-dessus du clavier.
              Padding(
                padding: EdgeInsets.only(
                  bottom: _keyboardOpen(context)
                      ? 0
                      : appBottomInsetInsideSafeArea(context),
                ),
                child: widget.bottomBuilder(),
              ),
            ],
          ),
        );
      }),
    );
  }
}
