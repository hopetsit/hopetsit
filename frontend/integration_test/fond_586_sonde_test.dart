// v586 — point 4 : « Mon fond (auto / pattes / aucun) ne marche pas ».
// Parcours connecté (compte de test) : Profil › Préférences → VRAI toucher sur
// chaque choix → capture de la page elle-même, puis de l'Accueil (onglet déjà
// monté derrière). Journal : valeur locale, valeur du compte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/preferences_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_host.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  b.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(sondeSetUp);

  testWidgets('586 fond ($kRole)', (t) async {
    await loginAndEnter(t);
    await openTab(t, 0);
    await shot(t, 'fond_00_accueil_depart');
    final ProfileSettingsHost host = kRole == 'sitter'
        ? (Get.isRegistered<SitterProfileController>()
            ? Get.find<SitterProfileController>()
            : Get.put(SitterProfileController()))
        : (Get.isRegistered<ProfileController>()
            ? Get.find<ProfileController>()
            : Get.put(ProfileController()));
    await host.loadMyProfile();
    final start = host.profile.value?.preferences.wallpaper ?? '?';
    say('depart : local=${PawWallpaperPrefs.mode()} compte=$start');
    for (final mode in ['none', 'paws', 'auto']) {
      Get.to(() => ProfilePreferencesScreen(host: host, accent: AppColors.activeRoleAccent()));
      await hold(t, 2500);
      final pill = find.text('pref_wallpaper_$mode'.tr);
      await t.scrollUntilVisible(pill, 200, scrollable: find.byType(Scrollable).first);
      await hold(t, 800);
      await realTap(t, pill, why: 'choix $mode');
      await hold(t, 3000);
      await shot(t, 'fond_${mode}_1_preferences');
      await host.loadMyProfile();
      say('apres $mode : local=${PawWallpaperPrefs.mode()} compte=${host.profile.value?.preferences.wallpaper}');
      ok('choix $mode ecrit en local', PawWallpaperPrefs.mode() == mode);
      ok('choix $mode relu du compte', host.profile.value?.preferences.wallpaper == mode);
      Get.back();
      await hold(t, 2000);
      await openTab(t, 0);
      await shot(t, 'fond_${mode}_2_accueil');
    }
    await sondeTearDown(t);
  });
}
