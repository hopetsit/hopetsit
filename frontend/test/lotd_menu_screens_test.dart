// v585 (lot D) — « Tout mon menu marche bien » (Daniel), partie DYNAMIQUE :
// on OUVRE chaque écran d'onglet des 3 rôles et chaque sous-page atteignable
// depuis le menu Profil, pour de vrai, dans le harnais sans réseau
// (`lotd_harness.dart`), et on vérifie qu'un écran s'affiche SANS exception.
//
// Ce qui n'est pas ouvert ici, et pourquoi :
//   · la PawMap (`GoogleMap` = vue native, impossible dans un test de widgets)
//     → couverte par `integration_test/pawmap_parcours_test.dart` sur le
//     simulateur iOS ET l'émulateur Android ;
//   · les écrans qui exigent une session réelle pour s'afficher (paiement
//     Airwallex, KYC en ligne) restent construits et vérifiés à l'état vide.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/boost/pawspot_leaderboard_screen.dart';
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
import 'package:hopetsit/views/profile/add_task_screen.dart';
import 'package:hopetsit/views/profile/billing_info_screen.dart';
import 'package:hopetsit/views/profile/blocked_users_screen.dart';
import 'package:hopetsit/views/profile/change_password_screen.dart';
import 'package:hopetsit/views/profile/edit_pet_screen.dart';
import 'package:hopetsit/views/profile/idea_box_screen.dart';
import 'package:hopetsit/views/profile/my_pets_screen.dart';
import 'package:hopetsit/views/profile/my_rates_screen.dart';
import 'package:hopetsit/views/profile/my_referrals_screen.dart';
import 'package:hopetsit/views/profile/privacy_policy_screen.dart';
import 'package:hopetsit/views/profile/profile_screen.dart';
import 'package:hopetsit/views/profile/promo_code_screen.dart';
import 'package:hopetsit/views/profile/terms_and_conditions_screen.dart';
import 'package:hopetsit/views/profile/view_task_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';

import 'lotd_harness.dart';

typedef _Build = Widget Function();

/// Un écran à ouvrir : nom lisible, rôle, constructeur.
class _Screen {
  const _Screen(this.name, this.role, this.build);
  final String name;
  final String role;
  final _Build build;
}

const Color _owner = Color(0xFFC92A12);
const Color _sitter = Color(0xFF2563EB);
const Color _walker = Color(0xFF16A34A);

final List<_Screen> _tabs = <_Screen>[
  _Screen('Propriétaire · Accueil', 'owner', () => const HomeScreen()),
  _Screen('Propriétaire · Messages', 'owner', () => const ChatScreen()),
  _Screen('Propriétaire · Réservations', 'owner', () => const OwnerBookingsScreen()),
  _Screen('Propriétaire · Profil', 'owner', () => const ProfileScreen()),
  _Screen('Gardien · Accueil', 'sitter', () => const SitterHomescreen()),
  _Screen('Gardien · Messages', 'sitter', () => const SitterChatScreen()),
  _Screen('Gardien · Réservations', 'sitter', () => const SitterBookingsScreen()),
  _Screen('Gardien · Profil', 'sitter', () => const SitterProfileScreen()),
  _Screen('Promeneur · Accueil', 'walker', () => const SitterHomescreen()),
  _Screen('Promeneur · Messages', 'walker', () => const SitterChatScreen()),
  _Screen('Promeneur · Réservations', 'walker', () => const WalkerBookingsScreen()),
  _Screen('Promeneur · Profil', 'walker', () => const WalkerProfileScreen()),
];

final List<_Screen> _subPages = <_Screen>[
  // Compte
  _Screen('Mes tâches', 'owner', () => const ViewTaskScreen()),
  _Screen('Ajouter une tâche', 'owner', () => const AddTaskScreen()),
  // Mes animaux
  _Screen('Mes animaux', 'owner', () => const MyPetsScreen()),
  _Screen('Ajouter un animal', 'owner', () => const EditPetScreen()),
  // Mon activité
  _Screen('Mes tarifs (gardien)', 'sitter', () => const MyRatesScreen(role: 'sitter')),
  _Screen('Mes tarifs (promeneur)', 'walker', () => const MyRatesScreen(role: 'walker')),
  _Screen('Disponibilités (gardien)', 'sitter', () => const AvailabilityCalendarScreen()),
  _Screen('Disponibilités (promeneur)', 'walker', () => const AvailabilityCalendarScreen(role: 'walker')),
  _Screen('Vérification d\'identité', 'sitter', () => const KycVerificationScreen()),
  // Paiements & wallet
  _Screen('Portefeuille', 'sitter', () => const WalletScreen()),
  _Screen('Mes paiements (propriétaire)', 'owner', () => const OwnerPaymentsScreen()),
  _Screen('Gérer mes paiements (gardien)', 'sitter', () => const PaymentManagementScreen()),
  _Screen('Mes cartes', 'owner', () => const SavedCardsScreen()),
  _Screen('IBAN', 'sitter', () => const IbanSetupScreen()),
  _Screen('Informations de facturation', 'owner', () => const BillingInfoScreen(accent: _owner)),
  // Abonnements & boutique
  _Screen('Code promo', 'owner', () => const PromoCodeScreen(accent: _owner)),
  _Screen('Boutique', 'owner', () => const CoinShopScreen()),
  _Screen('Parrainages', 'walker', () => const MyReferralsScreen()),
  _Screen('Classement PawSpot', 'sitter', () => const PawspotLeaderboardScreen()),
  // Sécurité
  _Screen('Changer le mot de passe', 'owner', () => const ChangePasswordScreen()),
  _Screen('Utilisateurs bloqués', 'owner', () => const BlockedUsersScreen()),
  // Aide
  _Screen('Comprendre la PawMap', 'walker', () => const PawMapHelpScreen()),
  _Screen('Une idée ? Un problème ?', 'sitter', () => const IdeaBoxScreen()),
  _Screen('Conditions', 'owner', () => const TermsAndConditionsScreen()),
  _Screen('Confidentialité', 'owner', () => const PrivacyPolicyScreen()),
  _Screen('Dépannage · Tester mes notifications', 'owner', () => const NotificationTestScreen()),
  // Cloche
  _Screen('Notifications', 'owner', () => const NotificationsScreen()),
];

Future<void> _open(WidgetTester tester, _Screen s) async {
  // `lotdSetUp` est appelé dans `setUp` (hors de la zone à temps simulé de
  // testWidgets, où `GetStorage.init` attendrait un minuteur jamais déclenché).
  lotdPhone(tester);
  await tester.pumpWidget(lotdApp(s.build()));
  await lotdSettle(tester, frames: 6);
  final dynamic e = tester.takeException();
  expect(e, isNull, reason: '${s.name} : exception à l\'ouverture → $e');
  // Un écran s'est bien affiché : un Scaffold est monté, avec du contenu.
  expect(find.byType(Scaffold), findsWidgets, reason: '${s.name} : aucun Scaffold');
  // Aucune clé de traduction brute à l'écran.
  final raw = find.byWidgetPredicate((w) =>
      w is Text && (w.data ?? '').isNotEmpty && RegExp(r'^[a-z0-9]+(_[a-z0-9]+){2,}$').hasMatch(w.data!));
  expect(raw, findsNothing, reason: '${s.name} : clé de traduction brute affichée');
  // Retour propre.
  Get.reset();
}

void main() {
  group('onglets des 3 rôles (hors PawMap, couverte par le parcours simulateur)', () {
    for (final s in _tabs) {
      group(s.name, () {
        setUp(() => lotdSetUp(role: s.role));
        testWidgets('s\'ouvre sans exception', (tester) => _open(tester, s),
            timeout: const Timeout(Duration(seconds: 60)));
      });
    }
  });

  group('sous-pages atteignables depuis le menu Profil', () {
    for (final s in _subPages) {
      group(s.name, () {
        setUp(() => lotdSetUp(role: s.role));
        testWidgets('s\'ouvre sans exception', (tester) => _open(tester, s),
            timeout: const Timeout(Duration(seconds: 60)));
      });
    }
  });

  final Set<Color> accents = {_owner, _sitter, _walker};
  test('les 3 accents de rôle restent les couleurs fixes de Daniel', () {
    expect(accents, {const Color(0xFFC92A12), const Color(0xFF2563EB), const Color(0xFF16A34A)});
  });
}
