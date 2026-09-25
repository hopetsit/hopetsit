// v584 (révision PawMap du 25/09, point 8) — barre du bas des fiches GARDIEN
// et PROMENEUR (ouvertes depuis la carte, l'accueil et les listes).
// Daniel : « Réserver en PREMIER, avec le prix dedans ; le chat en second,
// plus petit ». Widget PUR : les écrans fournissent les tarifs (PawProviderRates,
// devise du prestataire) et les rappels. Bouton signature (dégradé du rôle),
// jamais coupé (9 langues, 320 / 375 px), au-dessus de la barre Samsung
// (`PublicProfileActionBar` → `appBottomInset`).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/pawmap_theme.dart';
import '../../map/pawmap_rates.dart';
import '../../map/widgets/pawmap_buttons.dart';
import '../../map/widgets/pawmap_pins.dart';
import 'public_profile_kit.dart';

class ProviderActionBar extends StatelessWidget {
  const ProviderActionBar({
    super.key,
    required this.role,
    required this.rates,
    required this.onBook,
    required this.onMessage,
    this.canBook = true,
    this.askFirst = false,
    this.messageLocked = false,
    this.messageLoading = false,
  });

  /// 'sitter' | 'walker' — couleur du bouton.
  final String role;
  final PawProviderRates rates;
  final VoidCallback onBook;
  final VoidCallback? onMessage;

  /// false = Message seul. v586 (point 8) : les écrans ne s'en servent plus —
  /// Réserver est proposé à TOUS les spectateurs, sauf sur sa propre fiche
  /// (où la barre n'est pas affichée du tout).
  final bool canBook;

  /// « Demander une réservation » quand il faut d'abord une demande acceptée.
  final bool askFirst;
  final bool messageLocked;
  final bool messageLoading;

  @override
  Widget build(BuildContext context) {
    final Color color = PawMapLegend.roleColor(role);
    final String? from = rates.fromLabel;
    final Widget message = _MessageButton(
      color: color,
      locked: messageLocked,
      loading: messageLoading,
      onTap: onMessage,
      compact: canBook,
    );
    if (!canBook) {
      return PublicProfileActionBar(child: message);
    }
    return PublicProfileActionBar(
      secondary: [message],
      child: PawSignatureButton(
        key: const ValueKey<String>('provider_book'),
        label: askFirst
            ? 'pawmap_profile_ask_booking'.tr
            : (from == null
                ? 'pawmap_member_book'.tr
                : 'pawmap_book_from'.trParams({'price': from})),
        icon: Icons.event_available_rounded,
        color: color,
        action: PawButtonAction.book,
        onTap: onBook,
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({
    required this.color,
    required this.locked,
    required this.loading,
    required this.onTap,
    required this.compact,
  });
  final Color color;
  final bool locked;
  final bool loading;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String label = locked
        ? 'sitter_detail_unlock_after_payment'.tr
        : 'pawmap_profile_message'.tr;
    if (!compact) {
      return PawSignatureButton(
        key: const ValueKey<String>('provider_message'),
        kind: PawButtonKind.secondary,
        label: label,
        icon: locked ? Icons.lock_rounded : Icons.chat_bubble_rounded,
        color: color,
        loading: loading,
        enabled: !locked && onTap != null,
        onTap: onTap,
      );
    }
    // Petit : rond 48 avec l'icône + libellé court sous forme d'infobulle
    // (le bouton Réserver garde toute la largeur utile).
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: const ValueKey<String>('provider_message'),
          behavior: HitTestBehavior.opaque,
          onTap: (locked || loading) ? null : onTap,
          child: Container(
            width: 52.w,
            height: 52.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: PawMapTheme.isDark(context) ? 0.22 : 0.10),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: color.withValues(alpha: locked ? 0.25 : 0.55), width: 1.4),
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accentOn(context, color)),
                    )
                  : Icon(locked ? Icons.lock_rounded : Icons.chat_bubble_rounded,
                      size: 22.sp, color: AppColors.accentOn(context, color)),
            ),
          ),
        ),
      ),
    );
  }
}
