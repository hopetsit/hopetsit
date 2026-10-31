// PAM-B 31/10/2026 (point BOB, build 631) — les bandeaux de l'accueil ne
// disparaissent plus sur un toucher malheureux : la croix « fermer » et le ✗
// « refuser » passent par une confirmation. Deux fonctions pures, testables,
// branchées dans `home_quick_action_bar.dart`.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';

/// « Fermer ce bandeau ? » → true seulement si l'utilisateur confirme.
Future<bool> confirmBannerClose3110(BuildContext context) async {
  final bool? ok = await showAppConfirmDialog(
    context,
    title: 'pamb3110_dismiss_title'.tr,
    message: 'pamb3110_dismiss_body'.tr,
    confirmLabel: 'common_close'.tr,
    cancelLabel: 'common_cancel'.tr,
    icon: Icons.close_rounded,
  );
  return ok == true;
}

/// « Refuser cette demande ? » → true seulement si l'utilisateur confirme.
Future<bool> confirmBannerRefuse3110(BuildContext context) async {
  final bool? ok = await showAppConfirmDialog(
    context,
    title: 'pamb3110_refuse_title'.tr,
    message: 'pamb3110_refuse_body'.tr,
    confirmLabel: 'pawfollow_refuse'.tr,
    cancelLabel: 'common_cancel'.tr,
    destructive: true,
    icon: Icons.close_rounded,
  );
  return ok == true;
}
