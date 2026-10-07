// 613 §9 (ZOE, 07/10/2026) — mesuré sur l'émulateur Android (APK release,
// banc local à 35 gardiens + 35 promeneurs à Paris) : une PROMENADE publiée
// part en e-mail aux 35 promeneurs seulement (serveur : `rolesForServices`),
// mais la confirmation affichait « Envoyée à 70 gardiens et promeneurs ».
// Le nombre et le mot suivent désormais le rôle réellement prévenu.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/services/supply_city600.dart';
import 'package:http/http.dart' as http;

import 'lotd_harness.dart';

void main() {
  setUp(() async {
    await lotdSetUp(role: 'owner');
    resetSupplyCache600();
  });

  test('supply par rôle : promeneurs / gardiens / total, cache commun', () async {
    lotdResponder = (http.Request req) => <String, dynamic>{'sitters': 35, 'walkers': 35, 'total': 70};
    expect(await fetchSupplyTotal600('Paris', onlyRole: 'walker'), 35);
    lotdResponder = (http.Request req) => <String, dynamic>{'sitters': 1, 'walkers': 1, 'total': 2};
    expect(await fetchSupplyTotal600('Paris', onlyRole: 'sitter'), 35, reason: 'cache 10 min');
    expect(await fetchSupplyTotal600('Paris'), 70, reason: 'sans rôle : total, inchangé');
    resetSupplyCache600();
    lotdResponder = (http.Request req) => <String, dynamic>{'sitters': 4, 'walkers': 0, 'total': 4};
    expect(await fetchSupplyTotal600('Lyon', onlyRole: 'walker'), isNull,
        reason: '0 promeneur : aucun chiffre (rien d’inventé)');
    expect(await fetchSupplyTotal600('Lyon', onlyRole: 'sitter'), 4);
    resetSupplyCache600();
    lotdResponder = (http.Request req) => <String, dynamic>{'total': 9};
    expect(await fetchSupplyTotal600('Nice', onlyRole: 'walker'), isNull,
        reason: 'serveur sans détail par rôle : aucun chiffre');
  });

  test('textes « Envoyée à N promeneurs / gardiens » présents dans les 9 langues', () {
    final keys = AppTranslations().keys;
    for (final lang in <String>['en_US', 'fr_FR', 'es_ES', 'de_DE', 'it_IT', 'pt_PT', 'ko_KR', 'ja_JP', 'pl_PL']) {
      final m = keys[lang] ?? keys[lang.split('_').first];
      expect(m, isNotNull, reason: lang);
      for (final k in <String>['zoe613_sent_to_walkers', 'zoe613_sent_to_sitters']) {
        expect(m![k], isNotNull, reason: '$lang $k');
        expect(m[k]!.contains('{n}'), isTrue, reason: '$lang $k');
      }
    }
  });

  test('confirmation : nombre RÉEL renvoyé par le serveur, sinon texte honnête (9 langues)', () {
    final keys = AppTranslations().keys;
    Get.addTranslations(keys);
    Get.locale = const Locale('fr', 'FR');
    String msg(Map<String, dynamic> r, String role) =>
        PublishReservationRequestController.publishedMessage613(r, role);
    expect(msg(<String, dynamic>{'post': <String, dynamic>{}, 'notified': 35}, 'walker'), 'Envoyée à 35 promeneurs');
    expect(msg(<String, dynamic>{'post': <String, dynamic>{}, 'notified': 4}, 'sitter'), 'Envoyée à 4 gardiens');
    // Anti-doublon : 0 prévenu → jamais « Envoyée à 0 », jamais l'offre de la ville.
    expect(msg(<String, dynamic>{'post': <String, dynamic>{}, 'notified': 0}, 'walker'),
        'Ta demande est publiée : les prestataires proches la verront.');
    // Ancien serveur / délai dépassé : pas de chiffre du tout.
    expect(msg(<String, dynamic>{'post': <String, dynamic>{}}, 'walker'),
        'Ta demande est publiée : les prestataires proches la verront.');
    for (final lang in <String>['en_US', 'fr_FR', 'es_ES', 'de_DE', 'it_IT', 'pt_PT', 'ko_KR', 'ja_JP', 'pl_PL']) {
      final v = keys[lang]!['zoe613_published_no_count'];
      expect(v, isNotNull, reason: lang);
      expect(v!.contains(RegExp(r'\d')), isFalse, reason: '$lang : aucun chiffre');
    }
  });
}
