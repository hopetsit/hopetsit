import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// v565 audit-inscription — photo choisie pendant l'inscription.
///
/// Le wizard n'a pas encore de jeton au moment du choix : il mémorise le
/// chemin du fichier (`pendingSignupPhotoPath`) et l'upload se fait dès qu'un
/// jeton existe. AVANT, seul l'écran de code OTP faisait cet upload ; or
/// depuis v535 l'inscription entre DIRECTEMENT dans l'app (auto-login) sans
/// passer par l'OTP → la photo restait sur le téléphone et n'apparaissait
/// jamais dans le profil. Appelé maintenant depuis les deux chemins.
///
/// Best-effort : ne lève jamais. Retourne l'URL de l'avatar posé, sinon null.
Future<String?> uploadPendingSignupPhotoIfAny() async {
  final storage = GetStorage();
  try {
    final path =
        (storage.read(StorageKeys.pendingSignupPhotoPath) ?? '').toString().trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) {
      await storage.remove(StorageKeys.pendingSignupPhotoPath);
      return null;
    }
    final UserRepository repo = Get.isRegistered<UserRepository>()
        ? Get.find<UserRepository>()
        : UserRepository(Get.find());
    final result = await repo.updateProfilePicture(file);
    await storage.remove(StorageKeys.pendingSignupPhotoPath);
    String avatarUrl = '';
    try {
      avatarUrl = (result['avatar'] is Map)
          ? (result['avatar']['url'] ?? '').toString()
          : '';
      if (avatarUrl.isNotEmpty) {
        final prof = storage.read<Map>(StorageKeys.userProfile);
        if (prof != null) {
          final updated = Map<String, dynamic>.from(prof);
          updated['avatar'] = {'url': avatarUrl};
          await storage.write(StorageKeys.userProfile, updated);
        }
      }
    } catch (_) {/* non-fatal */}
    AppLogger.logInfo('[signup] post-signup profile photo uploaded OK');
    return avatarUrl.isEmpty ? null : avatarUrl;
  } catch (e) {
    AppLogger.logError(
      '[signup] failed to upload post-signup profile photo (will retry next session)',
      error: e,
    );
    // La clé reste en place : nouvel essai à la prochaine session.
    return null;
  }
}
