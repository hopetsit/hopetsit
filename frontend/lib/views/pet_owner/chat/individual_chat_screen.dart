import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/tracking_request_sheet.dart';
import 'package:hopetsit/views/pet_owner/walk/live_walk_map_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';
import 'package:hopetsit/widgets/report_dialog.dart';
import 'package:hopetsit/widgets/translate_message_button.dart';

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

  // v23.1.170 — Daniel : "il faut changer le bouton tu met suivre walker
  // ou sitter". On résout le rôle au moment du premier load (async) puis
  // on rebuild l'AppBar pour afficher "Suivre walker" / "Suivre sitter".
  // Avant la résolution, on garde "Suivre" générique.
  String? _providerRole;

  @override
  void initState() {
    super.initState();
    // Résolution async du rôle pour le bouton dynamique.
    _resolveProviderRole();

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

  // v23.1 part 68 — Bug 13 : "Suivre" button handler.
  // Looks up the most recent active paid booking with this contact, then
  // calls /bookings/:id/provider-location. Handles 4 cases :
  //   200      → opens PawMap (live location of the provider)
  //   402      → CoinShop tab 1 (PawFollow upsell)
  //   204      → snackbar "Le prestataire n'a pas encore partagé sa
  //              position"
  //   no book  → snackbar "Aucune réservation active à suivre"
  // v23.1.176 — Daniel : "demande suivre votre animale ds le chat ya pas".
  // Carte custom pour les messages type='pawfollow_request' qui affiche :
  //  - Icône + texte explicatif
  //  - Statut courant (pending / accepted / refused)
  //  - Si pending ET je suis le responder → boutons Accepter / Refuser
  // v23.1 part 200 — Daniel : "refonte carte chat pawfollow_request"
  // (mockup avec pet card top + dates orange + section GPS + badge statut +
  // boutons accept/refuse). Avant : on rendait une carte interne minimale
  // ici. Maintenant : on délègue au widget partagé `PawfollowRequestCard`
  // (qui est déjà utilisé côté sitter) — UI cohérente sur les 2 profils.
  // Le widget consomme directement le snapshot enrichi par le backend
  // (petName, petPhoto, startAt, endAt, lastLat/Lng, serviceType).
  Widget _buildPawfollowRequestCard(
    ChatMessage message,
    ChatController controller,
  ) {
    final myRole =
        (Get.find<GetStorage>().read<String>(StorageKeys.userRole) ?? 'owner')
            .toLowerCase();
    return PawfollowRequestCard(
      messageId: message.id,
      requesterRole: message.pawfollowRequesterRole,
      responderRole: message.pawfollowResponderRole,
      status: message.pawfollowStatus,
      myRole: myRole,
      onAccept: () => _respondPawfollow(message, 'accept'),
      onRefuse: () => _respondPawfollow(message, 'refuse'),
      // v23.1 part 200 — snapshot booking
      petName: message.pawfollowPetName,
      petPhoto: message.pawfollowPetPhoto,
      startAt: message.pawfollowStartAt,
      endAt: message.pawfollowEndAt,
      lastLat: message.pawfollowLastLat,
      lastLng: message.pawfollowLastLng,
      serviceType: message.pawfollowServiceType,
    );
  }

  Future<void> _respondPawfollow(
    ChatMessage message,
    String action,
  ) async {
    try {
      final repo = Get.find<OwnerRepository>();
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
      // Refresh la conversation pour récupérer le statut mis à jour.
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

  // v23.1.170 — résout le rôle du provider à partir des bookings actifs
  // pour pouvoir afficher dynamiquement "Suivre walker" / "Suivre sitter".
  Future<void> _resolveProviderRole() async {
    try {
      final repo = Get.find<OwnerRepository>();
      final bookings = await repo.getMyBookings();
      String norm(String s) =>
          s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final wantedName = norm(widget.contactName);
      final match = bookings.firstWhereOrNull((b) {
        final pay = (b.paymentStatus ?? '').toLowerCase();
        if (pay != 'paid') return false;
        return norm(b.sitter.name) == wantedName ||
            norm(b.sitter.name).contains(wantedName) ||
            wantedName.contains(norm(b.sitter.name));
      });
      final role = match?.providerRole;
      if (mounted && role != null && role.isNotEmpty) {
        setState(() => _providerRole = role);
      }
    } catch (_) {
      // silently fail — generic "Suivre" label remains
    }
  }

  String _followLabel() {
    final role = (_providerRole ?? '').toLowerCase();
    if (role == 'walker') return 'follow_button_walker'.tr;
    if (role == 'sitter') return 'follow_button_sitter'.tr;
    return 'follow_button_generic'.tr;
  }

  Future<void> _onSuivreTap() async {
    try {
      final repo = Get.find<OwnerRepository>();

      // v23.1 part 70 — Bug 12 : Daniel "bouton suivre chat marche pas".
      // Previous logic only matched booking where sitter.name == contactName,
      // which fails when :
      //   - contactName has trailing spaces / slightly different casing
      //   - the provider is a walker (booking.sitter is the populated
      //     sitter struct ; for walker bookings it contains the walker
      //     but the model holds different name normalization)
      //   - or the booking has multiple statuses ('paid' but also
      //     'agreed', 'accepted'). We were too restrictive.
      // Now we relax : ANY booking that's at least 'paid' (whatever
      // status flag) AND whose provider name fuzzily matches.
      final bookings = await repo.getMyBookings();
      String norm(String s) =>
          s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final wantedName = norm(widget.contactName);
      final candidate = bookings
          .where((b) {
            final pay = (b.paymentStatus ?? '').toLowerCase();
            final st  = (b.status ?? '').toLowerCase();
            if (pay != 'paid') return false;
            if (st == 'cancelled' || st == 'refunded' || st == 'completed') {
              return false;
            }
            return norm(b.sitter.name) == wantedName ||
                norm(b.sitter.name).contains(wantedName) ||
                wantedName.contains(norm(b.sitter.name));
          })
          .toList()
          // Most recent first.
          ..sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
      final bookingId = candidate.isNotEmpty ? candidate.first.id : null;

      // v23.1.193 — Daniel : "chat rien changer aucun bouton". Avant on
      // n'ouvrait le sheet QUE si bookingId trouve via fuzzy match nom
      // → quand le match foirait (espaces, casse, walker vs sitter),
      // Daniel ne voyait rien. Maintenant on ouvre TOUJOURS le sheet :
      //   - Si booking trouve → onConfirm = requestLiveTracking(bookingId)
      //   - Sinon → onConfirm = requestLiveTrackingByConversation
      // Le sheet utilise booking pour les details si dispo, sinon
      // fallback sur les infos de la conversation (contact name + avatar).
      final BookingModel? booking =
          candidate.isNotEmpty ? candidate.first : null;
      if (mounted) {
        await Get.to(() => TrackingRequestSheet(
              booking: booking,
              fallbackContactName: widget.contactName,
              fallbackContactImage: widget.contactImage,
              onConfirm: () async {
                try {
                  if (booking != null && bookingId != null && bookingId.isNotEmpty) {
                    await repo.requestLiveTracking(bookingId: bookingId);
                  } else {
                    await repo.requestLiveTrackingByConversation(
                      conversationId: widget.conversationId,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    CustomSnackbar.showError(
                      title: 'follow_unavailable_title'.tr,
                      message: e.toString()
                          .replaceAll('ApiException:', '').trim(),
                    );
                  }
                  return;
                }
                if (mounted) {
                  CustomSnackbar.showSuccess(
                    title: 'pawfollow_request_sent_title'.tr,
                    message: 'pawfollow_request_sent_msg'.tr,
                  );
                  await chatController.loadChatMessages(
                    widget.conversationId,
                    contactName: widget.contactName,
                  );
                }
              },
            ));
      }
    } catch (e) {
      CustomSnackbar.showError(
        title: 'follow_unavailable_title'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
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
        // v23.1 part 68 — Bug 13 : "Suivre" button in chat AppBar.
        // Calls /api/v1/bookings/:id/provider-location which returns
        //   200 { coordinates } → open PawMap centered on provider
        //   402 PAWFOLLOW_REQUIRED → upsell sheet (open CoinShop tab 1)
        //   204 NO_LOCATION_YET → snackbar "Provider hasn't shared yet"
        //   404 / 409 → "no active booking" snackbar
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: GestureDetector(
              onTap: _onSuivreTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4324), Color(0xFFFF6B45)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14.sp, color: Colors.white),
                    SizedBox(width: 4.w),
                    // v23.1.172 — Daniel : "change le bouton suivre avec
                    // suivre en direct mon animal pour owner". Label fixe
                    // (plus de label dynamique walker/sitter) car Daniel
                    // veut un wording plus clair côté propriétaire.
                    InterText(
                      text: 'follow_button_live_my_pet'.tr,
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
    // v23.1.176 — Daniel : "demande suivre votre animale ds le chat ya pas".
    // Carte avec boutons Accepter/Refuser quand un walker/sitter demande
    // à suivre ou inversement quand l'owner demande à suivre.
    if (message.isPawfollowRequest) {
      return _buildPawfollowRequestCard(message, controller);
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
              message.message,
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
      // v19.1.3 — long-press: own messages → Delete sheet; received → Report.
      onLongPress: message.isDeleted
          ? null
          : () {
              if (message.isFromCurrentUser) {
                _showDeleteMessageSheet(message, controller);
              } else {
                ReportDialog.show(
                  context: context,
                  targetType: 'message',
                  targetId: message.id,
                  conversationId: widget.conversationId,
                  snapshot: message.message,
                );
              }
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
              // v23.1.193 — Daniel : "peux pas effacer message". Le 3-pts
              // discret n'etait pas trouve. Maintenant : bouton texte
              // "Effacer" rouge visible a cote du timestamp pour les
              // messages envoyes par soi → 1 tap ouvre la sheet Supprimer.
              if (!message.isDeleted && message.isFromCurrentUser)
                ...[
                  const Spacer(),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      // v23.1.193 (verifie 3x) — Daniel : "peux pas
                      // effacer message". Le 3-pts ancien ouvrait un
                      // bottom-sheet PUIS une dialog confirm = 3 taps.
                      // Maintenant tap direct → dialog confirm = 2 taps.
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
          if (message.isDeleted)
            Padding(
              padding: EdgeInsets.only(left: 41.w),
              child: Row(
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 13.sp,
                    color: AppColors.textSecondary(context),
                  ),
                  SizedBox(width: 6.w),
                  InterText(
                    text: 'chat_message_deleted'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            )
          else if (message.message.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.only(left: 41.w),
              child: InterText(
                text: message.message,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary(context),
              ),
            ),
            // v23.1 part 105 — bouton "Traduire" sous chaque message texte.
            // Utilise la langue active de l'app comme cible.
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

  // v19.1.3 — bottom sheet with Delete action for own messages.
  void _showDeleteMessageSheet(ChatMessage message, ChatController controller) {
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
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorColor,
                  ),
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
                  leading: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary(context),
                  ),
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
