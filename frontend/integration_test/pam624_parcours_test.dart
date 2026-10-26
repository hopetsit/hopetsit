// 624 (PAM, 26/10/2026) — parcours PROPRIÉTAIRE complet au simulateur, compte
// de TEST en zone fictive (lat -35 / lng -30), demandes créées par
// ~/hopetsit-social/pam624_data.py. Aucun paiement : la page de paiement est
// seulement AFFICHÉE, puis tout est annulé par le script (0 € débité).
//   A — garde datée : lien de notification /application/<id>?from=email →
//       candidats (candidat entouré) → Écrire (chat) → retour → Choisir →
//       confirmation → paiement affiché.
//   D — balade « dates à prévoir » : candidats → encart → Choisir mes dates →
//       feuille des dates seules (date + heure, AUCUN code postal) →
//       Enregistrer → total frais compris → Choisir → paiement affiché.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const String kEmail = String.fromEnvironment('HPS_EMAIL');
const String kPassword = String.fromEnvironment('HPS_PASSWORD');
const String kAppA = String.fromEnvironment('HPS_APP_A');
const String kAppD = String.fromEnvironment('HPS_APP_D');
const String kTag = String.fromEnvironment('HPS_TAG', defaultValue: 'pam624');

void say(String s) => debugPrint('[PARCOURS] $s');

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 900));
  debugPrint('[SHOT] ${kTag}_$name');
  await t.pump(const Duration(milliseconds: 2600));
}

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (f.evaluate().isNotEmpty) return;
    await t.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null || message.startsWith('[HOPETSIT]')) return;
      // ignore: avoid_print
      print(message);
    };
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      say('Firebase : $e');
    }
    PushNotificationService.skipInitForIntegrationTests = true;
    MetaEventsService.skipTrackingPromptForTests = true;
    LocationService.skipPromptForTests = true; // fenêtre système de position
    setupDependencies();
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('fr');
  });

  testWidgets('Parcours propriétaire 624', (t) async {
    var fails = 0;
    void check(bool ok, String what) {
      say('${ok ? 'OK ' : 'KO '} $what');
      if (!ok) fails++;
    }

    final theme = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>()
        : Get.put<ThemeController>(ThemeController(), permanent: true);
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => Obx(() => GetMaterialApp(
            translations: AppTranslations(),
            locale: const Locale('fr', 'FR'),
            fallbackLocale: const Locale('en', 'US'),
            // Comme main.dart : calendrier et heure dans la langue de l'app.
            supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode.value,
            theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
            darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: const Scaffold(body: SizedBox.expand()),
          )),
    ));
    await t.pump(const Duration(seconds: 1));
    expect(kEmail, isNotEmpty);
    expect(kAppA, isNotEmpty);
    final auth = Get.find<AuthController>();
    auth.emailController.text = kEmail;
    auth.passwordController.text = kPassword;
    final logged = await auth.login(preferredRole: 'owner', skipFormValidation: true);
    check(logged, 'connexion propriétaire de test');
    await theme.setMode(ThemeMode.light);
    Get.offAll(() => const BottomNavWrapper());
    await t.pump(const Duration(seconds: 6));

    // ── A : garde datée, ouverte par le lien de la notification / de l'e-mail
    final sheet = find.byKey(const Key('cand2610_sheet'));
    // ignore: unawaited_futures
    DeepLinkService.instance.openRoute('/application/$kAppA?from=email');
    await waitFor(t, sheet);
    await t.pump(const Duration(seconds: 3));
    check(sheet.evaluate().isNotEmpty, 'A : le lien /application/<id>?from=email ouvre la page des candidats');
    check(find.byKey(Key('cand2610_card_$kAppA')).evaluate().isNotEmpty, 'A : le candidat de la notification est affiché');
    check(find.textContaining('72,00').evaluate().isNotEmpty, 'A : total frais compris au format français (72,00 €)');
    final h = t.view.physicalSize.height / t.view.devicePixelRatio;
    final wr = find.byKey(Key('cand2610_write_$kAppA'));
    final ch = find.byKey(Key('dates620_choose_$kAppA'));
    if (wr.evaluate().isNotEmpty && ch.evaluate().isNotEmpty) {
      check(t.getBottomLeft(ch).dy <= h, 'A : Écrire et Choisir visibles sans défiler (bas de Choisir ${t.getBottomLeft(ch).dy.toStringAsFixed(0)} / $h)');
    }
    await shot(t, '01_candidats_garde_datee');

    // Écrire à <prénom> → la conversation.
    await t.tap(wr);
    await waitFor(t, find.byType(IndividualChatScreen), seconds: 15);
    check(find.byType(IndividualChatScreen).evaluate().isNotEmpty, 'A : « Écrire à … » ouvre la conversation');
    await t.pump(const Duration(seconds: 2));
    await shot(t, '02_ecrire_conversation');
    Get.back();
    await t.pump(const Duration(seconds: 3));
    check(sheet.evaluate().isNotEmpty, 'A : retour du chat = page des candidats');

    // Choisir · 72,00 € → confirmation → paiement affiché.
    await t.tap(ch);
    await t.pump(const Duration(seconds: 2));
    await shot(t, '03_choisir_confirmation');
    final confirm = find.text('candidates_choose_confirm'.tr);
    check(confirm.evaluate().isNotEmpty, 'A : confirmation « Choisir ce prestataire ? »');
    if (confirm.evaluate().isNotEmpty) await t.tap(confirm.last);
    await t.pump(const Duration(seconds: 12));
    check(sheet.evaluate().isEmpty, 'A : la feuille se ferme après le choix');
    await shot(t, '04_paiement_affiche_garde');

    // Retour à l'accueil (aucun paiement).
    Get.offAll(() => const BottomNavWrapper());
    await t.pump(const Duration(seconds: 5));

    // ── D : balade « dates à prévoir »
    // ignore: unawaited_futures
    DeepLinkService.instance.openRoute('/application/$kAppD');
    await waitFor(t, sheet);
    await t.pump(const Duration(seconds: 3));
    check(find.text('Indique tes dates pour voir le prix total et choisir').evaluate().isNotEmpty,
        'D : encart « Indique tes dates … »');
    check(find.textContaining('14,40').evaluate().isNotEmpty, 'D : tarif frais compris (ownerUnitRate 14,40 €)');
    await shot(t, '05_candidats_dates_a_prevoir');
    await t.tap(find.byKey(const Key('dates620_set_dates_button')));
    await waitFor(t, find.byKey(const Key('dates2610_sheet')), seconds: 10);
    check(find.byKey(const Key('dates2610_sheet')).evaluate().isNotEmpty, 'D : « Choisir mes dates » ouvre la feuille des dates seules');
    check(find.byKey(const Key('dates2610_time')).evaluate().isNotEmpty, 'D : balade = une date + une heure');
    check(find.textContaining('ostal').evaluate().isEmpty, 'D : aucun code postal demandé');
    await shot(t, '06_feuille_dates');
    // Date : après-demain (le calendrier s'ouvre sur aujourd'hui).
    await t.tap(find.byKey(const Key('dates2610_start')));
    await t.pump(const Duration(seconds: 2));
    final d = DateTime.now().add(const Duration(days: 2));
    final day = find.text('${d.day}');
    if (d.month != DateTime.now().month) {
      // Mois suivant : flèche « mois suivant ».
      final next = find.byIcon(Icons.chevron_right);
      if (next.evaluate().isNotEmpty) {
        await t.tap(next.first);
        await t.pump(const Duration(seconds: 1));
      }
    }
    if (day.evaluate().isNotEmpty) await t.tap(day.last);
    await t.pump(const Duration(seconds: 1));
    final ok = find.text('OK');
    if (ok.evaluate().isNotEmpty) await t.tap(ok.last);
    await t.pump(const Duration(seconds: 2));
    await shot(t, '07_dates_choisies');
    await t.tap(find.byKey(const Key('dates2610_save')));
    await t.pump(const Duration(seconds: 10));
    check(find.byKey(const Key('dates2610_sheet')).evaluate().isEmpty, 'D : dates enregistrées, feuille fermée');
    await t.pump(const Duration(seconds: 4));
    final chD = find.byKey(Key('dates620_choose_$kAppD'));
    check(find.textContaining('14,40').evaluate().isNotEmpty, 'D : total recalculé par le serveur affiché (14,40 €)');
    check(find.text('Indique tes dates pour voir le prix total et choisir').evaluate().isEmpty,
        'D : encart retiré après les dates');
    await shot(t, '08_total_apres_dates');
    if (chD.evaluate().isNotEmpty) {
      await t.tap(chD);
      await t.pump(const Duration(seconds: 2));
      final c2 = find.text('candidates_choose_confirm'.tr);
      final bool dialog = c2.evaluate().isNotEmpty;
      check(dialog, 'D : Choisir possible après les dates (confirmation affichée)');
      if (dialog) {
        await t.tap(c2.last);
        await t.pump(const Duration(seconds: 12));
      }
      await shot(t, '09_paiement_affiche_balade');
    }
    Get.offAll(() => const BottomNavWrapper());
    await t.pump(const Duration(seconds: 3));
    say('TOTAL $kTag KO=$fails');
  });
}
