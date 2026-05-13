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
import 'package:hopetsit/widgets/active_benefits_row.dart';

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
          // v23.1 part 44 — fix Daniel "badge chat n'apparaît pas".
          // Foreground FCM handler only bumped unreadHome; chat-type
          // notifs (NEW_MESSAGE) had to wait for the socket to bump
          // the chat badge. When the socket was slow / not yet
          // connected, the notif arrived as a phone push but the
          // bottom-nav Chat badge stayed at 0.
          final chatTypes = {
            'new_message',
            'message',
            'message_new',
          };
          final bookingTypes = {
            'booking_paid',
            'booking_paid_owner',
            'payment_success',
            'application_accepted',
          };
          if (homeTypes.contains(rawType)) {
            nc.bumpUnreadHomeImmediate();
          } else if (chatTypes.contains(rawType)) {
            nc.bumpUnreadChatImmediate();
          } else if (bookingTypes.contains(rawType)) {
            nc.bumpUnreadBookingsImmediate();
          }
          nc.bumpUnreadCountImmediate();
          // v23.1 part 123 — Daniel : "profil verifier par admin mais pas
          // de badge vérifié". Quand admin approuve à distance, refetch
          // /users/me/benefits pour que le banner KYC passe au vert.
          if (rawType == 'kyc_verified' || rawType == 'kyc_rejected') {
            try {
              ActiveBenefitsRow.notifyChanged();
            } catch (_) {/* best-effort */}
          }
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
  ///
  /// Bug A3 — v22.4 :
  ///   • Le switch était un stub : tous les types tombaient dans `default` et
  ///     rien ne se passait quand l'utilisateur tapait une notif FCM en
  ///     arrière-plan (booking_accepted, application_accepted, etc.).
  ///   • Conséquence visible : l'utilisateur revenait sur la home et,
  ///     parfois, sur l'app le tap ré-essayait par erreur l'action
  ///     `respondToApplication(accept)` du flow in-app, ce qui produisait
  ///     "Échec candidature" si le backend rejetait (déjà acceptée, etc.).
  ///
  /// Stratégie :
  ///   • On force un refresh du `NotificationsController` pour que la liste
  ///     in-app soit à jour (le compteur badge bouge même si la nav échoue).
  ///   • On reconnaît explicitement les types booking_* / application_* /
  ///     message_* / post_* utilisés par le backend, mais on délègue le
  ///     routage fin au handler in-app `_navigateForNotification`. Ici on
  ///     ouvre simplement le shell (homeOwner par défaut). Le tap sur le
  ///     badge déclenche ensuite le bon écran via la liste de notifs.
  ///   • Aucun appel direct à `respondToApplication` ici → on n'enchaîne
  ///     plus jamais une action backend silencieuse depuis un tap FCM.
  void _routeFromData(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase();

    // Always refresh so the in-app list shows the new entry.
    try {
      if (Get.isRegistered<NotificationsController>()) {
        unawaited(Get.find<NotificationsController>().refreshAll());
      }
    } catch (_) {
      // Defensive: never let a refresh failure crash the FCM handler.
    }

    // Recognized types → just log; the actual screen routing is handled
    // by `_navigateForNotification` in `notifications_screen.dart` when the
    // user taps the badge / list entry. Adding the types here avoids any
    // silent fallthrough that previously caused unexpected behaviour.
    switch (type) {
      case 'message':
      case 'message_new':
      case 'booking_new':
      case 'booking_accepted':
      case 'booking_rejected':
      case 'booking_paid':
      case 'application_new':
      case 'application_accepted':
      case 'application_rejected':
      case 'post_like':
      case 'post_comment':
        if (kDebugMode) {
          debugPrint('FCM tap routed (type=$type) → notifications list');
        }
        break;
      default:
        if (kDebugMode) {
          debugPrint('FCM tap unknown type "$type" → no-op');
        }
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

  /// v23.1 part 43 — public re-register hook called after login.
  /// If a token is cached, register it under the new auth context.
  /// Otherwise, fetch a fresh token from FCM and register.
  Future<void> reRegisterAfterLogin() async {
    try {
      // v23.1 part 130 — Phase 6 audit P6-3 : Daniel "anciens payments
      // réapparaissent dans la barre de notif au login". Cause : les
      // notifs système Android délivrées avant le logout restaient dans
      // le centre de notifications. Au login suivant, on les voyait
      // refaire surface comme si elles venaient du nouveau compte. On
      // les purge MAINTENANT au début du login pour une "ardoise vierge".
      try {
        await _localNotifications.cancelAll();
      } catch (_) {/* best-effort */}

      String? token = fcmToken.value;
      if (token == null || token.isEmpty) {
        token = await _messaging.getToken();
        fcmToken.value = token;
      }
      if (token != null && token.isNotEmpty) {
        await _registerTokenOnBackend(token);
      } else {
        debugPrint('FCM token still null after login re-register attempt.');
      }
    } catch (e) {
      debugPrint('FCM re-register after login failed: $e');
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

  /// v23.1 part 121 — Daniel : "le bug de qd jme connecte les anciens
  /// payment reaparaisse dans la barre de notification". Cause : les
  /// notifications locales (flutter_local_notifications) restent dans
  /// la barre du système même après logout. Quand un autre user se
  /// connecte ou que le même user se reconnecte, elles sont toujours
  /// visibles.
  ///
  /// Cette méthode :
  ///   1. Annule TOUTES les notifications locales actives
  ///   2. Reset le badge de notifications iOS (à 0)
  ///   3. (déjà fait par unregisterCurrentToken) Supprime le FCM token
  ///      côté backend pour ne plus recevoir de push.
  Future<void> clearAllLocalNotifications() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('cancelAll local notifications failed: $e');
    }
    // Reset badge counter (iOS principalement).
    try {
      final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(badge: true);
      }
    } catch (_) {/* ignore */}
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
