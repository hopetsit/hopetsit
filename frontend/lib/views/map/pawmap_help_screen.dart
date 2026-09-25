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
// gardien / promeneur, Publier = propriétaire), comme sur la carte.
// En bas, « Voir sur la carte » ouvre l'onglet PawMap.
//
// Noms, icônes et couleurs des boutons : UNE source, `kPawRailSpecs` /
// `kPawDockSpecs` (`pawmap_rail.dart`) et `kPawCapsuleSpecs` — les mêmes que
// le menu de personnalisation du rail et l'appui long sur la carte.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/map_ui_state.dart';
import '../../utils/pawmap_theme.dart';
import '../profile/widgets/profile_ui_kit.dart';
import 'paw_map_screen.dart';
import 'widgets/paw_rail_button.dart';
import 'widgets/pawmap_buttons.dart';
import 'widgets/pawmap_discreet.dart';
import 'widgets/pawmap_pins.dart';
import 'widgets/pawmap_rail.dart';
import 'widgets/pawmap_sheets.dart';

class PawMapHelpScreen extends StatelessWidget {
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

  void _seeMap(BuildContext context) {
    if (fromMap && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    openMainTabOr(kPawMapTabIndex, () => const PawMapScreen());
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
    final spec = pawRailSpecOf(id)!;
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

  Widget _capsuleRow(BuildContext context, String id, {String? helpKey}) {
    final c = pawCapsuleSpecOf(id)!;
    final strong = id == 'publish' || id == 'direct';
    return _ButtonRow(
      key: ValueKey<String>('help_capsule_$id'),
      icon: _RoundIcon(icon: c.icon, color: c.color, filled: strong),
      title: id == 'fade' ? 'help587_t_fade'.tr : c.label,
      help: (helpKey ?? 'help587_b_$id').tr,
    );
  }

  Widget _plainRow(String id, IconData icon, Color color,
      {String? titleKey, bool filled = false}) {
    return _ButtonRow(
      key: ValueKey<String>('help_x_$id'),
      icon: _RoundIcon(icon: icon, color: color, filled: filled),
      title: (titleKey ?? 'help587_t_$id').tr,
      help: 'help587_b_$id'.tr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = pawLegendEntries();
    final role = _roleNow;
    // Mêmes règles que la carte : gardien / promeneur = pilule « Direct » en
    // haut à gauche ; sinon (propriétaire, sans compte) = « Publier ».
    final provider = role == 'sitter' || role == 'walker';
    final roleColor = PawMapLegend.roleColor(role.isEmpty ? 'owner' : role);
    return ProfileSubPageScaffold(
      title: 'pawmap_help_title'.tr,
      accent: PawMapTheme.accent,
      body: Column(
        key: const ValueKey<String>('pawmap_help_body'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'help587_intro'.tr,
            style: PawMapTheme.fontOn(context,
                size: 14.sp, weight: FontWeight.w600, color: _warmBody(context)),
          ),
          SizedBox(height: 6.h),
          Text(
            'help587_tip'.tr,
            style: PawMapTheme.fontOn(context,
                size: 12.5.sp, weight: FontWeight.w500, color: _warmBody(context)),
          ),
          SizedBox(height: 12.h),
          Container(
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

          // ── 1. Se repérer ──────────────────────────────────────────────
          _SectionTitle('help587_sec_find'.tr,
              key: const ValueKey<String>('help_sec_find')),
          _plainRow('pins', Icons.place_rounded, PawMapTheme.accent),
          for (final e in entries)
            PawLegendRow(
              key: ValueKey<String>('legend_${e.key}'),
              label: e.label,
              child: PawPinPreview(entry: e),
            ),
          // Signalement : inchangé (emoji du type), décrit sans image.
          PawLegendRow(
            key: const ValueKey<String>('legend_report'),
            label: 'pawmap_legend_report'.tr,
            child: Icon(Icons.warning_amber_rounded,
                size: 26.sp, color: PawMapTheme.danger),
          ),
          SizedBox(height: 6.h),
          _plainRow('locate', Icons.my_location_rounded, roleColor, filled: true),
          _plainRow('zoom', Icons.zoom_in_rounded, PawMapLegend.ink),
          _plainRow('sat', Icons.satellite_alt_rounded, PawMapTheme.accent),
          _plainRow('search', Icons.search_rounded, PawMapTheme.sitter),
          _railRow(context, 'around'),
          _railRow(context, 'directions'),
          _capsuleRow(context, 'fade'),
          _Example('help587_ex_find'.tr, key: const ValueKey<String>('help_ex_find')),

          // ── 2. Voir qui est autour ─────────────────────────────────────
          _SectionTitle('help587_sec_see'.tr,
              key: const ValueKey<String>('help_sec_see')),
          _capsuleRow(context, 'see'),
          _railRow(context, 'live_friends'),
          _plainRow('fit', Icons.groups_rounded, PawMapTheme.rose,
              titleKey: 'v565_live_friends_fit'),
          _plainRow('friends', Icons.favorite_rounded, PawMapLegend.friend,
              titleKey: 'pawmap585_btn_friends'),
          _railRow(context, 'spots'),
          _railRow(context, 'feed'),
          _Example('help587_ex_see'.tr, key: const ValueKey<String>('help_ex_see')),

          // ── 3. Être visible / en direct ────────────────────────────────
          _SectionTitle('help587_sec_live'.tr,
              key: const ValueKey<String>('help_sec_live')),
          _capsuleRow(context, 'eye'),
          if (provider) _capsuleRow(context, 'direct'),
          // v584 (25/09, point 14) — « Suivre ma promenade : Daniel ne sait
          // pas comment faire » : l'explication vit aussi ici.
          _LiveShareCard(key: const ValueKey<String>('help_live_share')),
          _Example(
              provider ? 'help587_ex_live_walker'.tr : 'help587_ex_live_owner'.tr,
              key: const ValueKey<String>('help_ex_live')),

          // ── 4. Agir ────────────────────────────────────────────────────
          _SectionTitle('help587_sec_act'.tr,
              key: const ValueKey<String>('help_sec_act')),
          if (!provider) _capsuleRow(context, 'publish'),
          _railRow(context, 'chat'),
          _railRow(context, 'photo'),
          _railRow(context, 'tag'),
          _railRow(context, 'report'),
          _dockRow(context, 'sos'),
          _dockRow(context, 'share'),
          _Example('help587_ex_act'.tr, key: const ValueKey<String>('help_ex_act')),

          // ── 5. Réglages ────────────────────────────────────────────────
          _SectionTitle('help587_sec_set'.tr,
              key: const ValueKey<String>('help_sec_set')),
          _capsuleRow(context, 'handle'),
          _plainRow('bars', Icons.chevron_left_rounded, PawMapLegend.ink),
          _plainRow('custom', Icons.tune_rounded, PawMapTheme.pawFollow),
          _dockRow(context, 'layers'),
          _dockRow(context, 'night'),
          _dockRow(context, 'history'),
          _plainRow('subs', Icons.workspace_premium_rounded, PawMapTheme.pawFollow,
              titleKey: 'pawmap585_btn_subs'),
          _Example('help587_ex_set'.tr, key: const ValueKey<String>('help_ex_set')),

          // ── FAQ ────────────────────────────────────────────────────────
          _SectionTitle('help587_faq_title'.tr,
              key: const ValueKey<String>('help_faq')),
          for (final n in const <int>[1, 2, 3, 4])
            _FaqCard(
              key: ValueKey<String>('help_faq_$n'),
              question: 'help587_q$n'.tr,
              answer: 'help587_a$n'.tr,
            ),
          SizedBox(height: 8.h),
        ],
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

/// v587 — texte courant de l'aide : encre chaude #3B2A26 (jamais de gris),
/// crème chaude en mode sombre.
Color _warmBody(BuildContext context) =>
    PawMapTheme.isDark(context) ? const Color(0xFFEBDDD6) : const Color(0xFF3B2A26);

/// Pastille ronde d'icône (même dessin que les raccourcis du dock) ; `filled`
/// = bouton d'action plein (Publier, Direct, Ma position).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, this.filled = false});

  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(colors: [Color.lerp(color, Colors.white, 0.12)!, color])
            : null,
        color: filled ? null : color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
            color: filled ? Colors.white : color.withValues(alpha: 0.45),
            width: filled ? 2 : 1),
      ),
      child: Icon(icon,
          size: 22.sp,
          color: filled ? Colors.white : PawMapTheme.toneOn(context, color)),
    );
  }
}

/// Encadré « Exemple » de fin de section (couleurs chaudes, pas de hauteur
/// fixe : le texte passe à la ligne).
class _Example extends StatelessWidget {
  const _Example(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: dark ? PawMapTheme.panelDark : PawMapTheme.pastelPeach,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: PawMapTheme.pawSpot.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded,
              size: 20.sp, color: PawMapTheme.toneOn(context, PawMapTheme.pawSpot)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${'help587_ex_label'.tr} · ',
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp,
                      weight: FontWeight.w800,
                      color: PawMapTheme.toneOn(context, PawMapTheme.accent)),
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
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: dark ? PawMapTheme.panelDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: PawMapTheme.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question,
              style: PawMapTheme.fontOn(context, size: 13.5.sp, weight: FontWeight.w800)),
          SizedBox(height: 4.h),
          Text(answer,
              style: PawMapTheme.fontOn(context,
                  size: 12.5.sp,
                  weight: FontWeight.w500,
                  height: 1.35,
                  color: _warmBody(context))),
        ],
      ),
    );
  }
}

/// « Partager ma balade en direct » (v584, point 14) : inchangé.
class _LiveShareCard extends StatelessWidget {
  const _LiveShareCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
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
            decoration: const BoxDecoration(
              color: PawMapLegend.pawFollow,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.share_location_rounded, color: Colors.white, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('pawmap_help_live_title'.tr,
                    style: PawMapTheme.fontOn(context, size: 14.sp, weight: FontWeight.w800)),
                SizedBox(height: 2.h),
                Text(
                  'pawmap_help_live_body'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 12.5.sp, weight: FontWeight.w500, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 22.h, bottom: 6.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 20.h,
            decoration: BoxDecoration(
              color: PawMapTheme.accent,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: PawMapTheme.fontOn(context, size: 17.sp, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    super.key,
    required this.icon,
    required this.title,
    required this.help,
  });

  final Widget icon;
  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56.w, child: Center(child: icon)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: PawMapTheme.fontOn(context,
                        size: 14.sp, weight: FontWeight.w800)),
                SizedBox(height: 2.h),
                Text(
                  help,
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
