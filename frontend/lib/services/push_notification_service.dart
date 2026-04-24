import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';

/// Push notification service for HopeTSIT.
///
/// Handles:
///   - Permissions (iOS + Android 13+)
///   - Retrieving / refreshing the FCM token and sending it to the backend
///   - Foreground messages (shown as local notifications)
///   - Background messages (via registered background handler)
///   - Tap handling (opening a chat thread, an offer, etc.)
///
/// The backend is expected to expose a POST endpoint to register the token
/// and to send push notifications with the following data payload shape:
///
/// ```
/// {
///   "type": "message" | "offer" | "booking" | "generic",
///   "thread_id": "...",      // when type == message
///   "offer_id":  "...",      // when type == offer
///   "booking_id": "...",     // when type == booking
///   "title": "...",
///   "body":  "..."
/// }
/// ```
class PushNotificationService extends GetxService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final RxnString fcmToken = RxnString();

  /// Android channel used for message + offer notifications.
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'hopetsit_default_channel',
    'HoPetSit notifications',
    description:
        'Messages, booking updates and special offers from HoPetSit.',
    importance: Importance.high,
  );

  bool _initialized = false;

  /// Must be called once at app startup (after Firebase.initializeApp).
  Future<PushNotificationService> init() async {
    if (_initialized) return this;
    _initialized = true;

    try {
      // iOS: request permission. Android 13+ also needs POST_NOTIFICATIONS.
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Configure local notifications (used for foreground messages).
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // iOS: display alerts even when the app is in the foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get and cache the token.
      final token = await _messaging.getToken();
      fcmToken.value = token;
      debugPrint('FCM token: $token');
      if (token != null && token.isNotEmpty) {
        unawaited(_registerTokenOnBackend(token));
      }

      // Refresh the cached token whenever Firebase rotates it.
      _messaging.onTokenRefresh.listen((String newToken) {
        fcmToken.value = newToken;
        debugPrint('FCM token refreshed');
        unawaited(_registerTokenOnBackend(newToken));
      });

      // Foreground message handler.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Handler when the user taps a notification while the app is in
      // background (but still alive).
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      // Handle the very first notification that launched the app (cold start).
      final RemoteMessage? initialMessage =
          await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _onMessageOpened(initialMessage);
      }
    } catch (e, st) {
      // Never crash the app because of notifications.
      debugPrint('Push notification init failed: $e\n$st');
    }

    return this;
  }

  /// Subscribe to a topic (e.g. "offers_fr") to receive targeted pushes
  /// (new offers, promotions, etc.).
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Subscribe to topic $topic failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('Unsubscribe from topic $topic failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('FCM foreground: ${message.messageId}');
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'HoPetSit';
    final body = notification?.body ?? message.data['body'] ?? '';

    // v20.0.13 — Increment the home/notifications badge IMMEDIATELY from the
    // FCM handler, in addition to the socket listener in NotificationsController.
    // Previously only the socket incremented the badge, so if FCM delivered the
    // push slightly earlier than the socket event the user saw the notification
    // pop up but the bottom-nav badge stayed at 0 for up to a few seconds.
    // Both paths now update the badge whichever arrives first.
    try {
      if (Get.isRegistered<NotificationsController>()) {
        final nc = Get.find<NotificationsController>();
        // v20.0.13 — dedup: if this notification id has already been seen
        // (by a faster socket event), skip — otherwise record it so the
        // incoming socket event won't double-increment.
        final data = Map<String, dynamic>.from(message.data);
        final alreadySeen = nc.markSeenOrDupePublic(data);
        if (!alreadySeen) {
          final rawType =
              (data['type'] ?? data['notificationType'] ?? '')
                  .toString()
                  .toLowerCase();
          final homeTypes = {
            'booking_new',
            'application_new',
            'booking_accepted',
            'provider_sent_request_walker',
            'provider_sent_request_sitter',
            'direct_request',
          };
          if (homeTypes.contains(rawType)) {
            nc.bumpUnreadHomeImmediate();
          }
          nc.bumpUnreadCountImmediate();
        }
      }
    } catch (_) {
      // Non-blocking: if the controller is not registered (rare), socket
      // will still catch up when it arrives.
    }

    final String payload = jsonEncode(message.data);

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    debugPrint('FCM opened app: ${message.data}');
    _routeFromData(message.data);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final Map<String, dynamic> data =
          jsonDecode(response.payload!) as Map<String, dynamic>;
      _routeFromData(data);
    } catch (_) {
      // ignore
    }
  }

  /// Decide which screen to open based on the notification payload.
  /// Kept intentionally defensive: if the target route is unknown we simply
  /// land the user on the notifications tab.
  void _routeFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString();
    switch (type) {
      case 'message':
        // Example: navigate to the chat thread.
        // Get.toNamed('/chat', arguments: data['thread_id']);
        break;
      case 'offer':
        // Get.toNamed('/offer', arguments: data['offer_id']);
        break;
      case 'booking':
        // Get.toNamed('/booking', arguments: data['booking_id']);
        break;
      default:
        break;
    }
  }

  String _currentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  Future<void> _registerTokenOnBackend(String token) async {
    try {
      final ApiClient api = Get.isRegistered<ApiClient>()
          ? Get.find<ApiClient>()
          : ApiClient();
      await api.post(
        ApiEndpoints.fcmToken,
        body: {'token': token, 'platform': _currentPlatform()},
        requiresAuth: true,
      );
      debugPrint('FCM token registered with backend');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Call on logout to remove the current device token from the backend.
  Future<void> unregisterCurrentToken() async {
    final token = fcmToken.value;
    if (token == null || token.isEmpty) return;
    try {
      final ApiClient api = Get.isRegistered<ApiClient>()
          ? Get.find<ApiClient>()
          : ApiClient();
      await api.delete(
        ApiEndpoints.fcmToken,
        body: {'token': token},
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('FCM token unregister failed: $e');
    }
  }
}

/// Top-level background handler (must be a top-level or static function
/// for FirebaseMessaging to pick it up).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep this handler minimal: Firebase is re-initialized in a separate
  // isolate, so heavy work should be avoided. The OS already shows the
  // notification via the default system tray, so we just log here.
  if (kDebugMode) {
    debugPrint('FCM background: ${message.messageId}');
  }
}
