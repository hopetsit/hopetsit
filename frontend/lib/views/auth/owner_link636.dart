import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// 636 — connexion SANS mot de passe pour les propriétaires créés par le site
/// (pub Meta : compte « lead »). Encart sur l'écran de connexion → feuille
/// avec l'e-mail → `POST /auth/owner-link { email, next, lang }` (route LEO du
/// 06/11 : 200 neutre que le compte existe ou non ; `next` = la route
/// mémorisée par le lien reçu sans session, sinon /posts).
const Color _orange = Color(0xFFC92A12);

/// Réponse attendue par l'utilisateur selon la réponse du serveur. Pure.
///   null statusCode / 2xx → `ownerlink636_sent` (neutre)
///   400 → `ownerlink636_email_invalid` ; 429 → `ownerlink636_too_many` ;
///   autre → `common_error_message`.
String ownerLinkMessageKey636(int? statusCode) {
  if (statusCode == null || (statusCode >= 200 && statusCode < 300)) {
    return 'ownerlink636_sent';
  }
  if (statusCode == 400) return 'ownerlink636_email_invalid';
  if (statusCode == 429) return 'ownerlink636_too_many';
  return 'common_error_message';
}

/// Forme minimale d'un e-mail (même règle que le serveur). Pure.
bool ownerLinkEmailLooksValid636(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

/// Encart « Pas de mot de passe ? Reçois ton lien par e-mail » (écran de
/// connexion). [emailOf] lit l'e-mail déjà saisi pour pré-remplir la feuille.
class OwnerLinkCard636 extends StatelessWidget {
  const OwnerLinkCard636({super.key, required this.emailOf, this.muted});
  final String Function() emailOf;
  final Color? muted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('ownerlink636_card'),
        behavior: HitTestBehavior.opaque,
        onTap: () => OwnerLinkSheet636.show(context, email: emailOf()),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _orange.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                color: _orange,
                size: 20.sp,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: InterText(
                  text: 'ownerlink636_title'.tr,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _orange,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _orange, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feuille : e-mail + bouton « Recevoir mon lien ».
class OwnerLinkSheet636 extends StatefulWidget {
  const OwnerLinkSheet636({super.key, this.email = ''});
  final String email;

  static Future<void> show(BuildContext context, {String email = ''}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => OwnerLinkSheet636(email: email),
    );
  }

  @override
  State<OwnerLinkSheet636> createState() => _OwnerLinkSheet636State();
}

class _OwnerLinkSheet636State extends State<OwnerLinkSheet636> {
  late final TextEditingController _email = TextEditingController(
    text: widget.email.trim(),
  );
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!ownerLinkEmailLooksValid636(email)) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'ownerlink636_email_invalid'.tr,
      );
      return;
    }
    setState(() => _sending = true);
    int? status;
    try {
      if (!Get.isRegistered<ApiClient>()) throw StateError('ApiClient absent');
      await Get.find<ApiClient>().post(
        '/auth/owner-link',
        body: <String, dynamic>{
          'email': email,
          'next': DeepLinkService.pendingRouteForOwnerLink636(),
          'lang': Get.locale?.languageCode ?? 'en',
        },
      );
    } on ApiException catch (e) {
      status = e.statusCode ?? 500;
      AppLogger.logWarning('owner-link refusé (${e.statusCode})');
    } catch (e) {
      status = 500;
      AppLogger.logWarning('owner-link échec : $e');
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final key = ownerLinkMessageKey636(status);
    if (key == 'ownerlink636_sent') {
      Navigator.of(context).maybePop();
      CustomSnackbar.showSuccess(title: 'common_success'.tr, message: key.tr);
    } else {
      CustomSnackbar.showError(title: 'common_error'.tr, message: key.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PoppinsText(
            text: 'ownerlink636_title'.tr,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: _orange,
          ),
          SizedBox(height: 8.h),
          InterText(
            text: 'ownerlink636_body'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          SizedBox(height: 14.h),
          TextField(
            key: const Key('ownerlink636_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sending ? null : _send(),
            decoration: InputDecoration(
              hintText: 'ownerlink636_email_hint'.tr,
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),
          // Bouton du kit (garde-fou lotd_raw_buttons_guard : jamais de
          // bouton Material brut) ; `loading` affiche la roue et bloque le tap.
          PawButton(
            key: const Key('ownerlink636_send'),
            label: 'ownerlink636_send'.tr,
            color: _orange,
            height: 52.h,
            loading: _sending,
            onTap: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
