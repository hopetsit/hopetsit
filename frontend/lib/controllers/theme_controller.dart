import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Sprint 6 step 1 — global theme controller.
/// Persists the user's preference ('light' | 'dark' | 'system') via GetStorage.
class ThemeController extends GetxController {
  static const String _storageKey = 'theme_mode';
  final GetStorage _storage = GetStorage();

  // Default to LIGHT so the app never accidentally renders in dark mode
  // just because the user's OS is set to dark (reported bug: dark mode
  // bleeding through on the availability calendar, dialogs, etc.).
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _storage.read<String>(_storageKey);
    themeMode.value = _decode(saved);
  }

  ThemeMode _decode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      // ignore: unreachable_switch_default
      default:
        return ThemeMode.light;
    }
  }

  String _encode(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _storage.write(_storageKey, _encode(mode));
    Get.changeThemeMode(mode);
  }

  Future<void> toggleTheme() async {
    final next = themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setMode(next);
  }
}
