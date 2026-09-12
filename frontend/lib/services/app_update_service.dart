import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// v561 — Daniel : « que l'app se mette à jour seule sur iOS et Android ».
///
/// Lit `GET /app-version` (latest / minimum par plateforme, réglés dans
/// l'admin) et compare au build installé :
///   - Android : API Google Play « In-App Updates » — sous le minimum →
///     mise à jour IMMÉDIATE (écran plein, l'app redémarre à jour) ; sinon
///     si une version plus récente existe → mise à jour SOUPLE (téléchargée
///     en arrière-plan, installée au prochain redémarrage) ;
///   - iOS : Apple n'autorise pas l'installation depuis l'app → sous le
///     minimum, écran bloquant avec bouton App Store ; sinon feuille
///     « Nouvelle version disponible » (une fois par version, refusable).
/// Appelé une fois par lancement, après le montage du menu principal.
class AppUpdateService {
  AppUpdateService._();
  static bool _checked = false;

  static Future<void> checkOnce() async {
    if (_checked || kIsWeb) return;
    _checked = true;
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber) ?? 0;
      if (installed <= 0) return;
      final res = await Get.find<ApiClient>().get('/app-version');
      if (res is! Map) return;
      final plat = Platform.isIOS ? res['ios'] : res['android'];
      if (plat is! Map) return;
      final latest = _int(plat['latest']);
      final minimum = _int(plat['minimum']);
      final url = (plat['url'] ?? '').toString();
      final message = (plat['message'] ?? '').toString();
      final forced = minimum > 0 && installed < minimum;
      final available = latest > 0 && installed < latest;
      if (!forced && !available) return;
      AppLogger.logInfo(
        'AppUpdate: installed=$installed latest=$latest minimum=$minimum forced=$forced',
      );
      if (Platform.isAndroid) {
        await _android(forced: forced, latest: latest, url: url, message: message);
      } else {
        await _ios(forced: forced, latest: latest, url: url, message: message);
      }
    } catch (e) {
      AppLogger.logError('AppUpdateService.checkOnce failed', error: e);
    }
  }

  static int _int(dynamic v) => int.tryParse((v ?? '').toString()) ?? 0;

  static Future<void> _android({
    required bool forced,
    required int latest,
    required String url,
    required String message,
  }) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (forced && info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
        if (info.flexibleUpdateAllowed) {
          final r = await InAppUpdate.startFlexibleUpdate();
          if (r == AppUpdateResult.success) {
            // Installée au prochain redémarrage ; on propose de relancer
            // tout de suite si l'utilisateur le veut.
            await InAppUpdate.completeFlexibleUpdate();
          }
          return;
        }
      }
    } catch (e) {
      // Play absent (APK hors store, émulateur) → repli sur la feuille store.
      AppLogger.logWarning('InAppUpdate indisponible : $e');
    }
    await _showSheet(forced: forced, latest: latest, url: url, message: message);
  }

  static Future<void> _ios({
    required bool forced,
    required int latest,
    required String url,
    required String message,
  }) =>
      _showSheet(forced: forced, latest: latest, url: url, message: message);

  static Future<void> _showSheet({
    required bool forced,
    required int latest,
    required String url,
    required String message,
  }) async {
    final box = GetStorage();
    final dismissKey = 'app_update_dismissed_$latest';
    if (!forced) {
      try {
        if (box.read(dismissKey) == true) return;
      } catch (_) {/* noop */}
    }
    final ctx = Get.context;
    if (ctx == null) return;
    final storeUrl = url.isNotEmpty
        ? url
        : (Platform.isIOS
            ? 'https://apps.apple.com/app/id6763645719'
            : 'https://play.google.com/store/apps/details?id=com.cardellihermanos.hopetsit');
    await showModalBottomSheet<void>(
      context: ctx,
      isDismissible: !forced,
      enableDrag: !forced,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => PopScope(
        canPop: !forced,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: AppColors.card(sheetCtx),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0x1AD83C28),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Color(0xFFD83C28), size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                (forced ? 'update_required_title' : 'update_available_title').tr,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message.isNotEmpty
                    ? message
                    : (forced ? 'update_required_body' : 'update_available_body').tr,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary(sheetCtx),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD83C28),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final u = Uri.parse(storeUrl);
                    try {
                      await launchUrl(u, mode: LaunchMode.externalApplication);
                    } catch (_) {/* noop */}
                  },
                  icon: Icon(Platform.isIOS
                      ? Icons.apple
                      : Icons.shop_rounded),
                  label: Text('update_btn_store'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              if (!forced) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    try {
                      box.write(dismissKey, true);
                    } catch (_) {/* noop */}
                    Navigator.of(sheetCtx).pop();
                  },
                  child: Text('update_btn_later'.tr),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
