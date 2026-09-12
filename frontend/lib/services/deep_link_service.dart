import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
// v532 — lien de partage d'un PawSpot (/spot/<id>) → ouvre la carte.
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/payment/airwallex_payment_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
// v23.1.286 — Daniel : "un mail message m'a ouvert la page Signaler".
// CAUSE : le deep-link routait vers des routes nommées NON enregistrées
// (Get.toNamed('/chat'…)) → échec silencieux → l'app restait sur l'onglet par
// défaut (PawMap + bouton Signaler). On pousse désormais le VRAI écran, par
// rôle, comme le fait déjà /friends.
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
// v561 — routeur unifié mail / push / cloche → écran précis.
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/views/friends/people_live_screen.dart';
import 'package:hopetsit/views/notifications/notification_post_view_screen.dart';
import 'package:hopetsit/views/pet_owner/booking-application/owner_booking_detail_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/views/pet_owner/booking/owner_bookings_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking/sitter_bookings_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/sitter_profile_screen.dart';
import 'package:hopetsit/views/pet_walker/booking/walker_bookings_screen.dart';
import 'package:hopetsit/views/pet_walker/profile/walker_profile_screen.dart';
import 'package:hopetsit/views/profile/profile_screen.dart';

/// v18.8 — écoute les deep links `hopetsit://pay/:bookingId` envoyés dans
/// les emails "Bonne nouvelle, votre demande de réservation vient d'être
/// acceptée". Avant v18.8, le bouton "Payer maintenant" du mail ouvrait
/// l'app mais n'ouvrait PAS la page de paiement → l'owner devait naviguer
/// à la main vers Réservations. Désormais on route automatiquement vers
/// `AirwallexPaymentScreen(booking: ..., providerType: ...)`.
///
/// v23.1 part 146 — Bug fix : écran noir indéfini quand l'app était lancée
/// via un lien `https://www.hopetsit.com/...` (cliqué depuis un email ou
/// un partage). 3 causes cumulées :
///   1. `www.hopetsit.com` n'était pas dans la whitelist → handle rejette
///      silencieusement, mais l'app a quand même reçu un Intent VIEW qui
///      peut bloquer le boot Flutter.
///   2. Race condition : `start()` était appelé AVANT `runApp(MyApp())`
///      donc `Get.to(...)` côté handler push dans un GetMaterialApp non
///      encore monté → navigation cassée + écran noir.
///   3. Aucun fallback pour les paths non reconnus (`/`, `/login`, `/walkers`,
///      etc.) → l'app recevait le lien mais ne savait pas quoi en faire.
///
/// Fix :
///   - Whitelist élargie : `hopetsit.com`, `www.hopetsit.com`, `app.hopetsit.com`
///   - Buffering : si la nav GetX n'est pas encore prête (Get.context == null
///     ou GetMaterialApp pas monté), on stocke l'URI dans `_pendingUri` et on
///     la rejoue via [flushPending()] appelé après le premier frame de MyApp.
///   - Try/catch ultra-large dans `_handle` → jamais d'exception qui remonte
///     vers le main isolate.
///   - Fallback gracieux : path non reconnu → on log et on laisse le splash
///     router normalement (pas d'écran noir).
class DeepLinkService {
  DeepLinkService._internal();
  static final DeepLinkService instance = DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// v23.1 part 146 — URIs reçues AVANT que `GetMaterialApp` soit monté.
  /// On les rejoue via [flushPending] au premier frame.
  final List<Uri> _pendingUris = <Uri>[];

  /// v23.1 part 146 — true une fois que `MyApp` a fait son premier frame et
  /// que `Get.context` est utilisable. Mis à true par [flushPending].
  bool _navigatorReady = false;

  /// À appeler au démarrage de l'app (après Get.put des repos/controllers).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _safeHandle(initial);
      }
    } catch (e) {
      AppLogger.logError('DeepLinkService.getInitialLink failed', error: e);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _safeHandle(uri);
      },
      onError: (Object e) {
        AppLogger.logError('DeepLinkService stream error', error: e);
      },
    );
  }

  /// v23.1 part 146 — wrapper paranoïaque : aucune exception ne remonte au
  /// main isolate. Si le navigator n'est pas encore prêt, on bufferise.
  Future<void> _safeHandle(Uri uri) async {
    try {
      if (!_navigatorReady) {
        AppLogger.logInfo(
          'DeepLink buffered (navigator not ready): ${uri.scheme}://${uri.host}${uri.path}',
        );
        _pendingUris.add(uri);
        return;
      }
      await _handle(uri);
    } catch (e, st) {
      // Catch large : on ne propage JAMAIS — sinon écran noir au boot.
      AppLogger.logError(
        'DeepLinkService._safeHandle failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// v23.1 part 146 — appelée depuis `MyApp` (ou splash) après le premier
  /// frame. Marque le navigator comme prêt et rejoue les URIs bufferisées.
  Future<void> flushPending() async {
    _navigatorReady = true;
    if (_pendingUris.isEmpty) return;
    final pending = List<Uri>.from(_pendingUris);
    _pendingUris.clear();
    AppLogger.logInfo(
      'DeepLink flushing ${pending.length} buffered URI(s)',
    );
    for (final uri in pending) {
      try {
        await _handle(uri);
      } catch (e, st) {
        AppLogger.logError(
          'DeepLinkService flushPending failed for $uri',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
    _navigatorReady = false;
    _pendingUris.clear();
  }

  /// v23.1 part 125 — Phase 2 audit M1.
  /// Regex strict pour valider un Mongo ObjectId 24 hex chars. Tout autre
  /// pattern (URL malicieuse passée via Intent depuis une app tierce, ou
  /// payload nullbyte/SQLi style) est rejeté AVANT navigation.
  static final RegExp _objectIdRegex = RegExp(r'^[a-fA-F0-9]{24}$');

  /// v23.1 part 146 — Regex stricte pour le one-time token de bridge web→app.
  /// Format : 64 chars hex lowercase (32 bytes random côté backend).
  /// Toute autre chaîne est rejetée avant l'appel `/auth/exchange`.
  static final RegExp _ottRegex = RegExp(r'^[a-f0-9]{64}$');

  /// v23.1 part 146 — hosts HTTPS autorisés pour les App Links.
  /// Inclut `www.` car Vercel sert le site sur les deux variantes et
  /// l'utilisateur peut taper sur n'importe laquelle depuis un email.
  static const Set<String> _allowedHttpsHosts = <String>{
    'hopetsit.com',
    'www.hopetsit.com',
    'app.hopetsit.com',
  };

  Future<void> _handle(Uri uri) async {
    // v23.1 part 125 — accepte exclusivement :
    //   hopetsit://<action>[/<arg>]                    (deep link app)
    //   https://hopetsit.com/<action>[/<arg>]          (App Links signés)
    //   https://www.hopetsit.com/<action>[/<arg>]      (variante www, v146)
    //   https://app.hopetsit.com/<action>[/<arg>]      (sous-domaine futur)
    // Tout autre host HTTPS est rejeté — empêche une app tierce de
    // forger une URL `https://malicious.example/pay/<id>` qui serait
    // résolue par notre AppLinks listener.
    if (uri.scheme == 'hopetsit') {
      // OK, scheme custom propre.
    } else if (uri.scheme == 'https' && _allowedHttpsHosts.contains(uri.host)) {
      // OK, App Links signés (autoVerify=true en manifest).
    } else {
      AppLogger.logWarning(
        'DeepLink rejected (unsupported scheme/host): ${uri.scheme}://${uri.host}',
      );
      return;
    }

    final segs = uri.pathSegments;
    final first =
        uri.host.isNotEmpty && uri.scheme == 'hopetsit'
            ? uri.host
            : (segs.isNotEmpty ? segs.first : '');

    // v19.2.0 — 4 chemins supportés :
    //   hopetsit://pay/:bookingId          → écran paiement
    //   hopetsit://chat[/:conversationId]  → écran chat (liste ou conversation)
    //   hopetsit://bookings[/:bookingId]   → écran réservations (provider accepte)
    //   hopetsit://notifications           → écran notifications
    // v23.1 part 146 — 5e chemin :
    //   hopetsit://auth?ott=<token>        → bridge session web → app
    // v449 — lien canonique des emails : `https://hopetsit.com/open`
    // (ou `hopetsit://open`). Objectif voulu par Daniel : « email → app si
    // installée ; sinon /download. Ne route PAS vers une conversation
    // précise ». Côté app, le simple fait d'avoir intercepté le lien suffit :
    // l'app est ouverte (ou ramenée au premier plan). Si l'utilisateur n'est
    // pas connecté, le splash/auth affiche le login puis l'accueil — flux
    // standard. On NE navigue donc nulle part : no-op gracieux.
    // v496 — Daniel : « depuis l'email, mon ami a cliqué "Voir la demande" →
    // GRAND ÉCRAN NOIR ». CAUSE RACINE : le lien App Link ouvre l'app et on
    // faisait Get.to(FriendsScreen) (ou autre écran authentifié) MÊME quand
    // l'utilisateur n'a PAS de session → l'écran exige auth + controllers non
    // initialisés → rendu NOIR. FIX : sans session, on ne navigue NULLE PART
    // (no-op gracieux) → le splash/onboarding affiche l'accueil public
    // (S'inscrire / Se connecter), exactement comme /open. Le pending link est
    // mémorisé pour reprise après login. Seuls open/app/auth passent sans
    // session (auth gère sa propre connexion via OTT).
    // v546 — Daniel : « améliore l'ajout d'amis ». Le bouton Partager de
    // l'écran Amis envoyait déjà https://hopetsit.com/invite?from=<id>, mais
    // RIEN ne traitait ce lien à l'arrivée : l'app s'ouvrait et c'est tout.
    // Désormais : avec session → demande d'ami envoyée automatiquement ;
    // sans session → l'invitation est mémorisée et rejouée juste après la
    // connexion ou l'inscription (cf. replayPendingInvite).
    if (first == 'invite') {
      await _handleInvite(uri);
      return;
    }

    final isPublicLink = first == 'open' || first == 'app' || first == 'auth';
    if (!isPublicLink && !_hasSession()) {
      // v561 — on mémorise la destination : elle est rejouée juste après la
      // connexion (replayPendingRoute), au lieu d'être perdue.
      _rememberPendingRoute(uri);
      AppLogger.logInfo(
        'DeepLink "$first" reçu SANS session → mémorisé, rejoué après login '
        '(onboarding/login s\'affiche au lieu d\'un écran noir).',
      );
      return;
    }
    if (first == 'open' || first == 'app') {
      AppLogger.logInfo('DeepLink /open — app ouverte (aucune navigation).');
      return;
    }
    // v561 — Daniel : « du mail : écran noir » / « ça me renvoie d'abord sur
    // le site ». Toute destination authentifiée attend que le menu principal
    // (StackedNavigationWrapper) soit monté : au démarrage à froid par un
    // lien ou un push, Get.to() partait AVANT l'accueil → pile vide = noir.
    await _waitForShell();
    final second = segs.length > 1 ? segs[1] : '';
    if (first == 'pay') {
      // v23.1 part 125 — bookingId DOIT être un ObjectId 24 hex. Sinon
      // on log et on ignore (anti Intent Redirection).
      // v23.1.155 — accepte aussi `?bookingId=<id>` (format query param
      // utilise par emailLinkBuilder.js cote backend pour les liens
      // /pay sans path arg).
      var rawBookingId = segs.isNotEmpty ? segs.last : '';
      if (rawBookingId.isEmpty || rawBookingId == 'pay') {
        rawBookingId = uri.queryParameters['bookingId'] ?? '';
      }
      if (!_objectIdRegex.hasMatch(rawBookingId)) {
        AppLogger.logWarning(
          'DeepLink rejected (invalid bookingId): "$rawBookingId"',
        );
        _openBookingsScreen();
        return;
      }
      await _openPayment(rawBookingId);
    } else if (first == 'chat') {
      // v561 — /chat/:conversationId ouvre LA conversation (rôle courant) ;
      // /chat seul ouvre la liste.
      if (_objectIdRegex.hasMatch(second)) {
        await _openConversation(second, uri.queryParameters);
      } else {
        _openChatList();
      }
    } else if (first == 'bookings' || first == 'walk') {
      // v561 — /bookings/:id → fiche de la réservation (propriétaire) ; liste
      // pour les prestataires (leurs boutons d'action y sont). /walk/:id idem
      // (le suivi de balade est intégré à la réservation).
      if (_objectIdRegex.hasMatch(second) && _currentRole() == 'owner') {
        await _openOwnerBookingDetail(second);
      } else {
        _openBookingsScreen();
      }
    } else if (first == 'notifications') {
      _openNotificationsScreen();
    } else if (first == 'book' || first == 'post') {
      // v561 — /post/:id → la fiche de l'annonce ; sans id → réservations.
      if (_objectIdRegex.hasMatch(second)) {
        await _openPost(second);
      } else {
        _openBookingsScreen();
      }
    } else if (first == 'posts') {
      // v561 — mails du cycle de vie « publie une annonce » → accueil, onglet
      // « Mes annonces » (premier onglet de l'accueil propriétaire).
      _goToTab(0);
    } else if (first == 'wallet') {
      // v561 — écran Portefeuille (solde, versements, retraits).
      Get.to(() => const WalletScreen());
    } else if (first == 'subscription') {
      Get.to(() => const CoinShopScreen(initialTab: 3));
    } else if (first == 'paw-spot' || first == 'pawspot') {
      Get.to(() => const CoinShopScreen(initialTab: 2));
    } else if (first == 'shop') {
      Get.to(() => const CoinShopScreen());
    } else if (first == 'spot') {
      // v532 — lien de PARTAGE d'un PawSpot : https://hopetsit.com/spot/<id>.
      // v552 — Daniel : « que ça tombe sur la chose précise ». On passe l'id
      // à la carte, qui se centre sur le spot et ouvre sa fiche au lieu de
      // s'ouvrir n'importe où.
      final spotId = segs.length > 1 ? segs[1] : (uri.queryParameters['id'] ?? '');
      Get.to(() => PawMapScreen(
            focusSpotId: _objectIdRegex.hasMatch(spotId) ? spotId : null,
          ));
    } else if (first == 'alert' || first == 'alerte' || first == 'report') {
      // v552 — lien de partage d'un signalement / d'un SOS animal :
      // https://hopetsit.com/alert/<id> → carte centrée + fiche ouverte.
      final reportId =
          segs.length > 1 ? segs[1] : (uri.queryParameters['id'] ?? '');
      Get.to(() => PawMapScreen(
            focusReportId:
                _objectIdRegex.hasMatch(reportId) ? reportId : null,
          ));
    } else if (first == 'map' || first == 'pawmap') {
      // v552 — « Partager la carte » : https://hopetsit.com/map?lat&lng&z
      // rouvre la PawMap exactement au même endroit et au même zoom.
      final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
      final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
      final z = double.tryParse(uri.queryParameters['z'] ?? '');
      // v559 — `&route=1` : ouvrir la carte avec l'itinéraire déjà lancé vers
      // ce point (modes à pied / vélo / voiture + virages).
      final route = uri.queryParameters['route'] == '1';
      if (route && lat != null && lng != null) {
        openPawMapWithRoute(lat, lng); // onglet PawMap (menu conservé) si possible
      } else if (lat == null && lng == null && navWrapperMounted.value) {
        // v561 — /pawmap ou /map sans position : l'onglet PawMap (menu
        // conservé) au lieu d'une carte poussée sans menu.
        _goToTab(kPawMapTabIndex);
      } else {
        Get.to(() => PawMapScreen(
              initialLat: lat,
              initialLng: lng,
              initialZoom: z,
            ));
      }
    } else if (first == 'profile') {
      _openProfileScreen();
    } else if (first == 'friends' || first == 'amis' ||
               first == 'family' || first == 'live') {
      // v561 — Daniel : « Voir la demande / Voir mes amis depuis le mail ».
      //   /friends            → onglet « Mes amis »
      //   /friends/requests   → onglet « Demandes » (accepter / refuser)
      //   /friends/family ou /family → onglet « Famille »
      //   /friends/live ou /live     → personnes en direct
      final sub = first == 'friends' || first == 'amis' ? second : first;
      if (sub == 'live') {
        Get.to(() => const PeopleLiveScreen());
      } else if (sub == 'requests' || sub == 'demandes') {
        Get.to(() => const FriendsScreen(initialIndex: 1));
      } else if (sub == 'family' || sub == 'famille') {
        Get.to(() => const FriendsScreen(initialIndex: 3));
      } else {
        Get.to(() => const FriendsScreen());
      }
    } else if (first == 'auth') {
      // v23.1 part 146 — auto-login via one-time token issued by the website.
      // Format attendu : hopetsit://auth?ott=<64 hex>
      //              ou : https://hopetsit.com/auth?ott=<64 hex>
      final ott = uri.queryParameters['ott'];
      if (ott == null || !_ottRegex.hasMatch(ott)) {
        AppLogger.logWarning(
          'DeepLink rejected (invalid ott): "${ott ?? "<null>"}"',
        );
        return;
      }
      await _handleAuthOtt(ott);
    } else {
      AppLogger.logInfo(
        'DeepLink path not handled (no-op): "${uri.path}"',
      );
    }
  }

  // ───────────────────────── v561 — routeur unifié ─────────────────────────

  /// Ouvre une route « thème » (`/friends/requests`, `/chat/<id>`,
  /// `/bookings/<id>`, `/alert/<id>`…) exactement comme un lien universel.
  /// Utilisé par le tap sur un push (champ `route` du payload) et par la
  /// cloche. Une route sans `/` initial est acceptée.
  Future<void> openRoute(String route) async {
    final r = route.trim();
    if (r.isEmpty) return;
    final path = r.startsWith('/') ? r : '/$r';
    await _safeHandle(Uri.parse('https://hopetsit.com$path'));
  }

  /// Route « thème » pour un type de notification (miroir de
  /// backend/src/utils/emailLinkBuilder.js → buildAppRoute). Sert aux pushs
  /// anciens sans champ `route` et à la cloche.
  static String routeForNotification(String type, Map<String, dynamic>? data) {
    final t = type.toLowerCase();
    final d = data ?? const <String, dynamic>{};
    String id(String key) {
      final v = (d[key] ?? '').toString();
      return _objectIdRegex.hasMatch(v) ? v : '';
    }
    final bookingId = id('bookingId').isNotEmpty ? id('bookingId') : id('id');
    final bookingPath = bookingId.isNotEmpty ? '/bookings/$bookingId' : '/bookings';
    final conv = id('conversationId');
    final chatPath = conv.isNotEmpty ? '/chat/$conv' : '/chat';
    final postId = id('postId');
    final postPath = postId.isNotEmpty ? '/post/$postId' : '/bookings';
    final reportId = id('reportId');
    if (t == 'booking_accepted' || t == 'payment_failed' || t == 'payment_required') {
      return bookingId.isNotEmpty ? '/pay?bookingId=$bookingId' : bookingPath;
    }
    if (t == 'new_message' || t == 'message' || t == 'message_new' ||
        t == 'chat_auto_welcome' || t == 'booking_paid_chat_unlocked') {
      return conv.isNotEmpty
          ? chatPath
          : (t == 'booking_paid_chat_unlocked' ? bookingPath : '/chat');
    }
    if (t == 'chat_addon_activated') return '/chat';
    if (t == 'walk_started' || t == 'walk_finished') {
      return bookingId.isNotEmpty ? '/walk/$bookingId' : bookingPath;
    }
    if (t == 'new_request_nearby' || t == 'post_new' ||
        t == 'post_application_eligible' ||
        t == 'application_rejected_other_accepted' ||
        t.startsWith('post_')) {
      return postPath;
    }
    if (t.startsWith('booking_') || t.startsWith('application_') ||
        t.startsWith('service_') || t == 'visit_report' ||
        t == 'payment_success') {
      return bookingPath;
    }
    if (t.startsWith('payout_') || t.startsWith('withdrawal_') ||
        t == 'wallet_credited' || t.contains('wallet')) {
      return '/wallet';
    }
    if (t == 'new_review' || t == 'premium_achieved' ||
        t == 'top_sitter_achieved' || t.startsWith('kyc_')) {
      return '/profile';
    }
    if (t == 'referral_credited' || t.startsWith('map_boost') ||
        t == 'profile_boost_activated') {
      return '/paw-spot';
    }
    if (t.startsWith('subscription_')) return '/subscription';
    if (t == 'friend_request_received' || t == 'family_invitation_received') {
      return '/friends/requests';
    }
    if (t == 'live_tracking_request_received') {
      return conv.isNotEmpty ? chatPath : '/friends/requests';
    }
    if (t == 'live_tracking_accepted') return '/friends/live';
    if (t.startsWith('friend_') || t.startsWith('family_') ||
        t.startsWith('live_tracking')) {
      return '/friends';
    }
    if (t == 'sos_pet_nearby' || t == 'lost_pet_sighting') {
      return reportId.isNotEmpty ? '/alert/$reportId' : '/map';
    }
    return '/notifications';
  }

  static const _pendingRouteKey = 'pending_deep_route';

  void _rememberPendingRoute(Uri uri) {
    try {
      final path = uri.scheme == 'hopetsit'
          ? '/${uri.host}${uri.path}'
          : uri.path;
      final q = uri.hasQuery ? '?${uri.query}' : '';
      GetStorage().write(_pendingRouteKey, '$path$q');
    } catch (_) {/* best-effort */}
  }

  /// Appelé après une connexion réussie : rejoue la destination d'un lien /
  /// push reçu alors que l'utilisateur n'était pas connecté.
  static Future<void> replayPendingRoute() async {
    String? route;
    try {
      route = GetStorage().read(_pendingRouteKey) as String?;
      GetStorage().remove(_pendingRouteKey);
    } catch (_) {
      route = null;
    }
    if (route == null || route.isEmpty) return;
    await Future.delayed(const Duration(milliseconds: 1200));
    await instance.openRoute(route);
  }

  /// Attend (max ~6 s) que le menu principal soit monté avant de pousser un
  /// écran authentifié. Sans ça, au démarrage à froid via lien/push, la pile
  /// de navigation est vide → écran noir.
  Future<void> _waitForShell() async {
    for (var i = 0; i < 30 && !navWrapperMounted.value; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!navWrapperMounted.value) {
      AppLogger.logWarning('DeepLink: menu principal non monté après 6 s, on navigue quand même.');
    }
  }

  void _goToTab(int index) {
    if (navWrapperMounted.value) {
      try {
        Get.until((route) => route.isFirst);
      } catch (_) {/* déjà à la racine */}
      requestedTab.value = index;
    }
  }

  Future<void> _openConversation(String conversationId, Map<String, String> q) async {
    final isSitter = _currentRole() != 'owner';
    String name = (q['name'] ?? '').trim();
    String image = '';
    try {
      if (isSitter) {
        if (!Get.isRegistered<SitterChatController>()) {
          Get.put(SitterChatController(Get.find<ChatRepository>(), storage: Get.find<GetStorage>()));
        }
        final c = Get.find<SitterChatController>();
        await c.reloadConversations();
        for (final conv in c.conversations) {
          if (conv.id == conversationId) {
            if (name.isEmpty) name = conv.contactName;
            image = conv.contactImage;
            break;
          }
        }
      } else {
        if (!Get.isRegistered<ChatController>()) {
          Get.put(ChatController(Get.find<ChatRepository>(), storage: Get.find<GetStorage>()));
        }
        final c = Get.find<ChatController>();
        await c.reloadConversations();
        for (final conv in c.conversations) {
          if (conv.id == conversationId) {
            if (name.isEmpty) name = conv.contactName;
            image = conv.contactImage;
            break;
          }
        }
      }
    } catch (e) {
      AppLogger.logError('DeepLink _openConversation: contact lookup failed', error: e);
    }
    if (name.isEmpty || name == 'Unknown') name = 'common_user'.tr;
    if (isSitter) {
      Get.to(() => SitterIndividualChatScreen(
            conversationId: conversationId,
            contactName: name,
            contactImage: image,
          ));
    } else {
      Get.to(() => IndividualChatScreen(
            conversationId: conversationId,
            contactName: name,
            contactImage: image,
          ));
    }
  }

  Future<void> _openOwnerBookingDetail(String bookingId) async {
    BookingModel? booking;
    try {
      if (Get.isRegistered<BookingsController>()) {
        booking = Get.find<BookingsController>()
            .bookings
            .firstWhereOrNull((b) => b.id == bookingId);
      }
      if (booking == null && Get.isRegistered<OwnerRepository>()) {
        final all = await Get.find<OwnerRepository>().getMyBookings();
        booking = all.firstWhereOrNull((b) => b.id == bookingId);
      }
    } catch (e) {
      AppLogger.logError('DeepLink _openOwnerBookingDetail failed', error: e);
    }
    if (booking == null) {
      _openBookingsScreen();
      return;
    }
    final b = booking;
    Get.to(() => OwnerBookingDetailScreen(
          booking: b,
          onPay: () => _openPayment(b.id),
        ));
  }

  Future<void> _openPost(String postId) async {
    PostModel? post;
    try {
      final pc = Get.isRegistered<PostsController>()
          ? Get.find<PostsController>()
          : Get.put(PostsController());
      PostModel? find() {
        for (final p in pc.posts) {
          if (p.id == postId) return p;
        }
        for (final p in pc.postsWithoutMedia) {
          if (p.id == postId) return p;
        }
        return null;
      }
      post = find();
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
    } catch (e) {
      AppLogger.logError('DeepLink _openPost failed', error: e);
    }
    if (post == null) {
      _openBookingsScreen();
      return;
    }
    final p = post;
    Get.to(() => NotificationPostViewScreen(post: p));
  }

  // v23.1.286 — navigation par rôle vers les VRAIS écrans (les routes nommées
  // /chat, /bookings… n'étaient pas enregistrées → no-op). On pousse l'écran
  // comme le fait /friends. Le rôle vient de AuthController.
  String _currentRole() {
    try {
      return (Get.find<AuthController>().userRole.value ?? '').toLowerCase();
    } catch (_) {
      return 'owner';
    }
  }

  static const _pendingInviteKey = 'pending_friend_invite';

  /// v546 — `/invite?from=ID&role=owner|sitter|walker`
  /// (ou `/invite/ROLE/ID`). Envoie la demande d'ami si une session existe,
  /// sinon mémorise l'invitation pour la rejouer après connexion.
  Future<void> _handleInvite(Uri uri) async {
    final segs = uri.pathSegments;
    var fromId = (uri.queryParameters['from'] ?? '').trim();
    var role = (uri.queryParameters['role'] ?? '').trim().toLowerCase();
    if (fromId.isEmpty && segs.length >= 3 && segs.first == 'invite') {
      role = segs[1].toLowerCase();
      fromId = segs[2];
    }
    if (!_objectIdRegex.hasMatch(fromId)) {
      AppLogger.logWarning('DeepLink invite rejeté (id invalide): "$fromId"');
      return;
    }
    if (!const {'owner', 'sitter', 'walker'}.contains(role)) role = 'owner';

    if (!_hasSession()) {
      try {
        GetStorage().write(_pendingInviteKey, {'from': fromId, 'role': role});
      } catch (_) {/* best-effort */}
      AppLogger.logInfo(
        'DeepLink invite mémorisé (pas de session) → rejoué après connexion.',
      );
      return;
    }
    await _sendInvite(fromId, role);
  }

  /// Appelé après une connexion / inscription réussie (AuthController) :
  /// rejoue l'invitation reçue quand l'utilisateur n'était pas connecté.
  static Future<void> replayPendingInvite() async {
    Map? raw;
    try {
      raw = GetStorage().read(_pendingInviteKey) as Map?;
    } catch (_) {
      raw = null;
    }
    if (raw == null) return;
    final fromId = (raw['from'] ?? '').toString();
    final role = (raw['role'] ?? 'owner').toString();
    try {
      GetStorage().remove(_pendingInviteKey);
    } catch (_) {/* noop */}
    if (fromId.isEmpty) return;
    // Laisse l'écran d'accueil se monter avant d'afficher le retour.
    await Future.delayed(const Duration(milliseconds: 1500));
    await _sendInvite(fromId, role);
  }

  static Future<void> _sendInvite(String fromId, String role) async {
    try {
      final controller = Get.isRegistered<FriendController>()
          ? Get.find<FriendController>()
          : Get.put(FriendController(), permanent: true);
      final err = await controller.sendRequest(fromId, role);
      if (err.isEmpty) {
        CustomSnackbar.showSuccess(
          title: 'friends_invite_sent_title'.tr,
          message: 'friends_invite_sent_message'.tr,
        );
      } else if (err == 'ALREADY_ACCEPTED') {
        CustomSnackbar.showInfo(
          title: 'friends_invite_sent_title'.tr,
          message: 'friends_invite_already_friends'.tr,
        );
      } else if (err == 'ALREADY_PENDING') {
        CustomSnackbar.showInfo(
          title: 'friends_invite_sent_title'.tr,
          message: 'friends_invite_already_pending'.tr,
        );
      } else if (err == 'SELF') {
        CustomSnackbar.showInfo(
          title: 'friends_invite_sent_title'.tr,
          message: 'friends_invite_self'.tr,
        );
      } else {
        CustomSnackbar.showError(title: 'common_error'.tr, message: err);
      }
    } catch (e) {
      AppLogger.logError('DeepLink invite : envoi échoué', error: e);
    }
  }

  /// v496 — Y a-t-il une session active ? (JWT présent). Sert à éviter
  /// d'ouvrir un écran authentifié (FriendsScreen, etc.) sur un appareil non
  /// connecté → écran noir. Best-effort : si l'ApiClient n'est pas encore
  /// enregistré (boot précoce), on considère « pas de session ».
  bool _hasSession() {
    try {
      if (!Get.isRegistered<ApiClient>()) return false;
      final t = Get.find<ApiClient>().authToken;
      return t != null && t.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _openChatList() {
    if (_currentRole() == 'owner') {
      Get.to(() => const ChatScreen());
    } else {
      Get.to(() => const SitterChatScreen()); // sitter + walker partagent
    }
  }

  void _openBookingsScreen() {
    switch (_currentRole()) {
      case 'walker':
        Get.to(() => const WalkerBookingsScreen());
        break;
      case 'sitter':
        Get.to(() => const SitterBookingsScreen());
        break;
      default:
        Get.to(() => const OwnerBookingsScreen());
    }
  }

  void _openNotificationsScreen() {
    if (_currentRole() == 'owner') {
      Get.to(() => const NotificationsScreen());
    } else {
      // v532 — écran complet pour tous les rôles (cf. sitter_homescreen).
      Get.to(() => const NotificationsScreen()); // sitter + walker
    }
  }

  void _openProfileScreen() {
    switch (_currentRole()) {
      case 'walker':
        Get.to(() => const WalkerProfileScreen());
        break;
      case 'sitter':
        Get.to(() => const SitterProfileScreen());
        break;
      default:
        Get.to(() => const ProfileScreen());
    }
  }

  /// v23.1 part 146 — Bridge de session web → app.
  ///
  /// Reçoit un OTT (one-time token) issu de POST /auth/one-time-token côté
  /// website. On l'échange via POST /auth/exchange contre un JWT 30j et on
  /// applique la session dans `AuthController.applyExchangedSession`, qui
  /// stocke le token + role + user et navigate vers le bon home.
  ///
  /// Robustesse :
  ///   - L'OTT a déjà été validé par regex côté `_handle`.
  ///   - On affiche un loader pendant le call réseau (peut prendre ~500ms
  ///     sur Render free-tier en cold start).
  ///   - En cas d'erreur (token expiré, déjà utilisé, réseau down), on
  ///     ferme le loader et on montre un toast d'erreur. L'utilisateur
  ///     atterrit sur l'écran courant (splash → onboarding ou home).
  Future<void> _handleAuthOtt(String ott) async {
    // Loader pendant l'exchange. Si Get.context est null malgré
    // `_navigatorReady = true` (cas pathologique), on skip silencieusement
    // le loader visuel mais on continue l'exchange.
    final hasContext = Get.context != null;
    if (hasContext) {
      showDialog(
        context: Get.context!,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.25),
        builder: (_) => const Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    try {
      if (!Get.isRegistered<ApiClient>()) {
        AppLogger.logError(
          'DeepLink _handleAuthOtt: ApiClient not registered',
        );
        return;
      }
      final apiClient = Get.find<ApiClient>();
      final response = await apiClient.post(
        '/auth/exchange',
        body: {'token': ott},
      );

      if (response is! Map<String, dynamic>) {
        AppLogger.logError(
          'DeepLink _handleAuthOtt: unexpected response type ${response.runtimeType}',
        );
        if (hasContext && Get.isDialogOpen == true) Get.back();
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_error_message'.tr,
        );
        return;
      }

      // Ferme le loader AVANT d'appeler applyExchangedSession (qui va
      // Get.offAll vers home — sinon le loader resterait par-dessus).
      if (hasContext && Get.isDialogOpen == true) Get.back();

      if (!Get.isRegistered<AuthController>()) {
        AppLogger.logError(
          'DeepLink _handleAuthOtt: AuthController not registered',
        );
        return;
      }
      final authController = Get.find<AuthController>();
      final ok = await authController.applyExchangedSession(response);

      if (!ok) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_error_message'.tr,
        );
      }
    } on ApiException catch (e) {
      if (hasContext && Get.isDialogOpen == true) Get.back();
      AppLogger.logError(
        'DeepLink _handleAuthOtt ApiException',
        error: e,
      );
      // 401 = token expiré / déjà utilisé. On affiche un message clair
      // sans révéler les internes (anti enumeration).
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.statusCode == 401
            ? 'deeplink_expired_msg'.tr
            : 'common_error_message'.tr,
      );
    } catch (e, st) {
      if (hasContext && Get.isDialogOpen == true) Get.back();
      AppLogger.logError(
        'DeepLink _handleAuthOtt failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _openPayment(String bookingId) async {
    try {
      // v18.9.8 — ouverture quasi-instantanée depuis une notif. Avant :
      // on attendait `getMyBookings()` (1-2s réseau) AVANT d'ouvrir l'écran,
      // donc écran noir pendant 2s après le tap sur la notif.
      //
      // Maintenant :
      //   1) Cache-first — on regarde si la booking est déjà en mémoire
      //      dans BookingsController ou l'ApiCache de OwnerRepository.
      //      Si oui → navigation immédiate (0ms réseau).
      //   2) Sinon → overlay loader Get.dialog pendant la fetch
      //      (spinner sur l'écran courant au lieu d'écran noir), puis
      //      push de l'écran Payment dès que la booking est dispo.
      BookingModel? booking;

      // (1) Cache-first : BookingsController garde déjà la liste en RAM.
      if (Get.isRegistered<BookingsController>()) {
        final ctrl = Get.find<BookingsController>();
        booking = ctrl.bookings.firstWhereOrNull((b) => b.id == bookingId);
      }

      // (2) Fallback réseau avec loader visible — empêche un écran vide.
      if (booking == null) {
        // Loader non-dismissible, barrier transparente pour rester sur
        // la vue actuelle.
        if (Get.context != null) {
          showDialog(
            context: Get.context!,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.25),
            builder: (_) => const Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          );
        }

        try {
          if (Get.isRegistered<OwnerRepository>()) {
            final repo = Get.find<OwnerRepository>();
            final all = await repo.getMyBookings();
            booking = all.firstWhereOrNull((b) => b.id == bookingId);
          }
          if (booking == null && Get.isRegistered<BookingsController>()) {
            final ctrl = Get.find<BookingsController>();
            await ctrl.loadBookings();
            booking = ctrl.bookings.firstWhereOrNull((b) => b.id == bookingId);
          }
        } finally {
          // Ferme le loader qu'on ait trouvé la booking ou pas.
          if (Get.isDialogOpen == true) Get.back();
        }
      }

      if (booking == null) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'common_error_message'.tr,
        );
        return;
      }
      final alreadyPaid =
          (booking.paymentStatus ?? '').toLowerCase() == 'paid';
      if (alreadyPaid) {
        // v561 — déjà payée : on montre la réservation au lieu de ne rien
        // faire (le mail « paiement » arrive parfois après le paiement).
        final b = booking;
        Get.to(() => OwnerBookingDetailScreen(booking: b));
        return;
      }
      final pricing = booking.pricing;
      final base = (pricing?.totalPrice ??
              pricing?.resolvedBaseAmount ??
              booking.totalAmount ??
              booking.basePrice) ??
          0.0;
      final serviceLower = (booking.serviceType ?? '').toLowerCase();
      final providerType = serviceLower.contains('walking') ||
              serviceLower.contains('dog_walking')
          ? 'walker'
          : 'sitter';
      Get.to(
        () => AirwallexPaymentScreen(
          booking: booking!,
          totalAmount: base,
          currency: pricing?.currency ?? booking.sitter.currency,
          providerType: providerType,
        ),
        // v18.9.8 — transition instantanée pour rester cohérent avec le
        // reste des flows critiques (payment, chat).
        transition: Transition.rightToLeft,
        duration: const Duration(milliseconds: 180),
      );
    } on ApiException catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      AppLogger.logError('DeepLink _openPayment ApiException', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_message'.tr,
      );
    } catch (e) {
      if (Get.isDialogOpen == true) Get.back();
      AppLogger.logError('DeepLink _openPayment failed', error: e);
    }
  }
}
