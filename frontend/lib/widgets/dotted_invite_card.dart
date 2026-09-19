import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';

/// v552 — carte à bordure pointillée de la spec redesign v3 (« Inviter
/// quelqu'un à partager sa position »). Peinte à la main : pas de dépendance
/// supplémentaire pour un simple pointillé.
class DottedInviteCard extends StatelessWidget {
  const DottedInviteCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.color = PawMapTheme.ok,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // v569 — DESIGN UNIQUEMENT : même API (title / subtitle / color). Le
    // pointillé posé sur un léger fond teinté (coins 20) se lit mieux, le
    // disque d'icône devient rond et le chevron est mis dans une pastille.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: color.withValues(alpha: 0.55)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 14.w),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_alt_1_rounded,
                    color: color, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.font(
                          size: 13.5.sp, weight: FontWeight.w800),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PawMapTheme.font(
                        size: 11.5.sp,
                        weight: FontWeight.w500,
                        color: PawMapTheme.sub,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 26.w,
                height: 26.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: color, size: 18.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    final path = Path()..addRRect(rect);
    const dash = 7.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}
