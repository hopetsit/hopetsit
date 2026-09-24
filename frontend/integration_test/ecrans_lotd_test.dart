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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures des écrans principaux et des sous-pages (3 rôles)', (tester) async {
    int ok = 0;
    final List<String> problems = <String>[];
    for (final s in _shots) {
      await lotdSetUp(role: s.role);
      await tester.pumpWidget(lotdApp(s.build()));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));
      final dynamic e = tester.takeException();
      if (e != null) problems.add('${s.name}: $e');
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(milliseconds: 100));
      }
      await binding.takeScreenshot(s.name);
      debugPrint('[CAPTURE] ${s.name}${e == null ? '' : ' (exception)'}');
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
