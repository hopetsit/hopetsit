import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_completion_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_hero.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
// v23.1 part 124 — Daniel : "Enlever admin de lapp ; car jai admin
// navigateur". Le panel admin est désormais accessible UNIQUEMENT via
// le navigateur (https://hopetsit-backend.onrender.com/admin). Le
// raccourci profil + l'import sont retirés ; le fichier
// views/admin/admin_dashboard_screen.dart sera supprimé en suivant.

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileController controller = Get.put(ProfileController());

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: PawPatternBackground(
 color: AppColors.activeRoleAccent(),
 child: SingleChildScrollView(
        child: Column(
          children: [
            // ── OWNER HERO HEADER ──────────────────────
            // v23.1.149 — Daniel : "le boost sur owner ne saffiche pas". On
            // wrap le hero dans un Obx qui ajoute un cadre doré + glow dès
            // que `ActiveBenefitsRow.boostActiveAccessor` passe à true. Ça
            // se rebuild auto quand l'ActiveBenefitsRow interne fetch ses
            // /users/me/benefits.
            // v23.1.175 — Daniel : "le cadre boost napparait toujour pas
            // sur le profile owner". Cause : timing async — _boostActive
            // mis à true seulement après le mount du widget enfant
            // ActiveBenefitsRow. On force maintenant un refetch immédiat
            // dès le build du profil owner pour avoir l'état correct au
            // tout premier frame (au lieu d'attendre 60s+ pour le tick).
            Builder(builder: (ctx) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ActiveBenefitsRow.refreshBoostState();
              });
              return const SizedBox.shrink();
            }),
            // v477 — maquette v2 : « Pas de contour jaune autour de la carte ».
            // Le liseré doré PawBoost est retiré du héros owner ; le statut
            // boost reste signalé par les badges/pastilles habituels.
            // v565 — en-tête PARTAGÉ par les 3 rôles (ProfileHero) : même
            // structure, dégradé orange propriétaire.
            ProfileHero(
              role: 'owner',
              userName: controller.userName,
              profileImageUrl: controller.profileImageUrl,
              profile: controller.profile,
              isUploadingImage: controller.isUploadingImage,
              onCamera: controller.pickAndUploadProfilePicture,
            ),

            Padding(
              // v468 — dégage le bas au-dessus du menu pleine largeur
              padding: EdgeInsets.fromLTRB(
                  // v488 — Daniel : « Se déconnecter toujours trop bas » → on
                  // dégage davantage le bas pour passer au-dessus du menu.
                  16.w, 0, 16.w, 140.h + appBottomInset(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),

                  // v565 — point 25 : barre « profil complété à X % ».
                  Obx(() => ProfileCompletionCard(
                        profile: controller.profile.value,
                        role: 'owner',
                        accent: AppColors.primaryColor,
                        onEditProfile: controller.navigateToEditProfile,
                        onPets: controller.navigateToEditPetProfile,
                        onPhoto: controller.pickAndUploadProfilePicture,
                      )),

                  // Quick Actions Row
                  _buildQuickActions(controller),
                  SizedBox(height: 20.h),

                  // v18.6 — Bouton "Booster mon profil" (orange owner).
                  const BoostProfileCard(role: 'owner'),
                  SizedBox(height: 20.h),

                  // Switch Role Cards — shows the 2 other roles the user can switch to.
                  const MyProfilesCard(),
                  SizedBox(height: 20.h),

                  // v565 — points 26/33 : catégories claires (Compte · Mes
                  // animaux · Paiements & wallet · Abonnements & boutique ·
                  // Préférences & notifications · Sécurité · Aide).
                  ProfileCategories(
                    role: 'owner',
                    accent: AppColors.primaryColor,
                    host: controller,
                    onEditProfile: controller.navigateToEditProfile,
                  ),

                  SizedBox(height: 24.h),

                  // Logout Button
                  ProfileSecondaryButton(
                    label: 'button_logout'.tr,
                    accent: AppColors.primaryColor,
                    icon: Icons.logout_rounded,
                    onTap: () => controller.showLogoutDialog(context),
                  ),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ],
        ),
      ),
),
    );
  }

  /// Quick action cards row for owner.
  Widget _buildQuickActions(ProfileController controller) {
    // v565 — Daniel : « le bouton Modifier l'animal, plus joli et moderne ».
    // Carte blanche Apple : icône patte sur carré orange, titre + sous-titre,
    // chevron ; ombre douce, pression = léger fondu.
    return Builder(
      builder: (context) {
        final accent = AppColors.ownerAccent;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: controller.navigateToEditPetProfile,
            borderRadius: BorderRadius.circular(18.r),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: AppColors.cardShadow(context),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.78)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13.r),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.pets_rounded, color: Colors.white, size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PoppinsText(
                            text: 'pet_edit_animal'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          InterText(
                            text: 'pet_edit_animal_sub'.tr,
                            fontSize: 11.5.sp,
                            color: AppColors.textSecondary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 30.w,
                      height: 30.w,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_right_rounded, color: accent, size: 20.sp),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // _buildProfileInfo / _buildOwnerHero / _buildOwnerAvatar / _buildOwnerPetsStrip
  // retirés en v565 : l'en-tête est le widget partagé ProfileHero.

  // v406 — _buildSettingsTileDanger retiré : la suppression du compte est
  // désormais rendue par ProfileSecurityTab (onglet Sécurité).
}
