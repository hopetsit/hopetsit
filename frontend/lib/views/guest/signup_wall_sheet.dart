import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'dart:io' show Platform;

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// v535 — SPEC ONBOARDING P1.2 : le MUR D'INSCRIPTION CONTEXTUEL.
///
/// Avant, le mur était à l'OUVERTURE de l'app (0 contenu sans compte,
/// ~2 % d'inscriptions). Désormais l'app s'explore librement, et cette
/// feuille n'apparaît qu'au moment où l'invité veut AGIR — contacter,
/// réserver, publier, taguer un spot. À cet instant l'intention est déjà
/// là : c'est le moment où la conversion est la plus forte.
///
/// [trigger] alimente l'événement `signup_wall_shown` (P3) :
/// 'contact' | 'booking' | 'publish' | 'spot' | 'profile'.
/// [name] personnalise le titre (« Crée ton compte pour contacter Marie »).
class SignupWallSheet extends StatelessWidget {
  final String trigger;
  final String? name;

  /// v565 (Daniel 18/09) — le mur propose les 3 rôles ; [recommendedRole]
  /// ('pet_owner' | 'pet_sitter' | 'pet_walker') est mis en avant en premier.
  /// Sans valeur : déduit du contexte d'appel — depuis une fiche de
  /// prestataire, la liste ou un CTA générique → « Propriétaire » ; depuis
  /// une annonce / demande de propriétaire → « Pet-sitter ».
  final String? recommendedRole;
  const SignupWallSheet({
    super.key,
    required this.trigger,
    this.name,
    this.recommendedRole,
  });

  static Future<void> show({
    required String trigger,
    String? name,
    String? recommendedRole,
  }) {
    FirebaseAnalyticsService.instance
        .logFunnel('signup_wall_shown', params: {'trigger': trigger});
    return Get.bottomSheet(
      SignupWallSheet(
        trigger: trigger,
        name: name,
        recommendedRole: recommendedRole,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  String get _recommended {
    final r = recommendedRole;
    if (r == 'pet_owner' || r == 'pet_sitter' || r == 'pet_walker') return r!;
    switch (trigger) {
      case 'post':
      case 'request':
      case 'publish':
      case 'apply':
        return 'pet_sitter';
      default:
        return 'pet_owner';
    }
  }

  void _toWizard(String userType) {
    FirebaseAnalyticsService.instance.logFunnel('signup_start',
        params: {'trigger': trigger, 'role': userType});
    Get.back();
    Get.to(() => SignupWizardScreen(userType: userType));
  }

  void _social(String provider) {
    if (!Get.isRegistered<AuthController>()) return;
    Get.back();
    final auth = Get.find<AuthController>();
    if (provider == 'apple') {
      auth.loginWithApple();
    } else {
      auth.loginWithGoogle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (name != null && name!.isNotEmpty)
        ? 'guest_wall_title_named'.trParams({'name': name!})
        : 'guest_wall_title'.tr;
    // v573 — harmonisation avec le design 567-571 : plus de `Colors.grey` ni
    // de ternaire `isDark` écrit à la main, poignée et coins alignés sur les
    // autres feuilles, boutons sociaux au langage `CustomButton`.
    final Color muted = AppColors.textSecondary(context);

    final roles = <_WallRole>[
      _WallRole(
        userType: 'pet_owner',
        titleKey: 'role_pet_owner',
        subtitleKey: 'guest_role_owner_sub',
        emoji: '🐾',
        color: AppColors.primaryColor,
      ),
      _WallRole(
        userType: 'pet_sitter',
        titleKey: 'role_pet_sitter',
        subtitleKey: 'guest_role_sitter_sub',
        emoji: '🏠',
        color: AppColors.sitterAccent,
      ),
      _WallRole(
        userType: 'pet_walker',
        titleKey: 'role_pet_walker',
        subtitleKey: 'guest_role_walker_sub',
        emoji: '🐕‍🦺',
        color: AppColors.greenColor,
      ),
    ];
    final recommended = _recommended;
    roles.sort((a, b) => a.userType == recommended
        ? -1
        : b.userType == recommended
            ? 1
            : 0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      // v569 — `Get.bottomSheet` ne protège pas le bas : sur le Samsung de
      // Daniel le SafeArea n'applique rien, les 3 tuiles de rôle et le bouton
      // finissaient sous la barre système.
      padding: EdgeInsets.fromLTRB(
          20.w, 14.h, 20.w, 20.h + appBottomInsetInsideSafeArea(context)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Center(
                child: Image.asset(
                  'assets/brand/png/logo-mark.png',
                  width: 52.w,
                  height: 52.w,
                ),
              ),
              SizedBox(height: 12.h),
              PoppinsText(
                text: title,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
              SizedBox(height: 6.h),
              InterText(
                text: 'guest_wall_subtitle'.tr,
                fontSize: 13.sp,
                color: muted,
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
              SizedBox(height: 16.h),
              InterText(
                text: 'guest_wall_choose_role'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: muted,
                maxLines: 2,
              ),
              SizedBox(height: 8.h),
              for (final r in roles) ...[
                _RoleCard(
                  role: r,
                  recommended: r.userType == recommended,
                  onTap: () => _toWizard(r.userType),
                ),
                SizedBox(height: 8.h),
              ],
              SizedBox(height: 6.h),
              Row(
                children: [
                  Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: InterText(
                      text: 'guest_wall_or_social'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  Expanded(child: Divider(color: muted.withValues(alpha: 0.35))),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  if (Platform.isIOS) ...[
                    Expanded(
                      child: _SocialBtn(
                        label: 'button_apple'.tr,
                        icon: Icons.apple,
                        bg: const Color(0xFF101319),
                        fg: Colors.white,
                        onTap: () => _social('apple'),
                      ),
                    ),
                    SizedBox(width: 10.w),
                  ],
                  Expanded(
                    child: _SocialBtn(
                      label: 'button_google'.tr,
                      icon: Icons.g_mobiledata,
                      bg: AppColors.card(context),
                      fg: AppColors.textPrimary(context),
                      border: true,
                      onTap: () => _social('google'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              CustomButton(
                bgColor: Colors.transparent,
                borderColor:
                    AppColors.accentOn(context, AppColors.primaryColor),
                textColor:
                    AppColors.accentOn(context, AppColors.primaryColor),
                title: 'guest_wall_login'.tr,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                radius: 16.r,
                height: 46.h,
                onTap: () {
                  Get.back();
                  Get.to(() => const LoginScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WallRole {
  final String userType;
  final String titleKey;
  final String subtitleKey;
  final String emoji;
  final Color color;
  const _WallRole({
    required this.userType,
    required this.titleKey,
    required this.subtitleKey,
    required this.emoji,
    required this.color,
  });
}

class _RoleCard extends StatelessWidget {
  final _WallRole role;
  final bool recommended;
  final VoidCallback onTap;
  const _RoleCard({
    required this.role,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = AppColors.accentOn(context, role.color);
    final BorderRadius br = BorderRadius.circular(18.r);
    return Material(
      color: recommended
          ? c.withValues(alpha: 0.10)
          : AppColors.card(context),
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(
              color: recommended
                  ? c
                  : AppColors.divider(context).withValues(alpha: 0.8),
              width: recommended ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(role.emoji, style: TextStyle(fontSize: 20.sp)),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: PoppinsText(
                            text: role.titleKey.tr,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w800,
                            color: c,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (recommended) ...[
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: role.color,
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: InterText(
                                text: 'guest_wall_recommended'.tr,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: role.subtitleKey.tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right_rounded, color: c, size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final bool border;
  final VoidCallback onTap;
  const _SocialBtn({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    this.border = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(14.r);
    return Material(
      color: bg,
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: br,
        onTap: onTap,
        child: Container(
          height: 46.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            borderRadius: br,
            border: border
                ? Border.all(color: AppColors.divider(context), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18.sp, color: fg),
              SizedBox(width: 7.w),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: InterText(
                    text: label,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
