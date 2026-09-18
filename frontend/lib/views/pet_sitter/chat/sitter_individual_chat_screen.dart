import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/chat_shared/chat_composer.dart';
import 'package:hopetsit/views/chat_shared/chat_conversation_body.dart';
import 'package:hopetsit/views/chat_shared/chat_gates.dart';
import 'package:hopetsit/views/chat_shared/chat_header.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/contacts_locked_sheet.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';
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

  /// v500 — Daniel : « le clavier s'ouvre mais se referme en une demi-
  /// seconde ». FocusNode STABLE possédé par le State : sans lui, le
  /// TextField gérait son focus en interne et un rebuild déclenché ~0,5 s
  /// après l'ouverture (fin du rechargement réseau, resync badge, événement
  /// socket) pouvait le faire sauter → clavier fermé. Ce nœud survit à
  /// TOUS les rebuilds.
  final FocusNode _inputFocusNode = FocusNode();

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
      // v500 — didChangeDependencies se déclenche AUSSI quand le CLAVIER
      // s'ouvre (MediaQuery change). Si l'utilisateur est en train d'écrire,
      // on ne recharge JAMAIS (le rechargement faisait sauter le focus →
      // clavier refermé « tout seul »).
      if (_inputFocusNode.hasFocus) return;
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
    _inputFocusNode.dispose();
    super.dispose();
  }

  // v23.1.176 — handler des boutons Accepter / Refuser sur la carte
  // pawfollow_request. Appelle le repo + refresh la conversation.
  Future<void> _respondPawfollow(
    SitterChatMessage message,
    String action,
  ) async {
    try {
      final repo = Get.find<SitterRepository>();
      await repo.respondPawfollowRequest(
        messageId: message.id,
        action: action,
      );
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: action == 'accept'
            ? 'pawfollow_accepted_title'.tr
            : 'pawfollow_refused_title'.tr,
        message: action == 'accept'
            ? 'pawfollow_accepted_msg'.tr
            : 'pawfollow_refused_msg'.tr,
      );
      await chatController.loadChatMessages(
        widget.conversationId,
        contactName: widget.contactName,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
  }

  // v23.1.170 — handler du bouton "Suis-moi" miroir côté sitter/walker.
  // 1. Cherche un booking actif (paid + non-cancelled) avec ce owner
  // 2. POST /bookings/:id/follow-request → backend push notif à l'owner
  // 3. Snackbar de confirmation
  Future<void> _onFollowMeTap() async {
    // v23.1.256 — DEEP FIX : on envoie TOUJOURS la demande de suivi dans la
    // conversation actuellement OUVERTE (widget.conversationId). Avant, on
    // cherchait un booking par NOM (norm(owner.name)) + paymentStatus=='paid'
    // — fragile : si le match échouait ou si paymentStatus manquait, on
    // basculait sur un autre chemin qui pouvait 403er ou créer la carte dans
    // une autre conversation → "la demande s'affiche dans aucun profil". Le
    // backend (requestLiveTrackingByConversation) accepte désormais tout
    // participant (booking OU friendChat) et crée la carte dans CETTE
    // conversation. On capture aussi la position GPS pour que l'owner puisse
    // suivre. Puis on recharge le chat → la carte apparaît immédiatement.
    try {
      final repo = Get.find<SitterRepository>();
      double? lat;
      double? lng;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {/* on continue sans coords */}

      await repo.requestLiveTrackingByConversation(
        conversationId: widget.conversationId,
        lat: lat,
        lng: lng,
      );
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'follow_request_sent_title'.tr,
        message: 'follow_request_sent_msg'.tr,
      );
      // Recharge le chat → la carte pawfollow_request apparaît tout de suite
      // côté expéditeur (sans dépendre du socket).
      await chatController.loadChatMessages(
        widget.conversationId,
        contactName: widget.contactName,
      );
    } catch (e) {
      if (!mounted) return;
      // v23.1.349 — service fini → message clair traduit (cf côté owner).
      final raw = e.toString();
      if (raw.contains('TRACKING_ENDED') || raw.contains('Service is over')) {
        CustomSnackbar.showWarning(
          title: 'tracking_service_over_title'.tr,
          message: 'tracking_service_over_msg'.tr,
        );
        return;
      }
      CustomSnackbar.showError(
        title: 'follow_unavailable_title'.tr,
        message: raw.replaceAll('ApiException:', '').trim(),
      );
    }
  }

  /// v23.1 part 240 — Daniel : "sur les 3 profile rajoute partager mon
  /// adresse pour rdv". Endpoint POST /conversations/:id/share-address
  /// est disponible pour les 3 roles ; ChatRepository.shareAddress en
  /// fait le wiring (cf chat_repository.dart).
  Future<void> _onShareAddressTap() async {
    try {
      final repo = Get.find<ChatRepository>();
      await repo.shareAddress(conversationId: widget.conversationId);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'address_share_sent_title'.tr,
        message: 'address_share_sent_msg'.tr,
      );
      await chatController.loadChatMessages(
        widget.conversationId,
        contactName: widget.contactName,
      );
    } catch (e) {
      if (!mounted) return;
      // v565 — point 14 : verrou contacts (402 CONTACTS_LOCKED) → feuille.
      if (maybeShowContactsLocked(context, e, theme: _theme)) return;
      final raw = e.toString().replaceAll('ApiException:', '').trim();
      final isMissingAddress = raw.toLowerCase().contains('no address');
      CustomSnackbar.showError(
        title: isMissingAddress
            ? 'address_share_no_profile_title'.tr
            : 'common_error'.tr,
        message: isMissingAddress
            ? 'address_share_no_profile_msg'.tr
            : raw,
      );
    }
  }

  /// v449 — Daniel : « améliore le partage de mon numéro sur les 3 profils ».
  /// Confirmation explicite (le numéro devient visible par l'interlocuteur),
  /// puis POST /conversations/:id/share-phone (role-agnostic) + feedback.
  Future<void> _onSharePhoneTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.card(dctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: InterText(
          text: 'phone_share_confirm_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(dctx),
        ),
        content: InterText(
          text: 'phone_share_confirm_msg'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(dctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(dctx),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: InterText(
              text: 'chat_share_phone_button'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = Get.find<ChatRepository>();
      await repo.sharePhone(conversationId: widget.conversationId);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'phone_share_sent_title'.tr,
        message: 'phone_share_sent_msg'.tr,
      );
      await chatController.loadChatMessages(widget.conversationId);
    } catch (e) {
      if (!mounted) return;
      // v565 — point 14 : verrou contacts (402 CONTACTS_LOCKED) → feuille.
      if (maybeShowContactsLocked(context, e, theme: _theme)) return;
      final raw = e.toString().replaceAll('ApiException:', '').trim();
      final isMissing = raw.toLowerCase().contains('no phone');
      CustomSnackbar.showError(
        title: isMissing
            ? 'phone_share_no_profile_title'.tr
            : 'common_error'.tr,
        message: isMissing ? 'phone_share_no_profile_msg'.tr : raw,
      );
    }
  }

  // ── v565 — écran de discussion partagé (views/chat_shared/) ──────────────
  // Points 13 / 16 / 18 / 36 : en-tête avec présence, bulles Apple, menu « + »
  // (photo, caméra, vidéo, vocal, numéro, adresse, PawFollow, traduction),
  // réponse à un message, états vide / chargement / erreur. Les actions
  // propres au rôle restent dans cet écran (sitter).
  ChatRoleTheme get _theme => ChatRoleTheme.forRole(chatController.myRole);

  Widget? _specialCard(ChatMessageBase m) {
    if (m is SitterChatMessage && m.isPawfollowRequest) {
      final myRole = (Get.find<GetStorage>().read<String>(StorageKeys.userRole) ??
              'sitter')
          .toLowerCase();
      return PawfollowRequestCard(
        messageId: m.id,
        requesterRole: m.pawfollowRequesterRole,
        responderRole: m.pawfollowResponderRole,
        status: m.pawfollowStatus,
        myRole: myRole,
        onAccept: () => _respondPawfollow(m, 'accept'),
        onRefuse: () => _respondPawfollow(m, 'refuse'),
        // v23.1 part 200 — snapshot booking pour la refonte mockup
        petName: m.pawfollowPetName,
        petPhoto: m.pawfollowPetPhoto,
        startAt: m.pawfollowStartAt,
        endAt: m.pawfollowEndAt,
        lastLat: m.pawfollowLastLat,
        lastLng: m.pawfollowLastLng,
        serviceType: m.pawfollowServiceType,
      );
    }
    return null;
  }

  List<ChatMenuItem> _roleMenuItems() => [
        ChatMenuItem(
          icon: Icons.phone_rounded,
          label: 'chat_share_phone_button'.tr,
          subtitle: 'cs_action_share_phone_sub'.tr,
          color: _theme.accent,
          onTap: _onSharePhoneTap,
        ),
        ChatMenuItem(
          icon: Icons.home_rounded,
          label: 'cs_action_share_address'.tr,
          subtitle: 'cs_action_share_address_sub'.tr,
          color: _theme.accentDark,
          onTap: _onShareAddressTap,
        ),
        ChatMenuItem(
          icon: Icons.share_location_rounded,
          label: 'follow_share_position_button'.tr,
          subtitle: 'cs_action_pawfollow_sub'.tr,
          color: const Color(0xFF7C3AED),
          onTap: _onFollowMeTap,
        ),
      ];

  void _sendText() {
    if (!mounted || _localMessageController.text.trim().isEmpty) return;
    try {
      // Sync local controller to shared controller before sending (v500).
      chatController.messageController.text = _localMessageController.text;
      chatController.sendMessage();
    } catch (_) {
      // Controller might be disposed, skip sending.
    }
  }

  Widget _bottom() {
    // Lit les .value dans l'Obx du corps (chat_conversation_body) ; ici on
    // choisit simplement le panneau.
    if (chatController.isPaymentRequired.value) {
      return ChatPaymentGate(theme: _theme);
    }
    if (chatController.isChatLocked.value) {
      return ChatLockedNotice(theme: _theme);
    }
    return ChatComposer(
      session: chatController,
      theme: _theme,
      textController: _localMessageController,
      focusNode: _inputFocusNode,
      onSendText: _sendText,
      contactName: widget.contactName,
      roleMenuItems: _roleMenuItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: ChatHeaderBar(
        session: chatController,
        theme: t,
        contactName: widget.contactName,
        contactImage: widget.contactImage,
        actions: [
          ChatHeaderPill(
            icon: Icons.share_location_rounded,
            label: 'follow_share_position_button'.tr,
            onTap: _onFollowMeTap,
            theme: t,
          ),
        ],
      ),
      body: ChatConversationBody(
        session: chatController,
        theme: t,
        conversationId: widget.conversationId,
        contactName: widget.contactName,
        specialCardBuilder: _specialCard,
        bottomBuilder: _bottom,
      ),
    );
  }
}
