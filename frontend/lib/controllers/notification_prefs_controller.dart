// v565 — point 19 / docs/v565_contracts.md §2 : préférences de notification.
//
//   GET   /users/me/notification-prefs  → { sound, categories: {…} }
//   PATCH /users/me/notification-prefs  (corps partiel) → objet complet
//
// Sauvegarde OPTIMISTE à chaque changement + rollback si le serveur refuse.
// Aperçu des sons via `audioplayers` sur `assets/sounds/<nom>.m4a`.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class NotificationPrefsController extends GetxController {
  NotificationPrefsController({ApiClient? api, GetStorage? storage})
      : _api = api ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient()),
        _storage = storage ?? GetStorage();

  static const String endpoint = '/users/me/notification-prefs';

  /// Catégories (ordre d'affichage) — clés FIGÉES par le contrat §2.
  static const List<String> categoryKeys = <String>[
    'messages',
    'bookings',
    'payments',
    'friends',
    'pawmap',
    'live',
    'reviews',
    'subscriptions',
  ];

  /// Sons disponibles — valeurs FIGÉES par le contrat §2.
  static const List<String> sounds = <String>[
    'default',
    'bark',
    'meow',
    'tweet',
    'vibrate',
    'silent',
  ];

  final ApiClient _api;
  final GetStorage _storage;
  final AudioPlayer _player = AudioPlayer();

  final RxBool loading = false.obs;
  final RxBool saving = false.obs;
  final RxString error = ''.obs;
  final RxString sound = 'default'.obs;
  final RxMap<String, bool> categories = <String, bool>{
    for (final k in categoryKeys) k: true,
  }.obs;
  final RxString previewing = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _applyCache();
    load();
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }

  void _applyCache() {
    try {
      final raw = _storage.read(StorageKeys.notificationPrefsCache);
      if (raw is Map) _applyJson(Map<String, dynamic>.from(raw));
    } catch (_) {/* cache facultatif */}
  }

  void _applyJson(Map<String, dynamic> json) {
    final s = (json['sound'] ?? '').toString();
    if (sounds.contains(s)) sound.value = s;
    final cats = json['categories'];
    if (cats is Map) {
      for (final k in categoryKeys) {
        final v = cats[k];
        if (v is bool) categories[k] = v;
      }
    }
    try {
      _storage.write(StorageKeys.notificationPrefsCache, {
        'sound': sound.value,
        'categories': Map<String, bool>.from(categories),
      });
    } catch (_) {/* best-effort */}
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    try {
      final r = await _api.get(endpoint, requiresAuth: true);
      if (r is Map) _applyJson(Map<String, dynamic>.from(r));
    } catch (e) {
      AppLogger.logError('notification-prefs load failed', error: e);
      error.value = 'notif_prefs_load_error'.tr;
    } finally {
      loading.value = false;
    }
  }

  Future<void> _patch(Map<String, dynamic> body, void Function() rollback) async {
    saving.value = true;
    try {
      final r = await _api.patch(endpoint, body: body, requiresAuth: true);
      if (r is Map) _applyJson(Map<String, dynamic>.from(r));
    } catch (e) {
      AppLogger.logError('notification-prefs patch failed', error: e);
      rollback();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'notif_prefs_save_error'.tr,
      );
    } finally {
      saving.value = false;
    }
  }

  /// Active / désactive une catégorie (optimiste + rollback).
  Future<void> setCategory(String key, bool enabled) async {
    final previous = categories[key] ?? true;
    if (previous == enabled) return;
    categories[key] = enabled;
    await _patch({'categories': {key: enabled}}, () => categories[key] = previous);
  }

  /// Change le son (optimiste + rollback) et le fait entendre.
  Future<void> setSound(String value) async {
    if (!sounds.contains(value)) return;
    final previous = sound.value;
    if (previous == value) {
      await preview(value);
      return;
    }
    sound.value = value;
    await preview(value);
    await _patch({'sound': value}, () => sound.value = previous);
  }

  /// Aperçu : bark/meow/tweet = fichier m4a ; vibrate = vibration ;
  /// default = son système court ; silent = rien.
  Future<void> preview(String value) async {
    previewing.value = value;
    try {
      switch (value) {
        case 'bark':
        case 'meow':
        case 'tweet':
          await _player.stop();
          await _player.play(AssetSource('sounds/$value.m4a'));
          break;
        case 'vibrate':
          await HapticFeedback.vibrate();
          break;
        case 'default':
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.lightImpact();
          break;
        default:
          break;
      }
    } catch (e) {
      AppLogger.logError('sound preview failed', error: e);
    } finally {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (previewing.value == value) previewing.value = '';
      });
    }
  }
}
