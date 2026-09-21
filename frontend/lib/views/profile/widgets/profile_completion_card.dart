// v565 — point 25 : barre « profil complété à X % » sur la page Profil des
// 3 rôles, avec lien vers ce qui manque. Disparaît quand le profil est à 100 %.
//
// v575 — Daniel : « ça ouvre les mêmes » et « quand tu remplis, ça ne met pas
// à jour ». Le calcul est sorti d'ici (fonction pure `utils/profile_completion.dart`,
// testée) et CHAQUE élément porte désormais sa propre destination : photo →
// sélecteur d'image, téléphone/adresse/ville → feuille coordonnées, nom / bio /
// services / animaux → écran d'édition POSITIONNÉ sur le bon champ, animaux du
// propriétaire → « Mes animaux ». Après l'action, `onChanged` recharge le
// profil depuis le serveur pour que le pourcentage bouge tout de suite.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/profile_completion.dart';
import 'package:hopetsit/views/profile/widgets/contact_info_gate.dart';
import 'package:hopetsit/widgets/app_text.dart';

export 'package:hopetsit/utils/profile_completion.dart'
    show ProfileFixItem, ProfileFixTarget, ProfileFocusField;

/// Conservé pour les appelants historiques.
List<ProfileFixItem> profileCompletionItems(ProfileModel p, String role) =>
    profileCompletionItemsFor(ProfileCompletionInput.fromProfile(p), role);

int profileCompletionPercent(ProfileModel p, String role) =>
    profileCompletionPercentFor(ProfileCompletionInput.fromProfile(p), role);

class ProfileCompletionCard extends StatelessWidget {
  final ProfileModel? profile;
  final String role;
  final Color accent;

  /// Ouvre « Modifier le profil ». Reçoit le champ à mettre en évidence
  /// (`ProfileFocusField.*`) ; un écran qui ne le gère pas l'ignore.
  ///
  /// v576 — le type est un `Future` et il est ATTENDU : quand il ne l'était
  /// pas (`void`), `onChanged` se déclenchait à l'instant même où l'écran
  /// d'édition s'ouvrait, donc AVANT toute modification — le pourcentage ne
  /// bougeait jamais au retour (« la barre ne monte pas », Daniel 21/09).
  final Future<void> Function(String? focusField) onEditProfile;
  /// « Mes animaux » (propriétaire). Attendu lui aussi.
  final Future<void> Function()? onPets;

  /// Sélecteur de photo. Attendu lui aussi.
  final Future<void> Function()? onPhoto;

  /// Rechargement du profil après une action (retour d'écran ou de feuille).
  final Future<void> Function()? onChanged;

  const ProfileCompletionCard({
    super.key,
    required this.profile,
    required this.role,
    required this.accent,
    required this.onEditProfile,
    this.onPets,
    this.onPhoto,
    this.onChanged,
  });

  Future<void> _fix(BuildContext context, ProfileFixItem item) async {
    switch (item.target) {
      case ProfileFixTarget.contactSheet:
        await showContactInfoSheet(context, role: role, profile: profile);
        break;
      case ProfileFixTarget.pets:
        if (onPets != null) {
          await onPets!();
        } else {
          await onEditProfile(item.focusField);
        }
        break;
      case ProfileFixTarget.photo:
        if (onPhoto != null) {
          await onPhoto!();
        } else {
          await onEditProfile(item.focusField);
        }
        break;
      case ProfileFixTarget.editProfile:
        await onEditProfile(item.focusField);
        break;
    }
    // Le pourcentage et la liste doivent bouger DÈS le retour.
    if (onChanged != null) await onChanged!();
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const SizedBox.shrink();
    final input = ProfileCompletionInput.fromProfile(p);
    final items = profileCompletionItemsFor(input, role);
    final missing = items.where((i) => !i.done).toList();
    if (missing.isEmpty) return const SizedBox.shrink();
    final percent = profileCompletionPercentFor(input, role);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PoppinsText(
                  text: 'completion_title'.trParams({'percent': '$percent'}),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: InterText(
                  text: '$percent %',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8.h,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          SizedBox(height: 10.h),
          InterText(
            text: 'completion_subtitle'.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final m in missing)
                GestureDetector(
                  key: ValueKey<String>('completion_fix_${m.key}'),
                  onTap: () => _fix(context, m),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14.sp, color: accent),
                        SizedBox(width: 4.w),
                        InterText(
                          text: m.labelKey.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: accent,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
