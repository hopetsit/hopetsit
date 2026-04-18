import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// A simple 2- or 3-segment control with a press animation.
///
/// - If [middleText] is null: segments are `left` (index 0) and `right` (index 1)
/// - If [middleText] is provided: segments are `left` (0), `middle` (1), `right` (2)
class CustomSegmentedControl extends StatefulWidget {
  final String leftText;
  final String? middleText;
  final String rightText;

  /// Backward-compat (used when [selectedIndex] is not provided).
  final bool isLeftSelected;

  /// Preferred way to set initial selection (0,1,2 depending on segments).
  final int? selectedIndex;

  final VoidCallback? onLeftTap;
  final VoidCallback? onMiddleTap;
  final VoidCallback? onRightTap;

  final double? width;
  final double? height;

  /// Optional per-segment active colors. When omitted, all segments use the
  /// app primary color (legacy behaviour). Used on the owner home to theme
  /// Publication (primary/orange), Pet-sitter (blue), Promeneur (green).
  final Color? activeColorLeft;
  final Color? activeColorMiddle;
  final Color? activeColorRight;

  const CustomSegmentedControl({
    super.key,
    required this.leftText,
    this.middleText,
    required this.rightText,
    this.isLeftSelected = true,
    this.selectedIndex,
    this.onLeftTap,
    this.onMiddleTap,
    this.onRightTap,
    this.width,
    this.height,
    this.activeColorLeft,
    this.activeColorMiddle,
    this.activeColorRight,
  });

  @override
  State<CustomSegmentedControl> createState() =>
      _CustomSegmentedControlState();
}

class _CustomSegmentedControlState extends State<CustomSegmentedControl>
    with TickerProviderStateMixin {
  late int _selectedIndex; // 0 left, 1 middle (if any), 2 right
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final rightIndex = widget.middleText != null ? 2 : 1;
    _selectedIndex = widget.selectedIndex ?? (widget.isLeftSelected ? 0 : rightIndex);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.selectedIndex;
    if (index != null && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  void _playTapAnimation() {
    HapticFeedback.lightImpact();
    _scaleController.forward().then((_) => _scaleController.reverse());
  }

  void _onLeftTap() {
    if (_selectedIndex == 0) return;
    _playTapAnimation();
    setState(() => _selectedIndex = 0);
    widget.onLeftTap?.call();
  }

  void _onMiddleTap() {
    if (widget.middleText == null) return;
    if (_selectedIndex == 1) return;
    _playTapAnimation();
    setState(() => _selectedIndex = 1);
    widget.onMiddleTap?.call();
  }

  void _onRightTap() {
    final rightIndex = widget.middleText != null ? 2 : 1;
    if (_selectedIndex == rightIndex) return;
    _playTapAnimation();
    setState(() => _selectedIndex = rightIndex);
    widget.onRightTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasMiddle = widget.middleText != null;
    final leftActive = widget.activeColorLeft ?? AppColors.primaryColor;
    final middleActive =
        widget.activeColorMiddle ?? AppColors.primaryColor;
    final rightActive = widget.activeColorRight ?? AppColors.primaryColor;

    return SizedBox(
      width: widget.width,
      child: Container(
        height: widget.height ?? 50.h,
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.grey300Color, width: 1.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Row(
                  children: [
                    // Left section (index 0)
                    Expanded(
                      child: GestureDetector(
                        onTap: _onLeftTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: _selectedIndex == 0
                                ? leftActive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.w),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: InterText(
                                  text: widget.leftText,
                                  textAlign: TextAlign.center,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedIndex == 0
                                      ? AppColors.whiteColor
                                      : AppColors.grey500Color,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (hasMiddle) ...[
                      SizedBox(width: 8.w),
                      // Middle section (index 1)
                      Expanded(
                        child: GestureDetector(
                          onTap: _onMiddleTap,
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: _selectedIndex == 1
                                  ? middleActive
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: InterText(
                                    text: widget.middleText!,
                                    textAlign: TextAlign.center,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedIndex == 1
                                        ? AppColors.whiteColor
                                        : AppColors.grey500Color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(width: 8.w),
                    // Right section (index 1 or 2 depending on middle)
                    Expanded(
                      child: GestureDetector(
                        onTap: _onRightTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: _selectedIndex ==
                                    (hasMiddle ? 2 : 1)
                                ? rightActive
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.w),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: InterText(
                                  text: widget.rightText,
                                  textAlign: TextAlign.center,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedIndex ==
                                          (hasMiddle ? 2 : 1)
                                      ? AppColors.whiteColor
                                      : AppColors.grey500Color,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

