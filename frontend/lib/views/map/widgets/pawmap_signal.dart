// v587 (25/09/2026, point 9) — Daniel : « les pop-ups de l'œil et du Direct
// sont gris et moches ». UN composant signature pour tous les messages courts
// de la PawMap (œil Tous / Amis seulement / Masqué, Direct activé / arrêté,
// pas de GPS, durée changée) : pastille flottante en verre blanc chaud, icône
// maison dans un disque à la couleur de l'état, texte court à l'encre chaude,
// fondu + léger rebond, 2 s. Et la confirmation d'arrêt du direct devient une
// petite feuille élégante (plus d'AlertDialog ni de snackbar gris).
// Même matière que la capsule (`pawSiteGlass`) et que le site
// (`website/src/components/StatusToast.tsx`). Zéro gris, mode sombre.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

/// État annoncé par la pastille (fixe la couleur du disque et l'icône).
enum PawSignalKind { live, liveOff, friends, all, hidden, noGps, error }

class PawSignalStyle {
  PawSignalStyle._();

  static const Color live = Color(0xFF16A34A); // vert direct
  static const Color friends = Color(0xFFF06AA0); // rose amis
  static const Color all = Color(0xFF2563EB); // bleu tous
  static const Color ink = Color(0xFF17141F); // encre « masqué »
  static const Color warn = Color(0xFFC2410C); // orange « pas de GPS »
  static const Color error = Color(0xFFC92A12);
  static const Color textInk = Color(0xFF3B2A26); // encre chaude
  static const Color textInkDark = Color(0xFFFBEFE6);

  static Color colorOf(PawSignalKind k) => switch (k) {
        PawSignalKind.live => live,
        PawSignalKind.liveOff => ink,
        PawSignalKind.friends => friends,
        PawSignalKind.all => all,
        PawSignalKind.hidden => ink,
        PawSignalKind.noGps => warn,
        PawSignalKind.error => error,
      };

  /// Petit glyphe posé sur la maison (l'état se lit même sans couleur).
  static IconData badgeOf(PawSignalKind k) => switch (k) {
        PawSignalKind.live => Icons.podcasts_rounded,
        PawSignalKind.liveOff => Icons.pause_rounded,
        PawSignalKind.friends => Icons.favorite_rounded,
        PawSignalKind.all => Icons.visibility_rounded,
        PawSignalKind.hidden => Icons.visibility_off_rounded,
        PawSignalKind.noGps => Icons.gps_off_rounded,
        PawSignalKind.error => Icons.priority_high_rounded,
      };

  /// Verre blanc chaud (clair) / verre brun chaud (sombre).
  static BoxDecoration glass(bool dark) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xF22D1F1B), Color(0xEB1E1716)]
              : const [Color(0xF5FFFBF7), Color(0xEBFFF2E8)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark ? const Color(0x38FFE4D6) : const Color(0xF2FFFFFF),
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x8C0C0604) : const Color(0x5292400E),
            blurRadius: 22,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      );
}

/// Disque à la couleur de l'état : maison blanche + petit glyphe.
class PawSignalHouse extends StatelessWidget {
  const PawSignalHouse({super.key, required this.kind, this.size = 30});

  final PawSignalKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = PawSignalStyle.colorOf(kind);
    final s = size.w;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                // Reflet chaud (jamais un mélange au blanc qui grise l'encre).
                colors: [
                  c == PawSignalStyle.ink
                      ? const Color(0xFF3B2A26)
                      : Color.lerp(c, const Color(0xFFFFE4D6), 0.18)!,
                  c,
                ],
              ),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.home_rounded, size: s * 0.56, color: Colors.white),
          ),
          Positioned(
            right: -s * 0.12,
            bottom: -s * 0.12,
            child: Container(
              width: s * 0.5,
              height: s * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: c, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Icon(PawSignalStyle.badgeOf(kind), size: s * 0.32, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

/// La pastille elle-même (sans animation) : réutilisable dans un écran.
class PawSignalPill extends StatelessWidget {
  const PawSignalPill({super.key, required this.kind, required this.text, this.onTap});

  final PawSignalKind kind;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      liveRegion: true,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(maxWidth: 340.w, minHeight: 44.h),
          padding: EdgeInsets.fromLTRB(7.w, 6.h, 16.w, 6.h),
          decoration: PawSignalStyle.glass(dark),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PawSignalHouse(kind: kind),
              SizedBox(width: 10.w),
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: dark ? PawSignalStyle.textInkDark : PawSignalStyle.textInk,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille animée : fondu + léger rebond à l'entrée, fondu à la sortie.
class PawSignalToast extends StatefulWidget {
  const PawSignalToast({
    super.key,
    required this.kind,
    required this.text,
    this.visibleFor = const Duration(seconds: 2),
    this.onDone,
    this.onTap,
  });

  final PawSignalKind kind;
  final String text;
  final Duration visibleFor;
  final VoidCallback? onDone;
  final VoidCallback? onTap;

  @override
  State<PawSignalToast> createState() => _PawSignalToastState();
}

class _PawSignalToastState extends State<PawSignalToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _t = Timer(widget.visibleFor, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
    final pop = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: pop,
        child: PawSignalPill(kind: widget.kind, text: widget.text, onTap: widget.onTap),
      ),
    );
  }
}

/// Affiche la pastille au-dessus de tout (haut de l'écran, sous l'encoche).
/// Une nouvelle pastille remplace la précédente : jamais d'empilement.
class PawSignal {
  PawSignal._();

  static OverlayEntry? _entry;

  static void show(BuildContext context, PawSignalKind kind, String text, {VoidCallback? onTap}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    HapticFeedback.selectionClick();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16.w,
        right: 16.w,
        top: MediaQuery.of(ctx).padding.top + 64.h,
        child: IgnorePointer(
          ignoring: onTap == null,
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: PawSignalToast(
                key: const ValueKey<String>('pawmap_signal_toast'),
                kind: kind,
                text: text,
                onTap: onTap,
                onDone: () {
                  if (_entry == entry) hide();
                },
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    final e = _entry;
    _entry = null;
    if (e != null && e.mounted) e.remove();
  }

  /// Pastille de l'œil (Tous / Amis seulement / Masqué).
  static void visibility(BuildContext context, String v, {VoidCallback? onTap}) {
    final kind = switch (v) {
      'friends' => PawSignalKind.friends,
      'hidden' => PawSignalKind.hidden,
      _ => PawSignalKind.all,
    };
    final key = switch (v) {
      'friends' => 'pawmap587_sig_vis_friends',
      'hidden' => 'pawmap587_sig_vis_hidden',
      _ => 'pawmap587_sig_vis_all',
    };
    show(context, kind, key.tr, onTap: onTap);
  }
}

/// « Arrêter le direct ? » — petite feuille élégante (verre chaud, bouton
/// signature vert → encre). Renvoie true si l'utilisateur confirme.
Future<bool> showPawStopLiveSheet(BuildContext context) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5217141F),
    builder: (ctx) => const PawStopLiveSheet(),
  );
  return r == true;
}

class PawStopLiveSheet extends StatelessWidget {
  const PawStopLiveSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? PawSignalStyle.textInkDark : PawSignalStyle.textInk;
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey<String>('pawmap_stop_live_sheet'),
        margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        decoration: PawSignalStyle.glass(dark).copyWith(
          borderRadius: BorderRadius.circular(28.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE8C9B8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            SizedBox(height: 14.h),
            const PawSignalHouse(kind: PawSignalKind.live, size: 48),
            SizedBox(height: 12.h),
            Text(
              'pawmap587_stop_title'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: ink),
            ),
            SizedBox(height: 6.h),
            Text(
              'pawmap587_stop_msg'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, height: 1.35, fontWeight: FontWeight.w500, color: ink.withValues(alpha: 0.82)),
            ),
            SizedBox(height: 16.h),
            _SignatureButton(
              key: const ValueKey<String>('pawmap_stop_live_confirm'),
              label: 'pawmap587_stop_btn'.tr,
              onTap: () => Navigator.of(context).pop(true),
            ),
            SizedBox(height: 4.h),
            TextButton(
              key: const ValueKey<String>('pawmap_stop_live_keep'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: ink, minimumSize: Size(double.infinity, 44.h)),
              child: Text('pawmap587_stop_keep'.tr, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton signature : pilule en dégradé encre chaude, liseré blanc, ombre ambre.
class _SignatureButton extends StatelessWidget {
  const _SignatureButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 50.h),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B2A26), Color(0xFF17141F)],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x5292400E), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop_circle_rounded, size: 18.sp, color: Colors.white),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
