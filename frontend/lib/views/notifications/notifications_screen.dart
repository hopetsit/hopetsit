import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/notifications/notification_application_view_screen.dart';
import 'package:hopetsit/views/notifications/notification_post_view_screen.dart';
import 'package:hopetsit/views/notifications/notification_sitter_application_card_view_screen.dart';
import 'package:hopetsit/views/payment/stripe_payment_screen.dart';
import 'package:hopetsit/views/pet_owner/booking-application/owner_booking_detail_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  NotificationsController get _c {
    if (!Get.isRegistered<NotificationsController>()) {
      return Get.put(NotificationsController(), permanent: true);
    }
    return Get.find<NotificationsController>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 160) {
      _c.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() => _c.refreshAll();

  Future<void> _onTapNotification(AppNotificationModel n) async {
    await _c.markAsRead(n);
    if (!mounted) return;
    await _navigateForNotification(context, n);
  }

  String? _dataString(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Resolves display name and avatar for a conversation (chat list API + optional payload).
  Future<({String name, String image})> _resolveChatContactForNotification({
    required String conversationId,
    required bool isSitter,
    required Map<String, dynamic> data,
  }) async {
    String name =
        _dataString(data, 'senderName') ??
        _dataString(data, 'actorName') ??
        _dataString(data, 'contactName') ??
        '';
    String image =
        _dataString(data, 'senderImage') ??
        _dataString(data, 'contactImage') ??
        _dataString(data, 'actorImage') ??
        '';

    if (isSitter) {
      if (!Get.isRegistered<SitterChatController>()) {
        Get.put(
          SitterChatController(
            Get.find<ChatRepository>(),
            storage: Get.find<GetStorage>(),
          ),
        );
      }
      final c = Get.find<SitterChatController>();
      await c.reloadConversations();
      for (final conv in c.conversations) {
        if (conv.id == conversationId) {
          if (name.isEmpty) name = conv.contactName;
          if (image.isEmpty) image = conv.contactImage;
          break;
        }
      }
    } else {
      if (!Get.isRegistered<ChatController>()) {
        Get.put(
          ChatController(
            Get.find<ChatRepository>(),
            storage: Get.find<GetStorage>(),
          ),
        );
      }
      final c = Get.find<ChatController>();
      await c.reloadConversations();
      for (final conv in c.conversations) {
        if (conv.id == conversationId) {
          if (name.isEmpty) name = conv.contactName;
          if (image.isEmpty) image = conv.contactImage;
          break;
        }
      }
    }

    if (name.isEmpty || name == 'Unknown') {
      name = 'common_user'.tr;
    }
    return (name: name, image: image);
  }

  PostModel? _findPost(PostsController c, String postId) {
    for (final p in c.posts) {
      if (p.id == postId) return p;
    }
    for (final p in c.postsWithoutMedia) {
      if (p.id == postId) return p;
    }
    return null;
  }

  Future<void> _openPostCardFromNotification(
    BuildContext context,
    String postId, {
    bool openCommentsOnOpen = false,
  }) async {
    final PostsController pc = Get.isRegistered<PostsController>()
        ? Get.find<PostsController>()
        : Get.put(PostsController());
    var post = _findPost(pc, postId);
    if (post == null) {
      await pc.refreshPosts();
      post = _findPost(pc, postId);
    }
    // v16.3h — last-resort fallback: fetch the post directly by id. This
    // covers the case where a notification targets a post that is not in
    // the local feed (e.g. a like from another user on a post outside the
    // current filter).
    if (post == null) {
      try {
        final repo = Get.isRegistered<PostRepository>()
            ? Get.find<PostRepository>()
            : PostRepository(Get.find<ApiClient>());
        post = await repo.getPostById(postId);
      } catch (_) {
        post = null;
      }
    }
    if (!context.mounted) return;
    if (post != null) {
      final resolved = post;
      Get.to(
        () => NotificationPostViewScreen(
          post: resolved,
          openCommentsOnOpen: openCommentsOnOpen,
        ),
      );
    } else {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'my_posts_no_posts'.tr,
      );
    }
  }

  Future<void> _navigateForNotification(
    BuildContext context,
    AppNotificationModel n,
  ) async {
    final type = n.type.toLowerCase();
    final data = n.data;
    final role = n.recipientRole.toLowerCase();

    // Session v16.3b - route for BOTH sitter AND walker (both are providers
    // and receive the same booking_new notification when an owner books them
    // directly). Using the sitter screens since they are role-agnostic at
    // the data level.
    if (role == 'sitter' || role == 'walker') {
      final bookingId = _dataString(data, 'bookingId');

      if (bookingId != null && bookingId.isNotEmpty) {
        if (type == 'booking_new') {
          Get.to(
            () => NotificationSitterNewRequestCardViewScreen(
              bookingId: bookingId,
            ),
          );
          return;
        }

        if (type.contains('application_accepted')) {
          Get.to(
            () =>
                NotificationSitterAcceptedCardViewScreen(bookingId: bookingId),
          );
          return;
        }
      }
    }

    // Session v16.3g - owner gets notified on booking_accepted / rejected /
    // paid AND application_accepted / application_rejected (if backend routes
    // them to owner). Tap opens the owner booking detail screen (shows price +
    // Pay button wired to Stripe). Previous version used Get.toNamed('/reservations')
    // which is not a registered route, causing a blank/error fallback screen.
    if (role == 'owner' &&
        (type == 'booking_accepted' ||
            type == 'booking_rejected' ||
            type == 'booking_paid' ||
            type.contains('accepted') ||
            type.contains('rejected'))) {
      final bookingId = _dataString(data, 'bookingId');
      if (bookingId != null && bookingId.isNotEmpty) {
        final ownerRepo = Get.find<OwnerRepository>();
        try {
          final bookings = await ownerRepo.getMyBookings();
          final booking = bookings.firstWhereOrNull(
            (b) => b.id == bookingId,
          );
          if (booking == null) {
            CustomSnackbar.showWarning(
              title: 'common_error'.tr,
              message: 'notifications_application_not_found'.tr,
            );
            return;
          }
          if (!context.mounted) return;

          // Session v17.2 — for booking_accepted on the owner side we go
          // DIRECTLY to StripePaymentScreen (skipping the detour via
          // OwnerBookingDetailScreen). Daniel asked for a 1-tap path:
          // provider accepts → owner taps notif → pays.
          //
          // For booking_rejected / booking_paid we keep the old detour to
          // OwnerBookingDetailScreen because there's nothing to pay.
          final bool isAcceptedNotif =
              type == 'booking_accepted' || type.contains('accepted');
          final bool isPayable = isAcceptedNotif &&
              (booking.paymentStatus ?? '').toLowerCase() != 'paid';

          if (isPayable) {
            // Derive provider type for colour — walker if booking carries
            // walker data or service type contains walking, else sitter.
            final providerRole = _dataString(data, 'providerRole');
            String? resolvedProviderType = providerRole?.toLowerCase();
            if (resolvedProviderType != 'walker' &&
                resolvedProviderType != 'sitter') {
              final serviceLower = (booking.serviceType ?? '').toLowerCase();
              resolvedProviderType =
                  (serviceLower.contains('walking') || serviceLower.contains('dog_walking'))
                      ? 'walker'
                      : 'sitter';
            }
            final pricing = booking.pricing;
            final base = (pricing?.totalPrice
                    ?? pricing?.resolvedBaseAmount
                    ?? booking.totalAmount
                    ?? booking.basePrice) ??
                0.0;
            // Best-effort: pre-create the PaymentIntent so Stripe Sheet opens
            // straight away when Pay is tapped. Swallow errors — the
            // PaymentScreen can retry on Pay-click.
            try {
              await ownerRepo.createPaymentIntent(bookingId: booking.id);
            } catch (e) {
              AppLogger.logDebug(
                'notif booking_accepted: createPaymentIntent pre-warm failed: $e',
              );
            }
            await Get.to(
              () => StripePaymentScreen(
                booking: booking,
                totalAmount: base,
                currency: pricing?.currency ?? booking.sitter.currency,
                providerType: resolvedProviderType,
              ),
            );
            return;
          }

          // Legacy path (rejected / paid / fallback): keep the Booking
          // detail screen with Pay + Cancel side-by-side buttons.
          Get.to(
            () => OwnerBookingDetailScreen(
              booking: booking,
              onPay: () async {
                try {
                  final piResp = await ownerRepo.createPaymentIntent(
                    bookingId: booking.id,
                  );
                  final cs = piResp['clientSecret']
                      ?? piResp['client_secret'];
                  if (cs is String && cs.isNotEmpty) {
                    final pricing = booking.pricing;
                    final base = (pricing?.totalPrice
                            ?? pricing?.resolvedBaseAmount
                            ?? booking.totalAmount
                            ?? booking.basePrice) ??
                        0.0;
                    await Get.to(
                      () => StripePaymentScreen(
                        booking: booking,
                        totalAmount: base,
                        currency: pricing?.currency
                            ?? booking.sitter.currency,
                      ),
                    );
                  }
                } catch (e) {
                  AppLogger.logError(
                    'notif onPay: createPaymentIntent failed',
                    error: e,
                  );
                  CustomSnackbar.showError(
                    title: 'common_error'.tr,
                    message: e.toString(),
                  );
                }
              },
              // v16.3h — Cancel button wired: show confirmation,
              // call BookingsController.cancelBooking, pop on success.
              onCancel: () {
                CustomConfirmationDialog.show(
                  context: Get.context!,
                  message: 'booking_cancel_dialog_message'.tr,
                  yesText: 'common_yes'.tr,
                  cancelText: 'common_cancel'.tr,
                  onYes: () async {
                    final ctrl = Get.isRegistered<BookingsController>()
                        ? Get.find<BookingsController>()
                        : Get.put(BookingsController());
                    await ctrl.cancelBooking(
                      bookingId: booking.id,
                      sitterId: booking.sitter.id,
                    );
                    if (Get.isOverlaysOpen) Get.back();
                    Get.back(); // close the OwnerBookingDetailScreen
                  },
                );
              },
            ),
          );
        } catch (e) {
          AppLogger.logError(
            'notif owner booking load failed',
            error: e,
          );
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: e.toString(),
          );
        }
        return;
      }
    }

    if (type == 'application_new' ||
        (type.contains('application') && !type.contains('post'))) {
      // Session v17.4 — one-tap accept flow for owners. The owner no longer
      // lands on the "Demande du sitter" full screen (which got stuck on
      // "Acceptée" after re-opening). Instead we show a compact dialog
      // with Accept / Refuse and navigate straight to StripePaymentScreen
      // on accept. Same path whether it's a sitter or walker application;
      // provider role drives dialog colours (green walker / blue sitter)
      // and is forwarded to StripePaymentScreen.providerType.
      final applicationId = _dataString(data, 'applicationId');
      final providerRoleFromData = _dataString(data, 'providerRole');
      final sitterId = _dataString(data, 'sitterId');
      if (role != 'owner') return;
      if (applicationId != null && applicationId.isNotEmpty) {
        await _showOwnerApplicationDialog(
          context: context,
          applicationId: applicationId,
          providerRoleHint: providerRoleFromData,
        );
        return;
      }
      // Fallback: no applicationId → keep legacy behaviour (sitter profile).
      if (sitterId != null) {
        Get.to(
          () => ServiceProviderDetailScreen(
            sitterId: sitterId,
            status: 'pending',
          ),
        );
      }
      return;
    }

    if (type == 'post_like' || type.contains('post_like')) {
      final postId = _dataString(data, 'postId');
      if (postId != null) {
        await _openPostCardFromNotification(context, postId);
      }
      return;
    }

    if (type == 'post_comment' || type.contains('post_comment')) {
      final postId = _dataString(data, 'postId');
      if (postId != null) {
        await _openPostCardFromNotification(
          context,
          postId,
          openCommentsOnOpen: true,
        );
      }
      return;
    }

    if (type == 'message_new' || type.contains('message')) {
      final conversationId = _dataString(data, 'conversationId');
      if (conversationId == null) return;
      final isSitter = role == 'sitter';
      final contact = await _resolveChatContactForNotification(
        conversationId: conversationId,
        isSitter: isSitter,
        data: data,
      );
      if (!context.mounted) return;
      if (isSitter) {
        Get.to(
          () => SitterIndividualChatScreen(
            conversationId: conversationId,
            contactName: contact.name,
            contactImage: contact.image,
          ),
        );
      } else {
        Get.to(
          () => IndividualChatScreen(
            conversationId: conversationId,
            contactName: contact.name,
            contactImage: contact.image,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        title: InterText(
          text: 'notifications_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          Obx(() {
            final hasUnread = _c.notifications.any((e) => e.isUnread);
            if (!hasUnread) return const SizedBox.shrink();
            return TextButton(
              onPressed: () async {
                await _c.markAllAsRead();
              },
              child: InterText(
                text: 'notifications_mark_all_read'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryColor,
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (_c.isLoading.value && _c.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryColor),
                SizedBox(height: 16.h),
                InterText(
                  text: 'notifications_loading'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey700Color,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (_c.errorMessage.value.isNotEmpty && _c.notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48.sp,
                    color: AppColors.greyText,
                  ),
                  SizedBox(height: 16.h),
                  InterText(
                    text: 'notifications_load_failed'.tr,
                    fontSize: 14.sp,
                    color: AppColors.grey700Color,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  TextButton(
                    onPressed: _c.loadInitial,
                    child: Text('common_refresh'.tr),
                  ),
                ],
              ),
            ),
          );
        }

        if (_c.notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 56.sp,
                      color: AppColors.primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  InterText(
                    text: 'notifications_empty_title'.tr,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackColor,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  InterText(
                    text: 'notifications_empty_subtitle'.tr,
                    fontSize: 14.sp,
                    color: AppColors.grey700Color,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.primaryColor,
          onRefresh: _onRefresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
            itemCount:
                _c.notifications.length + (_c.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _c.notifications.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        InterText(
                          text: 'notifications_loading_more'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.greyText,
                        ),
                      ],
                    ),
                  ),
                );
              }
              final item = _c.notifications[index];
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: NotificationCard(
                  notification: item,
                  onTap: () => _onTapNotification(item),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Session v17.4 — Owner application acceptance dialog
  //
  // Replaces the full-screen NotificationApplicationViewScreen detour.
  // Owner taps the application_new notif → we fetch the application and:
  //   • status = pending   → show a compact Accept / Refuse dialog
  //                          coloured by provider role. On Accept we call
  //                          OwnerRepository.respondToApplication and
  //                          Get.to() StripePaymentScreen. On Refuse we
  //                          just call respondToApplication(reject).
  //   • status = accepted  → resolve the Booking from bookingsController
  //                          and push StripePaymentScreen directly.
  //                          NO dead-end "Acceptée" card.
  //   • status = rejected  → snackbar "already rejected" and close.
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _showOwnerApplicationDialog({
    required BuildContext context,
    required String applicationId,
    String? providerRoleHint,
  }) async {
    final ownerRepo = Get.find<OwnerRepository>();

    // 1) Fetch the application from the owner's pending list.
    Map<String, dynamic>? appJson;
    try {
      final apps = await ownerRepo.getMyApplications();
      final match = apps.firstWhereOrNull((a) => a.id == applicationId);
      if (match != null) {
        appJson = {
          'id': match.id,
          'status': match.status,
          'bookingId': null, // populated below if we fetch raw
          'sitter': {
            'id': match.sitter.id,
            'name': match.sitter.name,
            'service': match.sitter.service,
            'currency': match.sitter.currency,
            'hourlyRate': match.sitter.hourlyRate,
          },
          'pricing': match.pricing == null
              ? null
              : {
                  'totalPrice': match.pricing?.totalPrice,
                  'currency': match.pricing?.currency,
                },
          'pet': {'name': match.petName},
          'serviceDate': match.serviceDate,
          'timeSlot': match.timeSlot,
          'description': match.description,
          'bookingIdRaw': match.bookingId,
        };
      }
    } catch (e) {
      AppLogger.logError('dialog: fetch application failed', error: e);
    }

    if (appJson == null) {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'notifications_application_not_found'.tr,
      );
      return;
    }

    // 2) Resolve provider type for colour + StripePaymentScreen param.
    String resolvedProviderType = (providerRoleHint ?? '').toLowerCase();
    if (resolvedProviderType != 'walker' && resolvedProviderType != 'sitter') {
      final services = ((appJson['sitter']?['service'] as List?) ?? const [])
          .map((s) => s.toString().toLowerCase())
          .toList();
      resolvedProviderType = services
              .any((s) => s.contains('dog_walking') || s.contains('walking'))
          ? 'walker'
          : 'sitter';
    }
    final Color accent = resolvedProviderType == 'walker'
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);

    final String status = (appJson['status'] as String? ?? '').toLowerCase();

    // 3) Already-accepted path → jump straight to StripePaymentScreen.
    if (status == 'accepted') {
      await _openPaymentForAcceptedApplication(
        ownerRepo: ownerRepo,
        bookingIdHint: appJson['bookingIdRaw']?.toString(),
        providerType: resolvedProviderType,
      );
      return;
    }

    // 4) Rejected path — nothing to do.
    if (status == 'rejected') {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'application_reject_success'.tr,
      );
      return;
    }

    // 5) Pending → v18.6 : on saute le dialog "Accepter et payer" et on
    // envoie direct sur la page paiement. La nouvelle StripePaymentScreen
    // (v18.5) affiche déjà provider + service + date + montant dans le
    // summary card, donc le dialog faisait doublon. Pour rejeter une
    // candidature, l'owner passe par l'onglet "Réservations" qui a déjà
    // un bouton reject. Tap sur la notif = consentement à accepter et
    // payer. Le bouton "Annuler" de la StripePaymentScreen laisse quand
    // même un retour arrière sans charge (PaymentIntent pas confirmé).
    if (!context.mounted) return;

    Map<String, dynamic>? response;
    try {
      response = await ownerRepo.respondToApplication(
        applicationId: applicationId,
        action: 'accept',
      );
    } catch (e) {
      AppLogger.logError('notif accept failed', error: e);
      // v22.2 — Bug 16d : afficher le VRAI message backend (ApiException
      // contient le payload error) plutot que le generique. Permet de voir
      // si c'est "missing pricing", "invalid action", "permission" etc.
      final raw = e.toString();
      final apiMatch = RegExp(r'\{.*"error"\s*:\s*"([^"]+)".*\}').firstMatch(raw);
      final detailedMsg = apiMatch?.group(1) ??
          (raw.contains('Exception:') ? raw.split('Exception:').last.trim() : null);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: detailedMsg != null && detailedMsg.isNotEmpty
            ? detailedMsg
            : 'application_action_failed'.tr,
      );
      return;
    }

    // Re-use BookingModel parser so StripePaymentScreen gets a real object.
    final bookingMap = response['booking'];
    if (bookingMap is Map) {
      try {
        final booking = BookingModel.fromJson(
          Map<String, dynamic>.from(bookingMap),
        );
        final pricing = booking.pricing;
        final base = (pricing?.totalPrice
                ?? pricing?.resolvedBaseAmount
                ?? booking.totalAmount
                ?? booking.basePrice) ??
            0.0;
        if (!context.mounted) return;
        Get.to(
          () => StripePaymentScreen(
            booking: booking,
            totalAmount: base,
            currency: pricing?.currency ?? booking.sitter.currency,
            providerType: resolvedProviderType,
          ),
        );
        if (Get.isRegistered<BookingsController>()) {
          unawaited(Get.find<BookingsController>().loadBookings());
        }
      } catch (e) {
        // v18.8 — si le parser BookingModel explose sur la réponse de
        // /applications/:id/respond, on ne montre PLUS un popup rouge
        // "Paiement indisponible". On tente un fallback transparent :
        // on recharge les bookings via GET /bookings/:id et on ouvre la
        // page paiement. Le popup d'erreur ne doit s'afficher que si
        // même ce fallback échoue.
        AppLogger.logError('notif accept: parse booking failed', error: e);
        final bookingIdHint = (bookingMap['id'] ??
                bookingMap['_id'] ??
                appJson['bookingIdRaw'])
            ?.toString();
        await _openPaymentForAcceptedApplication(
          ownerRepo: ownerRepo,
          bookingIdHint: bookingIdHint,
          providerType: resolvedProviderType,
        );
      }
    } else {
      // Pas de booking dans la réponse → fallback GET /bookings/:id avant
      // tout popup d'erreur. Avant v18.8, on balançait directement
      // "Paiement momentanément indisponible" sur chaque candidature,
      // même si l'acceptation avait réussi côté backend.
      await _openPaymentForAcceptedApplication(
        ownerRepo: ownerRepo,
        bookingIdHint: appJson['bookingIdRaw']?.toString(),
        providerType: resolvedProviderType,
      );
    }
  }

  /// v17.4 — shared helper: resolve a Booking by id and open PaymentPage.
  Future<void> _openPaymentForAcceptedApplication({
    required OwnerRepository ownerRepo,
    required String? bookingIdHint,
    required String providerType,
  }) async {
    try {
      final bookings = await ownerRepo.getMyBookings();
      final booking = bookings.firstWhereOrNull(
            (b) => b.id == bookingIdHint,
          ) ??
          bookings.firstWhereOrNull((b) =>
              (b.status.toLowerCase() == 'agreed' ||
                  b.status.toLowerCase() == 'accepted') &&
              (b.paymentStatus?.toLowerCase() ?? '') != 'paid');
      if (booking == null) {
        CustomSnackbar.showWarning(
          title: 'common_error'.tr,
          message: 'notifications_application_not_found'.tr,
        );
        return;
      }
      if ((booking.paymentStatus ?? '').toLowerCase() == 'paid') {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'application_accept_success'.tr,
        );
        return;
      }
      final pricing = booking.pricing;
      final base = (pricing?.totalPrice
              ?? pricing?.resolvedBaseAmount
              ?? booking.totalAmount
              ?? booking.basePrice) ??
          0.0;
      Get.to(
        () => StripePaymentScreen(
          booking: booking,
          totalAmount: base,
          currency: pricing?.currency ?? booking.sitter.currency,
          providerType: providerType,
        ),
      );
    } catch (e) {
      // v18.8 — plus de e.toString() en dur (fuite de stack en anglais
      // dans le snackbar). Message générique traduit.
      AppLogger.logError('open-payment-for-accepted failed', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    }
  }
}
