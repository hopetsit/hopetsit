import 'dart:convert';
import 'dart:io';

import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'api_config.dart';
import 'api_exception.dart';
import '../../utils/logger.dart';
import '../../utils/storage_keys.dart';

/// Lightweight HTTP client wrapper with shared configuration.
class ApiClient {
  ApiClient({http.Client? httpClient, GetStorage? storage})
    : _httpClient = httpClient ?? http.Client(),
      _storage = storage ?? GetStorage();

  final http.Client _httpClient;
  final GetStorage _storage;

  Map<String, String> get _defaultHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Executes a GET request and returns the decoded JSON body.
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );
    _logRequest('GET', uri, resolvedHeaders);
    final response = await _httpClient
        .get(uri, headers: resolvedHeaders)
        .timeout(ApiConfig.receiveTimeout);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a POST request and returns the decoded JSON body.
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );
    _logRequest('POST', uri, resolvedHeaders, body: body);
    final response = await _httpClient
        .post(uri, headers: resolvedHeaders, body: _encodeBody(body))
        .timeout(ApiConfig.receiveTimeout);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a PUT request and returns the decoded JSON body.
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );
    _logRequest('PUT', uri, resolvedHeaders, body: body);
    final response = await _httpClient
        .put(uri, headers: resolvedHeaders, body: _encodeBody(body))
        .timeout(ApiConfig.receiveTimeout);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a PATCH request and returns the decoded JSON body.
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );
    _logRequest('PATCH', uri, resolvedHeaders, body: body);
    final response = await _httpClient
        .patch(uri, headers: resolvedHeaders, body: _encodeBody(body))
        .timeout(ApiConfig.receiveTimeout);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a DELETE request and returns the decoded JSON body (if any).
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );
    _logRequest('DELETE', uri, resolvedHeaders, body: body);
    final response = await _httpClient
        .delete(uri, headers: resolvedHeaders, body: _encodeBody(body))
        .timeout(ApiConfig.receiveTimeout);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a POST request with multipart/form-data for file uploads.
  /// Supports both single file and multiple files.
  Future<dynamic> postMultipart(
    String endpoint, {
    File? file,
    List<File>? files,
    String fileFieldName = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, null);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );

    // Remove Content-Type header for multipart requests (it will be set automatically)
    final multipartHeaders = Map<String, String>.from(resolvedHeaders);
    multipartHeaders.remove('Content-Type');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(multipartHeaders);

    // Handle multiple files
    if (files != null && files.isNotEmpty) {
      for (final file in files) {
        final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
        final contentType = MediaType.parse(mimeType);
        request.files.add(
          await http.MultipartFile.fromPath(
            fileFieldName,
            file.path,
            contentType: contentType,
          ),
        );
      }
    } else if (file != null) {
      // Handle single file (backward compatibility)
      final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
      final contentType = MediaType.parse(mimeType);
      request.files.add(
        await http.MultipartFile.fromPath(
          fileFieldName,
          file.path,
          contentType: contentType,
        ),
      );
    }

    // Add additional fields if provided
    if (fields != null) {
      request.fields.addAll(fields);
    }

    _logRequest('POST (multipart)', uri, multipartHeaders);

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(ApiConfig.receiveTimeout);

    final response = await http.Response.fromStream(streamedResponse);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a POST request with multipart/form-data supporting multiple files
  /// with different field names. Accepts a map where keys are field names and
  /// values are either a single File or List<File>.
  Future<dynamic> postMultipartWithFields({
    required String endpoint,
    required Map<String, dynamic>
    fileFields, // e.g. {'avatar': File, 'photo': [File, File]}
    Map<String, String>? textFields,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );

    // Remove Content-Type header for multipart requests
    final multipartHeaders = Map<String, String>.from(resolvedHeaders);
    multipartHeaders.remove('Content-Type');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(multipartHeaders);

    // Process file fields
    for (final entry in fileFields.entries) {
      final fieldName = entry.key;
      final value = entry.value;

      if (value is File) {
        // Single file
        final mimeType = lookupMimeType(value.path) ?? 'image/jpeg';
        final contentType = MediaType.parse(mimeType);
        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            value.path,
            contentType: contentType,
          ),
        );
      } else if (value is List<File>) {
        // Multiple files with same field name
        for (final file in value) {
          final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
          final contentType = MediaType.parse(mimeType);
          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              file.path,
              contentType: contentType,
            ),
          );
        }
      }
    }

    // Add text fields if provided
    if (textFields != null) {
      request.fields.addAll(textFields);
    }

    _logRequest('POST (multipart)', uri, multipartHeaders);

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(ApiConfig.receiveTimeout);

    final response = await http.Response.fromStream(streamedResponse);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  /// Executes a PUT request with multipart/form-data for file uploads.
  Future<dynamic> putMultipart(
    String endpoint, {
    required File file,
    String fileFieldName = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = false,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final resolvedHeaders = _resolveHeaders(
      headers,
      requiresAuth: requiresAuth,
    );

    // Remove Content-Type header for multipart requests (it will be set automatically)
    final multipartHeaders = Map<String, String>.from(resolvedHeaders);
    multipartHeaders.remove('Content-Type');

    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(multipartHeaders);

    // Determine content type from file
    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';
    final contentType = MediaType.parse(mimeType);

    // Add file with explicit content type
    request.files.add(
      await http.MultipartFile.fromPath(
        fileFieldName,
        file.path,
        contentType: contentType,
      ),
    );

    // Add additional fields if provided
    if (fields != null) {
      request.fields.addAll(fields);
    }

    _logRequest('PUT (multipart)', uri, multipartHeaders);

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(ApiConfig.receiveTimeout);

    final response = await http.Response.fromStream(streamedResponse);
    _logResponse(uri, response);
    return _decodeResponse(response);
  }

  Uri _buildUri(String endpoint, Map<String, dynamic>? queryParameters) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (queryParameters == null) {
      return uri;
    }

    final sanitizedQuery = queryParameters.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    return uri.replace(queryParameters: sanitizedQuery);
  }

  Map<String, String> _mergeHeaders(Map<String, String>? headers) {
    if (headers == null) {
      return _defaultHeaders;
    }
    return {..._defaultHeaders, ...headers};
  }

  Map<String, String> _resolveHeaders(
    Map<String, String>? headers, {
    required bool requiresAuth,
  }) {
    final mergedHeaders = _mergeHeaders(headers);

    if (!requiresAuth) {
      return mergedHeaders;
    }

    final token = _storage.read<String>(StorageKeys.authToken);

    if (token == null || token.isEmpty) {
      throw ApiException(
        'Missing auth token for authenticated request.',
        details: token,
      );
    }

    return {...mergedHeaders, 'Authorization': 'Bearer $token'};
  }

  void _logRequest(
    String method,
    Uri uri,
    Map<String, String> headers, {
    Object? body,
  }) {
    final sanitizedHeaders = _sanitizeHeaders(headers);
    final sanitizedBody = _sanitizeBody(body);

    AppLogger.logRequest(
      method: method,
      url: uri.toString(),
      headers: sanitizedHeaders,
      body: _asLoggableBody(sanitizedBody),
    );
  }

  void _logResponse(Uri uri, http.Response response) {
    AppLogger.logResponse(
      statusCode: response.statusCode,
      url: uri.toString(),
      responseBody: response.body.isEmpty
          ? null
          : _tryDecodeJson(response.body),
    );
  }

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    for (final entry in headers.entries) {
      final key = entry.key;
      final lowerKey = key.toLowerCase();
      if (lowerKey == 'authorization' || lowerKey == 'cookie') {
        sanitized[key] = '***';
      } else {
        sanitized[key] = entry.value;
      }
    }
    return sanitized;
  }

  Object? _sanitizeBody(Object? body) {
    if (body == null) {
      return null;
    }

    if (body is Map) {
      return body.map((key, value) {
        final lowerKey = key.toString().toLowerCase();
        if (lowerKey.contains('password') ||
            lowerKey.contains('token') ||
            lowerKey.contains('secret')) {
          return MapEntry(key, '***');
        }
        return MapEntry(key, value);
      });
    }

    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        return _sanitizeBody(decoded);
      } catch (_) {
        return body.replaceAll(
          RegExp(r'"password"\s*:\s*"[^"]+"'),
          '"password":"***"',
        );
      }
    }

    return body;
  }

  Map<String, dynamic>? _asLoggableBody(Object? body) {
    if (body == null) {
      return null;
    }

    if (body is Map<String, dynamic>) {
      return body;
    }

    if (body is Map) {
      return body.map((key, value) => MapEntry(key.toString(), value));
    }

    return {'raw': body.toString()};
  }

  Object? _encodeBody(Object? body) {
    if (body == null) {
      return null;
    }
    if (body is String) {
      return body;
    }
    return jsonEncode(body);
  }

  dynamic _decodeResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode < 200 || statusCode >= 300) {
      final decodedBody = response.body.isEmpty
          ? null
          : _tryDecodeJson(response.body);
      throw ApiException(
        _extractErrorMessage(decodedBody, statusCode),
        statusCode: statusCode,
        details: decodedBody,
      );
    }

    if (response.body.isEmpty) {
      return null;
    }

    return _tryDecodeJson(response.body);
  }

  dynamic _tryDecodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _extractErrorMessage(dynamic data, int statusCode) {
    if (data == null) {
      return 'Request failed ($statusCode)';
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (data is Map) {
      final normalized = data.map(
        (key, value) => MapEntry(key.toString().toLowerCase(), value),
      );

      for (final key in const [
        'message',
        'error',
        'error_message',
        'detail',
        'description',
      ]) {
        final value = normalized[key];
        final message = _valueToMessage(value);
        if (message != null) {
          return message;
        }
      }
    }

    if (data is List && data.isNotEmpty) {
      final message = _valueToMessage(data.first);
      if (message != null) {
        return message;
      }
    }

    return 'Request failed ($statusCode)';
  }

  String? _valueToMessage(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    if (value is List && value.isNotEmpty) {
      return _valueToMessage(value.first);
    }
    if (value is Map &&
        value.isNotEmpty &&
        value.values.first is String &&
        (value.values.first as String).trim().isNotEmpty) {
      return value.values.first as String;
    }
    return null;
  }

  /// Dispose the underlying HTTP client when no longer needed.
  void dispose() {
    _httpClient.close();
  }
}
