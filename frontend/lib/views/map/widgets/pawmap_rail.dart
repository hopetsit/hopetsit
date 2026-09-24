// v584 — lot C du chantier du 24/09 : le RAIL GAUCHE PERSONNALISABLE.
//
// Daniel : « que les gens comprennent ce qu'ils font, à quoi ça sert » + rail
// « personnalisable (ordre et choix des boutons) ». Ici :
//   · [PawRailSpec]          — la fiche d'un bouton (id court, icône, couleurs
//     validées le 12/09, libellé, EXPLICATION en une phrase) ;
//   · [kPawRailSpecs]        — les 9 boutons connus, dans l'ordre d'origine ;
//   · [PawMapRail]           — la colonne, construite depuis l'ORDRE choisi par
//     l'utilisateur (enregistré sur le compte) ; appui = action, appui LONG =
//     l'explication ; un petit bouton « personnaliser » ferme la colonne ;
//   · [PawRailHelpSheet]     — la bulle d'explication d'un bouton ;
//   · [PawRailCustomizeSheet]— le menu de personnalisation : glisser pour
//     réordonner, interrupteur pour montrer / cacher, chaque ligne porte son
//     explication, bouton « Remettre l'ordre d'origine ».
// Aucune action ne vit ici : la colonne appelle `onTap(id)` et l'écran fait
// exactement ce qu'il faisait avant (mêmes fonctions, mêmes couleurs).

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../utils/pawmap_theme.dart';
import 'paw_rail_button.dart';
import 'pawmap_buttons.dart';
import 'pawmap_pins.dart';

// v561 — handoff « Paw Buttons » (Daniel, 12/09) : icônes SVG blanches
// pleines des boutons ronds (dégradé 165°, bord blanc, aucun libellé visible).
// Déplacées ici depuis paw_map_screen.dart, à l'identique.
const String kRailSvgPlaces =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><g fill="rgba(0,0,0,.34)"><circle cx="10.2" cy="7.2" r="1.1"/><circle cx="13.8" cy="7.2" r="1.1"/><circle cx="8.4" cy="9.4" r="1"/><circle cx="15.6" cy="9.4" r="1"/><path d="M12 9.3c-1.7 0-3.3 1.6-3.3 3.1 0 .9.8 1.7 1.7 1.7.6 0 1.1-.3 1.6-.3s1 .3 1.6.3c.9 0 1.7-.8 1.7-1.7 0-1.5-1.6-3.1-3.3-3.1z"/></g></svg>';
const String kRailSvgRoute =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 18c0-5 3-6 6-6s6-1 6-6" stroke-dasharray="3 2.6"/><circle cx="6" cy="18" r="2.6" fill="#FFFFFF" stroke="none"/><path d="M18 2.5c-1.8 0-3.2 1.4-3.2 3.2 0 2.2 3.2 5.3 3.2 5.3s3.2-3.1 3.2-5.3c0-1.8-1.4-3.2-3.2-3.2z" fill="#FFFFFF" stroke="none"/></svg>';
const String kRailSvgSpot =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M12 5.4l1.4 2.9 3.1.4-2.3 2.2.6 3.1L12 12.5 9.2 14l.6-3.1-2.3-2.2 3.1-.4z" fill="rgba(0,0,0,.34)"/></svg>';
const String kRailSvgAdd =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 22s-7.5-6.5-7.5-12A7.5 7.5 0 0 1 19.5 10c0 5.5-7.5 12-7.5 12z"/><path d="M10.9 6h2.2v2.9H16v2.2h-2.9V14h-2.2v-2.9H8V8.9h2.9z" fill="rgba(0,0,0,.34)"/></svg>';
const String kRailSvgReport =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 2.8 22.6 21H1.4z"/><path d="M10.9 9h2.2v6h-2.2zM10.9 16.5h2.2v2.2h-2.2z" fill="rgba(0,0,0,.4)"/></svg>';
const String kRailSvgFeed =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M5 2.5h2.2V21.5H5z"/><path d="M7.2 3.5h11.3l-2.4 4.5 2.4 4.5H7.2z"/><circle cx="18.5" cy="5" r="3.6" fill="#E24834" stroke="#fff" stroke-width="1.4"/></svg>';
const String kRailSvgLiveFriends =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><circle cx="9" cy="8" r="3.2"/><path d="M2.5 18.5c0-3.3 2.9-5.5 6.5-5.5s6.5 2.2 6.5 5.5V20h-13z"/><circle cx="16.5" cy="9" r="2.5"/><path d="M15.2 13.4c3.2.2 6.3 2.1 6.3 5.1V20h-4.6v-1.5c0-1.9-.6-3.6-1.7-5.1z"/><circle cx="19.5" cy="4.5" r="2.2" fill="#7CFFB2"/></svg>';
const String kRailSvgChat =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M12 3C6.9 3 3 6.3 3 10.4c0 2 1 3.9 2.6 5.2L4.8 20l4.6-1.9c.8.2 1.7.3 2.6.3 5.1 0 9-3.3 9-7.4S17.1 3 12 3z"/><g fill="rgba(0,0,0,.34)"><circle cx="8.6" cy="10.6" r="1.1"/><circle cx="12" cy="10.6" r="1.1"/><circle cx="15.4" cy="10.6" r="1.1"/></g></svg>';
const String kRailSvgPhoto =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="#FFFFFF"><path d="M9 4h6l1.4 2.2H20a1.6 1.6 0 0 1 1.6 1.6V18A1.6 1.6 0 0 1 20 19.6H4A1.6 1.6 0 0 1 2.4 18V7.8A1.6 1.6 0 0 1 4 6.2h3.6z"/><circle cx="12" cy="12.8" r="3.6" fill="rgba(0,0,0,.34)"/></svg>';

class PawRailSpec {
  const PawRailSpec({
    required this.id,
    required this.icon,
    required this.svg,
    required this.color,
    required this.g1,
    required this.g2,
    required this.labelKey,
    required this.helpKey,
  });

  final String id;
  final IconData icon;
  final String svg;
  final Color color;
  final Color g1;
  final Color g2;
  final String labelKey;
  final String helpKey;

  String get label => labelKey.tr;
  String get help => helpKey.tr;
}

/// Les 9 boutons du rail, dans l'ordre d'origine (celui de la v565/v573).
const List<PawRailSpec> kPawRailSpecs = <PawRailSpec>[
  PawRailSpec(
    id: 'around',
    icon: Icons.navigation_rounded,
    svg: kRailSvgPlaces,
    color: PawMapTheme.pawFollow,
    g1: Color(0xFFA076FF),
    g2: Color(0xFF7040D6),
    labelKey: 'pawmap_btn_around',
    helpKey: 'pawmap_rail_help_around',
  ),
  PawRailSpec(
    id: 'directions',
    icon: Icons.directions_rounded,
    svg: kRailSvgRoute,
    color: PawMapTheme.ok,
    g1: Color(0xFF3DBF6C),
    g2: Color(0xFF188A42),
    labelKey: 'pawmap_btn_directions',
    helpKey: 'pawmap_rail_help_directions',
  ),
  PawRailSpec(
    id: 'live_friends',
    icon: Icons.people_alt_rounded,
    svg: kRailSvgLiveFriends,
    color: PawMapTheme.rose,
    g1: Color(0xFFFF6EB4),
    g2: PawMapTheme.roseDark,
    labelKey: 'v565_live_friends_title',
    helpKey: 'pawmap_rail_help_live_friends',
  ),
  PawRailSpec(
    id: 'chat',
    icon: Icons.forum_rounded,
    svg: kRailSvgChat,
    color: PawMapTheme.sitter,
    g1: Color(0xFF5B9DFF),
    g2: Color(0xFF2358D6),
    labelKey: 'pawmap_btn_circle_chat',
    helpKey: 'pawmap_rail_help_chat',
  ),
  PawRailSpec(
    id: 'photo',
    icon: Icons.photo_camera_rounded,
    svg: kRailSvgPhoto,
    color: PawMapTheme.pawSpot,
    g1: Color(0xFFFFB067),
    g2: Color(0xFFE07A12),
    labelKey: 'pawmap_btn_spot_photo',
    helpKey: 'pawmap_rail_help_photo',
  ),
  PawRailSpec(
    id: 'spots',
    icon: Icons.travel_explore_rounded,
    svg: kRailSvgSpot,
    color: Color(0xFFE2981A),
    g1: Color(0xFFFAC346),
    g2: Color(0xFFE2981A),
    labelKey: 'pawmap_view_spots_btn',
    helpKey: 'pawmap_rail_help_spots',
  ),
  PawRailSpec(
    id: 'tag',
    icon: Icons.add_location_alt_rounded,
    svg: kRailSvgAdd,
    color: Color(0xFF18968A),
    g1: Color(0xFF48C8BA),
    g2: Color(0xFF18968A),
    labelKey: 'pawmap_tag_spot',
    helpKey: 'pawmap_rail_help_tag',
  ),
  PawRailSpec(
    id: 'report',
    icon: Icons.add_moderator_rounded,
    svg: kRailSvgReport,
    color: Color(0xFFD63A28),
    g1: Color(0xFFFF6E5C),
    g2: Color(0xFFD63A28),
    labelKey: 'pawmap_btn_send',
    helpKey: 'pawmap_rail_help_report',
  ),
  PawRailSpec(
    id: 'feed',
    icon: Icons.notifications_active_rounded,
    svg: kRailSvgFeed,
    color: Color(0xFF28201B),
    g1: Color(0xFF5A4E46),
    g2: Color(0xFF28201B),
    labelKey: 'pawmap_view_reports_btn',
    helpKey: 'pawmap_rail_help_feed',
  ),
];

/// Ordre par défaut (tous les boutons, dans l'ordre d'origine).
List<String> get kPawRailDefaultOrder =>
    kPawRailSpecs.map((s) => s.id).toList(growable: false);

PawRailSpec? pawRailSpecOf(String id) {
  for (final s in kPawRailSpecs) {
    if (s.id == id) return s;
  }
  return null;
}

/// Nettoie un ordre venu du compte : ids connus, sans doublon ; vide → défaut.
List<String> normalizeRailOrder(List<String>? order) {
  if (order == null) return kPawRailDefaultOrder;
  final out = <String>[];
  for (final id in order) {
    if (pawRailSpecOf(id) != null && !out.contains(id)) out.add(id);
  }
  return out.isEmpty ? kPawRailDefaultOrder : out;
}

/// Explications des boutons du dock et de la capsule (appui long).
const Map<String, String> kPawDockHelpKeys = <String, String>{
  'share': 'pawmap_rail_help_share',
  'sos': 'pawmap_rail_help_sos',
  'layers': 'pawmap_rail_help_layers',
  'night': 'pawmap_rail_help_night',
  'history': 'pawmap_rail_help_history',
};

class PawMapRail extends StatelessWidget {
  const PawMapRail({
    super.key,
    required this.order,
    required this.onTap,
    required this.onLongPress,
    required this.onCustomize,
    this.active = const <String>{},
  });

  /// Ids des boutons à afficher, dans l'ordre.
  final List<String> order;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;
  final VoidCallback onCustomize;
  final Set<String> active;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final id in order)
          if (pawRailSpecOf(id) case final PawRailSpec spec)
            Padding(
              padding: EdgeInsets.only(top: PawMapTheme.railGap.h),
              child: PawRailButton(
                key: ValueKey<String>('rail_$id'),
                color: spec.color,
                label: spec.label,
                icon: spec.icon,
                svg: spec.svg,
                gradientTop: spec.g1,
                gradientBottom: spec.g2,
                active: active.contains(id),
                onTap: () => onTap(id),
                onLongPress: () => onLongPress(id),
              ),
            ),
        // Bouton « personnaliser » : plus petit, encre, en bas du rail.
        Padding(
          padding: EdgeInsets.only(top: PawMapTheme.railGap.h),
          child: PawRailButton(
            key: const ValueKey<String>('rail_customize'),
            color: PawMapLegend.ink,
            label: 'pawmap_rail_customize'.tr,
            icon: Icons.tune_rounded,
            gradientTop: const Color(0xFF3A2F2A),
            gradientBottom: PawMapLegend.ink,
            size: PawMapTheme.railButtonSize - 8,
            onTap: onCustomize,
            onLongPress: onCustomize,
          ),
        ),
      ],
    );
  }
}

/// Bulle d'explication d'un bouton (appui long) : icône, nom, une phrase,
/// et le chemin vers la personnalisation.
class PawRailHelpSheet extends StatelessWidget {
  const PawRailHelpSheet({
    super.key,
    required this.title,
    required this.help,
    required this.color,
    required this.icon,
    this.onCustomize,
    this.onDo,
  });

  final String title;
  final String help;
  final Color color;
  final IconData icon;
  final VoidCallback? onCustomize;

  /// « Essayer » : fait l'action tout de suite.
  final VoidCallback? onDo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  gradient: PawMapTheme.railGradient(color),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                  boxShadow: PawMapTheme.railShadow(color),
                ),
                child: Icon(icon, color: Colors.white, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: PawMapTheme.fontOn(context,
                      size: 17.sp, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            help,
            style: PawMapTheme.fontOn(context,
                size: 13.5.sp, weight: FontWeight.w500, height: 1.35),
          ),
          SizedBox(height: 14.h),
          if (onDo != null)
            PawSignatureButton(
              key: const ValueKey<String>('rail_help_do'),
              label: title,
              icon: icon,
              color: color,
              onTap: onDo,
            ),
          if (onCustomize != null) ...[
            SizedBox(height: 6.h),
            Center(
              child: PawSignatureButton(
                key: const ValueKey<String>('rail_help_customize'),
                kind: PawButtonKind.link,
                label: 'pawmap_rail_customize'.tr,
                icon: Icons.tune_rounded,
                color: PawMapLegend.ink,
                expand: false,
                onTap: onCustomize,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Menu de personnalisation : glisser pour réordonner, interrupteur pour
/// montrer / cacher, explication sous chaque nom, « Remettre l'ordre
/// d'origine ». [onChanged] reçoit la liste des ids AFFICHÉS, dans l'ordre.
class PawRailCustomizeSheet extends StatefulWidget {
  const PawRailCustomizeSheet({
    super.key,
    required this.order,
    required this.onChanged,
  });

  final List<String> order;
  final ValueChanged<List<String>> onChanged;

  @override
  State<PawRailCustomizeSheet> createState() => _PawRailCustomizeSheetState();
}

class _PawRailCustomizeSheetState extends State<PawRailCustomizeSheet> {
  late List<String> _shown;
  late List<String> _hidden;

  @override
  void initState() {
    super.initState();
    _shown = normalizeRailOrder(widget.order);
    _hidden = kPawRailDefaultOrder.where((id) => !_shown.contains(id)).toList();
  }

  void _emit() => widget.onChanged(List<String>.unmodifiable(_shown));

  @override
  Widget build(BuildContext context) {
    final all = [..._shown, ..._hidden];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 4.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('pawmap_rail_customize'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 18.sp, weight: FontWeight.w800)),
              SizedBox(height: 4.h),
              Text('pawmap_rail_customize_sub'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 12.sp,
                      weight: FontWeight.w500,
                      color: PawMapTheme.subOn(context))),
            ],
          ),
        ),
        Flexible(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 6.h),
            itemCount: all.length,
            onReorder: (oldIndex, newIndex) {
              // Seuls les boutons AFFICHÉS se réordonnent entre eux.
              if (oldIndex >= _shown.length) return;
              var target = newIndex.clamp(0, _shown.length);
              if (target > oldIndex) target -= 1;
              setState(() {
                final id = _shown.removeAt(oldIndex);
                _shown.insert(target.clamp(0, _shown.length), id);
              });
              _emit();
            },
            itemBuilder: (_, i) {
              final id = all[i];
              final spec = pawRailSpecOf(id)!;
              final shown = i < _shown.length;
              return Container(
                key: ValueKey<String>('rail_row_$id'),
                margin: EdgeInsets.only(bottom: 6.h),
                padding: EdgeInsets.fromLTRB(8.w, 8.h, 6.w, 8.h),
                decoration: BoxDecoration(
                  color: shown
                      ? spec.color.withValues(
                          alpha: PawMapTheme.isDark(context) ? 0.18 : 0.08)
                      : PawMapTheme.veilOn(context, 0.04, darkAlpha: 0.10),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                      color: spec.color.withValues(alpha: shown ? 0.35 : 0.12)),
                ),
                child: Row(
                  children: [
                    if (shown)
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Icon(Icons.drag_indicator_rounded,
                              size: 22.sp, color: PawMapTheme.subOn(context)),
                        ),
                      )
                    else
                      SizedBox(width: 30.w),
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        gradient: PawMapTheme.railGradient(spec.color,
                            top: spec.g1, bottom: spec.g2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                      child: Icon(spec.icon, color: Colors.white, size: 18.sp),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.label,
                              maxLines: 2,
                              style: PawMapTheme.fontOn(context,
                                  size: 13.5.sp, weight: FontWeight.w800)),
                          Text(spec.help,
                              maxLines: 3,
                              style: PawMapTheme.fontOn(context,
                                  size: 11.sp,
                                  weight: FontWeight.w500,
                                  color: PawMapTheme.subOn(context))),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      key: ValueKey<String>('rail_switch_$id'),
                      value: shown,
                      activeThumbColor: Colors.white,
                      activeTrackColor: spec.color,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor:
                          PawMapTheme.accent.withValues(alpha: 0.35),
                      onChanged: (v) {
                        setState(() {
                          if (v) {
                            _hidden.remove(id);
                            _shown.add(id);
                          } else {
                            _shown.remove(id);
                            _hidden.insert(0, id);
                          }
                        });
                        _emit();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 14.h),
          child: PawSignatureButton(
            key: const ValueKey<String>('rail_reset'),
            kind: PawButtonKind.secondary,
            label: 'pawmap_rail_reset'.tr,
            icon: Icons.restart_alt_rounded,
            color: PawMapTheme.accent,
            onTap: () {
              setState(() {
                _shown = List<String>.from(kPawRailDefaultOrder);
                _hidden = <String>[];
              });
              _emit();
            },
          ),
        ),
      ],
    );
  }
}
