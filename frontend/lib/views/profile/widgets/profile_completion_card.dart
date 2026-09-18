// v565 — point 25 : barre « profil complété à X % » sur la page Profil des
// 3 rôles, avec lien vers ce qui manque (feuille coordonnées ou écran
// « Modifier le profil »). Disparaît quand le profil est à 100 %.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/contact_info_gate.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ProfileCompletionItem {
  final String key;
  final String label;
  final bool done;
  const ProfileCompletionItem(this.key, this.label, this.done);
}

/// Calcule les éléments de complétion d'un profil selon le rôle.
List<ProfileCompletionItem> profileCompletionItems(ProfileModel p, String role) {
  final isOwner = role == 'owner';
  final items = <ProfileCompletionItem>[
    ProfileCompletionItem('photo', 'completion_item_photo'.tr, p.avatar.url.trim().isNotEmpty),
    ProfileCompletionItem('phone', 'completion_item_phone'.tr, p.mobile.trim().isNotEmpty),
    ProfileCompletionItem('address', 'completion_item_address'.tr, p.address.trim().isNotEmpty),
    ProfileCompletionItem('city', 'completion_item_city'.tr, (p.city ?? '').trim().isNotEmpty),
    ProfileCompletionItem('bio', 'completion_item_bio'.tr, p.bio.trim().length >= 20),
  ];
  if (isOwner) {
    final petsCount = p.stats.petsCount > 0 ? p.stats.petsCount : p.pets.length;
    items.add(ProfileCompletionItem('pets', 'completion_item_pets'.tr, petsCount > 0));
  } else {
    items.add(ProfileCompletionItem('services', 'completion_item_services'.tr, p.service.isNotEmpty));
    items.add(ProfileCompletionItem('animals', 'completion_item_animals'.tr, p.acceptedPetTypes.isNotEmpty));
  }
  return items;
}

int profileCompletionPercent(ProfileModel p, String role) {
  final items = profileCompletionItems(p, role);
  if (items.isEmpty) return 100;
  final done = items.where((i) => i.done).length;
  return ((done / items.length) * 100).round();
}

class ProfileCompletionCard extends StatelessWidget {
  final ProfileModel? profile;
  final String role;
  final Color accent;
  final VoidCallback onEditProfile;
  final VoidCallback? onPets;
  final VoidCallback? onPhoto;

  const ProfileCompletionCard({
    super.key,
    required this.profile,
    required this.role,
    required this.accent,
    required this.onEditProfile,
    this.onPets,
    this.onPhoto,
  });

  void _fix(BuildContext context, ProfileCompletionItem item) {
    switch (item.key) {
      case 'phone':
      case 'address':
      case 'city':
        showContactInfoSheet(context, role: role, profile: profile);
        break;
      case 'pets':
        (onPets ?? onEditProfile)();
        break;
      case 'photo':
        (onPhoto ?? onEditProfile)();
        break;
      default:
        onEditProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) return const SizedBox.shrink();
    final items = profileCompletionItems(p, role);
    final missing = items.where((i) => !i.done).toList();
    if (missing.isEmpty) return const SizedBox.shrink();
    final percent = profileCompletionPercent(p, role);

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
                          text: m.label,
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
