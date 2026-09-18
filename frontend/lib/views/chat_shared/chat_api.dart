// v565 — appels réseau du chat ajoutés par le build 565 (contrat §5).
//
// Le ChatRepository historique n'appartient pas au lot app-chat ; les
// nouvelles routes/champs (drapeaux, replyTo, vocal, envoi média corrigé)
// vivent donc ici, en s'appuyant sur ApiClient pour le JSON et sur `http`
// pour le multipart (le postMultipart historique impose un timeout de 30 s,
// trop court pour un upload Cloudinary via Render : c'est l'une des causes
// des envois de photos/vidéos qui échouaient).
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_config.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';

class ChatApi {
  ChatApi._();

  /// Taille max acceptée par le serveur (multer 15 Mo par fichier).
  static const int maxFileBytes = 15 * 1024 * 1024;

  /// Durée max d'un upload (photos/vidéos/vocal) — Render + Cloudinary.
  static const Duration uploadTimeout = Duration(seconds: 150);

  static ApiClient get _api => Get.find<ApiClient>();

  /// `GET /app-config/chat-features` → { media, voice, reply }.
  static Future<ChatFeatureFlags> fetchFeatures() async {
    try {
      final r = await _api.get('/app-config/chat-features', requiresAuth: true);
      return ChatFeatureFlags.fromJson(r);
    } catch (e) {
      AppLogger.logError('chat-features unavailable, defaults on', error: e);
      return const ChatFeatureFlags();
    }
  }

  /// `POST /conversations/:id/messages` avec `replyTo: { messageId }`.
  static Future<Map<String, dynamic>> sendText({
    required String conversationId,
    required String body,
    required String senderRole,
    required String senderId,
    String? replyToMessageId,
  }) async {
    final r = await _api.post(
      '/conversations/$conversationId/messages',
      body: {
        'body': body,
        'senderRole': senderRole,
        'senderId': senderId,
        if (replyToMessageId != null && replyToMessageId.isNotEmpty)
          'replyTo': {'messageId': replyToMessageId},
      },
      requiresAuth: true,
    );
    return _unwrapMessage(r);
  }

  /// `POST /conversations/:id/messages/attachments` (multipart, champ
  /// `files`). `kind` = 'media' (photo/vidéo, défaut) ou 'voice' (+ duration).
  static Future<Map<String, dynamic>> sendAttachment({
    required String conversationId,
    required File file,
    required String senderRole,
    required String senderId,
    String kind = 'media',
    int? durationSeconds,
    String? body,
    String? replyToMessageId,
  }) async {
    final token = SecureTokenStore.currentToken();
    if (token == null || token.isEmpty) {
      throw ApiException('Auth token not found. Please login again.',
          statusCode: 401);
    }
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/conversations/$conversationId/messages/attachments',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    final mime = _mimeFor(file.path, kind);
    request.files.add(await http.MultipartFile.fromPath(
      'files',
      file.path,
      contentType: MediaType.parse(mime),
    ));
    request.fields['senderRole'] = senderRole;
    request.fields['senderId'] = senderId;
    request.fields['kind'] = kind;
    if (durationSeconds != null) {
      request.fields['duration'] = durationSeconds.toString();
    }
    if (body != null && body.trim().isNotEmpty) {
      request.fields['body'] = body.trim();
    }
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      request.fields['replyTo'] = jsonEncode({'messageId': replyToMessageId});
    }

    AppLogger.logInfo(
      '[chat] upload $kind ${file.path.split('/').last} ($mime) → $uri',
    );
    http.Response response;
    try {
      final streamed = await request.send().timeout(uploadTimeout);
      response = await http.Response.fromStream(streamed);
    } on SocketException catch (e) {
      throw NetworkUnreachableException('No internet connection', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkUnreachableException('Network request failed: ${e.message}',
          cause: e);
    }
    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessage(decoded, response.statusCode),
        statusCode: response.statusCode,
        details: decoded,
      );
    }
    return _unwrapMessage(decoded);
  }

  /// Traduction d'un message (route racine `/translate`).
  static Future<String?> translate({
    required String text,
    required String targetLang,
  }) async {
    final r = await _api.post(
      '/translate',
      body: {'text': text, 'targetLang': targetLang},
      requiresAuth: true,
    );
    if (r is Map) {
      if (r['warning'] == 'translation_unavailable') return null;
      final t = r['translation'];
      if (t is String && t.trim().isNotEmpty) return t;
    }
    return null;
  }

  static String _mimeFor(String path, String kind) {
    final guessed = lookupMimeType(path);
    if (kind == 'voice') {
      if (guessed != null && guessed.startsWith('audio/')) return guessed;
      return path.toLowerCase().endsWith('.aac') ? 'audio/aac' : 'audio/mp4';
    }
    if (guessed != null) return guessed;
    final p = path.toLowerCase();
    if (p.endsWith('.mov')) return 'video/quicktime';
    if (p.endsWith('.mp4') || p.endsWith('.m4v')) return 'video/mp4';
    if (p.endsWith('.heic')) return 'image/heic';
    if (p.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }

  static dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _errorMessage(dynamic data, int status) {
    if (data is Map) {
      for (final k in const ['error', 'message', 'msg']) {
        final v = data[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
    }
    return 'Request failed ($status)';
  }

  static Map<String, dynamic> _unwrapMessage(dynamic r) {
    if (r is Map) {
      final m = Map<String, dynamic>.from(r);
      if (m['message'] is Map) return Map<String, dynamic>.from(m['message']);
      if (m['sentMessage'] is Map) {
        return Map<String, dynamic>.from(m['sentMessage']);
      }
      return m;
    }
    throw ApiException('Unexpected response when sending message.',
        details: r);
  }

  /// Code d'erreur métier (`{ code: 'FEATURE_DISABLED' }`, `CONTACTS_LOCKED`…).
  static String? errorCode(Object error) {
    if (error is! ApiException) return null;
    final d = error.details;
    if (d is Map) {
      final c = d['code'];
      if (c != null) return c.toString();
    }
    return null;
  }

  static bool isFeatureDisabled(Object e) =>
      e is ApiException &&
      e.statusCode == 403 &&
      errorCode(e) == 'FEATURE_DISABLED';

  static bool isContactsLocked(Object e) =>
      e is ApiException &&
      e.statusCode == 402 &&
      errorCode(e) == 'CONTACTS_LOCKED';
}
