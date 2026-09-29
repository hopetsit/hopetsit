// v602 (ZOE, 29/09/2026) — Daniel : « vérifie que toutes les notifications,
// dans la cloche et sur l'app, renvoient bien à la tâche précise ».
//
// Table type → route du routeur commun (push + cloche), avec la MÊME `data`
// que celle envoyée par le serveur (backend/src/**/sendNotification). Chaque
// type du catalogue serveur (locales/fr/notifications.json) doit avoir une
// destination, et chaque destination doit être un chemin que DeepLinkService
// sait ouvrir.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/deep_link_service.dart';

const b = '6a5007807b1c2d3e4f5a6b7c'; // bookingId
const c = '6a976145aa1c2d3e4f5a6b7c'; // conversationId
const p = '6a0000000000000000000001'; // postId
const a = '6a0000000000000000000002'; // applicationId
const r = '6a0000000000000000000003'; // reportId
const s = '6a0000000000000000000004'; // spotId
const u = '6a0000000000000000000005'; // userId

String route(String type, Map<String, dynamic> data, String role) =>
    DeepLinkService.routeForNotification(type, data, role: role);

void main() {
  // type, rôle destinataire, data serveur, route attendue
  final cases = <List<Object>>[
    ['NEW_MESSAGE', 'owner', {'conversationId': c, 'messageId': b}, '/chat/$c'],
    ['NEW_MESSAGE', 'walker', {'conversationId': c}, '/chat/$c'],
    ['CHAT_AUTO_WELCOME', 'sitter', {'conversationId': c}, '/chat/$c'],
    ['BOOKING_PAID_CHAT_UNLOCKED', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['booking_new', 'sitter', {'bookingId': b, 'ownerId': u}, '/request/$b'],
    ['booking_new', 'walker', {'bookingId': b, 'ownerId': u}, '/request/$b'],
    ['booking_accepted', 'owner', {'bookingId': b}, '/pay?bookingId=$b'],
    ['booking_rejected', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['BOOKING_MUTUALLY_ACCEPTED', 'owner', {'bookingId': b}, '/pay?bookingId=$b'],
    ['BOOKING_MUTUALLY_ACCEPTED', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['booking_paid', 'walker', {'bookingId': b}, '/bookings/$b'],
    ['booking_paid_owner', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['BOOKING_COMPLETED', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['booking_cancelled_by_owner', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['booking_cancelled_by_provider', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['booking_refunded', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['application_new', 'owner', {'applicationId': a, 'postId': p}, '/application/$a'],
    ['application_accepted', 'sitter', {'applicationId': a, 'bookingId': b}, '/bookings/$b'],
    ['application_rejected', 'sitter', {'applicationId': a, 'postId': p}, '/post/$p'],
    ['application_rejected_other_accepted', 'walker', {'applicationId': a, 'postId': p}, '/post/$p'],
    ['new_request_nearby', 'sitter', {'postId': p}, '/post/$p'],
    ['new_request_for_you', 'walker', {'postId': p}, '/post/$p'],
    ['PAYMENT_SUCCESS', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['PAYMENT_FAILED', 'owner', {'bookingId': b}, '/pay?bookingId=$b'],
    ['wallet_credited', 'sitter', {'bookingId': b, 'amount': '20'}, '/wallet'],
    ['payout_initiated', 'sitter', {'bookingId': b}, '/wallet'],
    ['payout_completed', 'walker', {'bookingId': b}, '/wallet'],
    ['payout_failed', 'sitter', {'bookingId': b}, '/wallet'],
    ['withdrawal_initiated', 'sitter', {'transactionId': u}, '/wallet'],
    ['withdrawal_completed', 'sitter', {'transactionId': u}, '/wallet'],
    ['withdrawal_failed', 'walker', {'transactionId': u}, '/wallet'],
    ['kyc_verified', 'sitter', {'kycStatus': 'verified'}, '/identity'],
    ['kyc_rejected', 'walker', {'kycStatus': 'rejected'}, '/identity'],
    ['kyc_payment_succeeded', 'sitter', {'kycStatus': 'pending_verification'}, '/identity'],
    ['NEW_REVIEW', 'sitter', {'reviewId': u, 'rating': 5}, '/reviews'],
    ['PREMIUM_ACHIEVED', 'owner', {'count': 10}, '/profile'],
    ['TOP_SITTER_ACHIEVED', 'sitter', {'count': 10}, '/profile'],
    ['REFERRAL_CREDITED', 'owner', {'referredUserId': u}, '/shop/1'],
    ['map_boost_activated', 'sitter', {'tier': 'x'}, '/shop/0'],
    ['profile_boost_activated', 'walker', {'tier': 'x'}, '/shop/0'],
    ['subscription_activated', 'owner', {'plan': 'monthly'}, '/shop/1'],
    ['subscription_activated', 'owner', {'plan': 'premium_yearly'}, '/shop/3'],
    ['chat_addon_activated', 'owner', {'intervalDays': '30'}, '/chat'],
    ['pawspot_validated', 'owner', {'spotId': s}, '/spot/$s'],
    ['pawspot_popular', 'sitter', {'spotId': s}, '/spot/$s'],
    ['friend_request_received', 'owner', {'friendshipId': u, 'fromUserId': u}, '/friends/requests'],
    ['friend_request_accepted', 'owner', {'byUserId': u, 'byUserRole': 'walker'}, '/member/walker/$u'],
    ['friend_request_accepted', 'owner', {'byUserId': u}, '/friends'],
    ['family_invitation_received', 'owner', {'invitationId': u}, '/friends/requests'],
    ['family_member_added', 'owner', {'addedBy': u}, '/friends/family'],
    ['family_invitation_accepted', 'owner', {'memberUserId': u}, '/friends/family'],
    ['family_invitation_refused', 'owner', {'memberUserId': u}, '/friends/family'],
    ['service_started', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['service_completion_request', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['service_confirmed', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['service_disputed', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['service_start_due', 'walker', {'bookingId': b}, '/bookings/$b'],
    ['service_end_soon', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['service_start_t72h', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['VISIT_REPORT', 'owner', {'bookingId': b, 'reportId': r}, '/bookings/$b'],
    ['walk_started', 'owner', {'bookingId': b}, '/walk/$b'],
    ['walk_finished', 'owner', {'bookingId': b}, '/walk/$b'],
    ['handover_pickup_soon', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['handover_return_soon', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['handover_pickup_overdue', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['handover_pickup_auto', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['handover_return_auto', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['handover_picked_up', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['handover_pickup_confirmed', 'sitter', {'bookingId': b}, '/bookings/$b'],
    ['handover_returned', 'owner', {'bookingId': b}, '/bookings/$b'],
    ['handover_return_confirmed', 'walker', {'bookingId': b}, '/bookings/$b'],
    ['sos_pet_nearby', 'sitter', {'reportId': r}, '/alert/$r'],
    ['lost_pet_sighting', 'owner', {'reportId': r}, '/alert/$r'],
  ];

  group('table type → route (données du serveur)', () {
    for (final t in cases) {
      test('${t[0]} (${t[1]})', () {
        expect(
          route(t[0] as String, Map<String, dynamic>.from(t[2] as Map), t[1] as String),
          t[3],
        );
      });
    }
  });

  test('aucun type du catalogue serveur ne tombe sur la simple liste des notifications', () {
    final file = File('../backend/src/locales/fr/notifications.json');
    if (!file.existsSync()) return; // dépôt partiel
    final types = (jsonDecode(file.readAsStringSync()) as Map).keys.cast<String>();
    final data = <String, dynamic>{
      'bookingId': b, 'conversationId': c, 'postId': p, 'applicationId': a,
      'reportId': r, 'spotId': s, 'byUserId': u, 'byUserRole': 'owner',
    };
    final orphans = <String>[
      for (final t in types)
        if (route(t, data, 'owner') == '/notifications' ||
            route(t, data, 'sitter') == '/notifications')
          t,
    ];
    expect(orphans, isEmpty, reason: 'types sans destination : $orphans');
  });

  test('chaque destination est un chemin que DeepLinkService ouvre', () {
    final src = File('lib/services/deep_link_service.dart').readAsStringSync();
    final firsts = <String>{};
    for (final t in cases) {
      final path = (t[3] as String).split('?').first;
      firsts.add(path.split('/')[1]);
    }
    for (final f in firsts) {
      expect(src, contains("first == '$f'"), reason: 'chemin /$f non géré');
    }
  });

  test('push : la route de l\'app passe avant celle du serveur, sauf suivi en direct', () {
    expect(
      DeepLinkService.resolvePushRoute(
        'booking_new', {'bookingId': b, 'route': '/bookings/$b'}, role: 'sitter'),
      '/request/$b',
    );
    expect(
      DeepLinkService.resolvePushRoute(
        'live_tracking_request_received', {'conversationId': c, 'route': '/chat/$c'}),
      '/chat/$c',
    );
    expect(
      DeepLinkService.resolvePushRoute('type_futur', {'route': '/wallet'}),
      '/wallet',
    );
    expect(DeepLinkService.resolvePushRoute('type_futur', {}), '/notifications');
  });

  test('anciennes notifications sans id : repli sur la liste la plus proche', () {
    expect(route('booking_new', {}, 'sitter'), '/bookings');
    expect(route('application_rejected', {'applicationId': a}, 'sitter'), '/bookings');
    expect(route('NEW_MESSAGE', {}, 'owner'), '/chat');
    expect(route('sos_pet_nearby', {}, 'owner'), '/map');
    expect(route('pawspot_validated', {}, 'owner'), '/shop/2');
  });
}
