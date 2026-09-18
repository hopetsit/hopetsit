import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/my_pets_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pet_species_color.dart';
import 'package:hopetsit/views/pet_owner/pet_profile/pet_profile_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_completion_card.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/profile_notification_bell.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/widgets/active_benefits_row.dart';
import 'package:hopetsit/widgets/boost_profile_card.dart';
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
      body: SingleChildScrollView(
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
            _buildOwnerHero(controller),

            Padding(
              // v468 — dégage le bas au-dessus du menu pleine largeur
              padding: EdgeInsets.fromLTRB(
                  // v488 — Daniel : « Se déconnecter toujours trop bas » → on
                  // dégage davantage le bas pour passer au-dessus du menu.
                  16.w, 0, 16.w, 140.h + MediaQuery.of(context).viewPadding.bottom),
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
    );
  }

  /// Owner-specific hero: warm gradient header with centered avatar.
  Widget _buildOwnerHero(ProfileController controller) {
    // v474 — refonte selon la maquette Daniel (Header Redesign) : carte
    // dégradée HD avec 🐾 en filigrane + cercle déco (profondeur), chip rôle
    // « verre dépoli », cloche, avatar à anneau + caméra, nom, badges, et la
    // RANGÉE D'ANIMAUX (spécificité propriétaire) qui défile.
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8753F), Color(0xFFC92A12), Color(0xFFDD431C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34.r)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          _heroPaw(),
          _heroDecoCircle(),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 18.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _heroRoleChip('role_pet_owner'.tr),
                      const Spacer(),
                      const ProfileNotificationBell(role: 'owner'),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildOwnerAvatar(controller),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Obx(() => PoppinsText(
                                  text: controller.userName.value,
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )),
                            SizedBox(height: 7.h),
                            const ActiveBenefitsRow(compact: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildOwnerPetsStrip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🐾 en filigrane (coin haut-droit) — profondeur HD façon maquette.
  Widget _heroPaw() => Positioned(
        right: -26.w,
        top: -24.h,
        child: Transform.rotate(
          angle: 0.31,
          child: Text(
            '🐾',
            style: TextStyle(
              fontSize: 150.sp,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ),
      );

  /// Cercle décoratif translucide (coin bas-gauche).
  Widget _heroDecoCircle() => Positioned(
        left: -34.w,
        bottom: -56.h,
        child: Container(
          width: 150.w,
          height: 150.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      );

  /// Chip « verre dépoli » : logo app + libellé du rôle.
  Widget _heroRoleChip(String label) => Container(
        padding: EdgeInsets.fromLTRB(6.w, 5.h, 13.w, 5.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: Image.asset('assets/brand/png/ic_launcher.png',
                  width: 22.w, height: 22.w, fit: BoxFit.cover),
            ),
            SizedBox(width: 8.w),
            InterText(
              text: label,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ],
        ),
      );

  /// Rangée horizontale des animaux du propriétaire (photo + nom + race),
  /// défile si plus de 3. Câblée sur MyPetsController.
  Widget _buildOwnerPetsStrip() {
    final petsCtl = Get.isRegistered<MyPetsController>()
        ? Get.find<MyPetsController>()
        : Get.put(MyPetsController());
    return Obx(() {
      final pets = petsCtl.pets;
      if (pets.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: 14.h),
        child: SizedBox(
          height: 46.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: pets.length,
            separatorBuilder: (_, __) => SizedBox(width: 10.w),
            itemBuilder: (_, i) {
              final p = pets[i];
              // v540 — Jose : rien n'indiquait qu'on peut modifier la fiche
              // d'un animal → la puce est cliquable (ouvre la fiche, qui
              // contient l'édition) et porte un ✏️ visible.
              return GestureDetector(
                onTap: () => Get.to(() => PetProfileScreen(
                      pet: p,
                      accent: petSpeciesColor(p.category),
                    )),
                child: Container(
                padding: EdgeInsets.fromLTRB(6.w, 6.h, 10.w, 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 17.r,
                      backgroundColor: Colors.white24,
                      backgroundImage: p.avatar.url.isNotEmpty
                          ? CachedNetworkImageProvider(p.avatar.url)
                          : null,
                      child: p.avatar.url.isEmpty
                          ? Icon(Icons.pets, size: 15.sp, color: Colors.white)
                          : null,
                    ),
                    SizedBox(width: 9.w),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: p.petName,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          maxLines: 1,
                        ),
                        if (p.breed.isNotEmpty)
                          InterText(
                            text: p.breed,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                            maxLines: 1,
                          ),
                      ],
                    ),
                    SizedBox(width: 8.w),
                    // ✏️ — affordance d'édition demandée par Jose.
                    Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_rounded,
                          size: 11.sp, color: Colors.white),
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _buildOwnerAvatar(ProfileController controller) {
    return Stack(
      children: [
        Obx(() {
          final imageUrl = controller.profileImageUrl.value;
          final isUploading = controller.isUploadingImage.value;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(55.r),
              child: Container(
                // v477 — maquette v2 : avatar agrandi (84) anneau + caméra.
                width: 84.w,
                height: 84.w,
                color: AppColors.lightGrey,
                child: isUploading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                        ),
                      )
                    : imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 84.w,
                        height: 84.w,
                        memCacheWidth: 300, // v235.
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.lightGrey,
                          child: Icon(Icons.person, size: 50.sp, color: AppColors.primaryColor),
                        ),
                        errorWidget: (context, url, error) =>
                            Icon(Icons.person, size: 50.sp, color: AppColors.primaryColor),
                      )
                    : Icon(Icons.person, size: 50.sp, color: AppColors.primaryColor),
              ),
            ),
          );
        }),
        Obx(() {
          if (controller.isUploadingImage.value) return const SizedBox.shrink();
          return Positioned(
            bottom: 2,
            right: 2,
            child: GestureDetector(
              onTap: controller.pickAndUploadProfilePicture,
              child: Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(Icons.camera_alt_rounded, size: 14.sp, color: Colors.white),
              ),
            ),
          );
        }),
      ],
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

  // _buildProfileInfo removed — replaced by _buildOwnerHero + _buildOwnerAvatar.

  // v406 — _buildSettingsTileDanger retiré : la suppression du compte est
  // désormais rendue par ProfileSecurityTab (onglet Sécurité).
}
