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

import 'package:hopetsit/data/network/api_client.dart';
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

  Future<void> _load() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final api = Get.find<ApiClient>();
      final r = await api.get('/users/me/benefits', requiresAuth: true);
      if (!mounted) return;
      if (r is Map) {
        setState(() {
          _kycStatus = (r['kycStatus'] as String?) ?? 'none';
          _identityVerificationStatus =
              (r['identityVerificationStatus'] as String?) ?? 'none';
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
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
        onTap: null,
      );
    }
    if (isKycRejected) {
      return _banner(
        color: const Color(0xFFE53935),
        icon: Icons.cancel_outlined,
        label: 'kyc_banner_rejected'.tr,
        sublabel: 'kyc_banner_rejected_sub'.tr,
        onTap: _openKyc,
      );
    }
    if (isKycPending) {
      return _banner(
        color: const Color(0xFFF39C12),
        icon: Icons.hourglass_top_rounded,
        label: 'kyc_banner_pending'.tr,
        sublabel: 'kyc_banner_pending_sub'.tr,
        onTap: _openKyc,
      );
    }
    // status = 'none' → CTA explicite
    return _banner(
      color: AppColors.primaryColor,
      icon: Icons.assignment_ind_rounded,
      label: 'kyc_banner_none'.tr,
      sublabel: 'kyc_banner_none_sub'.tr,
      onTap: _openKyc,
    );
  }

  void _openKyc() async {
    await Get.to(() => const KycVerificationScreen());
    // Refresh après retour de l'écran KYC.
    _load();
  }

  Widget _banner({
    required Color color,
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback? onTap,
  }) {
    final clickable = onTap != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18.sp),
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
                        color: color,
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: sublabel,
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                if (clickable)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: color,
                    size: 20.sp,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
