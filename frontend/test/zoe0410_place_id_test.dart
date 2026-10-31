// 04/10/2026 (ZOE) — première vraie demande enregistrée « Parigi » : la liste
// OpenStreetMap répond dans la langue de l'app. Le champ ville retient
// désormais l'identifiant OSM du lieu choisi (« R7444 », le même dans toutes
// les langues), que la publication d'une demande joint aux coordonnées.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/widgets/city_location_picker.dart';

import 'lotd_harness.dart';

final List<Uri> _queries = <Uri>[];
http.Client _nominatimIt() => MockClient((http.Request req) async {
      _queries.add(req.url);
      final out = <Map<String, dynamic>>[
        <String, dynamic>{
          'osm_type': 'relation', 'osm_id': 7444,
          'lat': '48.8534951', 'lon': '2.3483915',
          'address': <String, dynamic>{'city': 'Parigi', 'country': 'Francia'},
        },
        <String, dynamic>{
          'lat': '-0.80', 'lon': '120.18',
          'address': <String, dynamic>{'town': 'Parigi', 'country': 'Indonesia'},
        },
      ];
      return http.Response(jsonEncode(out), 200,
          headers: <String, String>{'content-type': 'application/json; charset=utf-8'});
    });

Finder get _field => find.byKey(const Key('city610_field'));

Future<void> _mount(WidgetTester t, TextEditingController ctrl,
    void Function(String, double, double) onPick) async {
  lotdPhone(t);
  await t.pumpWidget(lotdApp(Scaffold(
    body: SingleChildScrollView(
      child: Column(children: <Widget>[
        CityLocationPicker(
          cityController: ctrl,
          onGetLocation: () {},
          isGettingLocation: false,
          detectedCity: '',
          onLocationSelected: onPick,
        ),
        const TextField(key: Key('other_field')),
      ]),
    ),
  )));
  await lotdSettle(t, frames: 2);
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    _queries.clear();
    CityLocationPicker.httpClientForTests = _nominatimIt();
  });
  tearDown(() async {
    CityLocationPicker.httpClientForTests = null;
    await Get.deleteAll(force: true);
    Get.reset();
  });

  testWidgets('« Parigi » choisi dans la liste : coordonnées + identifiant OSM R7444', (t) async {
    final ctrl = TextEditingController();
    final picks = <List<Object>>[];
    await _mount(t, ctrl, (c, la, ln) => picks.add(<Object>[c, la, ln]));
    await t.tap(_field);
    await t.enterText(_field, 'Pari');
    await t.pump(const Duration(milliseconds: 400));
    await lotdSettle(t, frames: 2);
    expect(find.text('Parigi'), findsNWidgets(2), reason: '2 suggestions (France, Indonésie)');
    await t.tap(find.text('Parigi').at(0));
    await lotdSettle(t, frames: 2);
    expect(picks.single, <Object>['Parigi', 48.8534951, 2.3483915]);
    expect(cityPlaceIdOf610(ctrl), 'R7444');
  });

  testWidgets('ville retouchée à la main après le choix : plus d identifiant', (t) async {
    final ctrl = TextEditingController();
    await _mount(t, ctrl, (_, __, ___) {});
    await t.tap(_field);
    await t.enterText(_field, 'Pari');
    await t.pump(const Duration(milliseconds: 400));
    await lotdSettle(t, frames: 2);
    await t.tap(find.text('Parigi').at(0));
    await lotdSettle(t, frames: 2);
    expect(cityPlaceIdOf610(ctrl), 'R7444');
    await t.enterText(_field, 'Parigi 11');
    await t.pump(const Duration(milliseconds: 400));
    await lotdSettle(t, frames: 2);
    expect(cityPlaceIdOf610(ctrl), isNull);
  });

  testWidgets('suggestion sans osm_type/osm_id : aucun identifiant inventé', (t) async {
    final ctrl = TextEditingController();
    await _mount(t, ctrl, (_, __, ___) {});
    await t.tap(_field);
    await t.enterText(_field, 'Pari');
    await t.pump(const Duration(milliseconds: 400));
    await lotdSettle(t, frames: 2);
    await t.tap(find.text('Parigi').at(1));
    await lotdSettle(t, frames: 2);
    expect(ctrl.text, 'Parigi');
    expect(cityPlaceIdOf610(ctrl), isNull);
  });
}
