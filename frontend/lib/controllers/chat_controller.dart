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
import 'package:image_picker/image_picker.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String message;
  final DateTime timestamp;
  final bool isFromCurrentUser;
  final List<String> attachments;
  // v19.1.3 — soft-delete flag, backend hides body+attachments for deleted.
  final bool isDeleted;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.message,
    required this.timestamp,
    required this.isFromCurrentUser,
    this.attachments = const [],
    this.isDeleted = false,
  });
}

class ChatConversation {
  final String id;
  final String contactName;
  final String contactImage;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isOnline;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.contactName,
    required this.contactImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isOnline,
    required this.unreadCount,
  });
}

class ChatController extends GetxController {
  ChatController(
    this._chatRepository, {
    GetStorage? storage,
    SocketService? socketService,
  }) : _storage = storage ?? GetStorage(),
       _socketService = socketService ?? Get.find<SocketService>();

  final ChatRepository _chatRepository;
  final GetStorage _storage;
  final SocketService _socketService;
  final TextEditingController messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Observable state
  final RxList<ChatConversation> conversations = <ChatConversation>[].obs;
  final RxList<ChatMessage> currentChatMessages = <ChatMessage>[].obs;
  final RxString currentChatId = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isChatLocked = false.obs;
  final RxList<File> selectedAttachments = <File>[].obs;

  // Sprint 3 step 4: gate chat on payment. Set when backend returns 403 + code=PAYMENT_REQUIRED.
  final RxBool isPaymentRequired = false.obs;
  final RxnString blockedBookingId = RxnString();

  // Store contact information for the current conversation
  String _contactName = '';
  String _contactImage = '';

  void setContactInfo(String name, String image) {
    _contactName = name;
    _contactImage = image;
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
      // Listen for new messages
      _socketService.onNewMessage((messageData) {
        _handleNewMessage(messageData);
      });
      // v20.0.19 — listen for soft-delete events so the other party sees the
      // "message deleted" placeholder appear in real time (no refresh needed).
      _socketService.onMessageDeleted((payload) {
        _handleMessageDeleted(payload);
      });
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
    // v20.0.19 — backend emits `message:new` (colon), not `new_message`.
    _socketService.removeListener('message:new');
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
      );
      currentChatMessages.refresh();
    } catch (e) {
      AppLogger.logError('Error handling message deleted', error: e);
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
        final newMessage = _mapToChatMessage(messageData, userId);
        // Check if message already exists to avoid duplicates
        final exists = currentChatMessages.any(
          (msg) => msg.id == newMessage.id,
        );
        if (!exists) {
          currentChatMessages.add(newMessage);
          // Update last message in conversations
          _updateLastMessage(newMessage.message);
        }
      }
    } catch (e) {
      AppLogger.logError('Error handling new message from socket', error: e);
    }
  }

  /// Public method to reload conversations (can be called from UI)
  Future<void> reloadConversations() async {
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final response = await _chatRepository.getChatList();
      conversations.value = response.map((item) {
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

    // Extract online status
    final isOnline =
        data['isOnline'] == true || data['online'] == true || false;

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
    );
  }

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

    isLoading.value = true;
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

      // Fetch messages from API
      final response = await _chatRepository.getConversationMessages(
        conversationId: chatId,
        role: role,
        userId: userId,
      );

      // Map API response to ChatMessage objects
      final mappedMessages = response.map((item) {
        return _mapToChatMessage(item, userId);
      }).toList();

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
      if (e is ApiException && e.statusCode == 403) {
        final details = e.details;
        final code = details is Map ? details['code']?.toString() : null;
        if (code == 'PAYMENT_REQUIRED') {
          isPaymentRequired.value = true;
          blockedBookingId.value =
              details is Map ? details['bookingId']?.toString() : null;
          currentChatMessages.value = [];
          return;
        }
      }

      errorMessage.value = errorMessageStr;
      // Fallback to empty list on error
      currentChatMessages.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  ChatMessage _mapToChatMessage(
    Map<String, dynamic> data,
    String currentUserId,
  ) {
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
    final _sid = senderId.trim().toLowerCase();
    final _cid = currentUserId.trim().toLowerCase();
    final isFromCurrentUser = _sid.isNotEmpty && _sid == _cid;

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

    // v19.1.3 — soft-deleted flag from backend (body + attachments are already
    // redacted server-side, we just flip the UI bit).
    final isDeleted = data['isDeleted'] == true ||
        data['deletedAt'] != null;

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
    );
  }

  /// v19.1.3 — Delete one of my own messages. Optimistic: flip local state to
  /// deleted immediately, then call backend; revert on error.
  /// v20.0.19 — removed the `!isFromCurrentUser` early return. The backend
  /// already enforces "only sender can delete" with a 403. If the UI marked
  /// isFromCurrentUser=false by mistake (senderId/userId string mismatch),
  /// the old code silently blocked the delete → Daniel saw "effacer marche
  /// pas". Now we always try; backend 403/404/500 surfaces a real error.
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

  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty && selectedAttachments.isEmpty) {
      return;
    }
    if (currentChatId.value.isEmpty) {
      return;
    }

    final messageText = messageController.text.trim();
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // Get user info from storage
    final userProfile = _storage.read<Map<String, dynamic>>(
      StorageKeys.userProfile,
    );
    final userId = userProfile?['id']?.toString() ?? '';
    final userName = userProfile?['name']?.toString() ?? 'You';

    // Extract user image - handle both string URLs and objects with url field
    String userImage = '';
    if (userProfile?['avatar'] != null) {
      if (userProfile!['avatar'] is String) {
        userImage = userProfile['avatar'] as String;
      } else if (userProfile['avatar'] is Map &&
          userProfile['avatar']['url'] != null) {
        userImage = userProfile['avatar']['url'] as String;
      }
    }

    // Create optimistic message
    final optimisticMessage = ChatMessage(
      id: tempId,
      senderId: userId,
      senderName: userName,
      senderImage: userImage,
      message: messageText.isNotEmpty ? messageText : '📎 Attachment',
      timestamp: DateTime.now(),
      isFromCurrentUser: true,
    );

    // Add optimistic message immediately
    currentChatMessages.add(optimisticMessage);
    final attachmentsToSend = List<File>.from(selectedAttachments);
    messageController.clear();
    selectedAttachments.clear();
    _updateLastMessage(messageText.isNotEmpty ? messageText : '📎 Attachment');

    try {
      // Get user role
      final role = _storage.read<String>(StorageKeys.userRole) ?? 'owner';

      // Send message with attachments if any, otherwise send text message
      Map<String, dynamic> response;
      if (attachmentsToSend.isNotEmpty) {
        response = await _chatRepository.sendMessageWithAttachments(
          conversationId: currentChatId.value,
          senderRole: role,
          senderId: userId,
          files: attachmentsToSend,
          body: messageText.isNotEmpty ? messageText : null,
        );
      } else {
        response = await _chatRepository.sendMessage(
          conversationId: currentChatId.value,
          body: messageText,
          senderRole: role,
          senderId: userId,
        );
      }

      // Replace optimistic message with actual message from API
      // Preserve sender name and image from optimistic message if API doesn't provide them
      final actualMessage = _mapToChatMessage(response, userId);

      // If API response doesn't have sender info, preserve from optimistic message
      final finalMessage = ChatMessage(
        id: actualMessage.id,
        senderId: actualMessage.senderId,
        senderName:
            actualMessage.senderName == 'You' ||
                actualMessage.senderName == 'Unknown'
            ? optimisticMessage.senderName
            : actualMessage.senderName,
        senderImage: actualMessage.senderImage.isEmpty
            ? optimisticMessage.senderImage
            : actualMessage.senderImage,
        message: actualMessage.message,
        timestamp: actualMessage.timestamp,
        isFromCurrentUser: actualMessage.isFromCurrentUser,
        attachments: actualMessage.attachments,
      );

      final index = currentChatMessages.indexWhere((msg) => msg.id == tempId);
      if (index != -1) {
        currentChatMessages[index] = finalMessage;
      } else {
        // If not found, add it (shouldn't happen, but just in case)
        currentChatMessages.add(finalMessage);
      }

      // Socket will handle real-time updates for other users
      // The message is already sent via API, socket will broadcast to other participants
    } catch (e) {
      AppLogger.logError('Error sending message', error: e);
      // Remove optimistic message on error
      currentChatMessages.removeWhere((msg) => msg.id == tempId);
      if (_isChatLockedAfterPaymentError(e)) {
        isChatLocked.value = true;
        messageController.clear();
        selectedAttachments.clear();
        CustomSnackbar.showWarning(
          title: 'chat_locked_title',
          message: 'chat_locked_after_payment',
        );
        return;
      }
      // Restore message text and attachments
      messageController.text = messageText;
      selectedAttachments.value = attachmentsToSend;
      // Show error to user
      errorMessage.value = 'Failed to send message. Please try again.';
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
      conversations[conversationIndex] = ChatConversation(
        id: conversations[conversationIndex].id,
        contactName: conversations[conversationIndex].contactName,
        contactImage: conversations[conversationIndex].contactImage,
        lastMessage: 'You: $message',
        lastMessageTime: DateTime.now(),
        isOnline: conversations[conversationIndex].isOnline,
        unreadCount: conversations[conversationIndex].unreadCount,
      );
    }
  }

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
