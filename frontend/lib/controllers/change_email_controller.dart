// v565 — point 2 / docs/v565_contracts.md §3 : changement d'e-mail par
// l'utilisateur.
//   POST /users/me/email-change          { newEmail, password } → { ok }
//   POST /users/me/email-change/confirm  { code }               → { ok, email }
//   POST /users/me/email-change/resend                          → { ok }
// Après succès : profil local + GetStorage(userProfile) mis à jour, puis les
// contrôleurs de profil rechargent depuis le serveur.
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';

enum ChangeEmailStep { form, code, done }

class ChangeEmailController extends GetxController {
  ChangeEmailController({ApiClient? api, GetStorage? storage})
      : _api = api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient()),
        _storage = storage ?? GetStorage();

  static const String _base = '/users/me/email-change';

  final ApiClient _api;
  final GetStorage _storage;

  final Rx<ChangeEmailStep> step = ChangeEmailStep.form.obs;
  final RxBool busy = false.obs;
  final RxBool resending = false.obs;
  final RxString error = ''.obs;
  final RxString pendingEmail = ''.obs;
  final RxString confirmedEmail = ''.obs;
  final RxInt resendCooldown = 0.obs;

  static final RegExp _emailRe = RegExp(r'^[\w+.-]+@([\w-]+\.)+[\w-]{2,}$');

  /// Étape 1 : demande le changement (envoie le code à la NOUVELLE adresse).
  Future<bool> request({required String newEmail, required String password}) async {
    final email = newEmail.trim().toLowerCase();
    error.value = '';
    if (!_emailRe.hasMatch(email)) {
      error.value = 'error_email_invalid'.tr;
      return false;
    }
    if (password.isEmpty) {
      error.value = 'error_password_required'.tr;
      return false;
    }
    busy.value = true;
    try {
      await _api.post(_base, body: {'newEmail': email, 'password': password}, requiresAuth: true);
      pendingEmail.value = email;
      step.value = ChangeEmailStep.code;
      _startCooldown();
      return true;
    } catch (e) {
      error.value = _messageFor(e, stage: 'request');
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Étape 2 : confirme avec le code à 6 chiffres.
  Future<bool> confirm(String code) async {
    final c = code.trim();
    error.value = '';
    if (!RegExp(r'^\d{6}$').hasMatch(c)) {
      error.value = 'change_email_code_invalid'.tr;
      return false;
    }
    busy.value = true;
    try {
      final r = await _api.post('$_base/confirm', body: {'code': c}, requiresAuth: true);
      final email = (r is Map ? (r['email'] ?? '') : '').toString().trim();
      confirmedEmail.value = email.isNotEmpty ? email : pendingEmail.value;
      await _applyLocally(confirmedEmail.value);
      step.value = ChangeEmailStep.done;
      return true;
    } catch (e) {
      error.value = _messageFor(e, stage: 'confirm');
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Renvoie le code (le serveur limite à 1 / 2 min).
  Future<void> resend() async {
    if (resending.value || resendCooldown.value > 0) return;
    resending.value = true;
    error.value = '';
    try {
      await _api.post('$_base/resend', requiresAuth: true);
      _startCooldown();
    } catch (e) {
      error.value = _messageFor(e, stage: 'resend');
    } finally {
      resending.value = false;
    }
  }

  void _startCooldown() {
    resendCooldown.value = 120;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (isClosed) return false;
      if (resendCooldown.value <= 0) return false;
      resendCooldown.value = resendCooldown.value - 1;
      return resendCooldown.value > 0;
    });
  }

  /// Met à jour le cache local et rafraîchit les contrôleurs de profil.
  Future<void> _applyLocally(String email) async {
    if (email.isEmpty) return;
    try {
      final raw = _storage.read(StorageKeys.userProfile);
      final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      map['email'] = email;
      await _storage.write(StorageKeys.userProfile, map);
    } catch (e) {
      AppLogger.logError('ChangeEmail: local cache update failed', error: e);
    }
    try {
      if (Get.isRegistered<ProfileController>()) {
        final pc = Get.find<ProfileController>();
        pc.email.value = email;
        await pc.loadMyProfile();
      }
    } catch (_) {/* best-effort */}
    try {
      if (Get.isRegistered<SitterProfileController>()) {
        final sc = Get.find<SitterProfileController>();
        sc.email.value = email;
        await sc.loadMyProfile();
      }
    } catch (_) {/* best-effort */}
  }

  String _messageFor(Object e, {required String stage}) {
    AppLogger.logError('ChangeEmail $stage failed', error: e);
    if (e is ApiException) {
      switch (e.statusCode) {
        case 401:
          return 'change_email_wrong_password'.tr;
        case 409:
          return 'signup_error_email_taken'.tr;
        case 429:
          return 'change_email_too_many'.tr;
        case 400:
          if (stage == 'confirm') return 'change_email_code_invalid'.tr;
          return e.message.trim().isNotEmpty ? e.message : 'error_email_invalid'.tr;
        default:
          return 'common_error_generic'.tr;
      }
    }
    if (e is NetworkUnreachableException || e is ApiTimeoutException) {
      return 'common_error_no_network'.tr;
    }
    return 'common_error_generic'.tr;
  }
}
