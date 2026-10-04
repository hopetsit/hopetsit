// 611 (PAM, 04/10/2026) — Daniel : « as-tu vérifié qu'on peut se faire un
// itinéraire entre amis ? ». Ce fichier rejoue :
//   1. ami hors direct : l'itinéraire vise la VRAIE position renvoyée par le
//      serveur (règle A, `approx:false`), jamais un point flouté gardé en mémoire ;
//   2. ami EN DIRECT : la destination suit l'ami (recalcul au-delà de 50 m, ou
//      30 s et 10 m), puis s'arrête proprement quand il coupe son direct ;
//   3. non-ami (position floutée ~1 km) : pas de bouton Itinéraire (choix le
//      plus honnête : un trajet vers un point faux trompe) ;
//   4. bouton présent sur la fiche d'un ami, absent sur une fiche floutée ;
//   5. textes 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/v565/pawmap611_i18n.dart';
import 'package:hopetsit/views/map/widgets/pawmap_route611.dart';
import 'package:hopetsit/views/map/widgets/pawmap_sheets.dart';

LatLng _north(LatLng p, double m) => LatLng(p.latitude + m / 111320, p.longitude);

class _DirApi implements ApiClient {
  Map<String, dynamic>? q;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParameters, Map<String, String>? headers, bool requiresAuth = false}) async {
    q = queryParameters;
    return {'points': [{'lat': 1, 'lng': 1}, {'lat': 2, 'lng': 2}], 'distanceMeters': 10, 'durationSeconds': 5};
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('1. ami hors direct : destination = position exacte du serveur', () {
    final world = <Map<String, dynamic>>[
      // vieux point FLOUTÉ en mémoire (avant que l'amitié soit connue)
      {'id': 'cam', 'approx': true, 'location': {'coordinates': [-1.4300, 37.8600]}},
      // couche monde 610 : l'ami à sa VRAIE position
      {'id': 'cam', 'personIds': ['cam', 'camS'], 'approx': false, 'isFriend': true,
        'location': {'coordinates': [-1.42491, 37.85162]}},
    ];
    final d = pawRouteTarget611(personIds: const ['camS'], world: world, live: null,
        tapped: const LatLng(37.8600, -1.4300), tappedApprox: true);
    expect(d, isNotNull);
    expect(d!.dest, const LatLng(37.85162, -1.42491));
    expect(d.followLive, isFalse);
  });

  test('1b. ami en direct : destination = position du direct, suivie', () {
    final d = pawRouteTarget611(personIds: const ['cam'], world: const [],
        live: const LatLng(37.85, -1.42), tapped: const LatLng(37.86, -1.43), tappedApprox: false);
    expect(d!.dest, const LatLng(37.85, -1.42));
    expect(d.followLive, isTrue);
  });

  test('3. non-ami flouté : aucun itinéraire', () {
    final world = <Map<String, dynamic>>[
      {'id': 'bob', 'approx': true, 'location': {'coordinates': [-1.43, 37.86]}},
    ];
    expect(pawRouteTarget611(personIds: const ['bob'], world: world, live: null,
        tapped: const LatLng(37.86, -1.43), tappedApprox: true), isNull);
  });

  test('2. suivi d\'un ami qui bouge : 50 m, ou 30 s et 10 m ; jamais en rafale', () {
    final f = PawRouteFollow611();
    final t0 = DateTime(2026, 10, 4, 18);
    const a = LatLng(37.85, -1.42);
    f.start('cam', a, t0);
    expect(f.shouldRecompute(_north(a, 20), t0.add(const Duration(seconds: 5))), isFalse);
    expect(f.shouldRecompute(_north(a, 60), t0.add(const Duration(seconds: 5))), isTrue);
    expect(f.shouldRecompute(_north(a, 12), t0.add(const Duration(seconds: 31))), isTrue);
    expect(f.shouldRecompute(_north(a, 5), t0.add(const Duration(seconds: 90))), isFalse);
    f.mark(_north(a, 60), t0.add(const Duration(seconds: 5)));
    expect(f.shouldRecompute(_north(a, 70), t0.add(const Duration(seconds: 6))), isFalse);
    f.stop();
    expect(f.friendId, isNull);
    expect(f.shouldRecompute(_north(a, 500), t0.add(const Duration(minutes: 5))), isFalse);
  });

  Widget sheet(PawMapMemberData m, VoidCallback? dir) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, __) => GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('fr'),
          home: Scaffold(
            body: SizedBox(
              height: 800,
              child: PawMapMemberSheet(
                member: m, viewerRole: 'owner', viewerLoggedIn: true,
                friendState: m.isFriend ? PawFriendState.friends : PawFriendState.idle,
                priceLabel: '', onBook: () {}, onProfile: () {}, onMessage: () {},
                onFriend: () {}, onDirections: dir, onPropose: () {}, onSignup: () {},
              ),
            ),
          ),
        ),
      );

  testWidgets('4. fiche d\'un ami : bouton Itinéraire ; fiche floutée : aucun', (t) async {
    var tapped = 0;
    await t.pumpWidget(sheet(const PawMapMemberData(id: 'cam', role: 'owner', name: 'Cam', isFriend: true),
        pawDirectionsAllowed611(approx: false) ? () => tapped++ : null));
    await t.pump();
    await t.tap(find.byKey(const ValueKey<String>('member_directions')));
    expect(tapped, 1);
    await t.pumpWidget(sheet(const PawMapMemberData(id: 'bob', role: 'sitter', name: 'Bob', approx: true),
        pawDirectionsAllowed611(approx: true) ? () => tapped++ : null));
    await t.pump();
    expect(find.byKey(const ValueKey<String>('member_directions')), findsNothing);
  });

  test('5. 9 langues', () {
    for (final l in const ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      for (final k in const ['pm611_route_follow', 'pm611_route_friend_stopped']) {
        expect((pawmap611I18n[l]![k] ?? '').trim(), isNotEmpty, reason: '$l $k');
      }
    }
  });

  test('D. itinéraire vers un ami : friendId envoyé au serveur (gratuit), rien vers un lieu', () async {
    Get.testMode = true;
    Get.reset();
    final api = _DirApi();
    Get.put<ApiClient>(api);
    final c = PawSpotController();
    await c.fetchDirections(from: const LatLng(1, 1), to: const LatLng(2, 2), friendId: 'cam123');
    expect(api.q!['friendId'], 'cam123');
    await c.fetchDirections(from: const LatLng(1, 1), to: const LatLng(2, 2));
    expect(api.q!.containsKey('friendId'), isFalse);
  });
}
