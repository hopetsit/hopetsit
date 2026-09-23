import 'dart:async' show Completer, unawaited;
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/services/app_badge_service.dart';
import 'package:hopetsit/services/deep_link_service.dart';
// v23.1.319 — Daniel (audit) : routage du tap PUSH vers l'écran Notifications.
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';

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

  // v567 — CANAUX « v2 ». Android FIGE un canal à sa création : sur les
  // téléphones passés par le build 565 (fichiers son absents de l'AAB), les
  // canaux `hopetsit_<son>` ont été créés MUETS et le restent à vie, même
  // après mise à jour (et un canal supprimé puis recréé sous le même id
  // retrouve ses anciens réglages). Seule issue : de nouveaux identifiants.
  // Le serveur envoie `hopetsit_<son>_v2` ; une ancienne app qui ne connaît
  // pas ce canal retombe sur le canal par défaut du manifeste.
  static final Int64List _vibration = Int64List.fromList(<int>[0, 220, 120, 260]);

  static AndroidNotificationChannel _soundChannel(String id, String label, String raw) =>
      AndroidNotificationChannel(
        'hopetsit_${id}_v2',
        'HoPetSit — $label',
        description: 'HoPetSit notifications ($label).',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(raw),
        enableVibration: true,
        vibrationPattern: _vibration,
        enableLights: true,
      );

  /// Canal par défaut : bip moderne `chime` (res/raw/chime.wav).
  static final AndroidNotificationChannel _androidChannel =
      _soundChannel('default', 'notifications', 'chime');

  static final List<AndroidNotificationChannel> _soundChannels =
      <AndroidNotificationChannel>[
    _soundChannel('frog', 'frog', 'frog'),
    _soundChannel('bark', 'bark', 'bark'),
    _soundChannel('meow', 'meow', 'meow'),
    _soundChannel('tweet', 'owl', 'tweet'),
    AndroidNotificationChannel(
      'hopetsit_vibrate_v2',
      'HoPetSit — vibrate',
      description: 'HoPetSit notifications with vibration only.',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
      vibrationPattern: _vibration,
    ),
    const AndroidNotificationChannel(
      'hopetsit_silent_v2',
      'HoPetSit — silent',
      description: 'HoPetSit silent notifications.',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    ),
  ];

  /// Anciens canaux (≤ 566) à retirer des réglages du téléphone.
  static const List<String> _legacyChannelIds = <String>[
    'hopetsit_default_channel',
    'hopetsit_frog',
    'hopetsit_bark',
    'hopetsit_meow',
    'hopetsit_tweet',
    'hopetsit_vibrate',
    'hopetsit_silent',
  ];

  /// Canal Android à utiliser pour un son (§2) — `default` → canal historique.
  static AndroidNotificationChannel channelForSound(String? sound) {
    final s = (sound ?? '').trim().toLowerCase();
    for (final c in _soundChannels) {
      if (c.id == 'hopetsit_${s}_v2') return c;
    }
    return _androidChannel;
  }

  /// v566 — petite icône de notification Android (res/drawable/ic_stat_notify.xml,
  /// protégée du réducteur de ressources par res/raw/keep.xml).
  static const String _smallIcon = 'ic_stat_notify';
  static const Color _accent = Color(0xFFD83C28);

  /// v566 — identifiant STABLE de la notification locale affichée pour une
  /// notification serveur : permet de la retirer de la barre système quand elle
  /// est lue sur un autre appareil (événement socket `notification.read`).
  static int localIdFor(String notificationId) =>
      notificationId.hashCode & 0x7fffffff;

  bool _systemBannersAuthorized = false;

  /// v566 — vrai sur iOS quand la bannière SYSTÈME s'affiche déjà pour un push reçu
  /// app ouverte (autorisation accordée + setForegroundNotificationPresentationOptions).
  /// Sert à ne pas afficher EN PLUS le bandeau in-app (demandes d'ami / famille).
  bool get iosShowsSystemBannerInForeground =>
      !kIsWeb && Platform.isIOS && _systemBannersAuthorized;

  bool _initialized = false;

  /// Must be called once at app startup (after Firebase.initializeApp).
  Future<PushNotificationService> init() async {
    if (_initialized) return this;
    _initialized = true;

    try {
      // v583 NEO — plus de demande d'autorisation au tout premier lancement,
      // AVANT l'inscription (audit du 23/09 : la fenêtre iOS s'ouvrait sur
      // l'écran d'accueil, sans explication). Sans session et sans réponse
      // antérieure, on attend l'entrée dans l'app : askAfterEntryIfUndecided()
      // explique d'abord pourquoi, puis pose la question système.
      // Un compte déjà connecté garde le comportement d'avant.
      final current = await _messaging.getNotificationSettings();
      if (current.authorizationStatus == AuthorizationStatus.notDetermined &&
          !_hasSession()) {
        _systemBannersAuthorized = false;
      } else {
        // iOS: request permission. Android 13+ also needs POST_NOTIFICATIONS.
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        _systemBannersAuthorized =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
      }

      // Configure local notifications (used for foreground messages).
      // v566 — audit : petite icône MONOCHROME (patte blanche, drawable vectoriel).
      // `@mipmap/ic_launcher` (icône pleine, opaque) donnait un carré blanc dans
      // la barre d'état Android.
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings(_smallIcon);
      // v583 NEO — ne demande RIEN ici : la seule demande est celle de
      // FirebaseMessaging (ci-dessus ou askAfterEntryIfUndecided), qui couvre
      // aussi les notifications locales sur iOS. Laisser `true` rouvrait la
      // fenêtre système au premier lancement.
      const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);
      // v567 — retire les canaux figés des builds ≤ 566 (voir plus haut).
      for (final id in _legacyChannelIds) {
        try {
          await androidPlugin?.deleteNotificationChannel(id);
        } catch (_) {}
      }
      // v565 — canaux par son (créés au démarrage, idempotent).
      for (final c in _soundChannels) {
        try {
          await androidPlugin?.createNotificationChannel(c);
        } catch (e) {
          debugPrint('createNotificationChannel ${c.id} failed: $e');
        }
      }

      // iOS: display alerts even when the app is in the foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

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
      // v566 — audit : l'obtention du jeton vient APRÈS l'installation des écouteurs et
      // dans son propre try/catch. Avant, sur iOS, un `getToken()` qui levait
      // `apns-token-not-set` (jeton APNs pas encore prêt : premier lancement, réseau
      // lent) sautait TOUT le reste de init() : ni affichage au premier plan, ni
      // ouverture du bon écran au tap, ni onTokenRefresh pour cette session.
      unawaited(_fetchAndRegisterToken());
    } catch (e, st) {
      // Never crash the app because of notifications.
      debugPrint('Push notification init failed: $e\n$st');
    }

    return this;
  }

  bool _hasSession() {
    try {
      if (!Get.isRegistered<ApiClient>()) return false;
      final t = Get.find<ApiClient>().authToken;
      return t != null && t.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void>? _entryAsk;

  /// v583 NEO — question « notifications » posée à l'entrée dans l'app
  /// (inscription ou connexion), une seule fois par session, et seulement si
  /// l'utilisateur n'a jamais répondu. Une phrase par rôle explique d'abord
  /// à quoi elles servent ; « Activer » ouvre ensuite la fenêtre système.
  /// « Plus tard » ne consomme pas la fenêtre système : elle sera posée au
  /// lancement suivant (compte connecté → comportement d'avant).
  /// Plusieurs appelants attendent le MÊME Future (connexion + assistant).
  Future<void> askAfterEntryIfUndecided({String? role}) =>
      _entryAsk ??= _askAfterEntry(role);

  Future<void> _askAfterEntry(String? role) async {
    try {
      // Laisse l'accueil s'afficher (Get.offAll) avant la fenêtre.
      await Future.delayed(const Duration(milliseconds: 1800));
      final current = await _messaging.getNotificationSettings();
      if (current.authorizationStatus != AuthorizationStatus.notDetermined) {
        return;
      }
      final r = (role ?? '').toLowerCase();
      final bodyKey = r.contains('walker')
          ? 'neo583_notif_walker'
          : r.contains('sitter')
              ? 'neo583_notif_sitter'
              : 'neo583_notif_owner';
      final choice = Completer<bool>();
      await Get.dialog<void>(
        CustomConfirmationDialog(
          message: bodyKey.tr,
          yesText: 'neo583_notif_allow'.tr,
          cancelText: 'neo583_notif_later'.tr,
          onYes: () {
            if (!choice.isCompleted) choice.complete(true);
          },
          onCancel: () {
            if (!choice.isCompleted) choice.complete(false);
          },
        ),
        barrierDismissible: false,
      );
      final ok = choice.isCompleted ? await choice.future : false;
      if (!ok) return;
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _systemBannersAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (_systemBannersAuthorized) {
        unawaited(_fetchAndRegisterToken());
      }
    } catch (e) {
      debugPrint('askAfterEntryIfUndecided failed: $e');
    }
  }

  /// v566 — jeton FCM : attend le jeton APNs sur iOS (jusqu'à 3 s), puis réessaie
  /// jusqu'à 3 fois (10 s, 30 s, 60 s) si le jeton n'est pas encore disponible.
  Future<void> _fetchAndRegisterToken({int attempt = 0}) async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        for (int i = 0; i < 6 && (apnsToken == null || apnsToken.isEmpty); i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          apnsToken = await _messaging.getAPNSToken();
        }
        debugPrint('APNs token ready: ${apnsToken != null}');
      }
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        fcmToken.value = token;
        debugPrint('FCM token: $token');
        await _registerTokenOnBackend(token);
        return;
      }
    } catch (e) {
      debugPrint('FCM getToken failed (attempt $attempt): $e');
    }
    const delays = <int>[10, 30, 60];
    if (attempt < delays.length) {
      await Future.delayed(Duration(seconds: delays[attempt]));
      if (fcmToken.value == null || fcmToken.value!.isEmpty) {
        await _fetchAndRegisterToken(attempt: attempt + 1);
      }
    }
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
    // v566 — push « badge seul » (notification lue / supprimée sur un autre appareil) :
    // rien à afficher, on recale seulement la cloche et le badge de l'icône.
    if ((message.data['type'] ?? '').toString() == 'badge_sync') {
      final n = int.tryParse((message.data['unreadCount'] ?? '').toString());
      if (n != null) unawaited(AppBadgeService.set(n, force: true));
      try {
        if (Get.isRegistered<NotificationsController>()) {
          unawaited(Get.find<NotificationsController>().refreshUnreadCount());
        }
      } catch (_) {/* best-effort */}
      return;
    }
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
            // v444 — passe l'id du message (si présent dans le payload FCM) pour
            // PARTAGER la dédup avec le socket message:new → un même message
            // n'incrémente le badge qu'une fois (sinon le resync corrige).
            final msgId = (data['messageId'] ??
                    data['message_id'] ??
                    data['msgId'] ??
                    '')
                .toString();
            nc.bumpUnreadChatImmediate(
                messageId: msgId.isNotEmpty ? msgId : null);
          } else if (bookingTypes.contains(rawType)) {
            nc.bumpUnreadBookingsImmediate();
          }
          // v448 — AUDIT : la CLOCHE (unreadCount) ne doit compter QUE les
          // notifications qui créent vraiment un doc Notification côté serveur.
          // Les messages chat alimentent le badge CHAT (unreadChat) et NON la
          // cloche → sinon la cloche sur-compte (« 5 » alors que la liste des
          // notifications en a 0). On saute donc le bump cloche pour les types
          // chat ; refreshUnreadCount() reste la vérité serveur au resume/ouverture.
          if (!chatTypes.contains(rawType)) {
            nc.bumpUnreadCountImmediate();
          }
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

    // v23.1.317 — Daniel (audit) : éviter le DOUBLE bandeau ami/famille. En 1er
    // plan, ces types affichent déjà un toast in-app (via le socket
    // notification.new dans NotificationsController). On ne montre donc PAS en
    // plus la notif système pour eux → un seul affichage. Le badge + le feed
    // sont déjà mis à jour au-dessus, donc rien n'est perdu.
    final fgType = (message.data['type'] ?? message.data['notificationType'] ?? '')
        .toString()
        .toLowerCase();
    if (fgType.startsWith('friend') || fgType.startsWith('family')) {
      return;
    }

    // v565 — BUG iOS « double bannière » : setForegroundNotificationPresentation
    // Options(alert: true) fait déjà afficher la bannière SYSTÈME pour tout push
    // qui porte un bloc `notification`. Appeler `show` en plus en affichait une
    // deuxième. Sur iOS on ne montre donc PAS de notification locale quand le
    // push a un bloc notification (les badges sont déjà mis à jour ci-dessus) ;
    // un push « data-only » reste affiché localement.
    // v568 — Daniel : « mon téléphone ne vibre pas ». App OUVERTE : on vibre
    // nous-mêmes (en plus du canal), sauf si l'utilisateur a choisi
    // « silencieux ». App fermée : c'est le canal Android v2 qui vibre.
    try {
      final fgSound = (message.data['sound'] ?? '').toString().trim().toLowerCase();
      if (fgSound != 'silent') unawaited(HapticFeedback.vibrate());
    } catch (_) {}

    if (!kIsWeb && Platform.isIOS && notification != null) {
      return;
    }

    final String payload = jsonEncode(message.data);

    // v565 — §2 : le push porte `data.sound` ('default'|'bark'|'meow'|'tweet'|
    // 'vibrate'|'silent') pour l'affichage en premier plan → canal Android
    // correspondant / son APNs `<sound>.caf` sur iOS.
    final sound = (message.data['sound'] ?? '').toString().trim().toLowerCase();
    final channel = channelForSound(sound);
    final bool silent = sound == 'silent';
    final bool vibrateOnly = sound == 'vibrate';
    // v567 — `default` (ou vide) = bip moderne `chime`.
    final bool customSound = !(silent || vibrateOnly);
    final String soundFile = (sound == 'frog' || sound == 'bark' || sound == 'meow' || sound == 'tweet') ? sound : 'chime';

    final serverId = (message.data['notificationId'] ?? '').toString();
    final int localId =
        serverId.isNotEmpty ? localIdFor(serverId) : message.hashCode;

    NotificationDetails details({required bool withCustomSound}) {
      final ch = withCustomSound ? channel : _androidChannel;
      return NotificationDetails(
        android: AndroidNotificationDetails(
          ch.id,
          ch.name,
          channelDescription: ch.description,
          importance: silent ? Importance.low : Importance.high,
          priority: silent ? Priority.low : Priority.high,
          icon: _smallIcon,
          color: _accent,
          playSound: !(silent || vibrateOnly),
          sound: withCustomSound && customSound
              ? RawResourceAndroidNotificationSound(soundFile)
              : null,
          enableVibration: !silent,
          vibrationPattern: silent ? null : _vibration,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: !(silent || vibrateOnly),
          sound: withCustomSound && customSound ? '$soundFile.caf' : null,
        ),
      );
    }

    // v566 — audit : dans l'AAB 565 le réducteur de ressources avait retiré
    // frog/bark/tweet.wav → `show` levait `invalid_sound` et la notification au
    // premier plan n'était JAMAIS affichée. Les fichiers sont désormais protégés
    // (res/raw/keep.xml) ; en plus, si le son manque quand même, on affiche la
    // notification sur le canal par défaut plutôt que de la perdre.
    try {
      await _localNotifications.show(
        localId,
        title,
        body,
        details(withCustomSound: true),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Local notification with custom sound failed ($e) → default channel');
      try {
        await _localNotifications.show(
          localId,
          title,
          body,
          details(withCustomSound: false),
          payload: payload,
        );
      } catch (e2) {
        debugPrint('Local notification failed: $e2');
      }
    }
  }

  /// v566 — Daniel : « quand je mets une notification en lu sur un appareil, les
  /// autres doivent se synchroniser ». Retire de la barre système ce qui vient
  /// d'être lu / supprimé ailleurs :
  ///   • tout lu, ou plus aucune non lue → on vide la barre (`cancelAll`, qui
  ///     retire aussi les notifications affichées par le système / FCM) ;
  ///   • sinon → la notification locale de chaque id (identifiant stable
  ///     `localIdFor`) et, sur Android, les notifications système au même
  ///     titre + corps (celles affichées par FCM app fermée n'ont pas notre id).
  Future<void> dismissSystemNotifications({
    bool all = false,
    Iterable<String> ids = const <String>[],
    int? unreadCount,
    Iterable<({String title, String body})> contents =
        const <({String title, String body})>[],
  }) async {
    try {
      if (all || (unreadCount != null && unreadCount <= 0)) {
        await _localNotifications.cancelAll();
        return;
      }
      for (final id in ids) {
        if (id.isEmpty) continue;
        await _localNotifications.cancel(localIdFor(id));
      }
      if (!kIsWeb && Platform.isAndroid && contents.isNotEmpty) {
        final active = await _localNotifications.getActiveNotifications();
        for (final a in active) {
          final match = contents.any((c) =>
              c.title.isNotEmpty &&
              (a.title ?? '') == c.title &&
              (a.body ?? '') == c.body);
          if (match && a.id != null) {
            await _localNotifications.cancel(a.id!, tag: a.tag);
          }
        }
      }
    } catch (e) {
      debugPrint('dismissSystemNotifications failed: $e');
    }
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
    if (type == 'badge_sync') return; // v566 — jamais de navigation pour un push « badge seul »

    // Always refresh so the in-app list shows the new entry.
    try {
      if (Get.isRegistered<NotificationsController>()) {
        unawaited(Get.find<NotificationsController>().refreshAll());
      }
    } catch (_) {
      // Defensive: never let a refresh failure crash the FCM handler.
    }

    // v23.1.319 — Daniel (audit) : AVANT, taper une notification PUSH ne
    // naviguait vers RIEN (juste un debugPrint) → l'app s'ouvrait sur la home,
    // cul-de-sac pour TOUS les types. On ouvre désormais l'écran Notifications
    // (la cloche), d'où le tap sur l'item route vers le bon écran via
    // _navigateForNotification (wallet / booking / chat / amis / boutique...).
    // v561 — Daniel : « le push doit envoyer direct sur l'app au thème
    // correspondant ». Le serveur met désormais le chemin (`route`) dans le
    // payload ; à défaut (ancien push), on le déduit du type. La navigation
    // passe par le routeur des liens universels (attend que le menu soit
    // monté au démarrage à froid → plus d'écran noir).
    try {
      var route = (data['route'] ?? '').toString().trim();
      if (route.isEmpty || !route.startsWith('/')) {
        route = DeepLinkService.routeForNotification(type, data);
      }
      // v575 — audit P1-3 : le serveur dit désormais pour QUEL profil la
      // notification a été émise. Si ce n'est pas le profil actif, on
      // n'ouvre pas un écran qui répondrait 403 : `openRoute` affiche la
      // liste des notifications avec un bandeau traduit.
      final recipientRole = (data['recipientRole'] ?? '').toString();
      unawaited(
        DeepLinkService.instance
            .openRoute(route, recipientRole: recipientRole),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FCM tap nav failed (type=$type): $e');
      try {
        Get.to(() => const NotificationsScreen());
      } catch (_) {/* noop */}
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
        // v23.1.396b — même fix iOS qu'à l'init : attendre le token APNs avant
        // getToken() pour qu'un compte connecté après le boot enregistre bien
        // son token (sinon push iOS jamais livré pour ce compte).
        if (Platform.isIOS) {
          String? apnsToken = await _messaging.getAPNSToken();
          for (int i = 0; i < 6 && (apnsToken == null || apnsToken.isEmpty); i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            apnsToken = await _messaging.getAPNSToken();
          }
        }
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
    // v566 — badge de l'icône remis à 0 (déconnexion).
    await AppBadgeService.clear();
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
