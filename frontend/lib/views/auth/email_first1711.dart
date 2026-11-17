// 1711 (NEO, ordre de Daniel du 17/11/2026) — inscription « e-mail d'abord » :
// les deux étapes posées DEVANT l'assistant (« Ton e-mail », « Code reçu par
// e-mail ») et la tuile « e-mail confirmé » de la 1re étape de l'assistant.
// État et appels serveur : `controllers/email_first1711.dart`.
//
// Règles GetX du projet : chaque Obx lit ses `.value` directement (jamais
// `Obx(() => Builder(...))`), aucun `CrossAxisAlignment.stretch`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:hopetsit/controllers/email_first1711.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';

/// 643 (ZOE, contrôle du 17/11) — ouvre l'écran de connexion SANS jamais en
/// monter deux à la fois. `LoginScreen` partage la clé de formulaire de
/// `AuthController` : un `Get.offAll(LoginScreen)` lancé alors qu'un écran de
/// connexion est déjà dans la pile (Connexion → Créer un compte → … → « Se
/// connecter ») en montait un second pendant la transition → « Duplicate
/// GlobalKey », champ mot de passe mort (vu au simulateur). S'il y en a déjà
/// un dans la pile, on y REVIENT ; sinon on l'ouvre comme avant.
void openLoginScreen1711() {
  bool found = false;
  Get.until((route) {
    if (route.settings.name == '/LoginScreen') found = true;
    return found || route.isFirst;
  });
  if (!found) Get.offAll(() => const LoginScreen());
}

const Color _kOk = Color(0xFF16A34A);
const Color _kErr = Color(0xFFDC2626);

OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: c, width: w),
    );

/// Étape « Ton e-mail ».
class EmailFirstEmailStep extends StatelessWidget {
  const EmailFirstEmailStep({
    super.key,
    required this.ef,
    required this.accent,
    required this.onLogin,
  });

  final EmailFirst1711 ef;
  final Color accent;

  /// « Se connecter » (un compte existe déjà pour cette adresse).
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.textPrimary(context);
    final secondary = AppColors.textSecondary(context);
    return Column(
      key: const Key('ef_email_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'ef_email_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        SizedBox(height: 6.h),
        InterText(
          text: 'ef_email_sub'.tr,
          fontSize: 13.sp,
          color: secondary,
        ),
        SizedBox(height: 16.h),
        TextField(
          key: const Key('ef_email_field'),
          controller: ef.emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) => ef.onEmailEdited(),
          onSubmitted: (_) => ef.submitEmail(),
          decoration: InputDecoration(
            labelText: 'signup_field_email'.tr,
            hintText: 'ef_email_hint'.tr,
            isDense: true,
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20.sp),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            enabledBorder:
                _border(AppColors.greyColor.withValues(alpha: 0.4), 1),
            border: _border(AppColors.greyColor.withValues(alpha: 0.4), 1),
            focusedBorder: _border(accent, 1.8),
          ),
        ),
        Obx(() {
          final err = ef.error.value;
          final sug = ef.suggestion.value;
          final exists = ef.exists.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (err.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: InterText(
                    key: const Key('ef_error'),
                    text: err,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: _kErr,
                  ),
                ),
              if (sug.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Material(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14.r),
                    child: InkWell(
                      key: const Key('ef_suggestion'),
                      borderRadius: BorderRadius.circular(14.r),
                      onTap: ef.applySuggestion,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_fix_high_rounded,
                                size: 18.sp, color: accent),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InterText(
                                    text: 'ef_suggest_q'.tr,
                                    fontSize: 12.sp,
                                    color: secondary,
                                  ),
                                  SizedBox(height: 2.h),
                                  InterText(
                                    text: sug,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                  SizedBox(height: 2.h),
                                  InterText(
                                    text: 'ef_suggest_use'.tr,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (exists)
                Padding(
                  padding: EdgeInsets.only(top: 12.h),
                  child: Container(
                    key: const Key('ef_exists'),
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'ef_exists_title'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: 'ef_exists_sub'.tr,
                          fontSize: 12.sp,
                          color: secondary,
                        ),
                        SizedBox(height: 8.h),
                        PawButton(
                          key: const Key('ef_login'),
                          label: 'ef_exists_login'.tr,
                          kind: PawButtonKind.secondary,
                          color: accent,
                          compact: true,
                          onTap: onLogin,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
        SizedBox(height: 18.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, size: 15.sp, color: secondary),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: 'ef_email_note'.tr,
                fontSize: 12.sp,
                color: secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Étape « Code reçu par e-mail ».
class EmailFirstCodeStep extends StatelessWidget {
  const EmailFirstCodeStep({super.key, required this.ef, required this.accent});

  final EmailFirst1711 ef;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.textPrimary(context);
    final secondary = AppColors.textSecondary(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pin = PinTheme(
      width: 46.w,
      height: 54.h,
      textStyle: TextStyle(
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.greyColor.withValues(alpha: 0.45)),
      ),
    );
    return Column(
      key: const Key('ef_code_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: 'ef_code_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        SizedBox(height: 6.h),
        InterText(
          text: 'ef_code_sub'.tr,
          fontSize: 13.sp,
          color: secondary,
        ),
        SizedBox(height: 4.h),
        // Adresse puis « Changer d'adresse » sur deux lignes : une adresse
        // longue ou un libellé long (es, de…) ne déborde jamais à 320 px.
        Obx(() => InterText(
              key: const Key('ef_code_email'),
              text: ef.pendingEmail.value,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: primary,
              maxLines: 2,
            )),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: PawButton(
            key: const Key('ef_change'),
            label: 'ef_code_change'.tr,
            kind: PawButtonKind.link,
            color: accent,
            compact: true,
            expand: false,
            onTap: ef.changeEmail,
          ),
        ),
        SizedBox(height: 10.h),
        Center(
          child: Pinput(
            key: const Key('ef_pin'),
            length: EmailFirst1711.codeLength,
            controller: ef.codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            // Collage accepté : « 123 456 » ou « 123-456 » → 123456.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: pin,
            focusedPinTheme: pin.copyWith(
              decoration: pin.decoration!
                  .copyWith(border: Border.all(color: accent, width: 1.8)),
            ),
            submittedPinTheme: pin.copyWith(
              decoration: pin.decoration!.copyWith(
                border: Border.all(color: accent),
                color: accent.withValues(alpha: 0.06),
              ),
            ),
            onChanged: ef.onCodeEdited,
            onCompleted: (v) => ef.submitCode(v),
          ),
        ),
        Obx(() {
          final err = ef.error.value;
          final info = ef.info.value;
          if (err.isEmpty && info.isEmpty) return SizedBox(height: 10.h);
          return Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 2.h),
            child: Center(
              child: InterText(
                key: Key(err.isNotEmpty ? 'ef_error' : 'ef_info'),
                text: err.isNotEmpty ? err : info,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: err.isNotEmpty ? _kErr : _kOk,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }),
        SizedBox(height: 6.h),
        Center(
          child: PawButton(
            key: const Key('ef_paste'),
            label: 'ef_code_paste'.tr,
            icon: Icons.content_paste_rounded,
            kind: PawButtonKind.link,
            color: accent,
            compact: true,
            expand: false,
            onTap: ef.pasteFromClipboard,
          ),
        ),
        Center(
          child: Obx(() {
            final left = ef.resendIn.value;
            if (left > 0) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: InterText(
                  key: const Key('ef_resend_wait'),
                  text: 'ef_code_resend_in'
                      .tr
                      .replaceAll('{s}', left.toString()),
                  fontSize: 13.sp,
                  color: secondary,
                ),
              );
            }
            return PawButton(
              key: const Key('ef_resend'),
              label: 'ef_code_resend'.tr,
              kind: PawButtonKind.link,
              color: accent,
              compact: true,
              expand: false,
              onTap: ef.resend,
            );
          }),
        ),
        SizedBox(height: 10.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 15.sp, color: secondary),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: 'ef_code_spam'.tr,
                fontSize: 12.sp,
                color: secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tuile « e-mail confirmé » (1re étape de l'assistant) : l'adresse validée
/// par le code, affichée et non modifiable.
class EmailFirstConfirmedTile extends StatelessWidget {
  const EmailFirstConfirmedTile({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Container(
        key: const Key('ef_confirmed'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: _kOk.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: _kOk.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Icons.mark_email_read_rounded, size: 20.sp, color: _kOk),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: email,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    maxLines: 1,
                  ),
                  SizedBox(height: 1.h),
                  InterText(
                    text: 'ef_confirmed'.tr,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: _kOk,
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded,
                size: 16.sp, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}
