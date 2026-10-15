// 616 (FLO, 15/10/2026, demande Daniel du 10/10) — acceptation EXPLICITE du
// mandat de facturation au premier retrait.
//
// Les CGU (v2.4) contiennent le mandat par lequel HoPetSit (CARDELLI HERMANOS
// LIMITED) établit les documents de prestation AU NOM du prestataire. Pour
// qu'il tienne juridiquement, le prestataire coche une case la première fois
// qu'il retire : le bouton de retrait reste inactif tant qu'elle n'est pas
// cochée. Une fois le mandat enregistré côté serveur
// (`billingMandateAcceptedAt`), on n'affiche plus qu'un rappel
// « Mandat accepté le … » et le bouton est actif directement.
//
// Composants du kit (PawButton via ProfilePrimaryButton), zéro gris : la case
// est dessinée en orange #C92A12 plein, jamais un Material brut.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// Orange HoPetSit (préférence de Daniel) pour la case et l'icône du mandat.
const Color kBillingMandateOrange = Color(0xFFC92A12);

/// Case du mandat + bouton de confirmation du retrait.
///
/// * `acceptedAt == null` : case obligatoire ; `onConfirm` n'est branché que
///   quand elle est cochée (le bouton est inactif sinon).
/// * `acceptedAt != null` : rappel seul (« Mandat accepté le … »), bouton actif.
class BillingMandateWithdrawGate extends StatefulWidget {
  const BillingMandateWithdrawGate({
    super.key,
    required this.acceptedAt,
    required this.acceptedVersion,
    required this.currentVersion,
    required this.accent,
    required this.buttonLabel,
    required this.onConfirm,
    this.loading = false,
    this.buttonIcon,
  });

  /// Date d'acceptation enregistrée côté serveur (null = jamais accepté).
  final DateTime? acceptedAt;

  /// Version des CGU acceptée (affichée dans le rappel).
  final String acceptedVersion;

  /// Version courante des CGU (celle qu'on enregistre en cochant).
  final String currentVersion;
  final Color accent;
  final String buttonLabel;

  /// Appelé seulement quand le retrait est permis. `mandateJustChecked` vaut
  /// true quand la case vient d'être cochée (le serveur doit l'enregistrer
  /// avant le retrait).
  final Future<void> Function({required bool mandateJustChecked})? onConfirm;
  final bool loading;
  final Object? buttonIcon;

  @override
  State<BillingMandateWithdrawGate> createState() =>
      _BillingMandateWithdrawGateState();
}

class _BillingMandateWithdrawGateState
    extends State<BillingMandateWithdrawGate> {
  bool _checked = false;

  bool get _alreadyAccepted => widget.acceptedAt != null;
  bool get _canConfirm =>
      !widget.loading && widget.onConfirm != null && (_alreadyAccepted || _checked);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_alreadyAccepted) _reminder(context) else _checkbox(context),
        SizedBox(height: 16.h),
        ProfilePrimaryButton(
          label: widget.buttonLabel,
          accent: widget.accent,
          loading: widget.loading,
          icon: widget.buttonIcon,
          onTap: _canConfirm
              ? () => widget.onConfirm!(mandateJustChecked: !_alreadyAccepted)
              : null,
        ),
      ],
    );
  }

  /// « Mandat accepté le 15 oct. 2026 (CGU v2.4) » — rappel seul.
  Widget _reminder(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'fr';
    final when = widget.acceptedAt!.toLocal();
    String date;
    try {
      date = DateFormat.yMMMd(locale).format(when);
    } catch (_) {
      // Données de langue intl pas (encore) chargées : date chiffrée, jamais un plantage.
      date = DateFormat('dd/MM/yyyy').format(when);
    }
    return Row(
      key: const Key('billing_mandate_reminder'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_rounded, size: 18.sp, color: kBillingMandateOrange),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: 'wallet_mandate_accepted_on'.trParams({
              'date': date,
              'version': widget.acceptedVersion.isEmpty
                  ? widget.currentVersion
                  : widget.acceptedVersion,
            }),
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  /// Case obligatoire, dessinée à la main (orange plein, jamais de gris).
  Widget _checkbox(BuildContext context) {
    return Semantics(
      checked: _checked,
      label: 'wallet_mandate_checkbox'.tr,
      child: GestureDetector(
        key: const Key('billing_mandate_checkbox'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _checked = !_checked),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _checked
                ? kBillingMandateOrange.withValues(alpha: 0.08)
                : AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: _checked ? kBillingMandateOrange : AppColors.divider(context),
              width: _checked ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22.w,
                height: 22.w,
                margin: EdgeInsets.only(top: 1.h),
                decoration: BoxDecoration(
                  color: _checked ? kBillingMandateOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: kBillingMandateOrange, width: 2),
                ),
                child: _checked
                    ? Icon(Icons.check_rounded, size: 16.sp, color: Colors.white)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: InterText(
                  text: 'wallet_mandate_checkbox'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
