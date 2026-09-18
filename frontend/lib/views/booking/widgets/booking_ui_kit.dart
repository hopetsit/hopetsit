// v565 (points 17 / 35) — kit d'interface partagé par les écrans Réservations
// des 3 rôles (owner / sitter / walker) et l'historique.
//
// Style Apple minimaliste + Paw Buttons : cartes `rounded 20` sans ombre
// lourde, filtres en pilules, pastilles de statut avec point coloré, états
// vide / chargement (squelettes) / erreur (avec « Réessayer ») uniformes.
// Toutes les chaînes passent par les clés de traduction (9 langues).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

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
        return BookingStatusStyle(const Color(0xFF6B7280),
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
            const Color(0xFF6B7280), primary.tr, Icons.info_rounded);
    }
  }
}

/// Pastille de statut : point coloré + libellé, fond teinté.
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Flexible(
            child: InterText(
              text: s.label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: s.color,
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
    return SizedBox(
      height: 46.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 6.h),
        itemCount: values.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, i) {
          final v = values[i];
          final isLink = linkValues.contains(v);
          final isSel = !isLink && selected == v;
          final c = counts?[v];
          return GestureDetector(
            onTap: () => onSelected(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isSel
                    ? accent
                    : AppColors.textSecondary(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
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
        },
      ),
    );
  }
}

/// Conteneur de carte : coins 20, fond carte, liseré discret, ombre légère.
class BookingCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  const BookingCard({
    super.key,
    required this.child,
    required this.accent,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
        Center(
          child: Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 38.sp, color: accent),
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
            child: ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: InterText(
                text: ctaLabel!,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
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
              color: red.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded, size: 38.sp, color: red),
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
        color: AppColors.textSecondary(context).withValues(alpha: 0.14),
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
