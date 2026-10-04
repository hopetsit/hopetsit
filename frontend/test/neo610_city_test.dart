// v610 NEO (Daniel, 04/10 : « on peut écrire n'importe quoi ») — la ville se
// CHOISIT partout : suggestions dès 2 lettres, choix dans la liste, « Ma
// position » ou carte. Du texte tapé n'est jamais accepté.
//
// Champ partagé `CityLocationPicker` (inscription e-mail, Google/Apple, profil
// des 3 rôles, publier une demande, coordonnées avant réservation) + règles des
// écrans qui ne passent pas par un Form (assistant d'inscription, Google/Apple).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/localization/v565/neo610_i18n.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/views/auth/social_city_screen.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';

import 'lotd_harness.dart';

/// Faux Nominatim : « Lyo » → Lyon (France), Lyons (USA).
final List<Uri> _queries = <Uri>[];
http.Client _nominatim() => MockClient((http.Request req) async {
      _queries.add(req.url);
      final q = (req.url.queryParameters['q'] ?? '').toLowerCase();
      final out = <Map<String, dynamic>>[];
      if ('lyon'.startsWith(q) || q.startsWith('lyo')) {
        out.add(<String, dynamic>{
          'lat': '45.7578', 'lon': '4.8320',
          'address': <String, dynamic>{'city': 'Lyon', 'country': 'France'},
        });
        out.add(<String, dynamic>{
          'lat': '43.0', 'lon': '-77.0',
          'address': <String, dynamic>{'town': 'Lyons', 'country': 'United States'},
        });
      }
      return http.Response(jsonEncode(out), 200,
          headers: <String, String>{'content-type': 'application/json; charset=utf-8'});
    });

class _Host extends StatefulWidget {
  const _Host({required this.ctrl, this.onPick});
  final TextEditingController ctrl;
  final void Function(String, double, double)? onPick;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final formKey = GlobalKey<FormState>();
  String detected = '';
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(children: <Widget>[
              CityLocationPicker(
                cityController: widget.ctrl,
                onGetLocation: () {
                  // Comme les écrans : la position trouvée remplit le champ.
                  setState(() => detected = 'Nice');
                  widget.ctrl.text = 'Nice';
                },
                isGettingLocation: busy,
                detectedCity: detected,
                onLocationSelected: widget.onPick,
              ),
              const TextField(key: Key('other_field')),
            ]),
          ),
        ),
      );
}

Future<_HostState> _mount(WidgetTester t, TextEditingController ctrl,
    {void Function(String, double, double)? onPick,
    Brightness brightness = Brightness.light}) async {
  lotdPhone(t);
  await t.pumpWidget(lotdApp(_Host(ctrl: ctrl, onPick: onPick), brightness: brightness));
  await lotdSettle(t, frames: 2);
  return t.state<_HostState>(find.byType(_Host));
}

Finder get _field => find.byKey(const Key('city610_field'));

Future<void> _type(WidgetTester t, String text) async {
  await t.tap(_field);
  await t.enterText(_field, text);
  await t.pump(const Duration(milliseconds: 400)); // délai anti-rafale 350 ms
  await lotdSettle(t, frames: 2);
}

Future<void> _blur(WidgetTester t) async {
  await t.tap(find.byKey(const Key('other_field')));
  await lotdSettle(t, frames: 2);
}

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    _queries.clear();
    CityLocationPicker.httpClientForTests = _nominatim();
  });
  tearDown(() async {
    CityLocationPicker.httpClientForTests = null;
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('champ ville partagé', () {
    testWidgets('texte libre : refusé (« Choisis ta ville dans la liste »)', (t) async {
      final ctrl = TextEditingController();
      final host = await _mount(t, ctrl);
      await _type(t, 'nimportequoi');
      await _blur(t);
      expect(cityPickedFromList610(ctrl), isFalse);
      expect(host.formKey.currentState!.validate(), isFalse);
      await lotdSettle(t, frames: 1);
      expect(find.text('Choisis ta ville dans la liste (ou touche « Ma position »).'),
          findsWidgets, reason: 'message d\'erreur + aide sous le champ');
      expect(find.byKey(const Key('city610_pick_hint')), findsOneWidget);
    });

    testWidgets('suggestions dès 2-3 lettres, un appui = ville + coordonnées', (t) async {
      final ctrl = TextEditingController();
      final picks = <List<Object>>[];
      final host = await _mount(t, ctrl, onPick: (c, la, ln) => picks.add(<Object>[c, la, ln]));
      await _type(t, 'Lyo');
      expect(_queries.single.host, 'nominatim.openstreetmap.org',
          reason: 'même source gratuite qu\'avant (aucun service payant)');
      expect(find.text('Lyon'), findsOneWidget);
      expect(find.text('Lyons'), findsOneWidget);
      await t.tap(find.text('Lyon'));
      await lotdSettle(t, frames: 2);
      expect(ctrl.text, 'Lyon');
      expect(picks.single, <Object>['Lyon', 45.7578, 4.8320]);
      expect(cityPickedFromList610(ctrl), isTrue);
      expect(host.formKey.currentState!.validate(), isTrue);
    });

    testWidgets('ville choisie puis retouchée à la main : de nouveau refusée', (t) async {
      final ctrl = TextEditingController();
      final host = await _mount(t, ctrl);
      await _type(t, 'Lyo');
      await t.tap(find.text('Lyon'));
      await lotdSettle(t, frames: 2);
      await _type(t, 'Lyon centre-ville bidon');
      await _blur(t);
      expect(cityPickedFromList610(ctrl), isFalse);
      expect(host.formKey.currentState!.validate(), isFalse);
    });

    testWidgets('« lyon » tapé exactement puis quitté : la suggestion est prise', (t) async {
      final ctrl = TextEditingController();
      final picks = <String>[];
      await _mount(t, ctrl, onPick: (c, _, __) => picks.add(c));
      await _type(t, 'lyon');
      await _blur(t);
      expect(ctrl.text, 'Lyon');
      expect(picks, <String>['Lyon']);
      expect(cityPickedFromList610(ctrl), isTrue);
    });

    testWidgets('touche Entrée : la 1re suggestion, jamais le texte brut', (t) async {
      final ctrl = TextEditingController();
      await _mount(t, ctrl);
      await _type(t, 'Lyo');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await lotdSettle(t, frames: 2);
      expect(ctrl.text, 'Lyon');
      expect(cityPickedFromList610(ctrl), isTrue);
    });

    testWidgets('« Ma position » : la ville trouvée est acceptée d\'un appui', (t) async {
      final ctrl = TextEditingController();
      final host = await _mount(t, ctrl);
      expect(find.text('Ma position'), findsOneWidget, reason: 'libellé clair (avant : « Auto »)');
      await t.tap(find.byKey(const Key('city610_auto_chip')));
      await lotdSettle(t, frames: 2);
      expect(ctrl.text, 'Nice');
      expect(cityPickedFromList610(ctrl), isTrue);
      expect(host.formKey.currentState!.validate(), isTrue);
    });

    testWidgets('ville déjà dans le profil à l\'ouverture : acceptée (comptes existants)', (t) async {
      final ctrl = TextEditingController(text: 'Asnières-sur-Seine');
      final host = await _mount(t, ctrl);
      expect(host.formKey.currentState!.validate(), isTrue);
    });

    testWidgets('aide lisible en mode sombre (contraste ≥ 4,5)', (t) async {
      final ctrl = TextEditingController();
      await _mount(t, ctrl, brightness: Brightness.dark);
      await _type(t, 'xx');
      await _blur(t);
      final hint = find.descendant(
          of: find.byKey(const Key('city610_pick_hint')), matching: find.byType(Text));
      final fg = t.widget<Text>(hint).style!.color!;
      final bg = ((t.widget<Container>(find.byKey(const Key('city610_pick_hint'))).decoration)
              as BoxDecoration)
          .color!;
      final la = fg.computeLuminance(), lb = bg.computeLuminance();
      final ratio = (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });

  group('assistant d\'inscription (3 rôles)', () {
    for (final role in <String>['pet_owner', 'pet_sitter', 'pet_walker']) {
      test('$role : ville tapée sans choix → refusée ; choisie → acceptée', () {
        final c = SignUpController(userType: role, authRepository: Get.find<AuthRepository>());
        c.cityController.text = 'nimportequoi';
        expect(c.validateStep(1), 'city610_pick_from_list');
        markCityPicked610(c.cityController, 'nimportequoi'); // = choix dans la liste
        expect(c.validateStep(1), isNot('city610_pick_from_list'));
        expect(c.validateStep(1), isNot('signup_error_city_required'));
      });
    }

    test('position GPS sans texte : toujours acceptée (comme avant)', () {
      final c = SignUpController(userType: 'pet_owner', authRepository: Get.find<AuthRepository>());
      c.userLatitude.value = -35.0;
      c.userLongitude.value = -30.0;
      c.selectedServices.add('walk');
      expect(c.validateStep(1), isNull);
    });
  });

  group('inscription Google / Apple', () {
    testWidgets('« Créer mon compte » avec une ville tapée : refusé, rien n\'est envoyé', (t) async {
      lotdPhone(t);
      await t.pumpWidget(lotdApp(const SocialCityScreen(provider: 'google', userType: 'pet_owner')));
      await lotdSettle(t, frames: 2);
      await t.tap(_field);
      await t.enterText(_field, 'nimportequoi');
      await lotdSettle(t, frames: 2);
      final before = lotdRequests.length;
      await t.ensureVisible(find.text('Créer mon compte'));
      await t.tap(find.text('Créer mon compte'));
      await lotdSettle(t, frames: 4);
      expect(find.textContaining('Choisis ta ville dans la liste'), findsWidgets);
      expect(lotdRequests.length, before, reason: 'aucun appel de connexion');
      await lotdSettle(t, frames: 20);
    });
  });

  test('les 4 textes ajoutés existent dans les 9 langues, non vides', () {
    const langs = <String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    final keys = neo610I18n['en']!.keys.toSet();
    expect(keys.length, 4);
    for (final l in langs) {
      expect(neo610I18n[l]!.keys.toSet(), keys, reason: l);
      for (final v in neo610I18n[l]!.values) {
        expect(v.trim(), isNotEmpty, reason: l);
      }
    }
  });
}
