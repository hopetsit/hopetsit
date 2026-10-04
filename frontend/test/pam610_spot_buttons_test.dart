// 610 (PAM, 04/10/2026) — Daniel : les boutons des PawSpots doivent être
// prouvés par de VRAIS appuis, pas par la lecture du code. On pose la vraie
// barre de gauche (PawMapRail) et la vraie ligne « PawSpot » de « Mes
// abonnements sur la carte », branchées sur les vraies actions de la carte
// (PawSpotActions610), avec un appareil photo / un envoi / des fiches simulés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:hopetsit/views/map/widgets/pawmap_rail.dart';
import 'package:hopetsit/views/map/widgets/pawmap_spots610.dart';
import 'package:hopetsit/views/map/widgets/pawmap_subscriptions_section.dart';

import 'lotd_harness.dart';

class _World {
  bool layer = false;
  final List<bool> saved = <bool>[];
  int loads = 0;
  int lists = 0;
  int pickers = 0;
  String? photoPath = '/tmp/spot.jpg';
  String? uploaded = 'https://cdn/spot.jpg';
  final List<String> uploads = <String>[];
  final List<(PawSpotLatLng610, String)> creates = <(PawSpotLatLng610, String)>[];
  bool createResult = true;
  final List<PawSpotLatLng610> after = <PawSpotLatLng610>[];
  int failed = 0;

  late final PawSpotActions610 actions = PawSpotActions610(
    layerOn: () => layer,
    saveLayer: (on) {
      layer = on;
      saved.add(on);
    },
    loadNearby: () async => loads++,
    takePhoto: () async => photoPath,
    uploadPhoto: (p) async {
      uploads.add(p);
      return uploaded;
    },
    openCreate: (at, url) async {
      creates.add((at, url));
      return createResult;
    },
    openList: () async => lists++,
    startPicking: () => pickers++,
    mapCenter: () => (lat: -35.0, lng: -30.0),
    gps: () => (lat: -35.0003, lng: -30.0002),
    afterCreated: (at) async => after.add(at),
    onUploadFailed: () => failed++,
    spotsLoaded: () => 0,
  );
}

Widget _rail(_World w) => lotdApp(Scaffold(
      body: SingleChildScrollView(
        child: PawMapRail(
          order: kPawRailDefaultOrder,
          onTap: (id) {
            switch (id) {
              case 'photo':
                w.actions.photo();
              case 'spots':
                w.actions.spots();
              case 'tag':
                w.actions.tag();
            }
          },
          onLongPress: (_) {},
          onCustomize: () {},
        ),
      ),
    ));

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    lotdResponder = (http.Request req) => const <String, dynamic>{};
  });

  testWidgets('« Photo du spot » : appareil → envoi → fiche à MA position GPS → spot sur ma carte',
      (t) async {
    lotdPhone(t);
    final w = _World();
    await t.pumpWidget(_rail(w));
    await lotdSettle(t);
    await t.tap(find.byKey(const ValueKey<String>('rail_photo')));
    await lotdSettle(t);
    expect(w.uploads, ['/tmp/spot.jpg']);
    expect(w.creates.single.$1, (lat: -35.0003, lng: -30.0002));
    expect(w.creates.single.$2, 'https://cdn/spot.jpg');
    expect(w.after.single, (lat: -35.0003, lng: -30.0002));
  });

  testWidgets('« Photo du spot » : photo annulée → rien ; envoi raté → message, pas de fiche',
      (t) async {
    lotdPhone(t);
    final w = _World()..photoPath = null;
    await t.pumpWidget(_rail(w));
    await lotdSettle(t);
    await t.tap(find.byKey(const ValueKey<String>('rail_photo')));
    await lotdSettle(t);
    expect(w.uploads, isEmpty);
    expect(w.creates, isEmpty);
    w
      ..photoPath = '/tmp/b.jpg'
      ..uploaded = null;
    await t.tap(find.byKey(const ValueKey<String>('rail_photo')));
    await lotdSettle(t);
    expect(w.failed, 1);
    expect(w.creates, isEmpty);
  });

  testWidgets('« Taguer un lieu » : couche allumée + viseur ; Valider → fiche au point visé',
      (t) async {
    lotdPhone(t);
    final w = _World();
    await t.pumpWidget(_rail(w));
    await lotdSettle(t);
    await t.tap(find.byKey(const ValueKey<String>('rail_tag')));
    await lotdSettle(t);
    expect(w.layer, isTrue);
    expect(w.pickers, 1);
    await w.actions.confirmTag((lat: -35.001, lng: -30.002));
    expect(w.creates.single.$1, (lat: -35.001, lng: -30.002));
    expect(w.creates.single.$2, '');
    expect(w.after.single, (lat: -35.001, lng: -30.002));
  });

  testWidgets('« Voir les spots » : couche éteinte → allumée, chargée, puis la liste', (t) async {
    lotdPhone(t);
    final w = _World();
    await t.pumpWidget(_rail(w));
    await lotdSettle(t);
    await t.tap(find.byKey(const ValueKey<String>('rail_spots')));
    await lotdSettle(t);
    expect(w.saved, [true]);
    expect(w.loads, 1);
    expect(w.lists, 1);
  });

  testWidgets('interrupteur PawSpot (« Mes abonnements sur la carte ») : éteint ↔ allumé', (t) async {
    lotdPhone(t);
    final w = _World()..layer = true;
    Widget host() => lotdApp(Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setS) => PawMapSubscriptionsSection(lines: [
              PawMapSubscriptionLine(
                id: 'spot',
                name: 'PawSpot',
                subtitle: '',
                icon: Icons.stars_rounded,
                color: const Color(0xFFE8920A),
                owned: true,
                on: w.layer,
                onToggle: () async {
                  await w.actions.toggle();
                  setS(() {});
                },
                onDiscover: () {},
              ),
            ]),
          ),
        ));
    await t.pumpWidget(host());
    await lotdSettle(t);
    await t.tap(find.byKey(const ValueKey<String>('pawmap_sub_switch_spot')));
    await lotdSettle(t);
    expect(w.layer, isFalse);
    expect(w.loads, 0);
    await t.tap(find.byKey(const ValueKey<String>('pawmap_sub_switch_spot')));
    await lotdSettle(t);
    expect(w.layer, isTrue);
    expect(w.loads, 1);
    expect(w.saved, [false, true]);
  });
}
