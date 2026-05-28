// v23.1 part 247 — Daniel : "ni le beau badge verifier". Widget reactive
// qui appelle GET /users/me/benefits au mount + se re-render quand
// ActiveBenefitsRow.notifyChanged() est fire (par exemple apres la
// completion KYC dans kyc_verification_screen.dart). Affiche le widget
// VerifiedBadge embelli (gradient bleu + icone + texte i18n) si l'user
// courant est verifie, sinon ne render rien (SizedBox.shrink).
//
// Usage : ajouter `const MyKycVerifiedBadge(large: true)` a cote du nom
// dans les profile screens sitter + walker.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/verified_badge.dart';

class MyKycVerifiedBadge extends StatefulWidget {
  final bool large;
  const MyKycVerifiedBadge({super.key, this.large = true});

  @override
  State<MyKycVerifiedBadge> createState() => _MyKycVerifiedBadgeState();
}

class _MyKycVerifiedBadgeState extends State<MyKycVerifiedBadge> {
  bool _isVerified = false;
  bool _loaded = false;
  Worker? _tickWorker;

  @override
  void initState() {
    super.initState();
    _load();
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
        final kyc = (r['kycStatus'] as String?) ?? 'none';
        final id = (r['identityVerificationStatus'] as String?) ?? 'none';
        final verified = kyc == 'verified' || id == 'verified';
        setState(() {
          _isVerified = verified;
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
    return VerifiedBadge(isVerified: _isVerified, large: widget.large);
  }
}
