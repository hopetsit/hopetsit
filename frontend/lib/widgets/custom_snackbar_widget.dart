import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import '../utils/app_colors.dart';

class CustomSnackbar {
  static Map<String, String>? _reverseValueToKey;
  static Map<String, String>? _normalizedValueToKey;
  static const List<(String, String)> _backendKeywordRules = <(String, String)>[
    ('failed to switch role', 'auth_role_switch_failed'),
    ('switch role failed', 'auth_role_switch_failed'),
    ('unable to switch role', 'auth_role_switch_failed'),
    ('role switched', 'auth_role_switched'),
    ('switched to', 'auth_role_switched_message'),
    ('failed to send request', 'request_send_failed'),
    ('unable to send request', 'request_send_failed'),
    ('request sent successfully', 'request_send_success'),
    ('application accepted successfully', 'sitter_application_accept_success'),
    ('application rejected successfully', 'sitter_application_reject_success'),
    ('reservation request published successfully', 'publish_request_success'),
  ];

  static String _normalizeMessage(String value) {
    var out = value.trim().toLowerCase();

    // Remove common backend prefixes that wrap the actual message.
    const prefixes = <String>[
      'error:',
      'exception:',
      'api error:',
      'bad request:',
      'unauthorized:',
      'forbidden:',
      'not found:',
      'validation error:',
      'failed:',
    ];
    for (final prefix in prefixes) {
      if (out.startsWith(prefix)) {
        out = out.substring(prefix.length).trim();
        break;
      }
    }

    // Remove punctuation noise and collapse spaces for resilient matching.
    out = out.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  static Map<String, String> _buildReverseValueToKeyMap() {
    final reverse = <String, String>{};
    final all = AppTranslations().keys;
    for (final localeMap in all.values) {
      for (final entry in localeMap.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value.isEmpty) continue;
        // Keep first-seen mapping for stability when values collide.
        reverse.putIfAbsent(value, () => key);
      }
    }
    return reverse;
  }

  static Map<String, String> _buildNormalizedValueToKeyMap() {
    final normalized = <String, String>{};
    // Backend errors are generally in English, so normalize from en_US source.
    final en = AppTranslations().keys['en_US'] ?? <String, String>{};
    for (final entry in en.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value.isEmpty) continue;
      final n = _normalizeMessage(value);
      if (n.isEmpty) continue;
      normalized.putIfAbsent(n, () => key);
    }
    return normalized;
  }

  static String _t(String value) {
    if (value.isEmpty) return value;

    // Standard path: caller passed translation key.
    final fromKey = value.tr;
    if (fromKey != value) return fromKey;

    // Compatibility path: caller may have passed already-translated text.
    // Map value back to key, then translate to current locale.
    _reverseValueToKey ??= _buildReverseValueToKeyMap();
    final mappedKey = _reverseValueToKey![value];
    if (mappedKey != null) {
      return mappedKey.tr;
    }

    // Backend message compatibility: normalize and map to known keys.
    _normalizedValueToKey ??= _buildNormalizedValueToKeyMap();
    final normalized = _normalizeMessage(value);
    final normalizedKey = _normalizedValueToKey![normalized];
    if (normalizedKey != null) {
      return normalizedKey.tr;
    }

    for (final (keyword, key) in _backendKeywordRules) {
      if (normalized.contains(keyword)) {
        return key.tr;
      }
    }

    // Fallback: keep runtime/backend messages unchanged.
    return value;
  }

  /// Defers snackbar display until after the current frame so GetX overlay
  /// is ready (avoids LateInitializationError: _animation has not been initialized).
  static void _showSafe(void Function() show) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
      show();
    });
  }

  static void showError({required String title, required String message}) {
    _showSafe(() {
      Get.snackbar(
        _t(title),
        _t(message),
        backgroundColor: AppColors.primaryColor,
        colorText: AppColors.whiteColor,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        icon: const Icon(Icons.error_outline, color: AppColors.whiteColor),
      );
    });
  }

  static void showSuccess({required String title, required String message}) {
    _showSafe(() {
      Get.snackbar(
        _t(title),
        _t(message),
        backgroundColor: Colors.green,
        colorText: AppColors.whiteColor,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        icon: const Icon(
          Icons.check_circle_outline,
          color: AppColors.whiteColor,
        ),
      );
    });
  }

  static void showWarning({required String title, required String message}) {
    _showSafe(() {
      Get.snackbar(
        _t(title),
        _t(message),
        backgroundColor: Colors.orange,
        colorText: AppColors.whiteColor,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        borderRadius: 8,
        icon: const Icon(
          Icons.warning_amber_outlined,
          color: AppColors.whiteColor,
        ),
      );
    });
  }
}
