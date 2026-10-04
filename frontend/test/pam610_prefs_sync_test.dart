// 610 (PAM, 04/10/2026) — Daniel : « réparer tout maintenant ». Mesuré au
// simulateur : le mode nuit choisi sur l'appareil A était effacé dès que
// l'appareil B bougeait sa carte (copie locale renvoyée EN BLOC parce que la
// caméra venait de bouger). Ici : A choisit la nuit, B bouge la carte, B
// rouvre la carte → la nuit est gardée, B n'envoie jamais que sa caméra.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';

import 'package:hopetsit/services/map_prefs_service.dart';

import 'lotd_harness.dart';

/// Le compte (serveur 610) : clé par clé, horodatage par clé, jamais de
/// valeur plus ancienne que celle enregistrée.
class _Account {
  final Map<String, dynamic> pawMap = <String, dynamic>{
    'nightMode': false,
    'layers': <String, dynamic>{'everyone': true, 'pawspots': true},
    'rail': <String>['around', 'spots'],
    'fieldAt': <String, dynamic>{},
  };

  void patch(Map<String, dynamic> body) {
    final pm = (body['pawMap'] as Map).cast<String, dynamic>();
    final at = ((body['pawMapAt'] as Map?) ?? const {}).cast<String, dynamic>();
    final fa = pawMap['fieldAt'] as Map<String, dynamic>;
    void put(String f, void Function() write) {
      final t = DateTime.tryParse('${at[f]}') ?? DateTime.now();
      final prev = DateTime.tryParse('${fa[f]}');
      if (prev != null && t.isBefore(prev)) return;
      write();
      fa[f] = t.toIso8601String();
    }
    for (final e in pm.entries) {
      if (MapPrefsService.subKeyed.contains(e.key) && e.value is Map) {
        for (final s in (e.value as Map).entries) {
          put('${e.key}__${s.key}', () {
            pawMap[e.key] = {...(pawMap[e.key] as Map? ?? const {}), s.key: s.value};
          });
        }
      } else {
        put(e.key, () => pawMap[e.key] = e.value);
      }
    }
  }
}

List<Map<String, dynamic>> _patches() => lotdRequests
    .where((r) => r.method == 'PATCH' && r.path.endsWith('/users/me/map-prefs'))
    .map((r) => r.body!)
    .toList();

void main() {
  late _Account account;

  setUp(() async {
    await lotdSetUp(role: 'owner');
    account = _Account();
    lotdResponder = (http.Request req) {
      if (req.url.path.endsWith('/users/me/map-prefs')) {
        if (req.method == 'PATCH') account.patch(jsonDecode(req.body) as Map<String, dynamic>);
        return <String, dynamic>{'mapVisibility': 'all', 'pawMap': account.pawMap};
      }
      return const <String, dynamic>{};
    };
  });

  /// Un « appareil » : sa propre copie locale et ses propres heures.
  MapPrefsService device(Map<String, dynamic> local, Map<String, String> at) {
    final d = MapPrefsService();
    d.prefs.assignAll(local);
    d.localAt
      ..clear()
      ..addAll(at);
    return d;
  }

  test('A choisit le mode nuit, B bouge la carte, B rouvre → la nuit est GARDÉE', () async {
    final old = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
    // A : allume la nuit.
    final a = device({'nightMode': false}, {'nightMode': old});
    a.update({'nightMode': true});
    await a.flush();
    expect(_patches().last['pawMap'], {'nightMode': true});
    expect(account.pawMap['nightMode'], isTrue);

    // B : copie locale ANCIENNE (nuit éteinte), il bouge sa carte.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = device(
      {'nightMode': false, 'layers': {'everyone': true, 'pawspots': true}, 'rail': ['around', 'spots']},
      {'nightMode': old},
    );
    b.update({'camera': {'lat': -35.0, 'lng': -30.0, 'zoom': 12.0}});
    await b.flush();
    expect(_patches().last['pawMap'].keys.toList(), ['camera']);
    expect(account.pawMap['nightMode'], isTrue, reason: 'B n\'a pas écrasé la nuit de A');

    // B rouvre la carte : il prend la nuit du compte, ne renvoie pas la sienne.
    final before = _patches().length;
    final changed = await b.loadFromAccount();
    expect(changed, isTrue);
    expect(b.nightMode, isTrue);
    expect(b.camera?['zoom'], 12.0);
    final sent = _patches().skip(before).toList();
    for (final p in sent) {
      expect((p['pawMap'] as Map).containsKey('nightMode'), isFalse);
    }
    expect(account.pawMap['nightMode'], isTrue);
  });

  test('instantané complet des calques : seul le calque touché part', () async {
    final s = device({'layers': {'everyone': true, 'pawspots': true, 'places': true}}, const {});
    s.update({'layers': {'everyone': false, 'pawspots': true, 'places': true}});
    await s.flush();
    expect(_patches().last['pawMap'], {'layers': {'everyone': false}});
    expect((_patches().last['pawMapAt'] as Map).keys, ['layers__everyone']);
    expect(account.pawMap['layers'], {'everyone': false, 'pawspots': true});
  });

  test('rien de changé → aucun envoi ; deux calques en 2 s → les deux partent', () async {
    final s = device({'nightMode': true, 'layers': {'everyone': true, 'pawspots': true}}, const {});
    s.update({'nightMode': true});
    await s.flush();
    expect(_patches(), isEmpty);
    s.update({'layers': {'everyone': false}});
    s.update({'layers': {'pawspots': false}});
    await s.flush();
    expect(_patches().single['pawMap'], {'layers': {'everyone': false, 'pawspots': false}});
  });

  test('fusion pure : calque changé ailleurs plus récemment gagne, ordre des barres local plus récent repart', () {
    final t0 = DateTime.utc(2026, 10, 4, 10).toIso8601String();
    final t1 = DateTime.utc(2026, 10, 4, 11).toIso8601String();
    final r = MapPrefsService.mergeRemote(
      local: {'layers': {'everyone': true, 'pawspots': true}, 'rail': ['spots', 'around'], 'verifiedOnly': false},
      localAt: {'layers__everyone': t0, 'rail': t1},
      remote: {
        'layers': {'everyone': false, 'pawspots': false},
        'rail': ['around', 'spots'],
        'verifiedOnly': true,
        'fieldAt': {'layers__everyone': t1, 'rail': t0},
      },
    );
    expect(r.prefs['layers'], {'everyone': false, 'pawspots': false});
    expect(r.prefs['rail'], ['spots', 'around']);
    expect(r.prefs['verifiedOnly'], isTrue);
    expect(r.push, {'rail': ['spots', 'around']});
    expect(r.pushAt, {'rail': t1});
    expect(r.changed, isTrue);
  });
}
