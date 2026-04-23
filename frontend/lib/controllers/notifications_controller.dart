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
    _attachSocketListener();
    refreshUnreadCount();
  }

  void _attachSocketListener() {
    try {
      final s = Get.find<SocketService>();
      s.socket?.off('notification.new');
      s.socket?.on('notification.new', (data) {
        try {
          // ignore: unnecessary_cast
          final map = data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};
          final type = (map['type'] as String?) ?? '';
          unreadCount.value = unreadCount.value + 1;
          if (type == 'NEW_MESSAGE') {
            unreadChat.value = unreadChat.value + 1;
            _storage.write(_kUnreadChat, unreadChat.value);
          } else if (type == 'BOOKING_MUTUALLY_ACCEPTED' ||
              type == 'PAYMENT_SUCCESS' ||
              type == 'PAYMENT_FAILED') {
            unreadBookings.value = unreadBookings.value + 1;
            _storage.write(_kUnreadBookings, unreadBookings.value);
          }
          // v18.9 — badge Accueil pour :
          //   - provider (walker/sitter) : booking_new = owner a envoyé
          //     une demande directe.
          //   - owner : application_new = un provider a postulé sur son
          //     post ; booking_accepted = provider a accepté sa demande.
          final lower = type.toLowerCase();
          if (lower == 'booking_new' ||
              lower == 'application_new' ||
              lower == 'booking_accepted' ||
              lower == 'application_accepted') {
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
