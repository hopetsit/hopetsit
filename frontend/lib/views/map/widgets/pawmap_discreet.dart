// v586 (25/09/2026) — la PawMap « très discrète et dégagée, en gardant toutes
// les options » (plan validé par Daniel). Widgets PURS, l'écran fournit les
// rappels :
//
//   · [PawMapOptionsHandle]   — la POIGNÉE « Options » : seule chose posée en
//     bas de la carte au repos (la feuille est rangée). Pilule blanc chaud,
//     empreinte de patte à la couleur du rôle + chevron vers le haut ; appui
//     ou glissement vers le haut = la feuille COMPLÈTE.
//   · [PawCapsuleEyeButton]   — l'ŒIL de la capsule droite : Tous (œil) ·
//     Amis seulement (œil + cœur) · Masqué (œil barré).
//   · [PawCapsuleRoleAction]  — l'action du rôle sous la capsule : Publier
//     (propriétaire, mégaphone rouge) ou Direct (gardien / promeneur : noir =
//     arrêté, vert qui respire = en direct).
//   · [PawMapSeeSection]      — point 7 : « Ce que je veux voir », une
//     pastille INDÉPENDANTE par famille (couper les lieux ne cache plus
//     jamais les personnes ni les amis).
//   · [kPawCapsuleSpecs]      — les textes de ces boutons, UNE source pour
//     l'appui long et « Comprendre la PawMap ».
//   · [pawMap586LaunchCount]  — compteur des ouvertures (libellés montrés aux
//     3 premières seulement).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../utils/pawmap_theme.dart';
import '../../../widgets/paw_button_kit.dart' show pawRoleGradient;
import '../../../widgets/paw_icons.dart';
import 'pawmap_pins.dart';

/// Nombre d'ouvertures de la PawMap mémorisé sur l'appareil ; `bump` à
/// l'ouverture de l'écran. Les petits libellés (« Options », « Publier »,
/// « Direct ») s'affichent tant que ce nombre est ≤ 3.
const String kPawMap586LaunchKey = 'pawmap586_launches';

int pawMap586LaunchCount({bool bump = false}) {
  try {
    final box = GetStorage();
    var n = (box.read(kPawMap586LaunchKey) as num?)?.toInt() ?? 0;
    if (bump) {
      n += 1;
      box.write(kPawMap586LaunchKey, n);
    }
    return n;
  } catch (_) {
    return 1;
  }
}

/// Libellés visibles aux 3 premières ouvertures (fonction pure, testée).
bool pawMap586ShowLabels(int launches) => launches <= 3;

/// Une entrée d'explication (appui long, « Comprendre la PawMap »).
class PawCapsuleSpec {
  const PawCapsuleSpec({
    required this.id,
    required this.icon,
    required this.color,
    required this.labelKey,
    required this.helpKey,
  });

  final String id;
  final IconData icon;
  final Color color;
  final String labelKey;
  final String helpKey;

  String get label => labelKey.tr;
  String get help => helpKey.tr;
}

const List<PawCapsuleSpec> kPawCapsuleSpecs = <PawCapsuleSpec>[
  PawCapsuleSpec(
    id: 'handle',
    icon: Icons.pets_rounded,
    color: PawMapLegend.owner,
    labelKey: 'pawmap586_handle_label',
    helpKey: 'pawmap586_help_handle_body',
  ),
  PawCapsuleSpec(
    id: 'publish',
    icon: Icons.campaign_rounded,
    color: PawMapLegend.owner,
    labelKey: 'pawmap586_publish_short',
    helpKey: 'pawmap586_publish_help',
  ),
  PawCapsuleSpec(
    id: 'direct',
    icon: Icons.podcasts_rounded,
    color: PawMapLegend.walker,
    labelKey: 'pawmap586_direct_short',
    helpKey: 'pawmap586_direct_help',
  ),
  PawCapsuleSpec(
    id: 'eye',
    icon: Icons.visibility_rounded,
    color: PawMapLegend.ink,
    labelKey: 'pawmap586_vis_btn',
    helpKey: 'pawmap586_vis_help',
  ),
  PawCapsuleSpec(
    id: 'see',
    icon: Icons.tune_rounded,
    color: PawMapLegend.friend,
    labelKey: 'pawmap586_see_title',
    helpKey: 'pawmap586_see_hint',
  ),
  PawCapsuleSpec(
    id: 'fade',
    icon: Icons.touch_app_rounded,
    color: PawMapLegend.sitter,
    labelKey: 'pawmap586_help_capsule',
    helpKey: 'pawmap586_help_fade',
  ),
];

PawCapsuleSpec? pawCapsuleSpecOf(String id) {
  for (final s in kPawCapsuleSpecs) {
    if (s.id == id) return s;
  }
  return null;
}

// ─── Point 5 : la carte s'efface quand on la manipule ────────────────────

/// Logique PURE de l'effacement au geste (testée) : un vrai déplacement du
/// doigt (> 12 px) ou un pincement sur la carte → `faded` ; 1 s après le
/// dernier doigt levé → retour. [restore] = le premier appui ailleurs.
/// `allowed` faux (placement au viseur, suivi en direct) → jamais effacé.
class PawChromeFade {
  PawChromeFade({this.returnAfter = const Duration(seconds: 1)});

  final Duration returnAfter;
  final RxBool faded = false.obs;
  Timer? _timer;
  int _pointers = 0;
  Offset? _downAt;

  void down(Offset at, {required bool allowed}) {
    _pointers++;
    _downAt ??= at;
    _timer?.cancel();
    if (_pointers > 1 && allowed) faded.value = true;
  }

  void move(Offset at, {required bool allowed}) {
    if (faded.value || !allowed) return;
    final start = _downAt;
    if (start != null && (at - start).distance > 12) faded.value = true;
  }

  void end() {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    if (_pointers > 0) return;
    _downAt = null;
    if (!faded.value) return;
    _timer?.cancel();
    _timer = Timer(returnAfter, () {
      if (_pointers == 0) faded.value = false;
    });
  }

  void restore() {
    if (!faded.value || _pointers > 0) return;
    _timer?.cancel();
    faded.value = false;
  }

  void dispose() => _timer?.cancel();
}

/// v587 (25/09) — « le direct ne marche pas, je vois suspendu » : le suivi
/// d'un ami se mettait EN PAUSE sur `onCameraMoveStarted`, que Google Maps
/// déclenche aussi pour des mouvements qui ne sont PAS un geste (appui sur un
/// rond : la carte se recentre dessus ; changement de marge ; animation plus
/// longue que la fenêtre de 800 ms). Seul un VRAI geste compte désormais :
/// un doigt qui glisse de plus de 12 px, ou deux doigts (pincer).
class PawMapDragWatch {
  int _pointers = 0;
  Offset? _downAt;
  bool _fired = false;

  /// Vrai quand ce doigt fait du geste un vrai geste (2e doigt posé).
  bool down(Offset at) {
    _pointers++;
    _downAt ??= at;
    return _fire(_pointers > 1);
  }

  /// Vrai la 1re fois que le glissement dépasse 12 px.
  bool move(Offset at) {
    final start = _downAt;
    return _fire(start != null && (at - start).distance > 12);
  }

  void end() {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    if (_pointers == 0) {
      _downAt = null;
      _fired = false;
    }
  }

  bool _fire(bool cond) {
    if (!cond || _fired) return false;
    _fired = true;
    return true;
  }
}

// ─── Poignée « Options » ──────────────────────────────────────────────────

class PawMapOptionsHandle extends StatefulWidget {
  const PawMapOptionsHandle({
    super.key,
    required this.roleColor,
    required this.showLabel,
    required this.onOpen,
  });

  final Color roleColor;

  /// Libellé « Options » visible (3 premières ouvertures) ; sinon icône
  /// seule, et un appui long l'affiche 2 s.
  final bool showLabel;
  final VoidCallback onOpen;

  @override
  State<PawMapOptionsHandle> createState() => _PawMapOptionsHandleState();
}

class _PawMapOptionsHandleState extends State<PawMapOptionsHandle> {
  bool _peekLabel = false;
  double _drag = 0;
  bool _pressed = false;

  void _revealLabel() {
    HapticFeedback.selectionClick();
    setState(() => _peekLabel = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _peekLabel = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    final bool label = widget.showLabel || _peekLabel;
    final Color role = widget.roleColor;
    final Color surface =
        dark ? const Color(0xFF2D1F1B) : const Color(0xFFFFFBF7);
    return Semantics(
      button: true,
      label: 'pawmap586_handle_hint'.tr,
      child: Tooltip(
        message: 'pawmap586_handle_hint'.tr,
        child: GestureDetector(
          key: const ValueKey<String>('pawmap_options_handle'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            HapticFeedback.selectionClick();
            widget.onOpen();
          },
          onLongPress: _revealLabel,
          onVerticalDragStart: (_) => _drag = 0,
          onVerticalDragUpdate: (d) => _drag += d.delta.dy,
          onVerticalDragEnd: (d) {
            // Vers le haut (un peu, ou avec de l'élan) = ouvrir.
            if (_drag < -8 || (d.primaryVelocity ?? 0) < -200) {
              HapticFeedback.selectionClick();
              widget.onOpen();
            }
            _drag = 0;
          },
          // Zone tactile ≥ 48 de haut, la pilule visible en fait 32.
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 32.h,
                constraints: BoxConstraints(minWidth: label ? 120.w : 76.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: role.withValues(alpha: dark ? 0.55 : 0.35),
                      width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: role.withValues(alpha: dark ? 0.40 : 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PawIconWidget(
                      PawIcon.paw,
                      key: const ValueKey<String>('pawmap_handle_paw'),
                      size: 18.w,
                      color: role,
                      fill: role.withValues(alpha: 0.25),
                    ),
                    if (label) ...[
                      SizedBox(width: 6.w),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'pawmap586_handle_label'.tr,
                            key: const ValueKey<String>('pawmap_handle_label'),
                            maxLines: 1,
                            style: PawMapTheme.font(
                              size: 13.sp,
                              weight: FontWeight.w800,
                              color: dark
                                  ? Color.lerp(role, Colors.white, 0.45)!
                                  : Color.lerp(role, Colors.black, 0.2)!,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(width: 4.w),
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 20.sp, color: role),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Œil (visibilité) ─────────────────────────────────────────────────────

class PawCapsuleEyeButton extends StatelessWidget {
  const PawCapsuleEyeButton({
    super.key,
    required this.state,
    required this.onTap,
    this.onLongPress,
    this.size = 42,
  });

  /// 'all' | 'friends' | 'hidden'.
  final String state;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  String get _label => switch (state) {
        'friends' => 'pawmap586_vis_friends'.tr,
        'hidden' => 'pawmap586_vis_hidden'.tr,
        _ => 'pawmap586_vis_all'.tr,
      };

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    final Color ink = dark ? const Color(0xFFF5F0EF) : PawMapLegend.ink;
    final bool on = state != 'all';
    return Tooltip(
      message: _label,
      child: Semantics(
        button: true,
        label: '${'pawmap586_vis_btn'.tr} : $_label',
        child: GestureDetector(
          key: const ValueKey<String>('pawmap_eye'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          onLongPress: onLongPress,
          child: SizedBox(
            width: size.w,
            height: size.w,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: (size - 10).w,
                height: (size - 10).w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == 'hidden'
                      ? PawMapLegend.ink
                      : (state == 'friends'
                          ? PawMapLegend.friend.withValues(alpha: dark ? 0.24 : 0.14)
                          : Colors.transparent),
                  border: on
                      ? Border.all(
                          color: state == 'hidden'
                              ? PawMapLegend.gold.withValues(alpha: 0.8)
                              : PawMapLegend.friend.withValues(alpha: 0.6),
                          width: 1.2)
                      : null,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      state == 'hidden'
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      key: ValueKey<String>('pawmap_eye_$state'),
                      size: 20.sp,
                      color: state == 'hidden' ? Colors.white : ink,
                    ),
                    if (state == 'friends')
                      Positioned(
                        right: -3.w,
                        bottom: -3.w,
                        child: Container(
                          padding: EdgeInsets.all(1.5.w),
                          decoration: BoxDecoration(
                            color: dark ? const Color(0xFF2D1F1B) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.favorite_rounded,
                              size: 11.sp, color: PawMapLegend.friend),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Action du rôle : Publier / Direct ────────────────────────────────────

enum PawRoleActionKind { publish, direct }

class PawCapsuleRoleAction extends StatefulWidget {
  const PawCapsuleRoleAction({
    super.key,
    required this.kind,
    required this.live,
    required this.showLabel,
    required this.onTap,
    this.onLongPress,
  });

  final PawRoleActionKind kind;

  /// Direct seulement : vrai = partage en cours (vert qui respire).
  final bool live;
  final bool showLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const Color green = Color(0xFF16A34A);
  static const Color ink = Color(0xFF17141F);

  @override
  State<PawCapsuleRoleAction> createState() => _PawCapsuleRoleActionState();
}

class _PawCapsuleRoleActionState extends State<PawCapsuleRoleAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool get _breathing =>
      widget.kind == PawRoleActionKind.direct && widget.live;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PawCapsuleRoleAction old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_breathing) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else if (_breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool publish = widget.kind == PawRoleActionKind.publish;
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final String label = publish
        ? 'pawmap586_publish_short'.tr
        : 'pawmap586_direct_short'.tr;
    final Gradient gradient = publish
        ? pawRoleGradient(PawMapLegend.owner)
        : (widget.live
            ? const LinearGradient(
                colors: [Color(0xFF22C55E), PawCapsuleRoleAction.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF33214A), PawCapsuleRoleAction.ink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ));
    final Color glow = publish
        ? PawMapLegend.owner
        : (widget.live ? PawCapsuleRoleAction.green : PawCapsuleRoleAction.ink);
    // L'état (arrêté / en direct) passe par `toggled` ; en direct, le
    // libellé le dit aussi.
    final String semantic = publish || !widget.live
        ? label
        : '$label · ${'pawmap_status_live'.tr}';
    return Semantics(
      button: true,
      toggled: publish ? null : widget.live,
      label: semantic,
      child: GestureDetector(
        key: ValueKey<String>(publish
            ? 'pawmap_action_publish'
            : (widget.live ? 'pawmap_action_direct_on' : 'pawmap_action_direct_off')),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _breath,
                builder: (ctx, child) {
                  final t = reduce ? 0.5 : _breath.value;
                  final bool lit = _breathing;
                  return Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: glow.withValues(
                              alpha: lit ? 0.35 + 0.35 * t : 0.28),
                          blurRadius: lit ? 10 + 10 * t : 10,
                          spreadRadius: lit ? 1 + 3 * t : 0,
                          offset: lit ? Offset.zero : const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Icon(
                  publish ? Icons.campaign_rounded : Icons.podcasts_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ),
              if (widget.showLabel) ...[
                SizedBox(height: 3.h),
                SizedBox(
                  width: 50.w,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: PawMapTheme.font(
                        size: 10.5.sp,
                        weight: FontWeight.w800,
                        color: PawMapTheme.toneOn(context, glow),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Point 7 : « Ce que je veux voir » ────────────────────────────────────

/// Une famille de la carte : son id, sa couleur de légende, son icône.
class PawSeeFamily {
  const PawSeeFamily(this.id, this.labelKey, this.icon, this.color,
      {this.dark = false});

  final String id;
  final String labelKey;
  final IconData icon;
  final Color color;

  /// Pastille noire (PawSpots : noir et or).
  final bool dark;
}

const List<PawSeeFamily> kPawSeeFamilies = <PawSeeFamily>[
  PawSeeFamily('friends', 'pawmap586_see_friends', Icons.favorite_rounded, PawMapLegend.friend),
  PawSeeFamily('owners', 'pawmap586_see_owners', Icons.pets_rounded, PawMapLegend.owner),
  PawSeeFamily('sitters', 'pawmap586_see_sitters', Icons.home_rounded, PawMapLegend.sitter),
  PawSeeFamily('walkers', 'pawmap586_see_walkers', Icons.directions_walk_rounded, PawMapLegend.walker),
  PawSeeFamily('places', 'pawmap586_see_places', Icons.place_rounded, Color(0xFF0E7490)),
  PawSeeFamily('pawspots', 'pawmap586_see_pawspots', Icons.stars_rounded, PawMapLegend.gold, dark: true),
  PawSeeFamily('reports', 'pawmap586_see_reports', Icons.warning_amber_rounded, Color(0xFFD32F2F)),
  PawSeeFamily('requests', 'pawmap586_see_requests', Icons.campaign_rounded, PawMapLegend.owner),
];

class PawMapSeeSection extends StatelessWidget {
  const PawMapSeeSection({
    super.key,
    required this.on,
    required this.onToggle,
    required this.onAll,
    required this.onNone,
    this.counter,
    this.footer,
  });

  /// Familles affichées (ids de [kPawSeeFamilies]).
  final Set<String> on;
  final ValueChanged<String> onToggle;
  final VoidCallback onAll;
  final VoidCallback onNone;

  /// « N membres autour de toi » (cliquable), sous le titre.
  final Widget? counter;

  /// Réglages fins sous les pastilles (disponible aujourd'hui, types de
  /// lieux…).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    final bool all = kPawSeeFamilies.every((f) => on.contains(f.id));
    final bool none = on.isEmpty;
    Widget shortcut(String key, String label, bool active, VoidCallback tap) =>
        Semantics(
          button: true,
          selected: active,
          label: label,
          child: GestureDetector(
            key: ValueKey<String>(key),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              tap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: BoxConstraints(minHeight: 34.h, minWidth: 44.w),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? PawMapTheme.accent.withValues(alpha: dark ? 0.28 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                    color: PawMapTheme.accent.withValues(alpha: active ? 0.7 : 0.3),
                    width: 1.2),
              ),
              child: Text(label,
                  style: PawMapTheme.font(
                      size: 12.sp,
                      weight: FontWeight.w800,
                      color: PawMapTheme.toneOn(context, PawMapTheme.accent))),
            ),
          ),
        );
    return Column(
      key: const ValueKey<String>('pawmap_see_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'pawmap586_see_title'.tr,
                style: PawMapTheme.fontOn(context,
                    size: 15.sp, weight: FontWeight.w800),
              ),
            ),
            shortcut('see_all', 'pawmap586_see_all'.tr, all, onAll),
            SizedBox(width: 6.w),
            shortcut('see_none', 'pawmap586_see_none'.tr, none, onNone),
          ],
        ),
        if (counter != null) ...[SizedBox(height: 4.h), counter!],
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final f in kPawSeeFamilies)
              _SeePill(
                family: f,
                on: on.contains(f.id),
                onTap: () => onToggle(f.id),
              ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          'pawmap586_see_hint'.tr,
          style: PawMapTheme.fontOn(context,
              size: 11.sp,
              weight: FontWeight.w500,
              color: PawMapTheme.subOn(context)),
        ),
        if (footer != null) ...[SizedBox(height: 8.h), footer!],
      ],
    );
  }
}

class _SeePill extends StatelessWidget {
  const _SeePill({required this.family, required this.on, required this.onTap});

  final PawSeeFamily family;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    final Color c = family.color;
    // Pastille allumée : dégradé de la famille (PawSpots : noir, icône or) ;
    // éteinte : contour à la couleur, fond teinté très pâle — jamais grise.
    final Gradient? g = !on
        ? null
        : (family.dark
            ? const LinearGradient(colors: [Color(0xFF33214A), PawMapLegend.ink])
            : pawRoleGradient(c));
    final Color fg = on
        ? (family.dark ? PawMapLegend.gold : Colors.white)
        : PawMapTheme.toneOn(context, family.dark ? PawMapLegend.ink : c);
    return Semantics(
      button: true,
      toggled: on,
      label: family.labelKey.tr,
      child: GestureDetector(
        key: ValueKey<String>('see_${family.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          constraints: BoxConstraints(minHeight: 38.h),
          padding: EdgeInsets.fromLTRB(6.w, 4.h, 12.w, 4.h),
          decoration: BoxDecoration(
            gradient: g,
            color: on ? null : c.withValues(alpha: dark ? 0.14 : 0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on
                  ? Colors.white.withValues(alpha: 0.6)
                  : (family.dark ? PawMapLegend.ink : c).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: (family.dark ? PawMapLegend.ink : c)
                          .withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on
                      ? Colors.white.withValues(alpha: family.dark ? 0.12 : 0.22)
                      : c.withValues(alpha: 0.14),
                ),
                child: Icon(family.icon, size: 16.sp, color: fg),
              ),
              SizedBox(width: 6.w),
              Text(
                family.labelKey.tr,
                maxLines: 1,
                style: PawMapTheme.font(
                    size: 12.5.sp, weight: FontWeight.w800, color: fg),
              ),
              SizedBox(width: 4.w),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  on ? Icons.check_rounded : Icons.add_rounded,
                  key: ValueKey<bool>(on),
                  size: 14.sp,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── v587 (point 1a) — pilule « ● Direct » en haut à gauche ──────────────

/// Libellé de la pilule : « Direct » (arrêté), « En direct » (< 1 min),
/// « En direct · 12 min », « Direct · pas de GPS » (partage lancé mais aucune
/// position réelle ne part). Pure, testée.
String pawDirectPillLabel({
  required bool live,
  required DateTime? startedAt,
  required DateTime now,
  bool noGps = false,
}) {
  if (!live) return 'pawmap587_direct_off'.tr;
  if (noGps) return 'pawmap587_direct_no_gps'.tr;
  final min = startedAt == null ? 0 : now.difference(startedAt).inMinutes;
  if (min < 1) return 'pawmap587_direct_on_now'.tr;
  return 'pawmap587_direct_on'.trParams({'min': '$min'});
}

/// Gardien / promeneur : UN appui démarre ou arrête le direct. Noire (encre)
/// quand arrêté ; verte lumineuse qui respire en direct (fixe si « réduire
/// les animations ») ; orange si le partage tourne sans GPS.
class PawMapDirectPill extends StatefulWidget {
  const PawMapDirectPill({
    super.key,
    required this.live,
    required this.startedAt,
    required this.onTap,
    this.noGps = false,
    this.onLongPress,
    this.now,
  });

  final bool live;
  final DateTime? startedAt;
  final bool noGps;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Tests : heure figée.
  final DateTime Function()? now;

  static const Color green = Color(0xFF16A34A);
  static const Color amber = Color(0xFFE8920A);
  static const Color ink = Color(0xFF17141F);

  @override
  State<PawMapDirectPill> createState() => _PawMapDirectPillState();
}

class _PawMapDirectPillState extends State<PawMapDirectPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PawMapDirectPill old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.live && !widget.noGps) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else if (_breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
    // La durée affichée avance toute seule (une fois par minute suffit).
    if (widget.live) {
      _minute ??= Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _minute?.cancel();
      _minute = null;
    }
  }

  @override
  void dispose() {
    _minute?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final DateTime now = (widget.now ?? DateTime.now)();
    final String label = pawDirectPillLabel(
      live: widget.live,
      startedAt: widget.startedAt,
      now: now,
      noGps: widget.noGps,
    );
    final Color base = !widget.live
        ? PawMapDirectPill.ink
        : (widget.noGps ? PawMapDirectPill.amber : PawMapDirectPill.green);
    final Gradient gradient = !widget.live
        ? const LinearGradient(
            colors: [Color(0xFF33214A), PawMapDirectPill.ink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: widget.noGps
                ? const [Color(0xFFF5A524), PawMapDirectPill.amber]
                : const [Color(0xFF22C55E), PawMapDirectPill.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return Semantics(
      button: true,
      toggled: widget.live,
      label: label,
      child: GestureDetector(
        key: ValueKey<String>(
            widget.live ? 'pawmap_direct_pill_on' : 'pawmap_direct_pill_off'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (ctx, child) {
            final double t = reduce ? 0.5 : _breath.value;
            final bool lit = widget.live && !widget.noGps;
            return Container(
              constraints: BoxConstraints(minHeight: 34.h),
              padding: EdgeInsets.fromLTRB(10.w, 6.h, 13.w, 6.h),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: base.withValues(alpha: lit ? 0.32 + 0.33 * t : 0.26),
                    blurRadius: lit ? 10 + 10 * t : 10,
                    spreadRadius: lit ? 1 + 2.5 * t : 0,
                    offset: lit ? Offset.zero : const Offset(0, 3),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.live ? Colors.white : const Color(0xFFFF4D3D),
                  border: widget.live
                      ? null
                      : Border.all(color: Colors.white, width: 1.2),
                ),
              ),
              SizedBox(width: 7.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
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

// ─── v587 (point 3) — barres repliables ──────────────────────────────────

/// Petite flèche en verre teinté posée au bord INTÉRIEUR d'une barre (rail
/// gauche : bord droit ; capsule droite : bord gauche). Barre rangée : la
/// même pastille devient la LANGUETTE collée au bord de l'écran, flèche
/// inversée. Cible tactile 40 × 48 (la pastille visible est plus fine).
class PawBarCollapseTab extends StatelessWidget {
  const PawBarCollapseTab({
    super.key,
    required this.left,
    required this.collapsed,
    required this.tint,
    required this.onTap,
  });

  /// Barre de GAUCHE (rail) ; sinon capsule de droite.
  final bool left;
  final bool collapsed;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Flèche : vers le bord qui range la barre ; inversée une fois rangée.
    final bool pointsLeft = left ? !collapsed : collapsed;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color glass = dark
        ? Color.alphaBlend(tint.withValues(alpha: 0.30), const Color(0xFF221A2E))
        : Color.alphaBlend(tint.withValues(alpha: 0.16), Colors.white);
    final BorderRadius radius = collapsed
        ? (left
            ? const BorderRadius.horizontal(right: Radius.circular(14))
            : const BorderRadius.horizontal(left: Radius.circular(14)))
        : BorderRadius.circular(14);
    return Semantics(
      button: true,
      label: collapsed ? 'pawmap587_bar_show'.tr : 'pawmap587_bar_hide'.tr,
      child: GestureDetector(
        key: ValueKey<String>(
            '${left ? 'pawmap_rail' : 'pawmap_capsule'}_${collapsed ? 'show' : 'hide'}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 30.w,
          height: 48.h,
          child: Align(
            alignment: collapsed
                ? (left ? Alignment.centerLeft : Alignment.centerRight)
                : Alignment.center,
            child: Container(
              width: collapsed ? 24.w : 22.w,
              height: collapsed ? 44.h : 36.h,
              decoration: BoxDecoration(
                color: glass.withValues(alpha: 0.94),
                borderRadius: radius,
                border: Border.all(color: tint.withValues(alpha: 0.35), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                pointsLeft
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 20.sp,
                color: dark ? Colors.white : PawMapLegend.darken(tint, 0.25),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v587 (point 3) — une barre (rail gauche ou capsule droite) qui glisse hors
/// écran en 200 ms en laissant sa languette collée au bord. Seule une
/// translation est animée (ni mise en page ni redessin de la barre : elle
/// est isolée dans un `RepaintBoundary`) : fluide sur un Android d'entrée de
/// gamme.
class PawCollapsibleBar extends StatefulWidget {
  const PawCollapsibleBar({
    super.key,
    required this.left,
    required this.collapsed,
    required this.tint,
    required this.onToggle,
    required this.child,
    this.edgeGap = 12,
  });

  final bool left;
  final bool collapsed;
  final Color tint;
  final VoidCallback onToggle;
  final Widget child;

  /// Distance entre la barre et le bord de l'écran (marge du parent).
  final double edgeGap;

  static const Duration duration = Duration(milliseconds: 200);

  @override
  State<PawCollapsibleBar> createState() => _PawCollapsibleBarState();
}

class _PawCollapsibleBarState extends State<PawCollapsibleBar> {
  final GlobalKey _barKey = GlobalKey();
  double _barWidth = 0;

  void _measure() {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final w = box != null && box.hasSize ? box.size.width : 0.0;
    if (w > 0 && (w - _barWidth).abs() > 0.5 && mounted) {
      setState(() => _barWidth = w);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final Widget bar = RepaintBoundary(
      child: KeyedSubtree(key: _barKey, child: widget.child),
    );
    final Widget tab = PawBarCollapseTab(
      left: widget.left,
      collapsed: widget.collapsed,
      tint: widget.tint,
      onTap: widget.onToggle,
    );
    final double shift = _barWidth + widget.edgeGap;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.collapsed ? 1 : 0),
      duration: PawCollapsibleBar.duration,
      curve: Curves.easeOutCubic,
      builder: (ctx, t, child) => Transform.translate(
        offset: Offset((widget.left ? -shift : shift) * t, 0),
        child: child,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widget.left ? [bar, tab] : [tab, bar],
      ),
    );
  }
}

/// v587 (point 2) — regroupement des membres SANS jamais absorber un ami :
/// chaque ami reste seul (son rond photo + anneau rose), seuls les autres
/// passent par [cluster]. Pure, testée.
List<List<T>> pawGroupKeepingFriends<T>(
  List<T> items,
  bool Function(T) isFriend,
  List<List<T>> Function(List<T> others) cluster,
) =>
    <List<T>>[
      for (final p in items)
        if (isFriend(p)) <T>[p],
      ...cluster(items.where((p) => !isFriend(p)).toList()),
    ];
