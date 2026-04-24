import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/repositories/notifications_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/logger.dart';

class NotificationsController extends GetxController {
  NotificationsController({NotificationsRepository? repository})
    : _repository = repository ?? Get.find<NotificationsRepository>();

  final NotificationsRepository _repository;

  final GetStorage _storage = GetStorage();
  static const String _kUnreadBookings = 'unreadBookings';
  static const String _kUnreadChat = 'unreadChat';
  // v18.9 — badge Accueil : walker/sitter reçoit direct request owner,
  // owner reçoit application d'un provider ou acceptation direct request.
  static const String _kUnreadHome = 'unreadHome';

  final RxList<AppNotificationModel> notifications =
      <AppNotificationModel>[].obs;
  final RxInt unreadCount = 0.obs;
  // Sprint 4 step 4 — per-category badges.
  final RxInt unreadBookings = 0.obs;
  final RxInt unreadChat = 0.obs;
  // v18.9 — badge sur onglet Accueil.
  final RxInt unreadHome = 0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxnString nextCursor = RxnString();
  final RxString errorMessage = ''.obs;

  static const int _pageLimit = 50;

  @override
  void onInit() {
    super.onInit();
    unreadBookings.value = _storage.read<int>(_kUnreadBookings) ?? 0;
    unreadChat.value = _storage.read<int>(_kUnreadChat) ?? 0;
    unreadHome.value = _storage.read<int>(_kUnreadHome) ?? 0;
    // v18.9.4 — force la connexion socket dès le démarrage des bottom nav.
    // Avant, le socket ne se connectait QUE dans chat_controller (onglet
    // Chat). Conséquence : si owner reçoit une demande directe alors qu'il
    // est sur Accueil / Réservations, l'event 'notification.new' du
    // backend ne lui arrivait jamais → aucun badge.
    _attachSocketListener(); // best-effort, au cas où socket déjà up
    _ensureSocketConnectedAndListen();
    // v20.0.19 — CRITICAL : s'enregistrer sur le hook onConnected du
    // SocketService. Avant ce fix, si l'user se loguait APRÈS le boot (ce
    // qui est toujours le cas en pratique : onInit au boot, login après),
    // _attachSocketListener était appelé à vide (socket.socket == null)
    // et le listener n'était JAMAIS attaché. Résultat : aucun badge ne
    // se bumpait en temps réel — l'user devait tuer/relancer l'app pour
    // que le onInit re-tourne avec un socket déjà connecté par ailleurs.
    try {
      final svc = Get.find<SocketService>();
      svc.addOnConnectedHook(_attachSocketListener);
    } catch (_) { /* SocketService pas encore enregistré */ }
    refreshUnreadCount();
  }

  Future<void> _ensureSocketConnectedAndListen() async {
    try {
      if (!Get.isRegistered<SocketService>()) return;
      final svc = Get.find<SocketService>();
      if (!svc.isConnected) {
        await svc.connect();
      }
      // Ré-attache le listener maintenant que le socket est connecté.
      _attachSocketListener();
    } catch (e) {
      AppLogger.logError('Notifications: socket connect failed', error: e);
    }
  }

  // v20.0.13 — dedup set shared between FCM handler + socket listener so
  // the badge only increments once per notification even if both paths
  // deliver the same event (FCM push + socket emit run in parallel).
  final Set<String> _seenNotifIds = <String>{};
  bool _markSeenOrDupe(Map<String, dynamic> data) {
    final id = (data['id'] ?? data['_id'] ?? data['notificationId'] ?? '')
        .toString();
    if (id.isEmpty) return false;
    if (_seenNotifIds.contains(id)) return true;
    _seenNotifIds.add(id);
    // Cap the cache to avoid unbounded memory.
    if (_seenNotifIds.length > 200) {
      final drop = _seenNotifIds.take(100).toList();
      for (final k in drop) _seenNotifIds.remove(k);
    }
    return false;
  }

  void _attachSocketListener() {
    try {
      final s = Get.find<SocketService>();
      s.socket?.off('notification.new');
      s.socket?.on('notification.new', (data) {
        try {
          // ignore: unnecessary_cast
          final map = data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
          // v20.0.13 — skip if FCM handler already bumped the badge for
          // this notification id.
          if (_markSeenOrDupe(map)) return;
          final type = (map['type'] as String?) ?? '';
          final lower = type.toLowerCase();
          unreadCount.value = unreadCount.value + 1;

          // v18.9.7 — badges par onglet selon la sémantique de l'event.
          // Chaque type de notification n'arrive que sur UN seul rôle
          // (ex: application_accepted va toujours à walker/sitter,
          // jamais à owner) donc on peut router sans vérifier le rôle.
          //
          // ACCUEIL  (unreadHome)
          //   - Owner   : booking_accepted (provider a accepté ma
          //               demande directe), application_new (provider
          //               a postulé sur mon post).
          //   - Provider: booking_new (owner m'a envoyé une demande
          //               directe à traiter).
          //
          // RÉSERVATIONS  (unreadBookings)
          //   - Owner   : PAYMENT_SUCCESS, PAYMENT_FAILED (suite de
          //               mon paiement).
          //   - Provider: application_accepted (owner a accepté ma
          //               candidature → une booking existe désormais
          //               en attente de paiement), PAYMENT_SUCCESS,
          //               booking_paid (owner a payé ma booking).
          //
          // CHAT  (unreadChat)
          //   - Les deux : NEW_MESSAGE (y compris le welcome auto
          //                envoyé par le backend juste après paiement).
          //
          // BOOKING_MUTUALLY_ACCEPTED, BOOKING_PAID_CHAT_UNLOCKED,
          // NEW_REVIEW, BOOKING_COMPLETED : pas de badge dédié
          // (visibles dans unreadCount + écran Notifications).
          if (lower == 'new_message') {
            unreadChat.value = unreadChat.value + 1;
            _storage.write(_kUnreadChat, unreadChat.value);
          } else if (lower == 'payment_success' ||
              lower == 'payment_failed' ||
              lower == 'booking_paid' ||
              lower == 'application_accepted') {
            unreadBookings.value = unreadBookings.value + 1;
            _storage.write(_kUnreadBookings, unreadBookings.value);
          } else if (lower == 'booking_new' ||
              lower == 'application_new' ||
              lower == 'booking_accepted') {
            unreadHome.value = unreadHome.value + 1;
            _storage.write(_kUnreadHome, unreadHome.value);
          }
        } catch (_) {}
      });
    } catch (_) {
      // SocketService not registered yet — listener will be re-attached on next onInit.
    }
  }

  void clearChatBadge() {
    unreadChat.value = 0;
    _storage.write(_kUnreadChat, 0);
  }

  void clearBookingsBadge() {
    unreadBookings.value = 0;
    _storage.write(_kUnreadBookings, 0);
  }

  // v18.9 — clear du badge Accueil (tap sur l'onglet 0).
  void clearHomeBadge() {
    unreadHome.value = 0;
    _storage.write(_kUnreadHome, 0);
  }

  // v20.0.13 — Helpers appelés par le handler FCM (push_notification_service)
  // pour incrémenter le badge immédiatement à l'arrivée de la notif, sans
  // attendre que l'event socket parallèle n'arrive. Idempotents : si le socket
  // arrive après avec le même event, le total peut être un peu gonflé mais il
  // sera resync au prochain clear ou refreshUnreadCount().
  void bumpUnreadHomeImmediate() {
    unreadHome.value = unreadHome.value + 1;
    _storage.write(_kUnreadHome, unreadHome.value);
  }

  void bumpUnreadCountImmediate() {
    unreadCount.value = unreadCount.value + 1;
  }

  // v20.0.13 — public wrapper around the dedup helper so the FCM handler
  // can check + register a notification id before bumping the badge.
  bool markSeenOrDupePublic(Map<String, dynamic> data) {
    return _markSeenOrDupe(data);
  }

  Future<void> refreshUnreadCount() async {
    try {
      final n = await _repository.getUnreadCount();
      unreadCount.value = n;
    } catch (e) {
      AppLogger.logError('Unread count failed', error: e);
    }
  }

  Future<void> loadInitial() async {
    isLoading.value = true;
    errorMessage.value = '';
    nextCursor.value = null;

    try {
      final result = await _repository.getMyNotifications(
        limit: _pageLimit,
        cursor: null,
      );
      notifications.assignAll(result.notifications);
      nextCursor.value = result.nextCursor;
      await refreshUnreadCount();
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      notifications.clear();
    } catch (e) {
      errorMessage.value = e.toString();
      notifications.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    final cursor = nextCursor.value;
    if (cursor == null || cursor.isEmpty || isLoadingMore.value) return;

    isLoadingMore.value = true;
    try {
      final result = await _repository.getMyNotifications(
        limit: _pageLimit,
        cursor: cursor,
      );
      if (result.notifications.isEmpty) {
        nextCursor.value = null;
        return;
      }
      final existingIds = notifications.map((e) => e.id).toSet();
      for (final n in result.notifications) {
        if (!existingIds.contains(n.id)) {
          notifications.add(n);
        }
      }
      nextCursor.value = result.nextCursor;
    } catch (e) {
      AppLogger.logError('Load more notifications failed', error: e);
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> markAsRead(AppNotificationModel item) async {
    if (!item.isUnread) return;
    try {
      await _repository.markAsRead(item.id);
      final i = notifications.indexWhere((e) => e.id == item.id);
      if (i != -1) {
        notifications[i] = item.copyWith(readAt: DateTime.now().toUtc());
        notifications.refresh();
      }
      await refreshUnreadCount();
    } on ApiException catch (e) {
      AppLogger.logError('Mark notification read failed', error: e.message);
    } catch (e) {
      AppLogger.logError('Mark notification read failed', error: e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      final now = DateTime.now().toUtc();
      for (var i = 0; i < notifications.length; i++) {
        if (notifications[i].isUnread) {
          notifications[i] = notifications[i].copyWith(readAt: now);
        }
      }
      notifications.refresh();
      unreadCount.value = 0;
    } on ApiException catch (e) {
      AppLogger.logError('Mark all read failed', error: e.message);
    } catch (e) {
      AppLogger.logError('Mark all read failed', error: e);
    }
  }

  Future<void> refreshAll() async {
    await loadInitial();
  }
}
