import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Centralized Logging System for API Requests and Responses
class AppLogger {
  static const String _tag = '[HOPETSIT]';

  /// Log API Request
  static void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    if (kDebugMode) {
      debugPrint('$_tag ========== API REQUEST ==========');
      debugPrint('$_tag Method: $method');
      debugPrint('$_tag URL: $url');

      if (headers != null && headers.isNotEmpty) {
        debugPrint('$_tag Headers:');
        headers.forEach((key, value) {
          // Hide sensitive headers
          if (key.toLowerCase().contains('authorization')) {
            final displayValue = value.length > 20
                ? '${value.substring(0, 20)}...'
                : value;
            debugPrint('$_tag   $key: $displayValue');
          } else {
            debugPrint('$_tag   $key: $value');
          }
        });
      }

      if (body != null && body.isNotEmpty) {
        debugPrint('$_tag Body:');
        try {
          final jsonString = const JsonEncoder.withIndent('  ').convert(body);
          debugPrint('$_tag $jsonString');
        } catch (e) {
          debugPrint('$_tag $body');
        }
      }

      debugPrint('$_tag ======================================');
    }
  }

  /// Log API Response
  static void logResponse({
    required int statusCode,
    required String url,
    dynamic responseBody,
    String? error,
  }) {
    if (kDebugMode) {
      debugPrint('$_tag ========== API RESPONSE ==========');
      debugPrint('$_tag Status Code: $statusCode');
      debugPrint('$_tag URL: $url');

      if (error != null) {
        debugPrint('$_tag Error: $error');
      } else if (responseBody != null) {
        debugPrint('$_tag Response Body:');
        try {
          if (responseBody is Map || responseBody is List) {
            final jsonString = const JsonEncoder.withIndent(
              '  ',
            ).convert(responseBody);
            debugPrint('$_tag $jsonString');
          } else {
            debugPrint('$_tag $responseBody');
          }
        } catch (e) {
          debugPrint('$_tag $responseBody');
        }
      }

      debugPrint('$_tag ======================================');
    }
  }

  /// Log General Debug Information
  static void logDebug(String message, {String? tag}) {
    if (kDebugMode) {
      final logTag = tag != null ? '$_tag [$tag]' : _tag;
      debugPrint('$logTag $message');
    }
  }

  /// Log General Information
  static void logInfo(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('$_tag ========== INFO ==========');
      debugPrint('$_tag Message: $message');
      if (data != null && data.isNotEmpty) {
        debugPrint('$_tag Data:');
        try {
          final jsonString = const JsonEncoder.withIndent('  ').convert(data);
          debugPrint('$_tag $jsonString');
        } catch (e) {
          debugPrint('$_tag $data');
        }
      }
      debugPrint('$_tag ===========================');
    }
  }

  /// Log Error Information
  static void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('$_tag ========== ERROR ==========');
      debugPrint('$_tag Message: $message');
      if (error != null) {
        debugPrint('$_tag Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_tag Stack Trace: $stackTrace');
      }
      debugPrint('$_tag ===========================');
    }
  }

  /// Log Success Information
  static void logSuccess(String message, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('$_tag ========== SUCCESS ==========');
      debugPrint('$_tag Message: $message');
      if (data != null && data.isNotEmpty) {
        debugPrint('$_tag Data:');
        try {
          final jsonString = const JsonEncoder.withIndent('  ').convert(data);
          debugPrint('$_tag $jsonString');
        } catch (e) {
          debugPrint('$_tag $data');
        }
      }
      debugPrint('$_tag =============================');
    }
  }

  /// Log User Action
  static void logUserAction(String action, {Map<String, dynamic>? data}) {
    if (kDebugMode) {
      debugPrint('$_tag ========== USER ACTION ==========');
      debugPrint('$_tag Action: $action');
      if (data != null && data.isNotEmpty) {
        debugPrint('$_tag Data:');
        try {
          final jsonString = const JsonEncoder.withIndent('  ').convert(data);
          debugPrint('$_tag $jsonString');
        } catch (e) {
          debugPrint('$_tag $data');
        }
      }
      debugPrint('$_tag =================================');
    }
  }
}
