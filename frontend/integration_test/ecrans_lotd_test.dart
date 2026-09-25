// v585 (lot D) — CAPTURES D'ÉCRAN des écrans principaux et des sous-pages du
// menu, SUR L'APPAREIL (simulateur iPhone / émulateur Android), pour la preuve
// « zéro gris » par les pixels (règle de Daniel du 25/09) et pour l'écran
// « Samsung » (rien de caché par la barre système).
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/ecrans_lotd_test.dart -d <udid|emulator-5554> \
//     --dart-define=CAPTURES=~/hopetsit-social/lotD_captures/<ios|android>
//
// Chaque écran est ouvert dans le harnais sans réseau ni compte
// (`test/lotd_harness.dart` : ApiClient sur faux HTTP, dépôts, stockage, rôle),
// puis photographié après 1,2 s. Aucune donnée réelle, aucun compte.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/shared/widgets/around_me_search_bar.dart';
import 'package:integration_test/integration_test.dart';

import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/kyc/kyc_verification_screen.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:hopetsit/views/notifications/notification_test_screen.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/views/pet_owner/booking/owner_bookings_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/chat_screen.dart';
import 'package:hopetsit/views/pet_owner/home/home_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/owner_payments_screen.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/pet_sitter/booking/sitter_bookings_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/home/sitter_homescreen.dart';
import 'package:hopetsit/views/pet_sitter/payment/payment_management_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/availability_calendar_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/iban_setup_screen.dart';
import 'package:hopetsit/views/pet_sitter/profile/sitter_profile_screen.dart';
import 'package:hopetsit/views/pet_walker/booking/walker_bookings_screen.dart';
import 'package:hopetsit/views/pet_walker/profile/walker_profile_screen.dart';
import 'package:hopetsit/views/profile/billing_info_screen.dart';
import 'package:hopetsit/views/profile/change_password_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/idea_box_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/profile_screen.dart';
import 'package:hopetsit/views/profile/promo_code_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';

import '../test/lotd_harness.dart';

class _Shot {
  const _Shot(this.name, this.role, this.build);
  final String name;
  final String role;
  final Widget Function() build;
}

final List<_Shot> _shots = <_Shot>[
  _Shot('01_owner_accueil', 'owner', () => const HomeScreen()),
  _Shot('02_owner_messages', 'owner', () => const ChatScreen()),
  _Shot('03_owner_reservations', 'owner', () => const OwnerBookingsScreen()),
  _Shot('04_owner_profil', 'owner', () => const ProfileScreen()),
  _Shot('05_sitter_accueil', 'sitter', () => const SitterHomescreen()),
  _Shot('06_sitter_messages', 'sitter', () => const SitterChatScreen()),
  _Shot('07_sitter_reservations', 'sitter', () => const SitterBookingsScreen()),
  _Shot('08_sitter_profil', 'sitter', () => const SitterProfileScreen()),
  _Shot('09_walker_accueil', 'walker', () => const SitterHomescreen()),
  _Shot('10_walker_reservations', 'walker', () => const WalkerBookingsScreen()),
  _Shot('11_walker_profil', 'walker', () => const WalkerProfileScreen()),
  _Shot('12_mes_animaux', 'owner', () => const MyPetsScreen()),
  _Shot('13_ajouter_animal', 'owner', () => const EditPetScreen()),
  _Shot('14_mes_tarifs', 'sitter', () => const MyRatesScreen(role: 'sitter')),
  _Shot('15_disponibilites', 'walker', () => const AvailabilityCalendarScreen(role: 'walker')),
  _Shot('16_kyc', 'sitter', () => const KycVerificationScreen()),
  _Shot('17_portefeuille', 'sitter', () => const WalletScreen()),
  _Shot('18_mes_paiements', 'owner', () => const OwnerPaymentsScreen()),
  _Shot('19_gerer_paiements', 'sitter', () => const PaymentManagementScreen()),
  _Shot('20_mes_cartes', 'owner', () => const SavedCardsScreen()),
  _Shot('21_iban', 'sitter', () => const IbanSetupScreen()),
  _Shot('22_facturation', 'owner', () => const BillingInfoScreen(accent: Color(0xFFC92A12))),
  _Shot('23_code_promo', 'owner', () => const PromoCodeScreen(accent: Color(0xFFC92A12))),
  _Shot('24_boutique', 'owner', () => const CoinShopScreen()),
  _Shot('25_parrainages', 'walker', () => const MyReferralsScreen()),
  _Shot('26_mot_de_passe', 'owner', () => const ChangePasswordScreen()),
  _Shot('27_aide_pawmap', 'walker', () => const PawMapHelpScreen()),
  _Shot('28_idee_probleme', 'sitter', () => const IdeaBoxScreen()),
  _Shot('29_conditions', 'owner', () => const TermsAndConditionsScreen()),
  _Shot('30_depannage_notifications', 'owner', () => const NotificationTestScreen()),
  _Shot('31_notifications', 'owner', () => const NotificationsScreen()),
];

/// `--dart-define=HOST_CAPTURE=true` : les captures sont prises PAR L'HÔTE
/// (`adb exec-out screencap` / `xcrun simctl io screenshot` en boucle) et
/// renommées d'après l'horodatage imprimé ; le test se contente d'afficher
/// chaque écran ~3 s. Utile quand le pilote `flutter drive` perd l'appareil
/// (émulateur passé « offline » au 8e écran le 25/09).
const bool kHostCapture = bool.fromEnvironment('HOST_CAPTURE');

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures des écrans principaux et des sous-pages (3 rôles)', (tester) async {
    int ok = 0;
    final List<String> problems = <String>[];
    // Android : la surface Flutter passe UNE fois en mode image (obligatoire
    // pour `takeScreenshot`), avant la première capture.
    if (Platform.isAndroid && !kHostCapture) {
      await binding.convertFlutterSurfaceToImage();
    }
    for (final s in _shots) {
      await lotdSetUp(role: s.role);
      await tester.pumpWidget(lotdApp(s.build()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));
      final dynamic e = tester.takeException();
      if (e != null) problems.add('${s.name}: $e');
      // Aucune clé de traduction brute à l'écran.
      final rawKeys = find
          .byWidgetPredicate((w) =>
              w is Text &&
              (w.data ?? '').isNotEmpty &&
              RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(w.data!))
          .evaluate()
          .map((el) => (el.widget as Text).data)
          .toList();
      if (rawKeys.isNotEmpty) problems.add('${s.name}: clés brutes $rawKeys');
      await tester.pump(const Duration(milliseconds: 100));
      debugPrint('[CAPTURE] ${DateTime.now().toIso8601String()} ${s.name}${e == null ? '' : ' (exception)'}');
      if (kHostCapture) {
        // L'hôte photographie pendant cette pause.
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
      } else {
        await binding.takeScreenshot(s.name);
      }
      ok++;
      Get.reset();
    }
    // Lot D — CURSEUR DE DISTANCE (Daniel, 25/09) : capture AVANT / APRÈS un
    // déplacement du curseur sur les 3 accueils, avec des annonces et des
    // gardiens fictifs à 40 et 60 km d'un centre en pleine mer.
    for (final role in <String>['owner', 'sitter', 'walker']) {
      final r = await _curseur(tester, role, binding, problems);
      if (r) ok += 2;
    }
    // Lot D — DEVISE (Daniel, 25/09) : Profil › Mes tarifs des gardiens et des
    // promeneurs dans 3 devises (suffixe = symbole du profil, jamais deux
    // devises), avec un faux profil.
    for (final c in <({String name, String role, String currency})>[
      (name: '34_tarifs_sitter_usd', role: 'sitter', currency: 'USD'),
      (name: '35_tarifs_walker_gbp', role: 'walker', currency: 'GBP'),
      (name: '36_tarifs_sitter_eur', role: 'sitter', currency: 'EUR'),
    ]) {
      await lotdSetUp(role: c.role);
      lotdResponder = (req) {
        final path = req.url.path;
        if (path.contains('/walkers/me/rates')) {
          return <String, dynamic>{'walkRates': <Map<String, dynamic>>[
            {'durationMinutes': 30, 'basePrice': 10, 'enabled': true, 'currency': c.currency},
            {'durationMinutes': 60, 'basePrice': 18, 'enabled': true, 'currency': c.currency},
          ]};
        }
        if (path.contains('/walkers/me')) {
          return <String, dynamic>{'id': 'u-test', 'name': 'Camille', 'currency': c.currency, 'extraPetRate': 5};
        }
        if (path.contains('/sitters/')) {
          return <String, dynamic>{'id': 'u-test', 'name': 'Camille', 'currency': c.currency,
            'hourlyRate': 12, 'dailyRate': 40, 'weeklyRate': 200, 'monthlyRate': 600};
        }
        return <String, dynamic>{};
      };
      await tester.pumpWidget(lotdApp(MyRatesScreen(role: c.role)));
      await _pause(tester, 4);
      final dynamic e = tester.takeException();
      if (e != null) problems.add('${c.name}: $e');
      await tester.pump(const Duration(milliseconds: 100));
      debugPrint('[CAPTURE] ${DateTime.now().toIso8601String()} ${c.name}');
      if (kHostCapture) {
        await _pause(tester, 6);
      } else {
        await binding.takeScreenshot(c.name);
      }
      ok++;
      Get.reset();
    }
    debugPrint('[CAPTURE] $ok écrans photographiés, ${problems.length} exception(s)');
    for (final p in problems) {
      debugPrint('[CAPTURE] exception : $p');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

// ─── Curseur de distance : fixtures fictives (aucune vraie ville) ───────────
const double _kLat = -35.2;
const double _kLng = -30.4;
({double lat, double lng}) _eastKm(double km) =>
    (lat: _kLat, lng: _kLng + km / (111.32 * math.cos(_kLat * math.pi / 180)));

Map<String, dynamic> _post(String id, double km, String service) {
  final p = _eastKm(km);
  return <String, dynamic>{
    'id': id, 'postType': 'text', 'body': 'Annonce fictive $id',
    'startDate': '2026-10-10T09:00:00.000Z', 'endDate': '2026-10-12T18:00:00.000Z',
    'serviceTypes': <String>[service],
    'location': <String, dynamic>{'city': 'Zone test', 'lat': p.lat, 'lng': p.lng},
    'createdAt': '2026-09-25T08:00:00.000Z',
    'owner': <String, dynamic>{'id': 'o-$id', 'name': 'Proprio $id', 'email': '', 'avatar': ''},
  };
}

Map<String, dynamic> _provider(String id, double km) {
  final p = _eastKm(km);
  return <String, dynamic>{
    'id': id, 'name': 'Gardien fictif $id', 'email': '$id@example.test', 'city': 'Zone test',
    'location': <String, dynamic>{'type': 'Point', 'coordinates': <double>[p.lng, p.lat]},
    'distanceInMeters': (km * 1000).round(), 'hourlyRate': 12, 'currency': 'EUR',
  };
}

String? _shownRadius(WidgetTester tester) {
  final f = find.descendant(
    of: find.byKey(const ValueKey<String>('around_me_radius_value')),
    matching: find.byType(Text),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f.first).data;
}

Future<void> _pause(WidgetTester tester, int frames) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _curseur(WidgetTester tester, String role,
    IntegrationTestWidgetsFlutterBinding binding, List<String> problems) async {
  await lotdSetUp(role: role);
  await GetStorage().write(StorageKeys.userProfile, <String, dynamic>{
    'id': 'u-test', '_id': 'u-test', 'name': 'Camille Durand', 'email': 'camille@example.test',
    'role': role, 'city': 'Zone test',
    'location': <String, dynamic>{'city': 'Zone test', 'country': 'Test', 'lat': _kLat, 'lng': _kLng},
  });
  final service = role == 'walker' ? 'dog_walking' : 'pet_sitting';
  lotdResponder = (req) {
    final path = req.url.path;
    if (path.endsWith('/posts/requests')) {
      return <String, dynamic>{'posts': <Map<String, dynamic>>[_post('p40', 40, service), _post('p60', 60, service)]};
    }
    if (path.endsWith('/sitters/nearby') || path.endsWith('/walkers/nearby')) {
      final m = double.tryParse(req.url.queryParameters['radiusInMeters'] ?? '') ?? 0;
      final all = <Map<String, dynamic>>[_provider('s40', 40), _provider('s60', 60)];
      final key = path.endsWith('/sitters/nearby') ? 'sitters' : 'walkers';
      return <String, dynamic>{key: all.where((x) => (x['distanceInMeters'] as int) <= m).toList()};
    }
    if (path.endsWith('/posts')) return <String, dynamic>{'posts': <Map<String, dynamic>>[]};
    return <String, dynamic>{};
  };
  final Widget screen = role == 'owner' ? const HomeScreen() : const SitterHomescreen();
  await tester.pumpWidget(lotdApp(screen));
  // Le propriétaire passe par le GPS de l'appareil (jusqu'à 6 s) avant de
  // retomber sur le profil : on lui laisse le temps.
  await _pause(tester, role == 'owner' ? 16 : 4);
  if (role == 'owner' && _shownRadius(tester) == null) {
    final tab = find.text('home_segment_sitters'.tr);
    if (tab.evaluate().isNotEmpty) {
      await tester.tap(tab.first);
      await _pause(tester, 2);
    }
  }
  final slider = find.descendant(of: find.byType(AroundMeSearchBar), matching: find.byType(Slider));
  if (slider.evaluate().isEmpty) {
    problems.add('curseur $role : barre « Autour de moi » introuvable');
    Get.reset();
    return false;
  }
  final before = _shownRadius(tester);
  await tester.pump(const Duration(milliseconds: 100));
  debugPrint('[CAPTURE] ${DateTime.now().toIso8601String()} 32_curseur_${role}_avant $before');
  if (kHostCapture) {
    await _pause(tester, 6);
  } else {
    await binding.takeScreenshot('32_curseur_${role}_avant');
  }
  // Vrai geste : on attrape le pouce (rayon courant) et on le tire à droite.
  final rect = tester.getRect(slider);
  final sw = tester.widget<Slider>(slider);
  final frac = (sw.value - sw.min) / (sw.max - sw.min);
  final thumb = Offset(rect.left + 24 + (rect.width - 48) * frac, rect.center.dy);
  final g = await tester.startGesture(thumb);
  final t = Stopwatch()..start();
  for (int i = 0; i < 30; i++) {
    await g.moveBy(const Offset(2, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  t.stop();
  await _pause(tester, role == 'owner' ? 14 : 3);
  final after = _shownRadius(tester);
  if (after == null || after == before) {
    problems.add('curseur $role : la valeur affichée n\'a pas changé ($before → $after)');
  }
  await tester.pump(const Duration(milliseconds: 100));
  debugPrint('[CAPTURE] ${DateTime.now().toIso8601String()} 33_curseur_${role}_apres $before → $after, 30 pas en ${t.elapsedMilliseconds} ms');
  if (kHostCapture) {
    await _pause(tester, 6);
  } else {
    await binding.takeScreenshot('33_curseur_${role}_apres');
  }
  Get.reset();
  return true;
}
