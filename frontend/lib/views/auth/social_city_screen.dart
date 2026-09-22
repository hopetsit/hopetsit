import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

/// v565 audit-inscription — dernière étape d'une inscription Google / Apple.
///
/// Un NOUVEL utilisateur social reçoit 400 ROLE_REQUIRED → il choisit son
/// rôle (SignUpAs) → on lui demande ici sa VILLE (obligatoire, décision
/// point 25 ; téléphone et adresse restent facultatifs et sont demandés au
/// moment utile), puis on relance le fournisseur avec `role` + `user`
/// (ville, coordonnées, pays, langue) : le serveur crée le compte vérifié.
class SocialCityScreen extends StatefulWidget {
  final String provider; // 'google' | 'apple'
  final String userType; // 'pet_owner' | 'pet_sitter' | 'pet_walker'

  const SocialCityScreen({
    super.key,
    required this.provider,
    required this.userType,
  });

  @override
  State<SocialCityScreen> createState() => _SocialCityScreenState();
}

class _SocialCityScreenState extends State<SocialCityScreen> {
  final TextEditingController _cityController = TextEditingController();
  final LocationService _locationService = LocationService();
  bool _gettingLocation = false;
  bool _submitting = false;
  String _detectedCity = '';
  double? _lat;
  double? _lng;
  String _country = '';

  String get _apiRole => widget.userType == 'pet_walker'
      ? 'walker'
      : widget.userType == 'pet_sitter'
          ? 'sitter'
          : 'owner';

  Color get _accent => widget.userType == 'pet_sitter'
      ? AppColors.sitterAccent
      : widget.userType == 'pet_walker'
          ? AppColors.greenColor
          : AppColors.primaryColor;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    if (_gettingLocation) return;
    setState(() => _gettingLocation = true);
    try {
      final data = await _locationService.getUserLocationWithCity();
      if (!mounted) return;
      if (data != null) {
        final city = (data['city'] as String? ?? '').trim();
        setState(() {
          _lat = data['latitude'] as double?;
          _lng = data['longitude'] as double?;
          _detectedCity = city;
          final iso = (data['countryCodeIso'] as String?)?.toUpperCase() ?? '';
          if (RegExp(r'^[A-Z]{2}$').hasMatch(iso)) _country = iso;
          if (city.isNotEmpty) _cityController.text = city;
        });
      } else {
        // v573 — BUG : les deux clés étaient passées BRUTES (sans `.tr`),
        // donc l'utilisateur lisait « snackbar_text_location_not_found ».
        // On passe au passage sur les messages `location573_*`, qui disent
        // POURQUOI la localisation a échoué au lieu d'un message unique.
        CustomSnackbar.showWarning(
          title: 'location573_title'.tr,
          message: _locationFailureMessage(),
        );
      }
    } catch (_) {
      if (mounted) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'map_load_error'.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  /// Message adapté à la raison du dernier échec de `LocationService`
  /// ('service_off' | 'denied' | 'denied_forever' | autre).
  String _locationFailureMessage() {
    switch (_locationService.lastFailure) {
      case 'service_off':
        return 'location573_service_off'.tr;
      case 'denied':
        return 'location573_denied'.tr;
      case 'denied_forever':
        return 'location573_denied_forever'.tr;
      default:
        return 'location573_not_found'.tr;
    }
  }

  Future<void> _continue() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'signup_error_city_required'.tr,
      );
      return;
    }
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    setState(() => _submitting = true);
    try {
      if (widget.provider == 'apple') {
        await auth.loginWithApple(
          role: _apiRole,
          city: city,
          lat: _lat,
          lng: _lng,
          country: _country,
        );
      } else {
        await auth.loginWithGoogle(
          role: _apiRole,
          city: city,
          lat: _lat,
          lng: _lng,
          country: _country,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accentOn(context, _accent);
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: PawPatternBackground(
          color: AppColors.activeRoleAccent(),
          child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BackButton(color: AppColors.textPrimary(context)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8.h),
                    // v573 — icône de section dans un rond teinté, comme
                    // partout ailleurs dans l'app depuis la v569.
                    Container(
                      width: 64.w,
                      height: 64.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_rounded,
                          color: accent, size: 32.sp),
                    ),
                    SizedBox(height: 18.h),
                    PoppinsText(
                      text: 'social_city_title'.tr,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      maxLines: 3,
                    ),
                    SizedBox(height: 6.h),
                    InterText(
                      text: 'social_city_sub'.tr,
                      fontSize: 13.5.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 4,
                    ),
                    SizedBox(height: 20.h),
                    // Carte du nouveau design : coins 20, surface du thème,
                    // bord `divider`, ombre douce (nulle en sombre).
                    Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.divider(context)
                              .withValues(alpha: 0.8),
                          width: 1,
                        ),
                        boxShadow: AppColors.cardShadow(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CityLocationPicker(
                            cityController: _cityController,
                            onGetLocation: _detectLocation,
                            isGettingLocation: _gettingLocation,
                            detectedCity: _detectedCity,
                            onLocationSelected: (city, latitude, longitude) {
                              setState(() {
                                _lat = latitude;
                                _lng = longitude;
                                _detectedCity = city;
                              });
                            },
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 14.sp,
                                  color: AppColors.textSecondary(context)),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: InterText(
                                  text: 'social_city_optional_hint'.tr,
                                  fontSize: 12.sp,
                                  color: AppColors.textSecondary(context),
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
            Padding(
              // v569 — complément du SafeArea (0 sur le Samsung de Daniel).
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w,
                  24.h + appBottomInsetInsideSafeArea(context)),
              child: CustomButton(
                // Fond plein : la couleur BRUTE du rôle (le texte est blanc
                // dessus). `accentOn` ne sert qu'au texte et aux icônes.
                bgColor: _accent,
                radius: 16.r,
                height: 52.h,
                onTap: _submitting ? null : _continue,
                child: _submitting
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : InterText(
                        text: 'social_city_continue'.tr,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        maxLines: 1,
                      ),
              ),
            ),
          ],
        ),
      ),
        ),
    );
  }
}
