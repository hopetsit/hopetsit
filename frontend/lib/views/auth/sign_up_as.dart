import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Sign-up role selector.
///
/// Displays the 3 available roles — Pet Owner, Pet Sitter, Pet Walker — as
/// distinct cards with their own color tone:
///   • Owner  → primary (warm orange)
///   • Sitter → blue (`sitterAccent`)
///   • Walker → green (`greenColor`)
///
/// Each card's illustration is tinted with the role accent so the 3 cards
/// feel visually distinct even if they share base illustrations.
class SignUpAsScreen extends StatelessWidget {
  const SignUpAsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                BackButton(
                  color: AppColors.textPrimary(context),
                  // v502 — arrivée via Get.offAll (nouvel utilisateur
                  // Apple/Google) = pile vide → le retour par défaut ne faisait
                  // rien. On revient si possible, sinon on ouvre la connexion.
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      // v537 — Daniel : « je suis bloqué sur cette page ».
                      // Pile vide → on revient à la DÉCOUVERTE invité (avant :
                      // LoginScreen, qui repartait ici = ping-pong sans sortie).
                      Get.offAll(() => const GuestLandingScreen());
                    }
                  },
                ),
                SizedBox(height: 16.h),
                // v23.1 part 138 — badge "Inscription" pour matcher le
                // badge "Connexion" du LoginScreen et bien distinguer
                // les 2 flows.
                Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: PoppinsText(
                      text: 'sign_up'.tr.toUpperCase(),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: PoppinsText(
                    text: 'sign_up_as_subtitle'.tr,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 8.h),
                Center(
                  child: InterText(
                    text: 'signup_as_subtitle'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 28.h),
                _RoleCard(
                  image: AppImages.petOwner,
                  titleKey: 'role_pet_owner',
                  subtitleKey: 'role_pet_owner_desc',
                  iconEmoji: '🏠',
                  accentColor: AppColors.primaryColor,
                  onTap: () => Get.to(() => SignupWizardScreen(userType: 'pet_owner')),
                ),
                SizedBox(height: 16.h),
                _RoleCard(
                  image: AppImages.petSitter,
                  titleKey: 'role_pet_sitter',
                  subtitleKey: 'role_pet_sitter_desc',
                  iconEmoji: '🛏️',
                  accentColor: AppColors.sitterAccent,
                  onTap: () => Get.to(() => SignupWizardScreen(userType: 'pet_sitter')),
                ),
                SizedBox(height: 16.h),
                _RoleCard(
                  image: AppImages.petWalker,
                  titleKey: 'role_pet_walker',
                  subtitleKey: 'role_pet_walker_desc',
                  iconEmoji: '🐕‍🦺',
                  accentColor: AppColors.greenColor,
                  onTap: () => Get.to(() => SignupWizardScreen(userType: 'pet_walker')),
                ),
                SizedBox(height: 24.h),
                // v23.1 part 138 — lien vers login si l'utilisateur arrive
                // ici par erreur (avait déjà un compte).
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InterText(
                        text: 'guest_already'.tr,
                        fontSize: 13.sp,
                        color: AppColors.textSecondary(context),
                      ),
                      SizedBox(width: 6.w),
                      GestureDetector(
                        // v502 — "Se connecter" : on arrive souvent ici via
                        // Get.offAll (ex : nouvel utilisateur Apple/Google) donc
                        // la pile de navigation est VIDE → Get.back() ne faisait
                        // rien (bouton mort). On ouvre explicitement l'écran de
                        // connexion.
                        onTap: () => Get.offAll(() => const LoginScreen()),
                        behavior: HitTestBehavior.opaque,
                        child: PoppinsText(
                          text: 'title_login'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                // v537 — Daniel : « je ne vois plus le mode invité ». Une
                // sortie claire vers la découverte sans compte.
                Center(
                  child: GestureDetector(
                    onTap: () => Get.offAll(() => const GuestLandingScreen()),
                    behavior: HitTestBehavior.opaque,
                    child: InterText(
                      text: 'guest_continue_without'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single role card — image with a tonal wash in the role accent color,
/// large emoji badge, and a 2-line subtitle describing the service.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.image,
    required this.titleKey,
    required this.subtitleKey,
    required this.iconEmoji,
    required this.accentColor,
    required this.onTap,
  });

  final String image;
  final String titleKey;
  final String subtitleKey;
  final String iconEmoji;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tinted image tile with emoji badge overlay
            Stack(
              children: [
                Container(
                  width: 96.w,
                  height: 96.h,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Base illustration
                        Image.asset(image, fit: BoxFit.cover),
                        // Tonal wash in the role accent
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withValues(alpha: 0.25),
                                accentColor.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Emoji badge bottom-right
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(iconEmoji, style: TextStyle(fontSize: 13.sp)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PoppinsText(
                    text: titleKey.tr,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  SizedBox(height: 6.h),
                  InterText(
                    text: subtitleKey.tr,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary(context),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18.sp,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
