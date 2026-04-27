import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// v22.5 — POLISH 2 : modern toast notifications.
///
/// Wraps `awesome_snackbar_content` to expose a slim, top-aligned, swipe-
/// dismissible API matching modern UX (Linear / Notion / Revolut style).
///
/// 4 levels :
///   * [success] (green ✓)
///   * [error]   (red ✕)
///   * [info]    (blue ⓘ)
///   * [warning] (orange ⚠)
///
/// Usage :
///   ModernToast.success('Animal sauvegardé');
///   ModernToast.error('Erreur réseau', title: 'Échec');
///
/// Internally uses `Get.showSnackbar` so a BuildContext is not required —
/// the same call can fire from any controller. Auto-dismisses in 3s and
/// supports swipe-to-dismiss out of the box (snackbarStatus drives the
/// animation; `isDismissible: true` enables the gesture).
///
/// IMPORTANT — backward compat : the legacy `CustomSnackbar` widget is now
/// a thin shim that forwards to this class so all existing call sites keep
/// working unchanged.
class ModernToast {
  ModernToast._();

  /// Default lifetime of a toast on screen.
  static const Duration _defaultDuration = Duration(seconds: 3);

  /// Internal renderer. The 4 public methods just configure title/colour.
  static void _show({
    required String message,
    required String title,
    required ContentType type,
  }) {
    // Defer to the next frame so GetX overlay is ready (avoids
    // LateInitializationError when fired during initState / build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
      Get.showSnackbar(
        GetSnackBar(
          snackPosition: SnackPosition.TOP,
          duration: _defaultDuration,
          isDismissible: true,
          dismissDirection: DismissDirection.horizontal,
          backgroundColor: Colors.transparent,
          boxShadows: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 4),
            ),
          ],
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          // We hand-roll the body with AwesomeSnackbarContent so the toast
          // looks consistent regardless of the screen background.
          messageText: AwesomeSnackbarContent(
            title: title,
            message: message,
            contentType: type,
            inMaterialBanner: false,
          ),
          // The actual title/message slots are unused — AwesomeSnackbarContent
          // owns its own layout — but GetSnackBar requires non-null values.
          titleText: const SizedBox.shrink(),
        ),
      );
    });
  }

  /// Green ✓ toast. Use for "saved", "sent", "added" confirmations.
  static void success(String message, {String? title}) {
    _show(
      message: message,
      title: title ?? 'Succès',
      type: ContentType.success,
    );
  }

  /// Red ✕ toast. Use for non-blocking error reports.
  /// For blocking/critical failures (payment crash, session expired) prefer
  /// an AlertDialog — toasts are passive notifications.
  static void error(String message, {String? title}) {
    _show(
      message: message,
      title: title ?? 'Erreur',
      type: ContentType.failure,
    );
  }

  /// Blue ⓘ toast. Use for hints, role-switch reminders, mode changes.
  static void info(String message, {String? title}) {
    _show(
      message: message,
      title: title ?? 'Info',
      type: ContentType.help,
    );
  }

  /// Orange ⚠ toast. Use for validation warnings, soft-fails.
  static void warning(String message, {String? title}) {
    _show(
      message: message,
      title: title ?? 'Attention',
      type: ContentType.warning,
    );
  }
}
