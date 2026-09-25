// v584 — lot C du chantier du 24/09 : la FEUILLE GLISSANTE de la PawMap.
//
// Plan validé par Daniel (« JE GARDE TOUT ») : « feuille glissante à 3
// positions + UN bouton principal contextuel ». Le panneau blanc du haut (qui
// mangeait la moitié de la carte) devient une feuille posée en BAS, au-dessus
// du menu, avec trois positions : basse (poignée + le bouton principal),
// moyenne (« Je cherche », compteur, filtres) et haute (tout : actions,
// calques, abonnements). Rien n'est retiré : tout ce que le panneau portait
// vit dans la feuille.
//
//   · [PawMapSheet]            — la feuille (DraggableScrollableSheet, 3 crans)
//   · [PawMapLookingSelector]  — idée 6 : UN sélecteur « Je cherche »
//   · [PawMapEmptyCard]        — idée 1 : carte vide = une action
//   · [PawMapDockRow]          — les 5 actions du dock (SOS, partager, calques,
//     nuit, historique), réutilisées dans la feuille ET sur la grande carte
//   · [PawMapCoach]            — idée 7 : UNE découverte guidée, 3 bulles max
// Widgets purs : l'écran fournit les rappels.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/pawmap_theme.dart';
import 'paw_rail_button.dart';
import 'pawmap_buttons.dart';
import 'pawmap_pins.dart';

/// Les trois crans de la feuille, en fraction de la hauteur disponible.
enum PawSheetStop { low, mid, high }

/// v585 (25/09/2026) — CAUSE EXACTE du bug 1 de Daniel (« la feuille ne
/// glisse pas vers le haut », 3 rôles, Samsung) — mesurée sur l'émulateur
/// avec de vrais `adb shell input swipe` : la feuille montait de quelques
/// dizaines de dp puis, 100 ms plus tard, retombait EXACTEMENT à sa position
/// basse. `DraggableScrollableSheet.didUpdateWidget` appelle `_replaceExtent`
/// qui, en mode `snap`, lance `goBallistic(0)` à la frame suivante : ce
/// « retour au cran le plus proche » ANNULE le glissement en cours. Or la
/// PawMap se reconstruit sans arrêt (le passage sous le seuil « bas » pendant
/// le geste lui-même, marqueurs, positions d'amis, sockets…) : chaque
/// reconstruction pendant le geste renvoyait la feuille en bas. Plus le
/// téléphone reçoit de données (le compte réel de Daniel), plus c'est
/// systématique.
///
/// Correctif : la `DraggableScrollableSheet` est construite UNE fois et
/// réutilisée à l'identique (Flutter ne rappelle pas `didUpdateWidget` pour
/// un widget identique) tant que ses crans ne changent pas ; le CONTENU,
/// lui, suit par un `ValueListenableBuilder`.
class PawMapSheet extends StatefulWidget {
  const PawMapSheet({
    super.key,
    required this.controller,
    required this.header,
    required this.children,
    required this.availableHeight,
    this.peekHeight = 118,
    this.midFraction = 0.46,
    this.highFraction = 0.90,
  });

  final DraggableScrollableController controller;

  /// Zone toujours visible en position basse : le bouton principal.
  final Widget header;
  final List<Widget> children;

  /// Hauteur (px) dans laquelle la feuille vit (écran moins le menu).
  final double availableHeight;
  final double peekHeight;
  final double midFraction;
  final double highFraction;

  double get lowFraction =>
      (peekHeight / availableHeight).clamp(0.08, 0.5).toDouble();

  /// Position (fraction) d'un cran.
  double fractionOf(PawSheetStop stop) => switch (stop) {
        PawSheetStop.low => lowFraction,
        PawSheetStop.mid => midFraction,
        PawSheetStop.high => highFraction,
      };

  @override
  State<PawMapSheet> createState() => _PawMapSheetState();
}

class _PawMapSheetState extends State<PawMapSheet> {
  late final ValueNotifier<PawMapSheet> _content =
      ValueNotifier<PawMapSheet>(widget);
  DraggableScrollableSheet? _sheet;
  String _cfg = '';

  @override
  void didUpdateWidget(covariant PawMapSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _content.value = widget;
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  String _configKey() {
    String r(double v) => v.toStringAsFixed(3);
    return '${identityHashCode(widget.controller)}:${r(widget.lowFraction)}:'
        '${r(widget.midFraction)}:${r(widget.highFraction)}';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _configKey();
    if (_sheet == null || cfg != _cfg) {
      _cfg = cfg;
      final low = widget.lowFraction;
      _sheet = DraggableScrollableSheet(
        controller: widget.controller,
        initialChildSize: low,
        minChildSize: low,
        maxChildSize: widget.highFraction,
        // v585 — crans gérés ici (voir [_settle]) : avec `snap` de Flutter,
        // un glissement lâché sans élan (fréquent au doigt, et c'est ce que
        // produit `adb input swipe`) revenait au cran le plus PROCHE, donc en
        // bas dès qu'on n'avait pas dépassé la moitié du chemin.
        snap: false,
        builder: (ctx, scroll) => ValueListenableBuilder<PawMapSheet>(
          valueListenable: _content,
          builder: (ctx, w, _) => _body(ctx, scroll, w),
        ),
      );
    }
    return Listener(
      onPointerDown: (_) {
        _pointers++;
        if (widget.controller.isAttached) _startSize = widget.controller.size;
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: _sheet!,
    );
  }

  int _pointers = 0;
  double _startSize = 0;

  void _release() {
    _pointers = (_pointers - 1).clamp(0, 10);
    if (_pointers > 0) return;
    // Après l'élan éventuel (une frame), on se pose sur un cran.
    Future<void>.delayed(const Duration(milliseconds: 60), _settle);
  }

  /// Cran visé : dans le SENS du geste — on a monté (même un peu, > 2 %) →
  /// le cran suivant au-dessus du point de départ ; descendu → celui du
  /// dessous. Un simple tap ne bouge rien.
  void _settle() {
    final c = widget.controller;
    if (!mounted || !c.isAttached || _pointers > 0) return;
    final stops = pawMapSheetStops(
        widget.lowFraction, widget.midFraction, widget.highFraction);
    final target = pawMapSheetSettle(
        start: _startSize, now: c.size, stops: stops);
    if (target == null || (target - c.size).abs() < 0.005) return;
    c.animateTo(target,
        duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
  }

  Widget _body(BuildContext ctx, ScrollController scroll, PawMapSheet w) {
    return Container(
      decoration: BoxDecoration(
        color: PawMapTheme.panelOn(ctx),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
        border: Border.all(color: PawMapTheme.borderOn(ctx)),
        boxShadow: [
          BoxShadow(
            color: PawMapTheme.ink.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 24.h),
        children: [
          // Poignée (orange, jamais grise) — elle SEULE pilote le glissement
          // sur la zone basse ; la liste défile ensuite.
          Center(
            child: Container(
              key: const ValueKey<String>('pawmap_sheet_grip'),
              width: 44.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: PawMapTheme.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          w.header,
          // v584 — assez d'air pour qu'en position basse RIEN ne dépasse
          // sous le bouton principal (au simulateur, « Je cherche » pointait).
          SizedBox(height: 22.h),
          ...w.children,
        ],
      ),
    );
  }
}

/// v585 — crans triés et distincts de la feuille.
List<double> pawMapSheetStops(double low, double mid, double high) {
  final l = <double>{low, mid, high}.toList()..sort();
  return l;
}

/// v585 — où poser la feuille quand le doigt se lève (fonction pure) :
/// déplacement < 2 % → rien (tap) ; vers le haut → premier cran au-dessus du
/// DÉPART ; vers le bas → premier cran en dessous du départ.
double? pawMapSheetSettle({
  required double start,
  required double now,
  required List<double> stops,
}) {
  final d = now - start;
  if (d.abs() < 0.02) {
    // Pas de geste : on se recale seulement si l'on est entre deux crans.
    if (stops.any((x) => (x - now).abs() < 0.01)) return null;
  }
  // Un grand geste vers le haut (> 25 % de l'écran) va jusqu'en HAUT d'un
  // coup (Daniel : « ça ne glisse pas assez haut, les icônes restent
  // coupées ») ; un grand geste vers le bas redescend tout en bas.
  if (d > 0.25) return stops.last;
  if (d < -0.25) return stops.first;
  if (d > 0) {
    for (final x in stops) {
      if (x > start + 0.01) return x < now - 0.08 ? stops.firstWhere((y) => y >= now - 0.01, orElse: () => stops.last) : x;
    }
    return stops.last;
  }
  for (final x in stops.reversed) {
    if (x < start - 0.01) return x > now + 0.08 ? stops.lastWhere((y) => y <= now + 0.01, orElse: () => stops.first) : x;
  }
  return stops.first;
}

/// Idée 6 — un seul sélecteur en haut : « Je cherche : gardiens / promeneurs /
/// lieux / amis » (+ « tout »). Pilules à parts égales, jamais de défilement.
class PawMapLookingSelector extends StatelessWidget {
  const PawMapLookingSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 'all' | 'sitters' | 'walkers' | 'places' | 'friends'
  final String value;
  final ValueChanged<String> onChanged;

  static const List<(String, String, IconData, Color)> options = [
    ('sitters', 'pawmap_sheet_sitters', Icons.home_rounded, PawMapLegend.sitter),
    ('walkers', 'pawmap_sheet_walkers', Icons.directions_walk_rounded, PawMapLegend.walker),
    ('places', 'pawmap_sheet_places', Icons.place_rounded, Color(0xFF0E7490)),
    ('friends', 'pawmap_sheet_friends', Icons.favorite_rounded, PawMapLegend.friend),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = PawMapTheme.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('pawmap_sheet_looking'.tr,
            style: PawMapTheme.fontOn(context,
                size: 12.sp,
                weight: FontWeight.w800,
                color: PawMapTheme.subOn(context))),
        SizedBox(height: 6.h),
        Row(
          children: [
            for (final (id, key, icon, color) in options) ...[
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == id,
                  label: key.tr,
                  child: GestureDetector(
                    key: ValueKey<String>('looking_$id'),
                    behavior: HitTestBehavior.opaque,
                    // Re-toucher la pilule active = revenir à « tout ».
                    onTap: () => onChanged(value == id ? 'all' : id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      constraints: BoxConstraints(minHeight: 48.h),
                      padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 2.w),
                      decoration: BoxDecoration(
                        gradient: value == id ? pawRoleGradient(color) : null,
                        color: value == id
                            ? null
                            : color.withValues(alpha: isDark ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: value == id
                              ? Colors.white.withValues(alpha: 0.6)
                              : color.withValues(alpha: 0.30),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 18,
                              color: value == id
                                  ? Colors.white
                                  : AppColors.accentOn(context, color)),
                          SizedBox(height: 3.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              key.tr,
                              maxLines: 1,
                              style: PawMapTheme.font(
                                size: 10.5.sp,
                                weight: FontWeight.w800,
                                color: value == id
                                    ? Colors.white
                                    : AppColors.accentOn(context, color),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (id != options.last.$1) SizedBox(width: 6.w),
            ],
          ],
        ),
      ],
    );
  }
}

/// Idée 1 — carte vide = une action. Propriétaire : « Publie ta demande, on
/// prévient les gardiens autour de toi » ; gardien / promeneur : « Sois le
/// premier gardien du quartier ».
class PawMapEmptyCard extends StatelessWidget {
  const PawMapEmptyCard({
    super.key,
    required this.viewerRole,
    required this.onAction,
  });

  final String viewerRole;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final bool owner = viewerRole == 'owner' || viewerRole.isEmpty;
    final Color color = PawMapLegend.roleColor(viewerRole.isEmpty ? 'owner' : viewerRole);
    return Container(
      key: const ValueKey<String>('pawmap_empty_card'),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: PawMapTheme.isDark(context) ? 0.16 : 0.07),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets_rounded, size: 18.sp, color: AppColors.accentOn(context, color)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text('pawmap_empty_title'.tr,
                    style: PawMapTheme.fontOn(context,
                        size: 14.sp, weight: FontWeight.w800)),
              ),
            ],
          ),
          if (!owner) ...[
            SizedBox(height: 4.h),
            Text('pawmap_empty_provider_sub'.tr,
                style: PawMapTheme.fontOn(context,
                    size: 12.sp,
                    weight: FontWeight.w500,
                    color: PawMapTheme.subOn(context))),
          ],
          SizedBox(height: 10.h),
          PawSignatureButton(
            key: const ValueKey<String>('pawmap_empty_action'),
            label: owner ? 'pawmap_empty_owner_btn'.tr : 'pawmap_empty_provider_btn'.tr,
            icon: owner ? Icons.campaign_rounded : Icons.person_rounded,
            color: color,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

/// Les 5 actions du dock (spec v3), en pilules de verre : SOS animal (rouge
/// plein), Partager la carte, Calques, Mode nuit, Historique. Sur la grande
/// carte elles défilent en bas ; dans la feuille elles passent à la ligne.
class PawMapDockRow extends StatelessWidget {
  const PawMapDockRow({
    super.key,
    required this.nightMode,
    required this.onSos,
    required this.onShare,
    required this.onLayers,
    required this.onNight,
    required this.onHistory,
    this.onLongPress,
    this.wrap = false,
    this.leftPadding = 0,
  });

  final bool nightMode;
  final VoidCallback onSos;
  final VoidCallback onShare;
  final VoidCallback onLayers;
  final VoidCallback onNight;
  final VoidCallback onHistory;

  /// Appui long → explication (id : sos / share / layers / night / history).
  final ValueChanged<String>? onLongPress;
  final bool wrap;
  final double leftPadding;

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required String id,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool filled = false,
      Color? color,
    }) {
      color ??= PawMapTheme.inkOn(context);
      final Color tone = filled ? PawMapTheme.danger : color;
      final child = PawGlassPill(
        color: filled ? PawMapTheme.danger : tone.withValues(alpha: 0.35),
        filled: filled,
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 13.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: filled ? Colors.white : color),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 120.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: PawMapTheme.font(
                    size: 12.sp,
                    weight: FontWeight.w700,
                    color: filled ? Colors.white : color,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return Padding(
        key: ValueKey<String>('dock_$id'),
        padding: EdgeInsets.only(right: wrap ? 0 : 8.w),
        child: PawPressable(
          label: label,
          onTap: onTap,
          onLongPress: onLongPress == null ? null : () => onLongPress!(id),
          child: child,
        ),
      );
    }

    final pills = [
      pill(id: 'sos', icon: Icons.sos_rounded, label: 'pawmap_dock_sos'.tr, filled: true, onTap: onSos),
      pill(id: 'share', icon: Icons.ios_share_rounded, label: 'pawmap_dock_share_map'.tr, onTap: onShare),
      pill(id: 'layers', icon: Icons.layers_rounded, label: 'pawmap_dock_layers'.tr, onTap: onLayers),
      pill(
        id: 'night',
        icon: nightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        label: 'pawmap_dock_night'.tr,
        color: nightMode ? PawMapTheme.accent : null,
        onTap: onNight,
      ),
      pill(id: 'history', icon: Icons.timeline_rounded, label: 'pawmap_dock_history'.tr, onTap: onHistory),
    ];
    if (wrap) {
      return Wrap(spacing: 8.w, runSpacing: 8.h, children: pills);
    }
    return SizedBox(
      height: 46.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: leftPadding, right: 12.w),
        children: pills,
      ),
    );
  }
}

/// v584 (25/09, point 13) — Daniel : « les bulles reviennent à CHAQUE
/// réouverture de la carte ». Règle PURE : la découverte guidée ne se montre
/// qu'au PREMIER lancement — jamais si le compte OU l'appareil l'a déjà vue,
/// jamais au retour d'un onglet (l'écran reste monté). Elle reste
/// consultable par « ? » / « Comprendre la PawMap ».
bool shouldShowPawMapCoach({
  required int accountCount,
  required int deviceCount,
  required bool shownThisSession,
}) {
  if (shownThisSession) return false;
  return accountCount < 1 && deviceCount < 1;
}

/// Idée 7 — UNE découverte guidée : 3 bulles au premier lancement seulement.
/// Une seule bulle à la fois, « Suivant » / « Compris », et une croix
/// « Ne plus montrer » qui marche.
class PawMapCoach extends StatelessWidget {
  const PawMapCoach({
    super.key,
    required this.step,
    required this.onNext,
    required this.onDone,
  });

  /// 0 = le « ? », 1 = le rail, 2 = la feuille.
  final int step;
  final VoidCallback onNext;
  final VoidCallback onDone;

  static const int steps = 3;

  @override
  Widget build(BuildContext context) {
    final texts = ['pawmap_coach_1'.tr, 'pawmap_coach_2'.tr, 'pawmap_coach_3'.tr];
    final icons = [Icons.question_mark_rounded, Icons.view_column_rounded, Icons.swipe_up_rounded];
    final last = step >= steps - 1;
    // La bulle se pose près de sa cible : haut-droite (« ? »), gauche (rail),
    // bas (feuille).
    final Alignment align = switch (step) {
      // Sous la rangée Partager/Agrandir (≈ 110 px), à droite près du « ? ».
      0 => const Alignment(0.6, -0.5),
      1 => const Alignment(-0.2, 0.15),
      _ => const Alignment(0, 0.55),
    };
    return Positioned.fill(
      key: const ValueKey<String>('pawmap_coach'),
      child: Stack(
        children: [
          // Voile encre (jamais gris) qui laisse deviner la carte.
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: PawMapLegend.ink.withValues(alpha: 0.35)),
            ),
          ),
          Align(
            alignment: align,
            child: Container(
              width: 300.w,
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
              decoration: BoxDecoration(
                color: PawMapTheme.panelOn(context),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: PawMapLegend.gold, width: 1.5),
                boxShadow: PawMapTheme.pillShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: const BoxDecoration(
                          color: PawMapLegend.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icons[step.clamp(0, 2)],
                            color: PawMapLegend.gold, size: 20.sp),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(
                            texts[step.clamp(0, 2)],
                            style: PawMapTheme.fontOn(context,
                                size: 13.5.sp, weight: FontWeight.w700, height: 1.3),
                          ),
                        ),
                      ),
                      // Croix « Ne plus montrer » (point 13) : ferme pour de bon.
                      Semantics(
                        button: true,
                        label: 'pawmap_coach_close'.tr,
                        child: GestureDetector(
                          key: const ValueKey<String>('coach_close'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onDone,
                          child: Padding(
                            padding: EdgeInsets.all(4.w),
                            child: Icon(Icons.close_rounded,
                                size: 20.sp, color: PawMapTheme.subOn(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      for (var i = 0; i < steps; i++)
                        Container(
                          width: i == step ? 18.w : 7.w,
                          height: 7.w,
                          margin: EdgeInsets.only(right: 4.w),
                          decoration: BoxDecoration(
                            color: i == step
                                ? PawMapLegend.gold
                                : PawMapTheme.accent.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      const Spacer(),
                      PawSignatureButton(
                        key: const ValueKey<String>('coach_next'),
                        kind: PawButtonKind.primary,
                        label: last ? 'pawmap_coach_done'.tr : 'pawmap_coach_next'.tr,
                        icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                        color: PawMapTheme.accent,
                        expand: false,
                        onTap: last ? onDone : onNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
