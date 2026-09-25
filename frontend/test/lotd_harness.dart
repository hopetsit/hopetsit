// v585 (lot D) — HARNAIS commun des tests « tout mon menu marche bien » :
// ouvre de VRAIS écrans de l'app, sans réseau, sans compte, sans plugin.
//
//   · `ApiClient` branché sur un faux client HTTP (`MockClient`) qui répond
//     `{}` / `[]` à tout : les contrôleurs chargent « rien », les écrans
//     rendent leurs états vides — et toute exception de construction remonte
//     dans `tester.takeException()` ;
//   · tous les dépôts enregistrés dans GetX avec cet ApiClient ;
//   · `GetStorage` sans fichier (mémoire seule en test) avec un rôle et un
//     profil minimal, pour que `AppColors.activeRoleAccent()` et les écrans
//     lisent le bon rôle ;
//   · `GetMaterialApp` avec les vraies traductions (fr par défaut) et
//     `ScreenUtilInit` (393 × 852, la taille de conception de l'app).
//
// Les requêtes reçues sont conservées dans `lotdRequests` (méthode, chemin,
// corps) pour vérifier qu'un bouton appelle bien la bonne route.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/favorites_repository.dart';
import 'package:hopetsit/repositories/invoice_repository.dart';
import 'package:hopetsit/repositories/kyc_repository.dart';
import 'package:hopetsit/repositories/notifications_repository.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/repositories/promo_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';

class LotdRequest {
  LotdRequest(this.method, this.path, this.body, [this.query = const <String, String>{}]);
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  /// Paramètres d'URL (`?radiusInMeters=30000`), vides s'il n'y en a pas.
  final Map<String, String> query;
  @override
  String toString() => '$method $path $body';
}

final List<LotdRequest> lotdRequests = <LotdRequest>[];

/// Réponse par défaut : `{}` (200). `lotdResponder` permet à un test de
/// répondre autre chose à un chemin donné.
Map<String, dynamic> Function(http.Request req)? lotdResponder;

http.Client lotdFakeHttp() => MockClient((http.Request req) async {
      Map<String, dynamic>? body;
      if (req.body.isNotEmpty) {
        try {
          body = jsonDecode(req.body) as Map<String, dynamic>;
        } catch (_) {
          body = <String, dynamic>{'raw': req.body};
        }
      }
      lotdRequests.add(LotdRequest(req.method, req.url.path, body, req.url.queryParameters));
      final custom = lotdResponder?.call(req);
      final payload = custom ?? const <String, dynamic>{};
      return http.Response(jsonEncode(payload), 200,
          headers: <String, String>{'content-type': 'application/json'});
    });

Directory? _tmp;

/// `path_provider` n'existe pas en test : on répond avec un dossier
/// temporaire pour que `GetStorage` (et tout ce qui écrit un fichier) marche.
Future<void> _mockPathProvider() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  _tmp ??= await Directory.systemTemp.createTemp('hps_lotd_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    // Seul le dossier des documents (GetStorage) est servi ; le dossier
    // « support » reste « plugin absent », comme dans tous les autres tests,
    // pour que google_fonts garde son comportement habituel hors réseau.
    if (call.method == 'getApplicationDocumentsDirectory') return _tmp!.path;
    throw MissingPluginException('No implementation for ${call.method} (harnais lot D)');
  });
  // package_info_plus : version factice (les écrans l'affichent parfois).
  const info = MethodChannel('dev.fluttercommunity.plus/package_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(info, (MethodCall call) async => <String, dynamic>{
            'appName': 'HoPetSit',
            'packageName': 'com.cardellihermanos.hopetsit',
            'version': '23.1.576',
            'buildNumber': '582',
          });
}

/// À appeler dans `setUp` : remet GetX à zéro et enregistre tout.
Future<void> lotdSetUp({String role = 'owner'}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Get.testMode = true;
  await Get.deleteAll(force: true);
  Get.reset();
  lotdRequests.clear();
  lotdResponder = null;
  await _mockPathProvider();
  await GetStorage.init();
  // Firebase Core simulé (aucun réseau) : `AuthController` lit
  // `FirebaseAuth.instance` dans un champ, qui exige une app Firebase.
  if (Firebase.apps.isEmpty) {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  }

  final storage = GetStorage();
  await storage.erase();
  await storage.write(StorageKeys.userRole, role);
  await storage.write('user_role', role);
  // Jeton de TEST (jamais un vrai) : ApiClient le lit en repli de GetStorage
  // quand le magasin sécurisé n'est pas hydraté (plugin absent en test).
  await storage.write(StorageKeys.authToken, 'test-token-lotd');
  await storage.write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test',
    '_id': 'u-test',
    'name': 'Camille Durand',
    'email': 'camille@example.test',
    'role': role,
    'city': 'Paris',
  });
  AppColors.activeRoleOverride = role;
  Get.put<GetStorage>(storage, permanent: true);

  final api = ApiClient(httpClient: lotdFakeHttp(), storage: storage);
  Get.put<ApiClient>(api, permanent: true);
  Get.put<AuthRepository>(AuthRepository(api), permanent: true);
  Get.put<ChatRepository>(ChatRepository(api), permanent: true);
  Get.put<FavoritesRepository>(FavoritesRepository(api), permanent: true);
  Get.put<InvoiceRepository>(InvoiceRepository(api), permanent: true);
  Get.put<KycRepository>(KycRepository(api), permanent: true);
  Get.put<NotificationsRepository>(NotificationsRepository(api), permanent: true);
  Get.put<OwnerRepository>(OwnerRepository(api), permanent: true);
  Get.put<PetRepository>(PetRepository(api), permanent: true);
  Get.put<PostRepository>(PostRepository(api), permanent: true);
  Get.put<PromoRepository>(PromoRepository(api), permanent: true);
  Get.put<SitterRepository>(SitterRepository(api), permanent: true);
  Get.put<UserRepository>(UserRepository(api), permanent: true);
  Get.put<WalkerRepository>(WalkerRepository(api), permanent: true);
  // Services que les onglets attendent (posés par les wrappers dans l'app) :
  // la prise réseau (jamais connectée ici) et le contrôleur d'authentification
  // (lit le rôle en stockage ; Google Sign-In absent en test = ignoré).
  Get.put<SocketService>(_NoSocket(storage: storage), permanent: true);
  Get.put<AuthController>(
    AuthController(Get.find<AuthRepository>(), storage, Get.find<UserRepository>()),
    permanent: true,
  );
}

/// La prise réseau sans réseau : `connect()` ne fait rien (le faux HTTP des
/// tests ne sait pas ouvrir un WebSocket, et aucun serveur n'est visé ici).
class _NoSocket extends SocketService {
  _NoSocket({super.storage});
  @override
  Future<void> connect({String? tokenOverride}) async {}
}

/// L'app de test : vraies traductions, taille de conception de l'app.
Widget lotdApp(Widget home, {Locale locale = const Locale('fr', 'FR'), Brightness brightness = Brightness.light}) {
  // Après un `Get.reset()` (écran précédent), GetX a perdu ses traductions et
  // sa langue : on les repose explicitement (sinon des CLÉS BRUTES s'affichent
  // dès le 2e écran sur l'appareil — vu sur les captures iOS du 25/09).
  Get.addTranslations(AppTranslations().keys);
  Get.locale = locale;
  Get.fallbackLocale = const Locale('en', 'US');
  return ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, __) => GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en', 'US'),
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: home,
    ),
  );
}

/// Fenêtre = la taille de conception (393 × 852, échelle ScreenUtil 1) ; sinon
/// une fenêtre de 800 × 600 double toutes les tailles et les taps manquent.
void lotdPhone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Pompe quelques images sans jamais attendre une animation infinie.
Future<void> lotdSettle(WidgetTester tester, {int frames = 4}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}
