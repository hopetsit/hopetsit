import 'package:hopetsit/utils/map_ui_state.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/paw_button_kit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
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
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
// v575 — audit P1-4 : repli de navigation par « route thème ».
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
// v23.1.319 — Daniel (audit) : routage des notifs paiement/wallet/boutique.
import 'package:hopetsit/views/notifications/notification_post_view_screen.dart';
import 'package:hopetsit/views/notifications/notification_sitter_application_card_view_screen.dart';
import 'package:hopetsit/views/payment/airwallex_payment_screen.dart';
import 'package:hopetsit/views/pet_owner/booking-application/owner_booking_detail_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
// v23.1.340 — Daniel : routage de la notif "C'est l'heure ! confirme le début
// du service" vers l'écran Réservations du prestataire (bouton 🐾).
// v532 — écrans cibles des types de notification qui n'étaient routés nulle part.
import 'package:hopetsit/views/pet_owner/booking/owner_bookings_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/localization/v565/fixes575_i18n.dart';
import 'package:hopetsit/widgets/notification_card.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  // v599 (ZOE) — Daniel : « pouvoir CHOISIR ». Appui long → mode sélection
  // (cases), « Supprimer (N) » / « Marquer lu (N) », « Tout » conservé.
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  // 610 (ZOE, 04/10) — Daniel : « ouvrir la cloche et voir une notification =
  // lue ». Tout ce que la cloche affiche est lu côté serveur (compteur de la
  // cloche + badge de l'icône recalés) ; les lignes qui étaient non lues à
  // l'arrivée gardent leur style « nouveau » jusqu'à la fermeture de l'écran.
  final Set<String> _freshIds = <String>{};
  Worker? _seenWorker;
  Timer? _seenDebounce;

  void _scheduleMarkSeen() {
    _seenDebounce?.cancel();
    _seenDebounce = Timer(const Duration(milliseconds: 400), _markDisplayedAsSeen);
  }

  void _markDisplayedAsSeen() {
    if (!mounted || _c.isLoading.value) return;
    final ids = <String>[];
    for (final n in _c.notifications) {
      if (n.isUnread && n.id.isNotEmpty) {
        _freshIds.add(n.id);
        ids.add(n.id);
      }
    }
    if (ids.isEmpty) return;
    if (mounted) setState(() {});
    unawaited(_c.markSeen(ids));
  }

  /// 610 — la cloche montre les 3 profils : une notification d'un AUTRE profil
  /// est lue, puis on dit de quel profil il s'agit au lieu d'ouvrir un écran
  /// que la session du profil actif ne peut pas charger (403).
  bool _isForOtherProfile(AppNotificationModel n) {
    final target = n.recipientRole.trim().toLowerCase();
    if (!const <String>['owner', 'sitter', 'walker'].contains(target)) {
      return false;
    }
    try {
      final current =
          (Get.find<AuthController>().userRole.value ?? '').toLowerCase();
      return current.isNotEmpty && current != target;
    } catch (_) {
      return false;
    }
  }

  void _enterSelection(AppNotificationModel item) {
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(item.id);
    });
  }

  void _toggleSelected(AppNotificationModel item) {
    setState(() {
      if (!_selected.remove(item.id)) _selected.add(item.id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelectAll() {
    final all = _c.notifications.map((e) => e.id).toSet();
    setState(() {
      if (_selected.length >= all.length) {
        _selected.clear();
        _selecting = false;
      } else {
        _selected
          ..clear()
          ..addAll(all);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final ok = await showAppConfirmDialog(
      context,
      title: 'notif599_delete_n_title'.trParams({'n': '${ids.length}'}),
      message: 'notif599_delete_n_body'.tr,
      confirmLabel: 'notif599_delete_n'.trParams({'n': '${ids.length}'}),
      cancelLabel: 'common_cancel'.tr,
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok != true || !mounted) return;
    _exitSelection();
    await _c.deleteMany(ids);
  }

  Future<void> _readSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    _exitSelection();
    await _c.markManyAsRead(ids);
  }

  Future<void> _deleteAll() async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'notif599_delete_all_title'.tr,
      message: 'notif599_delete_all_body'.tr,
      confirmLabel: 'notif599_delete_all'.tr,
      cancelLabel: 'common_cancel'.tr,
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (ok != true || !mounted) return;
    _exitSelection();
    await _c.clearAll();
  }

  /// Barre du bas en mode sélection : Supprimer (N) · Marquer lu (N).
  Widget _selectionBar(BuildContext context) {
    final n = _selected.length;
    final accent = AppColors.activeRoleAccent();
    final hasUnread = _c.notifications
        .any((e) => _selected.contains(e.id) && e.isUnread);
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h + appBottomInset(context)),
      decoration: BoxDecoration(
        color: AppColors.appBar(context),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1513).withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            // 599 (BOB) — boutons du kit, pas de Material brut (garde lotd).
            child: PawButton(
              label: 'notif599_delete_n'.trParams({'n': '$n'}),
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFE5484D),
              enabled: n > 0,
              height: 48.h,
              onTap: _deleteSelected,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: PawButton(
              label: 'notif599_read_n'.trParams({'n': '$n'}),
              icon: Icons.done_all_rounded,
              color: accent,
              enabled: n > 0 && hasUnread,
              height: 48.h,
              onTap: _readSelected,
            ),
          ),
        ],
      ),
    );
  }

  NotificationsController get _c {
    if (!Get.isRegistered<NotificationsController>()) {
      return Get.put(NotificationsController(), permanent: true);
    }
    return Get.find<NotificationsController>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _c.loadInitial();
      _markDisplayedAsSeen(); // 610
    });
    // 610 — page suivante, notification arrivée pendant la visite : vue = lue.
    _seenWorker = ever(_c.notifications, (_) => _scheduleMarkSeen());
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
    _seenWorker?.dispose();
    _seenDebounce?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() => _c.refreshAll();

  Future<void> _onTapNotification(AppNotificationModel n) async {
    await _c.markAsRead(n);
    if (!mounted) return;
    if (_isForOtherProfile(n)) {
      CustomSnackbar.showInfo(
        title: 'notifications_title'.tr,
        message: 'fixes575_notification_other_role'.tr.replaceAll(
            '{role}', fixes575RoleLabelKey(n.recipientRole.toLowerCase()).tr),
      );
      return;
    }
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

    // v575 — audit P1-4 : repli commun. `routeForNotification` connaît la
    // destination de CHAQUE type (miroir de `emailLinkBuilder.buildAppRoute`
    // côté serveur) et `openRoute` passe par les ONGLETS du menu — jamais par
    // un `Get.to(() => const XScreen())` qui afficherait un écran d'onglet
    // sans menu (cf. test/no_tab_push_test.dart).
    Future<void> openByRoute() async {
      final route =
          DeepLinkService.routeForNotification(type, data, role: role);
      await DeepLinkService.instance.openRoute(route);
    }

    // v602 (PAM) — suivi en direct : la demande / l'acceptation / le refus
    // ouvrent LA conversation de la carte (Accepter / Refuser, « Voir sur la
    // carte »), la balade ouvre la balade, « toujours actif » les personnes
    // en direct. Avant : `contains('live_tracking')` → écran Amis, et
    // `live_tracking_accepted` tombait d'abord dans la branche « réservation
    // acceptée » du propriétaire (`contains('accepted')`).
    if (type.startsWith('live_tracking') ||
        type == 'live_still_active' ||
        type == 'live_session_ended' ||
        type == 'walk_started' ||
        type == 'walk_finished') {
      await openByRoute();
      return;
    }

    // Session v16.3b - route for BOTH sitter AND walker (both are providers
    // and receive the same booking_new notification when an owner books them
    // directly). Using the sitter screens since they are role-agnostic at
    // the data level.
    if (role == 'sitter' || role == 'walker') {
      // v23.1.340 — Daniel : "le sitter/walker doit pouvoir cliquer Début de
      // service". La notif 'service_start_due' (C'est l'heure ! 🐾) ouvre
      // DIRECTEMENT l'écran Réservations du prestataire, où se trouve le
      // bouton « 🐾 J'ai récupéré l'animal » qui confirme le début du service.
      // v602 (ZOE) — « C'est l'heure ! » ouvre LA réservation (fiche avec
      // « J'ai récupéré l'animal »), plus la liste des réservations.
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
            // v602 — réservation disparue : message clair + la liste.
            CustomSnackbar.showInfo(
              title: 'notifications_title'.tr,
              message: 'notif602_booking_gone'.tr,
            );
            openMainTabOr(3, () => const OwnerBookingsScreen());
            return;
          }
          if (!context.mounted) return;

          // Session v17.2 — for booking_accepted on the owner side we go
          // DIRECTLY to AirwallexPaymentScreen (skipping the detour via
          // OwnerBookingDetailScreen). Daniel asked for a 1-tap path:
          // provider accepts → owner taps notif → pays.
          //
          // For booking_rejected / booking_paid we keep the old detour to
          // OwnerBookingDetailScreen because there's nothing to pay.
          final bool isAcceptedNotif =
              type == 'booking_accepted' || type.contains('accepted');
          // v602 (ZOE) — une réservation annulée / refusée / remboursée n'est
          // plus à payer : on montre sa fiche (avant : page de paiement).
          final bool isClosed = const <String>{
            'cancelled', 'canceled', 'rejected', 'refunded', 'completed', 'expired',
          }.contains(booking.status.toLowerCase());
          final bool isPayable = isAcceptedNotif &&
              !isClosed &&
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
              () => AirwallexPaymentScreen(
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
                      () => AirwallexPaymentScreen(
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

    // v602 (ZOE) — candidature : avant, le tap du propriétaire ACCEPTAIT la
    // candidature sans confirmation (et refusait les autres candidats). Le
    // routeur ouvre désormais LA candidature (candidats de la demande, choix
    // confirmé, puis paiement) ; côté prestataire, la demande concernée.
    if (type == 'application_new' ||
        (type.contains('application') && !type.contains('post'))) {
      await openByRoute();
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

    // v602 (ZOE) — Daniel : « chaque notification renvoie à la tâche
    // précise ». Les anciennes branches génériques (portefeuille pour tout ce
    // qui contenait « payment » — y compris l'identité —, boutique sur le
    // 1er onglet, écran Amis, LISTE des réservations, carte non centrée…)
    // passent par le routeur commun, qui ouvre la cible exacte.
    // Suivi en direct (live_tracking_*) : comportement inchangé (PAM).
    if (type.contains('live_tracking')) {
      Get.to(() => const FriendsScreen());
      return;
    }

    if (type == 'message_new' ||
        type == 'chat_auto_welcome' ||
        type.contains('message')) {
      final conversationId = _dataString(data, 'conversationId');
      if (conversationId == null) {
        await openByRoute();
        return;
      }
      // v23.1.286 — walker partage l'écran chat des prestataires (comme sitter).
      // Avant, walker tombait dans la branche owner → mauvais écran de conv.
      final isSitter = role == 'sitter' || role == 'walker';
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
      return;
    }

    // v575 — audit P1-4 : 14 types de notifications n'étaient couverts par
    // AUCUNE branche ci-dessus (booking_paid, booking_paid_owner, les 4
    // handover_*, walk_started, walk_finished, sos_pet_nearby,
    // live_session_ended, live_still_active, application_rejected,
    // application_rejected_other_accepted, BOOKING_MUTUALLY_ACCEPTED) : le
    // tap ne faisait RIEN.
    await openByRoute();
  }

  @override
  Widget build(BuildContext context) {
    // v571 — audit lisibilité mode sombre : `grey700Color` (#414651) est
    // presque noir, illisible sur le fond sombre. On garde la valeur claire
    // à l'identique et on éclaircit seulement en sombre.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bodyGrey =
        isDark ? AppColors.textSecondaryDark : AppColors.grey700Color;
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: AppColors.appBar(context),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: _selecting
            ? IconButton(
                tooltip: 'common_cancel'.tr,
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelection,
              )
            : null,
        title: InterText(
          text: _selecting
              ? 'notif599_selected_n'.trParams({'n': '${_selected.length}'})
              : 'notifications_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          if (_selecting)
            Obx(() {
              final all = _c.notifications.length;
              final allSelected = all > 0 && _selected.length >= all;
              return IconButton(
                tooltip: allSelected
                    ? 'notif599_deselect_all'.tr
                    : 'notif599_select_all'.tr,
                icon: Icon(allSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded),
                onPressed: all == 0 ? null : _toggleSelectAll,
              );
            })
          else ...[
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
            // v599 — menu : Sélectionner · Tout supprimer.
            Obx(() {
              if (_c.notifications.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                tooltip: 'notif599_more'.tr,
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.primaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
                color: AppColors.appBar(context),
                onSelected: (v) {
                  if (v == 'select' && _c.notifications.isNotEmpty) {
                    _enterSelection(_c.notifications.first);
                    setState(() => _selected.clear());
                  } else if (v == 'delete_all') {
                    _deleteAll();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'select',
                    child: Row(children: [
                      Icon(Icons.checklist_rounded,
                          size: 20.sp, color: AppColors.primaryColor),
                      SizedBox(width: 10.w),
                      Text('notif599_select'.tr,
                          style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Row(children: [
                      Icon(Icons.delete_sweep_outlined,
                          size: 20.sp, color: const Color(0xFFE5484D)),
                      SizedBox(width: 10.w),
                      Text('notif599_delete_all'.tr,
                          style: const TextStyle(
                              color: Color(0xFFE5484D),
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
      bottomNavigationBar: _selecting ? _selectionBar(context) : null,
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: Obx(() {
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
                  color: bodyGrey,
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
                    color: AppColors.textSecondary(context),
                  ),
                  SizedBox(height: 16.h),
                  InterText(
                    text: 'notifications_load_failed'.tr,
                    fontSize: 14.sp,
                    color: bodyGrey,
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
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  InterText(
                    text: 'notifications_empty_subtitle'.tr,
                    fontSize: 14.sp,
                    color: bodyGrey,
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
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final item = _c.notifications[index];
              // v599 — mode sélection : case + tap = cocher (pas de glisser).
              if (_selecting) {
                final checked = _selected.contains(item.id);
                final accent = AppColors.activeRoleAccent();
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _toggleSelected(item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 26.w,
                          height: 26.w,
                          margin: EdgeInsets.only(right: 10.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: checked ? accent : Colors.transparent,
                            border: Border.all(color: accent, width: 2),
                          ),
                          child: checked
                              ? Icon(Icons.check_rounded,
                                  size: 18.sp, color: Colors.white)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          selected: checked,
                          child: NotificationCard(
                            notification: item,
                            showAsNew: item.isUnread || _freshIds.contains(item.id),
                            onTap: () => _toggleSelected(item),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              // v566 — glisser vers la gauche = supprimer (synchronisé avec les
              // autres appareils par l'événement `notification.removed`).
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Dismissible(
                  key: ValueKey<String>('notif_${item.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Semantics(
                      label: 'notifications_delete'.tr,
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                  ),
                  onDismissed: (_) => _c.deleteNotification(item),
                  // v599 — appui long = mode sélection.
                  child: GestureDetector(
                    onLongPress: () => _enterSelection(item),
                    child: NotificationCard(
                      notification: item,
                      showAsNew: item.isUnread || _freshIds.contains(item.id),
                      onTap: () => _onTapNotification(item),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }),
        ),
    );
  }
}
