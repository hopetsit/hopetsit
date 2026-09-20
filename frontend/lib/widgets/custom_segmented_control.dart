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

  /// v569 — un seul segment de texte (même taille de police sur les 3, cf.
  /// v23.1.147 : « El tamaño del texto debe de ser igual »).
  Widget _segment({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: InterText(
              text: text,
              textAlign: TextAlign.center,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.whiteColor : AppColors.textTertiary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // v569 — RENDU SEULEMENT : les index, les rappels (onLeftTap /
    // onMiddleTap / onRightTap), le retour haptique et `didUpdateWidget`
    // sont inchangés. La bascule se fait désormais avec UNE pilule qui
    // GLISSE (au lieu de trois fonds qui s'allument/s'éteignent) et le
    // cadre suit le thème sombre.
    final hasMiddle = widget.middleText != null;
    final leftActive = widget.activeColorLeft ?? AppColors.primaryColor;
    final middleActive = widget.activeColorMiddle ?? AppColors.primaryColor;
    final rightActive = widget.activeColorRight ?? AppColors.primaryColor;

    final int count = hasMiddle ? 3 : 2;
    final int rightIndex = hasMiddle ? 2 : 1;
    final Color pillColor = _selectedIndex == 0
        ? leftActive
        : (_selectedIndex == 1 && hasMiddle ? middleActive : rightActive);
    // -1 (gauche) → +1 (droite) : position de la pilule.
    final double alignX = (_selectedIndex / (count - 1)) * 2 - 1;

    return SizedBox(
      width: widget.width,
      child: Container(
        height: widget.height ?? 50.h,
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.divider(context), width: 1.w),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                children: [
                  // Pilule glissante.
                  AnimatedAlign(
                    alignment: Alignment(alignX, 0),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: 1 / count,
                      heightFactor: 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: pillColor,
                          borderRadius: BorderRadius.circular(11.r),
                          boxShadow: [
                            BoxShadow(
                              color: pillColor.withValues(alpha: 0.28),
                              blurRadius: 10,
                              spreadRadius: -2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Libellés + zones tactiles.
                  Row(
                    children: [
                      _segment(
                        text: widget.leftText,
                        selected: _selectedIndex == 0,
                        onTap: _onLeftTap,
                      ),
                      if (hasMiddle)
                        _segment(
                          text: widget.middleText!,
                          selected: _selectedIndex == 1,
                          onTap: _onMiddleTap,
                        ),
                      _segment(
                        text: widget.rightText,
                        selected: _selectedIndex == rightIndex,
                        onTap: _onRightTap,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

