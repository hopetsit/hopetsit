import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_endpoints.dart';
import 'package:hopetsit/data/network/api_exception.dart';

/// Repository coordinating data access for chat/conversation resources.
class ChatRepository {
  ChatRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches the list of conversations for the current user.
  Future<List<Map<String, dynamic>>> getChatList() async {
    final response =
        await _apiClient.get(ApiEndpoints.conversationsList, requiresAuth: true)
            as dynamic;

    if (response == null) {
      return [];
    }

    if (response is List) {
      return response.map((item) => item as Map<String, dynamic>).toList();
    }

    if (response is Map<String, dynamic>) {
      // Handle case where API returns { conversations: [...] }
      if (response.containsKey('conversations') &&
          response['conversations'] is List) {
        return (response['conversations'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
      // Handle case where API returns { data: [...] }
      if (response.containsKey('data') && response['data'] is List) {
        return (response['data'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
      }
    }

    throw ApiException(
      'Unexpected response type when fetching chat list.',
      details: response,
    );
  }

  /// Fetches messages for a specific conversation.
  ///
  /// [conversationId] - The ID of the conversation
  /// [role] - The role of the user (e.g., 'owner', 'sitter')
  /// [userId] - The ID of the current user
  Future<List<Map<String, dynamic>>> getConversationMessages({
    required String conversationId,
    required String role,
    required String userId,
  }) async {
    final endpoint =
        '${ApiEndpoints.conversationMessages}/$conversationId/messages';
    final response =
        await _apiClient.get(
              endpoint,
              queryParameters: {'role': role, 'userId': userId},
              requiresAuth: true,
            )
            as dynamic;

    debugPrint('API Response type: ${response.runtimeType}');
    debugPrint('API Response: $response');

    if (response == null) {
      debugPrint('Response is null, returning empty list');
      return [];
    }

    if (response is Map<String, dynamic>) {
      // Handle case where API returns { messages: [...] }
      if (response.containsKey('messages') && response['messages'] is List) {
        final messages = (response['messages'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        debugPrint('Found ${messages.length} messages in response');
        return messages;
      }
      // Handle case where API returns { data: [...] }
      if (response.containsKey('data') && response['data'] is List) {
        final messages = (response['data'] as List)
            .map((item) => item as Map<String, dynamic>)
            .toList();
        debugPrint('Found ${messages.length} messages in data field');
        return messages;
      }
      debugPrint(
        'Response is Map but no messages/data field found. Keys: ${response.keys}',
      );
    }

    // If response is directly a list
    if (response is List) {
      final messages = response
          .map((item) => item as Map<String, dynamic>)
          .toList();
      debugPrint('Response is direct list with ${messages.length} items');
      return messages;
    }

    throw ApiException(
      'Unexpected response type when fetching conversation messages.',
      details: response,
    );
  }

  /// Sends a message in a conversation.
  /// POST /conversations/{conversationId}/messages
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String body,
    required String senderRole,
    required String senderId,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final endpoint = '${ApiEndpoints.sendMessage}/$conversationId/messages';
    final response =
        await _apiClient.post(
              endpoint,
              body: {
                'body': body,
                'senderRole': senderRole,
                'senderId': senderId,
                if (attachments != null && attachments.isNotEmpty)
                  'attachments': attachments,
              },
              requiresAuth: true,
            )
            as dynamic;

    if (response == null) {
      throw ApiException('Empty response when sending message.');
    }

    if (response is Map<String, dynamic>) {
      // Handle case where API returns { message: {...} }
      if (response.containsKey('message')) {
        return response['message'] as Map<String, dynamic>;
      }
      // Handle case where API returns { sentMessage: {...} }
      if (response.containsKey('sentMessage')) {
        return response['sentMessage'] as Map<String, dynamic>;
      }
      // Return response directly if it's already the message object
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected response type when sending message.',
      details: response,
    );
  }

  /// Sitter-only: share profile phone number as a special phone_share message.
  /// Backend gates by paymentStatus === 'paid'. Sprint 3 step 6.
  Future<Map<String, dynamic>> sharePhone({required String conversationId}) async {
    final endpoint = '${ApiEndpoints.sendMessage}/$conversationId/share-phone';
    final response = await _apiClient.post(
      endpoint,
      body: const <String, dynamic>{},
      requiresAuth: true,
    );
    if (response is Map<String, dynamic>) {
      return response['message'] is Map<String, dynamic>
          ? response['message'] as Map<String, dynamic>
          : response;
    }
    throw ApiException('Unexpected response when sharing phone.', details: response);
  }

  /// Sends a message with attachments (images/videos) in a conversation.
  /// POST /conversations/{conversationId}/messages/attachments
  Future<Map<String, dynamic>> sendMessageWithAttachments({
    required String conversationId,
    required String senderRole,
    required String senderId,
    required List<File> files,
    String? body,
    String? folder,
  }) async {
    final endpoint =
        '${ApiEndpoints.sendMessageWithAttachments}/$conversationId/messages/attachments';

    // Prepare fields for multipart request
    final fields = <String, String>{
      'senderRole': senderRole,
      'senderId': senderId,
      if (body != null && body.isNotEmpty) 'body': body,
      if (folder != null && folder.isNotEmpty) 'folder': folder,
    };

    final response =
        await _apiClient.postMultipart(
              endpoint,
              files: files,
              fileFieldName: 'files',
              fields: fields,
              requiresAuth: true,
            )
            as dynamic;

    if (response == null) {
      throw ApiException(
        'Empty response when sending message with attachments.',
      );
    }

    if (response is Map<String, dynamic>) {
      // Handle case where API returns { message: {...} }
      if (response.containsKey('message')) {
        final messageData = response['message'] as Map<String, dynamic>;
        debugPrint('Message with attachments response: $messageData');
        debugPrint('Attachments in response: ${messageData['attachments']}');
        return messageData;
      }
      // Handle case where API returns { sentMessage: {...} }
      if (response.containsKey('sentMessage')) {
        final messageData = response['sentMessage'] as Map<String, dynamic>;
        debugPrint('SentMessage with attachments response: $messageData');
        debugPrint('Attachments in response: ${messageData['attachments']}');
        return messageData;
      }
      // Return response directly if it's already the message object
      debugPrint('Direct message response: $response');
      debugPrint('Attachments in direct response: ${response['attachments']}');
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw ApiException(
      'Unexpected response type when sending message with attachments.',
      details: response,
    );
  }
}
