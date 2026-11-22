// 644 (BOB, 22/11/2026) — « Ajoute ta photo » (gardien / promeneur).
// Mesure du 22/11 : 42 % des gardiens ont une photo, et la page des candidats
// range désormais les profils AVEC photo en premier. Quand un prestataire sans
// photo de profil appuie pour candidater, une petite feuille s'intercale UNE
// fois par demande : « Les propriétaires choisissent d'abord les profils avec
// photo » + « Ajouter ma photo » (le sélecteur de photo de profil existant,
// `ProfileController.pickAndUploadProfilePicture` → PUT /users/me/profile-picture)
// + « Plus tard ». Jamais bloquant : dans tous les cas la candidature part.
// Coupe-circuit : `--dart-define=PHOTO_NUDGE_644=false`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

const bool kPhotoNudge644 = bool.fromEnvironment('PHOTO_NUDGE_644', defaultValue: true);

class PhotoNudge644 {
  PhotoNudge644._();

  /// Réglage effectif (les tests peuvent le forcer).
  static bool enabled = kPhotoNudge644;

  /// Demandes pour lesquelles la feuille a déjà été montrée (mémoire + disque).
  static const String storageKey = 'photo644_asked';
  static const int _maxKept = 200;
  static final Set<String> _asked = <String>{};
  static bool _addedThisSession = false;

  /// Ouvre le sélecteur de photo de profil EXISTANT et envoie la photo.
  /// Remplaçable en test.
  static Future<void> Function() addPhoto = _addPhotoDefault;

  /// Photo de profil connue du serveur (quand rien n'est connu sur le
  /// téléphone) : vrai / faux, ou null si la question n'a pas de réponse
  /// (hors ligne…). Remplaçable en test.
  static Future<bool?> Function() serverHasPhoto = _serverHasPhotoDefault;

  static void resetForTest() {
    enabled = kPhotoNudge644;
    _asked.clear();
    _inFlight = false;
    _addedThisSession = false;
    addPhoto = _addPhotoDefault;
    serverHasPhoto = _serverHasPhotoDefault;
  }

  static String _url(dynamic avatar) =>
      ((avatar is Map ? avatar['url'] : avatar) ?? '').toString().trim();

  /// Le téléphone connaît-il une photo de profil ? (profil persistant, puis
  /// les contrôleurs de profil déjà en mémoire). Pure lecture.
  static bool localHasPhoto() {
    if (_addedThisSession) return true;
    try {
      final raw = GetStorage().read(StorageKeys.userProfile);
      if (raw is Map) {
        if (_url(raw['avatar']).isNotEmpty) return true;
        if ((raw['profileImage'] ?? '').toString().trim().isNotEmpty) return true;
      }
    } catch (_) {/* stockage absent : on regarde les contrôleurs */}
    try {
      if (Get.isRegistered<ProfileController>() &&
          Get.find<ProfileController>().profileImageUrl.value.trim().isNotEmpty) {
        return true;
      }
      if (Get.isRegistered<SitterProfileController>() &&
          Get.find<SitterProfileController>().profileImageUrl.value.trim().isNotEmpty) {
        return true;
      }
    } catch (_) {/* contrôleur indisponible */}
    return false;
  }

  static bool _isProvider() {
    try {
      final r = (GetStorage().read(StorageKeys.userRole) ?? '').toString().toLowerCase();
      return r == 'sitter' || r == 'walker';
    } catch (_) {
      return false;
    }
  }

  static bool _alreadyAsked(String key) {
    if (_asked.contains(key)) return true;
    try {
      final raw = GetStorage().read(storageKey);
      if (raw is List && raw.map((e) => e.toString()).contains(key)) return true;
    } catch (_) {/* rien en mémoire */}
    return false;
  }

  static void _remember(String key) {
    _asked.add(key);
    try {
      final box = GetStorage();
      final raw = box.read(storageKey);
      final list = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
      if (!list.contains(key)) list.add(key);
      final kept = list.length > _maxKept ? list.sublist(list.length - _maxKept) : list;
      unawaited(box.write(storageKey, kept));
    } catch (_) {/* mémoire de session seulement */}
  }

  /// À appeler juste AVANT d'envoyer une candidature. [requestKey] = la demande
  /// (id de l'annonce). Montre la feuille au plus une fois par demande, à un
  /// gardien / promeneur sans photo ; rend toujours la main (jamais bloquant,
  /// aucune exception). Renvoie `true` si la feuille a été montrée.
  static Future<bool> maybeShow(String requestKey, {BuildContext? context}) async {
    // Une feuille (ou sa vérification) déjà en cours : pas de seconde.
    if (_inFlight) return false;
    _inFlight = true;
    try {
      return await _maybeShow(requestKey, context);
    } finally {
      _inFlight = false;
    }
  }

  static bool _inFlight = false;

  static Future<bool> _maybeShow(String requestKey, BuildContext? context) async {
    try {
      if (!enabled || requestKey.trim().isEmpty || !_isProvider()) return false;
      if (_alreadyAsked(requestKey) || localHasPhoto()) return false;
      // Rien sur le téléphone (nouvel appareil, cache vide) : le serveur
      // tranche. Sans réponse, on ne dérange pas.
      final bool? remote = await serverHasPhoto();
      if (remote != false) {
        if (remote == true) _addedThisSession = true;
        return false;
      }
      final BuildContext? ctx = context ?? Get.context;
      if (ctx == null || !ctx.mounted) return false;
      _remember(requestKey);
      final bool? add = await _showSheet(ctx);
      if (add == true) {
        try {
          await addPhoto();
        } catch (e) {
          AppLogger.logError('[photo644] ajout de la photo', error: e);
        }
        if (_controllerHasPhoto()) _addedThisSession = true;
      }
      return true;
    } catch (e) {
      AppLogger.logError('[photo644] feuille « Ajoute ta photo »', error: e);
      return false;
    }
  }

  static bool _controllerHasPhoto() {
    try {
      return Get.isRegistered<ProfileController>() &&
          Get.find<ProfileController>().profileImageUrl.value.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool?> _serverHasPhotoDefault() async {
    try {
      if (!Get.isRegistered<UserRepository>()) return null;
      final data =
          await Get.find<UserRepository>().getMyProfile().timeout(const Duration(seconds: 5));
      final profile = data['profile'] is Map ? data['profile'] as Map : data;
      // Une réponse qui n'est pas un profil (vide, partielle) ne prouve rien.
      final bool isProfile = <String>['id', '_id', 'email', 'name']
          .any((k) => (profile[k] ?? '').toString().trim().isNotEmpty);
      if (!isProfile) return null;
      return _url(profile['avatar']).isNotEmpty ||
          (profile['profileImage'] ?? '').toString().trim().isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _addPhotoDefault() async {
    final ProfileController c = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    await c.pickAndUploadProfilePicture();
    // L'en-tête du profil gardien lit son propre contrôleur : même photo.
    try {
      final url = c.profileImageUrl.value.trim();
      if (url.isNotEmpty && Get.isRegistered<SitterProfileController>()) {
        Get.find<SitterProfileController>().profileImageUrl.value = url;
      }
    } catch (_) {/* affichage seulement */}
  }

  static Future<bool?> _showSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final Color tone = AppColors.activeRoleAccent();
        return Container(
          key: const Key('photo644_sheet'),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
          decoration: BoxDecoration(
            color: AppColors.scaffold(ctx),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h + appBottomInset(ctx)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.divider(ctx),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Container(
                  width: 60.w,
                  height: 60.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_a_photo_rounded,
                      size: 28.sp, color: AppColors.accentOn(ctx, tone)),
                ),
                SizedBox(height: 12.h),
                PoppinsText(
                  text: 'cand644_photo_title'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(ctx),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                InterText(
                  text: 'cand644_photo_body'.tr,
                  fontSize: 14.sp,
                  height: 1.4,
                  color: AppColors.textSecondary(ctx),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18.h),
                ActionPillButton(
                  key: const Key('photo644_add'),
                  label: 'cand644_photo_add'.tr,
                  icon: Icons.add_a_photo_rounded,
                  tone: tone,
                  expand: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
                SizedBox(height: 4.h),
                Semantics(
                  button: true,
                  child: InkWell(
                    key: const Key('photo644_later'),
                    borderRadius: BorderRadius.circular(10.r),
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44, minWidth: 120),
                      child: Center(
                        widthFactor: 1,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                          child: InterText(
                            text: 'cand644_photo_later'.tr,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary(ctx),
                            textDecoration: TextDecoration.underline,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
