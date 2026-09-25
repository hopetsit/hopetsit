// Lot D (25/09/2026) — « dans le test je ne vois pas le menu » (Daniel).
//
// Les captures d'écrans du lot ouvrent chaque écran SEUL (sans la coquille à
// onglets) ; ce test lance l'APP RÉELLE (`main()` de l'app, vrai serveur), se
// connecte avec le compte de test EXISTANT du rôle demandé (aucun compte
// créé), puis ouvre les 5 onglets du menu du bas (Accueil, Chat, PawMap,
// Réservations, Profil) en laissant l'hôte photographier chaque écran :
//
//   flutter test integration_test/menu_reel_test.dart -d <appareil> \
//     --dart-define=HOST_CAPTURE=true --dart-define=HPS_ROLE=owner|sitter|walker \
//     --dart-define=HPS_TEST_PW=<mot de passe du compte de test, jamais affiché>
//
// Le test se déconnecte à la fin. Aucune donnée écrite (lecture seule).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/main.dart' as app;
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';
import 'package:integration_test/integration_test.dart';

const String kRole = String.fromEnvironment('HPS_ROLE', defaultValue: 'owner');
const String kPw = String.fromEnvironment('HPS_TEST_PW');
const bool kHostCapture = bool.fromEnvironment('HOST_CAPTURE');

Future<void> _pause(WidgetTester tester, int frames) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(WidgetTester tester, Finder f, {int seconds = 20}) async {
  for (int i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (f.evaluate().isNotEmpty) return true;
  }
  return f.evaluate().isNotEmpty;
}

Future<void> _capture(WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding, String name, [String rest = '']) async {
  await tester.pump(const Duration(milliseconds: 100));
  debugPrint('[CAPTURE] ${DateTime.now().toIso8601String()} $name $rest');
  if (kHostCapture) {
    await _pause(tester, 6);
  } else {
    await binding.takeScreenshot(name);
  }
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app réelle : connexion du compte de test et menu du bas ($kRole)', (tester) async {
    try {
      await _run(tester, binding);
    } catch (e, st) {
      // Le rapporteur de `flutter test` n'imprime pas toujours l'exception
      // venue de l'appareil : on la met nous-mêmes dans le journal.
      debugPrint('[CAPTURE] ERREUR : $e');
      debugPrint(st.toString().split('\n').take(12).join('\n'));
      rethrow;
    }
  });
}

Future<void> _run(WidgetTester tester, IntegrationTestWidgetsFlutterBinding binding) async {
    expect(kPw, isNotEmpty, reason: 'HPS_TEST_PW manquant');
    final email = 'dadaciao84+test$kRole@gmail.com';
    final problems = <String>[];

    // Mêmes initialisations que `main()` de l'app (stockage, .env, Firebase,
    // dépendances, thème), SANS la zone Sentry : `runApp` dans une zone
    // différente de celle du test fait échouer le test en silence (« zone
    // mismatch »), et Sentry n'a rien à voir avec le menu. Puis la VRAIE
    // racine de l'app (`MyApp` : splash → aiguillage → coquille à onglets).
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    await SecureTokenStore.instance.migrateFromLegacyIfNeeded();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      debugPrint('[CAPTURE] Firebase : $e');
    }
    setupDependencies();
    Get.put(ThemeController(), permanent: true);
    // Diagnostic : l'app réelle avale les erreurs asynchrones (Crashlytics /
    // rapporteur) → on les écrit dans le journal au lieu de laisser le test
    // mourir en silence.
    FlutterError.onError = (FlutterErrorDetails d) {
      debugPrint('[CAPTURE] ERREUR FLUTTER : ${d.exceptionAsString()}\n${d.stack.toString().split('\n').take(10).join('\n')}');
    };
    WidgetsBinding.instance.platformDispatcher.onError = (Object e, StackTrace st) {
      debugPrint('[CAPTURE] ERREUR ASYNC : $e\n${st.toString().split('\n').take(10).join('\n')}');
      return true;
    };
    await tester.pumpWidget(app.MyApp());
    await _pause(tester, 8); // splash (1,6 s) + aiguillage

    // Déjà connecté (run précédent interrompu) → on repart propre.
    if (find.byType(PawTabBar).evaluate().isNotEmpty && Get.isRegistered<AuthController>()) {
      final done = Get.find<AuthController>().logout();
      await _pause(tester, 8);
      await done.timeout(const Duration(seconds: 1), onTimeout: () {});
    }

    // Écran de connexion (même écran que « Se connecter » de l'écran invité).
    if (find.byType(LoginScreen).evaluate().isEmpty) {
      Get.to(() => const LoginScreen());
      await _pause(tester, 3);
    }
    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(2), reason: 'champs e-mail / mot de passe introuvables');
    await tester.enterText(fields.at(0), email);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(fields.at(1), kPw);
    await tester.pump(const Duration(milliseconds: 300));
    // Fermer le clavier puis appuyer sur « Se connecter » (premier bouton plein).
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 400));
    final loginBtn = find.widgetWithText(CustomButton, 'title_login'.tr);
    bool logged = false;
    if (loginBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(loginBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(loginBtn, warnIfMissed: false);
      logged = await _waitFor(tester, find.byType(PawTabBar), seconds: 45); // serveur distant : jusqu'à 20 s
    }
    if (!logged) {
      // Repli : le contrôleur (mêmes champs, même appel que le bouton) — le
      // bouton peut être sous le clavier sur le petit écran.
      debugPrint('[CAPTURE] connexion : repli par le contrôleur');
      final ok = await Get.find<AuthController>().login();
      if (!ok) problems.add('connexion refusée');
      logged = await _waitFor(tester, find.byType(PawTabBar), seconds: 40);
    }
    if (!logged) {
      problems.add('menu du bas absent après connexion ($kRole) — écran : '
          '${find.byType(LoginScreen).evaluate().isNotEmpty ? 'connexion' : 'autre'}');
    }
    for (final p in problems) {
      debugPrint('[CAPTURE] problème : $p');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));

    // Les 5 onglets, dans l'ordre du menu : Accueil, Chat, PawMap, Réservations, Profil.
    final names = <String>['accueil', 'chat', 'pawmap', 'reservations', 'profil'];
    for (int i = 0; i < 5; i++) {
      final bar = find.byType(PawTabBar);
      if (bar.evaluate().isEmpty) {
        problems.add('onglet $i : le menu du bas a disparu');
        break;
      }
      final rect = tester.getRect(bar);
      if (i == 2) {
        // La patte-pin au centre : elle dépasse la barre vers le haut (zone
        // tactile 84 × 67). On vise son cœur ; si le geste n'a pas pris, on
        // passe par le rappel du menu (même chemin que le geste).
        await tester.tapAt(Offset(rect.center.dx, rect.top + 8));
        await _pause(tester, 2);
        if (tester.widget<PawTabBar>(find.byType(PawTabBar)).currentIndex != 2) {
          tester.widget<PawTabBar>(find.byType(PawTabBar)).onTap(2);
        }
      } else {
        final labels = tester.widget<PawTabBar>(bar).labels;
        final t = find.descendant(of: bar, matching: find.text(labels[i]));
        if (t.evaluate().isNotEmpty) {
          await tester.tap(t.first, warnIfMissed: false);
        } else {
          tester.widget<PawTabBar>(bar).onTap(i);
        }
      }
      await _pause(tester, i == 2 ? 10 : 6); // la carte met quelques secondes
      final stillThere = find.byType(PawTabBar).evaluate().isNotEmpty;
      if (!stillThere) problems.add('onglet ${names[i]} : le menu du bas n\'est plus affiché');
      final idx = find.byType(PawTabBar).evaluate().isNotEmpty
          ? tester.widget<PawTabBar>(find.byType(PawTabBar)).currentIndex
          : -1;
      if (idx != i) problems.add('onglet ${names[i]} : index affiché $idx au lieu de $i');
      await _capture(tester, binding, '${kRole}_menu_${i + 1}_${names[i]}', idx == i ? 'ok' : 'index $idx');
    }

    // Déconnexion (aucune écriture) — bornée : sur simulateur la déconnexion
    // Google peut ne jamais répondre.
    if (Get.isRegistered<AuthController>()) {
      final done = Get.find<AuthController>().logout();
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await done.timeout(const Duration(seconds: 1), onTimeout: () {});
    }
    debugPrint('[CAPTURE] menu réel $kRole : 5 onglets, ${problems.length} problème(s)');
    for (final p in problems) {
      debugPrint('[CAPTURE] problème : $p');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
}
