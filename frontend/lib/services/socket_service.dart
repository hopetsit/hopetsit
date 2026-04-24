import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';

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

  /// Gets the current socket instance.
  io.Socket? get socket => _socket;

  /// Checks if socket is connected.
  bool get isConnected => _isConnected;

  /// Connects to the Socket.IO server.
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      AppLogger.logInfo('Socket already connected');
      return;
    }

    try {
      final token = _storage.read<String>(StorageKeys.authToken);
      if (token == null || token.isEmpty) {
        // Import AuthController to handle login required error
        // Note: We can't import controllers in services, so we'll handle this at the call site
        throw Exception('Auth token not found. Please login again.');
      }

      // Get socket URL from API config
      // Sprint 8 step 9 — Socket.IO mounts at the backend root, not under /api/v1.
      final socketUrl = ApiConfig.rootUrl;

      AppLogger.logInfo('Connecting to socket: $socketUrl');

      _socket = io.io(
        socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(5)
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
  void onNewMessage(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.on('message:new', (data) {
        try {
          final messageData = data as Map<String, dynamic>;
          AppLogger.logInfo('Received new message: $messageData');
          callback(messageData);
        } catch (e) {
          AppLogger.logError('Error handling new message', error: e);
        }
      });
    }
  }

  /// Listens for message sent confirmation.
  ///
  /// v20.0.19 — backend does NOT emit a dedicated `message:sent` event;
  /// the sender receives the same `message:new` payload via the
  /// emitToConversation fan-out. We therefore subscribe to `message:new`
  /// here too and let the caller de-duplicate by message id.
  void onMessageSent(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.on('message:new', (data) {
        try {
          final messageData = data as Map<String, dynamic>;
          AppLogger.logInfo('Message sent confirmation: $messageData');
          callback(messageData);
        } catch (e) {
          AppLogger.logError('Error handling message sent', error: e);
        }
      });
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
