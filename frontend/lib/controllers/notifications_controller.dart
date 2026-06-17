import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/repositories/notifications_repository.dart';
// v23.1.323 — Daniel : "7 messages badge à chaque ouverture". On cale le badge
// chat sur le VRAI total non-lu serveur (somme des unreadCount des conversations)
// au lieu d'un compteur local qui dérive / se ré-inflate à la reconnexion.
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class NotificationsController extends GetxController with WidgetsBindingObserver {
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
    // v23.1 — refresh notifs when app comes back to foreground so the
    // bell badge reflects the latest state (e.g. owner reopens the app
    // after a walker accepted while the app was backgrounded).
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // v23.1.254 — confort total : refresh silencieux du token AVANT de
      // reconnecter le socket. Si le token a expiré pendant le background,
      // refreshToken() en récupère un frais ET reconnecte le socket avec ce
      // token (sinon la reconnexion auto réutilise l'ancien token périmé →
      // handshake AUTH_FAILED → messages/demandes plus jamais temps réel).
      // Best-effort, fire-and-forget.
      try {
        if (Get.isRegistered<AuthController>()) {
          Get.find<AuthController>().refreshToken();
        }
      } catch (_) {/* defensive */}
      // App returned to foreground — pull latest notifs so the bell badge
      // is up to date (covers both push-arrived-while-bg and missed pushes).
      refreshAll();
      // v444 — recale le badge CHAT sur la vérité serveur au retour (messages
      // reçus pendant la pause → badge = vrai total, jamais un compteur dérivé).
      syncChatBadgeFromServer();
      // v23.1 part 228 — Daniel : "fais que en background l'app reste
      // connecter". L'OS suspend les sockets en background ; au resume
      // on force la reconnexion + on re-fetch les conversations pour
      // recuperer les messages recus pendant la pause. Le badge unreadChat
      // sera re-sync via /conversations/list + notifs FCM push.
      try {
        if (Get.isRegistered<SocketService>()) {
          Get.find<SocketService>().reconnectIfNeeded();
        }
      } catch (_) {/* defensive */}
    }
  }

  @override
  void onClose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _chatResyncTimer?.cancel();
    super.onClose();
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

  // v444 — Daniel : « badge messages 1 puis 5 qui revient ». DEUX causes :
  //  (1) le backend émet message:new aux 3 rooms de rôle ; un compte
  //      multi-rôles (owner+sitter+walker) recevait le MÊME message plusieurs
  //      fois + rejeu à la reconnexion → unreadChat sur-comptait.
  //  (2) le badge optimiste local ne se réconciliait pas toujours avec la
  //      vérité serveur.
  // Fix : dédup par id de message (chaque message ne compte qu'1×) + resync
  // DÉBOUNCÉ sur la somme serveur des unreadCount après chaque bump/lecture
  // → le badge converge TOUJOURS vers le vrai total, sans flicker.
  final Set<String> _seenChatMsgIds = <String>{};
  Timer? _chatResyncTimer;

  /// Extrait l'id unique d'un message d'un payload `message:new`
  /// ({message:{_id|id}} | {sentMessage:{...}} | {messageId}). '' si absent.
  String _chatMsgId(Map<String, dynamic> map) {
    dynamic inner = map['message'] ?? map['sentMessage'];
    if (inner is Map) {
      final id = inner['_id'] ?? inner['id'];
      if (id != null && id.toString().isNotEmpty) return id.toString();
    }
    final mid = map['messageId'] ?? map['_id'] ?? map['id'];
    return mid?.toString() ?? '';
  }

  /// true si ce message a déjà été compté (dédup multi-rooms / rejeu / FCM+socket).
  bool _chatMsgSeenOrDupe(String msgId) {
    if (msgId.isEmpty) return false;
    if (_seenChatMsgIds.contains(msgId)) return true;
    _seenChatMsgIds.add(msgId);
    if (_seenChatMsgIds.length > 300) {
      final drop = _seenChatMsgIds.take(150).toList();
      for (final k in drop) {
        _seenChatMsgIds.remove(k);
      }
    }
    return false;
  }

  /// Resync DÉBOUNCÉ du badge chat sur la vérité serveur. Appelé après chaque
  /// bump optimiste / lecture de conversation : les appels rapprochés se
  /// regroupent en un seul fetch → badge final = somme serveur exacte.
  void scheduleChatBadgeResync({int ms = 1500}) {
    _chatResyncTimer?.cancel();
    _chatResyncTimer = Timer(Duration(milliseconds: ms), () {
      syncChatBadgeFromServer();
    });
  }

  bool _markSeenOrDupe(Map<String, dynamic> data) {
    final id = (data['id'] ?? data['_id'] ?? data['notificationId'] ?? '')
        .toString();
    if (id.isEmpty) return false;
    if (_seenNotifIds.contains(id)) return true;
    _seenNotifIds.add(id);
    // Cap the cache to avoid unbounded memory.
    if (_seenNotifIds.length > 200) {
      final drop = _seenNotifIds.take(100).toList();
      for (final k in drop) {
        _seenNotifIds.remove(k);
      }
    }
    return false;
  }

  // v401 — handler badge chat, enregistré via le multiplexeur message:new
  // (réf. stable = tear-off de méthode d'instance, égale entre appels en Dart
  // → addMessageNewListener idempotent, removeMessageNewListener ciblé).
  // v23.1 part 130 — ne bumpe PAS quand c'est NOUS qui envoyons (triggeredBy
  // ou message.senderId == moi). v23.1.390 — couvre aussi les demandes de
  // suivi / partages (pas de triggeredBy → on déduit du senderId).
  void _onSocketMessageNew(Map<String, dynamic> map) {
    try {
      final triggered = map['triggeredBy'];
      final triggeredId = triggered is Map ? triggered['userId']?.toString() : null;
      final profile = _storage.read<Map<String, dynamic>>('user_profile');
      final myId = profile?['id']?.toString();
      if (triggeredId != null && myId != null && triggeredId == myId) {
        return;
      }
      final inner = map['message'];
      if (inner is Map && myId != null) {
        final rawSender = inner['senderId'];
        final senderId = rawSender is Map
            ? (rawSender['_id'] ?? rawSender['id'])?.toString()
            : rawSender?.toString();
        if (senderId != null && senderId == myId) {
          return;
        }
      }
    } catch (_) {/* best-effort */}
    // v444 — dédup : un même message livré via plusieurs rooms de rôle (compte
    // multi-rôles) ou rejoué à la reconnexion ne doit compter qu'UNE fois.
    if (_chatMsgSeenOrDupe(_chatMsgId(map))) return;
    unreadChat.value = unreadChat.value + 1;
    _storage.write(_kUnreadChat, unreadChat.value);
    // Réconcilie sur la vérité serveur peu après (corrige tout écart).
    scheduleChatBadgeResync();
  }

  void _attachSocketListener() {
    try {
      final s = Get.find<SocketService>();
      // v23.1 part 43 — fix Daniel "message arrive mais pas de badge" :
      // Le backend emit 'message:new' (chat) ET 'notification.new' (notif
      // catalog). Avant on n'écoutait que notification.new, donc quand le
      // sync fallback /confirm-payment créait un message système sans
      // déclencher sendNotification (template manquant à l'époque), le badge
      // chat ne bumpait jamais. Maintenant on écoute aussi message:new pour
      // bump unreadChat directement, indépendamment du flux notification.
      // v401 — Daniel : "qd je recoi un message le badge 1 du menu ne vient
      // pas". On s'abonne au MULTIPLEXEUR message:new du SocketService avec une
      // RÉFÉRENCE STABLE (_onSocketMessageNew, tear-off de méthode). Avant, ce
      // listener faisait socket.off/on et était écrasé par les ChatController
      // (qui font pareil), puis carrément supprimé quand on quittait un chat.
      // Le mux garantit que le badge survit à l'ouverture/fermeture des chats.
      s.addMessageNewListener(_onSocketMessageNew);
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

          // v23.1.182 — Daniel : "il faut jme deco et reco pour voir la
          // nouvelle notif au lieu que se soit instentanee". Le backend
          // envoie maintenant la notif complète (id, createdAt,
          // recipientRole) dans le payload socket. On insère direct la
          // notif EN TÊTE de la liste pour que l'écran Notifications se
          // mette à jour en temps réel sans refetch.
          try {
            final hasId = (map['id'] ?? map['_id'] ?? map['notificationId']) != null;
            if (hasId) {
              final notifJson = <String, dynamic>{
                'id': (map['id'] ?? map['_id'] ?? map['notificationId']).toString(),
                'recipientRole': (map['recipientRole'] ?? '').toString(),
                'recipientId': (map['recipientId'] ?? '').toString(),
                'actorRole': (map['actorRole'] ?? '').toString(),
                'actorId': (map['actorId'] ?? '').toString(),
                'type': type,
                'title': (map['title'] ?? '').toString(),
                'body': (map['body'] ?? '').toString(),
                'data': map['data'] is Map
                    ? Map<String, dynamic>.from(map['data'] as Map)
                    : <String, dynamic>{},
                'readAt': null,
                'createdAt': map['createdAt'] ?? DateTime.now().toUtc().toIso8601String(),
              };
              final newNotif = AppNotificationModel.fromJson(notifJson);
              // Dedupe : si la notif est déjà dans la liste (cas où
              // loadInitial a tourné en parallèle), on ne l'ajoute pas.
              final exists = notifications.any((n) => n.id == newNotif.id);
              if (!exists && newNotif.id.isNotEmpty) {
                notifications.insert(0, newNotif);
              }
            }
          } catch (_) {/* defensive */}

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
            // v23.1.317 — Daniel : "notifs en double / badges qui reviennent".
            // Le badge chat est DÉJÀ incrémenté par l'event socket `message:new`
            // (handler dédié plus haut). On re-bumpait ICI aussi sur le
            // notification.new type new_message → +2 par message reçu. On ne
            // bump plus ici : `message:new` est l'unique source de vérité du
            // badge chat (le feed, lui, reste alimenté par notification.new).
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
          } else if (lower.startsWith('service_')) {
            // v23.1.270 — Daniel : badge réservation "animal récupéré / rendu /
            // confirmation". Les events de confirmation de service
            // (service_started, service_completion_request, service_confirmed,
            // service_disputed) n'avaient pas de listener → le badge "action
            // requise" de l'onglet Réservations n'était mis à jour qu'au refresh
            // 30s. On recharge les réservations immédiatement → badge instantané.
            unreadBookings.value = unreadBookings.value + 1;
            _storage.write(_kUnreadBookings, unreadBookings.value);
            _reloadBookingControllers();
          }

          // v23.1.296 — Daniel : "les notifs amis et famille, rajoute-les au
          // bandeau sans que ça infecte le système de notif des paiements". On
          // affiche un toast in-app UNIQUEMENT pour les types ami/famille
          // (les paiements n'ont volontairement pas de bandeau). Le titre et le
          // corps sont DÉJÀ localisés côté backend (notificationSender) → on les
          // utilise tels quels, sans .tr.
          // v23.1.329 — Daniel : "les demandes d'amis, je ne veux PAS de pop-up
          // bleu, juste dans le bandeau notif (cloche) + voir le profil du
          // demandeur". On SUPPRIME le toast pour les demandes REÇUES
          // (friend_request_received / family_invitation_received /
          // live_tracking_request_received) : elles restent dans le feed avec
          // Accepter/Refuser + nom + photo. On garde le toast pour les AUTRES
          // events ami/famille (ex. demande ACCEPTÉE = retour positif utile).
          final isIncomingRequest = lower == 'friend_request_received' ||
              lower == 'family_invitation_received' ||
              lower == 'live_tracking_request_received';
          if ((lower.startsWith('friend') || lower.startsWith('family')) &&
              !isIncomingRequest) {
            final bannerTitle = (map['title'] ?? '').toString();
            final bannerBody = (map['body'] ?? '').toString();
            if (bannerTitle.isNotEmpty) {
              CustomSnackbar.showInfo(
                title: bannerTitle,
                message: bannerBody,
              );
            }
          }
        } catch (_) {}
      });
    } catch (_) {
      // SocketService not registered yet — listener will be re-attached on next onInit.
    }
  }

  /// v23.1.270 — recharge les contrôleurs de réservation (silencieux) à
  /// l'arrivée d'un event service_* pour rafraîchir le badge "action requise"
  /// de l'onglet Réservations en temps réel, quel que soit le rôle actif.
  void _reloadBookingControllers() {
    try {
      if (Get.isRegistered<BookingsController>()) {
        Get.find<BookingsController>().loadBookings(silent: true);
      }
    } catch (_) {/* defensive */}
    try {
      if (Get.isRegistered<SitterBookingsController>()) {
        Get.find<SitterBookingsController>().loadBookings(silent: true);
      }
    } catch (_) {/* defensive */}
    try {
      if (Get.isRegistered<WalkerBookingsController>()) {
        Get.find<WalkerBookingsController>().loadBookings(silent: true);
      }
    } catch (_) {/* defensive */}
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

  // v23.1 part 44 — chat + bookings counterparts so the foreground FCM
  // handler can update those badges immediately too. Without these the
  // bottom-nav Chat / Réservations badges only updated when the parallel
  // socket event arrived, which lagged behind the phone push by 1-2s in
  // the field (and never arrived at all when the socket was offline).
  void bumpUnreadChatImmediate({String? messageId}) {
    // v444 — dédup PARTAGÉE avec le socket message:new : si ce message a déjà
    // été compté (FCM push + socket arrivent en parallèle), on ne re-bumpe pas ;
    // on réconcilie quand même sur la vérité serveur.
    if (messageId != null && _chatMsgSeenOrDupe(messageId)) {
      scheduleChatBadgeResync();
      return;
    }
    unreadChat.value = unreadChat.value + 1;
    _storage.write(_kUnreadChat, unreadChat.value);
    scheduleChatBadgeResync();
  }

  void bumpUnreadBookingsImmediate() {
    unreadBookings.value = unreadBookings.value + 1;
    _storage.write(_kUnreadBookings, unreadBookings.value);
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
      // v23.1.323 — recale le badge chat sur le vrai total serveur (fire-and-forget).
      syncChatBadgeFromServer();
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

  /// v23.1.323 — Daniel : "à chaque ouverture de l'app, 7 messages en badge".
  /// Le badge chat était un compteur LOCAL (storage + bumps socket) jamais
  /// réconcilié → il se ré-inflate à la reconnexion (replay) et reste collé.
  /// Ici on le recale sur la VÉRITÉ serveur : somme des unreadCount des
  /// conversations (POST /:id/read remet bien à 0 quand on lit). Fire-and-forget.
  Future<void> syncChatBadgeFromServer() async {
    try {
      final chatRepo = ChatRepository(Get.find<ApiClient>());
      final convs = await chatRepo.getChatList();
      // v448 — AUDIT MESSAGERIE : DÉDUP par interlocuteur AVANT de sommer. Le
      // backend peut renvoyer 2 conversations pour la même personne (un fil
      // réservation + un fil amis) ; la liste de chat n'en AFFICHE qu'une (la
      // plus récente, via _dedupByOtherParty). Sans dédup ici, le badge
      // additionnait aussi l'unread du fil CACHÉ → « badge N alors que 0 visible »
      // impossible à faire descendre. On ne compte donc que le fil visible par
      // personne (même clé que la liste).
      int ts(Map m) {
        final v = m['lastMessageAt'] ?? m['lastMessageTime'] ?? m['updatedAt'];
        if (v is int) return v;
        return DateTime.tryParse(v?.toString() ?? '')?.millisecondsSinceEpoch ?? 0;
      }

      final byKey = <String, Map<String, dynamic>>{};
      for (final it in convs) {
        final op = it['otherParty'];
        final otherId =
            (op is Map ? (op['id'] ?? op['_id']) : null)?.toString() ?? '';
        final key = otherId.isNotEmpty
            ? 'u:$otherId'
            : 'c:${(it['_id'] ?? it['id'] ?? '').toString()}';
        final existing = byKey[key];
        if (existing == null || ts(it) >= ts(existing)) byKey[key] = it;
      }
      int total = 0;
      for (final c in byKey.values) {
        final u = c['unreadCount'];
        if (u is num) total += u.toInt();
      }
      if (total < 0) total = 0;
      unreadChat.value = total;
      _storage.write(_kUnreadChat, total);
    } catch (_) {
      // best-effort : en cas d'échec réseau, on garde le badge courant.
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
