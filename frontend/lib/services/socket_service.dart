import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Service for managing Socket.IO connections for real-time messaging.
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
  void joinConversation(String conversationId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_conversation', conversationId);
      AppLogger.logInfo('Joined conversation: $conversationId');
    }
  }

  /// Leaves a conversation room.
  void leaveConversation(String conversationId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_conversation', conversationId);
      AppLogger.logInfo('Left conversation: $conversationId');
    }
  }

  /// Listens for new messages in a conversation.
  void onNewMessage(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.on('new_message', (data) {
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
  void onMessageSent(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.on('message_sent', (data) {
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
