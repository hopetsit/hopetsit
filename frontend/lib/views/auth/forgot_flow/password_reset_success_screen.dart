import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_screen.dart';

/// v569 — RENDU SEULEMENT : le bouton renvoie toujours vers
/// `Get.offAll(() => const LoginScreen())`, les textes et les deux points de
/// contrôle sont inchangés.
///
/// La coche est désormais DESSINÉE progressivement par un
/// `TweenAnimationBuilder` (aucune dépendance ajoutée, aucun
/// `AnimationController` à gérer) : anneau qui s'ouvre puis trait de la coche
/// qui se trace.
class PasswordResetSuccessScreen extends StatelessWidget {
  const PasswordResetSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            22.w,
            24.h,
            22.w,
            28.h + appBottomInsetInsideSafeArea(context),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 32.h),

              // Success Icon Animation
              const _AnimatedSuccessCheck(),
              SizedBox(height: 32.h),

              // Success Title
              PoppinsText(
                text: 'forgot_password_reset_success_title'.tr,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              SizedBox(height: 12.h),

              // Success Message
              InterText(
                text: 'forgot_password_reset_success_message'.tr,
                fontSize: 14,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
                maxLines: 4,
              ),
              SizedBox(height: 32.h),

              // Success Checkpoints
              ForgotFlowCard(
                child: Column(
                  children: [
                    _buildCheckpoint(
                      icon: Icons.mail_outline,
                      title: 'forgot_password_email_verified_title'.tr,
                      subtitle: 'forgot_password_email_verified_subtitle'.tr,
                      context: context,
                    ),
                    SizedBox(height: 14.h),
                    Divider(
                      color: AppColors.divider(context).withValues(alpha: 0.7),
                      height: 1,
                    ),
                    SizedBox(height: 14.h),
                    _buildCheckpoint(
                      icon: Icons.lock_outline,
                      title: 'forgot_password_password_updated_title'.tr,
                      subtitle: 'forgot_password_password_updated_subtitle'.tr,
                      context: context,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28.h),

              // Continue Button
              CustomButton(
                height: 54.h,
                radius: 18.r,
                title: 'forgot_password_login_new_password'.tr,
                onTap: () {
                  Get.offAll(() => const LoginScreen());
                },
              ),
              SizedBox(height: 18.h),

              // Info Text
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFBC11).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFFFBC11).withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFFD99400),
                      size: 18.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: InterText(
                        text: 'forgot_password_security_warning'.tr,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                        maxLines: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckpoint({
    required IconData icon,
    required String title,
    required String subtitle,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor.withValues(alpha: 0.10),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 21.sp),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PoppinsText(
                text: title,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 2,
              ),
              SizedBox(height: 2.h),
              InterText(
                text: subtitle,
                fontSize: 12,
                color: AppColors.textSecondary(context),
                maxLines: 3,
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Icon(
          Icons.check_circle_rounded,
          size: 19.sp,
          color: const Color(0xFF16A34A),
        ),
      ],
    );
  }
}

/// Coche qui se trace, sans dépendance ni AnimationController.
class _AnimatedSuccessCheck extends StatelessWidget {
  const _AnimatedSuccessCheck();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        // 0 → 0.45 : le disque apparaît ; 0.35 → 1 : la coche se trace.
        final double disc = (t / 0.45).clamp(0.0, 1.0);
        final double stroke = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.85 + 0.15 * Curves.easeOutBack.transform(disc),
          child: Opacity(
            opacity: disc,
            child: Container(
              width: 118.w,
              height: 118.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: Size(54.w, 54.w),
                  painter: _CheckPainter(
                    progress: stroke,
                    color: AppColors.primaryColor,
                    strokeWidth: 6.w,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final Offset a = Offset(size.width * 0.16, size.height * 0.53);
    final Offset b = Offset(size.width * 0.42, size.height * 0.78);
    final Offset c = Offset(size.width * 0.86, size.height * 0.24);

    final double l1 = (b - a).distance;
    final double l2 = (c - b).distance;
    final double total = l1 + l2;
    final double drawn = total * progress;

    final Path path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= l1) {
      final Offset p = Offset.lerp(a, b, drawn / l1)!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final Offset p = Offset.lerp(b, c, (drawn - l1) / l2)!;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
