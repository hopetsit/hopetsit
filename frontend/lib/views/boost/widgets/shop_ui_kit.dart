// v566 — kit visuel de la boutique (audit « vérifie que tout est bon », Daniel
// 18/09). Style Apple minimaliste + « Paw Buttons » : cartes 20-24, pilule
// « Meilleur prix », économie en %, bouton d'achat collant, feuille de
// confirmation, mentions légales d'abonnement, gestion / annulation.
//
// Aucun texte en dur : toutes les chaînes viennent de l'appelant (déjà
// traduites) ou des clés `v566_shop_*` (paquet localization/v565/home_i18n).
// Anti-débordement (allemand, portugais) : chaque libellé est borné par
// maxLines + ellipsis ou FittedBox(scaleDown).

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Liens légaux (mêmes cibles que le pied de boutique iOS — `www` direct pour
/// éviter la redirection 308 du domaine nu).
const String kShopTermsUrl = 'https://www.hopetsit.com/cgu';
const String kShopPrivacyUrl = 'https://www.hopetsit.com/privacy';

/// Réglages d'abonnement de l'App Store (lien officiel Apple).
const String kAppleManageSubscriptionsUrl =
    'https://apps.apple.com/account/subscriptions';

// ═══════════════════════════════════════════════════════════════════════════
//  v567 — DÉGAGEMENT DU BAS (bug Samsung, captures de Daniel 19/09)
//  Sur son Samsung (edge-to-edge), `viewPadding.bottom` ET `padding.bottom`
//  valent 0 alors que la barre de navigation système (3 boutons) est DESSINÉE
//  par-dessus : la barre d'achat collante passait derrière, à moitié masquée,
//  bouton intouchable. Règle du projet : inset 0 sur Android → réserver 48 px
//  logiques ; sinon inset réel ; iOS = inset réel (home indicator ~34), jamais
//  +48.
// ═══════════════════════════════════════════════════════════════════════════

/// Dégagement bas à réserver sous un contenu posé au ras de l'écran.
double shopBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  final raw = math.max(mq.viewPadding.bottom, mq.padding.bottom);
  // v568 — sur Android, jamais moins de 48 px (barre à 3 boutons Samsung).
  return Platform.isAndroid ? math.max(raw, 48.0) : raw;
}

/// Dégagement SUPPLÉMENTAIRE dans une zone déjà protégée par un `SafeArea`
/// (feuilles `showModalBottomSheet(useSafeArea: true)`) : 0 dès que le système
/// annonce un inset (le SafeArea l'a déjà appliqué — sinon on doublerait le
/// home indicator iOS), 48 px sur Android quand l'inset est menti à 0.
double shopSafeAreaExtraInset(BuildContext context) {
  // v569 — `showModalBottomSheet(useSafeArea: true)` = SafeArea(bottom: FALSE) :
  // le bas de la feuille n'est jamais protégé. Les versions 567/568 croyaient
  // le contraire et n'ajoutaient rien → « Annuler » restait sous la barre
  // Samsung. On ajoute donc l'inset COMPLET (48 px minimum sur Android).
  return appBottomInset(context);
}

/// Rembourrage bas du contenu défilant d'un onglet de la boutique : la
/// dernière carte ne doit JAMAIS finir sous la barre d'achat collante.
double shopScrollBottomPadding(BuildContext context) =>
    ShopStickyBar.heightFor(context) + 16.h;

/// Nombre de jours restants, lisible. Au-delà de 10 ans (abonnement « à vie »,
/// comptes staff) on montre « Illimité ∞ » — même règle que
/// `widgets/active_benefits_row.dart`, qui affichait sinon « 26766 j ».
String shopDaysLabel(int days) {
  if (days > 3650) return 'shop567_unlimited'.tr;
  if (days <= 0) return '';
  return 'shop567_days_left'.tr.replaceAll('{n}', '$days');
}

/// Économie (en %) d'un forfait annuel par rapport à 12 mensualités.
/// Renvoie 0 si les prix ne permettent pas de calculer (évite « -0 % »).
int shopYearlySavingsPct({required double monthly, required double yearly}) {
  if (monthly <= 0 || yearly <= 0) return 0;
  final full = monthly * 12;
  if (yearly >= full) return 0;
  return ((1 - yearly / full) * 100).round();
}

/// Libellé de durée traduit pour un nombre de jours (30 → 1 mois, 365 → 1 an).
String shopPeriodLabel(int days) {
  if (days >= 360) return 'v566_shop_period_year'.tr;
  if (days >= 28 && days <= 31) return 'v566_shop_period_month'.tr;
  return 'v566_shop_period_days'.tr.replaceAll('{n}', '$days');
}

/// Date courte JJ/MM/AAAA (neutre, lisible dans les 9 langues).
String shopShortDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// v569 — MOTIF du bandeau produit : cercles et empreintes très transparents,
/// peints au [CustomPainter] (aucune image, aucun asset, aucune dépendance).
class _ShopHeroPattern extends CustomPainter {
  const _ShopHeroPattern();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.10);
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.055);
    canvas.drawCircle(Offset(size.width - 24, -18), 74, ring);
    canvas.drawCircle(Offset(size.width + 6, size.height + 2), 56, ring);
    canvas.drawCircle(Offset(size.width - 62, size.height * 0.34), 26, fill);
    _paw(canvas, Offset(size.width - 34, size.height * 0.62), 9, fill);
    _paw(canvas, Offset(size.width - 96, size.height * 0.86), 7, fill);
  }

  /// Empreinte : un coussinet + 4 orteils.
  void _paw(Canvas canvas, Offset c, double r, Paint p) {
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, r * 0.55),
        width: r * 1.7,
        height: r * 1.4,
      ),
      p,
    );
    for (var i = 0; i < 4; i++) {
      final a = -2.55 + i * 0.5;
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(math.cos(a) * r * 1.05, math.sin(a) * r * 1.05),
          width: r * 0.72,
          height: r * 0.92,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShopHeroPattern oldDelegate) => false;
}

/// v567 — BANDEAU PRODUIT commun aux 4 onglets (PawBoost, PawFollow, PawSpot,
/// Paw Premium) : disque blanc + icône du produit, nom, phrase courte, dégradé
/// du produit. Avant, seuls PawSpot et Paw Premium en avaient un vrai ; les
/// quatre onglets se lisent désormais pareil.
///
/// v569 — enrichi : motif discret au [CustomPainter], titre 22/800, et la
/// pastille d'état ([status]) intégrée DANS le hero, en bas à gauche.
class ShopHero extends StatelessWidget {
  const ShopHero({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.titleColor = Colors.white,
    this.trailing,
    this.status,
  });

  /// Icône posée sur le disque blanc (SVG « Paw Buttons », pièce dorée…).
  final Widget icon;
  final String title;
  final String subtitle;

  /// Dégradé du produit (Boost, Follow, Spot, Premium).
  final List<Color> colors;
  final Color titleColor;

  /// Ligne posée sous la phrase (dans la colonne de droite).
  final Widget? trailing;

  /// Pastille d'état du produit, posée en bas à gauche du bandeau.
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.6, 1),
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Motif décoratif (cercles + pattes), sous le contenu.
          const Positioned.fill(
            child: CustomPaint(painter: _ShopHeroPattern()),
          ),
          // Reflet haut (même langage visuel que les 4 cartes d'onglet).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1,
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.45)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 14,
                            spreadRadius: -6,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: icon,
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: titleColor,
                                height: 1.1,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          if (trailing != null) ...[
                            SizedBox(height: 10.h),
                            trailing!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (status != null) ...[
                  SizedBox(height: 14.h),
                  Align(alignment: Alignment.centerLeft, child: status!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// v567 — PASTILLE D'ÉTAT unique pour les 4 onglets (« PawSpot · Actif ·
/// 30 j restants », « PawBoost · Inactif »). Remplace les 4 cartes d'état
/// hétérogènes. Les jours passent par [shopDaysLabel] → « Illimité ∞ »
/// au-delà de 3 650 jours (bug « Il vous reste 26766 jours »).
class ShopStatusPill extends StatelessWidget {
  const ShopStatusPill({
    super.key,
    required this.label,
    required this.active,
    required this.accent,
    this.days,
    this.onDark = false,
  });

  /// Nom du produit (« PawSpot », « PawFamily »…).
  final String label;
  final bool active;
  final Color accent;

  /// Jours restants (null = on n'affiche que l'état).
  final int? days;

  /// Posée sur un fond sombre (onglet Paw Premium).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final state =
        active ? 'shop567_state_active'.tr : 'shop567_state_inactive'.tr;
    final left = (active && days != null) ? shopDaysLabel(days!) : '';
    final text = left.isEmpty ? '$label · $state' : '$label · $state · $left';
    final Color fg = active
        ? (onDark ? Colors.white : accent)
        : (onDark ? Colors.white.withValues(alpha: 0.65) : AppColors.textSecondary(context));
    final Color bg = active
        ? accent.withValues(alpha: onDark ? 0.30 : 0.12)
        : (onDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.divider(context).withValues(alpha: 0.45));
    return Container(
      constraints: BoxConstraints(minHeight: 34.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? fg.withValues(alpha: 0.45) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v567 — titre de section régulier (grille 8) : titre + sous-titre optionnel.
class ShopSectionTitle extends StatelessWidget {
  const ShopSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.color,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, SizedBox(width: 8.w)],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: color ?? AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.3,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pilule « MEILLEUR PRIX » / « −40 % ».
class ShopPill extends StatelessWidget {
  const ShopPill({
    super.key,
    required this.label,
    required this.background,
    this.foreground = Colors.white,
    this.gradient,
  });

  final String label;
  final Color background;
  final Color foreground;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 150.w),
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient == null ? null : LinearGradient(colors: gradient!),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: foreground,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Pastille de sélection (rond vide / coche pleine) des cartes d'offre.
class ShopSelectDot extends StatelessWidget {
  const ShopSelectDot({
    super.key,
    required this.selected,
    required this.color,
    this.idleColor,
    this.checkColor = Colors.white,
  });

  final bool selected;
  final Color color;
  final Color? idleColor;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    // v567 — état sélectionné plus net : pastille pleine + halo coloré (le
    // simple rond vide se lisait comme une radio grise sur les captures).
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : (idleColor ?? AppColors.divider(context)),
          width: 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 3),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 16, color: checkColor)
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  v569 — BLOCS COMMUNS AUX 4 ONGLETS
//  Les quatre onglets se lisent désormais EXACTEMENT pareil : hero, avantages,
//  gratuit vs payant, forfaits, rangée de confiance, « Aide & infos », barre
//  d'achat. Tout est ici pour qu'un changement de gabarit profite aux quatre.
// ═══════════════════════════════════════════════════════════════════════════

/// Un avantage produit : icône ronde teintée + titre court + sous-texte.
class ShopBenefit {
  const ShopBenefit({
    required this.title,
    this.body,
    this.icon,
    this.iconWidget,
    this.onTap,
  });

  /// Titre court (2-4 mots).
  final String title;

  /// Phrase d'explication (réutilise les clés existantes). `null` = le titre
  /// se suffit à lui-même.
  final String? body;

  /// Icône Material ; ignorée si [iconWidget] est fourni.
  final IconData? icon;

  /// Visuel personnalisé (badge rose « membre Paw Map », pièce dorée…).
  final Widget? iconWidget;

  /// Ligne cliquable (raccourci vers un autre onglet) → chevron affiché.
  final VoidCallback? onTap;
}

/// Liste verticale d'avantages (3 à 6 lignes), dans une carte régulière.
class ShopBenefitList extends StatelessWidget {
  const ShopBenefitList({
    super.key,
    required this.items,
    required this.accent,
    this.onDark = false,
  });

  final List<ShopBenefit> items;
  final Color accent;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        onDark ? Colors.white : AppColors.textPrimary(context);
    final bodyColor = onDark
        ? Colors.white.withValues(alpha: 0.70)
        : AppColors.textSecondary(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 6.h),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.divider(context),
        ),
        boxShadow: onDark ? const <BoxShadow>[] : AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in items)
            _ShopBenefitRow(
              benefit: b,
              accent: accent,
              titleColor: titleColor,
              bodyColor: bodyColor,
              onDark: onDark,
            ),
        ],
      ),
    );
  }
}

class _ShopBenefitRow extends StatelessWidget {
  const _ShopBenefitRow({
    required this.benefit,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.onDark,
  });

  final ShopBenefit benefit;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: benefit.iconWidget == null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: onDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      benefit.icon ?? Icons.check_rounded,
                      size: 18.sp,
                      color: onDark ? Colors.white : accent,
                    ),
                  )
                : Center(child: benefit.iconWidget),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  benefit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.2,
                    color: titleColor,
                  ),
                ),
                if (benefit.body != null && benefit.body!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    benefit.body!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: bodyColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (benefit.onTap != null) ...[
            SizedBox(width: 6.w),
            Icon(Icons.chevron_right_rounded, size: 20.sp, color: accent),
          ],
        ],
      ),
    );
    if (benefit.onTap == null) return row;
    return InkWell(
      onTap: benefit.onTap,
      borderRadius: BorderRadius.circular(14),
      child: row,
    );
  }
}

/// Rangée de confiance : 3 petites pastilles HONNÊTES selon la plateforme.
/// Android / carte (et tout achat ponctuel) : paiement unique → « sans
/// engagement » ; abonnement iOS (StoreKit) : « annulable à tout moment ».
class ShopTrustRow extends StatelessWidget {
  const ShopTrustRow({
    super.key,
    required this.accent,
    this.oneTime = false,
    this.onDark = false,
  });

  final Color accent;

  /// Achat ponctuel (PawBoost) : jamais de renouvellement, rien à annuler.
  final bool oneTime;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    // Sur iOS un ABONNEMENT se résilie dans les réglages App Store ; un achat
    // ponctuel (ou un paiement carte unique) n'a rien à résilier.
    final renewable = Platform.isIOS && !oneTime;
    final items = <List<Object>>[
      [Icons.lock_outline_rounded, 'shop569_trust_secure'.tr],
      [
        renewable ? Icons.event_repeat_rounded : Icons.handshake_outlined,
        (renewable ? 'shop569_trust_cancel' : 'shop569_trust_nocommit').tr,
      ],
      [Icons.bolt_rounded, 'shop569_trust_instant'.tr],
    ];
    Widget chip(IconData ic, String label) => Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: 64.h),
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: onDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : accent.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ic,
                    size: 17.sp, color: onDark ? Colors.white : accent),
                SizedBox(height: 5.h),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chip(items[0][0] as IconData, items[0][1] as String),
        SizedBox(width: 8.w),
        chip(items[1][0] as IconData, items[1][1] as String),
        SizedBox(width: 8.w),
        chip(items[2][0] as IconData, items[2][1] as String),
      ],
    );
  }
}

/// Ligne du bloc « Aide & infos » : icône, libellé, (valeur), chevron.
class ShopInfoRow extends StatelessWidget {
  const ShopInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.loading = false,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Widget posé avant le chevron (menu de devise, prix…).
  final Widget? trailing;
  final bool showChevron;
  final bool loading;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.textPrimary(context);
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        // Cible tactile confortable (≥ 52 px).
        constraints: const BoxConstraints(minHeight: 52),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          children: [
            loading
                ? SizedBox(
                    width: 18.sp,
                    height: 18.sp,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: tint),
                  )
                : Icon(icon, size: 18.sp, color: tint),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
            if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
            if (showChevron && onTap != null) ...[
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right_rounded,
                  size: 20.sp, color: AppColors.textSecondary(context)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte « Aide & infos » : titre + lignes séparées par un filet.
class ShopHelpCard extends StatelessWidget {
  const ShopHelpCard({super.key, required this.rows, this.footer});

  final List<Widget> rows;

  /// Mentions légales + liens CGU / confidentialité.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(Divider(
          height: 1,
          indent: 12.w,
          endIndent: 12.w,
          color: AppColors.divider(context),
        ));
      }
      children.add(rows[i]);
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(4.w, 12.h, 4.w, 8.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Text(
              'shop569_help_title'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          ...children,
          if (footer != null) ...[
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 6.h),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

/// v569 — TUILE DE FORFAIT, identique sur les 4 onglets.
///
/// Grande, lisible, cible tactile ≥ 56 px : ruban optionnel (« Le plus
/// choisi »), icône, nom + description, prix en gros à droite avec le prix
/// barré et le badge « −X % » alignés en haut, équivalent mensuel / prix par
/// jour en petit, et la coche animée de sélection.
class ShopPlanTile extends StatelessWidget {
  const ShopPlanTile({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.subtitle,
    this.footnote,
    this.leading,
    this.strikeLabel,
    this.savePct = 0,
    this.ribbon,
    this.badges = const <Widget>[],
    this.loading = false,
    this.onLongPress,
    this.onDark = false,
    this.checkColor = Colors.white,
  });

  final String title;
  final String priceLabel;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  /// Phrase courte sous le nom du forfait.
  final String? subtitle;

  /// Petite ligne sous le prix (« soit 4,17 €/mois », « 0,57 €/jour »).
  final String? footnote;

  /// Visuel à gauche (emoji, médaille, icône du produit).
  final Widget? leading;

  /// Prix barré (promo, ou prix des deux abonnements séparés).
  final String? strikeLabel;

  /// Économie affichée en badge vert (« −33 % »). 0 = masqué.
  final int savePct;

  /// Ruban posé en haut de la tuile (« Le plus choisi »).
  final String? ribbon;

  /// Pastilles additionnelles (« Meilleur prix », « Actif »…).
  final List<Widget> badges;
  final bool loading;

  /// Appui long = payer avec le portefeuille (sitter / walker).
  final VoidCallback? onLongPress;
  final bool onDark;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    final Color titleColor =
        onDark ? Colors.white : AppColors.textPrimary(context);
    final Color subColor = onDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.textSecondary(context);
    final Color bg = onDark
        ? Colors.white.withValues(alpha: selected ? 0.12 : 0.05)
        : (selected
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.05), AppColors.card(context))
            : AppColors.card(context));
    final Color borderColor = selected
        ? accent
        : (onDark
            ? Colors.white.withValues(alpha: 0.16)
            : AppColors.divider(context));

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 76),
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: onDark
                ? const <BoxShadow>[]
                : [
                    BoxShadow(
                      color: selected
                          ? accent.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.04),
                      blurRadius: selected ? 18 : 10,
                      spreadRadius: -6,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ribbon != null && ribbon!.isNotEmpty) ...[
                ShopPill(label: ribbon!, background: accent),
                SizedBox(height: 10.h),
              ],
              Row(
                children: [
                  if (leading != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: onDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: leading,
                    ),
                    SizedBox(width: 10.w),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: titleColor,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          SizedBox(height: 3.h),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              height: 1.3,
                              color: subColor,
                            ),
                          ),
                        ],
                        if (badges.isNotEmpty) ...[
                          SizedBox(height: 6.h),
                          Wrap(spacing: 6.w, runSpacing: 4.h, children: badges),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 118.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if ((strikeLabel != null && strikeLabel!.isNotEmpty) ||
                            savePct > 0) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (strikeLabel != null &&
                                  strikeLabel!.isNotEmpty)
                                Flexible(
                                  child: Text(
                                    strikeLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: subColor,
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: subColor,
                                    ),
                                  ),
                                ),
                              if (savePct > 0) ...[
                                SizedBox(width: 5.w),
                                // Flexible : le badge ne doit jamais pousser
                                // la ligne hors de la tuile (libellés longs
                                // en allemand / polonais).
                                Flexible(
                                  child: ShopPill(
                                    label: 'v566_shop_save_pct'
                                        .tr
                                        .replaceAll('{pct}', '$savePct'),
                                    background: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 2.h),
                        ],
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            priceLabel,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 21.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                              color: accent,
                            ),
                          ),
                        ),
                        if (footnote != null && footnote!.isNotEmpty)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              footnote!,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: subColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent),
                        )
                      : ShopSelectDot(
                          selected: selected,
                          color: accent,
                          checkColor: checkColor,
                          idleColor: onDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : null,
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v569 — SQUELETTE DE CHARGEMENT (shimmer maison : un dégradé qui glisse,
/// aucune dépendance ajoutée). Remplace le rond de progression pendant le
/// chargement des prix et des avantages.
class ShopSkeleton extends StatefulWidget {
  const ShopSkeleton({super.key, this.tiles = 3});

  /// Nombre de tuiles de forfait esquissées.
  final int tiles;

  @override
  State<ShopSkeleton> createState() => _ShopSkeletonState();
}

class _ShopSkeletonState extends State<ShopSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.divider(context).withValues(alpha: 0.55);
    final hi = AppColors.divider(context).withValues(alpha: 0.20);
    Widget box(double h, {double? w, double r = 16}) => Container(
          height: h,
          width: w ?? double.infinity,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value * 2 - 0.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(-1 + t * 2, -0.4),
            end: Alignment(t * 2, 0.4),
            colors: [base, hi, base],
          ).createShader(rect),
          child: child,
        );
      },
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            box(132.h, r: 24),
            SizedBox(height: 24.h),
            box(16.h, w: 150.w, r: 8),
            SizedBox(height: 12.h),
            box(168.h, r: 20),
            SizedBox(height: 24.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: box(150.h, r: 20)),
                SizedBox(width: 10.w),
                Expanded(child: box(150.h, r: 20)),
              ],
            ),
            SizedBox(height: 24.h),
            for (var i = 0; i < widget.tiles; i++) ...[
              box(84.h, r: 22),
              SizedBox(height: 12.h),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bouton d'achat COLLANT en bas d'un onglet de la boutique.
class ShopStickyBar extends StatelessWidget {
  const ShopStickyBar({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.buttonLabel,
    required this.colors,
    required this.onPressed,
    this.subLabel,
    this.loading = false,
    this.dark = false,
    this.buttonTextColor = Colors.white,
  });

  /// Nom de l'offre sélectionnée (« PawFollow · Annuel »).
  final String title;

  /// Prix affiché (« 49,99 € »), déjà formaté.
  final String priceLabel;

  /// Ligne discrète sous le prix (« soit 4,17 €/mois », « 7 jours »…).
  final String? subLabel;
  final String buttonLabel;

  /// Dégradé du bouton (couleur du produit).
  final List<Color> colors;
  final VoidCallback? onPressed;
  final bool loading;

  /// Barre sombre (onglet Paw Premium noir/or).
  final bool dark;
  final Color buttonTextColor;

  /// Hauteur du BOUTON (cible tactile ≥ 48 px).
  static const double _buttonHeight = 52;

  /// Hauteur totale occupée par la barre, dégagement système compris. Sert au
  /// rembourrage bas du contenu défilant ([shopScrollBottomPadding]) pour que
  /// la dernière carte ne finisse jamais sous la barre.
  /// (bouton + marge de sécurité) + rembourrages de la carte et du fondu
  /// + dégagement système.
  static double heightFor(BuildContext context) =>
      _buttonHeight + 8 + 24.h + 14.h + 12 + shopBottomInset(context);

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF150F0D) : AppColors.card(context);
    final titleColor =
        dark ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary(context);
    final priceColor =
        dark ? const Color(0xFFFFD34D) : AppColors.textPrimary(context);
    final enabled = onPressed != null && !loading;
    final scaffold = AppColors.scaffold(context);
    // v567 — carte FLOTTANTE arrondie posée sur un fondu vers le fond de la
    // page (pas de BackdropFilter : on est au-dessus d'une liste défilante).
    // Le dégagement bas vient de shopBottomInset → plus jamais derrière la
    // barre de navigation Samsung.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scaffold.withValues(alpha: 0),
            scaffold.withValues(alpha: 0.92),
            scaffold,
          ],
          stops: const [0, 0.35, 1],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12.w,
        14.h,
        12.w,
        shopBottomInset(context) + 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.10)
                : AppColors.divider(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  // v569 — micro-animation quand le forfait sélectionné
                  // change : le prix (et son équivalent mensuel) fondent et
                  // glissent au lieu de sauter d'un coup.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey<String>('$priceLabel|${subLabel ?? ''}'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            priceLabel,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 19.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: priceColor,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (subLabel != null && subLabel!.isNotEmpty)
                          Text(
                            subLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: titleColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 6,
              child: Semantics(
                button: true,
                enabled: enabled,
                label: buttonLabel,
                child: GestureDetector(
                  onTap: enabled ? onPressed : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: enabled || loading ? 1 : 0.45,
                    child: Container(
                      height: _buttonHeight,
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: const Alignment(-0.6, -1),
                          end: const Alignment(0.6, 1),
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        boxShadow: enabled
                            ? [
                                BoxShadow(
                                  color: colors.last.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  spreadRadius: -8,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                            : const <BoxShadow>[],
                      ),
                      child: loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: buttonTextColor,
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // v569 — cadenas discret : le paiement est
                                  // sécurisé (Apple / Airwallex).
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 13.sp,
                                    color: buttonTextColor.withValues(
                                        alpha: 0.75),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    buttonLabel,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                      color: buttonTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mentions obligatoires d'un achat boutique + liens CGU / confidentialité.
///
/// iOS (règle Apple 3.1.2) : durée, prix, renouvellement automatique, gestion
/// dans les réglages App Store. Android / autres : paiement par carte UNIQUE,
/// sans renouvellement automatique (c'est le fonctionnement réel du serveur).
class ShopLegalNote extends StatelessWidget {
  const ShopLegalNote({
    super.key,
    this.oneTime = false,
    this.onDark = false,
  });

  /// true = achat ponctuel (PawBoost) : jamais de renouvellement.
  final bool oneTime;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? Colors.white.withValues(alpha: 0.62)
        : AppColors.textSecondary(context);
    final String body;
    if (oneTime) {
      body = 'v566_shop_legal_onetime'.tr;
    } else if (Platform.isIOS) {
      body = 'v566_shop_legal_ios'.tr;
    } else {
      body = 'v566_shop_legal_other'.tr;
    }
    Widget link(String label, String url) => InkWell(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: TextStyle(fontSize: 10.5.sp, height: 1.35, color: color),
        ),
        SizedBox(height: 4.h),
        Wrap(
          spacing: 12.w,
          children: [
            link('iap_terms_link'.tr, kShopTermsUrl),
            link('iap_privacy_link'.tr, kShopPrivacyUrl),
          ],
        ),
      ],
    );
  }
}

/// Ligne « Gérer mon abonnement » : iOS → réglages d'abonnement App Store ;
/// ailleurs → feuille qui explique qu'il n'y a rien à annuler (paiement unique).
class ShopManageRow extends StatelessWidget {
  const ShopManageRow({
    super.key,
    required this.accent,
    this.activeUntil,
    this.onDark = false,
  });

  final Color accent;
  final DateTime? activeUntil;
  final bool onDark;

  /// v569 — ouvert aussi depuis la ligne « Gérer mon abonnement » du bloc
  /// « Aide & infos » (même comportement, même feuille).
  static Future<void> open(
    BuildContext context, {
    required Color accent,
    DateTime? activeUntil,
  }) =>
      ShopManageRow(accent: accent, activeUntil: activeUntil)._open(context);

  Future<void> _open(BuildContext context) async {
    if (Platform.isIOS) {
      final ok = await launchUrl(
        Uri.parse(kAppleManageSubscriptionsUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        // v567 — + dégagement système quand Android ment à 0 (Samsung).
        padding: EdgeInsets.fromLTRB(
            20.w, 14.h, 20.w, 20.h + shopSafeAreaExtraInset(ctx)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            InterText(
              text: Platform.isIOS
                  ? 'v566_shop_manage'.tr
                  : 'v566_shop_manage_other_title'.tr,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(ctx),
              maxLines: 2,
            ),
            SizedBox(height: 8.h),
            Text(
              Platform.isIOS
                  ? 'v566_shop_manage_ios_hint'.tr
                  : 'v566_shop_manage_other_body'.tr,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: AppColors.textSecondary(ctx),
              ),
            ),
            if (activeUntil != null) ...[
              SizedBox(height: 10.h),
              Text(
                'v566_shop_active_until'
                    .tr
                    .replaceAll('{date}', shopShortDate(activeUntil!)),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.10),
                  foregroundColor: accent,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'common_ok'.tr,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white.withValues(alpha: 0.9) : accent;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        // v567 — cible tactile ≥ 48 px, alignée sur le sélecteur de devise.
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: (onDark ? Colors.white : accent).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (onDark ? Colors.white : accent).withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.manage_accounts_outlined, size: 18.sp, color: fg),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'v566_shop_manage'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20.sp, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Bandeau ambre « Expire dans N j ».
class ShopExpiryNotice extends StatelessWidget {
  const ShopExpiryNotice({super.key, required this.days});

  final int days;

  /// Seuil « expiration proche ».
  static const int threshold = 5;

  static bool shouldShow(int days) => days > 0 && days <= threshold;

  @override
  Widget build(BuildContext context) {
    // Teinte de statut « ambre » : en mode sombre, le pastel clair devient un
    // pavé éblouissant et son texte brun (#92400E) reste illisible → fond
    // ambre très transparent + texte/icône éclaircis (règle des statuts).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFF59E0B);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark
            ? amber.withValues(alpha: 0.18)
            : const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? amber.withValues(alpha: 0.45)
              : const Color(0xFFF5C26B),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 18.sp,
              color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              (Platform.isIOS
                      ? 'v566_shop_expiring_soon_ios'
                      : 'v566_shop_expiring_soon')
                  .tr
                  .replaceAll('{days}', '$days'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFFCD34D)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// État d'erreur d'un onglet (réseau) avec bouton « Réessayer ».
class ShopErrorState extends StatelessWidget {
  const ShopErrorState({super.key, required this.onRetry, required this.accent});

  final VoidCallback onRetry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40.sp, color: AppColors.textSecondary(context)),
            SizedBox(height: 12.h),
            Text(
              'v566_shop_load_error'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            SizedBox(height: 14.h),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.10),
                foregroundColor: accent,
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'v566_shop_retry'.tr,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moyen de paiement annoncé dans la feuille de confirmation.
enum ShopPayMethod { appleIap, card, wallet }

/// Feuille de confirmation d'achat (remplace les AlertDialog hétérogènes).
///
/// Indispensable AVANT tout POST d'achat : le serveur active immédiatement les
/// comptes staff (gratuit) et les paiements wallet, sans écran de paiement.
/// Renvoie true si l'utilisateur confirme.
Future<bool> showShopConfirmSheet(
  BuildContext context, {
  required String productName,
  required String planLabel,
  required String priceLabel,
  required String durationLabel,
  required List<Color> colors,
  required Widget icon,
  required ShopPayMethod method,
  String? strikePriceLabel,
  String? noteLabel,
  bool oneTime = false,
  Color buttonTextColor = Colors.white,
}) async {
  final String methodLabel;
  final IconData methodIcon;
  switch (method) {
    case ShopPayMethod.appleIap:
      methodLabel = 'v566_shop_pay_apple'.tr;
      methodIcon = Icons.apple_rounded;
      break;
    case ShopPayMethod.wallet:
      methodLabel = 'v566_shop_pay_wallet'.tr;
      methodIcon = Icons.account_balance_wallet_outlined;
      break;
    case ShopPayMethod.card:
      methodLabel = 'v566_shop_pay_card'.tr;
      methodIcon = Icons.credit_card_rounded;
      break;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      Widget line(IconData ic, String label, String value, {String? strike}) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 9.h),
          child: Row(
            children: [
              Icon(ic, size: 18.sp, color: AppColors.textSecondary(ctx)),
              SizedBox(width: 10.w),
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary(ctx),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (strike != null) ...[
                      Flexible(
                        child: Text(
                          strike,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary(ctx),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.textSecondary(ctx),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 2,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
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

      return SingleChildScrollView(
        // v567 — + dégagement système quand Android ment à 0 (Samsung) : le
        // bouton « Payer » finissait derrière la barre de navigation.
        padding: EdgeInsets.fromLTRB(
            20.w, 12.h, 20.w, 18.h + shopSafeAreaExtraInset(ctx)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: const Alignment(-0.6, -1),
                      end: const Alignment(0.6, 1),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45)),
                  ),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: icon,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v566_shop_confirm_title'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(ctx),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.scaffold(ctx),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  line(Icons.sell_outlined, 'v566_shop_confirm_offer'.tr,
                      planLabel),
                  Divider(height: 1, color: AppColors.divider(ctx)),
                  line(Icons.event_available_outlined,
                      'v566_shop_confirm_duration'.tr, durationLabel),
                  Divider(height: 1, color: AppColors.divider(ctx)),
                  line(Icons.payments_outlined, 'v566_shop_confirm_price'.tr,
                      priceLabel,
                      strike: strikePriceLabel),
                  Divider(height: 1, color: AppColors.divider(ctx)),
                  line(methodIcon, 'v566_shop_confirm_payment'.tr, methodLabel),
                ],
              ),
            ),
            if (noteLabel != null && noteLabel.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                noteLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.last,
                ),
              ),
            ],
            SizedBox(height: 10.h),
            ShopLegalNote(oneTime: oneTime),
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                height: 52.h,
                width: double.infinity,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: const Alignment(-0.6, -1),
                    end: const Alignment(0.6, 1),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'v566_shop_confirm_pay'.tr.replaceAll('{price}', priceLabel),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                      color: buttonTextColor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'common_cancel'.tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(ctx),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result == true;
}
