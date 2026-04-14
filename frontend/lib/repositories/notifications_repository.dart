import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/app_notification_model.dart';

class NotificationsRepository {
  NotificationsRepository(this._apiClient);

  final ApiClient _apiClient;

  static const int _defaultLimit = 50;

  /// GET /notifications/my?limit=&cursor=
  Future<
    ({List<AppNotificationModel> notifications, String? nextCursor, int count})
  >
  getMyNotifications({int limit = _defaultLimit, String? cursor}) async {
    final query = <String, dynamic>{
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };

    final response = await _apiClient.get(
      ApiEndpoints.notificationsMy,
      queryParameters: query,
      requiresAuth: true,
    );

    if (response is! Map) {
      throw ApiException(
        'Unexpected notifications response.',
        details: response,
      );
    }

    final map = Map<String, dynamic>.from(response);
    final rawList = map['notifications'];
    final list = <AppNotificationModel>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          list.add(AppNotificationModel.fromJson(item));
        } else if (item is Map) {
          list.add(
            AppNotificationModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final next = map['nextCursor']?.toString();
    final count = (map['count'] is num)
        ? (map['count'] as num).toInt()
        : list.length;

    return (notifications: list, nextCursor: next, count: count);
  }

  /// GET /notifications/my/unread-count
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(
      '${ApiEndpoints.notificationsMy}/unread-count',
      requiresAuth: true,
    );

    int? parseCount(Map<String, dynamic> m) {
      dynamic c =
          m['count'] ??
          m['unreadCount'] ??
          m['unread'] ??
          m['totalUnread'] ??
          m['unread_count'];
      if (c is num) return c.toInt();
      if (c is String) return int.tryParse(c);
      final data = m['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        c = dm['count'] ?? dm['unreadCount'] ?? dm['unread'];
        if (c is num) return c.toInt();
        if (c is String) return int.tryParse(c);
      }
      return null;
    }

    if (response is Map<String, dynamic>) {
      final n = parseCount(response);
      if (n != null) return n;
    }
    if (response is Map) {
      final n = parseCount(Map<String, dynamic>.from(response));
      if (n != null) return n;
    }
    return 0;
  }

  /// PATCH /notifications/my/{id}/read
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _apiClient.patch(
      '${ApiEndpoints.notificationsMy}/$notificationId/read',
      requiresAuth: true,
    );
  }

  /// PATCH /notifications/my/read-all
  Future<void> markAllAsRead() async {
    await _apiClient.patch(
      '${ApiEndpoints.notificationsMy}/read-all',
      requiresAuth: true,
    );
  }
}
