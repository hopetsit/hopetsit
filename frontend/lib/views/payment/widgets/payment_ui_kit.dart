// v569 — kit de widgets des écrans de paiement (design uniquement).
//
// Daniel, build 569 : « si tu peux moderniser les pages de paiement de service,
// quand le propriétaire paye ». Direction : sobre et rassurante, façon Apple
// Pay / Stripe Checkout. Ces widgets ne connaissent AUCUNE logique de
// paiement : ils reçoivent des libellés déjà traduits et des callbacks. Toute
// la chaîne (Airwallex, PayPal, intentions, confirmation serveur) reste dans
// les contrôleurs et services, strictement inchangée.
//
// Règles du projet respectées ici :
//  - aucun `Obx` (ces widgets sont purement présentationnels) ;
//  - pas de `CrossAxisAlignment.stretch` avec `Expanded` dans un scroll ;
//  - pas d'`Expanded` sous `IntrinsicHeight` ;
//  - textes fournis par l'appelant via `.tr` (rien en dur, rien qui déborde :
//    `maxLines` + `FittedBox`/`ellipsis` partout où le texte peut grandir).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Barre du haut
// ─────────────────────────────────────────────────────────────────────────────

/// Barre du haut commune aux écrans de paiement : retour, titre centré avec un
/// petit cadenas, et (optionnel) le montant en sous-titre.
class PaySecureAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color accent;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final String? backTooltip;

  const PaySecureAppBar({
    super.key,
    required this.accent,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    this.backTooltip,
  });

  @override
  Size get preferredSize => Size.fromHeight(56.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.scaffold(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      iconTheme: IconThemeData(color: accent),
      leading: onBack == null
          ? null
          : IconButton(
              icon: Icon(backIcon, size: 20.sp, color: accent),
              tooltip: backTooltip,
              onPressed: onBack,
            ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded,
                  size: 14.sp, color: AppColors.textSecondary(context)),
              SizedBox(width: 6.w),
              Flexible(
                child: PoppinsText(
                  text: title,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            InterText(
              text: subtitle!,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: accent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Montant en tête
// ─────────────────────────────────────────────────────────────────────────────

/// Bloc « ce que je paie » : libellé discret + montant en gros, dans la devise
/// déjà formatée par l'appelant (jamais d'euro codé en dur).
class PayAmountHero extends StatelessWidget {
  final String label;
  final String amount;
  final Color accent;
  final IconData icon;

  const PayAmountHero({
    super.key,
    required this.label,
    required this.amount,
    required this.accent,
    this.icon = Icons.lock_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64.w,
          height: 64.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                accent.withValues(alpha: 0.06),
              ],
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 28.sp, color: accent),
        ),
        SizedBox(height: 12.h),
        InterText(
          text: label,
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
        SizedBox(height: 2.h),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: PoppinsText(
            text: amount,
            fontSize: 34.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Récapitulatif repliable
// ─────────────────────────────────────────────────────────────────────────────

/// Une ligne du récapitulatif (icône + libellé + valeur).
class PayRecapLine {
  final IconData icon;
  final String label;
  final String value;
  const PayRecapLine({
    required this.icon,
    required this.label,
    required this.value,
  });
}

/// Carte récapitulative compacte : en-tête toujours visible (prestataire +
/// service + total), détail repliable en dessous. Rien ne recouvre la page de
/// paiement : cette carte vit au-dessus, dans le flux normal.
class PayRecapCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String totalLabel;
  final String totalValue;
  final Color accent;
  final List<PayRecapLine> lines;
  final String expandLabel;
  final String collapseLabel;
  final bool initiallyExpanded;
  final String? avatarUrl;

  const PayRecapCard({
    super.key,
    required this.title,
    required this.totalLabel,
    required this.totalValue,
    required this.accent,
    required this.lines,
    required this.expandLabel,
    required this.collapseLabel,
    this.subtitle,
    this.initiallyExpanded = false,
    this.avatarUrl,
  });

  @override
  State<PayRecapCard> createState() => _PayRecapCardState();
}

class _PayRecapCardState extends State<PayRecapCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final hasLines = widget.lines.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(context),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: widget.title,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null &&
                        widget.subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      InterText(
                        text: widget.subtitle!,
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(color: AppColors.divider(context), height: 1),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: InterText(
                  text: widget.totalLabel,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                ),
              ),
              SizedBox(width: 10.w),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PoppinsText(
                    text: widget.totalValue,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: widget.accent,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          if (hasLines) ...[
            AnimatedCrossFade(
              firstChild: SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < widget.lines.length; i++) ...[
                      if (i > 0) SizedBox(height: 10.h),
                      PayDetailLine(line: widget.lines[i]),
                    ],
                  ],
                ),
              ),
              crossFadeState: _open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOutCubic,
            ),
            SizedBox(height: 4.h),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _open = !_open),
                style: TextButton.styleFrom(
                  foregroundColor: widget.accent,
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: InterText(
                        text: _open ? widget.collapseLabel : widget.expandLabel,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: widget.accent,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18.sp, color: widget.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context) {
    final url = widget.avatarUrl;
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.accent.withValues(alpha: 0.12),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: (url != null && url.isNotEmpty)
          ? null
          : Icon(Icons.person_rounded, color: widget.accent, size: 22.sp),
    );
  }
}

/// Ligne « icône · libellé · valeur » réutilisable hors du récapitulatif.
class PayDetailLine extends StatelessWidget {
  final PayRecapLine line;
  const PayDetailLine({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(
            color: AppColors.scaffold(context),
            borderRadius: BorderRadius.circular(9.r),
          ),
          alignment: Alignment.center,
          child: Icon(line.icon,
              size: 15.sp, color: AppColors.textSecondary(context)),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: line.label,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 1.h),
              PoppinsText(
                text: line.value,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
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

// ─────────────────────────────────────────────────────────────────────────────
// Confiance
// ─────────────────────────────────────────────────────────────────────────────

/// Rangée de confiance discrète : 1 à 3 gages (chiffrement, séquestre…) puis
/// les pastilles de marques en TEXTE (aucune image, aucun logo importé).
class PayTrustRow extends StatelessWidget {
  final List<String> assurances;
  final List<String> brands;
  final Color accent;

  const PayTrustRow({
    super.key,
    required this.assurances,
    required this.accent,
    this.brands = const <String>['VISA', 'Mastercard'],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final a in assurances)
          _pill(
            context,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 13.sp, color: accent),
                SizedBox(width: 5.w),
                Flexible(
                  child: InterText(
                    text: a,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                    // 2 lignes : « Argent bloqué jusqu'à la fin du service »
                    // ne tient pas sur une ligne en allemand ni en polonais.
                    maxLines: 2,
                    height: 1.25,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            border: accent.withValues(alpha: 0.18),
          ),
        for (final b in brands)
          _pill(
            context,
            child: Text(
              b.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textSecondary(context),
              ),
            ),
            border: AppColors.divider(context),
          ),
      ],
    );
  }

  Widget _pill(BuildContext context,
      {required Widget child, required Color border}) {
    return Container(
      constraints: BoxConstraints(maxWidth: 268.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// États : chargement / erreur
// ─────────────────────────────────────────────────────────────────────────────

/// Carte d'état pendant l'ouverture de la page sécurisée : indicateur,
/// message, et (si la WebView expose sa progression) une barre fine.
class PayLoadingCard extends StatelessWidget {
  final String message;
  final String? hint;
  final Color accent;
  final double? progress;

  const PayLoadingCard({
    super.key,
    required this.message,
    required this.accent,
    this.hint,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18.w,
                height: 18.w,
                child:
                    CircularProgressIndicator(color: accent, strokeWidth: 2.4),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: message,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 3.h,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3.h,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          if (hint != null && hint!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            InterText(
              text: hint!,
              fontSize: 11.5.sp,
              color: AppColors.textSecondary(context),
              height: 1.4,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

/// Squelette centré (page sécurisée en cours d'ouverture) — utilisé en
/// plein écran au-dessus d'une WebView encore vide.
class PayLoadingOverlay extends StatelessWidget {
  final String message;
  final Color accent;
  final double? progress;

  const PayLoadingOverlay({
    super.key,
    required this.message,
    required this.accent,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffold(context),
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 26.w,
              height: 26.w,
              child: CircularProgressIndicator(color: accent, strokeWidth: 2.6),
            ),
          ),
          SizedBox(height: 18.h),
          InterText(
            text: message,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
            maxLines: 3,
            height: 1.4,
          ),
          SizedBox(height: 18.h),
          // Squelette : trois barres qui suggèrent le futur formulaire.
          for (final w in <double>[1, 0.72, 0.5]) ...[
            _skeletonBar(context, w),
            SizedBox(height: 10.h),
          ],
          SizedBox(height: 4.h),
          SizedBox(
            width: 160.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3.h,
                backgroundColor: accent.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBar(BuildContext context, double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12.h,
        decoration: BoxDecoration(
          color: AppColors.divider(context).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// État d'erreur illustré : icône, titre, cause lisible, « Réessayer » et
/// « Annuler » (les mêmes actions qu'avant, seul l'habillage change).
class PayErrorPanel extends StatelessWidget {
  final String title;
  final String message;
  final String retryLabel;
  final String cancelLabel;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  final Color accent;
  final IconData icon;

  const PayErrorPanel({
    super.key,
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.cancelLabel,
    required this.onRetry,
    required this.onCancel,
    required this.accent,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78.w,
              height: 78.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.errorColor.withValues(alpha: 0.10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 34.sp, color: AppColors.errorColor),
            ),
            SizedBox(height: 16.h),
            PoppinsText(
              text: title,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            SizedBox(height: 8.h),
            InterText(
              text: message,
              fontSize: 13.sp,
              color: AppColors.textSecondary(context),
              textAlign: TextAlign.center,
              height: 1.45,
              maxLines: 5,
            ),
            SizedBox(height: 22.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size(double.infinity, 50.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18.sp),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: PoppinsText(
                        text: retryLabel,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary(context),
                minimumSize: Size(double.infinity, 46.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)),
              ),
              child: InterText(
                text: cancelLabel,
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
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

// ─────────────────────────────────────────────────────────────────────────────
// Résultat
// ─────────────────────────────────────────────────────────────────────────────

/// Grand disque animé du résultat : le cercle grandit, puis la coche (ou la
/// croix) se dessine. Aucune dépendance ajoutée — `TweenAnimationBuilder` +
/// `CustomPainter`. Le retour haptique part une seule fois, au montage.
class PayResultBadge extends StatefulWidget {
  final bool success;
  final double size;

  const PayResultBadge({super.key, required this.success, this.size = 118});

  @override
  State<PayResultBadge> createState() => _PayResultBadgeState();
}

class _PayResultBadgeState extends State<PayResultBadge> {
  @override
  void initState() {
    super.initState();
    // Retour haptique au résultat (succès = léger, échec = plus marqué).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.success) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color c =
        widget.success ? const Color(0xFF16A34A) : AppColors.errorColor;
    final double d = widget.size.w;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final scale = 0.7 + 0.3 * t.clamp(0.0, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.12),
        ),
        alignment: Alignment.center,
        child: Container(
          width: d * 0.72,
          height: d * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(c, Colors.white, 0.18)!,
                Color.lerp(c, Colors.black, 0.08)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, p, _) => CustomPaint(
              size: Size(d * 0.40, d * 0.40),
              painter: _PayMarkPainter(progress: p, success: widget.success),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dessine la coche (succès) ou la croix (échec) au fil de `progress`.
class _PayMarkPainter extends CustomPainter {
  final double progress;
  final bool success;

  _PayMarkPainter({required this.progress, required this.success});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (success) {
      final a = Offset(size.width * 0.10, size.height * 0.54);
      final b = Offset(size.width * 0.40, size.height * 0.82);
      final c = Offset(size.width * 0.90, size.height * 0.20);
      // Deux segments dessinés l'un après l'autre (0 → 0.4 puis 0.4 → 1).
      final t1 = (progress / 0.4).clamp(0.0, 1.0);
      canvas.drawLine(a, Offset.lerp(a, b, t1)!, p);
      if (progress > 0.4) {
        final t2 = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
        canvas.drawLine(b, Offset.lerp(b, c, t2)!, p);
      }
    } else {
      final a1 = Offset(size.width * 0.18, size.height * 0.18);
      final b1 = Offset(size.width * 0.82, size.height * 0.82);
      final a2 = Offset(size.width * 0.82, size.height * 0.18);
      final b2 = Offset(size.width * 0.18, size.height * 0.82);
      final t1 = (progress / 0.5).clamp(0.0, 1.0);
      canvas.drawLine(a1, Offset.lerp(a1, b1, t1)!, p);
      if (progress > 0.5) {
        final t2 = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
        canvas.drawLine(a2, Offset.lerp(a2, b2, t2)!, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PayMarkPainter old) =>
      old.progress != progress || old.success != success;
}

/// Pastille d'état (payé / échec / en attente) sous le titre du résultat.
class PayStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const PayStatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Flexible(
            child: InterText(
              text: label,
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              color: color,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// « Prochaines étapes » : 2-3 lignes à icônes, dans une carte douce.
class PayNextSteps extends StatelessWidget {
  final String title;
  final List<PayStep> steps;
  final Color accent;

  const PayNextSteps({
    super.key,
    required this.title,
    required this.steps,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: title,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            maxLines: 2,
          ),
          SizedBox(height: 12.h),
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(steps[i].icon, size: 16.sp, color: accent),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: InterText(
                      text: steps[i].text,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                      height: 1.35,
                      maxLines: 3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Une étape de « et maintenant ? ».
class PayStep {
  final IconData icon;
  final String text;
  const PayStep({required this.icon, required this.text});
}
