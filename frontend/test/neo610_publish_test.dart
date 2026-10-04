// v610 NEO (Daniel, 04/10, capture « Publier une demande » + vocal) :
//   1. HEURE INVISIBLE : après avoir choisi 14:00 dans l'horloge, la case
//      Début/Fin restait rose pâle « surlignée en blanc », sans l'heure ;
//   2. POSITION AUTO : un appui remplit la ville (permission, géocodage, champ) ;
//   3. VILLE CHOISIE DANS UNE LISTE : du texte tapé n'est jamais accepté ;
//   4. « Il manque : Choisis où se passe le service » : le choix s'enregistre et
//      le message disparaît ; un appui sur « Il manque » amène à l'étape.
// Écrit pour tourner AVANT le correctif (il doit échouer) et APRÈS (vert) :
// il n'utilise que des API qui existaient déjà.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/services/supply_city600.dart';
import 'package:hopetsit/utils/publish_draft600.dart';
import 'package:hopetsit/views/pet_owner/reservation_request/publish_reservation_request_screen.dart';

import 'lotd_harness.dart';

Finder _k(String k) => find.byKey(Key(k), skipOffstage: false);

Future<PublishReservationRequestController> _open(WidgetTester t,
    {String? service = 'pet_sitting', Brightness brightness = Brightness.light}) async {
  lotdPhone(t);
  await t.pumpWidget(lotdApp(const Scaffold(body: SizedBox.shrink()), brightness: brightness));
  await lotdSettle(t, frames: 1);
  Get.to(() => PublishReservationRequestScreen(initialServiceType: service));
  await lotdSettle(t);
  return Get.find<PublishReservationRequestController>();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Couleur de fond réelle derrière un texte : le 1er Container décoré au-dessus.
Color _bgBehind(WidgetTester t, Finder text) {
  for (final e in find.ancestor(of: text, matching: find.byType(Container)).evaluate()) {
    final d = (e.widget as Container).decoration;
    if (d is BoxDecoration && d.color != null) return d.color!;
  }
  fail('aucun fond trouvé derrière le texte');
}

Color _colorOf(WidgetTester t, Finder text) => t.widget<Text>(text).style!.color!;

/// Ouvre l'horloge depuis la case qui affiche [from], tape [hh]:[mm], valide.
Future<void> _pickTimeVia(WidgetTester t, String from, String hh, String mm) async {
  final cell = find.text(from).first;
  await t.ensureVisible(cell);
  await lotdSettle(t, frames: 2);
  await t.tap(cell);
  await lotdSettle(t);
  final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
  expect(fields, findsNWidgets(2), reason: 'horloge en mode saisie : heures + minutes');
  await t.enterText(fields.at(0), hh);
  await t.enterText(fields.at(1), mm);
  await lotdSettle(t, frames: 2);
  await t.tap(find.text('OK'));
  await lotdSettle(t);
}

class _FakeLocation implements LocationService {
  _FakeLocation(this.data, {this.failure = ''});
  final Map<String, dynamic>? data;
  final String failure;
  @override
  String lastFailure = '';
  @override
  Future<Map<String, dynamic>?> getUserLocationWithCity() async {
    lastFailure = data == null ? failure : '';
    return data;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _fillAllButCity(PublishReservationRequestController c) {
  if (c.selectedServiceType.value == null) c.selectServiceType('pet_sitting');
  c.toggleSpecies('dog');
  c.selectServiceLocation('at_owner');
  c.startDate.value = DateTime(2026, 12, 1);
  c.onDatesChanged();
}

void main() {
  setUpAll(() async {
    for (final l in <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl']) {
      await initializeDateFormatting(l);
    }
  });
  setUp(() async {
    await lotdSetUp(role: 'owner');
    resetSupplyCache600();
    clearPublishDraft600();
  });
  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('1. heure choisie = heure lisible, jour ET nuit', () {
    for (final b in <Brightness>[Brightness.dark, Brightness.light]) {
      testWidgets('${b.name} : 14:00 choisi dans l\'horloge s\'affiche aussitôt, contraste ≥ 4,5', (t) async {
        final c = await _open(t, brightness: b);
        expect(find.text('08:00'), findsOneWidget, reason: 'heure par défaut de la garde');
        await _pickTimeVia(t, '08:00', '14', '00');
        expect(c.startTime.value, const TimeOfDay(hour: 14, minute: 0));
        final shown = find.text('14:00');
        expect(shown, findsOneWidget, reason: 'l\'heure apparaît dans la case, sans rien valider d\'autre');
        final ratio = _contrast(_colorOf(t, shown), _bgBehind(t, shown));
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'heure lisible (${b.name}) : contraste mesuré ${ratio.toStringAsFixed(2)}');
        // Même règle pour la fin (20:00 par défaut).
        final end = find.text('20:00');
        expect(_contrast(_colorOf(t, end), _bgBehind(t, end)), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('2. « Ma position » remplit la ville toute seule', () {
    testWidgets('position trouvée : ville + coordonnées + étape Lieu faite', (t) async {
      final c = PublishReservationRequestController(
          locationService: _FakeLocation(<String, dynamic>{
        'city': 'Lyon', 'latitude': -35.0, 'longitude': -30.0,
      }));
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const Scaffold(body: SizedBox.shrink())));
      Get.put(c);
      c.cityController.clear();
      await c.detectLocation();
      await lotdSettle(t);
      expect(c.cityController.text, 'Lyon');
      expect(c.userLat.value, -35.0);
      expect(c.userLng.value, -30.0);
      expect(c.stepCityDone, isTrue);
      _fillAllButCity(c);
      expect(c.firstMissingField, isNull, reason: 'la ville trouvée par la position est acceptée');
      expect(find.textContaining('Trouvé : Lyon'), findsOneWidget, reason: 'confirmation affichée');
      await lotdSettle(t, frames: 20);
    });

    testWidgets('permission refusée : la ville reste vide et le message dit pourquoi', (t) async {
      final c = PublishReservationRequestController(
          locationService: _FakeLocation(null, failure: 'denied'));
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const Scaffold(body: SizedBox.shrink())));
      Get.put(c);
      c.cityController.clear();
      await c.detectLocation();
      await lotdSettle(t);
      expect(c.cityController.text, isEmpty);
      expect(find.textContaining('Autorise la localisation'), findsOneWidget);
      expect(c.isGettingLocation.value, isFalse);
      await lotdSettle(t, frames: 20);
    });
  });

  group('3. la ville se choisit, elle ne se tape pas', () {
    testWidgets('texte libre tapé dans le champ : « Publier » refuse, rien ne part', (t) async {
      final c = await _open(t);
      _fillAllButCity(c);
      expect(c.firstMissingField, isNull, reason: 'ville du profil (Paris) acceptée');
      final field = find.descendant(
          of: find.byType(Form), matching: find.byType(TextFormField)).at(0);
      // Le 1er TextFormField du formulaire est le champ ville (étape 4).
      await t.ensureVisible(field);
      await lotdSettle(t, frames: 2);
      await t.tap(field);
      await t.enterText(field, 'nimportequoi 123');
      await lotdSettle(t, frames: 2);
      FocusManager.instance.primaryFocus?.unfocus();
      await lotdSettle(t, frames: 2);
      expect(c.cityController.text, 'nimportequoi 123');
      expect(c.firstMissingField, isNotNull,
          reason: 'une ville tapée sans être choisie dans la liste ne doit pas suffire');
      expect(c.stepCityDone, isFalse);
      final before = lotdRequests.where((r) => r.method == 'POST' && r.path.endsWith('/posts')).length;
      await c.submit();
      await lotdSettle(t, frames: 20);
      final after = lotdRequests.where((r) => r.method == 'POST' && r.path.endsWith('/posts')).length;
      expect(after, before, reason: 'aucune demande publiée avec une ville inventée');
    });
  });

  group('4. lieu du service : le choix compte et le message disparaît', () {
    testWidgets('« Chez moi » choisi : plus de « Choisis où se passe le service »', (t) async {
      final c = await _open(t);
      c.toggleSpecies('dog');
      c.startDate.value = DateTime(2026, 12, 1);
      c.onDatesChanged();
      await lotdSettle(t, frames: 2);
      expect(c.firstMissingField, 'serviceLocation');
      expect(find.textContaining('Choisis où se passe le service'), findsOneWidget);

      await t.ensureVisible(_k('svc587_opt_at_owner'));
      await lotdSettle(t, frames: 2);
      await t.tap(_k('svc587_opt_at_owner'));
      await lotdSettle(t, frames: 2);
      expect(c.serviceLocation.value, 'at_owner');
      expect(c.firstMissingField, isNull);
      expect(find.textContaining('Choisis où se passe le service'), findsNothing);

      await t.ensureVisible(_k('svc587_opt_at_sitter'));
      await t.tap(_k('svc587_opt_at_sitter'));
      await lotdSettle(t, frames: 2);
      expect(c.serviceLocation.value, 'at_sitter', reason: 'changer d\'avis marche aussi');
    });

    testWidgets('un appui sur « Il manque » amène à l\'étape à compléter', (t) async {
      final c = await _open(t);
      c.toggleSpecies('dog');
      c.startDate.value = DateTime(2026, 12, 1);
      c.onDatesChanged();
      await lotdSettle(t, frames: 2);
      // On descend tout en bas du formulaire.
      await t.drag(find.byType(SingleChildScrollView).first, const Offset(0, -4000));
      await lotdSettle(t);
      final tile = _k('svc587_opt_at_owner');
      final screenH = t.view.physicalSize.height / t.view.devicePixelRatio;
      expect(t.getRect(tile).bottom < 0 || t.getRect(tile).top > screenH, isTrue,
          reason: 'le choix du lieu est hors de l\'écran');
      await t.tap(find.textContaining('Choisis où se passe le service'));
      await lotdSettle(t, frames: 6);
      final r = t.getRect(tile);
      expect(r.top >= 0 && r.bottom <= screenH, isTrue,
          reason: 'après l\'appui, « Chez moi » est à l\'écran (rect $r)');
    });
  });
}
