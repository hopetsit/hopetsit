import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/app_text.dart';

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

  // v18.9.4 — debounce pour bloquer la duplication de popups quand l'user
  // tape 5 fois sur un bouton qui rate. Avant, 5 taps = 5 snackbars
  // empilés. On garde le dernier couple (title|message) affiché et on
  // refuse un duplicata dans la fenêtre. `_lastShowAt` empêche aussi le
  // spam même avec un couple différent (rate-limit 600ms global).
  static String? _lastKey;
  static DateTime? _lastShowAt;

  static bool _shouldSuppress(String title, String message) {
    final now = DateTime.now();
    final key = '$title|$message';
    if (_lastShowAt != null) {
      final delta = now.difference(_lastShowAt!).inMilliseconds;
      if (delta < 600) {
        return true;
      }
      if (key == _lastKey && delta < 3000) {
        return true;
      }
    }
    _lastKey = key;
    _lastShowAt = now;
    return false;
  }

  // v567 — POLISH « bannière iOS » : les 4 méthodes publiques sont inchangées
  // (~670 call sites), seul le rendu change. On n'utilise plus
  // awesome_snackbar_content (gros bloc vert foncé à blobs qui se superposait
  // à la bannière système Android) mais une carte flottante posée dans
  // l'Overlay racine : SafeArea, fond blanc (ou #1D1D1F en sombre), coins 18,
  // pastille de couleur, barre de progression, glisser vers le haut pour
  // fermer, haptique. Aucun BuildContext requis (les appels viennent surtout
  // de contrôleurs) et tout est encapsulé dans un try/catch silencieux.
  // La machinerie historique (_t, _shouldSuppress) est préservée telle quelle.

  static void showError({required String title, required String message}) {
    if (_shouldSuppress(title, message)) return;
    _AppBanner.show(
      title: _t(title),
      message: _t(message),
      kind: _BannerKind.error,
    );
  }

  static void showSuccess({required String title, required String message}) {
    if (_shouldSuppress(title, message)) return;
    _AppBanner.show(
      title: _t(title),
      message: _t(message),
      kind: _BannerKind.success,
    );
  }

  static void showWarning({required String title, required String message}) {
    if (_shouldSuppress(title, message)) return;
    _AppBanner.show(
      title: _t(title),
      message: _t(message),
      kind: _BannerKind.warning,
    );
  }

  /// v22.5 — info toast (blue ⓘ). Used for hints like multi-role detected.
  static void showInfo({required String title, required String message}) {
    if (_shouldSuppress(title, message)) return;
    _AppBanner.show(
      title: _t(title),
      message: _t(message),
      kind: _BannerKind.info,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Bannière flottante style iOS — implémentation privée.
// ─────────────────────────────────────────────────────────────────────────

enum _BannerKind { success, error, warning, info }

class _BannerStyle {
  final Color accent;
  final IconData icon;
  final Duration life;
  const _BannerStyle(this.accent, this.icon, this.life);
}

const Map<_BannerKind, _BannerStyle> _kBannerStyles = <_BannerKind, _BannerStyle>{
  _BannerKind.success: _BannerStyle(
    Color(0xFF16A34A),
    Icons.check_rounded,
    Duration(seconds: 3),
  ),
  _BannerKind.error: _BannerStyle(
    Color(0xFFDC2626),
    Icons.close_rounded,
    Duration(seconds: 4),
  ),
  _BannerKind.warning: _BannerStyle(
    Color(0xFFE8920A),
    Icons.priority_high_rounded,
    Duration(seconds: 4),
  ),
  _BannerKind.info: _BannerStyle(
    Color(0xFF2563EB),
    Icons.info_outline_rounded,
    Duration(seconds: 3),
  ),
};

/// Gestionnaire d'Overlay : une seule bannière à l'écran, jamais d'empilement.
class _AppBanner {
  _AppBanner._();

  static OverlayEntry? _entry;

  static void show({
    required String title,
    required String message,
    required _BannerKind kind,
  }) {
    // Post-frame : l'overlay GetX n'est pas prêt pendant initState / build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Ferme une éventuelle snackbar GetX historique (autres widgets).
        if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
      } catch (_) {
        // Silencieux : jamais d'exception depuis une notification.
      }
      try {
        final OverlayState? overlay = _resolveOverlay();
        if (overlay == null || !overlay.mounted) return;

        _removeCurrent();

        late final OverlayEntry entry;
        entry = OverlayEntry(
          builder: (_) => _BannerCard(
            title: title,
            message: message,
            kind: kind,
            onDismissed: () => _remove(entry),
          ),
        );
        _entry = entry;
        overlay.insert(entry);
        _haptic(kind);
      } catch (_) {
        // Aucun overlay monté → on n'affiche rien, sans casser l'appelant.
      }
    });
    // v567 — sans image planifiée (app au repos, appel depuis un contrôleur
    // après un await), le rappel post-frame n'arriverait qu'au prochain geste.
    try {
      WidgetsBinding.instance.ensureVisualUpdate();
    } catch (_) {}
  }

  static OverlayState? _resolveOverlay() {
    OverlayState? overlay;
    try {
      final ctx = Get.overlayContext;
      if (ctx != null) overlay = Overlay.maybeOf(ctx, rootOverlay: true);
    } catch (_) {
      overlay = null;
    }
    try {
      overlay ??= Get.key.currentState?.overlay;
    } catch (_) {
      // Navigator racine indisponible.
    }
    return overlay;
  }

  static void _removeCurrent() {
    final previous = _entry;
    _entry = null;
    if (previous != null) _detach(previous);
  }

  static void _remove(OverlayEntry entry) {
    if (identical(_entry, entry)) _entry = null;
    _detach(entry);
  }

  static void _detach(OverlayEntry entry) {
    try {
      if (entry.mounted) entry.remove();
    } catch (_) {
      // Déjà retirée.
    }
  }

  static void _haptic(_BannerKind kind) {
    try {
      final light =
          kind == _BannerKind.success || kind == _BannerKind.info;
      if (light) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Pas de moteur haptique.
    }
  }
}

class _BannerCard extends StatefulWidget {
  final String title;
  final String message;
  final _BannerKind kind;
  final VoidCallback onDismissed;

  const _BannerCard({
    required this.title,
    required this.message,
    required this.kind,
    required this.onDismissed,
  });

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard>
    with TickerProviderStateMixin {
  static const double _maxWidth = 520;
  static const double _margin = 12;

  late final _BannerStyle _style = _kBannerStyles[widget.kind]!;
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: _style.life,
  );

  double _drag = 0;
  bool _dragging = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _life.addStatusListener(_onLifeStatus);
    _enter.forward();
    _life.forward();
  }

  void _onLifeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _close();
  }

  @override
  void dispose() {
    _life.removeStatusListener(_onLifeStatus);
    _enter.dispose();
    _life.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _life.stop();
    _enter.reverse().then((_) => widget.onDismissed());
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _life.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Uniquement vers le haut (valeurs négatives).
      _drag = math.min(0, _drag + details.delta.dy);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag < -24 || velocity < -260) {
      _close();
      return;
    }
    setState(() => _drag = 0);
    if (!_closing) _life.forward();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = dark ? const Color(0xFF1D1D1F) : Colors.white;
    final Color titleColor =
        dark ? const Color(0xFFF5F5F7) : const Color(0xFF17141F);
    final Color messageColor =
        dark ? const Color(0xFF9E9EA7) : const Color(0xFF6E6E73);
    final Color borderColor =
        dark ? const Color(0x26FFFFFF) : const Color(0x14000000);

    final curved = CurvedAnimation(
      parent: _enter,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_margin, _margin, _margin, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(curved),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: AnimatedContainer(
                      duration: _dragging
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      transform: Matrix4.translationValues(0, _drag, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: dark
                                    ? const Color(0x66000000)
                                    : const Color(0x1F000000),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _body(titleColor, messageColor),
                                _progressBar(dark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(Color titleColor, Color messageColor) {
    final bool hasMessage =
        widget.message.trim().isNotEmpty && widget.message != widget.title;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _style.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(_style.icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PoppinsText(
                  text: widget.title,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  height: 1.25,
                ),
                if (hasMessage) ...[
                  const SizedBox(height: 2),
                  InterText(
                    text: widget.message,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: messageColor,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    height: 1.3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          InkResponse(
            onTap: _close,
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: messageColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(bool dark) {
    return SizedBox(
      height: 2,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _life,
        builder: (_, _) {
          final double remaining = (1 - _life.value).clamp(0.0, 1.0);
          return Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: remaining,
              child: Container(
                color: _style.accent.withValues(alpha: dark ? 0.7 : 0.55),
              ),
            ),
          );
        },
      ),
    );
  }
}
