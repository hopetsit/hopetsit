import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Small red circular badge showing a count ("N" or "N+" when > cap).
/// Returns SizedBox.shrink when count is 0.
class NotificationBadge extends StatelessWidget {
  final int count;
  final int cap;
  final Color background;
  final Color foreground;

  const NotificationBadge({
    super.key,
    required this.count,
    this.cap = 9,
    this.background = const Color(0xFFE53935),
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > cap ? '$cap+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.h),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
