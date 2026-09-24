// v585 (lot D) — Profil › Aide des 3 rôles (demandes de Daniel du 25/09) :
//   (a) « Comprendre la PawMap » EN TÊTE de l'aide, ouvre `PawMapHelpScreen` ;
//   (b) « Tester les notifications » GARDÉ, relégué tout en bas (« Dépannage ») ;
//   (c) « Une idée ? Un problème ? » : choix idée / problème, texte libre,
//       envoi en un appui → `POST /bug-reports` avec `kind`, merci après envoi.
// Plus « Mon fond » (Préférences) : 3 choix, enregistrés sur le compte ET en
// local, et le papier peint qui suit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/profile_model.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/notifications/notification_test_screen.dart';
import 'package:hopetsit/views/profile/idea_box_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_host.dart';
import 'package:hopetsit/views/profile/widgets/profile_settings_tabs.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

import 'lotd_harness.dart';

class _FakeHost implements ProfileSettingsHost {
  @override
  final Rxn<ProfileModel> profile = Rxn<ProfileModel>();
  @override
  final RxBool prefsSaving = false.obs;
  final List<Map<String, dynamic>> saved = <Map<String, dynamic>>[];
  int languageDialogs = 0;
  int changePassword = 0;
  int blocked = 0;
  int deleteDialogs = 0;
  @override
  Future<void> loadMyProfile() async {}
  @override
  void navigateToBlockedUsers() => blocked++;
  @override
  void navigateToChangePassword() => changePassword++;
  @override
  Future<void> savePreferences(Map<String, dynamic> prefsJson) async => saved.add(prefsJson);
  @override
  Future<void> setTwoFactor(bool enabled) async {}
  @override
  void showDeleteAccountDialog(BuildContext context) => deleteDialogs++;
  @override
  void showLanguageDialog() => languageDialogs++;
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'walker');
    PawWallpaperPrefs.debugMode = null;
    PawWallpaperPrefs.debugSpecies = null;
    PawWallpaperPrefs.debugRole = null;
  });

  Widget categories(_FakeHost host, String role) => lotdApp(Scaffold(
        body: SingleChildScrollView(
          child: ProfileCategories(
            role: role,
            accent: const Color(0xFF16A34A),
            host: host,
            onEditProfile: () {},
          ),
        ),
      ));

  testWidgets('Aide : « Comprendre la PawMap » en tête, ouvre PawMapHelpScreen', (tester) async {
    lotdPhone(tester);
    final host = _FakeHost();
    await tester.pumpWidget(categories(host, 'walker'));
    await lotdSettle(tester);
    expect(tester.takeException(), isNull);

    // Les rangées de l'aide, dans l'ordre d'affichage.
    final helpTitle = find.text('AIDE');
    expect(helpTitle, findsOneWidget);
    final rows = find.byType(ProfileRow);
    final List<String> titles = rows.evaluate().map((e) => (e.widget as ProfileRow).title).toList();
    final int iHelp = titles.indexOf('Comprendre la PawMap');
    expect(iHelp, greaterThanOrEqualTo(0));
    expect(titles[iHelp + 1], 'Une idée ? Un problème ?');
    // « Tester mes notifications » n'est PLUS une rangée de l'aide…
    expect(titles.where((t) => t.toLowerCase().contains('notification') && t.toLowerCase().contains('test')), isEmpty);
    // …mais vit tout en bas, dans la petite ligne « Dépannage ».
    final trouble = find.byKey(const ValueKey<String>('help_troubleshoot_row'));
    await tester.scrollUntilVisible(trouble, 300, scrollable: find.byType(Scrollable).first);
    expect(trouble, findsOneWidget);
    expect(find.textContaining('Dépannage'), findsOneWidget);
    final Offset troubleY = tester.getTopLeft(trouble);
    final Offset helpY = tester.getTopLeft(find.text('Comprendre la PawMap'));
    expect(troubleY.dy, greaterThan(helpY.dy), reason: 'le dépannage est sous l\'aide');

    // Tap « Comprendre la PawMap » → l'écran d'aide du lot C.
    await tester.tap(find.text('Comprendre la PawMap'));
    await lotdSettle(tester);
    expect(find.byType(PawMapHelpScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    Get.back();
    await lotdSettle(tester);

    // Tap « Dépannage » → l'écran de test des notifications (gardé).
    await tester.tap(trouble);
    await lotdSettle(tester);
    expect(find.byType(NotificationTestScreen), findsOneWidget);
  });

  testWidgets('Boîte à idées : idée / problème, envoi en un appui avec kind, merci', (tester) async {
    lotdPhone(tester);
    await tester.pumpWidget(lotdApp(const IdeaBoxScreen()));
    await lotdSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Une idée ? Un problème ?'), findsOneWidget);
    expect(find.text('Une idée'), findsWidgets);
    expect(find.text('Un problème'), findsWidgets);

    // Bouton désactivé tant que le texte est trop court ; message si on appuie.
    final send = find.widgetWithText(PawButton, 'Envoyer');
    expect(send, findsOneWidget);
    await tester.tap(send);
    await lotdSettle(tester);
    expect(find.text('Écris au moins 3 caractères.'), findsOneWidget);
    expect(lotdRequests, isEmpty);
    // La bannière disparaît (4 s) avant le prochain appui, sinon elle le couvre.
    await tester.pump(const Duration(seconds: 5));

    // Une idée : 3 caractères suffisent.
    await tester.enterText(find.byType(TextField).first, 'Widget iOS');
    await lotdSettle(tester);
    await tester.tap(send);
    await lotdSettle(tester, frames: 8);
    expect(lotdRequests.where((r) => r.path.endsWith('/bug-reports')).length, 1);
    final req = lotdRequests.firstWhere((r) => r.path.endsWith('/bug-reports'));
    expect(req.method, 'POST');
    expect(req.body!['kind'], 'idea');
    expect(req.body!['description'], 'Widget iOS');
    expect(req.body!['screen'], 'app:profile_help');
    expect(find.text('Merci, on lit tout.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Boîte à idées : un problème exige 10 caractères et part avec kind problem', (tester) async {
    lotdPhone(tester);
    await tester.pumpWidget(lotdApp(const IdeaBoxScreen()));
    await lotdSettle(tester);
    await tester.tap(find.widgetWithText(PawChoicePill, 'Un problème'));
    await lotdSettle(tester);
    await tester.enterText(find.byType(TextField).first, 'Court');
    await lotdSettle(tester);
    await tester.tap(find.widgetWithText(PawButton, 'Envoyer'));
    await lotdSettle(tester);
    expect(find.text('Décris le problème en 10 caractères au moins.'), findsOneWidget);
    expect(lotdRequests, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.enterText(find.byType(TextField).first, 'Le bouton Payer ne répond pas');
    await lotdSettle(tester);
    await tester.tap(find.widgetWithText(PawButton, 'Envoyer'));
    await lotdSettle(tester, frames: 8);
    expect(lotdRequests.single.body!['kind'], 'problem');
  });

  testWidgets('Mon fond : 3 choix, enregistré sur le compte ET en local, motifs qui suivent', (tester) async {
    lotdPhone(tester);
    final host = _FakeHost();
    await tester.pumpWidget(lotdApp(Scaffold(
      body: SingleChildScrollView(
        child: ProfilePreferencesTab(
          accent: const Color(0xFF16A34A),
          prefs: const ProfilePreferences(),
          onSave: (u) => host.savePreferences(u.toJson()),
          onLanguage: () {},
        ),
      ),
    )));
    await lotdSettle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('MON FOND'), findsOneWidget);
    expect(find.text('Auto, selon mon animal'), findsOneWidget);
    expect(find.text('Pattes seules'), findsOneWidget);
    expect(find.text('Aucun'), findsOneWidget);

    await tester.tap(find.text('Aucun'));
    await lotdSettle(tester);
    expect(host.saved.single['wallpaper'], 'none');
    expect(PawWallpaperPrefs.mode(), 'none');
    expect(PawWallpaperPrefs.motifs(), isEmpty);

    await tester.tap(find.text('Pattes seules'));
    await lotdSettle(tester);
    expect(host.saved.last['wallpaper'], 'paws');
    expect(PawWallpaperPrefs.motifs(), {PawMotif.paw, PawMotif.heart});

    await tester.tap(find.text('Auto, selon mon animal'));
    await lotdSettle(tester);
    expect(host.saved.last['wallpaper'], 'auto');
  });

  test('Motifs « à mon animal » : espèce → objets ; sans animal → rôle', () {
    PawWallpaperPrefs.debugMode = 'auto';
    PawWallpaperPrefs.debugSpecies = ['dog'];
    expect(PawWallpaperPrefs.motifs(), containsAll([PawMotif.paw, PawMotif.heart, PawMotif.bone, PawMotif.ball, PawMotif.leash]));
    PawWallpaperPrefs.debugSpecies = ['cat'];
    expect(PawWallpaperPrefs.motifs(), containsAll([PawMotif.fish, PawMotif.yarn, PawMotif.moon]));
    PawWallpaperPrefs.debugSpecies = ['dog', 'cat'];
    expect(PawWallpaperPrefs.motifs(), containsAll([PawMotif.bone, PawMotif.fish]));
    PawWallpaperPrefs.debugSpecies = ['rabbit'];
    expect(PawWallpaperPrefs.motifs(), contains(PawMotif.carrot));
    PawWallpaperPrefs.debugSpecies = ['bird'];
    expect(PawWallpaperPrefs.motifs(), contains(PawMotif.feather));
    PawWallpaperPrefs.debugSpecies = <String>[];
    PawWallpaperPrefs.debugRole = 'sitter';
    expect(PawWallpaperPrefs.motifs(), {PawMotif.paw, PawMotif.heart, PawMotif.house});
    PawWallpaperPrefs.debugRole = 'walker';
    expect(PawWallpaperPrefs.motifs(), {PawMotif.paw, PawMotif.heart, PawMotif.tree});
    PawWallpaperPrefs.debugRole = '';
    expect(PawWallpaperPrefs.motifs(), {PawMotif.paw, PawMotif.heart});
    expect(PawWallpaperPrefs.normalizeSpecies('Chien'), 'dog');
    expect(PawWallpaperPrefs.normalizeSpecies('Katze'), 'cat');
    expect(PawWallpaperPrefs.normalizeSpecies('Other'), '');
  });
}
