import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'dart:async' show TimeoutException, unawaited;
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'dart:io'
    show HttpException, SocketException, TlsException, WebSocketException;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, FlutterError;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/services/live_tracking_bg.dart';
import 'package:hopetsit/services/push_notification_service.dart'
    show firebaseMessagingBackgroundHandler;
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/routes/app_routes.dart';
import 'package:hopetsit/routes/app_pages.dart';
import 'package:hopetsit/views/splash/splash_screen.dart';
import 'package:hopetsit/views/map/pawmap_snapshot.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/utils/paw_menu_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// v598 — ZOE : repères de démarrage, lisibles en build profile avec
// `adb logcat | grep BOOT` (debugPrint est un no-op en release : coût nul).
final Stopwatch bootWatch = Stopwatch()..start();
void bootMark(String label) =>
    debugPrint('[BOOT] ${bootWatch.elapsedMilliseconds} ms — $label');

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// v530 — les coupures réseau passagères (WiFi qui décroche, requête
// interrompue, serveur injoignable) étaient enregistrées fatal:true dans
// Crashlytics → emails « Nouveaux problèmes provoquant de nombreux
// plantages » pour 1 event isolé par version (523/527/529), alors que le
// filet de sécurité rattrape l'erreur et que l'app ne se ferme pas. Ces
// erreurs restent visibles dans Crashlytics mais en NON-FATAL ; tout le
// reste demeure fatal.
bool _isNetworkError(Object error) {
  if (error is SocketException ||
      error is HttpException ||
      error is TlsException ||
      error is WebSocketException ||
      error is TimeoutException) {
    return true;
  }
  // Clients HTTP qui enrobent l'erreur d'origine (http.ClientException,
  // GetConnect) sans exposer un type de dart:io.
  final text = error.toString();
  return text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection closed') ||
      text.contains('Connection reset') ||
      text.contains('Connection refused') ||
      text.contains('Network is unreachable') ||
      text.contains('Software caused connection abort') ||
      // v569 — google_fonts sans réseau : la police de repli s'affiche, ce
      // n'est pas un plantage (Crashlytics le comptait comme fatal).
      text.contains('Failed to load font');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // v23.1 part 231 — Daniel : "app lag sur Oppo / petits ecrans".
  // FIX SYSTEM-WIDE n°1 : reduire le cache d'images Flutter.
  // Default Flutter : 1000 images / 100MB. Sur Oppo A-series 4GB RAM
  // (1.5GB dispo apps), 100MB de cache + decodage full-res = swap +
  // lag global. On capte a 50MB / 100 images : permet de garder les
  // avatars + cards visibles en cache, mais libere de la RAM.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB

  // v23.1 part 125 — Phase 2 audit C1.
  // En release, `debugPrint` ne doit RIEN écrire. Flutter ne strip pas
  // debugPrint automatiquement, donc 194 sites du codebase loguaient PII
  // (FCM tokens, body de réponses, emails) dans logcat → vu par d'autres
  // apps sur device rooté + politique Play "logs de données utilisateurs".
  // Ce no-op global couvre l'ensemble du codebase d'un coup, sans toucher
  // aux 200 sites un par un.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // v23.1.164 — Daniel : "quand je change de langue les arrow samsung
  // devienne blanche, met gris tte les langue". v163 mettait fond orange
  // + icones noires, mais le changement de langue (via Get.updateLocale)
  // reconstruit MaterialApp et reset les SystemUiOverlayStyle au defaut
  // OS (icones blanches sur certains Samsung). Fix : on passe a un fond
  // GRIS NEUTRE qui ne depend ni de la langue ni du theme orange.
  // En complement, on re-applique le style via AnnotatedRegion au root
  // du MaterialApp (build() ci-dessous) pour resister aux rebuilds de
  // locale change.
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    // v23.1.164 — Gris #E5E7EB (slate-200) + icones SOMBRES = lisible
    // dans toutes les langues, persiste aux changements de locale.
    systemNavigationBarColor: Color(0xFFEEE4E2),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0xFFEEE4E2),
    // v465 — Daniel : « la barre Samsung est transparente, on voit des boutons
    // derrière ». true = la barre système a un fond opaque (scrim) → plus de
    // contenu visible/cliquable derrière elle.
    systemNavigationBarContrastEnforced: true,
  ));

  await GetStorage.init();
  bootMark('GetStorage.init');
  await dotenv.load(fileName: ".env");
  bootMark('dotenv');

  // v594 — Daniel (26/09) : sur l'Oppo A40 de son frère, écran vide avant la
  // PawMap. Le moteur Google Maps ne démarrait qu'à la première carte (lent
  // sur ces puces). On le prépare dès le lancement, sans attendre.
  unawaited(_warmUpMaps());
  // v603 — la photo de la dernière PawMap est décodée pendant l'écran de
  // démarrage : posée sans délai par-dessus la carte à son ouverture.
  unawaited(PawMapSnapshotStore.warmUp());

  // v598 — ZOE (mesuré sur émulateur 2 Go, démarrage à froid) : les cinq
  // initialisations ci-dessous sont indépendantes les unes des autres et
  // s'enchaînaient en série avant runApp (≈ 0,8 s, dont ≈ 0,7 s pour la
  // lecture du Keystore Android). Lancées ensemble, l'app n'attend plus que
  // la plus longue. L'ORDRE des effets est conservé : tout est terminé avant
  // setupDependencies() (le jeton est hydraté avant que les contrôleurs, le
  // socket et les notifications push ne le lisent).
  await Future.wait<void>(<Future<void>>[
    _initDateFormatting(),
    // v23.1 part 125 — Phase 2 audit C4 : migrer le JWT depuis GetStorage
    // vers flutter_secure_storage (Keystore Android / Keychain iOS) au boot,
    // AVANT que les controllers / api_client ne tentent de le lire.
    SecureTokenStore.instance.migrateFromLegacyIfNeeded().then((_) => bootMark('SecureTokenStore.migrate')),
    // v416 — enregistre le service de fond du suivi en direct (survit au
    // swipe-kill sur Android). Non bloquant + non fatal (try/catch interne).
    configureLiveTrackingService().then((_) => bootMark('configureLiveTrackingService')),
    _logNotificationLaunch(),
    _initFirebase(),
  ]);
  bootMark('initialisations parallèles terminées');
  setupDependencies();
  Get.put(ThemeController(), permanent: true);
  bootMark('setupDependencies');

  // v18.8 — écoute les deep links hopetsit://pay/:bookingId envoyés dans
  // les emails "demande acceptée". Fire-and-forget : le stream reste
  // actif pendant toute la durée de vie de l'app.
  // ignore: discarded_futures
  DeepLinkService.instance.start();

  // v21.1.1 — Stripe purgé. Airwallex SDK init.
  // v23.1 part 250 — perf time-to-first-frame : l'init Airwallex bloquait
  // runApp (= duree de l'ecran noir au demarrage) alors que le SDK n'est
  // utile qu'au PREMIER paiement. On le lance en fire-and-forget : l'app
  // demarre immediatement, le SDK finit de s'init en tache de fond. Le
  // flow paiement attend deja confirmPaymentIntent qui re-check l'init.
  final useDemo = (dotenv.env['AIRWALLEX_USE_DEMO'] ?? 'false').toLowerCase() == 'true';
  // ignore: discarded_futures
  AirwallexPaymentService.init(live: !useDemo);

  // v529 — SDK Meta (App Events) : init APRÈS la première frame pour que la
  // popup ATT iOS ne s'affiche pas par-dessus l'écran de lancement (Apple
  // refuse le prompt tant que l'app n'est pas au premier plan et active).
  // Fire-and-forget, non fatal.
  // v583 (lot A, décision de Daniel du 23/09) — init() ne présente plus la
  // fenêtre ATT ; requestTrackingAfterEntry() la pose seulement quand
  // l'utilisateur est entré dans l'app ET que la fenêtre des notifications a
  // déjà sa réponse (jamais deux fenêtres système dans la même session).
  // 606 (refus Apple 2.1) — ordre fixe : Firebase (signaux pub refusés sur
  // iOS) → Meta (aligné sur la réponse ATT connue) → fenêtre ATT si un compte
  // est déjà connecté. L'accueil la redemande aussi après connexion.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // v532 — Firebase Analytics : canal par lequel Google Ads reçoit les events
    // in-app (sign_up). Sans lui, Google n'optimise que sur le volume d'installs.
    await FirebaseAnalyticsService.instance.init();
    await MetaEventsService.instance.init();
    // ignore: discarded_futures
    MetaEventsService.instance.requestTrackingAfterEntry();
  });

  // Sprint 8 step 6 — optional Sentry. Opt-in via SENTRY_DSN_FRONTEND in .env.
  final sentryDsn = dotenv.env['SENTRY_DSN_FRONTEND'] ?? '';
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = double.tryParse(
              dotenv.env['SENTRY_TRACES_SAMPLE_RATE'] ?? '0',
            ) ??
            0.0;
      },
      appRunner: () => runApp(MyApp()),
    );
  } else {
    bootMark('runApp');
    runApp(MyApp());
    WidgetsBinding.instance.addPostFrameCallback((_) => bootMark('1re image Flutter'));
  }
  // 606 (BOB, captures App Store) — DEBUG SEULEMENT : la clé locale `hps_shot_route`
  // (posée dans GetStorage.gs, app fermée) ouvre un écran sans lien — un lien poserait
  // « Ouvrir dans HoPetSit ? » sur le simulateur. Jamais actif en release (kReleaseMode).
  if (!kReleaseMode) {
    final box = GetStorage();
    final shotRoute = (box.read('hps_shot_route') ?? '').toString();
    if (shotRoute.startsWith('/')) {
      box.remove('hps_shot_route');
      Future.delayed(const Duration(seconds: 4),
          () => DeepLinkService.instance.openRoute(shotRoute));
    }
  }
}

/// v530 — Daniel : « dates en anglais (Jul 9, 2026) alors que l'app est en
/// français ». Les DateFormat SANS locale explicite suivent Intl.defaultLocale
/// — jamais réglé jusqu'ici → anglais partout (cloche notifs, commentaires,
/// historique gains...). On initialise les symboles de dates des 9 langues
/// puis on aligne Intl.defaultLocale sur la langue de l'app (aussi mis à
/// jour à chaque changement de langue dans LocalizationService.updateLocale).
Future<void> _initDateFormatting() async {
  try {
    // v532 — ko_KR et ja_JP ajoutés : sans eux, DateFormat('dd MMM yyyy','ko')
    // lève LocaleDataException et fait CRASHER les écrans portefeuille et
    // historique des gains (ce n'est pas un simple affichage dégradé).
    for (final code in [
      'en_US', 'fr_FR', 'es_ES', 'de_DE', 'it_IT', 'pt_PT', 'ko_KR', 'ja_JP',
      'pl_PL', // v546 — polonais
    ]) {
      await initializeDateFormatting(code);
    }
    Intl.defaultLocale = LocalizationService.getInitialLocale().toString();
  } catch (e) {
    debugPrint('date formatting init failed: $e');
  }
  bootMark('initializeDateFormatting x9');
}

Future<void> _logNotificationLaunch() async {
  try {
    final initialNotification = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (initialNotification?.didNotificationLaunchApp == true) {
      Future.delayed(const Duration(seconds: 1), () {
        debugPrint('notification here');
      });
    }
  } catch (e) {
    debugPrint('notification launch details failed: $e');
  }
  bootMark('getNotificationAppLaunchDetails');
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    bootMark('Firebase.initializeApp');
    // v18.6 — FCM push fix. Enregistre le background handler AVANT
    // setupDependencies qui put-async PushNotificationService. Sans ça,
    // l'OS drop les push reçues app-killed/background.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // v23.1 part 125 — Phase 2 audit L3 : Crashlytics.
    // Collecte les crashes natifs + non-fatal Flutter errors. Désactivé en
    // debug pour ne pas polluer le tableau de bord Firebase. Crash-free %
    // visible côté Play Vitals.
    if (kReleaseMode) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError = (details) {
        if (_isNetworkError(details.exception)) {
          FirebaseCrashlytics.instance.recordFlutterError(details);
        } else {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };
      // Capture aussi les async errors hors zone Flutter.
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        FirebaseCrashlytics.instance
            .recordError(error, stack, fatal: !_isNetworkError(error));
        return true;
      };
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    }
  } catch (e) {
    debugPrint("Firebase error is $e");
  }
  bootMark('Firebase+Crashlytics');
}

/// v23.1 part 235 — Daniel : "sa lag encore legerement" sur Oppo.
/// ScrollBehavior global qui force ClampingScrollPhysics (Android natif,
/// scroll arrete net sans rebond) au lieu de BouncingScrollPhysics par
/// defaut (iOS-style avec overscroll bounce animation = ~10% CPU drain
/// par swipe). Aussi : on retire le glow effect Android pour eviter le
/// rebuild du overscroll indicator pendant le scroll.
class _PerfScrollBehavior extends ScrollBehavior {
  const _PerfScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child; // no glow
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // Design size based on modern devices
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // v23.1.164 — Daniel : "quand je change de langue les arrow samsung
        // devienne blanche". On wrap GetMaterialApp dans un AnnotatedRegion
        // qui re-applique le SystemUiOverlayStyle a chaque rebuild (donc
        // chaque changement de langue qui fait rebuild MaterialApp). Le
        // setSystemUIOverlayStyle initial dans main() ne survivait pas a
        // Get.updateLocale() qui recree l'arbre widget.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Color(0xFFEEE4E2),
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Color(0xFFEEE4E2),
            // v465 — Daniel : « la barre Samsung est transparente, on voit des boutons
    // derrière ». true = la barre système a un fond opaque (scrim) → plus de
    // contenu visible/cliquable derrière elle.
    systemNavigationBarContrastEnforced: true,
          ),
          child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus!.unfocus(),
          child: GetMaterialApp(
            debugShowCheckedModeBanner: false,
            // v23.1 part 235 — Daniel : "sa lag encore legerement". Force
            // ClampingScrollPhysics partout (Android natif) au lieu du
            // default BouncingScrollPhysics (iOS-style avec overscroll
            // animation = ~10% CPU drain par scroll). Sur Oppo low-end,
            // ce gain compte.
            scrollBehavior: const _PerfScrollBehavior(),
            translations: AppTranslations(),
            locale: LocalizationService.getInitialLocale(),
            fallbackLocale: LocalizationService.fallbackLocale,
            supportedLocales: LocalizationService.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.light,
              // v23.1 part 20 — kill global splash factory pour éviter tout
              // ripple Material gris résiduel autour des items de la bottom
              // nav bar (cas Accueil tab).
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryColor,
                brightness: Brightness.light,
              ).copyWith(
                // Force readable text on surfaces everywhere (fixes the almost
                // invisible Radio / Checkbox / ListTile labels we had in the
                // "Publier une demande" screen and other forms).
                onSurface: AppColors.blackColor,
                onSurfaceVariant: AppColors.grey700Color,
              ),
              // v585 (bug 9) — TOUS les menus déroulants et contextuels sur un
              // blanc chaud, coins 16, ombre teintée : plus jamais de gris.
              canvasColor: PawMenuColors.paperLight,
              // Ligne focalisée d'un menu : plus de voile gris Material (la
              // valeur choisie a déjà sa teinte du rôle + coche) ; survol en
              // teinte chaude.
              focusColor: Colors.transparent,
              hoverColor: AppColors.primaryColor.withValues(alpha: 0.06),
              popupMenuTheme: PawMenuThemes(dark: false).popup,
              menuTheme: PawMenuThemes(dark: false).menu,
              dropdownMenuTheme: PawMenuThemes(dark: false).dropdownMenu,
              primaryColor: AppColors.primaryColor,
              // v449 — fallback global teinté par RÔLE (owner orange pâle /
              // sitter bleu pâle / walker vert pâle). Les pages posent leur
              // propre AppColors.scaffold(context) ; ceci ne sert que de
              // fallback quand un Scaffold n'en pose pas.
              scaffoldBackgroundColor: AppColors.scaffoldLightForRole(),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.whiteColor,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: AppColors.primaryColor),
                titleTextStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.blackColor,
                ),
              ),
              cardColor: AppColors.whiteColor,
              useMaterial3: true,
              // v571 — Daniel : « belle police dans toute l'app ». Tout
              // Text() brut (boutons, dialogues, listes) héritait de la police
              // système ; il hérite maintenant d'Inter, comme InterText.
              textTheme: GoogleFonts.interTextTheme(
                Typography.blackMountainView.apply(
                  bodyColor: AppColors.blackColor,
                  displayColor: AppColors.blackColor,
                ),
              ),
              listTileTheme: const ListTileThemeData(
                textColor: AppColors.blackColor,
                iconColor: AppColors.grey700Color,
              ),
              radioTheme: RadioThemeData(
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primaryColor;
                  }
                  return AppColors.grey700Color;
                }),
              ),
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primaryColor;
                  }
                  return AppColors.whiteColor;
                }),
                checkColor: WidgetStateProperty.all(AppColors.whiteColor),
                side: const BorderSide(color: AppColors.grey700Color, width: 1.5),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.primaryColor
                        : AppColors.greyColor),
                // v578 — piste ETEINTE en teinte chaude pleine : a 30 %
                // d'opacite sur blanc, la couleur redevenait grise.
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.primaryColor.withValues(alpha: 0.4)
                        : AppColors.grey300Color),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: AppColors.grey700Color),
                hintStyle: TextStyle(color: AppColors.greyColor),
              ),
              // Fixes the "Changer de rôle" dialog where title/body text was
              // nearly invisible (light grey on white).
              // v569 — Daniel : « tous les boutons de l'ancien style modernisés ».
              // Défauts GLOBAUX des boutons Material (65 ElevatedButton, 39
              // OutlinedButton, TextButton, FilledButton) : coins 14, hauteur
              // tactile 48, texte 15/700, plus d'ombre « Material » datée. Un
              // style local (styleFrom) garde la priorité.
              // v585 (lot D) — mêmes 4 thèmes, sans UN gris : désactivé =
              // teinte pâle pleine, ondulation teintée, contour couleur
              // (`PawMaterialButtonThemes`, widgets/paw_button_kit.dart).
              elevatedButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: false).elevated,
              filledButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: false).filled,
              outlinedButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: false).outlined,
              textButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: false).text,
              dialogTheme: const DialogThemeData(
                backgroundColor: AppColors.whiteColor,
                surfaceTintColor: AppColors.whiteColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
                titleTextStyle: TextStyle(
                  color: AppColors.blackColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                contentTextStyle: TextStyle(
                  color: AppColors.blackColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryColor,
                brightness: Brightness.dark,
              ),
              primaryColor: AppColors.primaryColor,
              scaffoldBackgroundColor: AppColors.backgroundDark,
              // v585 (bug 9) — menus en encre foncée chaude, jamais gris.
              popupMenuTheme: PawMenuThemes(dark: true).popup,
              menuTheme: PawMenuThemes(dark: true).menu,
              dropdownMenuTheme: PawMenuThemes(dark: true).dropdownMenu,
              canvasColor: PawMenuColors.paperDark,
              focusColor: Colors.transparent,
              hoverColor: AppColors.primaryColor.withValues(alpha: 0.10),
              cardColor: AppColors.cardDark,
              dividerColor: AppColors.dividerDark,
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.surfaceDark,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: AppColors.primaryColor),
                titleTextStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              textTheme: GoogleFonts.interTextTheme(
                Typography.whiteMountainView.apply(
                  bodyColor: AppColors.textPrimaryDark,
                  displayColor: AppColors.textPrimaryDark,
                ),
              ),
              listTileTheme: const ListTileThemeData(
                textColor: AppColors.textPrimaryDark,
                iconColor: AppColors.textPrimaryDark,
              ),
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: AppColors.cardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.dividerDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.dividerDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
                ),
              ),
              // v569 — mêmes défauts de boutons qu'en thème clair.
              // v585 (lot D) — mêmes 4 thèmes, sans UN gris : désactivé =
              // teinte pâle pleine, ondulation teintée, contour couleur
              // (`PawMaterialButtonThemes`, widgets/paw_button_kit.dart).
              elevatedButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: true).elevated,
              filledButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: true).filled,
              outlinedButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: true).outlined,
              textButtonTheme: PawMaterialButtonThemes(accent: AppColors.primaryColor, dark: true).text,
              dialogTheme: const DialogThemeData(
                backgroundColor: AppColors.cardDark,
                surfaceTintColor: AppColors.cardDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
                titleTextStyle: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                contentTextStyle: TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              useMaterial3: true,
            ),
            themeMode: Get.find<ThemeController>().themeMode.value,
            builder: (BuildContext context, Widget? child) {
              final MediaQueryData data = MediaQuery.of(context);
              // Clamp text scaling to <= 1.02 for layout stability.
              final double scale = data.textScaler.scale(1.0);
              final double clamped = scale < 1.02 ? scale : 1.02;
              return MediaQuery(
                data: data.copyWith(textScaler: TextScaler.linear(clamped)),
                child: child!,
              );
            },
            // Sprint 8 step 1 — named-route registry. Legacy Get.to(() => Screen())
            // calls remain functional; new code should use Get.toNamed(AppRoutes.xxx).
            initialRoute: AppRoutes.splash,
            getPages: AppPages.pages,
            // v569 — Crashlytics « PageRedirect.page : Null check » (8 utilisateurs) :
            // un lien universel / hopetsit:// ouvrait l'app avec une route
            // inconnue de GetX (ex. /bookings/123) → plantage. Route inconnue =
            // écran de démarrage ; DeepLinkService ouvre ensuite le bon écran.
            unknownRoute: GetPage(
              name: '/not-found',
              page: () => const SplashScreen(),
            ),
          ),
          ),
        );
      },
    );
  }
}

/// v594 — prépare le moteur de rendu Google Maps (Android) avant la 1re
/// carte. Sans effet ailleurs ; une erreur ici ne bloque jamais l'app.
/// v599 — APK de test A/B pour l'Oppo A40 de Daniel (carte vide 5 s au
/// premier affichage) : `--dart-define=HPS_MAP_SURFACE=1` active la
/// « composition hybride » du SDK Google Maps (la carte est une vraie vue
/// Android, plus une texture). Jamais actif dans le build des stores.
const bool kHpsMapSurface =
    String.fromEnvironment('HPS_MAP_SURFACE', defaultValue: '0') == '1';

Future<void> _warmUpMaps() async {
  try {
    final impl = GoogleMapsFlutterPlatform.instance;
    if (impl is GoogleMapsFlutterAndroid) {
      if (kHpsMapSurface) impl.useAndroidViewSurface = true;
      await impl.initializeWithRenderer(AndroidMapRenderer.latest);
    }
  } catch (_) {/* déjà initialisé ou indisponible : la carte le fera */}
}

