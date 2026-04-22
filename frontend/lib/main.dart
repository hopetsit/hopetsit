import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/services/push_notification_service.dart'
    show firebaseMessagingBackgroundHandler;
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/routes/app_routes.dart';
import 'package:hopetsit/routes/app_pages.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();
  await dotenv.load(fileName: ".env");
  var initialNotification = await flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  if (initialNotification?.didNotificationLaunchApp == true) {
    Future.delayed(const Duration(seconds: 1), () {
      debugPrint('notification here');
    });
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // v18.6 — FCM push fix. Enregistre le background handler AVANT
    // setupDependencies qui put-async PushNotificationService. Sans ça,
    // l'OS drop les push reçues app-killed/background.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase error is $e");
  }

  setupDependencies();
  Get.put(ThemeController(), permanent: true);

  // ── Stripe init (fix StripeConfigException on first PaymentSheet call) ───
  // We set the publishable key ONCE at startup. Before this fix, each payment
  // flow (Boost / Premium / Map Boost) tried to lazy-init Stripe right before
  // presenting the sheet, which left a race window where initPaymentSheet
  // could throw StripeConfigException if applySettings() hadn't finished.
  final stripePk = dotenv.env['STRIPE_PUBLISHABLE_KEY']?.trim() ?? '';
  if (stripePk.isNotEmpty && stripePk.startsWith('pk_')) {
    try {
      Stripe.publishableKey = stripePk;
      await Stripe.instance.applySettings();
      debugPrint(
        '[Stripe] initialized at boot with key '
        '${stripePk.substring(0, 7)}…${stripePk.substring(stripePk.length - 4)}',
      );
    } catch (e) {
      debugPrint('[Stripe] boot init failed: $e');
    }
  } else {
    debugPrint(
      '[Stripe] no publishable key found in .env — payments will fail until '
      'STRIPE_PUBLISHABLE_KEY is set. Current value: '
      '${stripePk.isEmpty ? '(empty)' : '(invalid format)'}',
    );
  }

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
    runApp(MyApp());
  }
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
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus!.unfocus(),
          child: GetMaterialApp(
            debugShowCheckedModeBanner: false,
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
              primaryColor: AppColors.primaryColor,
              scaffoldBackgroundColor: AppColors.scaffoldLight,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.whiteColor,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: AppColors.primaryColor),
                titleTextStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.blackColor,
                ),
              ),
              cardColor: AppColors.whiteColor,
              useMaterial3: true,
              textTheme: Typography.blackMountainView.apply(
                bodyColor: AppColors.blackColor,
                displayColor: AppColors.blackColor,
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
                trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppColors.primaryColor.withValues(alpha: 0.4)
                        : AppColors.greyColor.withValues(alpha: 0.3)),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle: TextStyle(color: AppColors.grey700Color),
                hintStyle: TextStyle(color: AppColors.greyColor),
              ),
              // Fixes the "Changer de rôle" dialog where title/body text was
              // nearly invisible (light grey on white).
              dialogTheme: const DialogThemeData(
                backgroundColor: AppColors.whiteColor,
                surfaceTintColor: AppColors.whiteColor,
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
              canvasColor: AppColors.backgroundDark,
              cardColor: AppColors.cardDark,
              dividerColor: AppColors.dividerDark,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.surfaceDark,
                elevation: 0,
                scrolledUnderElevation: 0.5,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: AppColors.primaryColor),
                titleTextStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              textTheme: Typography.whiteMountainView.apply(
                bodyColor: AppColors.textPrimaryDark,
                displayColor: AppColors.textPrimaryDark,
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
              dialogTheme: const DialogThemeData(
                backgroundColor: AppColors.cardDark,
                surfaceTintColor: AppColors.cardDark,
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
          ),
        );
      },
    );
  }
}
