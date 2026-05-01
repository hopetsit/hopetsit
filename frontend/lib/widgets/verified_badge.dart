import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// v23.1 part 36 — badge "✓ Vérifié" affiché à côté du nom des sitters/walkers
/// dont kycStatus == 'verified' (passeport ou CNI vérifié via Persona).
///
/// Variants :
/// - `inline` (default) : petit badge à côté d'un nom
/// - `large` : badge plus visible pour le profil
class VerifiedBadge extends StatelessWidget {
  /// Si false, le widget ne render rien (utilisé conditionnellement).
  final bool isVerified;
  final bool large;
  final String? tooltipText;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.large = false,
    this.tooltipText,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    final iconSize = large ? 18.sp : 14.sp;
    final padding = large
        ? EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h)
        : EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h);
    final color = const Color(0xFF1976D2); // Material Blue 700

    final widget = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: iconSize,
            color: color,
          ),
          if (large) ...[
            SizedBox(width: 4.w),
            Text(
              'Vérifié',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
    if (tooltipText != null && tooltipText!.isNotEmpty) {
      return Tooltip(message: tooltipText!, child: widget);
    }
    return widget;
  }
}
