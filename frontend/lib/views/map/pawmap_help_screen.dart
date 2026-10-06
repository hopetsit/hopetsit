// v584 — « Comprendre la PawMap » : l'écran ouvert par le bouton « ? » de la
// carte, RÉUTILISABLE (demande de Daniel du 25/09) : le lot D le branchera
// dans Profil › Aide des 3 rôles.
//
//   Ouvrir :  Get.to(() => const PawMapHelpScreen());
//   ou      :  Get.toNamed(PawMapHelpScreen.routeName)  (route nommée déclarée
//             dans `PawMapHelpScreen.page`, à ajouter aux `getPages` si besoin).
//
// v587 (point 10) — contenu en 5 sections : Se repérer · Voir qui est
// autour · Être visible / en direct · Agir · Réglages. Pour chaque bouton :
// son icône, à quoi il sert, pourquoi, le geste exact (`help587_b_<id>`,
// pack `help587_i18n.dart`, mêmes textes que la légende du site). Un exemple
// par section, puis une FAQ. Seuls les boutons du rôle sont décrits (Direct =
// 3 profils depuis le 25/09, Publier = propriétaire), comme sur la carte.
// En bas, « Voir sur la carte » ouvre l'onglet PawMap.
//
// v597 (27/09, Daniel : « moderniser comme sur le site web avec cadre,
// animation etc ») — même contenu que `PawMapLegendModal.tsx` du site :
//   · encadré vert « Ta position reste privée » (rayon ~1 km, seul le Direct
//     est exact) ;
//   · mon rond plein / « amis seulement ou masqué » (pointillés + œil barré),
//     l'ami (halo rose, contour = ses rôles), les couleurs des profils
//     (orange → bleu → vert), la bulle double prix gardien + promeneur, et
//     « un seul halo à la fois » (PawBoost > PawFollow > ami, couronne en plus) ;
//   · sections en CARTES arrondies, petites illustrations dessinées avec les
//     peintres de la carte, apparition douce au défilement (coupée quand
//     l'OS demande de réduire les animations), encadré 💡 par section.
// Textes : clés `help2709_*` (help587_i18n.dart), mêmes phrases que
// website/src/lib/i18n/privacy2709.ts. Aucun gris : encre, crème et orange.
//
// Noms, icônes et couleurs des boutons : UNE source, `kPawRailSpecs` /
// `kPawDockSpecs` (`pawmap_rail.dart`) et `kPawCapsuleSpecs` — les mêmes que
// le menu de personnalisation du rail et l'appui long sur la carte.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/widgets/paw_rank611.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/map_ui_state.dart';
import '../../utils/pawmap_theme.dart';
import '../profile/widgets/profile_ui_kit.dart';
import 'widgets/paw_rail_button.dart';
import 'widgets/pawmap_buttons.dart';
import 'widgets/pawmap_discreet.dart';
import 'widgets/pawmap_pins.dart';
import 'widgets/pawmap_rail.dart';
import 'widgets/pawmap_sheets.dart';
import 'widgets/pawmap_balade_illustration.dart';
import '../../widgets/paw_tab_bar.dart';

// ── Palette de l'aide (chaude, jamais grise) ──────────────────────────────
const Color _cream = Color(0xFFFFFBF7);
const Color _creamDeep = Color(0xFFFCEDE4);
const Color _inkWarm = Color(0xFF231715);
const Color _cardDark = Color(0xFF2E201C);
const Color _cardDarkDeep = Color(0xFF241916);
const Color _lineLight = Color(0xFFF3E3DA);
const Color _lineDark = Color(0xFF3A2A25);

class PawMapHelpScreen extends StatefulWidget {
  const PawMapHelpScreen({super.key, this.fromMap = false, this.role});

  /// Route nommée (facultative) : `Get.toNamed(PawMapHelpScreen.routeName)`.
  static const String routeName = '/pawmap/help';

  /// Page GetX prête à être ajoutée à la liste des routes de l'app.
  static GetPage<dynamic> get page =>
      GetPage<dynamic>(name: routeName, page: () => const PawMapHelpScreen());

  /// `true` quand l'écran est ouvert DEPUIS la carte : « Voir sur la carte »
  /// revient simplement en arrière (la carte est juste derrière).
  final bool fromMap;

  /// v587 — rôle à expliquer (`owner` / `sitter` / `walker`) ; `null` = le
  /// rôle du compte. Un bouton absent de ce rôle n'est pas décrit.
  final String? role;

  @override
  State<PawMapHelpScreen> createState() => _PawMapHelpScreenState();
}

/// v605 (30/09) — Daniel : « vu que tout est numéroté, fais un menu avec les
/// titres pour aller directement à la section sans défiler ». Les sections
/// du sommaire, dans l'ordre de l'écran (id, numéro, clé du titre).
const List<(String, int?, String)> kPawHelpSections = <(String, int?, String)>[
  ('find', 1, 'help587_sec_find'),
  ('see', 2, 'help587_sec_see'),
  ('live', 3, 'help587_sec_live'),
  ('balade', 4, 'help599_sec_balade'),
  // 607 (ZOE, 02/10) — mêmes sections et mêmes textes que l'aide du site (LEO).
  ('plush', 5, 'help607_plush_title'),
  // 612 (Daniel, 05/10) — les rangs ont LEUR section (avant : une ligne
  // perdue au bas des peluches, introuvable).
  ('ranks', 6, 'help611_ranks_t'),
  ('pioneer', 7, 'help607_pioneer_title'),
  ('act', 8, 'help587_sec_act'),
  ('set', 9, 'help587_sec_set'),
  ('faq', null, 'help587_faq_title'),
];

class _PawMapHelpScreenState extends State<PawMapHelpScreen> {
  bool get fromMap => widget.fromMap;
  String? get role => widget.role;

  /// Ancre de chaque section (sommaire → défilement jusqu'à elle).
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{
    for (final s in kPawHelpSections)
      s.$1: GlobalKey(debugLabel: 'help_anchor_${s.$1}'),
  };

  Future<void> _goTo(String id) async {
    final ctx = _anchors[id]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: _reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0, // section plus haute que l'écran : son HAUT en haut
    );
  }

  void _seeMap(BuildContext context) {
    if (fromMap && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    openPawMap();
  }

  /// Rôle affiché : celui passé, sinon celui du compte (même source que la
  /// carte). Vide = pas de compte → comme la carte, « Publier » est montré.
  String get _roleNow {
    if (role != null) return role!;
    final auth =
        Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    return auth?.userRole.value ?? '';
  }

  void _explain(BuildContext context, PawRailSpec spec) {
    showPawMapSheet<void>(
      context,
      PawRailHelpSheet(
        title: spec.label,
        help: 'help587_b_${spec.id}'.tr,
        color: spec.color,
        icon: spec.icon,
        onDo: () {
          Navigator.of(context).pop();
          _seeMap(context);
        },
      ),
    );
  }

  Widget _railRow(BuildContext context, String id) {
    // v602 — « Voir signaux » est passé dans la barre de droite.
    final spec = (pawRailSpecOf(id) ?? pawCapsuleSlotOf(id))!;
    return _ButtonRow(
      key: ValueKey<String>('help_rail_$id'),
      icon: PawRailButton(
        color: spec.color,
        label: spec.label,
        svg: spec.svg,
        gradientTop: spec.g1,
        gradientBottom: spec.g2,
        onTap: () => _explain(context, spec),
      ),
      title: spec.label,
      help: 'help587_b_$id'.tr,
    );
  }

  Widget _dockRow(BuildContext context, String id) {
    final d = pawDockSpecOf(id)!;
    return _ButtonRow(
      key: ValueKey<String>('help_dock_$id'),
      icon: _RoundIcon(icon: d.icon, color: d.color),
      title: d.label,
      help: 'help587_b_$id'.tr,
    );
  }

  Widget _capsuleRow(BuildContext context, String id,
      {String? helpKey, String? extraKey}) {
    final c = pawCapsuleSpecOf(id)!;
    final strong = id == 'publish' || id == 'direct';
    return _ButtonRow(
      key: ValueKey<String>('help_capsule_$id'),
      icon: _RoundIcon(icon: c.icon, color: c.color, filled: strong),
      title: id == 'fade' ? 'help587_t_fade'.tr : c.label,
      help: (helpKey ?? 'help587_b_$id').tr + (extraKey == null ? '' : extraKey.tr),
    );
  }

  Widget _plainRow(String id, IconData icon, Color color,
      {String? titleKey, String? helpKey, bool filled = false}) {
    return _ButtonRow(
      key: ValueKey<String>('help_x_$id'),
      icon: _RoundIcon(icon: icon, color: color, filled: filled),
      title: (titleKey ?? 'help587_t_$id').tr,
      help: (helpKey ?? 'help587_b_$id').tr,
    );
  }

  /// Une épingle de la légende (dessinée par les peintres de la carte).
  Widget _pinRow(PawLegendEntry e,
      {String? title, String? help, Color? color, bool wide = false}) {
    return _ButtonRow(
      key: ValueKey<String>('legend_${e.key}'),
      icon: wide
          ? FittedBox(fit: BoxFit.scaleDown, child: PawPinPreview(entry: e))
          : _PinBox(child: PawPinPreview(entry: e)),
      title: title ?? e.label,
      help: help,
      titleColor: color,
      stacked: wide,
    );
  }

  /// v597 — les ronds et halos du 27/09, dans l'ordre du site.
  List<Widget> _peopleRows(Map<String, PawLegendEntry> byKey) {
    final rows = <Widget>[];
    void add(String key, {String? t, String? b, Color? c}) {
      final e = byKey[key];
      if (e != null) rows.add(_pinRow(e, title: t?.tr, help: b?.tr, color: c));
    }

    add('me', t: 'help2709_me_t', b: 'help2709_me_b', c: PawMapLegend.owner);
    add('friends_only', t: 'help2709_mefr_t', b: 'help2709_mefr_b', c: PawMapLegend.ink);
    rows.add(_pinRow(_friendEntry(),
        title: 'help2709_friend_t'.tr,
        help: 'help2709_friend_b'.tr,
        color: PawMapLegend.friend));
    for (final r in const ['owner', 'sitter', 'walker']) {
      add('member_$r', c: PawMapLegend.roleColor(r));
    }
    rows.add(_ButtonRow(
      key: const ValueKey<String>('help_roles'),
      icon: const _RolePills(),
      title: 'help2709_roles_t'.tr,
      help: 'help2709_roles_b'.tr,
      titleColor: PawMapLegend.ink,
    ));
    rows.add(_pinRow(_duoEntry(),
        title: 'help2709_duo_t'.tr,
        help: 'help2709_duo_b'.tr,
        color: PawMapLegend.sitter,
        wide: true));
    add('premium', c: const Color(0xFFB7791F));
    add('boost', c: const Color(0xFF0E7490));
    rows.add(_pinRow(_followEntry(),
        title: 'help2709_follow_t'.tr,
        help: 'help2709_follow_b'.tr,
        color: PawMapLegend.pawFollow));
    rows.add(_ButtonRow(
      key: const ValueKey<String>('help_halo'),
      icon: const _HaloTrio(),
      title: 'help2709_halo_t'.tr,
      help: 'help2709_halo_b'.tr,
      titleColor: PawMapLegend.ink,
    ));
    add('verified', c: PawMapLegend.sitter);
    add('member_group');
    add('request', c: PawMapLegend.owner);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final entries = pawLegendEntries();
    final byKey = {for (final e in entries) e.key: e};
    const peopleKeys = {
      'me', 'friend', 'friends_only', 'member_owner', 'member_sitter',
      'member_walker', 'premium', 'boost', 'verified', 'member_group', 'request',
      'spot',
    };
    final role = _roleNow;
    // Mêmes règles que la carte : pilule « Direct » en haut à gauche pour les
    // 3 profils (v587) ; « Publier » en plus pour le propriétaire.
    final provider = role == 'sitter' || role == 'walker';
    final roleColor = PawMapLegend.roleColor(role.isEmpty ? 'owner' : role);
    return ProfileSubPageScaffold(
      title: 'pawmap_help_title'.tr,
      accent: PawMapTheme.accent,
      body: Center(
        child: ConstrainedBox(
          // Tablette : une colonne de lecture confortable, centrée.
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            key: const ValueKey<String>('pawmap_help_body'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Reveal(child: _HeroCard()),
              SizedBox(height: 12.h),
              const _Reveal(child: _PrivacyCard(key: ValueKey<String>('help_privacy'))),
              SizedBox(height: 12.h),
              // v605 — sommaire cliquable (numéros + titres des sections).
              _HelpToc(
                key: const ValueKey<String>('help_toc'),
                onTap: (id) => unawaited(_goTo(id)),
              ),

              // ── 1. Se repérer ──────────────────────────────────────────
              _SectionCard(
                anchorKey: _anchors['find'],
                id: 'find',
                number: 1,
                icon: Icons.explore_rounded,
                title: 'help587_sec_find'.tr,
                example: 'help587_ex_find'.tr,
                children: [
                  _plainRow('pins', Icons.place_rounded, PawMapTheme.accent),
                  ..._peopleRows(byKey),
                  for (final e in entries) ...[
                    if (!peopleKeys.contains(e.key)) _pinRow(e),
                    // v597 — PawSpot : son nom sous la goutte au zoom rue.
                    if (e.key == 'spot')
                      _pinRow(_spotNamedEntry(e.label),
                          help: 'help2709_spotname_b'.tr,
                          color: const Color(0xFFB7791F),
                          wide: true),
                  ],
                  // Signalement : inchangé (emoji du type), décrit sans image.
                  _ButtonRow(
                    key: const ValueKey<String>('legend_report'),
                    icon: _RoundIcon(
                        icon: Icons.warning_amber_rounded, color: PawMapTheme.danger),
                    title: 'pawmap_legend_report'.tr,
                  ),
                  _plainRow('locate', Icons.my_location_rounded, roleColor, filled: true),
                  _plainRow('zoom', Icons.zoom_in_rounded, PawMapLegend.ink),
                  _plainRow('sat', Icons.satellite_alt_rounded, PawMapTheme.accent),
                  // v589 — les 4 ronds orange du haut, dans l'ordre de l'écran.
                  _plainRow('legendbtn', Icons.question_mark_rounded, PawMapTheme.accent,
                      filled: true,
                      titleKey: 'help589_t_legendbtn',
                      helpKey: 'help589_b_legendbtn'),
                  // 610 — la loupe cherche aussi les amis et les membres.
                  _plainRow('search', Icons.search_rounded, PawMapTheme.accent,
                      filled: true,
                      titleKey: 'help610_search_t',
                      helpKey: 'help610_search_b'),
                  _plainRow('refresh', Icons.refresh_rounded, PawMapTheme.accent,
                      filled: true, titleKey: 'help589_t_refresh', helpKey: 'help589_b_refresh'),
                  _plainRow('options', Icons.settings_rounded, PawMapTheme.accent,
                      filled: true, titleKey: 'pawmap589_options', helpKey: 'help589_b_options'),
                  _railRow(context, 'pawpoints'),
                  _railRow(context, 'around'),
                  _railRow(context, 'directions'),
                  _capsuleRow(context, 'fade'),
                ],
              ),

              // ── 2. Voir qui est autour ─────────────────────────────────
              _SectionCard(
                anchorKey: _anchors['see'],
                id: 'see',
                number: 2,
                icon: Icons.groups_rounded,
                title: 'help587_sec_see'.tr,
                example: 'help587_ex_see'.tr,
                children: [
                  _capsuleRow(context, 'see'),
                  _railRow(context, 'live_friends'),
                  // 610 — demandes d'amis visibles sur la carte.
                  _plainRow('requests610', Icons.person_add_alt_1_rounded,
                      PawMapLegend.friend,
                      filled: true,
                      titleKey: 'help610_requests_t',
                      helpKey: 'help610_requests_b'),
                  // v607 (décision 4.4) — le bouton rose affiche / masque
                  // tous les membres : même titre et même phrase que le site.
                  _plainRow('fit', Icons.groups_rounded, PawMapTheme.rose,
                      titleKey: 'map_members_show', helpKey: 'h587_b_members'),
                  _plainRow('friends', Icons.favorite_rounded, PawMapLegend.friend,
                      titleKey: 'pawmap585_btn_friends'),
                  _railRow(context, 'spots'),
                  _railRow(context, 'feed'),
                ],
              ),

              // ── 3. Être visible / en direct ────────────────────────────
              _SectionCard(
                anchorKey: _anchors['live'],
                id: 'live',
                number: 3,
                icon: Icons.sensors_rounded,
                title: 'help587_sec_live'.tr,
                example:
                    provider ? 'help587_ex_live_walker'.tr : 'help587_ex_live_owner'.tr,
                children: [
                  _capsuleRow(context, 'eye'),
                  // v587 — Daniel : les 3 réglages expliqués, mêmes phrases que le réglage.
                  const _VisibilityCard(key: ValueKey<String>('help_visibility')),
                  // 610 — RÈGLE A (Daniel, 04/10) : amis à la vraie position.
                  _plainRow('friendspos610', Icons.favorite_rounded,
                      PawMapLegend.friend,
                      titleKey: 'help610_friends_pos_t',
                      helpKey: 'help610_friends_pos_b'),
                  // v587 — le Direct existe pour les 3 profils (Daniel, 25/09).
                  _capsuleRow(context, 'direct',
                      helpKey: 'help589_b_direct', extraKey: 'help589_followers'),
                  // v584 (25/09, point 14) — « Suivre ma promenade ».
                  const _LiveShareCard(key: ValueKey<String>('help_live_share')),
                ],
              ),

              // ── 4. La Balade (v599, Daniel 29/09) ─────────────────────
              _SectionCard(
                anchorKey: _anchors['balade'],
                id: 'balade',
                number: 4,
                icon: Icons.directions_walk_rounded,
                title: 'help599_sec_balade'.tr,
                example: 'help599_ex_balade'.tr,
                children: [
                  const _BaladeCard(key: ValueKey<String>('help_balade_image')),
                  _ButtonRow(
                    key: const ValueKey<String>('help_balade_me'),
                    icon: _RoundIcon(
                        icon: Icons.directions_walk_rounded,
                        color: roleColor,
                        filled: true),
                    title: 'help599_t_me'.tr,
                    help: 'help599_b_me'.tr,
                  ),
                  _ButtonRow(
                    key: const ValueKey<String>('help_balade_others'),
                    icon: const _RoundIcon(
                        icon: Icons.visibility_rounded,
                        color: PawMapLegend.pawFollow,
                        filled: true),
                    title: 'help599_t_others'.tr,
                    help: 'help599_b_others'.tr,
                  ),
                  _ButtonRow(
                    key: const ValueKey<String>('help_balade_dot'),
                    // v605 — « Le contour de la patte du menu » : une
                    // petite patte au contour vert (le vrai dessin du menu).
                    icon: const _GreenRimPaw(
                        key: ValueKey<String>('help_balade_dot_paw')),
                    title: 'help599_t_dot'.tr,
                    // 610 — un ami : la carte file sur lui ; plusieurs : liste.
                    help: 'help610_greenpaw_b'.tr,
                  ),
                ],
              ),

              // ── 5. Les peluches de la Balade + PawPoints (607) ───────────
              _SectionCard(
                anchorKey: _anchors['plush'],
                id: 'plush',
                number: 5,
                icon: Icons.toys_rounded,
                title: 'help607_plush_title'.tr,
                children: [
                  _ButtonRow(
                    key: const ValueKey<String>('help607_plush'),
                    icon: Image.asset('assets/images/plush607_teddy.png',
                        width: 40.w, height: 40.w, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _RoundIcon(
                            icon: Icons.toys_rounded,
                            color: PawMapTheme.accent,
                            filled: true)),
                    title: 'pp607_help_plush_row'.tr,
                    help: 'help607_plush_body'.tr,
                  ),
                  // 607 (ZOE, demande de Daniel) — les 5 peluches + la dorée,
                  // nom dessous, puis le barème complet (textes de LEO).
                  const _PlushGallery(key: ValueKey<String>('help607_plush_gallery')),
                  _ButtonRow(
                    key: const ValueKey<String>('help607_plush_bonus'),
                    icon: Image.asset('assets/images/plush607_teddy_gold.png',
                        width: 40.w, height: 40.w, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _RoundIcon(
                            icon: Icons.emoji_events_rounded,
                            color: Color(0xFFE8A00A),
                            filled: true)),
                    title: 'help607_plush_gold'.tr,
                    help: 'help607_plush_bonus'.tr,
                  ),
                ],
              ),

              // ── 6. Les rangs (612 : section à part, pastilles réelles) ──
              _SectionCard(
                anchorKey: _anchors['ranks'],
                id: 'ranks',
                number: 6,
                icon: Icons.military_tech_rounded,
                title: 'help611_ranks_t'.tr,
                children: [
                  // Les 5 rangs : la VRAIE pastille de l'app + le seuil
                  // (kPawRankMins611, miroir testé du serveur ranks611.js).
                  for (var i = 0; i < kPawRankKeys611.length; i++)
                    _RankRow612(
                      key: ValueKey<String>('help612_rank_${kPawRankKeys611[i]}'),
                      level: i + 1,
                    ),
                  _ButtonRow(
                    key: const ValueKey<String>('help611_ranks'),
                    icon: const _RoundIcon(
                        icon: Icons.military_tech_rounded,
                        color: Color(0xFFE07A2E),
                        filled: true),
                    title: 'help611_ranks_t'.tr,
                    help: 'help611_ranks_b'.tr,
                  ),
                  _ButtonRow(
                    // 612 — la ligne PawPoints de la section 5 vient ici :
                    // « comment gagner des points », juste sous les rangs.
                    key: const ValueKey<String>('help607_pawpoints'),
                    icon: const _RoundIcon(
                        icon: Icons.stars_rounded,
                        color: Color(0xFFE8A00A),
                        filled: true),
                    title: 'help612_earn_t'.tr,
                    help: 'pp607_help_points_body'.tr,
                  ),
                ],
              ),

              // ── 7. Ramène tes clients · badge Pionnier (607) ─────────────
              _SectionCard(
                anchorKey: _anchors['pioneer'],
                id: 'pioneer',
                number: 7,
                icon: Icons.flag_rounded,
                title: 'help607_pioneer_title'.tr,
                children: [
                  _ButtonRow(
                    key: const ValueKey<String>('help607_pioneer'),
                    icon: const _RoundIcon(
                        icon: Icons.flag_rounded,
                        color: PawMapTheme.accent,
                        filled: true),
                    title: 'help607_pioneer_badge'.tr,
                    help: 'help607_pioneer_body'.tr,
                  ),
                  // 609 — badge « Identité vérifiée » sur la carte (PAM), textes de verified609_i18n.
                  _ButtonRow(
                    key: const ValueKey<String>('help609_verified'),
                    icon: const _RoundIcon(
                        icon: Icons.verified_rounded,
                        color: Color(0xFF2563EB),
                        filled: true),
                    title: 'help609_verified_title'.tr,
                    help: 'help609_verified_body'.tr,
                  ),
                ],
              ),

              // ── 7. Agir ────────────────────────────────────────────────
              _SectionCard(
                anchorKey: _anchors['act'],
                id: 'act',
                number: 8,
                icon: Icons.touch_app_rounded,
                title: 'help587_sec_act'.tr,
                example: 'help587_ex_act'.tr,
                children: [
                  if (!provider) _capsuleRow(context, 'publish'),
                  if (provider)
                    _capsuleRow(context, 'requests', helpKey: 'pawmap589_requests_help'),
                  _railRow(context, 'chat'),
                  _railRow(context, 'photo'),
                  _railRow(context, 'tag'),
                  _railRow(context, 'report'),
                  // 610 — RÈGLE B : voir = tous ; danger = gratuit, illimité.
                  _plainRow('alerts610', Icons.health_and_safety_rounded,
                      PawMapTheme.danger,
                      filled: true,
                      titleKey: 'help610_alerts_t',
                      helpKey: 'help610_alerts_b'),
                  _dockRow(context, 'sos'),
                  _dockRow(context, 'share'),
                ],
              ),

              // ── 8. Réglages ────────────────────────────────────────────
              _SectionCard(
                anchorKey: _anchors['set'],
                id: 'set',
                number: 9,
                icon: Icons.tune_rounded,
                title: 'help587_sec_set'.tr,
                example: 'help587_ex_set'.tr,
                children: [
                  _plainRow('options2', Icons.settings_rounded, PawMapTheme.accent,
                      filled: true, titleKey: 'pawmap589_options', helpKey: 'help589_b_options'),
                  _plainRow('bars', Icons.chevron_left_rounded, PawMapLegend.ink),
                  _plainRow('custom', Icons.swap_vert_rounded, PawMapTheme.accent,
                      helpKey: 'help589_b_custom'),
                  _dockRow(context, 'layers'),
                  _dockRow(context, 'night'),
                  _dockRow(context, 'history'),
                  _plainRow('subs', Icons.workspace_premium_rounded, PawMapTheme.pawFollow,
                      titleKey: 'pawmap585_btn_subs'),
                ],
              ),

              // ── FAQ ────────────────────────────────────────────────────
              _SectionCard(
                anchorKey: _anchors['faq'],
                id: 'faq',
                icon: Icons.help_rounded,
                title: 'help587_faq_title'.tr,
                titleKey: const ValueKey<String>('help_faq'),
                dividers: false,
                children: [
                  for (final n in const <int>[1, 2, 3, 4])
                    _FaqCard(
                      key: ValueKey<String>('help_faq_$n'),
                      question: 'help587_q$n'.tr,
                      // v587 — « Qui voit ma position ? » = les phrases du réglage.
                      answer: n == 2 ? pawMapVisibilityExplained() : 'help587_a$n'.tr,
                    ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
      bottom: PawSignatureButton(
        key: const ValueKey<String>('pawmap_help_see_map'),
        label: 'pawmap_help_see_map'.tr,
        icon: Icons.map_rounded,
        color: PawMapTheme.accent,
        onTap: () => _seeMap(context),
      ),
    );
  }
}

// ── Épingles supplémentaires (mêmes peintres que la carte) ─────────────────

/// Ami : halo rose, contour bicolore gardien + promeneur (ses rôles), point
/// vert « en ligne » — comme `photoPinHtml({roles:[sitter,walker]})` du site.
PawLegendEntry _friendEntry() {
  const s = PawMapLegend.friendSize;
  return PawLegendEntry(
    key: 'friend',
    label: 'help2709_friend_t'.tr,
    width: PawMapPinPainter.photoBitmapSize(s),
    height: PawMapPinPainter.photoBitmapSize(s),
    paint: (c) => PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.friend,
        ringColors: const [PawMapLegend.sitter, PawMapLegend.walker],
        size: s,
        online: true,
        fallbackTint: PawMapLegend.friend),
  );
}

/// Gardien + promeneur : UNE bulle bleu / vert avec les deux prix.
PawLegendEntry _duoEntry() {
  const s = PawMapLegend.memberSize;
  const price = '20 €|12 €';
  final pw = PawMapPinPainter.photoBitmapSize(s);
  final w = math.max(pw, PawMapPinPainter.priceBubbleWidth(price) + 10);
  return PawLegendEntry(
    key: 'duo2709',
    label: 'help2709_duo_t'.tr,
    width: w,
    height: pw + PawMapPinPainter.priceBubbleZone,
    paint: (c) {
      c.save();
      c.translate((w - pw) / 2, 0);
      PawMapPinPainter.paintPhotoDot(c,
          avatar: null,
          ringColor: PawMapLegend.sitter,
          ringColors: const [PawMapLegend.sitter, PawMapLegend.walker],
          size: s,
          priceBubble: price,
          fallbackTint: PawMapLegend.sitter,
          fallbackIcon: Icons.home_rounded);
      c.restore();
    },
  );
}

/// PawSpot avec son nom dessous (étiquette noire, contour et texte or),
/// comme au zoom rue sur la carte.
PawLegendEntry _spotNamedEntry(String label) {
  const s = PawMapLegend.spotSize;
  const name = 'Parc Monceau';
  final dw = PawMapPinPainter.dropBitmapWidth(s);
  final dh = PawMapPinPainter.dropHeight(s);
  final w = math.max(dw, PawMapPinPainter.spotLabelWidth(name) + 4);
  return PawLegendEntry(
    key: 'spot',
    label: label,
    width: w,
    height: dh + PawMapPinPainter.spotLabelZone,
    paint: (c) {
      c.save();
      c.translate((w - dw) / 2, 0);
      PawMapPinPainter.paintPawSpotDrop(c, type: 'path_walk');
      c.restore();
      PawMapPinPainter.paintPawSpotLabel(c,
          label: name, cx: w / 2, top: dh - PawMapPinPainter.dropMargin + 3);
    },
  );
}

/// PawFollow : lueur violette (suivi en direct).
PawLegendEntry _followEntry() {
  const s = PawMapLegend.memberSize;
  return PawLegendEntry(
    key: 'follow2709',
    label: 'help2709_follow_t'.tr,
    width: PawMapPinPainter.photoBitmapSize(s),
    height: PawMapPinPainter.photoBitmapSize(s),
    paint: (c) => PawMapPinPainter.paintPhotoDot(c,
        avatar: null,
        ringColor: PawMapLegend.walker,
        size: s,
        followPhase: 0.25,
        fallbackTint: PawMapLegend.walker,
        fallbackIcon: Icons.directions_walk_rounded),
  );
}

// ── Briques visuelles ──────────────────────────────────────────────────────

/// v587 — texte courant de l'aide : encre chaude #3B2A26 (jamais de gris),
/// crème chaude en mode sombre.
Color _warmBody(BuildContext context) =>
    PawMapTheme.isDark(context) ? const Color(0xFFEBDDD6) : const Color(0xFF3B2A26);

/// Encre des titres : #231715 le jour, crème la nuit.
Color _titleInk(BuildContext context) =>
    PawMapTheme.isDark(context) ? const Color(0xFFFBEFE6) : _inkWarm;

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Apparition douce (fondu + léger glissé) quand le bloc entre à l'écran en
/// défilant. Rien ne bouge si l'OS demande de réduire les animations.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.child});

  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;
  ScrollPosition? _pos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown) return;
    _pos?.removeListener(_check);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _shown) return;
    final ro = context.findRenderObject();
    if (_pos == null) {
      _show();
      return;
    }
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final top = ro.localToGlobal(Offset.zero).dy;
    final screenH = MediaQuery.sizeOf(context).height;
    if (top < screenH * 0.96) _show();
  }

  void _show() {
    _pos?.removeListener(_check);
    _pos = null;
    if (mounted) setState(() => _shown = true);
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Surface commune des cartes : crème le jour, brun chaud la nuit, liseré
/// orange léger, ombre chaude (jamais noire ni grise).
BoxDecoration _cardDecoration(BuildContext context, {Color? border}) {
  final dark = PawMapTheme.isDark(context);
  return BoxDecoration(
    color: dark ? _cardDark : _cream,
    borderRadius: BorderRadius.circular(22.r),
    border: Border.all(
      color: border ??
          (dark
              ? const Color(0xFFFF9A85).withValues(alpha: 0.18)
              : PawMapTheme.accent.withValues(alpha: 0.16)),
    ),
    boxShadow: [
      BoxShadow(
        color: (dark ? const Color(0xFF0E0605) : const Color(0xFF9A3412))
            .withValues(alpha: dark ? 0.35 : 0.10),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// En-tête : mini-carte dessinée + intro + astuce + mémo noir et or.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: _cardDecoration(context).copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark ? const [_cardDark, _cardDarkDeep] : const [_cream, _creamDeep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'help587_intro'.tr,
                      style: PawMapTheme.fontOn(context,
                          size: 14.sp,
                          weight: FontWeight.w700,
                          height: 1.35,
                          color: _titleInk(context)),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'help587_tip'.tr,
                      style: PawMapTheme.fontOn(context,
                          size: 12.5.sp,
                          weight: FontWeight.w500,
                          height: 1.35,
                          color: _warmBody(context)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              ExcludeSemantics(
                child: CustomPaint(
                  size: Size(84.w, 70.w),
                  painter: _MiniMapPainter(dark: dark),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: PawMapLegend.ink,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              'pawmap_legend_memo'.tr,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: PawMapLegend.gold,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Petite carte illustrée : rues, un rond par rôle, un ami avec son halo
/// rose, un PawSpot noir et or.
class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.2));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRRect(
        rr, Paint()..color = dark ? const Color(0xFF3A2620) : const Color(0xFFFFEBDD));
    final street = Paint()
      ..color = dark ? const Color(0xFF55362B) : const Color(0xFFF6D2BC)
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-4, h * 0.62), Offset(w + 4, h * 0.38), street);
    canvas.drawLine(Offset(w * 0.3, -4), Offset(w * 0.46, h + 4), street);
    canvas.drawLine(Offset(w * 0.72, -4), Offset(w * 0.8, h + 4), street..strokeWidth = w * 0.045);
    // Parc.
    canvas.drawCircle(Offset(w * 0.12, h * 0.18), w * 0.14,
        Paint()..color = const Color(0xFF16A34A).withValues(alpha: dark ? 0.35 : 0.22));
    canvas.restore();

    void dot(Offset c, Color col, {Color? glow}) {
      final r = w * 0.075;
      if (glow != null) {
        canvas.drawCircle(c, r * 2.1,
            Paint()
              ..color = glow.withValues(alpha: 0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
      canvas.drawCircle(c, r + 1.8, Paint()..color = Colors.white);
      canvas.drawCircle(c, r, Paint()..color = col);
    }

    dot(Offset(w * 0.22, h * 0.72), PawMapLegend.owner);
    dot(Offset(w * 0.56, h * 0.26), PawMapLegend.sitter);
    dot(Offset(w * 0.86, h * 0.68), PawMapLegend.walker);
    dot(Offset(w * 0.6, h * 0.74), PawMapLegend.friend, glow: PawMapLegend.friend);
    // PawSpot : goutte noire liserée d'or.
    final sc = Offset(w * 0.84, h * 0.2);
    final r = w * 0.07;
    final drop = Path()
      ..moveTo(sc.dx, sc.dy + r * 2.1)
      ..quadraticBezierTo(sc.dx - r * 1.4, sc.dy + r * 0.6, sc.dx - r, sc.dy)
      ..arcToPoint(Offset(sc.dx + r, sc.dy), radius: Radius.circular(r))
      ..quadraticBezierTo(sc.dx + r * 1.4, sc.dy + r * 0.6, sc.dx, sc.dy + r * 2.1)
      ..close();
    canvas.drawPath(drop, Paint()..color = PawMapLegend.ink);
    canvas.drawPath(
        drop,
        Paint()
          ..color = PawMapLegend.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) => old.dark != dark;
}

/// v597 — encadré vert « Ta position reste privée » (cadenas), comme le site.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF15291B) : const Color(0xFFE9F7EE),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
            color: (dark ? const Color(0xFF43B862) : const Color(0xFF2E9E48))
                .withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF43B862), Color(0xFF1F7A37)],
              ),
            ),
            child: Icon(Icons.lock_rounded, color: Colors.white, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('help2709_priv_t'.tr,
                    style: PawMapTheme.fontOn(context,
                        size: 14.sp,
                        weight: FontWeight.w800,
                        color: dark ? const Color(0xFF7FE39A) : const Color(0xFF1F7A37))),
                SizedBox(height: 3.h),
                Text('help2709_priv_b'.tr,
                    style: PawMapTheme.fontOn(context,
                        size: 12.5.sp,
                        weight: FontWeight.w500,
                        height: 1.4,
                        color: dark ? const Color(0xFFDDEFE2) : const Color(0xFF1B4D2B))),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ExcludeSemantics(
            child: CustomPaint(
              size: Size(52.w, 52.w),
              painter: _RadiusPainter(dark: dark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le rayon « ≈ 1 km » : cercle vert en pointillés, maison décalée, rond
/// affiché ailleurs dans le cercle.
class _RadiusPainter extends CustomPainter {
  const _RadiusPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    const green = Color(0xFF2E9E48);
    canvas.drawCircle(c, r, Paint()..color = green.withValues(alpha: dark ? 0.22 : 0.14));
    final dash = Paint()
      ..color = dark ? const Color(0xFF7FE39A) : green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    const n = 18;
    for (int i = 0; i < n; i++) {
      final a0 = i * 2 * math.pi / n;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0, math.pi / n * 0.9, false, dash);
    }
    // Maison (la vraie adresse, jamais montrée) : petit pictogramme au centre.
    final hs = size.width * 0.2;
    final house = Path()
      ..moveTo(c.dx, c.dy - hs * 0.7)
      ..lineTo(c.dx + hs * 0.7, c.dy)
      ..lineTo(c.dx + hs * 0.5, c.dy)
      ..lineTo(c.dx + hs * 0.5, c.dy + hs * 0.6)
      ..lineTo(c.dx - hs * 0.5, c.dy + hs * 0.6)
      ..lineTo(c.dx - hs * 0.5, c.dy)
      ..lineTo(c.dx - hs * 0.7, c.dy)
      ..close();
    canvas.drawPath(house, Paint()..color = dark ? const Color(0xFFDDEFE2) : const Color(0xFF1F7A37));
    // Le rond affiché, quelque part dans le rayon.
    final p = c + Offset(r * 0.52, -r * 0.5);
    canvas.drawCircle(p, size.width * 0.11, Paint()..color = Colors.white);
    canvas.drawCircle(p, size.width * 0.08, Paint()..color = PawMapLegend.sitter);
  }

  @override
  bool shouldRepaint(covariant _RadiusPainter old) => old.dark != dark;
}

/// Une section = une carte arrondie : pastille numérotée, titre, rangées
/// séparées par un filet chaud, puis l'encadré 💡.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.anchorKey,
    required this.id,
    required this.icon,
    required this.title,
    required this.children,
    this.number,
    this.example,
    this.titleKey,
    this.dividers = true,
  });

  /// v605 — ancre du sommaire (défilement jusqu'à la section).
  final Key? anchorKey;
  final String id;
  final int? number;
  final IconData icon;
  final String title;
  final String? example;
  final List<Widget> children;
  final Key? titleKey;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final line = PawMapTheme.isDark(context) ? _lineDark : _lineLight;
    final body = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (dividers && i > 0) {
        body.add(Divider(height: 1, thickness: 1, color: line, indent: 72.w));
      }
      body.add(_Reveal(child: children[i]));
    }
    return Padding(
      key: anchorKey,
      padding: EdgeInsets.only(top: 16.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 12.h),
        decoration: _cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Reveal(
              child: _SectionTitle(
                title,
                key: titleKey ?? ValueKey<String>('help_sec_$id'),
                icon: icon,
                number: number,
              ),
            ),
            SizedBox(height: 6.h),
            ...body,
            if (example != null)
              _Reveal(child: _Example(example!, key: ValueKey<String>('help_ex_$id'))),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key, required this.icon, this.number});

  final String text;
  final IconData icon;
  final int? number;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13.r),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE0553F), PawMapTheme.accent, Color(0xFF9E1F0B)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: PawMapTheme.accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            if (number != null)
              Positioned(
                right: -5,
                top: -5,
                child: Container(
                  width: 17.w,
                  height: 17.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PawMapLegend.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: PawMapLegend.gold, width: 1.2),
                  ),
                  child: Text('$number',
                      style: TextStyle(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                          color: PawMapLegend.gold,
                          height: 1)),
                ),
              ),
          ],
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: PawMapTheme.fontOn(context,
                size: 17.sp, weight: FontWeight.w800, color: _titleInk(context)),
          ),
        ),
      ],
    );
  }
}

/// Case de 64 × 64 où l'épingle est posée (réduite si elle est plus grande).
class _PinBox extends StatelessWidget {
  const _PinBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64.w,
      height: 64.w,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

/// Pastille ronde d'icône (même dessin que les raccourcis du dock) ; `filled`
/// = bouton d'action plein (Publier, Direct, Ma position).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, this.filled = false});

  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    // 610 (03/10) — Daniel : « bouton gris ». Une icône à l'encre (zoom,
    // œil, flèches, mode nuit…) donnait un rond gris (encre à 14 %). Elle
    // prend désormais l'orange de la marque, comme les autres ronds : ZÉRO GRIS.
    final bool inky = !filled && this.color.computeLuminance() < 0.02;
    final Color color = inky ? PawMapTheme.accent : this.color;
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.14)!, color])
            : null,
        color: filled ? null : color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
            color: filled ? Colors.white : color.withValues(alpha: 0.45),
            width: filled ? 2 : 1),
        boxShadow: filled
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: Icon(icon,
          size: 22.sp,
          color: filled ? Colors.white : PawMapTheme.toneOn(context, color)),
    );
  }
}

/// Les 3 boutons « Profil » : un rôle, deux rôles, trois rôles — ordre fixe
/// orange → bleu → vert (couleurs exactes de la carte).
class _RolePills extends StatelessWidget {
  const _RolePills();

  Widget _pill(List<Color> colors, int n) {
    final stops = <double>[];
    final cols = <Color>[];
    for (int i = 0; i < colors.length; i++) {
      stops..add(i / colors.length)..add((i + 1) / colors.length);
      cols..add(colors[i])..add(colors[i]);
    }
    return Container(
      width: 54.w,
      height: 18.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: LinearGradient(colors: cols, stops: stops),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < n; i++)
            Icon(Icons.person_rounded, size: 11.sp, color: Colors.white),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(const [PawMapLegend.owner], 1),
          SizedBox(height: 4.h),
          _pill(const [PawMapLegend.sitter, PawMapLegend.walker], 2),
          SizedBox(height: 4.h),
          _pill(const [PawMapLegend.owner, PawMapLegend.sitter, PawMapLegend.walker], 3),
        ],
      ),
    );
  }
}

/// « Un seul halo à la fois » : turquoise PawBoost › violet PawFollow › rose
/// ami, avec la couronne dorée PawPremium au-dessus. Les halos respirent
/// doucement (immobiles si l'OS réduit les animations). Turquoise = la
/// couleur que dessine l'app (`PawMapLegend.boost`, `drawBoostGlow`).
class _HaloTrio extends StatefulWidget {
  const _HaloTrio();

  @override
  State<_HaloTrio> createState() => _HaloTrioState();
}

class _HaloTrioState extends State<_HaloTrio> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sep = Text('›',
        style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: _titleInk(context),
            height: 1));
    return SizedBox(
      width: 64.w,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final s = Curves.easeInOut.transform(_c.value);
          Widget dot(Color col, double alpha) => Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: col.withValues(alpha: alpha),
                      blurRadius: 5 + 5 * s,
                      spreadRadius: 1 + 2 * s,
                    ),
                  ],
                ),
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  size: 16.sp, color: const Color(0xFFE2A21A)),
              SizedBox(height: 4.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot(PawMapLegend.boost, 0.75),
                    SizedBox(width: 3.w),
                    sep,
                    SizedBox(width: 3.w),
                    dot(PawMapLegend.pawFollow, 0.55),
                    SizedBox(width: 3.w),
                    sep,
                    SizedBox(width: 3.w),
                    dot(PawMapLegend.friend, 0.62),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Encadré « Exemple » 💡 de fin de section (couleurs chaudes, le texte passe
/// à la ligne).
class _Example extends StatelessWidget {
  const _Example(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2620) : _creamDeep,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: PawMapTheme.pawSpot.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡', style: TextStyle(fontSize: 16.sp, height: 1.2)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${'help587_ex_label'.tr} · ',
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp,
                      weight: FontWeight.w800,
                      color: dark ? const Color(0xFFFF9A85) : PawMapTheme.accent),
                ),
                TextSpan(
                  text: text,
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp,
                      weight: FontWeight.w500,
                      height: 1.35,
                      color: _warmBody(context)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une question de la FAQ et sa réponse (toujours ouvertes : rien à deviner).
class _FaqCard extends StatelessWidget {
  const _FaqCard({super.key, required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2620) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: PawMapTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PawMapTheme.accent.withValues(alpha: dark ? 0.3 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.question_mark_rounded,
                size: 14.sp, color: dark ? const Color(0xFFFF9A85) : PawMapTheme.accent),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(question,
                    style: PawMapTheme.fontOn(context,
                        size: 13.5.sp, weight: FontWeight.w800, color: _titleInk(context))),
                SizedBox(height: 4.h),
                Text(answer,
                    style: PawMapTheme.fontOn(context,
                        size: 12.5.sp,
                        weight: FontWeight.w500,
                        height: 1.35,
                        color: _warmBody(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// v587 — les 3 réglages « Qui me voit sur la carte », mot pour mot comme
/// dans l'œil, la feuille et Profil › Préférences (vis587_i18n).
String pawMapVisibilityExplained() => [
      '${'vis587_all_t'.tr} — ${'vis587_all_d'.tr}',
      '${'vis587_friends_t'.tr} — ${'vis587_friends_d'.tr}',
      '${'vis587_hidden_t'.tr} — ${'vis587_hidden_d'.tr}',
      'vis587_live'.tr,
      'vis587_where'.tr,
    ].join('\n');

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    Widget line(IconData icon, Color c, String t, String d) => Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26.w,
                height: 26.w,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: dark ? 0.28 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15.sp, color: PawMapTheme.toneOn(context, c)),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text.rich(
                  TextSpan(children: <InlineSpan>[
                    TextSpan(
                        text: '$t — ',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: _titleInk(context))),
                    TextSpan(text: d),
                  ]),
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp,
                      weight: FontWeight.w500,
                      height: 1.35,
                      color: _warmBody(context)),
                ),
              ),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2620) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: PawMapLegend.friend.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('vis587_title'.tr,
              style: PawMapTheme.fontOn(context,
                  size: 13.5.sp, weight: FontWeight.w800, color: _titleInk(context))),
          SizedBox(height: 8.h),
          line(Icons.visibility_rounded, PawMapLegend.sitter,
              'vis587_all_t'.tr, 'vis587_all_d'.tr),
          line(Icons.favorite_rounded, PawMapLegend.friend,
              'vis587_friends_t'.tr, 'vis587_friends_d'.tr),
          line(Icons.visibility_off_rounded, PawMapTheme.accent, // 610 — plus de gris
              'vis587_hidden_t'.tr, 'vis587_hidden_d'.tr),
          Text('${'vis587_live'.tr}\n${'vis587_where'.tr}',
              style: PawMapTheme.fontOn(context,
                  size: 12.sp, weight: FontWeight.w700, height: 1.35,
                  color: _warmBody(context))),
        ],
      ),
    );
  }
}

/// « Partager ma balade en direct » (v584, point 14).
class _LiveShareCard extends StatelessWidget {
  const _LiveShareCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: PawMapLegend.pawFollow
            .withValues(alpha: PawMapTheme.isDark(context) ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: PawMapLegend.pawFollow.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9B6BF5), PawMapLegend.pawFollow],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: PawMapLegend.pawFollow.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(Icons.share_location_rounded, color: Colors.white, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('pawmap_help_live_title'.tr,
                    style: PawMapTheme.fontOn(context,
                        size: 14.sp, weight: FontWeight.w800, color: _titleInk(context))),
                SizedBox(height: 2.h),
                Text(
                  'pawmap_help_live_body'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp,
                      weight: FontWeight.w500,
                      height: 1.35,
                      color: _warmBody(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// v599 — L'image de « La Balade » : ce que je vois / ce que voient les
/// autres, dessinée par les vrais peintres (nette à 2× et 3×, clair et nuit,
/// 9 langues), avec sa légende.
class _BaladeCard extends StatelessWidget {
  const _BaladeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final role = ((Get.isRegistered<AuthController>()
                ? Get.find<AuthController>().userRole.value
                : null) ??
            'owner')
        .toLowerCase();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PawMapBaladeIllustration(
            dark: PawMapTheme.isDark(context),
            role: role.isEmpty ? 'owner' : role,
          ),
          SizedBox(height: 6.h),
          Text(
            'help599_img_caption'.tr,
            style: PawMapTheme.fontOn(context,
                size: 11.5.sp,
                weight: FontWeight.w500,
                height: 1.3,
                color: _warmBody(context)),
          ),
        ],
      ),
    );
  }
}

/// Une rangée : l'illustration à gauche (bouton, épingle, dessin), le titre
/// (à la couleur de ce qu'il décrit) et l'explication à droite.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    super.key,
    required this.icon,
    required this.title,
    this.help,
    this.titleColor,
    this.stacked = false,
  });

  final Widget icon;
  final String title;
  final String? help;
  final Color? titleColor;

  /// Illustration large (bulle double prix, nom d'un PawSpot) : posée
  /// au-dessus du texte pour rester lisible à 375 px.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    final Color tc = titleColor == null
        ? _titleInk(context)
        : (dark
            ? (titleColor == PawMapLegend.ink
                ? _titleInk(context)
                : PawMapTheme.toneOn(context, titleColor!))
            : titleColor!);
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: PawMapTheme.fontOn(context,
                size: 14.sp, weight: FontWeight.w800, color: tc)),
        if (help != null && help!.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            help!,
            style: PawMapTheme.fontOn(context,
                size: 12.5.sp,
                weight: FontWeight.w500,
                height: 1.35,
                color: _warmBody(context)),
          ),
        ],
      ],
    );
    if (stacked) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 9.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(left: 4.w), child: icon),
            SizedBox(height: 6.h),
            Padding(padding: EdgeInsets.only(left: 72.w), child: texts),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 64.w, child: Center(child: icon)),
          SizedBox(width: 8.w),
          Expanded(
            child: Padding(padding: EdgeInsets.only(top: 2.h), child: texts),
          ),
        ],
      ),
    );
  }
}


/// 607 (ZOE) — les 5 mini-peluches (dessins de PAM) + la dorée, nom dessous.
/// Retour à la ligne (Wrap) : jamais de débordement, même à 320 px.
class _PlushGallery extends StatelessWidget {
  const _PlushGallery({super.key});

  static const List<String> _types = <String>['teddy', 'bunny', 'kitty', 'puppy', 'fox'];

  @override
  Widget build(BuildContext context) {
    Widget item(String asset, String label, Key key) => SizedBox(
          key: key,
          width: 58.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(asset, width: 44.w, height: 44.w, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(width: 44.w, height: 44.w)),
              SizedBox(height: 4.h),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PawMapTheme.fontOn(context,
                    size: 10.5.sp, weight: FontWeight.w700, color: _warmBody(context)),
              ),
            ],
          ),
        );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6.w,
        runSpacing: 10.h,
        children: [
          for (var i = 0; i < _types.length; i++)
            item('assets/images/plush607_${_types[i]}.png',
                'help607_plush_names_${i + 1}'.tr,
                ValueKey<String>('help607_plush_${_types[i]}')),
          item('assets/images/plush607_teddy_gold.png', 'help607_plush_gold'.tr,
              const ValueKey<String>('help607_plush_golden')),
        ],
      ),
    );
  }
}

/// v605 — sommaire de « Comprendre la PawMap » : une puce par section
/// (numéro doré sur encre + titre), au dégradé orange de la PawMap. Un appui
/// fait défiler jusqu'à la section. Retour à la ligne, jamais de défilement
/// horizontal (règle de Daniel).
class _HelpToc extends StatelessWidget {
  const _HelpToc({super.key, required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = PawMapTheme.isDark(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered_rounded,
                  size: 18.sp, color: PawMapTheme.accent),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  'pm605_help_toc'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 14.sp,
                      weight: FontWeight.w800,
                      color: _titleInk(context)),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final s in kPawHelpSections)
                _TocChip(
                  key: ValueKey<String>('help_toc_${s.$1}'),
                  number: s.$2,
                  label: s.$3.tr,
                  dark: dark,
                  onTap: () => onTap(s.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TocChip extends StatelessWidget {
  const _TocChip({
    super.key,
    required this.number,
    required this.label,
    required this.dark,
    required this.onTap,
  });

  final int? number;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = dark ? const Color(0xFF3A2420) : const Color(0xFFFCE4D8);
    final Color ink = dark ? const Color(0xFFFBEFE6) : const Color(0xFF7A1D0C);
    return Semantics(
      button: true,
      label: number == null ? label : '$number. $label',
      child: Material(
        color: fill,
        shape: StadiumBorder(
            side: BorderSide(
                color: PawMapTheme.accent.withValues(alpha: dark ? 0.7 : 0.45),
                width: 1.2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 36.h),
            child: Padding(
              padding: EdgeInsets.fromLTRB(5.w, 4.h, 12.w, 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24.w,
                    height: 24.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE0553F), PawMapTheme.accent, Color(0xFF9E1F0B)],
                      ),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: number == null
                        ? Icon(Icons.help_rounded, size: 14.sp, color: Colors.white)
                        : Text('$number',
                            style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1)),
                  ),
                  SizedBox(width: 7.w),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.fontOn(context,
                          size: 12.5.sp, weight: FontWeight.w700, color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v605 — la patte du menu en petit, CONTOUR VERT (un ami est en direct) :
/// le même dessin que le menu (`PawGlyph`), jamais un simple point.
class _GreenRimPaw extends StatelessWidget {
  const _GreenRimPaw({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44.w,
      height: 44.w,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: kPawTabBarPawBox,
          height: kPawTabBarPawBox,
          child: PawGlyph(
            size: kPawTabBarPawBox,
            rimColor: PawLiveDot.green,
            toeProgress: const <double>[1, 1, 1, 1],
            toeOpacity: const <double>[1, 1, 1, 1],
          ),
        ),
      ),
    );
  }
}


/// 612 — une ligne par rang : la pastille telle qu'affichée dans l'app
/// (profil, fiche de la carte) et « dès N PawPoints ».
class _RankRow612 extends StatelessWidget {
  const _RankRow612({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final int min = kPawRankMins611[level - 1];
    final String n = NumberFormat.decimalPattern(Get.locale?.toLanguageTag())
        .format(min);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Flexible(
            child: PawRankPill611(
              rank: PawRank611(
                key: kPawRankKeys611[level - 1],
                level: level,
                pointsEarned: min,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              'help612_rank_from'.tr.replaceAll('{n}', n),
              style: PawMapTheme.fontOn(context,
                  size: 12.5.sp, weight: FontWeight.w700, color: _warmBody(context)),
            ),
          ),
        ],
      ),
    );
  }
}
