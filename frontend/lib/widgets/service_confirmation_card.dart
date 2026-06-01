import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v23.1.259 — Carte de confirmation de service (Daniel).
///
/// Affiche, sur l'écran détail réservation, l'état du flux de confirmation et
/// le bon bouton selon le rôle :
///   PROVIDER (sitter/walker) :
///     awaiting_start/none  → "J'ai récupéré l'animal"   (onStart)
///     in_progress          → "J'ai rendu l'animal"       (onComplete)
///     awaiting_confirmation→ "En attente de l'owner"     (info)
///     confirmed            → "Confirmé — paiement libéré"
///     disputed             → "Problème signalé"
///   OWNER :
///     awaiting_start/none  → "Pas encore démarré"
///     in_progress          → "Service en cours"
///     awaiting_confirmation→ carte CONFIRMER / SIGNALER UN PROBLÈME
///     confirmed            → "Confirmé"
///     disputed             → "Litige en cours"
///
/// Ne s'affiche que pour les réservations PAYÉES (le flux ne concerne que
/// l'argent en séquestre). v23.1.262 — pour `confirmationStatus == 'none'`
/// (bookings LEGACY payés avant la feature, souvent déjà terminés) on MASQUE
/// entièrement la carte : sinon les anciennes réservations affichaient
/// « Service pas encore démarré » alors qu'elles sont finies (Daniel). Les
/// réservations passées par le nouveau flux reçoivent `awaiting_start` côté
/// backend dès le paiement → la carte s'affiche normalement.
class ServiceConfirmationCard extends StatelessWidget {
  const ServiceConfirmationCard({
    super.key,
    required this.confirmationStatus,
    required this.role,
    required this.isPaid,
    this.busy = false,
    this.onStart,
    this.onComplete,
    this.onConfirm,
    this.onDispute,
  });

  final String confirmationStatus;
  final String role; // 'owner' | 'sitter' | 'walker'
  final bool isPaid;
  final bool busy;
  final Future<void> Function()? onStart;
  final Future<void> Function()? onComplete;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onDispute;

  bool get _isProvider => role == 'sitter' || role == 'walker';
  String get _status =>
      confirmationStatus.isEmpty ? 'none' : confirmationStatus;

  @override
  Widget build(BuildContext context) {
    if (!isPaid) return const SizedBox.shrink();
    final st = _status;
    // v23.1.262 — bookings legacy (payés avant la feature) : confirmationStatus
    // reste 'none' et n'entrera jamais dans le flux → on masque la carte pour
    // ne pas afficher « Service pas encore démarré » sur des services finis.
    if (st == 'none') return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  color: AppColors.primaryColor, size: 18.sp),
              SizedBox(width: 8.w),
              InterText(
                text: 'service_card_header'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ..._buildBody(context, st),
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context, String st) {
    // États finaux / informatifs communs.
    if (st == 'confirmed') {
      return [_infoLine(context, '✅ ${'service_card_confirmed'.tr}', green: true)];
    }
    if (st == 'disputed') {
      return [
        _infoLine(
          context,
          '⚠️ ${(_isProvider ? 'service_card_disputed_provider' : 'service_card_disputed_owner').tr}',
          warn: true,
        ),
      ];
    }

    if (_isProvider) {
      if (st == 'in_progress') {
        return [
          _infoLine(context, 'service_card_in_progress'.tr),
          SizedBox(height: 10.h),
          _actionButton(
            label: 'service_card_provider_complete_btn'.tr,
            onTap: onComplete,
            color: const Color(0xFF16A34A),
          ),
        ];
      }
      if (st == 'awaiting_confirmation') {
        return [_infoLine(context, 'service_card_awaiting_owner'.tr)];
      }
      // awaiting_start / none → démarrer
      return [
        _actionButton(
          label: 'service_card_provider_start_btn'.tr,
          onTap: onStart,
          color: AppColors.primaryColor,
        ),
      ];
    }

    // OWNER
    if (st == 'awaiting_confirmation') {
      return [
        InterText(
          text: 'service_card_owner_confirm_desc'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                label: 'service_card_confirm_btn'.tr,
                onTap: onConfirm,
                color: const Color(0xFF16A34A),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _actionButton(
                label: 'service_card_dispute_btn'.tr,
                onTap: onDispute,
                color: const Color(0xFFDC2626),
                outlined: true,
              ),
            ),
          ],
        ),
      ];
    }
    if (st == 'in_progress') {
      return [_infoLine(context, 'service_card_owner_in_progress'.tr)];
    }
    return [_infoLine(context, 'service_card_owner_not_started'.tr)];
  }

  Widget _infoLine(BuildContext context, String text,
      {bool green = false, bool warn = false}) {
    final c = green
        ? const Color(0xFF16A34A)
        : warn
            ? const Color(0xFFDC2626)
            : AppColors.textSecondary(context);
    return InterText(
      text: text,
      fontSize: 13.sp,
      fontWeight: (green || warn) ? FontWeight.w700 : FontWeight.w500,
      color: c,
    );
  }

  Widget _actionButton({
    required String label,
    required Future<void> Function()? onTap,
    required Color color,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (busy || onTap == null) ? null : () => onTap(),
        style: ElevatedButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : color,
          foregroundColor: outlined ? color : Colors.white,
          elevation: outlined ? 0 : 1,
          side: outlined ? BorderSide(color: color, width: 1.3) : null,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: outlined ? color : Colors.white,
                ),
              )
            : InterText(
                text: label,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: outlined ? color : Colors.white,
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
