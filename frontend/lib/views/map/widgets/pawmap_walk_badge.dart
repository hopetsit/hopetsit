// v601 (PAM, 29/09) — DRAPEAU BALADE à droite, au-dessus du bouton Balade.
//
// La pilule « En balade · 120 min · N te suivent » quitte le haut à gauche :
// elle devient ce badge vert compact posé juste au-dessus du bouton Balade de
// la barre de droite, visible SEULEMENT pendant la balade (durée + suiveurs).
// Même palette que le bouton en direct (`kJewelWalkOn`). La phrase entière
// (9 langues) est lue par le lecteur d'écran et s'affiche à l'appui long.
// Le point vert discret du menu (599) reste.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/custom_snackbar_widget.dart';
import 'pawmap_jewel.dart';

/// Texte court de la durée (« 12 min », « 12分 », « 12분 »…), 9 langues.
String pawWalkBadgeMinutes(DateTime? startedAt, DateTime now) {
  final int min = startedAt == null
      ? 0
      : now.difference(startedAt).inMinutes.clamp(0, 99999).toInt();
  return 'pawmap601_walk_min'.tr.replaceAll('{n}', '$min');
}

/// Phrase complète (lecteur d'écran, appui long) :
/// « En balade · 12 min · 2 te suivent ».
String pawWalkBadgeSentence(DateTime? startedAt, DateTime now, int followers,
    {bool elsewhere = false}) {
  if (elsewhere) return 'live589_pill_elsewhere'.tr;
  final parts = <String>[
    'pawmap590_on_walk'.tr,
    pawWalkBadgeMinutes(startedAt, now),
    if (followers > 0)
      'pawmap590_followers'.tr.replaceAll('{n}', '$followers'),
  ];
  return parts.join(' · ');
}

class PawWalkBadge extends StatefulWidget {
  const PawWalkBadge({
    super.key,
    required this.startedAt,
    required this.followers,
    this.elsewhere = false,
    this.width = 44,
    this.now,
  });

  final DateTime? startedAt;
  final int followers;

  /// La balade tourne sur mon AUTRE téléphone : pas de durée locale.
  final bool elsewhere;
  final double width;

  /// Tests : heure figée.
  final DateTime Function()? now;

  @override
  State<PawWalkBadge> createState() => _PawWalkBadgeState();
}

class _PawWalkBadgeState extends State<PawWalkBadge> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // La durée avance toute seule (20 s suffit pour une minute exacte).
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _explain(String sentence) {
    CustomSnackbar.showInfo(title: 'pawmap590_on_walk'.tr, message: sentence);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = (widget.now ?? DateTime.now)();
    final String sentence = pawWalkBadgeSentence(
        widget.startedAt, now, widget.followers,
        elsewhere: widget.elsewhere);
    final TextStyle strong = GoogleFonts.poppins(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      height: 1.05,
    );
    final TextStyle small = GoogleFonts.poppins(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      height: 1.05,
    );
    return Semantics(
      label: sentence,
      liveRegion: true,
      child: GestureDetector(
        key: const ValueKey<String>('pawmap_walk_badge'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _explain(sentence),
        onLongPress: () => _explain(sentence),
        child: ExcludeSemantics(
          child: Container(
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            decoration: BoxDecoration(
              gradient: kJewelWalkOn.gradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: kJewelWalkOn.dark.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: widget.elsewhere
                      ? const Icon(Icons.smartphone_rounded,
                          size: 14, color: Colors.white)
                      : Text(pawWalkBadgeMinutes(widget.startedAt, now),
                          key: const ValueKey<String>('pawmap_walk_badge_min'),
                          maxLines: 1,
                          softWrap: false,
                          style: strong),
                ),
                if (widget.followers > 0 && !widget.elsewhere) ...[
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 2),
                        Text('${widget.followers > 99 ? '99+' : widget.followers}',
                            key: const ValueKey<String>(
                                'pawmap_walk_badge_followers'),
                            maxLines: 1,
                            softWrap: false,
                            style: small),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
