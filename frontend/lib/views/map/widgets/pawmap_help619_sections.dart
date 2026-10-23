// 619 (PAM, 23/10/2026) — « Comprendre la PawMap » aussi complète que la page
// web /pawmap (ordre de Daniel du 23/10 : « la page n'est pas complète
// comparée à celle du web »). Les blocs du site qui manquaient dans l'app,
// avec les MÊMES textes (pack `help619_i18n.dart`, 9 langues) :
//   · [PawHelpHero619]          — la patte-pin animée sur sa tuile orange, le
//     titre et le sous-titre du site, la ligne « positions approximatives » ;
//   · [PawHelpSteps619]         — « Comment ça marche » en 3 étapes 01 · 02 · 03 ;
//   · [PawHelpCategories619]    — les 9 catégories de lieux, chacune avec SON
//     glyphe maison (`PawGlyphs.place`, le même que la goutte de la carte) et
//     SA couleur pleine (`PawMapLegend.placeColor`) ;
//   · [PawHelpPointsTeaser619]  — l'encart or « PawPoints : ton activité
//     récompensée » + « Voir mes PawPoints » ;
//   · [PawHelpNews619]          — collection du mois (5 peluches habillées),
//     pins or / argent / bronze / 1er Chef de meute, ×2 Premium ;
//   · [PawHelpSubscriptions619] — ce qui est gratuit, ce que chaque abonnement
//     ajoute (3 cartes en verre dépoli PawFollow / PawSpot / PawPremium) et la
//     bande PawPremium.
// Aucun gris (teintes chaudes pleines, crèmes fixes), mode sombre lisible,
// 375 px sans débordement (Wrap / LayoutBuilder, jamais de texte coupé).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../utils/pawmap_theme.dart';
import '../../../widgets/paw_card_icons.dart';
import '../../../widgets/paw_icons.dart';
import '../../../widgets/paw_pins618.dart';
import '../../../widgets/paw_tab_bar.dart';
import 'pawmap_pins.dart';
import 'pawmap_plush_month618.dart';

// ── Palette locale (mêmes crèmes que l'écran d'aide) ───────────────────────
const Color _inkWarm = Color(0xFF231715);
const Color _cardDark = Color(0xFF2E201C);
const Color _creamDeep = Color(0xFFFCEDE4);
const Color _goldInk = Color(0xFF8A5A00);
const Color _goldInkDark = Color(0xFFFFD98A);

Color _titleInk(BuildContext c) =>
    PawMapTheme.isDark(c) ? const Color(0xFFFBEFE6) : _inkWarm;
Color _warmBody(BuildContext c) =>
    PawMapTheme.isDark(c) ? const Color(0xFFEBDDD6) : const Color(0xFF3B2A26);
bool _reduceMotion(BuildContext c) =>
    MediaQuery.maybeDisableAnimationsOf(c) ?? false;

/// Bouton pilule plein (dégradé), texte blanc, jamais coupé (2 lignes au
/// besoin), zone tactile ≥ 44.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onTap,
    this.ink = Colors.white,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                    color: colors.last.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 46.h),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: PawMapTheme.fontOn(context,
                            size: 13.5.sp,
                            weight: FontWeight.w800,
                            color: ink,
                            height: 1.15),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Icon(Icons.arrow_forward_rounded, size: 16.sp, color: ink),
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

// ── 1. Le héros : patte-pin animée + titre et sous-titre du site ───────────

/// La scène du site (`PawMapHeroBadge`) : la patte-pin sur sa tuile orange,
/// les quatre doigts qui sortent puis rentrent doucement (fixe quand l'OS
/// demande de réduire les animations), puis le titre et le sous-titre de la
/// page /pawmap et la ligne « positions approximatives ».
class PawHelpHero619 extends StatefulWidget {
  const PawHelpHero619({super.key});

  @override
  State<PawHelpHero619> createState() => _PawHelpHero619State();
}

class _PawHelpHero619State extends State<PawHelpHero619>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reduceMotion(context)) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    final tile = Container(
      width: 92.w,
      height: 92.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0553F), PawMapTheme.accent, Color(0xFF9E1F0B)],
        ),
        boxShadow: [
          BoxShadow(
              color: PawMapTheme.accent.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = Curves.easeInOutCubic.transform(_c.value);
            // Les doigts sortent en cascade (droite → gauche), comme au splash.
            final toes = <double>[
              for (var i = 0; i < 4; i++)
                ((t * 1.6) - i * 0.15).clamp(0.0, 1.0),
            ];
            return PawGlyph(
              size: 66.w,
              toeProgress: toes,
              toeOpacity: toes,
            );
          },
        ),
      ),
    );
    return Container(
      key: const ValueKey<String>('help619_hero'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF3A2016), _cardDark]
              : const [Color(0xFFFFF1E8), Color(0xFFFFFBF7)],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
            color: PawMapTheme.accent.withValues(alpha: dark ? 0.35 : 0.2)),
        boxShadow: [
          BoxShadow(
              color: (dark ? const Color(0xFF0E0605) : const Color(0xFF9A3412))
                  .withValues(alpha: dark ? 0.35 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExcludeSemantics(child: tile),
          SizedBox(height: 14.h),
          Text(
            'help619_title'.tr,
            textAlign: TextAlign.center,
            style: PawMapTheme.fontOn(context,
                size: 21.sp,
                weight: FontWeight.w800,
                height: 1.12,
                letterSpacing: -0.4,
                color: _titleInk(context)),
          ),
          SizedBox(height: 8.h),
          Text(
            'help619_sub'.tr,
            textAlign: TextAlign.center,
            style: PawMapTheme.fontOn(context,
                size: 13.sp,
                weight: FontWeight.w500,
                height: 1.4,
                color: _warmBody(context)),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1.h),
                child: PawIconWidget(PawIcon.lock,
                    size: 15.sp,
                    color: dark ? const Color(0xFF7FE39A) : const Color(0xFF1F7A37)),
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  'help619_privacy'.tr,
                  textAlign: TextAlign.center,
                  style: PawMapTheme.fontOn(context,
                      size: 12.sp,
                      weight: FontWeight.w700,
                      height: 1.3,
                      color: dark ? const Color(0xFF7FE39A) : const Color(0xFF1F7A37)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 2. « Comment ça marche » : 3 étapes ────────────────────────────────────

class PawHelpSteps619 extends StatelessWidget {
  const PawHelpSteps619({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    const keys = ['help619_step1', 'help619_step2', 'help619_step3'];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        children: [
          for (var i = 0; i < keys.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == keys.length - 1 ? 0 : 10.h),
              child: Container(
                key: ValueKey<String>('help619_step_${i + 1}'),
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF3A2420) : _creamDeep,
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0${i + 1}',
                      style: PawMapTheme.fontOn(context,
                          size: 12.sp,
                          weight: FontWeight.w800,
                          letterSpacing: 2.4,
                          color: dark ? const Color(0xFFFF9A85) : PawMapTheme.accent),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      keys[i].tr,
                      style: PawMapTheme.fontOn(context,
                          size: 13.5.sp,
                          weight: FontWeight.w600,
                          height: 1.45,
                          color: _titleInk(context)),
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

// ── 3. Les 9 catégories de lieux ───────────────────────────────────────────

/// Les catégories de la carte, avec le glyphe maison de leur goutte.
const List<String> kPawHelpCategories619 = <String>[
  'vet', 'shop', 'groomer', 'park', 'beach', 'water', 'trainer', 'hotel', 'restaurant',
];

class PawHelpCategories619 extends StatelessWidget {
  const PawHelpCategories619({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La pastille du site : « 9 catégories · 177 pays · … ».
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF3A2420) : _creamDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'help619_categories'.tr,
              style: PawMapTheme.fontOn(context,
                  size: 12.sp,
                  weight: FontWeight.w800,
                  color: dark ? const Color(0xFFFF9A85) : const Color(0xFF7A1D0C)),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'help619_places_note'.tr,
            style: PawMapTheme.fontOn(context,
                size: 12.5.sp,
                weight: FontWeight.w500,
                height: 1.4,
                color: _warmBody(context)),
          ),
          SizedBox(height: 12.h),
          LayoutBuilder(
            builder: (context, box) {
              final double w = (box.maxWidth - 8.w) / 2;
              return Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final cat in kPawHelpCategories619)
                    SizedBox(
                      width: w,
                      child: _CategoryTile(cat: cat),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.cat});

  final String cat;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    final Color color = PawMapLegend.placeColor(cat);
    return Container(
      key: ValueKey<String>('help619_cat_$cat'),
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 10.w, 8.h),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF3A2420) : _creamDeep,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.16)!, color],
              ),
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Center(
              child: CustomPaint(
                size: Size(19.w, 19.w),
                painter: _GlyphPainter(PawGlyphs.place[cat]!, Colors.white),
              ),
            ),
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'help619_cat_$cat'.tr,
              maxLines: 3,
              style: PawMapTheme.fontOn(context,
                  size: 12.5.sp,
                  weight: FontWeight.w700,
                  height: 1.2,
                  color: _titleInk(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un glyphe de la famille maison (grille 24) peint en plein dans sa boîte.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.d, this.color);

  final String d;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    PawMapPinPainter.drawGlyph(
        canvas, PawSvgPath.parse(d), Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.d != d || old.color != color;
}

// ── 4. Encart PawPoints (or) ───────────────────────────────────────────────

class PawHelpPointsTeaser619 extends StatelessWidget {
  const PawHelpPointsTeaser619({super.key, required this.onSeePoints});

  final VoidCallback onSeePoints;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    return Container(
      key: const ValueKey<String>('help619_points_teaser'),
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF3A2D10), Color(0xFF2A2010)]
              : const [Color(0xFFFFF6DB), Color(0xFFFFFBF0), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF1D9A6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE7A3), Color(0xFFF4C04A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFB07800).withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: PawIconWidget(PawIcon.paw,
                      size: 26.sp,
                      color: const Color(0xFF7A4E00),
                      fill: const Color(0xFF7A4E00)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'pp607_teaser_title'.tr,
                  style: PawMapTheme.fontOn(context,
                      size: 15.sp,
                      weight: FontWeight.w800,
                      height: 1.2,
                      color: dark ? _goldInkDark : _goldInk),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              key: const ValueKey<String>('help619_see_points'),
              label: 'help619_see_all'.tr,
              colors: const [Color(0xFFF4C04A), Color(0xFFD99A0B), Color(0xFFB07800)],
              onTap: onSeePoints,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. Nouveautés : collection du mois · pins · ×2 Premium ─────────────────

class PawHelpNews619 extends StatelessWidget {
  const PawHelpNews619({super.key, required this.onPawPoints});

  final VoidCallback onPawPoints;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    const Color month = Color(0xFFC2571A);
    final plush = Padding(
      padding: EdgeInsets.only(top: 2.h),
      child: Wrap(
        spacing: 4.w,
        children: [
          for (final ty in const ['teddy', 'bunny', 'kitty', 'puppy', 'fox'])
            PawThemedPlush618(type: ty, theme: 'autumn', color: month, size: 42.w),
        ],
      ),
    );
    final pins = Wrap(
      spacing: 6.w,
      children: [
        for (final code in const [1, 2, 3, 4]) PawPinDisc618(code: code, size: 34.w),
      ],
    );
    final x2 = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/pawpremium_logo.png',
            width: 40.w,
            height: 40.w,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => PawIconWidget(PawIcon.crown,
                size: 36.sp,
                color: const Color(0xFFFFD34D),
                fill: const Color(0xFFFFD34D))),
        SizedBox(width: 10.w),
        Text('×2',
            style: PawMapTheme.fontOn(context,
                size: 28.sp,
                weight: FontWeight.w800,
                color: const Color(0xFFFFD34D))),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NewsCard(
            id: 'month',
            visual: plush,
            title: 'help619_month_t'.tr,
            chip: 'help619_month_soon'.tr,
            chipColor: month,
            body: 'help619_month_b'.tr,
            colors: dark
                ? const [Color(0xFF3F2414), Color(0xFF2E1A10)]
                : const [Color(0xFFFFF1E6), Color(0xFFFFFFFF)],
            ring: const Color(0xFFF6C9A8),
            titleColor: dark ? const Color(0xFFFFB38A) : const Color(0xFF9A3412),
          ),
          SizedBox(height: 10.h),
          _NewsCard(
            id: 'pins',
            visual: pins,
            title: 'help619_pins_t'.tr,
            body: 'help619_pins_b'.tr,
            colors: dark
                ? const [Color(0xFF3A2D10), Color(0xFF2A2010)]
                : const [Color(0xFFFFF6DB), Color(0xFFFFFFFF)],
            ring: const Color(0xFFF1D9A6),
            titleColor: dark ? _goldInkDark : _goldInk,
          ),
          SizedBox(height: 10.h),
          _NewsCard(
            id: 'premium',
            visual: x2,
            title: 'help619_premium_t'.tr,
            body: 'help619_premium_b'.tr,
            colors: const [Color(0xFF2A2219), Color(0xFF15120D)],
            ring: const Color(0xFF4A3A22),
            titleColor: const Color(0xFFFFD34D),
            bodyColor: const Color(0xFFFDF8F7),
          ),
          SizedBox(height: 10.h),
          Text(
            'help619_no_money'.tr,
            textAlign: TextAlign.center,
            style: PawMapTheme.fontOn(context,
                size: 12.5.sp,
                weight: FontWeight.w700,
                height: 1.35,
                color: _warmBody(context)),
          ),
          SizedBox(height: 10.h),
          Center(
            child: _PillButton(
              key: const ValueKey<String>('help619_ppg_link'),
              label: 'help619_ppg_link'.tr,
              colors: const [Color(0xFFF4C04A), Color(0xFFD99A0B), Color(0xFFB07800)],
              onTap: onPawPoints,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({
    required this.id,
    required this.visual,
    required this.title,
    required this.body,
    required this.colors,
    required this.ring,
    required this.titleColor,
    this.chip,
    this.chipColor,
    this.bodyColor,
  });

  final String id;
  final Widget visual;
  final String title;
  final String body;
  final List<Color> colors;
  final Color ring;
  final Color titleColor;
  final String? chip;
  final Color? chipColor;
  final Color? bodyColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey<String>('help619_news_$id'),
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: ring),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 44.h),
            child: Align(alignment: Alignment.centerLeft, child: visual),
          ),
          SizedBox(height: 10.h),
          Text(title,
              style: PawMapTheme.fontOn(context,
                  size: 17.sp,
                  weight: FontWeight.w800,
                  height: 1.15,
                  color: titleColor)),
          if (chip != null) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: chipColor ?? PawMapTheme.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(chip!,
                  style: PawMapTheme.fontOn(context,
                      size: 11.5.sp, weight: FontWeight.w800, color: Colors.white)),
            ),
          ],
          SizedBox(height: 6.h),
          Text(body,
              style: PawMapTheme.fontOn(context,
                  size: 13.sp,
                  weight: FontWeight.w500,
                  height: 1.45,
                  color: bodyColor ?? _warmBody(context))),
        ],
      ),
    );
  }
}

// ── 6. Abonnements : gratuit / avec, en verre dépoli ───────────────────────

/// Les trois offres du site (`SubscriptionsExplainer`), dans l'ordre du site.
/// [tab] = onglet de la boutique (`CoinShopScreen.initialTab`).
class PawHelpPlan619 {
  const PawHelpPlan619(this.id, this.name, this.accent, this.tab, this.svg);
  final String id;
  final String name;
  final Color accent;
  final int tab;
  final String svg;
}

const List<PawHelpPlan619> kPawHelpPlans619 = <PawHelpPlan619>[
  PawHelpPlan619('pf', 'PawFollow', Color(0xFF6A34E0), 1, PawCardIcons.follow),
  PawHelpPlan619('ps', 'PawSpot', Color(0xFFE8890A), 2, PawCardIcons.spot),
  PawHelpPlan619('pp', 'PawPremium', Color(0xFFB8860B), 3, PawCardIcons.premium),
];

class PawHelpSubscriptions619 extends StatelessWidget {
  const PawHelpSubscriptions619({super.key, required this.onOpenShop});

  /// Ouvre la boutique sur l'onglet de l'offre (1 PawFollow · 2 PawSpot ·
  /// 3 Paw Premium).
  final ValueChanged<int> onOpenShop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'help619_sub_sub'.tr,
            style: PawMapTheme.fontOn(context,
                size: 13.sp,
                weight: FontWeight.w500,
                height: 1.45,
                color: _warmBody(context)),
          ),
          SizedBox(height: 12.h),
          for (final p in kPawHelpPlans619) ...[
            _GlassPlanCard(plan: p, onOpen: () => onOpenShop(p.tab)),
            SizedBox(height: 10.h),
          ],
          _PremiumBand(onOpen: () => onOpenShop(3)),
        ],
      ),
    );
  }
}

/// Carte « verre dépoli » : fond teinté de l'offre, reflet en haut, liseré
/// à sa couleur. En mode sombre le reflet est teinté (jamais un blanc
/// translucide, qui redeviendrait gris).
class _GlassPlanCard extends StatelessWidget {
  const _GlassPlanCard({required this.plan, required this.onOpen});

  final PawHelpPlan619 plan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = PawMapTheme.isDark(context);
    final Color a = plan.accent;
    final Color accentOn = dark ? Color.lerp(a, Colors.white, 0.45)! : a;
    final Color base1 = dark ? Color.lerp(a, Colors.black, 0.62)! : Color.lerp(a, Colors.white, 0.86)!;
    final Color base2 = dark ? Color.lerp(a, Colors.black, 0.78)! : Color.lerp(a, Colors.white, 0.95)!;
    final Color inner = dark ? Color.lerp(a, Colors.black, 0.84)! : Colors.white.withValues(alpha: 0.88);
    final Color gloss = dark ? Color.lerp(a, Colors.white, 0.5)! : Colors.white;
    final String free = 'help619_sub_${plan.id}_free'.tr;
    final String plus = 'help619_sub_${plan.id}_plus'.tr;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [base1, base2]),
              ),
            ),
          ),
          // Reflet du verre : moitié haute plus claire, fondu vers le bas.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 72.h,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gloss.withValues(alpha: dark ? 0.16 : 0.6),
                      gloss.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            key: ValueKey<String>('help619_plan_${plan.id}'),
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: a.withValues(alpha: dark ? 0.55 : 0.35), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: a.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.string(plan.svg, width: 30.w, height: 30.w),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(plan.name,
                          style: PawMapTheme.fontOn(context,
                              size: 18.sp,
                              weight: FontWeight.w800,
                              color: _titleInk(context))),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text('help619_sub_free_label'.tr.toUpperCase(),
                    style: PawMapTheme.fontOn(context,
                        size: 10.5.sp,
                        weight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: _warmBody(context))),
                SizedBox(height: 3.h),
                Text(free,
                    style: PawMapTheme.fontOn(context,
                        size: 13.sp,
                        weight: FontWeight.w500,
                        height: 1.45,
                        color: _titleInk(context))),
                // 611 — l'itinéraire vers un AMI est gratuit.
                if (plan.id == 'pf') ...[
                  SizedBox(height: 6.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Icon(Icons.check_rounded,
                            size: 16.sp,
                            color: dark ? const Color(0xFF7FE39A) : const Color(0xFF15803D)),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text('help619_route_free'.tr,
                            style: PawMapTheme.fontOn(context,
                                size: 13.sp,
                                weight: FontWeight.w700,
                                height: 1.35,
                                color: dark ? const Color(0xFF7FE39A) : const Color(0xFF15803D))),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: inner,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${'help619_sub_plus_label'.tr} ${plan.name}'.toUpperCase(),
                          style: PawMapTheme.fontOn(context,
                              size: 10.5.sp,
                              weight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: accentOn)),
                      SizedBox(height: 3.h),
                      Text(plus,
                          style: PawMapTheme.fontOn(context,
                              size: 13.sp,
                              weight: FontWeight.w500,
                              height: 1.45,
                              color: _titleInk(context))),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Semantics(
                  button: true,
                  child: InkWell(
                    key: ValueKey<String>('help619_plan_cta_${plan.id}'),
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(12.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text('${'help619_sub_cta'.tr} ${plan.name}',
                                style: PawMapTheme.fontOn(context,
                                    size: 13.5.sp,
                                    weight: FontWeight.w800,
                                    color: accentOn)),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.arrow_forward_rounded, size: 16.sp, color: accentOn),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La bande PawPremium du site : noir et or, logo, sous-titre, bouton.
class _PremiumBand extends StatelessWidget {
  const _PremiumBand({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('help619_premium_band'),
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2219), Color(0xFF15120D)],
        ),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFF4A3A22)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0F0B08).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/pawpremium_logo.png',
                  width: 56.w,
                  height: 56.w,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => PawIconWidget(PawIcon.crown,
                      size: 44.sp,
                      color: const Color(0xFFFFD34D),
                      fill: const Color(0xFFFFD34D))),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PawPremium',
                        style: PawMapTheme.fontOn(context,
                            size: 18.sp,
                            weight: FontWeight.w800,
                            color: const Color(0xFFFFD34D))),
                    SizedBox(height: 3.h),
                    Text('help619_premium_sub'.tr,
                        style: PawMapTheme.fontOn(context,
                            size: 13.sp,
                            weight: FontWeight.w500,
                            height: 1.4,
                            color: const Color(0xFFFDF8F7))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Align(
            alignment: Alignment.centerLeft,
            child: _PillButton(
              key: const ValueKey<String>('help619_premium_cta'),
              label: 'help619_premium_cta'.tr,
              colors: const [Color(0xFFFFE7A3), Color(0xFFF4C04A)],
              ink: const Color(0xFF231715),
              onTap: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}
