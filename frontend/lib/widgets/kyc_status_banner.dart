// v23.1 part 115 — Daniel : "ya pas le badge a verifier aussi coter sitter
// et walker". Petit banner cliquable affiché sous le header du profil
// sitter/walker qui :
//   - rappelle au user qu'il doit vérifier son identité (kycStatus = 'none')
//   - affiche le statut en attente (pending_payment / pending_verification)
//   - affiche le badge vérifié ✓ (verified)
//   - affiche un rejet + retry (rejected)
//
// Click → ouvre KycVerificationScreen.
//
// Lit GET /users/me/benefits via le même mécanisme que ActiveBenefitsRow.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/kyc/kyc_verification_screen.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/app_text.dart';

class KycStatusBanner extends StatefulWidget {
  const KycStatusBanner({super.key});

  @override
  State<KycStatusBanner> createState() => _KycStatusBannerState();
}

class _KycStatusBannerState extends State<KycStatusBanner> {
  String _kycStatus = 'none';
  String _identityVerificationStatus = 'none';
  bool _loaded = false;
  Worker? _tickWorker;

  @override
  void initState() {
    super.initState();
    // v592 — réponse déjà connue (en-tête du profil) → bandeau affiché dès la
    // 1re image, sans apparaître après coup (la page sautait).
    final known = ActiveBenefitsRow.sessionBenefits;
    if (known != null) _apply(known);
    _load();
    // Refresh when ActiveBenefitsRow.notifyChanged() is called (après KYC).
    _tickWorker = ever<int>(
      // ignore: invalid_use_of_protected_member
      ActiveBenefitsRow.refreshTickAccessor,
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _tickWorker?.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> r) {
    _kycStatus = (r['kycStatus'] as String?) ?? 'none';
    _identityVerificationStatus =
        (r['identityVerificationStatus'] as String?) ?? 'none';
    _loaded = true;
  }

  /// v592 — même requête partagée que l'en-tête (ActiveBenefitsRow) : une
  /// seule réponse /users/me/benefits pour les deux.
  Future<void> _load() async {
    await ActiveBenefitsRow.refreshBoostState();
    if (!mounted) return;
    final r = ActiveBenefitsRow.sessionBenefits;
    setState(() {
      if (r != null) {
        _apply(r);
      } else {
        _loaded = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    // v23.1 part 121 — Daniel : "le profil walker me dise identite verifier
    // alors que jai meme pas envoyer limage". Le banner se basait sur
    // `verified || kycStatus=='verified'`, mais `verified` est le flag
    // legacy mis à true par diverses actions admin (vérif IBAN, etc.) et
    // PAS forcément lié à une vérif d'identité. Maintenant on combine
    // kycStatus (flow Persona payant) ET identityVerificationStatus (flow
    // manuel upload + admin review). Le flag legacy `verified` n'est plus
    // utilisé pour décider du badge KYC.
    final isKycVerified = _kycStatus == 'verified' ||
        _identityVerificationStatus == 'verified';
    final isKycRejected = _kycStatus == 'rejected' ||
        _identityVerificationStatus == 'rejected';
    final isKycPending = _kycStatus == 'pending_payment' ||
        _kycStatus == 'pending_verification' ||
        _identityVerificationStatus == 'pending';

    if (isKycVerified) {
      return _banner(
        color: const Color(0xFF16A34A),
        icon: Icons.verified_rounded,
        label: 'kyc_banner_verified'.tr,
        sublabel: 'kyc_banner_verified_sub'.tr,
        statusLabel: 'misc569_kyc_state_verified'.tr,
        onTap: null,
      );
    }
    if (isKycRejected) {
      return _banner(
        color: const Color(0xFFE53935),
        icon: Icons.cancel_outlined,
        label: 'kyc_banner_rejected'.tr,
        sublabel: 'kyc_banner_rejected_sub'.tr,
        ctaLabel: 'misc569_kyc_cta_retry'.tr,
        onTap: _openKyc,
      );
    }
    if (isKycPending) {
      return _banner(
        color: const Color(0xFFF39C12),
        icon: Icons.hourglass_top_rounded,
        label: 'kyc_banner_pending'.tr,
        sublabel: 'kyc_banner_pending_sub'.tr,
        statusLabel: 'misc569_kyc_state_pending'.tr,
        onTap: _openKyc,
      );
    }
    // status = 'none' → CTA explicite
    return _banner(
      color: AppColors.primaryColor,
      icon: Icons.assignment_ind_rounded,
      label: 'kyc_banner_none'.tr,
      sublabel: 'kyc_banner_none_sub'.tr,
      ctaLabel: 'misc569_kyc_cta_start'.tr,
      onTap: _openKyc,
    );
  }

  void _openKyc() async {
    await Get.to(() => const KycVerificationScreen());
    // Refresh après retour de l'écran KYC.
    _load();
  }

  /// v569 — refonte visuelle : carte coins 18 sur fond de carte (plus de bloc
  /// entièrement teinté), disque d'état 40 px, pastille d'état colorée quand
  /// il n'y a rien à faire (validé / en cours) et bouton d'action en pilule
  /// quand il y a une action. Aucun changement de logique ni de navigation.
  Widget _banner({
    required Color color,
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback? onTap,
    String? ctaLabel,
    String? statusLabel,
  }) {
    final clickable = onTap != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: AppColors.cardShadow(context),
            ),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterText(
                        text: label,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        color: AppColors.textPrimary(context),
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: sublabel,
                        fontSize: 11.sp,
                        height: 1.3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                if (clickable && (ctaLabel ?? '').isNotEmpty)
                  _pillButton(ctaLabel!, color)
                else if ((statusLabel ?? '').isNotEmpty)
                  _statusDot(statusLabel!, color)
                else if (clickable)
                  Icon(Icons.chevron_right_rounded, color: color, size: 20.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bouton d'action en pilule (le tap réel reste celui de l'InkWell parent).
  Widget _pillButton(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      constraints: BoxConstraints(maxWidth: 120.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            spreadRadius: -3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InterText(
        text: label,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        color: Colors.white,
      ),
    );
  }

  /// Pastille d'état (validé / en cours) : point coloré + libellé court.
  Widget _statusDot(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      constraints: BoxConstraints(maxWidth: 120.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Flexible(
            child: InterText(
              text: label,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
