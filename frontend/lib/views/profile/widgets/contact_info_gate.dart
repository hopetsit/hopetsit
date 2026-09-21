// v565 — points 1 / 25 : porte de complétion « au bon moment ».
//
// ============================================================================
// API FIGÉE (utilisée par le lot app-home-bookings) — ne pas renommer.
// ============================================================================
//
//   bool profileHasContactInfo(ProfileModel profile)
//     → true si le téléphone ET l'adresse sont renseignés.
//
//   Future<bool> ensureContactInfo(BuildContext context, {required String role})
//     → role ∈ 'owner' | 'sitter' | 'walker'.
//       • Si le profil courant a déjà téléphone + adresse : renvoie true sans
//         rien afficher.
//       • Sinon : ouvre la feuille « Complète tes coordonnées » (indicatif
//         déduit du pays du compte + numéro + adresse + ville), enregistre via
//         PUT /users/me/profile (route « moi-même », 3 rôles), rafraîchit les
//         contrôleurs de profil, puis renvoie true.
//       • Renvoie false si l'utilisateur ferme la feuille sans enregistrer
//         (ou si l'enregistrement échoue).
//
//   Exemple (prestataire qui accepte une réservation) :
//     if (!await ensureContactInfo(context, role: 'sitter')) return;
//     … accepter la réservation …
//
//   Exemple (propriétaire qui envoie une demande) :
//     if (!await ensureContactInfo(context, role: 'owner')) return;
//
// La feuille est autonome : elle charge le profil courant elle-même si aucun
// contrôleur de profil n'est monté.
// ============================================================================
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/profile/widgets/phone_prefix_helper.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/utils/server_error_message.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Vrai si le téléphone ET l'adresse sont renseignés.
bool profileHasContactInfo(ProfileModel profile) => profile.hasContactInfo;

/// Profil courant selon le rôle (contrôleur monté), sinon null.
ProfileModel? _currentProfile(String role) {
  try {
    if (role == 'sitter' && Get.isRegistered<SitterProfileController>()) {
      return Get.find<SitterProfileController>().profile.value;
    }
    if (Get.isRegistered<ProfileController>()) {
      return Get.find<ProfileController>().profile.value;
    }
  } catch (_) {/* défensif */}
  return null;
}

/// Charge le profil « moi » depuis le serveur (best-effort, 3 rôles).
Future<ProfileModel?> _fetchProfile() async {
  try {
    final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
    final r = await api.get('/users/me/profile', requiresAuth: true);
    if (r is Map) {
      final data = (r['profile'] is Map) ? Map<String, dynamic>.from(r['profile']) : Map<String, dynamic>.from(r);
      return ProfileModel.fromJson(data);
    }
  } catch (e) {
    AppLogger.logError('ensureContactInfo: profile fetch failed', error: e);
  }
  return null;
}

/// Rafraîchit les contrôleurs de profil montés après une sauvegarde.
Future<void> _refreshProfileControllers() async {
  try {
    if (Get.isRegistered<ProfileController>()) {
      await Get.find<ProfileController>().loadMyProfile();
    }
  } catch (_) {/* best-effort */}
  try {
    if (Get.isRegistered<SitterProfileController>()) {
      await Get.find<SitterProfileController>().loadMyProfile();
    }
  } catch (_) {/* best-effort */}
}

/// Ouvre la feuille de complétion si téléphone/adresse manquent.
/// Renvoie true quand les coordonnées sont complètes (déjà ou après saisie).
Future<bool> ensureContactInfo(BuildContext context, {required String role}) async {
  final r = role.toLowerCase();
  ProfileModel? profile = _currentProfile(r);
  if (profile != null && profileHasContactInfo(profile)) return true;
  profile ??= await _fetchProfile();
  if (profile != null && profileHasContactInfo(profile)) return true;
  if (!context.mounted) return false;
  final saved = await showContactInfoSheet(context, role: r, profile: profile);
  return saved == true;
}

/// Feuille « Complète tes coordonnées » (utilisable aussi depuis la barre de
/// complétion du profil). Renvoie true si enregistré.
Future<bool?> showContactInfoSheet(
  BuildContext context, {
  required String role,
  ProfileModel? profile,
}) {
  return showProfileSheet<bool>(
    context,
    builder: (ctx) => _ContactInfoSheet(role: role, profile: profile),
  );
}

class _ContactInfoSheet extends StatefulWidget {
  const _ContactInfoSheet({required this.role, required this.profile});
  final String role;
  final ProfileModel? profile;

  @override
  State<_ContactInfoSheet> createState() => _ContactInfoSheetState();
}

class _ContactInfoSheetState extends State<_ContactInfoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  String _dial = '';
  String _iso = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _iso = (p?.country ?? '').isNotEmpty
        ? p!.country
        : (PhonePrefix.isoForDial(p?.countryCode).isNotEmpty
            ? PhonePrefix.isoForDial(p?.countryCode)
            : PhonePrefix.deviceIso());
    _dial = PhonePrefix.resolveDial(
      storedCode: p?.countryCode,
      countryIso: _iso,
      rawMobile: p?.mobile,
    );
    _phone.text = PhonePrefix.nationalNumber(p?.mobile ?? '', _dial);
    _address.text = p?.address ?? '';
    _city.text = p?.city ?? '';
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
      final national = PhonePrefix.nationalNumber(_phone.text, _dial);
      final payload = <String, dynamic>{
        'mobile': national,
        'countryCode': _dial,
        'address': _address.text.trim(),
      };
      final city = _city.text.trim();
      final p = widget.profile;
      if (city.isNotEmpty) {
        // v575 — la ville PLATE est envoyée en plus de `location` : sans GPS,
        // le serveur ne pouvait la déduire que du chemin de secours, et
        // l'élément « Ville » de la complétion restait rouge.
        payload['city'] = city;
        payload['location'] = {
          if (p?.latitude != null && p?.longitude != null) ...{
            'lat': p!.latitude,
            'lng': p.longitude,
          },
          'city': city,
        };
      }
      await api.put('/users/me/profile', body: payload, requiresAuth: true);
      try {
        final box = GetStorage();
        final raw = box.read(StorageKeys.userProfile);
        final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        map['mobile'] = national;
        map['countryCode'] = _dial;
        map['address'] = _address.text.trim();
        await box.write(StorageKeys.userProfile, map);
      } catch (_) {/* best-effort */}
      await _refreshProfileControllers();
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'contact_gate_saved'.tr,
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      AppLogger.logError('ensureContactInfo save failed', error: e.message);
      if (mounted) {
        // v576 — jamais le texte serveur brut (anglais) dans le bandeau.
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: errorKeyFor(e, fallbackKey: 'profile_update_failed'),
        );
      }
    } catch (e) {
      AppLogger.logError('ensureContactInfo save failed', error: e);
      if (mounted) {
        CustomSnackbar.showError(title: 'common_error'.tr, message: 'profile_update_failed'.tr);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = profileAccentFor(widget.role);
    final isProvider = widget.role != 'owner';
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProfileSheetHandle(),
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(Icons.contact_phone_rounded, color: accent, size: 22.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: 'contact_gate_title'.tr,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        InterText(
                          text: isProvider ? 'contact_gate_body_provider'.tr : 'contact_gate_body_owner'.tr,
                          fontSize: 12.sp,
                          color: AppColors.textSecondary(context),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              InterText(
                text: 'label_mobile_number'.tr,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 6.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: AppColors.divider(context)),
                    ),
                    child: CountryCodePicker(
                      onChanged: (cc) {
                        setState(() {
                          _dial = cc.dialCode ?? _dial;
                          _iso = cc.code ?? _iso;
                        });
                      },
                      initialSelection: _iso.isNotEmpty ? _iso : _dial,
                      favorite: const ['FR', 'US', 'BE', 'CH', 'ES'],
                      showFlagDialog: true,
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      textStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: ProfileInput(
                      label: '',
                      hint: 'hint_phone'.tr,
                      controller: _phone,
                      accent: accent,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      enabled: !_saving,
                      validator: (v) {
                        final n = PhonePrefix.nationalNumber(v ?? '', _dial);
                        if (n.isEmpty) return 'error_phone_required'.tr;
                        final full = _dial.replaceAll(RegExp(r'\D'), '') + n.replaceAll(RegExp(r'\D'), '');
                        if (!RegExp(r'^\d{7,15}$').hasMatch(full)) return 'error_phone_invalid'.tr;
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              ProfileInput(
                label: 'label_address'.tr,
                hint: 'hint_address'.tr,
                controller: _address,
                accent: accent,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v ?? '').trim().length < 2 ? 'error_address_required'.tr : null,
              ),
              SizedBox(height: 14.h),
              ProfileInput(
                label: 'label_city'.tr,
                hint: 'signup_field_city'.tr,
                controller: _city,
                accent: accent,
                textInputAction: TextInputAction.done,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().isEmpty ? 'signup_error_city_required'.tr : null,
              ),
              SizedBox(height: 8.h),
              InterText(
                text: 'contact_gate_privacy'.tr,
                fontSize: 11.5.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
                height: 1.35,
              ),
              SizedBox(height: 16.h),
              ProfilePrimaryButton(
                label: 'contact_gate_save'.tr,
                accent: accent,
                loading: _saving,
                onTap: _saving ? null : _save,
                icon: Icons.check_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
