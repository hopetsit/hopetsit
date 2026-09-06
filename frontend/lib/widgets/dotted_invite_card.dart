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
    return CustomPaint(
      painter: _DashedBorderPainter(color: color.withValues(alpha: 0.55)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15.r),
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
                    style: PawMapTheme.font(
                        size: 13.5.sp, weight: FontWeight.w800),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: PawMapTheme.font(
                      size: 11.5.sp,
                      weight: FontWeight.w500,
                      color: PawMapTheme.sub,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: PawMapTheme.sub, size: 20.sp),
          ],
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
      const Radius.circular(18),
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
