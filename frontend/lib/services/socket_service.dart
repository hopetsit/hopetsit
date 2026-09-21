import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';

/// Service for managing Socket.IO connections for real-time messaging.
///
/// v20.0.19 — CRITICAL FIX: event names realigned with backend protocol
/// (chatSocket.js). Before this fix, the app emitted `join_conversation`,
/// `leave_conversation` and listened to `new_message` / `message_sent`
/// (underscore convention), but the backend uses colon-based names
/// (`conversation:join`, `conversation:leave`, `message:new`,
/// `message:deleted`, `conversation:read`). As a result:
///   - joining a conversation room silently failed
///   - no real-time messages ever arrived (no badge bump, no chat list
///     refresh, no unread count update)
///   - delete-message UI never updated on the other party's side
///   - read receipts never propagated
///
/// Additionally the `conversation:join` payload must be a MAP
/// `{ conversationId, role, userId }`, not the raw id string.
class SocketService {
  SocketService({GetStorage? storage}) : _storage = storage ?? GetStorage();

  final GetStorage _storage;
  io.Socket? _socket;
  bool _isConnected = false;

  // v20.0.19 — hooks exécutés à chaque onConnect du socket. Permet au
  // NotificationsController (et à tout autre consommateur) de (ré)attacher
  // ses listeners après une connexion tardive (ex: user qui se logue
  // APRÈS le boot, donc après l'onInit du NotificationsController).
  final List<void Function()> _onConnectedHooks = [];

  /// Registers a callback that runs every time the socket successfully
  /// connects (including reconnects). The callback may be called multiple
  /// times — make your logic idempotent (off → on).
  void addOnConnectedHook(void Function() cb) {
    _onConnectedHooks.add(cb);
    if (_isConnected) {
      try { cb(); } catch (e) {
        AppLogger.logError('onConnected hook threw', error: e);
      }
    }
  }

  /// Gets the current socket instance.
  io.Socket? get socket => _socket;

  /// Checks if socket is connected.
  bool get isConnected => _isConnected;

  /// Connects to the Socket.IO server.
  ///
  /// v575 — [tokenOverride] permet d'imposer le jeton du handshake sans
  /// dépendre de la course d'écriture du stockage sécurisé (utilisé par
  /// `reconnectWithToken` après un changement de rôle).
  Future<void> connect({String? tokenOverride}) async {
    if (_socket != null && _isConnected) {
      AppLogger.logInfo('Socket already connected');
      return;
    }

    try {
      final token = (tokenOverride != null && tokenOverride.isNotEmpty)
          ? tokenOverride
          : SecureTokenStore.currentToken();
      if (token == null || token.isEmpty) {
        // Import AuthController to handle login required error
        // Note: We can't import controllers in services, so we'll handle this at the call site
        throw Exception('Auth token not found. Please login again.');
      }

      // Get socket URL from API config
      // Sprint 8 step 9 — Socket.IO mounts at the backend root, not under /api/v1.
      final socketUrl = ApiConfig.rootUrl;

      AppLogger.logInfo('Connecting to socket: $socketUrl');

      // v23.1 part 130 — Phase 6 audit P6-1 : envoyer le JWT via
      // l'option `auth` qui est la voie officielle socket.io v3+ et que
      // le middleware io.use lit en priorité. setExtraHeaders reste en
      // fallback pour les vieux clients (et les WebView).
      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            // v23.1 part 228 — Daniel : "fais que en background l'app
            // reste connecter". Avant : 5 essais (~25s max) puis socket
            // mort definitif. Si l'app est en background plus longtemps,
            // au resume on doit force-reconnect. Maintenant on tente 999
            // fois (effectivement infini), donc des qu'OS re-permet le
            // network le socket se rebranche tout seul.
            .setReconnectionAttempts(999)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        AppLogger.logInfo('Socket connected');
        // Sprint 4 step 4 — identify ourselves for per-user notifications.
        final profile = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
        final role = _storage.read<String>(StorageKeys.userRole);
        final userId = profile?['id']?.toString();
        if (role != null && role.isNotEmpty && userId != null && userId.isNotEmpty) {
          _socket!.emit('user:identify', {'role': role, 'userId': userId});
        }
        // v20.0.19 — fire all post-connect hooks (NotificationsController,
        // chat controllers, etc.). Wrapped in try/catch so one buggy hook
        // can't break the others.
        for (final cb in _onConnectedHooks) {
          try { cb(); } catch (e) {
            AppLogger.logError('onConnected hook threw', error: e);
          }
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        AppLogger.logInfo('Socket disconnected');
      });

      _socket!.onError((error) {
        AppLogger.logError('Socket error', error: error);
      });

      _socket!.onConnectError((error) {
        AppLogger.logError('Socket connection error', error: error);
      });
    } catch (e) {
      AppLogger.logError('Failed to connect socket', error: e);
      rethrow;
    }
  }

  /// Disconnects from the Socket.IO server.
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      AppLogger.logInfo('Socket disconnected and disposed');
    }
  }

  /// v23.1.397 — Daniel : « Session expirée » à la reconnexion. Au logout,
  /// le socket restait connecté avec l'ANCIEN token → requêtes résiduelles
  /// → 401 → snackbar parasite. On COUPE le socket.
  ///
  /// v23.1.399 — Daniel : « vérifie que Me suivre marche ». On NE purge PLUS
  /// les _onConnectedHooks : ils sont enregistrés par des services PERMANENTS
  /// (LiveMapService → map:identify) qui SURVIVENT au logout et ne sont
  /// jamais recréés → les vider les perdait à jamais, cassant le suivi en
  /// direct après un cycle déconnexion→reconnexion. Les hooks sont
  /// idempotents et relisent le token courant à la (re)connexion : aucun
  /// risque de rejouer l'état de l'ancien compte.
  void resetForLogout() {
    try {
      disconnect();
    } catch (e) {
      AppLogger.logError('resetForLogout failed', error: e);
    }
  }

  /// v575 — P1-2 : reconnexion FORCÉE avec un nouveau jeton.
  ///
  /// Le serveur lit le rôle et l'id dans le JWT **au handshake**
  /// (`chatSocket.js` : `socket.join(userRoom(trusted.role, trusted.id))`).
  /// Après un changement de rôle, mettre simplement `socket.auth` à jour ne
  /// suffit donc pas : tant que la connexion courante vit, le socket reste
  /// dans la room `user:<ancien rôle>:<ancien id>` et ne reçoit plus ni
  /// message ni notification en direct. `updateAuthToken` ne coupe
  /// volontairement PAS un socket vivant — d'où cette méthode dédiée.
  ///
  /// Idempotente et sans fuite d'écouteurs : on détruit l'instance socket
  /// (`disconnect()` fait `dispose()` + met `_socket` à null, ce qui retire
  /// tous ses listeners) puis `connect()` en recrée une. Les abonnés des
  /// multiplexeurs (`message:new`, accusés, présence, `conversation:deleted`)
  /// vivent dans des listes Dart qui survivent à l'opération ; leurs listeners
  /// socket sont re-bindés ici, et les `_onConnectedHooks` (notifications,
  /// carte en direct…) sont rejoués par `onConnect`.
  Future<void> reconnectWithToken(String token) async {
    try {
      if (token.isEmpty) {
        AppLogger.logError('reconnectWithToken: jeton vide, ignoré');
        return;
      }
      disconnect();
      await connect(tokenOverride: token);
      // Les muxes se rebindent sur la NOUVELLE instance socket ; sans cela
      // les abonnés resteraient enregistrés côté Dart mais plus aucun
      // événement n'arriverait du serveur.
      _rebindMuxes();
      AppLogger.logInfo('Socket reconnecté avec le nouveau jeton');
    } catch (e) {
      AppLogger.logError('reconnectWithToken failed', error: e);
    }
  }

  /// Re-attache les listeners socket des multiplexeurs sur l'instance
  /// courante. Sans effet quand personne n'est abonné.
  void _rebindMuxes() {
    if (_socket == null) return;
    if (_messageNewSubs.isNotEmpty) _bindMessageNewMux();
    if (_receiptSubs.isNotEmpty) _bindReceiptMux();
    if (_presenceSubs.isNotEmpty) _bindPresenceMux();
    if (_convDeletedSubs.isNotEmpty) _bindConversationDeletedMux();
  }

  /// v23.1 part 228 — Daniel : "fais que en background l'app reste
  /// connecter". Appele au resume du lifecycle Flutter. Si le socket
  /// est dispose ou disconnected, on re-connecte. Sinon best-effort
  /// le force-reconnect via socket.connect() (idempotent si deja up).
  Future<void> reconnectIfNeeded() async {
    try {
      if (_socket == null) {
        await connect();
        return;
      }
      if (!_isConnected) {
        // Tentative explicite de reconnect.
        _socket!.connect();
      }
    } catch (e) {
      AppLogger.logError('reconnectIfNeeded failed', error: e);
    }
  }

  /// v23.1.254 — Met à jour le token JWT utilisé par le socket et garantit
  /// que le temps réel reste vivant après un refresh silencieux du token.
  ///
  /// Bug racine corrigé : `setAuth({'token': token})` capture le token UNE
  /// SEULE FOIS au connect initial. Les reconnexions automatiques de
  /// socket.io réutilisent CE token. Si le token a été rafraîchi (ou s'il
  /// était périmé au démarrage), les reconnexions échouaient en boucle
  /// (handshake AUTH_FAILED côté backend) → messages chat / demandes d'amis
  /// / notifs JAMAIS livrés en temps réel tant qu'on ne se reco/deco pas.
  ///
  /// Ici on : (1) met à jour `socket.auth` ET les extraHeaders pour que les
  /// futures reconnexions utilisent le token frais ; (2) si le socket est
  /// mort (le token périmé l'avait tué), on force un disconnect→connect
  /// MAINTENANT pour relancer le handshake. S'il est déjà vivant, on ne le
  /// coupe pas (évite une coupure inutile du temps réel).
  Future<void> updateAuthToken(String token) async {
    try {
      if (_socket == null) {
        // Pas encore de socket : connexion normale avec le jeton frais.
        await connect(tokenOverride: token);
        return;
      }
      // Met à jour la source de vérité pour les (re)connexions futures.
      _socket!.auth = {'token': token};
      try {
        _socket!.io.options?['extraHeaders'] = {
          'Authorization': 'Bearer $token',
        };
      } catch (_) {/* options peut être immuable selon l'état — best-effort */}

      if (!_isConnected) {
        // Socket mort → relance immédiate avec le token frais.
        _socket!.disconnect();
        _socket!.connect();
        AppLogger.logInfo('Socket auth updated + reconnecting (was dead)');
      } else {
        AppLogger.logInfo('Socket auth token updated (live, no cut)');
      }
    } catch (e) {
      AppLogger.logError('updateAuthToken failed', error: e);
    }
  }

  /// Joins a conversation room.
  ///
  /// v20.0.19 — backend handler at chatSocket.js line 40 expects
  /// event `conversation:join` with payload `{ conversationId, role, userId }`.
  /// The previous implementation emitted `join_conversation` with the raw
  /// id string, which the backend silently ignored — so the socket never
  /// joined the conversation room and no `message:new` events were ever
  /// delivered to this socket.
  void joinConversation(String conversationId) {
    if (_socket != null && _isConnected) {
      final profile = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
      final role = _storage.read<String>(StorageKeys.userRole);
      final userId = profile?['id']?.toString();
      _socket!.emit('conversation:join', {
        'conversationId': conversationId,
        if (role != null) 'role': role,
        if (userId != null) 'userId': userId,
      });
      AppLogger.logInfo('Joined conversation: $conversationId');
    }
  }

  /// Leaves a conversation room.
  ///
  /// v20.0.19 — backend handler at chatSocket.js line 89 expects
  /// event `conversation:leave` with payload `{ conversationId }`.
  void leaveConversation(String conversationId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('conversation:leave', {'conversationId': conversationId});
      AppLogger.logInfo('Left conversation: $conversationId');
    }
  }

  /// Marks a conversation as read so the other party's unread count drops
  /// to 0 in real time (no app refresh required).
  ///
  /// v20.0.19 — backend handler at chatSocket.js line 139 expects
  /// event `conversation:read` with payload `{ conversationId, role, userId }`.
  void markConversationRead(String conversationId) {
    if (_socket != null && _isConnected) {
      final profile = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
      final role = _storage.read<String>(StorageKeys.userRole);
      final userId = profile?['id']?.toString();
      _socket!.emit('conversation:read', {
        'conversationId': conversationId,
        if (role != null) 'role': role,
        if (userId != null) 'userId': userId,
      });
    }
  }

  /// Listens for new messages in a conversation.
  ///
  /// v20.0.19 — backend emits `message:new` (colon) from 3 places:
  ///   - chatSocket.js line 122 (socket-driven `message:send`)
  ///   - conversationController.js (REST POST /messages and booking events)
  ///   - stripeWebhookController.js (post-payment system message)
  // v23.1 part 205 — Daniel : "lorsque je suis longtemps sur l'app ouverte
  // elle auto crash". Root cause : `_socket!.on(event, cb)` APPENDS un
  // nouveau listener à chaque appel sans retirer l'ancien. Quand la socket
  // se reconnecte (network hiccup, app foreground), les hooks fire de
  // nouveau les .on(...) → après 8h ça fait des centaines de doublons qui
  // tirent tous sur chaque message → callback explosion → OOM.
  // Fix : appeler `off(event)` AVANT chaque `.on(event, ...)`.
  // ── message:new multiplexeur ────────────────────────────────────────────
  // v401 — Daniel : "qd je recoi un message le badge 1 du menu ne vient pas".
  // ROOT CAUSE : plusieurs consommateurs de `message:new` (NotificationsController
  // = badge chat, ChatController + SitterChatController = affichage du message)
  // faisaient CHACUN `socket.off('message:new')` + `.on(...)`. Le dernier à
  // s'enregistrer écrasait donc les autres ; pire, quand un ChatController
  // quittait l'écran il faisait `off('message:new')` → plus AUCUN listener →
  // le badge ne se bumpait plus jusqu'à la prochaine reconnexion socket.
  //
  // FIX : un SEUL listener socket interne (le mux) qui redistribue l'event à
  // N abonnés. S'abonner/se désabonner n'affecte plus les autres. Les abonnés
  // passent une RÉFÉRENCE STABLE (tear-off de méthode d'instance ou closure
  // stockée en champ) pour pouvoir se retirer proprement.
  final List<void Function(Map<String, dynamic>)> _messageNewSubs = [];

  void _bindMessageNewMux() {
    final s = _socket;
    if (s == null) return;
    // Idempotent : off→on rebinde l'unique handler mux sur le socket COURANT
    // (nécessaire après une reconnexion qui a remplacé l'instance socket).
    s.off('message:new');
    s.on('message:new', (data) {
      Map<String, dynamic> map;
      try {
        map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      } catch (_) {
        return;
      }
      for (final cb in List.of(_messageNewSubs)) {
        try {
          cb(map);
        } catch (e) {
          AppLogger.logError('message:new subscriber threw', error: e);
        }
      }
      _ackDelivered(map);
    });
  }

  // ── v566 — accusés de réception / lecture (✓ ✓✓ ✓✓ bleu) ────────────────
  /// Conversation réellement AFFICHÉE (posée par l'écran de discussion via
  /// ChatSessionMixin.setChatVisible). Un message reçu pour cette
  /// conversation est marqué LU par le contrôleur (`POST /read`) ; pour toute
  /// autre, on accuse seulement réception ici.
  static String visibleConversationId = '';

  /// Ids déjà accusés (le même `message:new` arrive par la room de
  /// conversation ET par la room utilisateur) — borné.
  final List<String> _ackedIds = [];

  /// Émet `message:delivered { conversationId, messageId }` pour un message
  /// REÇU (jamais pour les miens, jamais pour un message système). Le serveur
  /// pose `deliveredAt` et prévient l'expéditeur ; il ne renvoie RIEN au
  /// destinataire → aucune boucle possible.
  void _ackDelivered(Map<String, dynamic> map) {
    try {
      final s = _socket;
      if (s == null || !_isConnected) return;
      final raw = map['message'] is Map
          ? map['message'] as Map
          : (map['sentMessage'] is Map ? map['sentMessage'] as Map : map);
      final messageId = (raw['id'] ?? raw['_id'] ?? '').toString();
      final conversationId =
          (map['conversationId'] ?? raw['conversationId'] ?? '').toString();
      final senderId = (raw['senderId'] ?? map['senderId'] ?? '').toString();
      final senderRole = (raw['senderRole'] ?? '').toString().toLowerCase();
      if (messageId.isEmpty || conversationId.isEmpty || senderId.isEmpty) return;
      if (senderRole == 'system') return;
      if (raw['deliveredAt'] != null || raw['readAt'] != null) return;
      final profile = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
      final me = profile?['id']?.toString() ?? '';
      if (me.isEmpty || senderId == me) return;
      // Conversation à l'écran → le contrôleur appelle /read (lu ⊃ remis).
      if (conversationId == visibleConversationId) return;
      if (_ackedIds.contains(messageId)) return;
      _ackedIds.add(messageId);
      if (_ackedIds.length > 80) _ackedIds.removeAt(0);
      s.emit('message:delivered', {
        'conversationId': conversationId,
        'messageId': messageId,
      });
    } catch (e) {
      AppLogger.logError('message:delivered ack failed', error: e);
    }
  }

  /// Multiplexeur `message:read` + `message:delivered` : UN listener socket
  /// par événement, N abonnés (référence STABLE), comme message:new.
  final List<void Function(String event, Map<String, dynamic> data)>
      _receiptSubs = [];

  void _bindReceiptMux() {
    final s = _socket;
    if (s == null) return;
    for (final event in const ['message:read', 'message:delivered']) {
      s.off(event);
      s.on(event, (data) {
        Map<String, dynamic> map;
        try {
          map = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
        } catch (_) {
          return;
        }
        for (final cb in List.of(_receiptSubs)) {
          try {
            cb(event, map);
          } catch (e) {
            AppLogger.logError('$event subscriber threw', error: e);
          }
        }
      });
    }
  }

  /// Abonne un listener d'accusés (idempotent ; à rappeler depuis un
  /// onConnected hook pour survivre aux reconnexions).
  void addReceiptListener(
      void Function(String event, Map<String, dynamic> data) cb) {
    if (!_receiptSubs.contains(cb)) _receiptSubs.add(cb);
    _bindReceiptMux();
  }

  void removeReceiptListener(
      void Function(String event, Map<String, dynamic> data) cb) {
    _receiptSubs.remove(cb);
  }

  /// Abonne un listener `message:new` SANS écraser les autres. Passer une
  /// référence STABLE (tear-off de méthode ou closure conservée dans un champ)
  /// pour pouvoir la retirer ensuite. Idempotent : ré-ajouter la même réf est
  /// un no-op pour la liste mais re-bind le listener socket sous-jacent (utile
  /// après une reconnexion). À appeler depuis un onConnected hook.
  void addMessageNewListener(void Function(Map<String, dynamic>) cb) {
    if (!_messageNewSubs.contains(cb)) _messageNewSubs.add(cb);
    _bindMessageNewMux();
  }

  /// Désabonne UN listener `message:new` (les autres restent actifs).
  void removeMessageNewListener(void Function(Map<String, dynamic>) cb) {
    _messageNewSubs.remove(cb);
  }

  // ── presence:update multiplexeur (v565, contrat §6) ─────────────────────
  // Le serveur émet `presence:update { userId, online, at }` aux amis et aux
  // correspondants de conversation à chaque connexion/déconnexion socket.
  // Même principe que message:new : UN listener socket, N abonnés (liste de
  // conversations owner/sitter, écran de discussion, onglet amis…).
  final List<void Function(Map<String, dynamic>)> _presenceSubs = [];

  void _bindPresenceMux() {
    final s = _socket;
    if (s == null) return;
    s.off('presence:update');
    s.on('presence:update', (data) {
      Map<String, dynamic> map;
      try {
        map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      } catch (_) {
        return;
      }
      for (final cb in List.of(_presenceSubs)) {
        try {
          cb(map);
        } catch (e) {
          AppLogger.logError('presence:update subscriber threw', error: e);
        }
      }
    });
  }

  /// Abonne un listener `presence:update` (référence STABLE, idempotent).
  /// À appeler depuis un onConnected hook pour survivre aux reconnexions.
  void addPresenceListener(void Function(Map<String, dynamic>) cb) {
    if (!_presenceSubs.contains(cb)) _presenceSubs.add(cb);
    _bindPresenceMux();
  }

  /// Désabonne UN listener `presence:update`.
  void removePresenceListener(void Function(Map<String, dynamic>) cb) {
    _presenceSubs.remove(cb);
  }

  // ── conversation:deleted multiplexeur (v569) ────────────────────────────
  // Daniel : « que tout soit bien synchronisé Android / iOS / web ». Le
  // serveur émet `conversation:deleted { conversationId, at }` vers les 3
  // rooms de rôle de CELUI qui supprime → tous SES appareils retirent la
  // conversation sans recharger. Même principe que presence:update : UN
  // listener socket, N abonnés (liste owner, liste sitter/walker…).
  final List<void Function(Map<String, dynamic>)> _convDeletedSubs = [];

  void _bindConversationDeletedMux() {
    final s = _socket;
    if (s == null) return;
    s.off('conversation:deleted');
    s.on('conversation:deleted', (data) {
      Map<String, dynamic> map;
      try {
        map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      } catch (_) {
        return;
      }
      for (final cb in List.of(_convDeletedSubs)) {
        try {
          cb(map);
        } catch (e) {
          AppLogger.logError('conversation:deleted subscriber threw', error: e);
        }
      }
    });
  }

  /// Abonne un listener `conversation:deleted` (référence STABLE, idempotent).
  /// À appeler depuis un onConnected hook pour survivre aux reconnexions.
  void addConversationDeletedListener(void Function(Map<String, dynamic>) cb) {
    if (!_convDeletedSubs.contains(cb)) _convDeletedSubs.add(cb);
    _bindConversationDeletedMux();
  }

  /// Désabonne UN listener `conversation:deleted`.
  void removeConversationDeletedListener(void Function(Map<String, dynamic>) cb) {
    _convDeletedSubs.remove(cb);
  }

  /// LEGACY — délègue désormais au multiplexeur pour ne plus clobberer les
  /// autres abonnés. Préférer addMessageNewListener avec une réf stable.
  void onNewMessage(Function(Map<String, dynamic>) callback) {
    addMessageNewListener((m) => callback(m));
  }

  /// Listens for message sent confirmation.
  ///
  /// v20.0.19 — backend does NOT emit a dedicated `message:sent` event;
  /// the sender receives the same `message:new` payload via the
  /// emitToConversation fan-out. We therefore subscribe to `message:new`
  /// here too and let the caller de-duplicate by message id.
  void onMessageSent(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      // v23.1 part 205 — idem onNewMessage (cf. note plus haut). Mais
      // attention : onNewMessage ET onMessageSent visent TOUS LES DEUX
      // l'event 'message:new'. Si on .off() ici on coupe aussi le hook
      // de onNewMessage. Solution : on n'utilise PLUS .on() sur le même
      // event partagé — onMessageSent est devenu inutilisé en pratique
      // (la dedup se fait par id côté ChatController). On garde la
      // méthode pour API stability mais on ne register PLUS de listener.
      AppLogger.logInfo(
        '[v205] onMessageSent: skipped duplicate listener (handled by onNewMessage + id dedup)',
      );
      // Hint pour ne pas confondre : la callback est ignorée volontairement.
      // ignore: unused_local_variable
      final ignored = callback;
    }
  }

  /// Listens for soft-deleted messages.
  ///
  /// v20.0.19 — backend emits `message:deleted` from:
  ///   - DELETE /conversations/:id/messages/:messageId (sender self-delete)
  ///   - DELETE /admin/messages/:id (admin moderation)
  /// Payload contains `{ conversationId, messageId, ... }`.
  void onMessageDeleted(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.off('message:deleted');
      _socket!.on('message:deleted', (data) {
        try {
          final payload = data as Map<String, dynamic>;
          AppLogger.logInfo('Message deleted: $payload');
          callback(payload);
        } catch (e) {
          AppLogger.logError('Error handling message deleted', error: e);
        }
      });
    }
  }

  /// Listens for read-receipt updates emitted when the other party opens
  /// the conversation (unreadCount → 0).
  ///
  /// v20.0.19 — backend emits `conversation:read` with
  /// `{ conversationId, conversation, triggeredBy: { role, userId } }`.
  void onConversationRead(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.off('conversation:read');
      _socket!.on('conversation:read', (data) {
        try {
          final payload = data as Map<String, dynamic>;
          callback(payload);
        } catch (e) {
          AppLogger.logError('Error handling conversation read', error: e);
        }
      });
    }
  }

  /// Removes all listeners for a specific event.
  void removeListener(String event) {
    if (_socket != null) {
      _socket!.off(event);
    }
  }

  /// Removes all listeners.
  void removeAllListeners() {
    if (_socket != null) {
      _socket!.clearListeners();
    }
  }
}
