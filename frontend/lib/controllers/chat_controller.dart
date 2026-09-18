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
class ChatMessage extends ChatMessageBase {
  ChatMessage({
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

  ChatMessage copyWith({
    String? id,
    String? message,
    List<ChatAttachment>? media,
    bool? isPending,
    bool? isFailed,
    bool? isDeleted,
  }) {
    return ChatMessage(
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
class ChatConversation extends ChatConversationBase {
  ChatConversation({
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

  ChatConversation copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isOnline,
    int? unreadCount,
    DateTime? lastSeenAt,
  }) {
    return ChatConversation(
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

class ChatController extends GetxController
    with ChatSessionMixin<ChatMessage, ChatConversation> {
  ChatController(
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
  final RxList<ChatConversation> conversations = <ChatConversation>[].obs;
  @override
  final RxList<ChatMessage> currentChatMessages = <ChatMessage>[].obs;
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
  final RxList<File> selectedAttachments = <File>[].obs;

  // Sprint 3 step 4: gate chat on payment. Set when backend returns 403 + code=PAYMENT_REQUIRED.
  @override
  final RxBool isPaymentRequired = false.obs;
  final RxnString blockedBookingId = RxnString();

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
      _storage.read<String>(StorageKeys.userRole) ?? 'owner';

  @override
  String get currentUserId =>
      (_storage.read<Map<String, dynamic>>(StorageKeys.userProfile)?['id'] ??
              '')
          .toString();

  @override
  ChatMessage buildLocalMessage({
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
    return ChatMessage(
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
  ChatMessage mapServerMessage(Map<String, dynamic> raw) =>
      _mapToChatMessage(raw, currentUserId);

  @override
  ChatMessage withStatus(ChatMessage m, {bool? isPending, bool? isFailed}) =>
      m.copyWith(isPending: isPending, isFailed: isFailed);

  @override
  ChatConversation withPresence(
    ChatConversation c, {
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
    // Don't dispose messageController here - it should persist during chat flow
    // Clear the text instead to reset state without disposing
    messageController.clear();
    super.onClose();
  }

  Future<void> _initializeSocket() async {
    try {
      if (!_socketService.isConnected) {
        await _socketService.connect();
      }
      // v23.1 part 242 — Daniel : "je veux que les message et demande
      // aparaisse sur lapplication instatanement, que jai pas besoin de
      // mettre a jour la page". Avant : onNewMessage etait appele UNE
      // SEULE FOIS au _initializeSocket. Si la socket disconnect/reconnect
      // (background → foreground), le listener etait perdu jusqu'a ce
      // que l'user reouvre le chat. Fix : on enregistre les listeners
      // via addOnConnectedHook → garanti re-attachement a chaque connect.
      void wireListeners() {
        // v23.1.258 — Daniel : "les messages et la demande ne sont pas
        // instantanés, je dois rafraîchir la page". CAUSE : on ré-attachait
        // bien les listeners à chaque (re)connexion, MAIS on ne RE-REJOIGNAIT
        // PAS la room de conversation. Or joinConversation() est skippé si le
        // socket n'est pas encore connecté au moment du loadChatMessages
        // (connect() est async, _isConnected encore false juste après) → le
        // client n'entre jamais dans la room `conversationId` → les
        // `message:new` émis vers cette room ne lui arrivent jamais en direct.
        // FIX : on (re)joint la conversation courante à CHAQUE connexion.
        if (currentChatId.value.isNotEmpty) {
          _socketService.joinConversation(currentChatId.value);
        }
        // v401 — abonnement au multiplexeur avec une RÉFÉRENCE STABLE
        // (tear-off de méthode) : ne clobbere plus le listener badge du
        // NotificationsController, et _cleanupSocket retire exactement
        // CE listener sans toucher aux autres. Idempotent sur reconnexion.
        _socketService.addMessageNewListener(_handleNewMessage);
        // v565 — présence en ligne (contrat §6), réf. stable du mixin.
        _socketService.addPresenceListener(handlePresenceUpdate);
        _socketService.onMessageDeleted((payload) {
          _handleMessageDeleted(payload);
        });
        // v23.1.349 — Daniel : "j'ai accepté la demande de suivi, j'ai dû
        // mettre à jour la page pour voir 'accepté'". Le backend émet
        // `message:updated` quand la carte pawfollow_request change de statut,
        // mais l'app l'ignorait (et la dédup par id de message:new bloquait la
        // mise à jour) → REMPLACE le message existant par sa version à jour.
        _socketService.socket?.off('message:updated');
        _socketService.socket?.on('message:updated', (data) {
          if (data is Map) {
            _handleMessageUpdated(Map<String, dynamic>.from(data));
          }
        });
      }

      wireListeners(); // immediate si socket deja UP
      _socketService.addOnConnectedHook(wireListeners); // re-attach on reconnect
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
    // v401 — on retire UNIQUEMENT notre abonnement message:new (le listener
    // badge du NotificationsController reste actif). Avant, removeListener
    // ('message:new') faisait socket.off() → supprimait TOUS les abonnés →
    // badge chat mort après avoir ouvert/fermé un chat.
    _socketService.removeMessageNewListener(_handleNewMessage);
    _socketService.removePresenceListener(handlePresenceUpdate);
    _socketService.removeListener('message:deleted');
  }

  // v20.0.19 — marks a message as deleted when the OTHER party soft-deletes it.
  // Optimistic delete for our own messages is handled in deleteMessage().
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
      currentChatMessages[idx] = ChatMessage(
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
  // (changement de statut d'une carte pawfollow_request, etc.) → la carte
  // passe de "en attente" à "accepté/refusé" instantanément, sans refresh.
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
      final updated = _mapToChatMessage(raw, userId);
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
        // v23.1.170 — Daniel : "jai payer un walker on commence a secirre ds
        // le chat et la il yavais que des numlero qui saffichet et ecran
        // noir crash". Cause racine : le webhook paiement Airwallex émet
        // `message:new` avec un payload NESTED `{ conversationId, message:
        // {_id, body, senderId, ...} }`, alors que l'envoi normal émet flat
        // `{ conversationId, _id, body, senderId, ... }`. `_mapToChatMessage`
        // lit les champs au top-level → body=null → fallback affiche
        // `Map.toString()` du nested (= IDs Mongo qui ressemblent à des
        // chiffres), et _id=null → fallback `DateTime.now().millisecondsSinceEpoch`
        // (= chiffres purs). On déballe avant le mapping.
        // v23.1.276 — déballe `message` (booking) OU `sentMessage` (ami/famille).
        final raw = messageData['message'] is Map
            ? Map<String, dynamic>.from(messageData['message'] as Map)
            : messageData['sentMessage'] is Map
                ? Map<String, dynamic>.from(messageData['sentMessage'] as Map)
                : messageData;
        final newMessage = _mapToChatMessage(raw, userId);
        // v23.1.270 — Daniel : "quand j'écris ça s'écrit en double". CAUSE :
        // l'écho socket de MON PROPRE message arrive souvent AVANT que le POST
        // REST n'ait remplacé le tempId optimiste par le vrai _id → la dédup
        // par id rate → l'écho est ajouté en 2e exemplaire. FIX : on n'ajoute
        // JAMAIS l'écho de mon propre message (il est déjà affiché en optimiste
        // puis finalisé par la réponse REST). On dédup quand même par id pour
        // les messages des AUTRES (rejeu socket à la reconnexion).
        final senderId = raw['senderId']?.toString() ??
            messageData['senderId']?.toString() ??
            '';
        final isMine = senderId.isNotEmpty && senderId == userId;
        final exists = currentChatMessages.any(
          (msg) => msg.id == newMessage.id,
        );
        if (!isMine && !exists && _isRenderableMessage(newMessage)) {
          currentChatMessages.add(newMessage);
          // Update last message in conversations
          _updateLastMessage(newMessage.message);
        }
      } else {
        // v23.1 part 35 — fix Daniel "badge Chat marche pas" : quand un
        // message arrive pour une AUTRE conversation que celle ouverte
        // (ou si l'app est sur un autre tab), on incrémente le badge unreadChat
        // de NotificationsController. Avant, le _handleNewMessage ignorait
        // simplement ces messages → badge restait à 0 → user ne voyait jamais
        // qu'il avait reçu un message tant qu'il n'ouvrait pas Chat.
        try {
          final senderId =
              messageData['senderId']?.toString() ??
              messageData['message']?['senderId']?.toString() ??
              messageData['sentMessage']?['senderId']?.toString() ??
              '';
          // N'incrémente PAS si c'est nous-mêmes qui avons envoyé.
          if (senderId.isNotEmpty && senderId != userId) {
            if (Get.isRegistered<NotificationsController>()) {
              // v444 — NE PAS ré-incrémenter ici : NotificationsController.
              // _onSocketMessageNew (dédupé par id de message) est désormais
              // l'UNIQUE source du badge chat. Avant, ce ++ s'ajoutait à celui
              // de _onSocketMessageNew → double comptage (« badge 1 puis 5 »).
              // On déclenche juste une réconciliation débouncée sur le serveur.
              Get.find<NotificationsController>().scheduleChatBadgeResync();
            }
          }
        } catch (_) { /* noop */ }
      }

      // v23.1 part 242 — Daniel : "messages et demandes instatanement
      // sans avoir a mettre a jour". Update la conversations LIST aussi :
      //   - si la conv existe → update lastMessage + bump unreadCount +
      //     move to top (Whatsapp-like)
      //   - si pas dans la liste (nouvelle conv) → reloadConversations()
      // pour la voir apparaitre sans manual refresh. Avant : un nouveau
      // message pour une conv non-ouverte ne bumpait que le badge global
      // → user ne voyait pas l'aperçu / dernier message bouger dans la
      // liste tant qu'il ne refresh pas.
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
          // Remove + insert at top to bring conv to the top of the list.
          conversations.removeAt(idx);
          conversations.insert(0, updated);
        } else {
          // Conversation pas encore en cache → reload (couvre les
          // nouvelles convs qui apparaissent en temps reel).
          _loadConversations();
        }
      } catch (_) {/* defensive — never crash on real-time path */}
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
      // v23.1.267 — Daniel : "réécrire ouvre une nouvelle conversation alors
      // qu'une existe déjà". Le backend maintient 2 espaces de conversation
      // (réservation vs amis) pour la même personne → 2 docs possibles. On
      // collapse par contact (otherParty.id), en gardant le fil le plus
      // récent, pour ne montrer qu'UNE conversation par personne.
      final deduped = _dedupByOtherParty(response);
      conversations.value = deduped.map((item) {
        return _mapToChatConversation(item);
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

  /// v23.1.267 — déduplique la liste de conversations par contact
  /// (otherParty.id), en gardant la conversation la plus récente. Évite
  /// d'afficher 2 fils (réservation + amis) avec la même personne.
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

  ChatConversation _mapToChatConversation(Map<String, dynamic> data) {
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

    return ChatConversation(
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
      final role = _storage.read<String>(StorageKeys.userRole) ?? 'owner';

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
      // reconnecte". On marque la conversation LUE côté serveur dès l'ouverture :
      //  - socket conversation:read → temps réel (drop le badge de l'autre).
      //  - HTTP POST /conversations/:id/read → PERSISTE le unread=0 en DB, donc
      //    /conversations/list ne le ressort plus au reload/reconnexion.
      _socketService.markConversationRead(chatId);
      _chatRepository.markConversationRead(conversationId: chatId);
      // v444 — après avoir marqué la conv lue côté serveur, recale le badge
      // GLOBAL sur la vérité serveur (sinon il restait gonflé jusqu'au prochain
      // démarrage). Débouncé court pour laisser le POST /read se propager.
      if (Get.isRegistered<NotificationsController>()) {
        Get.find<NotificationsController>().scheduleChatBadgeResync(ms: 900);
      }

      // Fetch messages from API
      final response = await _chatRepository.getConversationMessages(
        conversationId: chatId,
        role: role,
        userId: userId,
      );

      // Map API response to ChatMessage objects
      // v23.1.276 — on filtre les artefacts vides (voir _isRenderableMessage)
      // pour ne jamais afficher de bulle fantôme vide.
      final mappedMessages = response
          .map((item) => _mapToChatMessage(item, userId))
          .where(_isRenderableMessage)
          .toList();

      AppLogger.logDebug(
        'Loaded ${mappedMessages.length} messages for conversation $chatId',
      );
      isPaymentRequired.value = false;
      blockedBookingId.value = null;
      currentChatMessages.value = mappedMessages;
    } catch (e) {
      final errorMessageStr = e.toString();
      AppLogger.logError('Error loading chat messages', error: e);

      // Check if this is a login required error
      if (AuthController.isLoginRequiredError(errorMessageStr)) {
        await AuthController.handleLoginRequiredError();
        return;
      }

      // Payment-required gate (sprint 3 step 4)
      // v23.1 part 227 — Daniel : "erreur api 403 ds longlet chat".
      // On loggue desormais le detail brut backend pour diagnostiquer
      // POURQUOI le 403 (PAYMENT_REQUIRED vs Not participant vs autre).
      // Et on affiche le message backend lisible dans errorMessage
      // au lieu d'un raw "ApiException(statusCode: 403 ...)".
      if (e is ApiException && e.statusCode == 403) {
        final details = e.details;
        AppLogger.logError(
          '[Chat 403] message="${e.message}" details=$details',
        );
        final code = details is Map ? details['code']?.toString() : null;
        if (code == 'PAYMENT_REQUIRED') {
          isPaymentRequired.value = true;
          blockedBookingId.value =
              details is Map ? details['bookingId']?.toString() : null;
          currentChatMessages.value = [];
          // v500 — Daniel : « rajoute un message quand ça arrive pour ne pas
          // laisser l'utilisateur sans compréhension ». Avant : la saisie
          // était remplacée par le mini-bandeau ~1s après l'ouverture → le
          // clavier se fermait « tout seul » et l'utilisateur croyait à un
          // bug (retours store). On explique clairement pourquoi.
          CustomSnackbar.showWarning(
            title: 'chat_gate_title'.tr,
            message: 'chat_gate_body'.tr,
          );
          return;
        }
        // 403 sans code PAYMENT_REQUIRED → surface le message backend
        // (path + role mismatch si requireRole, ou autre cause).
        errorMessage.value = e.message.isNotEmpty
            ? e.message
            : 'chat_error_403_title'.tr;
        currentChatMessages.value = [];
        return;
      }

      // v23.1 part 227 — Daniel : "erreur api 403". Pour eviter le
      // generique "wifi-off Erreur lors du chargement" quand c'est en
      // realite un message backend lisible, on extrait le message
      // ApiException si disponible.
      errorMessage.value = e is ApiException && e.message.isNotEmpty
          ? e.message
          : errorMessageStr;
      // Fallback to empty list on error
      currentChatMessages.value = [];
    } finally {
      isMessagesLoading.value = false;
    }
  }

  // v23.1.276 — un message TEXTE au corps vide, sans pièce jointe et NON
  // marqué supprimé est un artefact (ne doit jamais s'afficher) — évite la
  // bulle fantôme vide. Les messages supprimés (placeholder), les cards
  // non-texte (pawfollow_request…) et les messages avec PJ restent rendus.
  bool _isRenderableMessage(ChatMessage m) {
    if (m.isDeleted) return true;
    if (m.type != 'text') return true;
    if (m.attachments.isNotEmpty) return true;
    return m.message.trim().isNotEmpty;
  }

  ChatMessage _mapToChatMessage(
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    // v23.1.276 — Daniel : "sur lapp jecris et sa me met message supprimé".
    // CAUSE RACINE : le payload `message:new` (socket) ET la réponse REST POST
    // d'envoi nichent le vrai message sous `message` (chat booking) ou
    // `sentMessage` (chat ami/famille), avec conversationId/triggeredBy au
    // top-level. Avant on lisait data['body'] directement → null pour ces
    // enveloppes → texte vide → (v272) marqué "Message supprimé". On DÉBALLE
    // d'abord le sous-objet message s'il existe, puis on map celui-là.
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

    // Extract sender ID — robust against backend shapes where `sender` is
    // a populated Map { _id, name, avatar } instead of a plain string id.
    final senderId =
        data['senderId']?.toString() ??
        (data['sender'] is Map
            ? ((data['sender'] as Map)['_id']?.toString() ??
                  (data['sender'] as Map)['id']?.toString() ??
                  '')
            : data['sender']?.toString()) ??
        data['userId']?.toString() ??
        '';

    // v20.0.19 — comparison tolérante (trim + lowercase) pour éviter qu'un
    // mismatch de casse/whitespace fasse croire que le message n'est pas
    // à l'utilisateur → long-press désactivé → "effacer marche pas".
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

    // Extract message text
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

    // v23.1.176 — type + metadata pour pawfollow_request card.
    final typeStr = (data['type'] ?? 'text').toString();
    Map<String, dynamic> metadataMap = const {};
    if (data['metadata'] is Map) {
      try {
        metadataMap = Map<String, dynamic>.from(data['metadata'] as Map);
      } catch (_) {/* defensive */}
    }

    // v19.1.3 — soft-deleted flag from backend (body + attachments are already
    // redacted server-side, we just flip the UI bit).
    // v23.1.276 — Daniel : "sur lapp jecris et sa me met message supprimé".
    // L'heuristique v272 "texte vide ⇒ supprimé" produisait des FAUX POSITIFS
    // dès qu'un message légitime arrivait avec un body non lu (enveloppe
    // sentMessage des chats ami/famille). Maintenant qu'on déballe l'enveloppe
    // en tête de fonction, le body est toujours lu correctement, donc on
    // revient à un flag de suppression EXPLICITE uniquement : un message n'est
    // "supprimé" que si le serveur l'a marqué (isDeleted/deletedAt). Les rares
    // messages réellement vides non-supprimés sont filtrés à l'affichage.
    final isDeleted =
        data['isDeleted'] == true || data['deletedAt'] != null;

    return ChatMessage(
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

  /// v19.1.3 — Delete one of my own messages. Optimistic: flip local state to
  /// deleted immediately, then call backend; revert on error.
  /// v20.0.19 — removed the `!isFromCurrentUser` early return. The backend
  /// already enforces "only sender can delete" with a 403. If the UI marked
  /// isFromCurrentUser=false by mistake (senderId/userId string mismatch),
  /// the old code silently blocked the delete → Daniel saw "effacer marche
  /// pas". Now we always try; backend 403/404/500 surfaces a real error.
  /// v23.1.195 — Daniel : "ajouter effacer pour effacer la conversation
  /// en entier". Supprime hard la conversation + tous ses messages via
  /// le backend, puis retire de la liste locale. Optimistic update :
  /// retrait immediat, rollback en cas d'echec.
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
    if (original.isDeleted) return true; // already deleted, idempotent

    // Optimistic UI update
    currentChatMessages[idx] = ChatMessage(
      id: original.id,
      senderId: original.senderId,
      senderName: original.senderName,
      senderImage: original.senderImage,
      message: '',
      timestamp: original.timestamp,
      isFromCurrentUser: true,
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
        // v20.0.19 — Revert optimistic update ET afficher feedback clair.
        // Avant : revert silencieux → Daniel voyait le message re-apparaître
        // sans comprendre pourquoi.
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
      AppLogger.logError('deleteMessage failed', error: e);
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
      ChatMessage? actualMessage;
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
        final finalMessage = ChatMessage(
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

    // v19.1.2 — localized via i18n keys (time_days_ago / _hours_ago / _minutes_ago
     // already exist in all 6 locales).
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
}
