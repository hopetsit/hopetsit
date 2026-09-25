// v565 (points 17 / 35) — kit d'interface partagé par les écrans Réservations
// des 3 rôles (owner / sitter / walker) et l'historique.
//
// Style Apple minimaliste + Paw Buttons : cartes `rounded 20` sans ombre
// lourde, filtres en pilules, pastilles de statut avec point coloré, états
// vide / chargement (squelettes) / erreur (avec « Réessayer ») uniformes.
// Toutes les chaînes passent par les clés de traduction (9 langues).
//
// v571 — modernisation des 3 pages Réservations (Daniel : « encore plus
// moderne […] les 4 onglets aussi »). Ajouts, tous PUBLICS et paramétrés,
// à API compatible avec l'existant (les nouveaux paramètres sont optionnels) :
//   · [BookingSegmentedTabs] — sélecteur segmenté des 4 onglets, cohérent
//     avec `_buildTabBar` de l'accueil propriétaire : conteneur arrondi 16
//     sur `AppColors.card`, bord `AppColors.divider`, pastille active pleine
//     à la couleur du rôle, animation 200 ms, auto-défilement vers l'onglet
//     actif (aucun débordement possible à 320 dp, même en allemand/polonais) ;
//   · [BookingAppBarTitle] — titre + sous-titre/compteur de l'en-tête ;
//   · [BookingPartyHeader] — avatar + nom + service en tête de carte ;
//   · [BookingMetaChip] — pastille « icône + valeur » (animal, date, heure…) ;
//   · [BookingPriceRow] — bloc prix bien lisible.
// Mode sombre : aucune couleur en dur pour les textes et les fonds ; les
// pastilles de statut sont éclaircies en sombre pour rester lisibles.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Couleur de TEXTE lisible pour une couleur d'état donnée.
///
/// En sombre, les couleurs pleines (#16A34A, #2563EB…) deviennent trop
/// sourdes sur un fond #242424 : on les éclaircit. En clair, on les garde.
Color bookingToneForeground(BuildContext context, Color tone) =>
    _isDark(context) ? Color.lerp(tone, Colors.white, 0.42)! : tone;

/// Fond teinté d'une pastille d'état (≈ 18 % d'alpha, un peu plus en sombre).
Color bookingToneSurface(BuildContext context, Color tone) =>
    tone.withValues(alpha: _isDark(context) ? 0.22 : 0.14);

/// Couleur + libellé d'un statut de réservation (fusion statut + paiement).
class BookingStatusStyle {
  final Color color;
  final String label;
  final IconData icon;
  const BookingStatusStyle(this.color, this.label, this.icon);

  /// [status] = statut de la réservation, [paymentStatus] = statut du
  /// paiement (prioritaire quand payé / échoué), [accent] = couleur du rôle
  /// pour « acceptée ».
  static BookingStatusStyle resolve(
    String status, {
    String? paymentStatus,
    Color? accent,
  }) {
    final st = status.toLowerCase().trim();
    final pay = (paymentStatus ?? '').toLowerCase().trim();
    String primary = st;
    if (pay == 'paid') primary = 'paid';
    if (pay == 'failed') primary = 'payment_failed';
    switch (primary) {
      case 'paid':
        return BookingStatusStyle(const Color(0xFF16A34A),
            'status_paid_label'.tr, Icons.check_circle_rounded);
      case 'completed':
        return BookingStatusStyle(const Color(0xFF16A34A),
            'status_completed_label'.tr, Icons.verified_rounded);
      case 'pending':
        return BookingStatusStyle(const Color(0xFFF59E0B),
            'status_pending_label'.tr, Icons.schedule_rounded);
      case 'payment_pending':
        return BookingStatusStyle(const Color(0xFFF59E0B),
            'status_payment_pending_label'.tr, Icons.schedule_rounded);
      case 'agreed':
      case 'accepted':
        return BookingStatusStyle(accent ?? AppColors.primaryColor,
            'status_agreed_label'.tr, Icons.handshake_rounded);
      case 'cancelled':
      case 'rejected':
        return BookingStatusStyle(const Color(0xFF8B6960),
            'status_cancelled_label'.tr, Icons.cancel_rounded);
      case 'refunded':
        return BookingStatusStyle(const Color(0xFF2563EB),
            'status_refunded_label'.tr, Icons.undo_rounded);
      case 'failed':
        return BookingStatusStyle(const Color(0xFFEF4444),
            'status_failed_label'.tr, Icons.error_rounded);
      case 'payment_failed':
        return BookingStatusStyle(const Color(0xFFEF4444),
            'status_payment_failed_label'.tr, Icons.error_rounded);
      default:
        return BookingStatusStyle(
            const Color(0xFF8B6960), primary.tr, Icons.info_rounded);
    }
  }
}

/// Pastille de statut : icône + libellé, fond teinté.
///
/// v571 — le fond passe à ≈ 18 % d'alpha et le texte est ÉCLAIRCI en mode
/// sombre (`bookingToneForeground`) : les statuts gris et bleus étaient
/// illisibles sur le fond #242424 des cartes.
class BookingStatusChip extends StatelessWidget {
  final String status;
  final String? paymentStatus;
  final Color? accent;
  const BookingStatusChip({
    super.key,
    required this.status,
    this.paymentStatus,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final s = BookingStatusStyle.resolve(status,
        paymentStatus: paymentStatus, accent: accent);
    final Color fg = bookingToneForeground(context, s.color);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bookingToneSurface(context, s.color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12.sp, color: fg),
          SizedBox(width: 5.w),
          Flexible(
            child: InterText(
              text: s.label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: fg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre de filtres en pilules (défilement horizontal).
class BookingFilterBar extends StatelessWidget {
  final List<String> values;
  final String selected;
  final String Function(String) label;
  final ValueChanged<String> onSelected;
  final Color accent;
  /// Valeurs qui ouvrent un écran au lieu de filtrer (ex. « Factures ») :
  /// affichées avec une icône de lien.
  final Set<String> linkValues;
  /// Compteurs facultatifs par valeur (affichés en petit).
  final Map<String, int>? counts;

  const BookingFilterBar({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.accent,
    this.linkValues = const <String>{},
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    // v573 — Daniel ne veut pas de filtres qui glissent : les pastilles se
    // rangent sur plusieurs lignes FIXES (Wrap), tout est visible d'un coup.
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: List<Widget>.generate(values.length, (i) {
          final v = values[i];
          final isLink = linkValues.contains(v);
          final isSel = !isLink && selected == v;
          final c = counts?[v];
          return GestureDetector(
            onTap: () => onSelected(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSel
                    ? accent
                    : AppColors.textSecondary(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLink) ...[
                    Icon(Icons.receipt_long_rounded,
                        size: 14.sp, color: AppColors.textPrimary(context)),
                    SizedBox(width: 5.w),
                  ],
                  InterText(
                    text: label(v),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isSel ? Colors.white : AppColors.textPrimary(context),
                    maxLines: 1,
                  ),
                  if (c != null && c > 0) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: isSel
                            ? Colors.white.withValues(alpha: 0.25)
                            : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: InterText(
                        text: '$c',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Icône par défaut d'un onglet de la page Réservations (v571).
///
/// Partagée par les 3 rôles pour que « Payée » ou « Factures » portent
/// toujours le même pictogramme.
IconData bookingTabIcon(String value) {
  switch (value.toLowerCase().trim()) {
    case 'all':
      return Icons.grid_view_rounded;
    case 'paid':
      return Icons.verified_rounded;
    case 'refunded':
      return Icons.undo_rounded;
    case 'factures':
      return Icons.receipt_long_rounded;
    case 'pending':
    case 'payment_pending':
      return Icons.schedule_rounded;
    case 'agreed':
    case 'accepted':
      return Icons.handshake_rounded;
    case 'completed':
      return Icons.task_alt_rounded;
    case 'cancelled':
    case 'rejected':
      return Icons.cancel_rounded;
    case 'failed':
      return Icons.error_rounded;
    default:
      return Icons.label_important_rounded;
  }
}

/// Sélecteur segmenté des onglets de la page Réservations (v571).
///
/// Même grammaire visuelle que `_buildTabBar` / `_tabPill` de l'accueil
/// propriétaire : conteneur arrondi 16 sur `AppColors.card(context)`, bord
/// `AppColors.divider(context)`, ombre douce, pastille active PLEINE à la
/// couleur d'accent du rôle avec texte blanc, transition 200 ms, icône +
/// libellé, et petite bulle de compteur quand [counts] en fournit un.
///
/// ⚠️ Avec 4 onglets et des libellés longs (allemand, polonais) une rangée à
/// largeurs égales déborde sous 360 dp. La rangée défile donc horizontalement
/// et l'onglet actif est automatiquement ramené dans la vue — aucun
/// débordement possible, et les libellés restent entiers (pas de FittedBox
/// qui les rendrait minuscules).
class BookingSegmentedTabs extends StatefulWidget {
  /// Valeurs des onglets, dans l'ordre (ex. all / refunded / paid / factures).
  final List<String> values;

  /// Valeur actuellement sélectionnée.
  final String selected;

  /// Libellé traduit d'une valeur.
  final String Function(String) label;

  /// Icône d'une valeur (facultatif : une icône par défaut sinon).
  final IconData Function(String)? icon;

  /// Rappelé au tap (le retour haptique est déjà envoyé).
  final ValueChanged<String> onSelected;

  /// Couleur d'accent du rôle.
  final Color accent;

  /// Valeurs qui OUVRENT un écran au lieu de filtrer (ex. « Factures ») :
  /// elles ne prennent jamais l'état actif et portent un chevron.
  final Set<String> linkValues;

  /// Compteurs facultatifs par valeur (bulle discrète).
  final Map<String, int>? counts;

  /// Marge extérieure (par défaut 16 h / 10 v).
  final EdgeInsetsGeometry? margin;

  const BookingSegmentedTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.accent,
    this.icon,
    this.linkValues = const <String>{},
    this.counts,
    this.margin,
  });

  @override
  State<BookingSegmentedTabs> createState() => _BookingSegmentedTabsState();
}

class _BookingSegmentedTabsState extends State<BookingSegmentedTabs> {
  IconData _iconFor(String v) {
    final IconData? custom = widget.icon?.call(v);
    if (custom != null) return custom;
    return Icons.circle_outlined;
  }

  // v571 — Daniel : « pas de slide dans les onglets de la page Réservations ».
  // Les onglets se partagent la largeur à parts égales (icône au-dessus du
  // libellé, libellé réduit par FittedBox si la langue est longue) : tout est
  // visible d'un coup, rien ne défile.
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < widget.values.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: 4.w),
            Expanded(child: _pill(context, widget.values[i])),
          ],
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String value) {
    final bool isLink = widget.linkValues.contains(value);
    final bool selected = !isLink && widget.selected == value;
    final int? count = widget.counts?[value];
    final Color fg =
        selected ? AppColors.whiteColor : AppColors.textSecondary(context);

    return GestureDetector(
      key: ValueKey<String>('booking_tab_$value'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {/* pas de moteur haptique */}
        widget.onSelected(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? widget.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isLink ? Icons.open_in_new_rounded : _iconFor(value),
                  size: 17.sp,
                  color: fg,
                ),
                if (count != null && count > 0) ...<Widget>[
                  SizedBox(width: 4.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.whiteColor.withValues(alpha: 0.26)
                          : widget.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: InterText(
                      text: '$count',
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.whiteColor
                          : bookingToneForeground(context, widget.accent),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 4.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: InterText(
                text: widget.label(value),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: fg,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Titre d'en-tête d'écran : titre + sous-titre/compteur discret (v571).
class BookingAppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const BookingAppBarTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PoppinsText(
          text: title,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
          SizedBox(height: 1.h),
          InterText(
            text: subtitle!,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Tête de carte : avatar (ou initiale), nom, service, pastille de statut.
class BookingPartyHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;
  const BookingPartyHeader({
    super.key,
    required this.name,
    required this.accent,
    this.avatarUrl,
    this.subtitle,
    this.trailing,
  });

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 44.w,
      height: 44.w,
      color: accent.withValues(alpha: _isDark(context) ? 0.26 : 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded,
          size: 24.sp, color: bookingToneForeground(context, accent)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String url = (avatarUrl ?? '').trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.30), width: 2),
          ),
          padding: EdgeInsets.all(2.w),
          child: ClipOval(
            child: url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url,
                    width: 44.w,
                    height: 44.w,
                    memCacheWidth: 132,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _placeholder(context),
                    errorWidget: (_, __, ___) => _placeholder(context),
                  )
                : _placeholder(context),
          ),
        ),
        SizedBox(width: 11.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InterText(
                text: name.trim().isNotEmpty ? name : '—',
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                SizedBox(height: 2.h),
                InterText(
                  text: subtitle!,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          SizedBox(width: 8.w),
          // Largeur bornée (et non `Flexible`) : la pastille reste collée à
          // droite et son libellé s'ellipse au lieu de pousser le nom.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 150.w),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

/// Pastille « icône + valeur » pour les méta-données d'une réservation
/// (animal, date, heure, durée). Se range dans un [Wrap] : jamais de
/// débordement, quelle que soit la langue.
class BookingMetaChip extends StatelessWidget {
  final IconData icon;
  final String value;

  /// Libellé long, lu par les lecteurs d'écran (l'icône porte le sens visuel).
  final String? semanticsLabel;
  final Color? tint;
  const BookingMetaChip({
    super.key,
    required this.icon,
    required this.value,
    this.semanticsLabel,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = tint ?? AppColors.textSecondary(context);
    return Semantics(
      label: semanticsLabel,
      value: value,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.textSecondary(context)
              .withValues(alpha: _isDark(context) ? 0.16 : 0.07),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13.sp, color: c),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 190.w),
              child: InterText(
                text: value.trim().isNotEmpty ? value : '—',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloc prix : pastille d'icône + petit libellé + montant bien lisible.
///
/// [amount] est la chaîne DÉJÀ construite par l'écran (« 48,00 € », mais aussi
/// « Tu as payé 48 € ») : le kit ne décide d'aucun texte.
class BookingPriceRow extends StatelessWidget {
  final String amount;
  final String? caption;
  final Color accent;
  final IconData icon;
  const BookingPriceRow({
    super.key,
    required this.amount,
    required this.accent,
    this.caption,
    this.icon = Icons.payments_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = bookingToneForeground(context, accent);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: _isDark(context) ? 0.24 : 0.10),
            borderRadius: BorderRadius.circular(11.r),
          ),
          child: Icon(icon, size: 17.sp, color: fg),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if ((caption ?? '').trim().isNotEmpty) ...<Widget>[
                InterText(
                  text: caption!,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
              ],
              InterText(
                text: amount,
                fontSize: 15.5.sp,
                fontWeight: FontWeight.w800,
                color: fg,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filet de séparation interne d'une carte.
class BookingCardDivider extends StatelessWidget {
  final double vertical;
  const BookingCardDivider({super.key, this.vertical = 12});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical.h),
      child: Container(height: 1, color: AppColors.divider(context)),
    );
  }
}

/// Conteneur de carte : coins 20, fond carte, liseré discret, ombre légère.
class BookingCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  /// v571 — marge extérieure (par défaut : 14 px sous la carte).
  final EdgeInsetsGeometry? margin;
  const BookingCard({
    super.key,
    required this.child,
    required this.accent,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? EdgeInsets.only(bottom: 14.h),
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: accent.withValues(alpha: _isDark(context) ? 0.26 : 0.14),
        ),
        // v571 — l'ombre noire en dur disparaissait en sombre ; le helper du
        // thème ne rend rien en sombre et une ombre douce en clair.
        boxShadow: AppColors.cardShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Ligne d'information (icône + libellé + valeur).
class BookingInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const BookingInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.textSecondary(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 14.sp, color: c),
          ),
          SizedBox(width: 10.w),
          SizedBox(
            width: 86.w,
            child: InterText(
              text: label,
              fontSize: 12.sp,
              color: AppColors.textSecondary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: InterText(
              text: value.trim().isNotEmpty ? value : '—',
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// État vide (icône dans un disque, titre, sous-titre, CTA facultatif).
class BookingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final Color accent;
  /// true = à loger dans un sliver / une colonne (pas de défilement propre).
  final bool embedded;
  const BookingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView pour que le pull-to-refresh reste possible sur l'état vide.
      shrinkWrap: embedded,
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          32.w, embedded ? 32.h : 60.h, 32.w, embedded ? 32.h : 120.h),
      children: [
        // v571 — illustration ronde à l'accent, avec un halo plus large pour
        // un état vide accueillant plutôt que « vide ».
        Center(
          child: Container(
            width: 108.w,
            height: 108.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _isDark(context) ? 0.12 : 0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 78.w,
              height: 78.w,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: _isDark(context) ? 0.24 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 36.sp, color: bookingToneForeground(context, accent)),
            ),
          ),
        ),
        SizedBox(height: 18.h),
        PoppinsText(
          text: title,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          SizedBox(height: 6.h),
          InterText(
            text: subtitle!,
            fontSize: 13.sp,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
          ),
        ],
        if (ctaLabel != null && onCta != null) ...[
          SizedBox(height: 20.h),
          Center(
            child: ActionPillButton(
              label: ctaLabel!,
              tone: accent,
              onPressed: onCta,
            ),
          ),
        ],
      ],
    );
  }
}

/// État d'erreur : message lisible + « Réessayer ».
class BookingErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool embedded;
  const BookingErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    return ListView(
      shrinkWrap: embedded,
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          32.w, embedded ? 32.h : 60.h, 32.w, embedded ? 32.h : 120.h),
      children: [
        Center(
          child: Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              color: red.withValues(alpha: _isDark(context) ? 0.22 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded,
                size: 38.sp, color: bookingToneForeground(context, red)),
          ),
        ),
        SizedBox(height: 18.h),
        PoppinsText(
          text: 'v565_bk_error_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.h),
        InterText(
          text: message,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 20.h),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded, size: 18.sp),
            label: InterText(
              text: 'common_retry'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary(context),
              side: BorderSide(
                  color: AppColors.textSecondary(context).withValues(alpha: 0.4)),
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Squelette de chargement : 3 cartes grises animées (sans dépendance).
class BookingLoadingList extends StatefulWidget {
  final Color accent;
  const BookingLoadingList({super.key, required this.accent});

  @override
  State<BookingLoadingList> createState() => _BookingLoadingListState();
}

class _BookingLoadingListState extends State<BookingLoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bone(BuildContext context, double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        // Lot D — os à la teinte du rôle (le brun translucide lisait « gris »
        // sur les captures du flux promeneur).
        color: widget.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final op = 0.55 + 0.45 * _c.value;
        return Opacity(
          opacity: op,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
            itemCount: 3,
            itemBuilder: (context, i) => BookingCard(
              accent: widget.accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _bone(context, 80.w, 22.h),
                      const Spacer(),
                      Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary(context)
                              .withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _bone(context, 90.w, 14.h),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  _bone(context, 180.w, 14.h),
                  SizedBox(height: 10.h),
                  _bone(context, 140.w, 14.h),
                  SizedBox(height: 10.h),
                  _bone(context, 220.w, 14.h),
                  SizedBox(height: 16.h),
                  _bone(context, double.infinity, 44.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
