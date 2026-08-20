import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/date_slash_formatter.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v409 refonte — inscription en wizard 5 étapes (maquette « S'INSCRIRE COMME …
/// »). Réutilise SignUpController (tag: userType) → l'auth/OTP existante n'est
/// pas touchée. Couleurs par rôle : owner orange / sitter bleu / walker vert.
class SignupWizardScreen extends StatelessWidget {
  final String userType; // 'pet_owner' | 'pet_sitter' | 'pet_walker'
  const SignupWizardScreen({super.key, required this.userType});

  bool get _isOwner => userType == 'pet_owner';
  bool get _isSitter => userType == 'pet_sitter';
  bool get _isWalker => userType == 'pet_walker';

  Color get _accent => _isWalker
      ? AppColors.walkerAccent
      : _isSitter
          ? AppColors.sitterAccent
          : AppColors.primaryColor;

  static const _steps = 5;

  SignUpController _ctrl() {
    return Get.isRegistered<SignUpController>(tag: userType)
        ? Get.find<SignUpController>(tag: userType)
        : Get.put(
            SignUpController(
              userType: userType,
              authRepository: Get.find<AuthRepository>(),
            ),
            tag: userType,
            permanent: true,
          );
  }

  @override
  Widget build(BuildContext context) {
    // v449 — teinte la page d'inscription par RÔLE (owner orange / sitter bleu
    // / walker vert) AVANT toute auth. Une fois connecté, le rôle réel reprend
    // la main (le override n'est qu'un fallback), donc aucune fuite.
    AppColors.activeRoleOverride = userType;
    final c = _ctrl();
    // S'assure que l'AuthController est dispo (parité avec sign_up_screen).
    if (!Get.isRegistered<AuthController>()) {
      Get.put(
        AuthController(Get.find<AuthRepository>(), GetStorage()),
        tag: userType,
        permanent: true,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.appBar(context),
        leading: BackButton(
          color: AppColors.textPrimary(context),
          onPressed: () {
            if (c.currentStep.value > 0) {
              c.currentStep.value -= 1;
              c.onStepEntered(c.currentStep.value);
            } else {
              Get.back();
            }
          },
        ),
      ),
      // v449 — Daniel : « quand on écrit on voit mal, fais page pleine ».
      // resizeToAvoidBottomInset=true (défaut) + on MASQUE le gros en-tête
      // (logo + titre + sous-titre) dès que le clavier est ouvert → les champs
      // récupèrent toute la hauteur et sont tous lisibles ; padding bas généreux
      // pour que le dernier champ ne passe pas sous le bouton « Suivant ».
      body: SafeArea(
        child: Obx(() {
          final step = c.currentStep.value;
          final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
          return Column(
            children: [
              if (!keyboardOpen) ...[
                _header(context),
                SizedBox(height: 14.h),
              ] else
                SizedBox(height: 8.h),
              _progressBar(step),
              SizedBox(height: keyboardOpen ? 12.h : 18.h),
              Expanded(
                child: SingleChildScrollView(
                  controller: c.wizardScroll,
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                  child: _stepBody(context, c, step),
                ),
              ),
              _bottomBar(context, c, step),
            ],
          );
        }),
      ),
    );
  }

  // ── header (logo patte + titre + sous-titre) ──────────────────────────────
  Widget _header(BuildContext context) {
    final titleKey = _isOwner
        ? 'signup_wizard_title_owner'
        : _isSitter
            ? 'signup_wizard_title_sitter'
            : 'signup_wizard_title_walker';
    final subKey = _isOwner
        ? 'signup_wizard_sub_owner'
        : _isSitter
            ? 'signup_wizard_sub_sitter'
            : 'signup_wizard_sub_walker';
    return Column(
      children: [
        // v480 — maquette « Inscription Flow » : en-tête compact (paw rond
        // 46px couleur du rôle + ombre) pour que l'étape tienne sans scroll.
        Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            color: _accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.pets_rounded, color: Colors.white, size: 23.sp),
        ),
        SizedBox(height: 8.h),
        PoppinsText(
          text: titleKey.tr.toUpperCase(),
          fontSize: 16.sp,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 3.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: InterText(
            text: subKey.tr,
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── barre de progression 1-2-3-4-5 ────────────────────────────────────────
  Widget _progressBar(int step) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Row(
        children: List.generate(_steps * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < step;
            return Expanded(
              child: Container(
                height: 2.5.h,
                color: done ? _accent : AppColors.greyColor.withValues(alpha: 0.3),
              ),
            );
          }
          final idx = i ~/ 2;
          final active = idx <= step;
          return Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: active ? _accent : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? _accent : AppColors.greyColor.withValues(alpha: 0.4),
                width: 1.6,
              ),
            ),
            alignment: Alignment.center,
            child: idx < step
                ? Icon(Icons.check, color: Colors.white, size: 14.sp)
                : InterText(
                    text: '${idx + 1}',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.greyColor,
                  ),
          );
        }),
      ),
    );
  }

  // ── corps de l'étape ───────────────────────────────────────────────────────
  Widget _stepBody(BuildContext context, SignUpController c, int step) {
    if (step == 0) return _stepPerso(context, c);
    if (_isOwner) {
      switch (step) {
        case 1:
          return _stepOwnerPets(context, c);
        case 2:
          return _stepOwnerSearch(context, c);
        case 3:
          return _stepOwnerPrefs(context, c);
        default:
          return _stepReview(context, c);
      }
    }
    // sitter / walker
    switch (step) {
      case 1:
        return _stepProviderLocation(context, c);
      case 2:
        return _stepProviderAbout(context, c);
      case 3:
        return _stepProviderRates(context, c);
      default:
        return _stepReview(context, c);
    }
  }

  // ── ÉTAPE 1 — Informations personnelles (commune) ──────────────────────────
  Widget _stepPerso(BuildContext context, SignUpController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_personal'.tr),
        // v492 — Daniel : « tout le monde loupe l'ajout de la photo ». Bloc MIS
        // EN ÉVIDENCE (carte teintée + anneau accent + halo) avec le libellé
        // « Photo de profil » écrit À GAUCHE et le cercle photo à droite.
        GestureDetector(
          onTap: c.pickProfileImage,
          child: Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                  color: _accent.withValues(alpha: 0.35), width: 1.4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoppinsText(
                        text: 'signup_photo_label'.tr,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                      ),
                      SizedBox(height: 4.h),
                      InterText(
                        text: 'signup_photo_hint'.tr,
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Obx(() {
                  final img = c.profileImageRx.value;
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _accent, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38.r,
                          backgroundColor: _accent.withValues(alpha: 0.12),
                          backgroundImage: img != null ? FileImage(img) : null,
                          child: img == null
                              ? Icon(Icons.add_a_photo_rounded,
                                  size: 30.sp, color: _accent)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(Icons.camera_alt,
                              size: 12.sp, color: Colors.white),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        _field(c.nameController, 'signup_field_name'.tr),
        // v527 — retour Jose : hint localisé (DD/MM/AAAA en espagnol…) +
        // slashs insérés automatiquement pendant la saisie.
        _field(c.dobController, 'signup_field_dob'.tr,
            hint: 'date_hint_dmy'.tr,
            kb: TextInputType.datetime,
            formatters: [DateSlashFormatter()]),
        _label('signup_field_language'.tr),
        Obx(() => _dropdown(
              value: c.selectedLanguage.value,
              items: c.languageOptions,
              onChanged: c.updateLanguage,
            )),
        SizedBox(height: 10.h),
        _label('signup_field_phone'.tr),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.greyColor.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: CountryCodePicker(
                onChanged: (cc) {
                  c.selectedCountryCode.value = cc.dialCode ?? '+1';
                  if (cc.code != null) c.selectedCountry.value = cc.code!;
                },
                // v441 — préremplissage région : indicatif déduit de la locale
                // du device (region ES → +34). L'utilisateur peut changer.
                initialSelection: c.initialCountryIso,
                favorite: const ['FR', 'BE', 'CH', 'US'],
                showFlagDialog: true,
                padding: EdgeInsets.zero,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(child: _field(c.phoneController, '', kb: TextInputType.phone, dense: true)),
          ],
        ),
        SizedBox(height: 10.h),
        _field(c.emailController, 'signup_field_email'.tr, kb: TextInputType.emailAddress),
        _PasswordField(controller: c.passwordController, label: 'signup_field_password'.tr,
            onChanged: (v) => c.passwordLive.value = v, accent: _accent),
        _PasswordField(
            controller: c.confirmPasswordController,
            label: 'signup_field_confirm_password'.tr,
            accent: _accent),
        SizedBox(height: 10.h),
        Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v532 — la checklist reflète EXACTEMENT validatePassword()
                // (longueur / majuscule / minuscule / chiffre). Avant, elle
                // affichait « caractère spécial » — non exigé — et taisait la
                // minuscule — exigée : les 4 pastilles passaient au vert puis
                // le bouton Suivant refusait le mot de passe.
                _pwRule('signup_pw_min'.tr, c.pwMinLength),
                _pwRule('signup_pw_upper'.tr, c.pwHasUpper),
                _pwRule('signup_pw_lower'.tr, c.pwHasLower),
                _pwRule('signup_pw_digit'.tr, c.pwHasDigit),
              ],
            )),
      ],
    );
  }

  // ── ÉTAPE 2 owner — Mes animaux (ajout après vérif email) ──────────────────
  Widget _stepOwnerPets(BuildContext context, SignUpController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_pets'.tr),
        InterText(
          text: 'signup_pets_hint'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.pets_rounded, color: _accent, size: 22.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: 'signup_pets_after_verification'.tr,
                  fontSize: 13.sp,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 3 owner — Ce que vous recherchez ─────────────────────────────────
  Widget _stepOwnerSearch(BuildContext context, SignUpController c) {
    final services = const [
      ['walk', 'signup_service_walk', 'signup_service_walk_sub', Icons.directions_walk_rounded],
      ['daycare', 'signup_service_daycare', 'signup_service_daycare_sub', Icons.wb_sunny_rounded],
      ['boarding', 'signup_service_boarding', 'signup_service_boarding_sub', Icons.home_rounded],
      ['visit', 'signup_service_visit', 'signup_service_visit_sub', Icons.volunteer_activism_rounded],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_search'.tr),
        InterText(
          text: 'signup_search_hint'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 14.h),
        ...services.map((s) => Obx(() {
              final sel = c.selectedServices.contains(s[0]);
              return _checkRow(
                icon: s[3] as IconData,
                title: (s[1] as String).tr,
                sub: (s[2] as String).tr,
                selected: sel,
                onTap: () => c.toggleInList(c.selectedServices, s[0] as String),
              );
            })),
        SizedBox(height: 14.h),
        // v532 — le propriétaire n'avait AUCUNE étape de localisation : il
        // choisissait un « rayon de recherche » sans point de référence, et
        // son compte était créé sans coordonnées → la recherche « autour de
        // moi » et la PawMap démarraient à vide. On réutilise exactement le
        // bloc localisation des prestataires (détection auto + autocomplete).
        _label('signup_step_location'.tr),
        _locationBlock(context, c),
        SizedBox(height: 14.h),
        _label('signup_search_radius'.tr),
        _radiusDropdown(c),
        SizedBox(height: 16.h),
        // v419 — Daniel : "il manque À propos de moi (max 250) qui s'affichera
        // sur ma publication owner, visible par walker/sitter". L'owner décrit
        // ses animaux / attentes ; ce bio est envoyé (data['bio']) et apparaît
        // sur l'annonce.
        _label('signup_about_you'.tr),
        TextField(
          controller: c.bioController,
          maxLines: 4,
          maxLength: 250,
          decoration: _roundedDec(hint: 'signup_about_hint_owner'.tr),
        ),
      ],
    );
  }

  // ── ÉTAPE 4 owner — Vos préférences ────────────────────────────────────────
  Widget _stepOwnerPrefs(BuildContext context, SignUpController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_prefs'.tr),
        Obx(() => _switchRow('profile_pref_notifications'.tr, c.prefNotifications.value,
            (v) => c.prefNotifications.value = v)),
        Obx(() => _switchRow('profile_pref_quick_replies'.tr, c.prefQuickReplies.value,
            (v) => c.prefQuickReplies.value = v)),
        Obx(() => _switchRow('profile_pref_photos'.tr, c.prefPhotos.value,
            (v) => c.prefPhotos.value = v)),
        // v445 — « Assurance PawMap » retirée du wizard (fonctionnalité morte).
        Obx(() => _switchRow('profile_pref_flexible_cancellation'.tr, c.prefFlexCancel.value,
            (v) => c.prefFlexCancel.value = v)),
        SizedBox(height: 14.h),
        _label('signup_pref_language'.tr),
        Obx(() => _dropdown(
              value: c.selectedLanguage.value,
              items: c.languageOptions,
              onChanged: c.updateLanguage,
            )),
      ],
    );
  }

  // ── ÉTAPE 2 sitter/walker — Localisation ───────────────────────────────────

  /// v540 — bloc localisation UNIFIÉ des 3 profils, « simple et joli » :
  /// la position est détectée automatiquement à l'entrée de l'étape
  /// (onStepEntered) ; pendant la détection → carte avec spinner ; ville
  /// trouvée → carte ✓ avec la ville + « Modifier » ; sinon → bouton de
  /// détection + autocomplete manuel (comportement historique).
  Widget _locationBlock(BuildContext context, SignUpController c) {
    return Obx(() {
      final getting = c.isGettingLocation.value;
      final detected = c.userCity.value;
      final typed = c.cityController.text.trim();
      final city = detected.isNotEmpty ? detected : typed;
      final has = (c.userLatitude.value != null &&
              c.userLongitude.value != null) ||
          typed.isNotEmpty;
      final editing = c.editingLocation.value;

      if (getting) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18.sp,
                height: 18.sp,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: _accent),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: InterText(
                  text: 'location_getting'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: _accent,
                ),
              ),
            ],
          ),
        );
      }

      if (has && !editing) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: _accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.place_rounded,
                    size: 20.sp, color: Colors.white),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'signup_city_detected'.tr,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: PoppinsText(
                            text: city.isEmpty ? '📍' : city,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(Icons.check_circle_rounded,
                            size: 16.sp, color: const Color(0xFF27AE60)),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => c.editingLocation.value = true,
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: InterText(
                  text: 'signup_change_city'.tr,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: c.getCurrentLocationFromMaps,
            icon: Icon(Icons.my_location_rounded,
                size: 18.sp, color: _accent),
            label: Text('signup_location_auto'.tr),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: BorderSide(color: _accent),
              minimumSize: Size(double.infinity, 46.h),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r)),
            ),
          ),
          SizedBox(height: 10.h),
          CityLocationPicker(
            cityController: c.cityController,
            onGetLocation: () => c.getCurrentLocationFromMaps(),
            isGettingLocation: c.isGettingLocation.value,
            detectedCity: c.userCity.value,
            onLocationSelected: (city, lat, lng) {
              c.userCity.value = city;
              c.userLatitude.value = lat;
              c.userLongitude.value = lng;
              c.editingLocation.value = false;
            },
          ),
        ],
      );
    });
  }

  Widget _stepProviderLocation(BuildContext context, SignUpController c) {
    final animals = _isWalker
        ? const [
            ['dog', 'pet_animal_dog'],
            ['cat', 'pet_animal_cat'],
            ['small', 'pet_animal_small'],
            ['nac', 'pet_animal_nac'],
          ]
        : const [
            ['dog', 'pet_animal_dog'],
            ['cat', 'pet_animal_cat'],
            ['rodent', 'pet_animal_rodent'],
            ['bird', 'pet_animal_bird'],
            ['reptile', 'pet_animal_reptile'],
            ['nac', 'pet_animal_nac'],
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_location'.tr),
        // v494 — Daniel : « remets le bouton auto-détection ». Bouton PROÉMINENT
        // « Détecter ma position » au-dessus du champ ville (en plus du mini
        // bouton interne de CityLocationPicker), même handler getCurrentLocation.
        _locationBlock(context, c),
        SizedBox(height: 12.h),
        _label('signup_field_radius'.tr),
        _radiusDropdown(c),
        SizedBox(height: 6.h),
        _label(_isWalker ? 'signup_animals_walked'.tr : 'signup_animals_accepted'.tr),
        Obx(() => Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: animals.map((a) {
                final sel = c.acceptedAnimals.contains(a[0]);
                return _chip((a[1]).tr, sel,
                    () => c.toggleInList(c.acceptedAnimals, a[0]));
              }).toList(),
            )),
        if (_isWalker) ...[
          SizedBox(height: 14.h),
          _label('signup_availability'.tr),
          _daysSelector(c),
          SizedBox(height: 14.h),
          _label('signup_durations'.tr),
          Obx(() => Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: const [
                  ['30', '30 min'],
                  ['60', '1 h'],
                  ['120', '2 h'],
                ].map((d) {
                  final sel = c.selectedDurations.contains(d[0]);
                  return _chip(d[1], sel,
                      () => c.toggleInList(c.selectedDurations, d[0]));
                }).toList(),
              )),
        ] else ...[
          SizedBox(height: 14.h),
          _label('signup_services_offered'.tr),
          ...const [
            ['sit_home', 'signup_sitsvc_at_mine'],
            ['sit_owner', 'signup_sitsvc_at_owner'],
            ['daycare', 'signup_sitsvc_daycare'],
            ['meds', 'signup_sitsvc_meds'],
            ['vet_transport', 'signup_sitsvc_vet_transport'],
          ].map((s) => Obx(() {
                final sel = c.selectedServices.contains(s[0]);
                return _checkRow(
                  title: (s[1]).tr,
                  selected: sel,
                  onTap: () => c.toggleInList(c.selectedServices, s[0]),
                );
              })),
        ],
      ],
    );
  }

  // ── ÉTAPE 3 sitter/walker — À propos + Expérience ──────────────────────────
  Widget _stepProviderAbout(BuildContext context, SignUpController c) {
    final exp = _isWalker
        ? const [
            ['passionate', 'signup_exp_passionate'],
            ['owner', 'signup_exp_owner'],
            ['shelter', 'signup_exp_shelter'],
            ['training_dog', 'signup_exp_training_dog'],
            ['ex_pro_walker', 'signup_exp_ex_pro_walker'],
            ['educator_dog', 'signup_exp_educator_dog'],
          ]
        : const [
            ['passionate', 'signup_exp_passionate'],
            ['owner', 'signup_exp_owner'],
            ['ex_sitter', 'signup_exp_ex_sitter'],
            ['training', 'signup_exp_training'],
            ['educator', 'signup_exp_educator'],
            ['vet_aux', 'signup_exp_vet_aux'],
            ['shelter', 'signup_exp_shelter'],
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_about'.tr),
        _label('signup_about_you'.tr),
        TextField(
          controller: c.bioController,
          maxLines: 4,
          maxLength: 250,
          decoration: _roundedDec(hint: 'signup_about_hint'.tr),
        ),
        SizedBox(height: 8.h),
        _label('signup_experience'.tr),
        ...exp.map((e) => Obx(() {
              final sel = c.experienceTags.contains(e[0]);
              return _checkRow(
                title: (e[1]).tr,
                selected: sel,
                onTap: () => c.toggleInList(c.experienceTags, e[0]),
              );
            })),
      ],
    );
  }

  // ── ÉTAPE 4 sitter/walker — Mes tarifs ──────────────────────────────────────
  Widget _stepProviderRates(BuildContext context, SignUpController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('signup_step_rates'.tr),
        _label('signup_currency'.tr),
        Obx(() => _dropdown(
              value: c.selectedCurrency.value,
              items: c.currencyOptions,
              onChanged: c.updateCurrency,
            )),
        SizedBox(height: 8.h),
        if (_isWalker) ...[
          // v532 — les durées cochées à l'étape 2 pilotent enfin les champs
          // de tarif. AVANT, `selectedDurations` n'était lu NULLE PART : le
          // promeneur cochait « 30 min » puis on lui redemandait quand même
          // les 3 tarifs — étape 2 sans effet et formulaire contradictoire.
          // Si rien n'est coché, on affiche les 3 (comportement historique).
          Obx(() {
            final sel = c.selectedDurations;
            final showAll = sel.isEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAll || sel.contains('30'))
                  _field(c.walkerRate30Controller, 'signup_rate_30min'.tr,
                      kb: TextInputType.number, suffix: c.currencySymbol),
                if (showAll || sel.contains('60'))
                  _field(c.walkerRate60Controller, 'signup_rate_1h'.tr,
                      kb: TextInputType.number, suffix: c.currencySymbol),
                if (showAll || sel.contains('120'))
                  _field(c.walkerRate120Controller, 'signup_rate_2h'.tr,
                      kb: TextInputType.number, suffix: c.currencySymbol),
              ],
            );
          }),
        ] else ...[
          // v532 — suffixe = devise réellement choisie (et non « € » en dur).
          Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(c.ratePerDayController, 'signup_rate_day'.tr,
                      kb: TextInputType.number, suffix: c.currencySymbol),
                  _field(c.ratePerWeekController, 'signup_rate_week'.tr,
                      kb: TextInputType.number, suffix: c.currencySymbol),
                  _field(c.ratePerMonthController, 'signup_rate_month'.tr,
                      kb: TextInputType.number, suffix: c.currencySymbol),
                ],
              )),
        ],
        _field(c.extraAnimalController, 'signup_rate_extra_animal'.tr,
            kb: TextInputType.number, suffix: '€'),
        // v444 — « Temps de réponse » (minutes), identique à my_rates_screen
        // (sitter + walker). Persisté en responseTimeMinutes → cohérent avec
        // ce qu'affiche l'onglet Tarifs du profil après l'inscription.
        _field(c.responseTimeController, 'signup_rate_response_time'.tr,
            kb: TextInputType.number, suffix: 'min'),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.lightGrey.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16.sp, color: AppColors.greyColor),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'signup_rate_extra_hint'.tr,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 5 — Aperçu + conditions ──────────────────────────────────────────
  Widget _stepReview(BuildContext context, SignUpController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_isOwner ? 'signup_step_review_account'.tr : 'signup_step_review_profile'.tr),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Obx(() {
                final img = c.profileImageRx.value;
                return CircleAvatar(
                  radius: 28.r,
                  backgroundColor: _accent.withValues(alpha: 0.12),
                  backgroundImage: img != null ? FileImage(img) : null,
                  child: img == null
                      ? Icon(Icons.person, color: _accent, size: 26.sp)
                      : null,
                );
              }),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: c.nameController.text.trim().isEmpty
                          ? '—'
                          : c.nameController.text.trim(),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    if (!_isOwner)
                      Padding(
                        padding: EdgeInsets.only(top: 2.h, bottom: 2.h),
                        child: InterText(
                          text: '⭐ ${'signup_new_profile'.tr}',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: _accent,
                        ),
                      ),
                    if (c.cityController.text.trim().isNotEmpty)
                      InterText(
                        text: '📍 ${c.cityController.text.trim()}',
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    if (!_isOwner)
                      InterText(
                        text: '⏱ ${'signup_response_15'.tr}  ·  🟢 ${'signup_available_today'.tr}',
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // v417 — Daniel : "l'aperçu doit montrer services + tarifs comme la
        // maquette". Récap Services proposés + Mes tarifs pour sitter/walker.
        if (!_isOwner) ...[
          SizedBox(height: 12.h),
          _reviewProviderRecap(context, c),
        ],
        SizedBox(height: 14.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16.sp, color: _accent),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: 'signup_review_editable_hint'.tr,
                  fontSize: 12.sp,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        Obx(() => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: c.agreeToTerms.value,
                  activeColor: _accent,
                  onChanged: c.toggleAgreeToTerms,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12.h),
                    child: InterText(
                      text: 'signup_accept_terms'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            )),
      ],
    );
  }

  // v417 — récap "Aperçu de mon profil" : services + tarifs (comme la maquette).
  Widget _reviewProviderRecap(BuildContext context, SignUpController c) {
    String v(TextEditingController ctrl) {
      final t = ctrl.text.trim();
      return t.isEmpty ? '—' : t;
    }

    // v540 — devise du profil (plus de « € » en dur) + unités TRADUITES
    // (elles restaient en français dans les 7 autres langues).
    final sym = c.currencySymbol;
    final List<List<String>> tarifs = _isWalker
        ? [
            ['${v(c.walkerRate30Controller)} $sym', '/ 30 min'],
            ['${v(c.walkerRate60Controller)} $sym', '/ 1 h'],
            ['${v(c.walkerRate120Controller)} $sym', '/ 2 h'],
          ]
        : [
            ['${v(c.ratePerDayController)} $sym', '/ ${'unit_day'.tr}'],
            ['${v(c.ratePerWeekController)} $sym', '/ ${'unit_week'.tr}'],
            ['${v(c.ratePerMonthController)} $sym', '/ ${'unit_month'.tr}'],
          ];

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'signup_review_services'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 6.h),
          Obx(() => Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: c.acceptedAnimals.isEmpty
                    ? [
                        InterText(
                          text: '—',
                          fontSize: 12.sp,
                          color: AppColors.greyText,
                        )
                      ]
                    : c.acceptedAnimals
                        .map((a) => Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 5.h),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: InterText(
                                text: 'pet_animal_$a'.tr,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: _accent,
                              ),
                            ))
                        .toList(),
              )),
          Divider(height: 20.h, color: AppColors.greyText.withValues(alpha: 0.15)),
          InterText(
            text: 'signup_review_rates'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 6.h),
          ...tarifs.map((t) => Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    PoppinsText(
                      text: t[0],
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                    SizedBox(width: 6.w),
                    InterText(
                      text: t[1],
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              )),
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: InterText(
              text: '+ ${c.extraAnimalController.text.trim().isEmpty ? '8' : c.extraAnimalController.text.trim()} € ${'signup_per_extra_animal'.tr}',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── barre de boutons bas ────────────────────────────────────────────────────
  Widget _bottomBar(BuildContext context, SignUpController c, int step) {
    final isLast = step == _steps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
      // v480 — maquette « Inscription Flow » : bouton d'action en dégradé de
      // la couleur du rôle, collé en bas (mêmes onNext/isLoading qu'avant).
      child: Obx(() {
        final loading = c.isLoading.value;
        return Container(
          width: double.infinity,
          height: 52.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_accent, Color.lerp(_accent, Colors.black, 0.18)!],
            ),
            borderRadius: BorderRadius.circular(15.r),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15.r),
              onTap: loading ? null : () => _onNext(c, step, isLast),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : PoppinsText(
                        text: isLast
                            ? (_isOwner
                                ? 'signup_create_account'.tr
                                : 'signup_create_profile'.tr)
                            : 'common_next'.tr,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _onNext(SignUpController c, int step, bool isLast) {
    // v532 — TOUTES les étapes sont validées (avant : seulement la 1re), et
    // l'erreur passe par CustomSnackbar comme partout ailleurs dans l'app
    // (Get.snackbar brut n'avait ni le style ni la position du reste).
    final err = c.validateStep(step);
    if (err != null) {
      CustomSnackbar.showWarning(
        title: 'error_invalid_details_title'.tr,
        message: err,
      );
      return;
    }
    if (isLast) {
      c.handleWizardSignUp(email: c.emailController.text.trim());
    } else {
      c.currentStep.value = step + 1;
      c.onStepEntered(step + 1);
    }
  }

  // ── widgets utilitaires ─────────────────────────────────────────────────────
  Widget _sectionTitle(String text) => Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Builder(
          builder: (context) => PoppinsText(
            text: text,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(top: 10.h, bottom: 6.h),
        child: Builder(
          builder: (context) => InterText(
            text: text,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
      );

  // v490 — Daniel veut le design ARRONDI pour l'inscription, mais SANS le bug
  // gris v489. Version SÛRE : bordure arrondie 14r + focus couleur du rôle.
  // ⚠️ AUCUN `filled`, AUCUN `context`/`Builder`, AUCUN `Obx(()=>Builder())`
  // (= EXACTEMENT ce qui plantait en release / blocs gris). Le thème gère les
  // couleurs texte/label → dark-mode OK automatiquement.
  InputDecoration _roundedDec(
      {String? label, String? hint, String? suffixText, Widget? suffixIcon}) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: (label == null || label.isEmpty) ? null : label,
      hintText: hint,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      enabledBorder: b(AppColors.greyColor.withValues(alpha: 0.4), 1),
      border: b(AppColors.greyColor.withValues(alpha: 0.4), 1),
      focusedBorder: b(_accent, 1.8),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {String? hint, TextInputType? kb, String? suffix, bool dense = false,
      List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 0 : 6.h),
      child: TextField(
        controller: ctrl,
        keyboardType: kb,
        inputFormatters: formatters,
        decoration: _roundedDec(label: label, hint: hint, suffixText: suffix),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue:
          items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
      isExpanded: true,
      decoration: _roundedDec(),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _radiusDropdown(SignUpController c) {
    const opts = ['5', '10', '15', '20', '25', '30', '50', '100'];
    // v490 — Obx lit `.value` DIRECTEMENT dans sa closure (PAS de Builder
    // enfant) → pas de « improper use of GetX » → pas de bloc gris release.
    return Obx(() => DropdownButtonFormField<String>(
          initialValue: opts.contains(c.coverageRadius.value)
              ? c.coverageRadius.value
              : '20',
          isExpanded: true,
          decoration: _roundedDec(),
          items: opts
              .map((e) => DropdownMenuItem(value: e, child: Text('$e km')))
              .toList(),
          onChanged: (v) => c.coverageRadius.value = v ?? '20',
        ));
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.15) : AppColors.card(context),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: selected ? _accent : AppColors.greyColor.withValues(alpha: 0.4),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _accent : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _checkRow({
    IconData? icon,
    required String title,
    String? sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.08) : AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected ? _accent : AppColors.greyColor.withValues(alpha: 0.3),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20.sp, color: _accent),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: title,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    if (sub != null && sub.isNotEmpty)
                      InterText(
                        text: sub,
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                      ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: selected ? _accent : AppColors.greyColor,
                size: 22.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Builder(
      builder: (context) => Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.greyColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: PoppinsText(
                text: label,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            AppSwitch(value: value, onChanged: onChanged, accent: _accent),
          ],
        ),
      ),
    );
  }

  Widget _daysSelector(SignUpController c) {
    const days = [
      ['mon', 'day_mon'],
      ['tue', 'day_tue'],
      ['wed', 'day_wed'],
      ['thu', 'day_thu'],
      ['fri', 'day_fri'],
      ['sat', 'day_sat'],
      ['sun', 'day_sun'],
    ];
    return Obx(() => Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: days.map((d) {
            final sel = c.availableDays.contains(d[0]);
            return _chip(d[1].tr, sel, () => c.toggleInList(c.availableDays, d[0]));
          }).toList(),
        ));
  }

  Widget _pwRule(String text, bool ok) => Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14.sp, color: ok ? const Color(0xFF16A34A) : AppColors.greyColor),
            SizedBox(width: 6.w),
            InterText(
              text: text,
              fontSize: 11.sp,
              color: ok ? const Color(0xFF16A34A) : AppColors.greyColor,
            ),
          ],
        ),
      );
}

/// Champ mot de passe avec œil afficher/masquer.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final Color accent;
  final ValueChanged<String>? onChanged;
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.accent,
    this.onChanged,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscure,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(
                color: AppColors.greyColor.withValues(alpha: 0.4), width: 1),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(
                color: AppColors.greyColor.withValues(alpha: 0.4), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(color: widget.accent, width: 1.8),
          ),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}
