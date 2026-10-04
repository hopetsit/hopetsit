// 611 (ZOE, 04/10/2026) — contrat app ↔ serveur et textes du point 1 de
// PROCHAIN_BUILD_611.md (animal perdu / trouvé GRATUIT pour tous) :
//   · refus 409 LOST_PET_ACTIVE du serveur → contrôleur marqué « alerte en
//     cours » avec l'alerte reçue ; /quota → `lostPet` lu ; clôture = DELETE ;
//   · classement synchronisé avec backend/src/utils/mapReportRules610.js ;
//   · textes 9 langues (mêmes clés, @date protégé, branchés dans v565),
//     « Comprendre la PawMap » (help610_alerts_b) à jour ;
//   · boutique : « plusieurs alertes animal perdu en même temps ».
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/alerts611_i18n.dart';
import 'package:hopetsit/localization/v565/pawmap610_i18n.dart';
import 'package:hopetsit/models/map_report_model.dart';

import 'lotd_harness.dart';

const _point = LatLng(-35, -30); // zone fictive

Future<List<http.Request>> _withApi(
  Future<void> Function(MapReportController c) body,
  http.Response Function(http.Request req) respond,
) async {
  final seen = <http.Request>[];
  final api = ApiClient(
    httpClient: MockClient((http.Request req) async {
      seen.add(req);
      return respond(req);
    }),
    storage: Get.find<GetStorage>(),
  );
  await Get.delete<ApiClient>(force: true);
  Get.put<ApiClient>(api, permanent: true);
  await body(MapReportController());
  return seen;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

void main() {
  setUp(() async => lotdSetUp(role: 'owner'));

  test('refus 409 LOST_PET_ACTIVE : alerte en cours retenue, rien de créé', () async {
    late MapReportController ctl;
    await _withApi((c) async {
      ctl = c;
      final r = await c.createReport(type: 'lost_pet', point: _point);
      expect(r, isNull);
    }, (req) => _json(<String, dynamic>{
          'code': 'LOST_PET_ACTIVE',
          'limit': 1,
          'active': 1,
          'activeReportId': 'r-active',
          'activeExpiresAt': '2026-10-06T08:00:00.000Z',
          'upgradeUrl': '/subscriptions/plans',
        }, 409));
    expect(ctl.lostPetActive.value, isTrue);
    expect(ctl.comfortLimitReached.value, isFalse, reason: '409 ≠ quota confort');
    expect(ctl.premiumRequired.value, isFalse);
    expect(ctl.lostPetQuota.value?.blocked, isTrue);
    expect(ctl.lostPetQuota.value?.activeReportId, 'r-active');
    expect(ctl.lostPetQuota.value?.activeExpiresAt?.toUtc(), DateTime.utc(2026, 10, 6, 8));
    expect(ctl.reports, isEmpty);
  });

  test('/quota : lostPet lu ; clôture = DELETE de l\'alerte puis compteur relu', () async {
    var closed = false;
    late MapReportController ctl;
    final seen = await _withApi((c) async {
      ctl = c;
      await c.loadQuota();
      expect(c.lostPetQuota.value?.blocked, isTrue);
      expect(c.lostPetQuota.value?.activeReportId, 'r-active');
      final ok = await c.closeLostPetAlert('r-active');
      expect(ok, isTrue);
    }, (req) {
      if (req.method == 'DELETE') {
        closed = true;
        return _json(<String, dynamic>{'message': 'Deleted.'});
      }
      return _json(<String, dynamic>{
        'isPremium': false,
        'comfort': <String, dynamic>{'unlimited': false, 'limit': 1, 'used': 0, 'remaining': 1},
        'lostPet': closed
            ? <String, dynamic>{'unlimited': false, 'limit': 1, 'active': 0, 'remaining': 1}
            : <String, dynamic>{
                'unlimited': false, 'limit': 1, 'active': 1, 'remaining': 0,
                'activeReportId': 'r-active',
              },
      });
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.where((r) => r.method == 'DELETE').single.url.path, endsWith('/map-reports/r-active'));
    expect(ctl.lostPetQuota.value?.blocked, isFalse);
    expect(ctl.lostPetActive.value, isFalse);
  });

  test('abonné : quota illimité → jamais bloqué', () {
    final q = LostPetQuota.fromJson(<String, dynamic>{'unlimited': true, 'limit': null});
    expect(q.blocked, isFalse);
  });

  test('classement identique au serveur : perdu/trouvé gratuits, plus aucun type réservé', () {
    final js = File('../backend/src/utils/mapReportRules610.js').readAsStringSync();
    List<String> list(String name) {
      final m = RegExp('const $name = \\[([^\\]]*)\\]').firstMatch(js)!;
      return RegExp(r"'([a-z_]+)'").allMatches(m.group(1)!).map((x) => x.group(1)!).toList()
        ..sort();
    }
    expect(list('PREMIUM_CREATE_TYPES'), isEmpty);
    expect(ReportTypes.premiumCreateTypes, isEmpty);
    expect([...ReportTypes.petAlertTypes]..sort(), list('PET_ALERT_TYPES'));
    expect(RegExp(r'const LOST_PET_ACTIVE_LIMIT = 1;').hasMatch(js), isTrue);
    expect(ReportTypes.isFree('found_pet'), isTrue);
    expect(ReportTypes.isFree('lost_pet'), isFalse, reason: 'perdu : gratuit mais 1 à la fois');
    expect(ReportTypes.isLostPet('lost_pet'), isTrue);
  });

  test('textes : 9 langues, mêmes clés, @date protégé, branchés, aide à jour', () {
    const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    const full = {
      'en': 'en_US', 'fr': 'fr_FR', 'es': 'es_ES', 'de': 'de_DE', 'it': 'it_IT',
      'pt': 'pt_PT', 'ko': 'ko_KR', 'ja': 'ja_JP', 'pl': 'pl_PL',
    };
    final ref = alerts611I18n['en']!.keys.toSet();
    final tr = AppTranslations().keys;
    final helpEn = pawmap610I18n['en']!['help610_alerts_b']!;
    for (final l in langs) {
      final m = alerts611I18n[l]!;
      expect(m.keys.toSet(), ref, reason: l);
      for (final k in ref) {
        expect(m[k]!.trim(), isNotEmpty, reason: '$l $k');
        expect(m[k]!.contains('@date'), alerts611I18n['en']![k]!.contains('@date'), reason: '$l $k');
        expect(tr[full[l]]![k], m[k], reason: 'branché dans v565 : $l $k');
        if (l != 'en') expect(m[k], isNot(alerts611I18n['en']![k]), reason: 'resté en anglais : $l $k');
      }
      final help = pawmap610I18n[l]!['help610_alerts_b']!;
      expect(tr[full[l]]!['help610_alerts_b'], help, reason: l);
      if (l != 'en') expect(help, isNot(helpEn), reason: l);
    }
    expect(tr['fr_FR']!['alerts611_active_title'], 'Tu as déjà une alerte en cours');
    expect(tr['fr_FR']!['shop611_lost_multi'], 'Plusieurs alertes animal perdu en même temps');
    final helpFr = tr['fr_FR']!['help610_alerts_b']!;
    expect(helpFr, contains('ou un animal trouvé est gratuit et sans limite'));
    expect(helpFr, contains('Animal perdu : gratuit pour tous, 1 alerte active à la fois sans abonnement'));
    expect(helpFr, contains('bon Samaritain'));
  });

  test('boutique : « plusieurs alertes animal perdu en même temps » dans les 3 abonnements', () {
    final src = File('lib/views/boost/coin_shop_screen.dart').readAsStringSync();
    expect("'shop611_lost_multi'.tr".allMatches(src).length, greaterThanOrEqualTo(4));
    expect("'shop611_lost_free'.tr".allMatches(src).length, greaterThanOrEqualTo(3));
    for (final k in ['shop611_pp_free_body', 'shop611_pp_plus_body', 'shop611_ps_plus_body']) {
      expect(src.contains("'$k'.tr"), isTrue, reason: k);
    }
    for (final k in ['shop610_pp_free_body', 'shop610_pp_plus_body', 'shop610_ps_plus_body']) {
      expect(src.contains("'$k'.tr"), isFalse, reason: 'ancien texte sans perdu/trouvé : $k');
    }
  });

  test('feuille Signaler : plus de cadenas perdu/trouvé dans le code', () {
    final src = File('lib/views/map/widgets/create_report_sheet.dart').readAsStringSync();
    expect(src.contains('_buildPremiumSection'), isFalse);
    expect(src.contains('ReportTypes.petAlertTypes'), isTrue);
    expect(src.contains("'alerts610_section_lost_locked'"), isFalse);
  });
}
