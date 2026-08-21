import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_text_field.dart';
import 'package:hopetsit/widgets/micro_anims.dart';
import 'package:hopetsit/views/auth/forgot_flow/forgot_password_email_screen.dart';
import 'package:hopetsit/views/auth/sign_up_as.dart';

/// v540 — écran de connexion « Bon retour ❤ » (maquette LAP écran 2a).
/// Reskin visuel UNIQUEMENT : toute la logique (formKey, contrôleurs email/
/// mot de passe, validateurs, handleLoginWithNavigation, spinners Google/
/// Apple indépendants, mot de passe oublié, langue, thème) est inchangée.
/// Nouveautés : carte « Reprendre » (dernier compte connecté, stocké par
/// AuthController dans 'last_login_hint' — jamais de mot de passe),
/// « Se souvenir de moi » (préremplit l'e-mail), sortie invité en bas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _storage = GetStorage();
  late final AuthController controller;

  Map<String, dynamic>? _hint; // {name, avatar, role, email}
  bool _remember = false;
  // v543 — Daniel : « Reprendre ne fait rien ». Le bouton préremplissait
  // l'e-mail (souvent déjà rempli → invisible). Maintenant il donne AUSSI le
  // focus au mot de passe : le clavier s'ouvre, l'action est visible.
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    controller = Get.find<AuthController>();

    final raw = _storage.read('last_login_hint');
    if (raw is Map && (raw['email'] ?? '').toString().isNotEmpty) {
      _hint = Map<String, dynamic>.from(raw);
    }
    final remembered = _storage.read('remembered_email');
    if (remembered is String && remembered.isNotEmpty) {
      _remember = true;
      if (controller.emailController.text.isEmpty) {
        controller.emailController.text = remembered;
      }
    }
  }

  @override
  void dispose() {
    _passwordFocus.dispose();
    super.dispose();
  }

  void _login() {
    // « Se souvenir de moi » : on ne stocke QUE l'e-mail, jamais le mot
    // de passe.
    if (_remember) {
      _storage.write(
        'remembered_email',
        controller.emailController.text.trim(),
      );
    } else {
      _storage.remove('remembered_email');
    }
    controller.handleLoginWithNavigation();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'pet_sitter':
        return 'role_pet_sitter'.tr;
      case 'pet_walker':
        return 'role_pet_walker'.tr;
      case 'pet_owner':
        return 'role_pet_owner'.tr;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const ink = Color(0xFF1B222E);
    final titleColor = isDark ? Colors.white : ink;
    final mutedColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B6259);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFFF9F4),
      body: Container(
        decoration: isDark
            ? null
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF9F4), Color(0xFFFFF3EA)],
                ),
              ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 8.h),

                  // ── Barre du haut : thème + langue (fonctions conservées) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _topIconButton(
                        context,
                        icon: isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: isDark ? Colors.amber : const Color(0xFF6B6259),
                        onTap: () => Get.changeThemeMode(
                          Get.isDarkMode ? ThemeMode.light : ThemeMode.dark,
                        ),
                      ),
                      _topIconButton(
                        context,
                        icon: Icons.language_rounded,
                        color: titleColor,
                        onTap: () => _showLanguageDialog(context),
                      ),
                    ],
                  ),

                  SizedBox(height: 10.h),

                  // ── Logo centré + titre Fredoka « Bon retour ❤ » ──
                  Container(
                    width: 76.w,
                    height: 76.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(color: const Color(0xFFECE5DE)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC92A12).withValues(alpha: 0.10),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(7.w),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15.r),
                      child: Image.asset(
                        'assets/brand/png/apple-icon-original.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FredokaText(
                          text: 'welcome_back'.tr,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      HeartBeat(
                        child: Text('❤',
                            style: TextStyle(
                                fontSize: 24.sp,
                                color: const Color(0xFFC92A12))),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  InterText(
                    text: 'login_subtitle'.tr,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),

                  SizedBox(height: 20.h),

                  // ── Carte « Reprendre » : dernier compte connecté ──
                  if (_hint != null) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: _ResumeCard(
                      hint: _hint!,
                      roleLabel:
                          _roleLabel((_hint!['role'] ?? '').toString()),
                      isDark: isDark,
                      onResume: () {
                        controller.emailController.text =
                            (_hint!['email'] ?? '').toString();
                        _passwordFocus.requestFocus();
                      },
                    ),
                    ),
                    SizedBox(height: 18.h),
                    _labelDivider(
                        context, 'login_or_email'.tr, isDark, mutedColor),
                    SizedBox(height: 18.h),
                  ],

                  // ── E-mail ──
                  CustomTextField(
                    labelText: 'label_email'.tr,
                    hintText: 'hint_email'.tr,
                    controller: controller.emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: controller.validateEmail,
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      size: 20.sp,
                      color: mutedColor,
                    ),
                    radius: 16.r,
                  ),
                  SizedBox(height: 14.h),

                  // ── Mot de passe ──
                  CustomTextField(
                    labelText: 'label_password'.tr,
                    hintText: 'hint_password_login'.tr,
                    focusNode: _passwordFocus,
                    controller: controller.passwordController,
                    obscureText: true,
                    showPasswordToggle: true,
                    textInputAction: TextInputAction.done,
                    validator: controller.validatePassword,
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      size: 20.sp,
                      color: mutedColor,
                    ),
                    radius: 16.r,
                  ),
                  SizedBox(height: 8.h),

                  // ── « Se souvenir de moi » + « Mot de passe oublié ? » ──
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _remember = !_remember),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22.w,
                              height: 22.w,
                              child: Checkbox(
                                value: _remember,
                                onChanged: (v) =>
                                    setState(() => _remember = v ?? false),
                                activeColor: const Color(0xFFC92A12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.dividerDark
                                      : const Color(0xFFD8CFC6),
                                  width: 1.6,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InterText(
                              text: 'login_remember'.tr,
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Get.to(
                          () => const ForgotPasswordEmailScreen(),
                          transition: Transition.rightToLeft,
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: InterText(
                          text: 'forgot_password'.tr,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFC92A12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Se connecter (dégradé marque) ──
                  Obx(
                    () => GestureDetector(
                      onTap: controller.isLoading.value ? null : _login,
                      child: Container(
                        width: double.infinity,
                        height: 52.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE25822), Color(0xFFC92A12)],
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC92A12)
                                  .withValues(alpha: 0.30),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: controller.isLoading.value
                              ? SizedBox(
                                  width: 22.sp,
                                  height: 22.sp,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : PoppinsText(
                                  text: 'title_login'.tr,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  _labelDivider(
                      context, 'or_continue_with'.tr, isDark, mutedColor),
                  SizedBox(height: 18.h),

                  // ── Google + Apple côte à côte ──
                  // v540 — Row enveloppée dans Obx : avant, les .value
                  // étaient lus HORS Obx → les spinners ne s'affichaient
                  // jamais et les boutons ne se désactivaient pas.
                  Obx(
                    () => Row(
                      children: [
                        Expanded(
                          child: _SocialLoginButton(
                            onTap: controller.isLoading.value ||
                                    controller.isGoogleLoginLoading.value ||
                                    controller.isAppleLoginLoading.value
                                ? null
                                : () => controller.loginWithGoogle(),
                            imagePath: AppImages.googleIcon,
                            label: 'button_google'.tr,
                            isDark: isDark,
                            isLoading:
                                controller.isGoogleLoginLoading.value,
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _SocialLoginButton(
                              onTap: controller.isLoading.value ||
                                      controller.isGoogleLoginLoading.value ||
                                      controller.isAppleLoginLoading.value
                                  ? null
                                  : () => controller.loginWithApple(),
                              icon: Icons.apple,
                              label: 'button_apple'.tr,
                              isDark: isDark,
                              isLoading:
                                  controller.isAppleLoginLoading.value,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 18.h),

                  // ── Mode invité (carte pointillée rose de la maquette) ──
                  GestureDetector(
                    onTap: () =>
                        Get.offAll(() => const GuestLandingScreen()),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFF472B6)
                              .withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🐭', style: TextStyle(fontSize: 15.sp)),
                          SizedBox(width: 8.w),
                          PoppinsText(
                            text: 'guest_continue_without'.tr,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFF472B6)
                                : const Color(0xFF9D6B85),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // ── « Nouveau ? Créer un compte » ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InterText(
                        text: 'login_new'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: mutedColor,
                      ),
                      SizedBox(width: 6.w),
                      GestureDetector(
                        onTap: () => Get.to(() => const SignUpAsScreen()),
                        behavior: HitTestBehavior.opaque,
                        child: PoppinsText(
                          text: 'login_create'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC92A12),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topIconButton(BuildContext context,
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? AppColors.dividerDark : const Color(0xFFECE5DE),
          ),
        ),
        child: Icon(icon, size: 21.sp, color: color),
      ),
    );
  }

  Widget _labelDivider(
      BuildContext context, String label, bool isDark, Color mutedColor) {
    final line = isDark ? AppColors.dividerDark : const Color(0xFFE8DFD6);
    return Row(
      children: [
        Expanded(child: Divider(color: line, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: InterText(
            text: label,
            fontSize: 12.sp,
            color: mutedColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(child: Divider(color: line, thickness: 1)),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Track the selected language inside the dialog so the check mark moves
    // when the user taps. Without StatefulBuilder, the check stayed frozen
    // on whatever language was active at open-time.
    String selectedCode = LocalizationService.getCurrentLanguageCode();
    final entries = LocalizationService.languageLabels.entries.toList();

    Get.defaultDialog(
      title: 'language_dialog_title'.tr,
      titleStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textPrimaryDark : AppColors.blackColor,
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.whiteColor,
      content: StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: entries.map((entry) {
              final isSelected = entry.key == selectedCode;
              return ListTile(
                title: InterText(
                  text:
                      '${LocalizationService.languageFlags[entry.key] ?? ''} ${entry.value}'
                          .trim(),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color:
                      isDark ? AppColors.textPrimaryDark : AppColors.blackColor,
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppColors.primaryColor)
                    : null,
                onTap: () async {
                  setDialogState(() {
                    selectedCode = entry.key;
                  });
                  await LocalizationService.updateLocale(entry.key);
                  // Brief pause so the visual confirmation registers.
                  await Future.delayed(const Duration(milliseconds: 250));
                  Get.back();
                  CustomSnackbar.showSuccess(
                    title: 'language_updated_title'.tr,
                    message: 'language_updated_message'.tr,
                  );
                },
              );
            }).toList(),
          );
        },
      ),
      textCancel: 'common_cancel'.tr,
      cancelTextColor: AppColors.primaryColor,
    );
  }
}

/// Carte « Reprendre » de la maquette : avatar + nom + rôle de la dernière
/// session, bouton qui préremplit l'e-mail. Aucune donnée sensible stockée.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.hint,
    required this.roleLabel,
    required this.isDark,
    required this.onResume,
  });

  final Map<String, dynamic> hint;
  final String roleLabel;
  final bool isDark;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final name = (hint['name'] ?? '').toString();
    final avatar = (hint['avatar'] ?? '').toString();
    final sub = roleLabel.isEmpty
        ? 'login_last_session'.tr
        : '$roleLabel · ${'login_last_session'.tr}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : const Color(0xFFECE5DE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE25822).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatar.isNotEmpty
                  ? Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackAvatar(),
                    )
                  : _fallbackAvatar(),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: name.isEmpty
                      ? (hint['email'] ?? '').toString()
                      : name,
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1B222E),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: sub,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF6B6259),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          SoftPulse(
            child: GestureDetector(
            onTap: onResume,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE25822), Color(0xFFC92A12)],
                ),
                borderRadius: BorderRadius.circular(99.r),
              ),
              child: PoppinsText(
                text: 'login_resume'.tr,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() => Container(
        color: const Color(0xFFFFF3EA),
        child: Center(
          child: Text('🐾', style: TextStyle(fontSize: 18.sp)),
        ),
      );
}

/// Modern social login button with icon + label (Google/Apple).
/// Google: white background with subtle grey border.
/// Apple: black background with white text.
class _SocialLoginButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String? imagePath;
  final IconData? icon;
  final String label;
  final bool isDark;
  // v23.1 part 200 — spinner par-bouton (Google ou Apple indépendant)
  final bool isLoading;

  const _SocialLoginButton({
    this.onTap,
    this.imagePath,
    this.icon,
    required this.label,
    required this.isDark,
    this.isLoading = false,
  });

  bool get _isApple => icon == Icons.apple;

  @override
  Widget build(BuildContext context) {
    final isAppleButton = _isApple;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: isAppleButton
              ? const Color(0xFF101319)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(16.r),
          border: isAppleButton
              ? null
              : Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : const Color(0xFFECE5DE),
                  width: 1.4,
                ),
          boxShadow: isAppleButton
              ? null
              : [
                  BoxShadow(
                    color: AppColors.blackColor.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              // v23.1 part 200 — spinner inline (remplace icon+label) sur
              // CE bouton uniquement quand son provider est en cours
              ? SizedBox(
                  width: 20.sp,
                  height: 20.sp,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isAppleButton ? Colors.white : AppColors.primaryColor,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (imagePath != null)
                      Image.asset(
                        imagePath!,
                        height: 20.sp,
                        width: 20.sp,
                        fit: BoxFit.cover,
                      )
                    else if (icon != null)
                      Icon(
                        icon,
                        size: 20.sp,
                        color: isAppleButton
                            ? Colors.white
                            : AppColors.textPrimary(context),
                      ),
                    SizedBox(width: 8.w),
                    InterText(
                      text: label,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isAppleButton
                          ? Colors.white
                          : AppColors.textPrimary(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
