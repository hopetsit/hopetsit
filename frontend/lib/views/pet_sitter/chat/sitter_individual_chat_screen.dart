import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/address_share_card.dart';
import 'package:hopetsit/widgets/phone_share_card.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';
import 'package:hopetsit/widgets/translate_message_button.dart';

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
                      memCacheWidth: 126, // v234.
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
        // v23.1.170 — Daniel : "pareil du coter de walker et sitter y
        // doive poivoir envoyer au owner suis moi et que les 3 profile
        // recoive les notification". Bouton miroir côté sitter/walker :
        // un tap envoie POST /bookings/:id/follow-request → push notif à
        // l'owner avec deep-link vers la LiveWalkMapScreen.
        actions: [
          // v23.1 part 240 — partager mon adresse pour RDV (cf
          // address_share_card.dart + bottom_nav_wrapper note).
          Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: GestureDetector(
              onTap: _onShareAddressTap,
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4324).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4324).withValues(alpha: 0.40),
                    width: 1.2,
                  ),
                ),
                child: Icon(Icons.home_rounded,
                    size: 18.sp, color: const Color(0xFFEF4324)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: GestureDetector(
              onTap: _onFollowMeTap,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_location_rounded,
                        size: 14.sp, color: Colors.white),
                    SizedBox(width: 4.w),
                    // v23.1.172 — Daniel : "Partager ma position en direct"
                    // côté walker/sitter (au lieu de "Suis-moi" v170).
                    InterText(
                      text: 'follow_share_position_button'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (chatController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // v18.8 — épuré : pas de raw message, et affichage uniquement si
        // la conversation n'a pas encore de messages en cache.
        // v23.1 part 227 — mirroir IndividualChatScreen owner : distinguer
        // 403 (cadenas) du wifi-off, afficher detail backend, retry.
        if (chatController.errorMessage.value.isNotEmpty &&
            chatController.currentChatMessages.isEmpty) {
          final raw = chatController.errorMessage.value;
          final is403 = raw.toLowerCase().contains('403') ||
              raw.toLowerCase().contains('permission') ||
              raw.toLowerCase().contains('forbidden') ||
              raw.toLowerCase().contains('not a chat participant') ||
              raw.toLowerCase().contains('payment required');
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
                    size: 42.sp,
                    color: is403 ? Colors.orange : AppColors.greyColor,
                  ),
                  SizedBox(height: 10.h),
                  InterText(
                    text: is403
                        ? 'chat_error_403_title'.tr
                        : 'chat_error_loading_messages'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: InterText(
                      text: raw,
                      fontSize: 11.sp,
                      color: AppColors.greyText,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  OutlinedButton.icon(
                    onPressed: () {
                      chatController.errorMessage.value = '';
                      chatController
                          .loadChatMessages(chatController.currentChatId.value);
                    },
                    icon: Icon(Icons.refresh_rounded, size: 18.sp),
                    label: Text('chat_retry'.tr),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            children: [
              // Messages List — v477 : fond légèrement teinté de la couleur du
              // rôle (bleu sitter / vert walker), façon maquette Conversation.
              Expanded(
                child: Container(
                  color: AppColors.primaryColor.withValues(alpha: 0.05),
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
              ),

              // Message Input
              // v500 — verrou « paiement requis » : panneau explicatif clair
              // (avant : erreur générique et clavier qui se fermait sans raison).
              chatController.isPaymentRequired.value
                  ? _buildPaymentGateNotice()
                  : chatController.isChatLocked.value
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
    // v23.1.176 — Daniel : carte avec boutons Accepter/Refuser quand
    // l'owner demande à suivre OU quand on a déjà demandé soi-même.
    // v23.1 part 240 — carte "Adresse pour RDV" partagee.
    if (message.isAddressShare) {
      return AddressShareCard(
        address: message.addressShareAddress,
        city: message.addressShareCity,
        lat: message.addressShareLat,
        lng: message.addressShareLng,
        isFromCurrentUser: message.isFromCurrentUser,
      );
    }
    // v449 — carte « Numéro de téléphone » partagé (3 rôles).
    if (message.isPhoneShare) {
      return PhoneShareCard(
        phone: message.phoneShareNumber,
        isFromCurrentUser: message.isFromCurrentUser,
      );
    }
    if (message.isPawfollowRequest) {
      final myRole = Get.find<GetStorage>()
              .read<String>(StorageKeys.userRole) ??
          'sitter';
      return PawfollowRequestCard(
        messageId: message.id,
        requesterRole: message.pawfollowRequesterRole,
        responderRole: message.pawfollowResponderRole,
        status: message.pawfollowStatus,
        myRole: myRole.toLowerCase(),
        onAccept: () => _respondPawfollow(message, 'accept'),
        onRefuse: () => _respondPawfollow(message, 'refuse'),
        // v23.1 part 200 — snapshot booking pour la refonte mockup
        petName: message.pawfollowPetName,
        petPhoto: message.pawfollowPetPhoto,
        startAt: message.pawfollowStartAt,
        endAt: message.pawfollowEndAt,
        lastLat: message.pawfollowLastLat,
        lastLng: message.pawfollowLastLng,
        serviceType: message.pawfollowServiceType,
      );
    }
    if (message.isSystem) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 24.w),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.grey300Color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              message.systemDisplayText,
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


    return GestureDetector(
      onLongPress: (message.isDeleted || !message.isFromCurrentUser)
          ? null
          : () => _showSitterDeleteSheet(message, controller),
      child: Container(
      margin: EdgeInsets.only(bottom: 15.h),
      child: Column(
        // v480 — maquette « Conversation » : reçu = bulle blanche à gauche,
        // envoyé = bulle colorée à droite (alignement par rôle).
        crossAxisAlignment: message.isFromCurrentUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Sender info and timestamp
          Row(
            children: [
              // v485b — maquette « Conversation » : avatar seulement pour les
              // messages REÇUS (envoyés à droite sans avatar).
              if (!message.isFromCurrentUser)
              CircleAvatar(
                radius: 18.r,
                backgroundColor: AppColors.grey300Color,
                backgroundImage:
                    message.senderImage.isNotEmpty &&
                        (message.senderImage.startsWith('http://') ||
                            message.senderImage.startsWith('https://'))
                    // v23.1 part 250 — perf : maxWidth 120 (avatar 36px),
                    // tres repete par bulle de message.
                    ? CachedNetworkImageProvider(message.senderImage, maxWidth: 120)
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
              if (!message.isFromCurrentUser) SizedBox(width: 8.w),
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
              // v23.1.193 — Bouton "Effacer" visible (au lieu du 3-pts).
              if (!message.isDeleted && message.isFromCurrentUser)
                ...[
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      // v23.1.193 (verifie 3x) — 1 tap → dialog confirm
                      // (au lieu de Sheet → Dialog = 3 taps).
                      onTap: () async {
                        final confirmed = await Get.dialog<bool>(
                          AlertDialog(
                            title: Text('chat_delete_message'.tr),
                            content: Text('chat_delete_message_confirm'.tr),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(result: false),
                                child: Text('common_cancel'.tr),
                              ),
                              TextButton(
                                onPressed: () => Get.back(result: true),
                                child: Text(
                                  'chat_delete_message'.tr,
                                  style: TextStyle(
                                      color: AppColors.errorColor),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await controller.deleteMessage(message.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(10.r),
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
                        memCacheWidth: 450, // v234.
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
          if (message.isDeleted)
            Padding(
              padding: EdgeInsets.only(left: 41.w),
              child: Row(
                children: [
                  Icon(Icons.block_rounded, size: 13.sp, color: AppColors.textSecondary(context)),
                  SizedBox(width: 6.w),
                  InterText(
                    text: 'chat_message_deleted'.tr,
                    fontSize: 13.sp,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            )
          else if (message.message.isNotEmpty) ...[
            // v480 — bulle de message (colorée si envoyée, blanche si reçue).
            Container(
              constraints: BoxConstraints(maxWidth: 250.w),
              margin: EdgeInsets.only(
                  left: message.isFromCurrentUser ? 0 : 41.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: message.isFromCurrentUser
                    ? AppColors.primaryColor
                    : AppColors.card(context),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft:
                      Radius.circular(message.isFromCurrentUser ? 16.r : 4.r),
                  bottomRight:
                      Radius.circular(message.isFromCurrentUser ? 4.r : 16.r),
                ),
                border: message.isFromCurrentUser
                    ? null
                    : Border.all(color: AppColors.grey300Color),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InterText(
                text: message.message,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: message.isFromCurrentUser
                    ? Colors.white
                    : AppColors.textPrimary(context),
              ),
            ),
            // v23.1 part 105 — bouton "Traduire" (cf TranslateMessageButton).
            TranslateMessageButton(
              text: message.message,
              targetLang: Get.locale?.languageCode ?? 'fr',
              leftPadding: 41.w,
            ),
          ],
        ],
      ),
      ),
    );
  }

  // v19.1.3 — Sitter: long-press own message → Delete sheet.
  void _showSitterDeleteSheet(
    SitterChatMessage message,
    SitterChatController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: AppColors.errorColor),
                  title: InterText(
                    text: 'chat_delete_message'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.errorColor,
                  ),
                  subtitle: InterText(
                    text: 'chat_delete_message_subtitle'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final confirmed = await Get.dialog<bool>(
                      AlertDialog(
                        title: Text('chat_delete_message'.tr),
                        content: Text('chat_delete_message_confirm'.tr),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(result: false),
                            child: Text('common_cancel'.tr),
                          ),
                          TextButton(
                            onPressed: () => Get.back(result: true),
                            child: Text(
                              'chat_delete_message'.tr,
                              style: TextStyle(color: AppColors.errorColor),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await controller.deleteMessage(message.id);
                    }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                  title: InterText(
                    text: 'common_cancel'.tr,
                    fontSize: 14.sp,
                    color: AppColors.textPrimary(context),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
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
          // v449 — Partager mon numéro (3 rôles) avec confirmation explicite.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _onSharePhoneTap,
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

  /// v500 — Daniel : « rajoute un message pour ne pas laisser l'utilisateur
  /// sans compréhension ». Panneau clair côté prestataire quand le backend
  /// verrouille le chat tant que la réservation n'est pas payée (le paiement
  /// vient de l'owner → pas de bouton Payer ici, juste l'explication + la
  /// boutique d'abonnements).
  Widget _buildPaymentGateNotice() {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_rounded,
                size: 20.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'chat_gate_title'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'chat_gate_body'.tr,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Get.to(() => const CoinShopScreen()),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
              ),
              child: Text(
                'chat_gate_shop'.tr,
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
