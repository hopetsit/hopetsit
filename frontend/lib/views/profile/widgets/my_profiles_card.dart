// v565 — Daniel (18/09) : « au lieu de "Passer en sitter / walker / owner",
// mettre "Mon profil sitter…" pour que le client comprenne qu'en UN compte il
// peut avoir les 3 profils, et faire un bouton plus beau ».
// Bloc « Mes profils » partagé par les 3 pages profil : une carte par rôle
// (propriétaire · pet-sitter · promeneur) à la couleur du rôle ; le profil
// actif porte une coche, les autres « Ouvrir » (profil déjà créé) ou
// « Créer » (pas encore). Le tap ouvre la confirmation puis
// AuthController.switchRole (logique inchangée).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class MyProfilesCard extends StatelessWidget {
  const MyProfilesCard({super.key});

  static const List<String> _roles = ['owner', 'sitter', 'walker'];

  static Color accentFor(String role) {
    switch (role) {
      case 'walker':
        return AppColors.walkerAccent;
      case 'sitter':
        return AppColors.sitterAccent;
      default:
        return AppColors.primaryColor;
    }
  }

  static IconData _iconFor(String role) {
    switch (role) {
      case 'walker':
        return Icons.directions_walk_rounded;
      case 'sitter':
        return Icons.home_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  static String _titleFor(String role) => 'my_profile_$role'.tr;

  static String _roleLabel(String role) {
    switch (role) {
      case 'walker':
        return 'role_pet_walker'.tr;
      case 'sitter':
        return 'role_pet_sitter'.tr;
      default:
        return 'role_pet_owner'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      final current = (auth.userRole.value ?? 'owner').toLowerCase();
      final available = auth.availableRoles.map((r) => r.toLowerCase()).toSet();
      return Container(
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 8.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PoppinsText(
              text: 'my_profiles_title'.tr,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 2.h),
            PoppinsText(
              text: 'my_profiles_sub'.tr,
              fontSize: 11.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            for (final role in _roles)
              _ProfileRow(
                role: role,
                accent: accentFor(role),
                icon: _iconFor(role),
                title: _titleFor(role),
                isActive: role == current,
                exists: available.contains(role),
                onTap: role == current
                    ? null
                    : () => _confirm(context, targetRole: role),
              ),
          ],
        ),
      );
    });
  }

  void _confirm(BuildContext context, {required String targetRole}) {
    final auth = Get.find<AuthController>();
    final label = _roleLabel(targetRole);
    final accent = accentFor(targetRole);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Obx(() {
          final isLoading = auth.isSwitchingRole.value;
          return AlertDialog(
            backgroundColor: AppColors.card(dialogContext),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            title: Text(
              _titleFor(targetRole),
              style: TextStyle(
                color: AppColors.textPrimary(dialogContext),
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: CircularProgressIndicator(color: accent),
                  ),
                Text(
                  isLoading
                      ? 'dialog_switch_role_switching'.trParams({'role': label})
                      : 'my_profiles_confirm'.trParams({'role': label}),
                  style: TextStyle(color: AppColors.textPrimary(dialogContext)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                child: Text('common_cancel'.tr,
                    style: TextStyle(color: AppColors.textSecondary(dialogContext))),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        await auth.switchRole(targetRole: targetRole);
                        if (!dialogContext.mounted) return;
                        if (Get.isDialogOpen == true) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text('my_profiles_continue'.tr),
              ),
            ],
          );
        });
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.role,
    required this.accent,
    required this.icon,
    required this.title,
    required this.isActive,
    required this.exists,
    required this.onTap,
  });

  final String role;
  final Color accent;
  final IconData icon;
  final String title;
  final bool isActive;
  final bool exists;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String chip = isActive
        ? 'my_profiles_active'.tr
        : (exists ? 'my_profiles_open'.tr : 'my_profiles_create'.tr);
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: isActive ? accent.withValues(alpha: 0.10) : AppColors.card(context),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isActive ? accent : accent.withValues(alpha: 0.25),
                width: isActive ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(icon, size: 21.sp, color: Colors.white),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: PoppinsText(
                    text: title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive ? accent : AppColors.textPrimary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                // Daniel (18/09) : « Actif » = profil en cours, « Activé » =
                // déjà créé (coche, contour), « Activer » = pas encore créé (plein).
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: isActive || !exists ? accent : Colors.transparent,
                    border: Border.all(color: accent, width: 1.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive || exists)
                        Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: Icon(Icons.check_rounded,
                              size: 13.sp, color: isActive ? Colors.white : accent),
                        ),
                      PoppinsText(
                        text: chip,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: isActive || !exists ? Colors.white : accent,
                      ),
                      if (!isActive && !exists)
                        Padding(
                          padding: EdgeInsets.only(left: 2.w),
                          child: Icon(Icons.chevron_right_rounded, size: 15.sp, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
