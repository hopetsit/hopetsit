import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/views/chat_shared/chat_api.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:image_picker/image_picker.dart';

/// v565 — hérite de ChatMessageBase (views/chat_shared/chat_models.dart) :
/// tous les getters (système, pawfollow, partage numéro/adresse, médias,
/// citation) vivent dans la base commune aux deux contrôleurs.
class SitterChatMessage extends ChatMessageBase {
  SitterChatMessage({
    required super.id,
    required super.senderId,
    required super.senderName,
    required super.senderImage,
    required super.message,
    required super.timestamp,
    required super.isFromCurrentUser,
    super.attachments,
    super.isDeleted,
    super.senderRole,
    super.type,
    super.metadata,
    super.media,
    super.replyTo,
    super.isPending,
    super.isFailed,
  });

  SitterChatMessage copyWith({
    String? id,
    String? message,
    List<ChatAttachment>? media,
    bool? isPending,
    bool? isFailed,
    bool? isDeleted,
  }) {
    return SitterChatMessage(
      id: id ?? this.id,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      message: message ?? this.message,
      timestamp: timestamp,
      isFromCurrentUser: isFromCurrentUser,
      attachments: attachments,
      isDeleted: isDeleted ?? this.isDeleted,
      senderRole: senderRole,
      type: type,
      metadata: metadata,
      media: media ?? this.media,
      replyTo: replyTo,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}

/// v565 — hérite de ChatConversationBase (contactId / lastSeenAt pour la
/// présence en ligne).
class SitterChatConversation extends ChatConversationBase {
  SitterChatConversation({
    required super.id,
    required super.contactName,
    required super.contactImage,
    required super.lastMessage,
    required super.lastMessageTime,
    required super.isOnline,
    required super.unreadCount,
    super.contactId,
    super.contactRole,
    super.lastSeenAt,
  });

  SitterChatConversation copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isOnline,
    int? unreadCount,
    DateTime? lastSeenAt,
  }) {
    return SitterChatConversation(
      id: id,
      contactName: contactName,
      contactImage: contactImage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      contactId: contactId,
      contactRole: contactRole,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class SitterChatController extends GetxController
    with ChatSessionMixin<SitterChatMessage, SitterChatConversation> {
  SitterChatController(
    this._chatRepository, {
    GetStorage? storage,
    SocketService? socketService,
  }) : _storage = storage ?? GetStorage(),
       _socketService = socketService ?? Get.find<SocketService>();

  final ChatRepository _chatRepository;
  final GetStorage _storage;
  final SocketService _socketService;
  @override
  final TextEditingController messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Observable state
  @override
  final RxList<SitterChatConversation> conversations =
      <SitterChatConversation>[].obs;
  @override
  final RxList<SitterChatMessage> currentChatMessages =
      <SitterChatMessage>[].obs;
  @override
  final RxString currentChatId = ''.obs;
  @override
  final RxBool isLoading = false.obs;

  /// v500 — Daniel : « impossible d'ecrire, le clavier se referme tout seul ».
  /// CAUSE RACINE : isLoading etait PARTAGE entre le chargement de la LISTE
  /// des conversations et celui des MESSAGES de la conversation ouverte.
  /// Chaque refresh de la liste en arriere-plan (socket message:new, resync
  /// badge, activite web du meme compte) basculait l'ecran de conversation
  /// sur le spinner plein ecran -> le champ de saisie etait detruit -> le
  /// clavier se fermait instantanement. Flag DEDIE aux messages :
  @override
  final RxBool isMessagesLoading = false.obs;
  @override
  final RxString errorMessage = ''.obs;
  @override
  final RxBool isChatLocked = false.obs;

  /// v500 — parité avec le chat owner : le backend renvoie 403
  /// PAYMENT_REQUIRED tant que la réservation n'est pas payée. Avant, le
  /// côté sitter/walker affichait juste une erreur générique incomprise.
  @override
  final RxBool isPaymentRequired = false.obs;
  final RxList<File> selectedAttachments = <File>[].obs;

  // Store contact information for the current conversation
  String _contactName = '';
  String _contactImage = '';

  void setContactInfo(String name, String image) {
    _contactName = name;
    _contactImage = image;
  }

  // ── v565 — hooks du ChatSessionMixin (views/chat_shared/chat_session.dart) ─
  @override
  String get myRole =>
      _storage.read<String>(StorageKeys.userRole) ?? 'sitter';

  @override
  String get currentUserId =>
      (_storage.read<Map<String, dynamic>>(StorageKeys.userProfile)?['id'] ??
              '')
          .toString();

  @override
  SitterChatMessage buildLocalMessage({
    required String id,
    required String body,
    required String type,
    List<ChatAttachment> media = const [],
    ChatReplyRef? replyTo,
    bool isPending = false,
    bool isFailed = false,
  }) {
    final p = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
    String img = '';
    final a = p?['avatar'];
    if (a is String) {
      img = a;
    } else if (a is Map && a['url'] != null) {
      img = a['url'].toString();
    }
    return SitterChatMessage(
      id: id,
      senderId: currentUserId,
      senderName: p?['name']?.toString() ?? 'cs_you'.tr,
      senderImage: img,
      message: body,
      timestamp: DateTime.now(),
      isFromCurrentUser: true,
      senderRole: myRole,
      type: type,
      media: media,
      replyTo: replyTo,
      isPending: isPending,
      isFailed: isFailed,
    );
  }

  @override
  SitterChatMessage mapServerMessage(Map<String, dynamic> raw) =>
      _mapToSitterChatMessage(raw, currentUserId, myRole);

  @override
  SitterChatMessage withStatus(SitterChatMessage m, {bool? isPending, bool? isFailed}) =>
      m.copyWith(isPending: isPending, isFailed: isFailed);

  @override
  SitterChatConversation withPresence(
    SitterChatConversation c, {
    required bool isOnline,
    DateTime? lastSeenAt,
  }) =>
      c.copyWith(isOnline: isOnline, lastSeenAt: lastSeenAt);

  @override
  void updateLastMessagePreview(String preview) => _updateLastMessage(preview);

  /// Aperçu d'un message sans texte (photo / vidéo / vocal / partage).
  String _previewFromRaw(Map<String, dynamic> raw) {
    final type = (raw['type'] ?? '').toString();
    if (type == 'voice') return chatPreviewForKind('audio', '');
    if (type == 'phone_share' || type == 'address_share') {
      return chatPreviewForKind(type, '');
    }
    final media = parseChatAttachments(raw['attachments']);
    if (media.isNotEmpty) {
      return chatPreviewForKind(media.first.resourceType, '');
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    _loadConversations();
    _initializeSocket();
  }

  @override
  void onClose() {
    _cleanupSocket();
    messageController.dispose();
    super.onClose();
  }

  Future<void> _initializeSocket() async {
    try {
      if (!_socketService.isConnected) {
        await _socketService.connect();
      }
      // v23.1 part 242 — re-attach socket listeners on every (re)connect
      // pour que les messages arrivent instantanement meme apres un
      // background → foreground (cf chat_controller.dart pour explication).
      void wireListeners() {
        // v23.1.258 — re-(join) la conversation à CHAQUE connexion : sinon, si
        // le socket n'était pas encore connecté au loadChatMessages, le client
        // n'entre jamais dans la room → messages/demandes pas reçus en direct
        // (il fallait rafraîchir). Cf chat_controller pour le détail.
        if (currentChatId.value.isNotEmpty) {
          _socketService.joinConversation(currentChatId.value);
        }
        // v401 — réf stable via le multiplexeur (cf. chat_controller) : ne
        // clobbere plus le listener badge du NotificationsController.
        _socketService.addMessageNewListener(_handleNewMessage);
        // v565 — présence en ligne (contrat §6), réf. stable du mixin.
        _socketService.addPresenceListener(handlePresenceUpdate);
        _socketService.onMessageDeleted((payload) {
          _handleMessageDeleted(payload);
        });
        // v23.1.349 — Daniel : statut de la carte pawfollow_request pas
        // instantané (cf chat_controller pour le détail) → on applique
        // message:updated en remplaçant le message par sa version à jour.
        _socketService.socket?.off('message:updated');
        _socketService.socket?.on('message:updated', (data) {
          if (data is Map) {
            _handleMessageUpdated(Map<String, dynamic>.from(data));
          }
        });
      }

      wireListeners();
      _socketService.addOnConnectedHook(wireListeners);
    } catch (e) {
      AppLogger.logError('Failed to initialize socket', error: e);
      final errorMessageStr = e.toString();
      if (AuthController.isLoginRequiredError(errorMessageStr)) {
        await AuthController.handleLoginRequiredError();
      }
    }
  }

  void _cleanupSocket() {
    if (currentChatId.value.isNotEmpty) {
      _socketService.leaveConversation(currentChatId.value);
    }
    // v401 — retire UNIQUEMENT notre abonnement message:new (cf.
    // chat_controller) ; le listener badge reste vivant.
    _socketService.removeMessageNewListener(_handleNewMessage);
    _socketService.removePresenceListener(handlePresenceUpdate);
    _socketService.removeListener('message:deleted');
  }

  // v20.0.19 — mirror of chat_controller's _handleMessageDeleted. Flips the
  // matching message to the isDeleted placeholder when the other party deletes
  // their own message. Our own deletes are already optimistic (deleteMessage).
  void _handleMessageDeleted(Map<String, dynamic> payload) {
    try {
      final conversationId = payload['conversationId']?.toString() ?? '';
      final messageId = payload['messageId']?.toString() ?? '';
      if (conversationId.isEmpty || messageId.isEmpty) return;
      if (conversationId != currentChatId.value) return;
      final idx = currentChatMessages.indexWhere((m) => m.id == messageId);
      if (idx < 0) return;
      final original = currentChatMessages[idx];
      if (original.isDeleted) return;
      currentChatMessages[idx] = SitterChatMessage(
        id: original.id,
        senderId: original.senderId,
        senderName: original.senderName,
        senderImage: original.senderImage,
        message: '',
        timestamp: original.timestamp,
        isFromCurrentUser: original.isFromCurrentUser,
        attachments: const [],
        isDeleted: true,
        senderRole: original.senderRole,
      );
      currentChatMessages.refresh();
    } catch (e) {
      AppLogger.logError('Error handling message deleted', error: e);
    }
  }

  // v23.1.349 — remplace un message existant par sa version mise à jour
  // (statut de carte pawfollow_request, etc.) — instantané, sans refresh.
  void _handleMessageUpdated(Map<String, dynamic> messageData) {
    try {
      final conversationId =
          messageData['conversationId']?.toString() ??
          messageData['conversation']?['id']?.toString() ??
          '';
      if (conversationId != currentChatId.value) return;
      final raw = messageData['message'] is Map
          ? Map<String, dynamic>.from(messageData['message'] as Map)
          : messageData;
      final userProfile =
          _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
      final userId = userProfile?['id']?.toString() ?? '';
      final updated = _mapToSitterChatMessage(raw, userId, 'sitter');
      final idx = currentChatMessages.indexWhere((m) => m.id == updated.id);
      if (idx < 0) return; // pas encore affiché → message:new s'en charge
      currentChatMessages[idx] = updated;
      currentChatMessages.refresh();
    } catch (e) {
      AppLogger.logError('Error handling message updated', error: e);
    }
  }

  void _handleNewMessage(Map<String, dynamic> messageData) {
    try {
      // Get user ID from storage
      final userProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      final userId = userProfile?['id']?.toString() ?? '';

      // Only add message if it belongs to the current conversation
      final conversationId =
          messageData['conversationId']?.toString() ??
          messageData['conversation']?['id']?.toString() ??
          '';

      if (conversationId == currentChatId.value) {
        // v23.1.170 — Voir chat_controller.dart pour l'explication détaillée.
        // Le webhook paiement émet un payload nested `{conversationId,
        // message: {...}}` au lieu du payload flat. Sans unpack, on affichait
        // des IDs Mongo bruts comme texte → écran noir + crash.
        // v23.1.276 — déballe `message` (booking) OU `sentMessage` (ami/famille).
        final raw = messageData['message'] is Map
            ? Map<String, dynamic>.from(messageData['message'] as Map)
            : messageData['sentMessage'] is Map
                ? Map<String, dynamic>.from(messageData['sentMessage'] as Map)
                : messageData;
        final newMessage = _mapToSitterChatMessage(
          raw,
          userId,
          'sitter',
        );
        // v23.1.270 — Daniel : "quand j'écris ça s'écrit en double". On
        // n'ajoute JAMAIS l'écho socket de mon propre message (déjà affiché en
        // optimiste + finalisé par la réponse REST) — sinon course tempId/_id
        // → doublon. Dédup par id conservée pour les messages des autres.
        final senderId = raw['senderId']?.toString() ??
            messageData['senderId']?.toString() ??
            '';
        final isMine = senderId.isNotEmpty && senderId == userId;
        // Check if message already exists to avoid duplicates
        final exists = currentChatMessages.any(
          (msg) => msg.id == newMessage.id,
        );
        if (!isMine && !exists && _isRenderableMessage(newMessage)) {
          currentChatMessages.add(newMessage);
          // Update last message in conversations
          _updateLastMessage(newMessage.message);
        }
      } else {
        // v448 — AUDIT MESSAGERIE : NE PLUS incrémenter unreadChat ici. C'est
        // exactement le double-comptage « 1 puis 5 » que v444 avait retiré de
        // chat_controller.dart mais qui était RESTÉ ici (sitter/walker) : le
        // badge était bumpé À LA FOIS par NotificationsController._onSocketMessageNew
        // (dédupé par id de message) ET par ce ++ brut (sans dédup), souvent
        // plusieurs fois car message:new est diffusé aux 3 rooms de rôle.
        // Source unique de vérité = NotificationsController. On se contente de
        // déclencher un resync débouncé sur le vrai total serveur.
        try {
          if (Get.isRegistered<NotificationsController>()) {
            Get.find<NotificationsController>().scheduleChatBadgeResync();
          }
        } catch (_) { /* noop */ }
      }

      // v23.1 part 242 — Update conversations LIST aussi (Whatsapp-like).
      // Cf chat_controller.dart pour l'explication detaillee. Resultat :
      // le sitter/walker voit la conv bumper au top + last message preview
      // mis a jour en temps reel, sans avoir a refresh.
      try {
        // v23.1.276 — déballe `message` (booking) OU `sentMessage` (ami/famille).
        final raw = messageData['message'] is Map
            ? Map<String, dynamic>.from(messageData['message'] as Map)
            : messageData['sentMessage'] is Map
                ? Map<String, dynamic>.from(messageData['sentMessage'] as Map)
                : messageData;
        final msgConvId =
            messageData['conversationId']?.toString() ??
            messageData['conversation']?['id']?.toString() ??
            '';
        if (msgConvId.isEmpty) return;
        final rawBody = (raw['body'] ?? raw['message'] ?? '').toString();
        // v565 — aperçu lisible pour photo / vidéo / vocal sans texte.
        final body = rawBody.trim().isNotEmpty ? rawBody : _previewFromRaw(raw);
        final senderIdForList =
            raw['senderId']?.toString() ??
            (raw['sender'] is Map ? (raw['sender'] as Map)['_id']?.toString() : null) ??
            '';
        final isFromOther = senderIdForList.isNotEmpty && senderIdForList != userId;
        final idx = conversations.indexWhere((c) => c.id == msgConvId);
        if (idx >= 0) {
          final existing = conversations[idx];
          final updated = existing.copyWith(
            lastMessage: body.isNotEmpty ? body : existing.lastMessage,
            lastMessageTime: DateTime.now(),
            unreadCount: isFromOther && msgConvId != currentChatId.value
                ? existing.unreadCount + 1
                : existing.unreadCount,
          );
          conversations.removeAt(idx);
          conversations.insert(0, updated);
        } else {
          // Nouvelle conv pas encore en cache → reload.
          _loadConversations();
        }
      } catch (_) {/* defensive */}
    } catch (e) {
      AppLogger.logError('Error handling new message from socket', error: e);
    }
  }

  /// Public method to reload conversations (can be called from UI)
  @override
  Future<void> reloadConversations() async {
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _chatRepository.getChatList();
      // v23.1.267 — dédup par contact (otherParty.id) : ne montrer qu'UNE
      // conversation par personne (évite le doublon réservation + amis).
      final deduped = _dedupByOtherParty(response);
      conversations.value = deduped.map((item) {
        return _mapToSitterChatConversation(item);
      }).toList();
    } catch (e) {
      // v18.7 — affiche le message backend (FR) au lieu du raw ApiException.
      errorMessage.value = e is ApiException && e.message.isNotEmpty
          ? e.message
          : 'chat_error_loading_messages'.tr;
      conversations.value = [];
      debugPrint('Error loading conversations: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// v23.1.267 — déduplique la liste par contact (otherParty.id), gardant la
  /// conversation la plus récente (évite 2 fils réservation + amis).
  List<Map<String, dynamic>> _dedupByOtherParty(dynamic items) {
    int ts(Map m) {
      final v = m['lastMessageAt'] ?? m['lastMessageTime'] ?? m['updatedAt'];
      if (v is int) return v;
      final d = DateTime.tryParse(v?.toString() ?? '');
      return d?.millisecondsSinceEpoch ?? 0;
    }

    final byKey = <String, Map<String, dynamic>>{};
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final it = Map<String, dynamic>.from(raw);
        final op = it['otherParty'];
        final otherId =
            (op is Map ? (op['id'] ?? op['_id']) : null)?.toString() ?? '';
        final key = otherId.isNotEmpty
            ? 'u:$otherId'
            : 'c:${(it['_id'] ?? it['id'] ?? '').toString()}';
        final existing = byKey[key];
        if (existing == null || ts(it) >= ts(existing)) {
          byKey[key] = it;
        }
      }
    }
    final result = byKey.values.toList()
      ..sort((a, b) => ts(b).compareTo(ts(a)));
    return result;
  }

  SitterChatConversation _mapToSitterChatConversation(
    Map<String, dynamic> data,
  ) {
    // Extract conversation ID
    final id =
        data['_id']?.toString() ??
        data['id']?.toString() ??
        data['conversationId']?.toString() ??
        '';

    // Extract contact information - prioritize otherParty (the person you're chatting with)
    String contactName = 'Unknown';
    if (data['otherParty'] != null && data['otherParty'] is Map) {
      contactName = data['otherParty']['name']?.toString() ?? 'Unknown';
    } else {
      contactName =
          data['contactName']?.toString() ??
          data['name']?.toString() ??
          data['participantName']?.toString() ??
          'Unknown';
    }

    // Extract contact image - prioritize otherParty avatar
    String contactImage = '';
    if (data['otherParty'] != null && data['otherParty'] is Map) {
      final otherParty = data['otherParty'] as Map<String, dynamic>;
      if (otherParty['avatar'] != null) {
        if (otherParty['avatar'] is String) {
          contactImage = otherParty['avatar'] as String;
        } else if (otherParty['avatar'] is Map &&
            otherParty['avatar']['url'] != null) {
          contactImage = otherParty['avatar']['url'] as String;
        }
      }
    }

    // Fallback to other fields if otherParty doesn't have avatar
    if (contactImage.isEmpty) {
      if (data['contactImage'] != null) {
        if (data['contactImage'] is String) {
          contactImage = data['contactImage'] as String;
        } else if (data['contactImage'] is Map &&
            data['contactImage']['url'] != null) {
          contactImage = data['contactImage']['url'] as String;
        }
      } else if (data['avatar'] != null) {
        if (data['avatar'] is String) {
          contactImage = data['avatar'] as String;
        } else if (data['avatar'] is Map && data['avatar']['url'] != null) {
          contactImage = data['avatar']['url'] as String;
        }
      } else if (data['profileImage'] != null) {
        if (data['profileImage'] is String) {
          contactImage = data['profileImage'] as String;
        } else if (data['profileImage'] is Map &&
            data['profileImage']['url'] != null) {
          contactImage = data['profileImage']['url'] as String;
        }
      }
    }

    // Use empty string as fallback (UI will show icon instead)
    if (contactImage.isEmpty) {
      contactImage = '';
    }

    // Extract last message
    final lastMessage =
        data['lastMessage']?.toString() ??
        data['message']?.toString() ??
        data['text']?.toString() ??
        '';

    // Extract last message time
    DateTime lastMessageTime;
    if (data['lastMessageTime'] != null) {
      if (data['lastMessageTime'] is String) {
        lastMessageTime =
            DateTime.tryParse(data['lastMessageTime']) ?? DateTime.now();
      } else if (data['lastMessageTime'] is int) {
        lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
          data['lastMessageTime'],
        );
      } else {
        lastMessageTime = DateTime.now();
      }
    } else if (data['updatedAt'] != null) {
      if (data['updatedAt'] is String) {
        lastMessageTime =
            DateTime.tryParse(data['updatedAt']) ?? DateTime.now();
      } else if (data['updatedAt'] is int) {
        lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
          data['updatedAt'],
        );
      } else {
        lastMessageTime = DateTime.now();
      }
    } else {
      lastMessageTime = DateTime.now();
    }

    // v565 — présence (contrat §6) : `isOnline` calculé par le serveur +
    // `lastSeenAt` ; identité du correspondant pour `presence:update`.
    final isOnline =
        data['isOnline'] == true || data['online'] == true || false;
    final op = data['otherParty'] is Map
        ? Map<String, dynamic>.from(data['otherParty'] as Map)
        : const <String, dynamic>{};
    final contactId =
        (op['id'] ?? op['_id'] ?? op['userId'] ?? data['otherPartyId'] ?? '')
            .toString();
    final contactRole = (op['role'] ?? data['otherPartyRole'] ?? '').toString();
    DateTime? lastSeenAt;
    final rawSeen = data['lastSeenAt'] ?? op['lastSeenAt'];
    if (rawSeen is String) lastSeenAt = DateTime.tryParse(rawSeen);
    if (rawSeen is int) lastSeenAt = DateTime.fromMillisecondsSinceEpoch(rawSeen);

    // Extract unread count
    final unreadCount = data['unreadCount'] is int
        ? ((data['unreadCount'] ?? 0) as num).toInt()
        : (data['unread'] is num ? (data['unread'] as num).toInt() : 0);

    return SitterChatConversation(
      id: id,
      contactName: contactName,
      contactImage: contactImage,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      isOnline: isOnline,
      unreadCount: unreadCount,
      contactId: contactId,
      contactRole: contactRole,
      lastSeenAt: lastSeenAt,
    );
  }

  @override
  Future<void> loadChatMessages(
    String chatId, {
    String? contactName,
    String? contactImage,
  }) async {
    // Leave previous conversation if any
    if (currentChatId.value.isNotEmpty && currentChatId.value != chatId) {
      _socketService.leaveConversation(currentChatId.value);
    }

    currentChatId.value = chatId;

    // Store contact information if provided
    if (contactName != null && contactName.isNotEmpty) {
      _contactName = contactName;
    }
    if (contactImage != null) {
      _contactImage = contactImage;
    }

    isMessagesLoading.value = true;
    errorMessage.value = '';

    try {
      // Get user ID and role from storage
      final userProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      final userId = userProfile?['id']?.toString();
      final role = _storage.read<String>(StorageKeys.userRole) ?? 'sitter';

      if (userId == null || userId.isEmpty) {
        await AuthController.handleLoginRequiredError();
        return;
      }

      // Ensure socket is connected
      if (!_socketService.isConnected) {
        await _socketService.connect();
      }

      // Join conversation room for real-time updates
      _socketService.joinConversation(chatId);
      // v565 — point vert / vu il y a X + drapeaux admin du chat.
      replyTarget.value = null;
      syncPeerPresence(chatId);
      loadFeatures();

      // v23.1.301 — Daniel : "une fois lus, les badges reviennent quand je me
      // reconnecte". On marque la conversation LUE côté serveur dès l'ouverture
      // (socket = temps réel, HTTP = persiste unread=0 en DB → /conversations
      // /list ne ressort plus le badge au reload/reconnexion).
      _socketService.markConversationRead(chatId);
      _chatRepository.markConversationRead(conversationId: chatId);

      // Fetch messages from API
      final response = await _chatRepository.getConversationMessages(
        conversationId: chatId,
        role: role,
        userId: userId,
      );

      // Map API response to SitterChatMessage objects
      // v23.1.276 — filtre les artefacts vides (voir _isRenderableMessage).
      final mappedMessages = response
          .map((item) => _mapToSitterChatMessage(item, userId, role))
          .where(_isRenderableMessage)
          .toList();

      AppLogger.logDebug(
        'Loaded ${mappedMessages.length} messages for conversation $chatId',
      );
      isPaymentRequired.value = false;
      currentChatMessages.value = mappedMessages;
    } catch (e) {
      final errorMessageStr = e.toString();
      AppLogger.logError('Error loading chat messages', error: e);

      // Check if this is a login required error
      if (AuthController.isLoginRequiredError(errorMessageStr)) {
        await AuthController.handleLoginRequiredError();
        return;
      }

      // v500 — même détection PAYMENT_REQUIRED que le chat owner (le
      // backend verrouille tant que la réservation n'est pas payée) :
      // panneau clair + snackbar au lieu d'une erreur générique.
      if (e is ApiException && e.statusCode == 403) {
        final details = e.details;
        final code = details is Map ? details['code']?.toString() : null;
        if (code == 'PAYMENT_REQUIRED') {
          isPaymentRequired.value = true;
          currentChatMessages.value = [];
          CustomSnackbar.showWarning(
            title: 'chat_gate_title'.tr,
            message: 'chat_gate_body'.tr,
          );
          return;
        }
      }

      errorMessage.value = errorMessageStr;
      // Fallback to empty list on error
      currentChatMessages.value = [];
    } finally {
      isMessagesLoading.value = false;
    }
  }

  // v23.1.276 — artefact vide (texte sans corps/PJ, non supprimé) → jamais
  // affiché (évite la bulle fantôme). Voir chat_controller pour le détail.
  bool _isRenderableMessage(SitterChatMessage m) {
    if (m.isDeleted) return true;
    if (m.type != 'text') return true;
    if (m.attachments.isNotEmpty) return true;
    return m.message.trim().isNotEmpty;
  }

  SitterChatMessage _mapToSitterChatMessage(
    Map<String, dynamic> data,
    String currentUserId,
    String currentUserRole,
  ) {
    // v23.1.276 — Daniel : "sur lapp jecris et sa me met message supprimé".
    // Le payload message:new (socket) et la réponse REST POST nichent le vrai
    // message sous `message` (booking) ou `sentMessage` (ami/famille). On
    // DÉBALLE l'enveloppe d'abord, sinon body=null → faux "Message supprimé".
    if (data['message'] is Map) {
      data = Map<String, dynamic>.from(data['message'] as Map);
    } else if (data['sentMessage'] is Map) {
      data = Map<String, dynamic>.from(data['sentMessage'] as Map);
    }
    // Extract message ID
    final id =
        data['_id']?.toString() ??
        data['id']?.toString() ??
        data['messageId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Extract sender ID
    final senderId =
        data['senderId']?.toString() ??
        (data['sender'] is Map
            ? ((data['sender'] as Map)['_id']?.toString() ??
                  (data['sender'] as Map)['id']?.toString() ??
                  '')
            : data['sender']?.toString()) ??
        data['userId']?.toString() ??
        '';

    // v20.0.19 — comparison tolérante : trim + lowercase pour éviter les
    // mismatch du type "61A2B3..." vs "61a2b3..." ou whitespace surnuméraire
    // qui faisaient croire que le message n'appartenait pas à l'utilisateur.
    // Conséquence du bug : le sitter/walker ne pouvait plus long-press son
    // propre message → pas de menu Effacer → "le bouton effacer marche pas".
    final sid = senderId.trim().toLowerCase();
    final cid = currentUserId.trim().toLowerCase();
    final isFromCurrentUser = sid.isNotEmpty && sid == cid;

    // Extract sender name - check multiple possible fields
    String senderName = '';
    if (data['senderName'] != null) {
      senderName = data['senderName']?.toString() ?? '';
    } else if (data['sender'] != null) {
      if (data['sender'] is Map) {
        senderName = data['sender']?['name']?.toString() ?? '';
      } else if (data['sender'] is String) {
        // If sender is just an ID, we'll need to look it up
        senderName = '';
      }
    } else if (data['name'] != null) {
      senderName = data['name']?.toString() ?? '';
    }

    // Check for senderRole-based fields (owner/sitter)
    final senderRole = data['senderRole']?.toString() ?? '';
    if (senderName.isEmpty && senderRole.isNotEmpty) {
      // Try to get from role-specific fields
      if (data['owner'] != null &&
          data['owner'] is Map &&
          senderRole == 'owner') {
        senderName = data['owner']['name']?.toString() ?? '';
      } else if (data['sitter'] != null &&
          data['sitter'] is Map &&
          senderRole == 'sitter') {
        senderName = data['sitter']['name']?.toString() ?? '';
      }
    }

    // If sender name is still empty and it's from current user, get from storage
    if (senderName.isEmpty && isFromCurrentUser) {
      final userProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      senderName = userProfile?['name']?.toString() ?? 'You';
    } else if (senderName.isEmpty) {
      // For other users, use stored contact information
      senderName = _contactName.isNotEmpty ? _contactName : 'Unknown';
    }

    // Extract sender image - handle both string URLs and objects with url field
    String senderImage = '';
    if (data['senderImage'] != null) {
      if (data['senderImage'] is String) {
        senderImage = data['senderImage'] as String;
      } else if (data['senderImage'] is Map &&
          data['senderImage']['url'] != null) {
        senderImage = data['senderImage']['url'] as String;
      }
    } else if (data['sender'] != null && data['sender'] is Map) {
      final sender = data['sender'] as Map<String, dynamic>;
      if (sender['avatar'] != null) {
        if (sender['avatar'] is String) {
          senderImage = sender['avatar'] as String;
        } else if (sender['avatar'] is Map && sender['avatar']['url'] != null) {
          senderImage = sender['avatar']['url'] as String;
        }
      }
    } else if (data['avatar'] != null) {
      if (data['avatar'] is String) {
        senderImage = data['avatar'] as String;
      } else if (data['avatar'] is Map && data['avatar']['url'] != null) {
        senderImage = data['avatar']['url'] as String;
      }
    } else if (data['profileImage'] != null) {
      if (data['profileImage'] is String) {
        senderImage = data['profileImage'] as String;
      } else if (data['profileImage'] is Map &&
          data['profileImage']['url'] != null) {
        senderImage = data['profileImage']['url'] as String;
      }
    }

    // Check for senderRole-based fields (owner/sitter)
    if (senderImage.isEmpty && senderRole.isNotEmpty) {
      if (data['owner'] != null &&
          data['owner'] is Map &&
          senderRole == 'owner') {
        final owner = data['owner'] as Map<String, dynamic>;
        if (owner['avatar'] != null) {
          if (owner['avatar'] is String) {
            senderImage = owner['avatar'] as String;
          } else if (owner['avatar'] is Map && owner['avatar']['url'] != null) {
            senderImage = owner['avatar']['url'] as String;
          }
        }
      } else if (data['sitter'] != null &&
          data['sitter'] is Map &&
          senderRole == 'sitter') {
        final sitter = data['sitter'] as Map<String, dynamic>;
        if (sitter['avatar'] != null) {
          if (sitter['avatar'] is String) {
            senderImage = sitter['avatar'] as String;
          } else if (sitter['avatar'] is Map &&
              sitter['avatar']['url'] != null) {
            senderImage = sitter['avatar']['url'] as String;
          }
        }
      }
    }

    // If sender image is still empty and it's from current user, get from storage
    if (senderImage.isEmpty && isFromCurrentUser) {
      final userProfile = _storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      if (userProfile?['avatar'] != null) {
        if (userProfile!['avatar'] is String) {
          senderImage = userProfile['avatar'] as String;
        } else if (userProfile['avatar'] is Map &&
            userProfile['avatar']['url'] != null) {
          senderImage = userProfile['avatar']['url'] as String;
        }
      }
    } else if (senderImage.isEmpty) {
      // For other users, use stored contact image
      senderImage = _contactImage;
    }

    // Use empty string as fallback (UI will show icon instead)
    if (senderImage.isEmpty) {
      senderImage = '';
    }

    // Extract message text - prioritize 'body' field as per API response
    final message =
        data['body']?.toString() ??
        data['message']?.toString() ??
        data['text']?.toString() ??
        data['content']?.toString() ??
        '';

    // Extract timestamp
    DateTime timestamp;
    if (data['timestamp'] != null) {
      if (data['timestamp'] is String) {
        timestamp = DateTime.tryParse(data['timestamp']) ?? DateTime.now();
      } else if (data['timestamp'] is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
      } else {
        timestamp = DateTime.now();
      }
    } else if (data['createdAt'] != null) {
      if (data['createdAt'] is String) {
        timestamp = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
      } else if (data['createdAt'] is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(data['createdAt']);
      } else {
        timestamp = DateTime.now();
      }
    } else {
      timestamp = DateTime.now();
    }

    // Extract attachments
    List<String> attachments = [];
    if (data['attachments'] != null) {
      if (data['attachments'] is List) {
        attachments = (data['attachments'] as List)
            .map((item) {
              if (item is String) {
                return item;
              } else if (item is Map) {
                // Try different possible field names
                if (item['url'] != null) {
                  return item['url'] is String
                      ? item['url'] as String
                      : item['url'].toString();
                } else if (item['file'] != null) {
                  return item['file'] is String
                      ? item['file'] as String
                      : item['file'].toString();
                } else if (item['fileUrl'] != null) {
                  return item['fileUrl'] is String
                      ? item['fileUrl'] as String
                      : item['fileUrl'].toString();
                } else if (item['attachmentUrl'] != null) {
                  return item['attachmentUrl'] is String
                      ? item['attachmentUrl'] as String
                      : item['attachmentUrl'].toString();
                }
              }
              return '';
            })
            .where(
              (url) =>
                  url.isNotEmpty &&
                  (url.startsWith('http://') || url.startsWith('https://')),
            )
            .toList();
      }
    }

    AppLogger.logDebug(
      'Extracted ${attachments.length} attachments for message $id',
    );
    if (attachments.isNotEmpty) {
      AppLogger.logDebug('Attachment URLs: $attachments');
    }

    final senderRoleStr = (data['senderRole'] ?? data['sender_role'] ?? '').toString();

    // v23.1.176 — type + metadata pour la carte pawfollow_request.
    final typeStr = (data['type'] ?? 'text').toString();
    Map<String, dynamic> metadataMap = const {};
    if (data['metadata'] is Map) {
      try {
        metadataMap = Map<String, dynamic>.from(data['metadata'] as Map);
      } catch (_) {/* defensive */}
    }

    // v19.1.3 — soft-deleted flag from backend.
    // v23.1.276 — Daniel : "sur lapp jecris et sa me met message supprimé".
    // On retire l'heuristique v272 "texte vide ⇒ supprimé" (faux positifs sur
    // les messages dont l'enveloppe sentMessage n'était pas déballée). Le body
    // est désormais toujours lu (déballage en tête), donc suppression EXPLICITE
    // uniquement ; les rares vides non-supprimés sont filtrés à l'affichage.
    final isDeleted =
        data['isDeleted'] == true || data['deletedAt'] != null;

    return SitterChatMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderImage: senderImage,
      message: message,
      timestamp: timestamp,
      isFromCurrentUser: isFromCurrentUser,
      attachments: attachments,
      isDeleted: isDeleted,
      senderRole: senderRoleStr,
      type: typeStr,
      metadata: metadataMap,
      // v565 — pièces typées + citation (contrat §5).
      media: parseChatAttachments(data['attachments']),
      replyTo: parseChatReplyTo(data['replyTo']),
    );
  }

  /// v19.1.3 — Delete my own message (sitter + walker side).
  /// v20.0.19 — même fix que ChatController (owner) :
  ///   - retiré le blocage silencieux `!isFromCurrentUser` qui empêchait
  ///     la suppression quand le mapping senderId/userId était foireux
  ///   - ajouté un snackbar d'erreur visible en cas d'échec (avant c'était
  ///     un revert silencieux → l'user ne comprenait pas pourquoi le
  ///     message "réapparaissait" tout seul).
  /// v23.1.196 — Daniel : "ajouter effacer pour effacer la conversation
  /// en entier". Supprime hard la conv + tous ses messages cote backend,
  /// puis retire de la liste locale. Optimistic + rollback si echec.
  @override
  Future<bool> deleteConversation(String conversationId) async {
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) return false;
    final removed = conversations[idx];
    conversations.removeAt(idx);
    try {
      final ok = await _chatRepository.deleteConversation(
        conversationId: conversationId,
      );
      if (!ok) {
        conversations.insert(idx, removed);
        Get.snackbar('common_error'.tr, 'common_try_again'.tr);
        return false;
      }
      return true;
    } catch (e) {
      conversations.insert(idx, removed);
      Get.snackbar(
        'common_error'.tr,
        e.toString().replaceAll('ApiException:', '').trim(),
      );
      return false;
    }
  }

  @override
  Future<bool> deleteMessage(String messageId) async {
    if (currentChatId.value.isEmpty) return false;
    final idx = currentChatMessages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return false;
    final original = currentChatMessages[idx];
    if (original.isDeleted) return true; // idempotent

    currentChatMessages[idx] = SitterChatMessage(
      id: original.id,
      senderId: original.senderId,
      senderName: original.senderName,
      senderImage: original.senderImage,
      message: '',
      timestamp: original.timestamp,
      isFromCurrentUser: original.isFromCurrentUser,
      attachments: const [],
      isDeleted: true,
    );
    currentChatMessages.refresh();

    try {
      final ok = await _chatRepository.deleteMessage(
        conversationId: currentChatId.value,
        messageId: messageId,
      );
      if (!ok) {
        currentChatMessages[idx] = original;
        currentChatMessages.refresh();
        Get.snackbar(
          'common_error'.tr,
          'chat_delete_message_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      return ok;
    } catch (e) {
      AppLogger.logError('deleteMessage failed (sitter/walker)', error: e);
      currentChatMessages[idx] = original;
      currentChatMessages.refresh();
      Get.snackbar(
        'common_error'.tr,
        'chat_delete_message_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// Sprint 3 step 6 — share sitter's profile phone via the dedicated endpoint.
  /// Reloads messages on success so the new phone_share appears in the thread.
  Future<void> sharePhone() async {
    if (currentChatId.value.isEmpty) {
      return;
    }
    try {
      await _chatRepository.sharePhone(conversationId: currentChatId.value);
      await loadChatMessages(currentChatId.value);
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  @override
  Future<void> sendMessage() async {
    final messageText = messageController.text.trim();
    // v565 — les pièces jointes sélectionnées (ancien flux « + » avec aperçu)
    // partent par le canal média réparé : une requête par fichier, timeout
    // long, `kind=media` (contrat §5).
    if (selectedAttachments.isNotEmpty) {
      final files = List<File>.from(selectedAttachments);
      selectedAttachments.clear();
      await sendMediaFiles(files);
    }
    if (messageText.isEmpty || currentChatId.value.isEmpty) {
      return;
    }

    final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    // v565 — réponse à un message : instantané local + `replyTo.messageId`.
    final replyRef = snapshotReply();
    final optimisticMessage = buildLocalMessage(
      id: tempId,
      body: messageText,
      type: 'text',
      replyTo: replyRef,
      isPending: true,
    );

    // Add optimistic message immediately
    currentChatMessages.add(optimisticMessage);
    messageController.clear();
    replyTarget.value = null;
    _updateLastMessage(messageText);

    try {
      final response = await ChatApi.sendText(
        conversationId: currentChatId.value,
        body: messageText,
        senderRole: myRole,
        senderId: currentUserId,
        replyToMessageId: replyRef?.messageId,
      );

      // v23.1 part 240 — mapping défensif : si le payload est illisible on
      // GARDE la bulle optimiste (plus d'écran noir).
      SitterChatMessage? actualMessage;
      try {
        actualMessage = mapServerMessage(response);
      } catch (mappingErr) {
        AppLogger.logError(
          'sendMessage : mapping failed, keeping optimistic',
          error: mappingErr,
        );
      }

      final index = currentChatMessages.indexWhere((msg) => msg.id == tempId);
      if (actualMessage != null) {
        final a = actualMessage;
        final finalMessage = SitterChatMessage(
          id: a.id,
          senderId: a.senderId.isNotEmpty ? a.senderId : currentUserId,
          senderName: a.senderName == 'You' || a.senderName == 'Unknown'
              ? optimisticMessage.senderName
              : a.senderName,
          senderImage: a.senderImage.isEmpty
              ? optimisticMessage.senderImage
              : a.senderImage,
          message: a.message.isNotEmpty ? a.message : messageText,
          timestamp: a.timestamp,
          isFromCurrentUser: true,
          attachments: a.attachments,
          senderRole: a.senderRole,
          type: a.type,
          metadata: a.metadata,
          media: a.media,
          replyTo: a.replyTo ?? replyRef,
        );
        if (index != -1) {
          currentChatMessages[index] = finalMessage;
        } else {
          currentChatMessages.add(finalMessage);
        }
      } else if (index != -1) {
        currentChatMessages[index] = optimisticMessage.copyWith(isPending: false);
      }
      // Socket will handle real-time updates for other users.
    } catch (e) {
      AppLogger.logError('Error sending message', error: e);
      // Remove optimistic message on error
      currentChatMessages.removeWhere((msg) => msg.id == tempId);
      if (_isChatLockedAfterPaymentError(e)) {
        isChatLocked.value = true;
        messageController.clear();
        selectedAttachments.clear();
        CustomSnackbar.showWarning(
          title: 'chat_locked_title'.tr,
          message: 'chat_locked_after_payment'.tr,
        );
        return;
      }
      // Restore message text (and the quoted message) so the user can retry.
      messageController.text = messageText;
      if (ChatApi.isFeatureDisabled(e)) {
        // v565 — l'admin a désactivé les réponses : on renvoie sans citation.
        final f = features.value;
        features.value =
            ChatFeatureFlags(media: f.media, voice: f.voice, reply: false);
        CustomSnackbar.showWarning(
          title: 'common_error'.tr,
          message: 'cs_feature_disabled'.tr,
        );
        return;
      }
      errorMessage.value = 'cs_send_failed_body'.tr;
      // v500 — afficher la VRAIE raison renvoyée par le serveur.
      final apiMsg = e is ApiException
          ? '[${e.statusCode ?? '?'}] ${e.message}'
          : (e is NetworkUnreachableException
              ? 'cs_send_failed_body'.tr
              : e.toString());
      CustomSnackbar.showError(
        title: 'cs_send_failed_title'.tr,
        message: apiMsg.length > 220 ? apiMsg.substring(0, 220) : apiMsg,
      );
    }
  }

  bool _isChatLockedAfterPaymentError(Object error) {
    final raw = (error is ApiException ? error.message : error.toString())
        .toLowerCase();
    final is403 = error is ApiException && (error.statusCode ?? 0) == 403;
    final hasPaymentGateMessage =
        raw.contains('chat is only available after payment is completed') ||
        (raw.contains('chat') &&
            raw.contains('payment') &&
            (raw.contains('completed') || raw.contains('booking')));
    return is403 && hasPaymentGateMessage;
  }

  Future<void> pickAttachments() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        // Add new files to the list (limit to 10 files max)
        final newFiles = pickedFiles
            .take(10 - selectedAttachments.length)
            .map((xFile) => File(xFile.path))
            .toList();

        selectedAttachments.addAll(newFiles);

        if (pickedFiles.length >
            (10 - selectedAttachments.length + newFiles.length)) {
          AppLogger.logInfo('Attachment limit reached: Only 10 files allowed');
        }
      }
    } catch (e) {
      AppLogger.logError('Failed to pick attachments', error: e);
    }
  }

  void removeAttachment(int index) {
    if (index >= 0 && index < selectedAttachments.length) {
      selectedAttachments.removeAt(index);
    }
  }

  void _updateLastMessage(String message) {
    final conversationIndex = conversations.indexWhere(
      (conv) => conv.id == currentChatId.value,
    );
    if (conversationIndex != -1) {
      conversations[conversationIndex] =
          conversations[conversationIndex].copyWith(
        lastMessage: '${'cs_you'.tr}: $message',
        lastMessageTime: DateTime.now(),
      );
    }
  }

  @override
  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // v565 — localisé (parité avec ChatController owner).
    if (difference.inDays > 0) {
      return 'time_days_ago'.trParams({'count': difference.inDays.toString()});
    } else if (difference.inHours > 0) {
      return 'time_hours_ago'.trParams({'count': difference.inHours.toString()});
    } else if (difference.inMinutes > 0) {
      return 'time_minutes_ago'.trParams({'count': difference.inMinutes.toString()});
    } else {
      return 'time_just_now'.tr;
    }
  }

  String formatMessageTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $period';
  }
}
