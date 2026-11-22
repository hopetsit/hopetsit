// 644 (BOB, 22/11/2026) — page des candidats du propriétaire, parité site et
// serveur du 22/11 :
//  - textes des 9 langues, repris mot pour mot du site ;
//  - modèle : `priceOffer2211View` / `payLater2211View` / `serviceType`
//    (absents = comme avant) ;
//  - tri « confiance d'abord » (mêmes cas que website/scripts/test-cand3110.mjs)
//    + PawBoost gardé devant + « Plus loin de chez toi » ;
//  - « Proposer mon prix » : états, bornes, messages par code ;
//  - « Réserver (prénom), payer plus tard » : deux temps, état réservé,
//    « Payer maintenant », pas de paiement ouvert tout seul ;
//  - « Lui parler avant de réserver » : 4 messages prêts → champ de la conversation ;
//  - « Ajoute ta photo » : une fois par demande, jamais bloquant ;
//  - petits écrans (360×640, 320×568) et gros caractères : pas de débordement ;
//  - notification `price_offer_2211` : comportement actuel (liste des notifications).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/v565/cand644_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/cand644.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/shared/photo_nudge644.dart';

import 'lotd_harness.dart';

const _langs = <String>['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const _bookingId = '6ae3b1bee86658cbe6d9e34c';
const _appOnly644 = <String>{'cand644_ask_hint', 'cand644_offer_hint', 'cand644_offer_sent', 'cand644_offer_pending'};

// Point de la demande (zone fictive, comme le test du site).
const double _pLat = -35, _pLng = -30;

Map<String, dynamic> _app(
  String id, {
  String name = 'Imane Benali',
  double? dlat,
  double total = 120,
  double rate = 10,
  String status = 'pending',
  String role = 'sitter',
  bool photo = false,
  bool verified = false,
  bool boosted = false,
  String? serviceType,
  String? bookingId,
  Map<String, dynamic>? pricing,
  Map<String, dynamic>? offer,
  Map<String, dynamic>? later,
}) =>
    <String, dynamic>{
      'id': id,
      'postId': 'p1',
      'status': status,
      'createdAt': '2026-11-20T10:00:00Z',
      'description': '',
      if (serviceType != null) 'serviceType': serviceType,
      if (bookingId != null) 'bookingId': bookingId,
      role: <String, dynamic>{
        'id': 's-$id',
        'name': name,
        'currency': 'EUR',
        'rating': 0,
        'reviewsCount': 0,
        if (photo) 'avatar': {'url': 'https://img.test/$id.jpg', 'publicId': ''},
        if (verified) 'identityVerified': true,
        if (boosted) 'isBoosted': true,
        if (dlat != null) 'location': {'lat': _pLat + dlat, 'lng': _pLng},
      },
      'pricing': pricing ?? <String, dynamic>{'totalPrice': total, 'appliedRate': rate, 'unit': 'day', 'currency': 'EUR'},
      if (offer != null) 'priceOffer2211View': offer,
      if (later != null) 'payLater2211View': later,
    };

ApplicationModel _m(Map<String, dynamic> j) => ApplicationModel.fromJson(j);

/// « 84,00 EUR » au format de la langue (l'espace avant € est insécable).
String _eur(double v) => CurrencyHelper.format('EUR', v);
int? _km(ApplicationModel a) => candidateKm2610(_pLat, _pLng, a.sitter.lat, a.sitter.lng);
List<String> _sorted(List<ApplicationModel> items, {String? focus, List<String>? services}) =>
    sortCandidates644(items, kmOf: _km, highlightId: focus, postServices: services).map((x) => x.id).toList();

const _canOffer = <String, dynamic>{
  'enabled': true, 'canOffer': true, 'count': 0, 'max': 2, 'status': null, 'amount': null,
  'currency': 'EUR', 'currentTotal': 120, 'minAmount': 84, 'negotiated': false,
};
const _canReserve = <String, dynamic>{
  'enabled': true, 'canReserve': true, 'status': null, 'deadline': null, 'at': null, 'holdHours': 48,
};
const _waiting = <String, dynamic>{
  'enabled': true, 'canReserve': false, 'status': 'waiting', 'deadline': '2026-11-24T13:00:00.000Z', 'holdHours': null,
};

void main() {
  setUpAll(() {
    Get.testMode = true;
    Get.locale = const Locale('fr', 'FR');
    Get.fallbackLocale = const Locale('en', 'US');
  });

  group('i18n 644', () {
    test('9 langues, mêmes clés, jamais vides, variables gardées, paquet branché', () {
      final fr = cand644I18n['fr']!;
      expect(fr.length, 46);
      expect(cand644I18n.keys.toSet(), _langs.toSet());
      for (final l in _langs) {
        final m = cand644I18n[l]!;
        expect(m.keys.toSet(), fr.keys.toSet(), reason: l);
        for (final e in m.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$l ${e.key}');
          for (final tok in const ['{name}', '{km}', '{min}', '{max}', '{price}', '{hours}', '{date}', '{animal}']) {
            if (fr[e.key]!.contains(tok)) expect(e.value, contains(tok), reason: '$l ${e.key} $tok');
          }
        }
        expect(v565For(l)['cand644_offer_btn'], m['cand644_offer_btn'], reason: 'paquet branché ($l)');
      }
      expect(fr['cand644_ask_btn'], 'Lui parler avant de réserver');
      expect(fr['cand644_offer_btn'], 'Proposer mon prix');
      expect(fr['cand644_later_btn'], 'Réserver {name}, payer plus tard');
      expect(fr['cand644_later_text'], contains("Rien n'est débité maintenant"));
      expect(fr['cand644_far_title'], 'Plus loin de chez toi · à plus de {km} km');
      expect(fr['cand644_photo_body'], "Les propriétaires choisissent d'abord les profils avec photo.");
    });

    test('textes du site repris mot pour mot (website/src/lib/i18n/cand3110.ts)', () {
      final f = File('../website/src/lib/i18n/cand3110.ts');
      expect(f.existsSync(), isTrue, reason: 'lancer depuis frontend/ dans le dépôt complet');
      final ts = f.readAsStringSync();
      int checked = 0;
      for (final l in _langs) {
        for (final e in cand644I18n[l]!.entries) {
          if (e.key.startsWith('cand644_photo_')) continue; // propres à l'app
          // 644 (ZOE) — dans l'app la réponse arrive d'abord par notification
          // (push + cloche), l'e-mail en plus : ces 4 textes diffèrent du site.
          if (_appOnly644.contains(e.key)) continue;
          final siteKey = e.key.substring('cand644_'.length);
          expect(ts, contains('$siteKey: ${jsonEncode(e.value)}'), reason: '$l $siteKey');
          checked++;
        }
      }
      expect(checked, 38 * 9);
    });
  });

  group('644 (ZOE) — textes propres à l\'app et bandeau d\'accueil', () {
    setUp(() {
      Get.addTranslations(<String, Map<String, String>>{'fr_FR': cand644I18n['fr']!});
      Get.locale = const Locale('fr', 'FR');
      Flags644.reset();
    });

    test('réponse annoncée par notification ET e-mail, dans les 9 langues (jamais « par e-mail » seul)', () {
      const words = <String, String>{
        'fr': 'notification', 'en': 'notification', 'es': 'notificación', 'de': 'Mitteilung', 'it': 'notifica',
        'pt': 'notificação', 'pl': 'powiadomieni', 'ko': '알림', 'ja': '通知',
      };
      for (final l in _langs) {
        for (final k in _appOnly644) {
          expect(cand644I18n[l]![k], contains(words[l]!), reason: '$l $k');
        }
      }
      expect(cand644I18n['fr']!['cand644_ask_hint'], contains('{name}'));
      expect(cand644I18n['fr']!['cand644_offer_hint'], allOf(contains('{min}'), contains('{max}'), contains('{name}')));
    });

    test('bandeau d\'accueil : « Réservé jusqu\'au … » pour un « payer plus tard » en cours, sinon titre d\'avant', () {
      final held = _m(_app('a2', status: 'accepted', bookingId: _bookingId, later: _waiting));
      final chosen = _m(_app('a1', status: 'accepted', bookingId: _bookingId));
      final paid = _m(_app('a3', status: 'accepted', bookingId: _bookingId, later: {..._waiting, 'status': 'paid'}));
      final t = heldBannerTitle644(_bookingId, [held]);
      expect(t, isNotNull);
      expect(t, startsWith('Réservé jusqu\'au '));
      expect(t, isNot(contains('{date}')));
      expect(heldBannerTitle644(_bookingId, [chosen]), isNull, reason: 'choix classique : titre d\'avant');
      expect(heldBannerTitle644(_bookingId, [paid]), isNull);
      expect(heldBannerTitle644('6ae3b1bee86658cbe6d9e399', [held]), isNull, reason: 'autre réservation');
      expect(heldBannerTitle644('', [held]), isNull);
      Flags644.payLater = false;
      expect(heldBannerTitle644(_bookingId, [held]), isNull, reason: 'option coupée = titre d\'avant');
      Flags644.reset();
    });
  });

  group('modèle', () {
    test('champs absents (ancien serveur) = comme avant', () {
      final a = _m(_app('a1'));
      expect(a.priceOffer, isNull);
      expect(a.payLater, isNull);
      expect(a.serviceType, '');
      expect(a.status, 'pending');
      expect(a.pricing!.totalPrice, 120);
      expect(isHeld644(a), isFalse);
      expect(offerNote644(a, 'Imane').text, '');
    });

    test('vues du serveur lues telles quelles', () {
      final a = _m(_app('a1', serviceType: 'dog_walking', offer: {
        ..._canOffer, 'status': 'pending', 'amount': 99.5, 'canOffer': false,
      }, later: _canReserve));
      expect(a.serviceType, 'dog_walking');
      expect(a.priceOffer!.canOffer, isFalse);
      expect(a.priceOffer!.status, 'pending');
      expect(a.priceOffer!.amount, 99.5);
      expect(a.priceOffer!.currency, 'EUR');
      expect(a.priceOffer!.currentTotal, 120);
      expect(a.priceOffer!.minAmount, 84);
      expect(a.payLater!.canReserve, isTrue);
      expect(a.payLater!.holdHours, 48);
      expect(a.payLater!.status, '');
      expect(a.payLater!.deadline, isNull);
      final w = _m(_app('a2', status: 'accepted', later: _waiting));
      expect(w.payLater!.status, 'waiting');
      expect(w.payLater!.deadline, DateTime.utc(2026, 11, 24, 13));
      expect(isHeld644(w), isTrue);
      // vue illisible : ignorée, la candidature se lit quand même
      final bad = _m({..._app('a3'), 'priceOffer2211View': 'x', 'payLater2211View': 3});
      expect(bad.priceOffer, isNull);
      expect(bad.payLater, isNull);
    });

    test('photo : objet {url} (app) ou texte (site), vide = pas de photo', () {
      expect(hasPhoto644(_m(_app('a1'))), isFalse);
      expect(hasPhoto644(_m(_app('a1', photo: true))), isTrue);
      final asText = _app('a1');
      (asText['sitter'] as Map<String, dynamic>)['avatar'] = 'https://img.test/x.jpg';
      expect(hasPhoto644(_m(asText)), isTrue);
      final blank = _app('a1');
      (blank['sitter'] as Map<String, dynamic>)['avatar'] = '   ';
      expect(hasPhoto644(_m(blank)), isFalse);
    });
  });

  group('tri (mêmes cas que le site)', () {
    test('le plus proche d\'abord, puis le moins cher, distance inconnue en dernier', () {
      final items = [
        _m(_app('a', dlat: 0.3, total: 50)),
        _m(_app('b', dlat: 0.01, total: 90)),
        _m(_app('c', dlat: 0.01, total: 60)),
        _m(_app('d', total: 10.5)),
      ];
      expect(_sorted(items), ['c', 'b', 'a', 'd']);
      // ~1 km d'arrondi : 0,9 km et 0,3 km sont à égalité (1 km) → le moins cher
      expect(_sorted([_m(_app('x', dlat: 0.008, total: 40)), _m(_app('y', dlat: 0.003, total: 30))]), ['y', 'x']);
    });

    test('le candidat de la notification passe devant ; total incohérent = inconnu', () {
      final items = [
        _m(_app('a', dlat: 0.01, total: 50)),
        _m(_app('b', dlat: 0.5, total: 20)),
        _m(_app('c', dlat: 0.01, total: 5)),
      ];
      expect(_sorted(items, focus: 'b'), ['b', 'a', 'c']);
      expect(candidateTotalValue644(_m(_app('c', total: 5))), isNull, reason: '5 < tarif 10');
      expect(candidateTotalValue644(_m(_app('s', pricing: {'totalPrice': 50, 'stale': true}))), isNull);
      expect(candidateTotalValue644(_m(_app('i', pricing: {'totalPrice': 50, 'indicative': true}))), isNull);
      expect(candidateTotalValue644(_m(_app('o', total: 64.8))), 64.8);
    });

    test('identité vérifiée d\'abord, puis l\'ordre d\'avant', () {
      final items = [
        _m(_app('pres', dlat: 0.01, total: 30)),
        _m(_app('loinV', dlat: 0.5, total: 90, verified: true)),
        _m(_app('moyen', dlat: 0.1, total: 20)),
        _m(_app('presV', dlat: 0.02, total: 80, verified: true, role: 'walker')),
      ];
      expect(_sorted(items), ['presV', 'loinV', 'pres', 'moyen']);
      expect(_sorted(items, focus: 'moyen'), ['moyen', 'presV', 'loinV', 'pres']);
      final none = [_m(_app('a', dlat: 0.3, total: 50)), _m(_app('b', dlat: 0.01, total: 90)), _m(_app('c', dlat: 0.01, total: 60))];
      expect(_sorted(none), ['c', 'b', 'a']);
    });

    test('photo d\'abord, puis identité vérifiée, puis le plus proche', () {
      final items = [
        _m(_app('presRien', dlat: 0.01, total: 30)),
        _m(_app('loinPhoto', dlat: 0.5, total: 90, photo: true)),
        _m(_app('moyenVerif', dlat: 0.1, total: 20, verified: true)),
        _m(_app('moyenPhotoVerif', dlat: 0.1, total: 80, photo: true, verified: true, role: 'walker')),
        _m(_app('presPhoto', dlat: 0.02, total: 70, photo: true)),
      ];
      expect(_sorted(items), ['moyenPhotoVerif', 'presPhoto', 'loinPhoto', 'moyenVerif', 'presRien']);
      expect(_sorted(items, focus: 'presRien'), ['presRien', 'moyenPhotoVerif', 'presPhoto', 'loinPhoto', 'moyenVerif']);
      final all = [
        _m(_app('a', dlat: 0.3, total: 50, photo: true)),
        _m(_app('b', dlat: 0.01, total: 90, photo: true)),
        _m(_app('c', dlat: 0.2, total: 60, photo: true, verified: true)),
      ];
      expect(_sorted(all), ['c', 'b', 'a']);
    });

    test('promenade / visite : plus de 10 km après tous les autres ; inconnue = proche ; personne masqué', () {
      // 0,2° ≈ 22 km ; 0,05° ≈ 6 km ; 0,09° ≈ 10 km (pas « plus de 10 »)
      final items = [
        _m(_app('loinPV', dlat: 0.2, total: 20, photo: true, verified: true)),
        _m(_app('pres', dlat: 0.05, total: 90)),
        _m(_app('limite', dlat: 0.09, total: 50)),
        _m(_app('inconnu', total: 10.5)),
        _m(_app('loin2', dlat: 0.25, total: 15)),
      ];
      expect(kFarKm644, 10);
      for (final svc in const ['dog_walking', 'home_visit']) {
        expect(_sorted(items, services: [svc]), ['pres', 'limite', 'inconnu', 'loinPV', 'loin2'], reason: svc);
        expect(isFar644(items[0], _km(items[0]), [svc]), isTrue);
        expect(isFar644(items[1], _km(items[1]), [svc]), isFalse);
        expect(isFar644(items[2], _km(items[2]), [svc]), isFalse, reason: '10 km tout juste : proche');
        expect(isFar644(items[3], _km(items[3]), [svc]), isFalse, reason: 'distance inconnue : proche');
        expect(isFar644(items[0], null, [svc]), isFalse, reason: 'demande sans point');
      }
      expect(_sorted(items, services: ['dog_walking']).length, items.length);
      expect(_sorted(items, focus: 'loin2', services: ['dog_walking']), ['loin2', 'pres', 'limite', 'inconnu', 'loinPV']);
      for (final svcs in <List<String>?>[['house_sitting'], ['day_care'], ['house_sitting', 'dog_walking'], [], null]) {
        expect(_sorted(items, services: svcs), ['loinPV', 'pres', 'limite', 'loin2', 'inconnu'], reason: '$svcs');
        expect(isFar644(items[0], _km(items[0]), svcs), isFalse);
      }
      // le service de la CANDIDATURE prime sur ceux de la demande
      final balade = _m(_app('b', dlat: 0.2, serviceType: 'dog_walking'));
      final garde = _m(_app('g', dlat: 0.2, serviceType: 'house_sitting'));
      expect(isFar644(balade, _km(balade), ['house_sitting']), isTrue);
      expect(isFar644(garde, _km(garde), ['dog_walking']), isFalse);
      // intertitre : avant le 1er « plus loin », seulement s'il reste un proche ; jamais le candidat de la notification
      final sorted = sortCandidates644(items, kmOf: _km, postServices: ['dog_walking']);
      expect(firstFarId644(sorted, kmOf: _km, postServices: ['dog_walking']), 'loinPV');
      expect(firstFarId644(sorted, kmOf: _km, postServices: ['house_sitting']), '');
      final onlyFar = [items[0], items[4]];
      expect(firstFarId644(onlyFar, kmOf: _km, postServices: ['dog_walking']), '', reason: 'tous loin : pas d\'intertitre');
      final focusFar = sortCandidates644(items, kmOf: _km, highlightId: 'loinPV', postServices: ['dog_walking']);
      expect(firstFarId644(focusFar, kmOf: _km, highlightId: 'loinPV', postServices: ['dog_walking']), 'loin2');
    });

    test('tri stable sans point de demande (ordre du serveur)', () {
      final items = [_m(_app('a', total: 50)), _m(_app('b', total: 50))];
      expect(sortCandidates644(items, kmOf: (_) => null).map((x) => x.id), ['a', 'b']);
      expect(candidateKm2610(_pLat, _pLng, _pLat + 0.01, _pLng), 1);
      expect(candidateKm2610(_pLat, _pLng, _pLat + 0.09, _pLng), 10);
    });

    test('PawBoost (règle de l\'app, build 628) gardé devant photo / identité / distance, sous « plus loin »', () {
      final items = [
        _m(_app('photoVerif', dlat: 0.01, photo: true, verified: true)),
        _m(_app('boost', dlat: 0.05, boosted: true)),
        _m(_app('boostLoin', dlat: 0.3, boosted: true)),
      ];
      expect(_sorted(items), ['boost', 'boostLoin', 'photoVerif']);
      expect(_sorted(items, focus: 'photoVerif'), ['photoVerif', 'boost', 'boostLoin']);
      expect(_sorted(items, services: ['dog_walking']), ['boost', 'photoVerif', 'boostLoin']);
    });
  });

  group('règles pures', () {
    setUp(() {
      Get.addTranslations(<String, Map<String, String>>{'fr_FR': cand644I18n['fr']!});
      Get.locale = const Locale('fr', 'FR');
      Flags644.reset();
    });

    test('montant saisi', () {
      expect(parseAmount644('100'), 100);
      expect(parseAmount644(' 99,5 '), 99.5);
      expect(parseAmount644('99.555'), 99.56);
      expect(parseAmount644('100 €'), 100);
      expect(parseAmount644(''), isNull);
      expect(parseAmount644('abc'), isNull);
      expect(parseAmount644('0'), isNull);
      expect(parseAmount644('1.2.3'), isNull);
    });

    test('bornes locales = celles du serveur (entre min et moins que le total)', () {
      expect(offerLocalCheck644(null, min: 84, max: 120), 'OFFER_TOO_LOW');
      expect(offerLocalCheck644(83.99, min: 84, max: 120), 'OFFER_TOO_LOW');
      expect(offerLocalCheck644(84, min: 84, max: 120), '');
      expect(offerLocalCheck644(119.99, min: 84, max: 120), '');
      expect(offerLocalCheck644(120, min: 84, max: 120), 'OFFER_NOT_LOWER');
      expect(offerLocalCheck644(50), '', reason: 'bornes inconnues : le serveur tranche');
    });

    test('messages d\'erreur par code', () {
      String t(String code) => offerErrorText644(code, min: 84, max: 120, currency: 'EUR');
      expect(t('OFFER_TOO_LOW'), allOf(contains('trop bas'), contains('84,00')));
      expect(t('OFFER_NOT_LOWER'), allOf(contains('inférieur'), contains('120,00')));
      expect(t('OFFER_LIMIT'), 'Tu as déjà fait tes propositions pour ce candidat.');
      for (final c in const ['OFFER_DISABLED', 'OFFER_NO_PRICE', 'OFFER_NOT_PENDING', 'DATES_REQUIRED', '']) {
        expect(t(c), "La proposition n'est pas partie. Réessaie dans un instant.", reason: c);
      }
      expect(offerErrorText644('OFFER_TOO_LOW', currency: 'EUR'), contains("n'est pas partie"), reason: 'borne inconnue');
      expect(laterErrorText644('PAY_LATER_TOO_LATE'), contains('commence trop tôt'));
      for (final c in const ['PAY_LATER_DISABLED', 'PAY_LATER_ALREADY_USED', '']) {
        expect(laterErrorText644(c), contains("n'a pas abouti"), reason: c);
      }
      for (final c in const ['OFFER_TOO_LOW', 'PAY_LATER_TOO_LATE']) {
        expect(t(c), isNot(contains(c)), reason: 'jamais le code brut');
      }
    });

    test('code lu dans la réponse du serveur', () {
      expect(apiErrorCode644(ApiException('x', statusCode: 400, details: {'code': 'OFFER_TOO_LOW'})), 'OFFER_TOO_LOW');
      expect(apiErrorCode644(ApiException('PAY_LATER_TOO_LATE: trop tard', statusCode: 409)), 'PAY_LATER_TOO_LATE');
      expect(apiErrorCode644(ApiException('Request failed', statusCode: 500)), '');
    });

    test('état de la proposition', () {
      ApplicationModel o(String status, {double? amount = 100, String appStatus = 'pending'}) =>
          _m(_app('a1', status: appStatus, offer: {..._canOffer, 'canOffer': false, 'status': status, 'amount': amount}));
      expect(offerNote644(o('pending'), 'Imane').text, 'Ta proposition de ${_eur(100)} est envoyée à Imane · réponse par notification et e-mail');
      expect(offerNote644(o('pending'), 'Imane').good, isTrue);
      expect(offerNote644(o('pending', amount: null), 'Imane').text, 'Proposition envoyée à Imane · réponse par notification et e-mail');
      expect(offerNote644(o('accepted'), 'Imane').text, 'Imane a accepté ton prix : ${_eur(100)}');
      expect(offerNote644(o('accepted'), 'Imane').good, isTrue);
      expect(offerNote644(o('declined'), 'Imane').text, 'Imane préfère garder son prix');
      expect(offerNote644(o('declined'), 'Imane').good, isFalse);
      expect(offerNote644(o('expired'), 'Imane').text, 'Ta proposition de ${_eur(100)} est restée sans réponse');
      expect(offerNote644(o('cancelled'), 'Imane').text, contains("n'est plus valable"));
      expect(offerNote644(o('inconnu'), 'Imane').text, '');
      expect(offerNote644(o('accepted', appStatus: 'accepted'), 'Imane').text, '', reason: 'déjà choisi : plus de note');
    });

    test('4 messages prêts : se parler d\'abord, animal et rôle, dates', () {
      final q = questions644(isWalker: false, animalKind: 'dog', tbd: false);
      expect(q, [
        'Pouvons-nous nous parler 10 minutes avant que je réserve ?',
        'Avez-vous déjà gardé un chien comme le mien ?',
        'Pouvez-vous passer le voir avant ?',
        'Êtes-vous disponible à ces dates ?',
      ]);
      final w = questions644(isWalker: true, animalKind: 'Chat', tbd: true);
      expect(w[1], 'Avez-vous déjà promené un chat comme le mien ?');
      expect(w[3], 'Quelles sont vos disponibilités ?');
      expect(questions644(isWalker: false, animalKind: '', tbd: false)[1], contains('un animal comme le mien'));
    });

    test('paiement à la fermeture : jamais tout seul pour un « payer plus tard » en cours', () {
      final chosen = _m(_app('a1', status: 'accepted', bookingId: _bookingId));
      final held = _m(_app('a2', status: 'accepted', bookingId: _bookingId, later: _waiting));
      final paid = _m(_app('a3', status: 'accepted', bookingId: _bookingId, later: {..._waiting, 'status': 'paid'}));
      expect(chosenBookingId644([chosen], 'p1'), _bookingId, reason: 'comme au build 628');
      expect(chosenBookingId644([held], 'p1'), isNull);
      expect(chosenBookingId644([paid], 'p1'), _bookingId, reason: 'payée → la fiche, comme avant');
      expect(chosenBookingId644([chosen], 'autre'), isNull);
      expect(chosenBookingId628([held], 'p1'), _bookingId, reason: 'l\'ancienne règle n\'est pas modifiée');
      Flags644.payLater = false;
      expect(chosenBookingId644([held], 'p1'), _bookingId, reason: 'option coupée = build 628');
      Flags644.reset();
    });

    test('échéance à l\'heure du téléphone, jamais vide', () {
      final s = heldDate644(DateTime.utc(2026, 11, 24, 13), locale: 'fr');
      expect(s.trim(), isNotEmpty);
      expect(s, contains('24'));
    });

    test('notification price_offer_2211 : aucune adresse dans le push → liste des notifications (comportement actuel)', () {
      // Champs réellement envoyés par notifyProvider (priceOffer2211.js) : applicationId, postId,
      // reminderTitle, reminderBody. Le lien signé de réponse n'est que dans l'e-mail.
      expect(
        DeepLinkService.routeForNotification('price_offer_2211', {
          'applicationId': '6ae3b1bee86658cbe6d9e34d', 'postId': '6ae3b1bee86658cbe6d9e34e',
          'reminderTitle': 'x', 'reminderBody': 'y',
        }, role: 'sitter'),
        '/notifications',
      );
      // Gabarits « payer plus tard » : même destination que le type sous lequel ils voyagent.
      const b = '6ae3b1bee86658cbe6d9e34c';
      String r(String type, String role) =>
          DeepLinkService.routeForNotification(type, {'bookingId': b, 'applicationId': b, 'postId': b}, role: role);
      expect(r('pay_later_reminder_2211', 'owner'), r('booking_accepted', 'owner'));
      expect(r('pay_later_reminder_2211', 'owner'), '/pay?bookingId=$b');
      expect(r('pay_later_released_owner_2211', 'owner'), r('application_new', 'owner'));
      expect(r('pay_later_released_provider_2211', 'sitter'), r('booking_cancelled_by_owner', 'sitter'));
      for (final t in const ['pay_later_reminder_2211', 'pay_later_released_owner_2211', 'pay_later_released_provider_2211']) {
        expect(r(t, 'owner'), isNot('/notifications'), reason: t);
        expect(r(t, 'sitter'), isNot('/notifications'), reason: t);
      }
    });
  });

  group('feuille des candidats', () {
    late List<Map<String, dynamic>> apps;
    final List<String> paid = <String>[];
    late Future<void> Function(String) savedOpenPayment;

    setUp(() async {
      await lotdSetUp(role: 'owner');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async => null);
      Get.locale = const Locale('fr', 'FR');
      Flags644.reset();
      paid.clear();
      savedOpenPayment = openBookingPayment628;
      openBookingPayment628 = (id) async => paid.add(id);
    });
    tearDown(() async {
      openBookingPayment628 = savedOpenPayment;
      Flags644.reset();
      await Get.deleteAll(force: true);
      Get.reset();
    });

    Future<void> open(
      WidgetTester tester,
      List<Map<String, dynamic>> list, {
      Map<String, dynamic> Function(LotdRequest? _, String path, Map<String, dynamic>? body)? onPost,
      List<String> services = const ['house_sitting'],
      double width = 375,
      double height = 667,
      double textScale = 1.0,
      String? highlight,
    }) async {
      apps = list;
      lotdResponder = (req) {
        final path = req.url.path;
        if (path.endsWith('/applications/my')) return <String, dynamic>{'applications': apps};
        if (path.contains('/posts/by-id/')) {
          return <String, dynamic>{
            'post': {
              'id': 'p1', '_id': 'p1', 'dateMode': 'exact', 'serviceTypes': services,
              'animalTypes': ['dog'],
              'location': {'city': 'Paris', 'lat': _pLat, 'lng': _pLng},
              'owner': {'id': 'o1', 'name': 'Camille'},
              'createdAt': '2026-11-20T10:00:00Z', 'updatedAt': '2026-11-20T10:00:00Z',
            },
          };
        }
        if (req.method == 'POST' && onPost != null && (path.endsWith('/price-offer') || path.endsWith('/respond'))) {
          Map<String, dynamic>? body;
          try {
            body = jsonDecode(req.body) as Map<String, dynamic>;
          } catch (_) {}
          return onPost(null, path, body);
        }
        return <String, dynamic>{};
      };
      lotdPhone(tester, width: width, height: height);
      if (textScale != 1.0) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: GestureDetector(
              key: const Key('open_sheet'),
              onTap: () => PostCandidatesSheet.show(
                  context: ctx, postId: 'p1', source: 'direct', highlightApplicationId: highlight),
              child: const Text('ouvrir'),
            ),
          ),
        );
      })));
      await lotdSettle(tester);
      await tester.tap(find.byKey(const Key('open_sheet')));
      await lotdSettle(tester, frames: 14);
    }

    Future<void> tapKey(WidgetTester tester, String key, {int frames = 8}) async {
      final f = find.byKey(Key(key));
      await tester.ensureVisible(f);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(f);
      await lotdSettle(tester, frames: frames);
    }

    Future<void> scrollTo(WidgetTester tester, String key, {bool up = false}) async {
      final list = find.descendant(of: find.byKey(const Key('cand2610_sheet')), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(Key(key)), up ? -120 : 120, scrollable: list, maxScrolls: 80);
      await lotdSettle(tester, frames: 2);
    }

    List<LotdRequest> sent(String suffix) => lotdRequests.where((r) => r.path.endsWith(suffix)).toList();

    testWidgets('ancien serveur (aucune vue) : ni prix proposé ni « payer plus tard » ; Choisir inchangé ; « Lui parler » affiché',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1')]);
      expect(find.byKey(const Key('cand644_extras_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_later_btn_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_offer_btn_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_far_header')), findsNothing);
      expect(find.textContaining('Choisir · 120,00'), findsOneWidget);
      expect(find.byKey(const Key('cand2610_reject_a1')), findsOneWidget);
      expect(find.text('Lui parler avant de réserver'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('les trois boutons selon ce que dit le serveur',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', offer: _canOffer, later: _canReserve),
        _app('a2', name: 'Tom Petit', offer: {..._canOffer, 'canOffer': false}, later: {..._canReserve, 'canReserve': false}),
        _app('a3', name: 'Zoé Roy', pricing: {'stale': true, 'unit': 'day', 'currency': 'EUR'}, offer: _canOffer, later: _canReserve),
      ]);
      expect(find.byKey(const Key('cand644_later_btn_a1')), findsOneWidget);
      expect(find.byKey(const Key('cand644_offer_btn_a1'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const Key('cand644_later_btn_a2'), skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('cand644_offer_btn_a2'), skipOffstage: false), findsNothing);
      await scrollTo(tester, 'cand2610_card_a3');
      await lotdSettle(tester);
      expect(find.byKey(const Key('cand644_later_btn_a3'), skipOffstage: false), findsNothing, reason: 'sans total : rien à réserver');
      expect(find.byKey(const Key('cand644_offer_btn_a3'), skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('coupe-circuits : chaque nouveauté masquée, écran d\'avant',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      Flags644.priceOffer = false;
      Flags644.payLater = false;
      Flags644.talkBefore = false;
      Flags644.order = false;
      await open(tester, [
        _app('a1', dlat: 0.3, offer: {..._canOffer, 'status': 'declined', 'amount': 90}, later: _canReserve),
        _app('a2', name: 'Tom Petit', dlat: 0.01, verified: true),
      ], services: const ['dog_walking']);
      expect(find.byKey(const Key('cand644_extras_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_far_header'), skipOffstage: false), findsNothing);
      expect(find.text('Écrire à Imane'), findsOneWidget);
      // ordre du build 628 : ordre du serveur (a1 avant a2)
      final y1 = tester.getTopLeft(find.byKey(const Key('cand2610_card_a1'))).dy;
      expect(find.byKey(const Key('cand2610_card_a2')).evaluate().isEmpty ||
          y1 < tester.getTopLeft(find.byKey(const Key('cand2610_card_a2'))).dy, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Proposer mon prix : minimum affiché, trop bas refusé sur place, envoi, état « en attente », lien retiré',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', offer: _canOffer)], onPost: (_, path, body) => <String, dynamic>{
            'offer': {'index': 0, 'amount': body?['amount'], 'currency': 'EUR', 'status': 'pending'},
            'priceOffer2211View': {..._canOffer, 'canOffer': false, 'count': 1, 'status': 'pending', 'amount': body?['amount']},
          });
      await tapKey(tester, 'cand644_offer_btn_a1');
      expect(find.byKey(const Key('cand644_offer_box_a1')), findsOneWidget);
      expect(find.text('Propose ton prix à Imane'), findsOneWidget);
      expect(find.textContaining('entre ${_eur(84)} et moins de ${_eur(120)}'), findsOneWidget);
      // trop bas : message avec le minimum, rien n'est envoyé
      await tester.enterText(find.byKey(const Key('cand644_offer_input_a1')), '50');
      await tapKey(tester, 'cand644_offer_send_a1');
      expect(find.textContaining('Ce prix est trop bas : propose au moins ${_eur(84)}'), findsOneWidget);
      expect(sent('/price-offer'), isEmpty);
      // pas plus bas que le total : refusé aussi
      await tester.enterText(find.byKey(const Key('cand644_offer_input_a1')), '120');
      await tapKey(tester, 'cand644_offer_send_a1');
      expect(find.textContaining('Propose un prix inférieur à ${_eur(120)}'), findsOneWidget);
      expect(sent('/price-offer'), isEmpty);
      // montant valable (virgule acceptée)
      await tester.enterText(find.byKey(const Key('cand644_offer_input_a1')), '99,5');
      await tapKey(tester, 'cand644_offer_send_a1', frames: 12);
      final reqs = sent('/price-offer');
      expect(reqs, hasLength(1));
      expect(reqs.single.method, 'POST');
      expect(reqs.single.path, contains('/applications/a1/price-offer'));
      expect(reqs.single.body, {'amount': 99.5});
      expect(find.byKey(const Key('cand644_offer_box_a1')), findsNothing);
      expect(find.text('Ta proposition de ${_eur(99.5)} est envoyée à Imane · réponse par notification et e-mail'), findsOneWidget);
      expect(find.byKey(const Key('cand644_offer_btn_a1')), findsNothing, reason: 'une proposition en attente : plus de lien');
      expect(find.textContaining('Choisir · 120,00'), findsOneWidget, reason: 'le prix ne change qu\'après l\'accord du gardien');
      expect(find.byKey(const Key('cand2610_sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Proposer mon prix : refus du serveur par code (trop bas, pas plus bas, limite)',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      String code = 'OFFER_TOO_LOW';
      // bornes absentes de la vue : le contrôle local laisse passer, le serveur tranche
      await open(tester, [_app('a1', offer: {..._canOffer, 'minAmount': 84, 'currentTotal': 120})],
          onPost: (_, path, body) => <String, dynamic>{'__status': code == 'OFFER_LIMIT' ? 409 : 400, 'error': 'x', 'code': code, 'minAmount': 84, 'currentTotal': 120});
      await tapKey(tester, 'cand644_offer_btn_a1');
      await tester.enterText(find.byKey(const Key('cand644_offer_input_a1')), '100');
      await tapKey(tester, 'cand644_offer_send_a1', frames: 12);
      expect(sent('/price-offer'), hasLength(1));
      expect(find.textContaining('Ce prix est trop bas : propose au moins ${_eur(84)}'), findsOneWidget);
      expect(find.byKey(const Key('cand644_offer_box_a1')), findsOneWidget, reason: 'on peut corriger');
      code = 'OFFER_NOT_LOWER';
      await tapKey(tester, 'cand644_offer_send_a1', frames: 12);
      expect(find.textContaining('Propose un prix inférieur à ${_eur(120)}'), findsOneWidget);
      code = 'OFFER_LIMIT';
      await tapKey(tester, 'cand644_offer_send_a1', frames: 12);
      expect(sent('/price-offer'), hasLength(3));
      expect(find.text('Tu as déjà fait tes propositions pour ce candidat.'), findsOneWidget);
      expect(find.byKey(const Key('cand644_offer_box_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_offer_btn_a1')), findsNothing, reason: 'limite atteinte : le lien disparaît');
      expect(find.textContaining('OFFER_'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('proposition acceptée : note verte, total et « Choisir » au nouveau prix du serveur',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', total: 100, offer: {..._canOffer, 'canOffer': false, 'status': 'accepted', 'amount': 100, 'currentTotal': 100, 'negotiated': true}),
      ]);
      expect(find.text('Imane a accepté ton prix : ${_eur(100)}'), findsOneWidget);
      expect(find.textContaining('Choisir · 100,00'), findsOneWidget);
      expect(find.byKey(const Key('cand644_offer_btn_a1')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('proposition refusée : note, on peut reproposer, prix inchangé',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', offer: {..._canOffer, 'status': 'declined', 'amount': 90, 'count': 1}),
      ]);
      expect(find.text('Imane préfère garder son prix'), findsOneWidget);
      expect(find.byKey(const Key('cand644_offer_btn_a1')), findsOneWidget);
      expect(find.textContaining('Choisir · 120,00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Réserver, payer plus tard : deux temps, appel serveur, état réservé, aucun paiement ouvert seul, « Payer maintenant »',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', later: _canReserve), _app('a2', name: 'Tom Petit')], onPost: (_, path, body) {
        apps = [
          _app('a1', status: 'accepted', bookingId: _bookingId, later: _waiting),
          _app('a2', name: 'Tom Petit'),
        ];
        return <String, dynamic>{
          'application': {'id': 'a1', 'status': 'accepted', 'bookingId': _bookingId},
          'booking': {'id': _bookingId},
          'payLater2211': {'at': '2026-11-22T13:00:00.000Z', 'deadline': '2026-11-24T13:00:00.000Z', 'holdHours': 48},
        };
      });
      expect(find.textContaining('Choisir · 120,00'), findsWidgets, reason: 'le bouton principal reste');
      expect(find.text('Réserver Imane, payer plus tard'), findsOneWidget);
      // 1er temps : le texte de confirmation, rien n'est envoyé
      await tapKey(tester, 'cand644_later_btn_a1');
      expect(find.byKey(const Key('cand644_later_confirm_a1')), findsOneWidget);
      expect(find.textContaining('Imane sera prévenu(e). Tu as 48 h pour payer et confirmer'), findsOneWidget);
      expect(find.textContaining("Rien n'est débité maintenant"), findsOneWidget);
      expect(sent('/respond'), isEmpty);
      // « Fermer » referme sans rien envoyer
      await tapKey(tester, 'cand644_later_close_a1');
      expect(find.byKey(const Key('cand644_later_confirm_a1')), findsNothing);
      expect(sent('/respond'), isEmpty);
      // 2e temps : confirmer
      await tapKey(tester, 'cand644_later_btn_a1');
      await tapKey(tester, 'cand644_later_ok_a1', frames: 14);
      final reqs = sent('/respond');
      expect(reqs, hasLength(1));
      expect(reqs.single.path, contains('/applications/a1/respond'));
      expect(reqs.single.body, {'action': 'accept', 'payLater': true});
      // état réservé, feuille toujours ouverte, aucun paiement ouvert
      expect(find.byKey(const Key('cand2610_sheet')), findsOneWidget);
      expect(find.byKey(const Key('cand644_held_a1')), findsOneWidget);
      expect(find.textContaining("Réservé jusqu'au"), findsOneWidget);
      expect(find.textContaining('Payer maintenant · 120,00'), findsOneWidget);
      expect(find.text('Lui écrire'), findsOneWidget);
      expect(find.byKey(const Key('dates620_choose_a1')), findsNothing);
      expect(find.byKey(const Key('cand2610_reject_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_later_btn_a1')), findsNothing);
      expect(find.byKey(const Key('cand2610_card_a2'), skipOffstage: false), findsOneWidget, reason: 'les autres candidats restent');
      expect(paid, isEmpty);
      // « Payer maintenant » : la feuille se ferme, le paiement existant de la réservation s'ouvre
      await tapKey(tester, 'cand644_pay_a1', frames: 12);
      expect(find.byKey(const Key('cand2610_sheet')), findsNothing);
      expect(paid, [_bookingId]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('réservation en cours : fermer la feuille n\'ouvre pas le paiement',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', status: 'accepted', bookingId: _bookingId, later: _waiting)]);
      expect(find.byKey(const Key('cand644_held_a1')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('cand2610_sheet')))).pop();
      await lotdSettle(tester, frames: 10);
      expect(find.byKey(const Key('cand2610_sheet')), findsNothing);
      expect(paid, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('payer plus tard refusé : trop tard → message, bouton retiré, « Choisir » reste ; libérée → note',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('a1', later: _canReserve),
        _app('a2', name: 'Tom Petit', later: {..._canReserve, 'canReserve': false, 'status': 'released'}),
      ], onPost: (_, path, body) => <String, dynamic>{'__status': 409, 'error': 'too soon', 'code': 'PAY_LATER_TOO_LATE'});
      await tapKey(tester, 'cand644_later_btn_a1');
      await tapKey(tester, 'cand644_later_ok_a1', frames: 12);
      expect(sent('/respond'), hasLength(1));
      expect(find.textContaining('Le service commence trop tôt pour réserver sans payer'), findsOneWidget);
      expect(find.byKey(const Key('cand644_later_btn_a1')), findsNothing);
      expect(find.byKey(const Key('cand644_later_confirm_a1')), findsNothing);
      expect(find.byKey(const Key('dates620_choose_a1')), findsOneWidget);
      expect(find.textContaining('PAY_LATER'), findsNothing);
      expect(find.byKey(const Key('cand2610_sheet')), findsOneWidget);
      expect(paid, isEmpty);
      await scrollTo(tester, 'cand644_later_released_a2');
      expect(find.textContaining("n'a pas été payée à temps"), findsOneWidget);
      expect(find.byKey(const Key('cand644_later_btn_a2'), skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Lui parler avant de réserver : 4 messages prêts, un toucher = conversation de CE candidat',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [_app('a1', role: 'walker')]);
      await tapKey(tester, 'cand2610_write_a1');
      expect(find.byKey(const Key('cand644_talk_sheet')), findsOneWidget);
      expect(find.text('Pose ta question à Imane avant de payer'), findsOneWidget);
      expect(find.text('Pouvons-nous nous parler 10 minutes avant que je réserve ?'), findsOneWidget);
      expect(find.text('Avez-vous déjà promené un chien comme le mien ?'), findsOneWidget);
      expect(find.text('Pouvez-vous passer le voir avant ?'), findsOneWidget);
      expect(find.text('Êtes-vous disponible à ces dates ?'), findsOneWidget);
      expect(lotdRequests.where((r) => r.path.contains('/conversations')), isEmpty, reason: 'rien n\'est envoyé avant le choix');
      await tapKey(tester, 'cand644_q_0');
      expect(find.byKey(const Key('cand644_talk_sheet')), findsNothing);
      final start = lotdRequests.where((r) => r.path.contains('/conversations')).toList();
      expect(start, isNotEmpty);
      expect(start.last.query['walkerId'], 's-a1');
      expect(start.last.body ?? const <String, dynamic>{}, isNot(contains('message')), reason: 'le message n\'est pas envoyé à la place du propriétaire');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('message prêt posé dans le champ de la conversation, modifiable',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      lotdPhone(tester);
      lotdResponder = (req) {
        if (req.url.path.contains('/messages')) return <String, dynamic>{'data': <dynamic>[]};
        if (req.url.path.contains('/conversations')) return <String, dynamic>{'conversations': <dynamic>[]};
        return <String, dynamic>{};
      };
      const draft = 'Pouvons-nous nous parler 10 minutes avant que je réserve ?';
      await tester.pumpWidget(lotdApp(const IndividualChatScreen(
          conversationId: 'conv-644', contactName: 'Imane Benali', contactImage: '', initialDraft: draft)));
      await lotdSettle(tester, frames: 4);
      final texts = tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text).toList();
      expect(texts, contains(draft), reason: 'champs : $texts');
      final field = find.widgetWithText(TextField, draft);
      expect(field, findsOneWidget);
      await tester.enterText(field, '$draft Merci !');
      await tester.pump();
      expect(find.widgetWithText(TextField, '$draft Merci !'), findsOneWidget);
      expect(lotdRequests.where((r) => r.method == 'POST' && r.path.contains('/messages')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('promenade : intertitre « Plus loin de chez toi » avant le 1er candidat à plus de 10 km ; identité vérifiée d\'abord',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      await open(tester, [
        _app('loin', name: 'Luc Loin', dlat: 0.2, verified: true),
        _app('rien', name: 'Rémi Rien', dlat: 0.02),
        _app('photo', name: 'Paula Verif', dlat: 0.05, verified: true),
      ], services: const ['dog_walking'], height: 2400);
      final yPhoto = tester.getTopLeft(find.byKey(const Key('cand2610_card_photo'))).dy;
      final yRien = tester.getTopLeft(find.byKey(const Key('cand2610_card_rien'))).dy;
      final yHead = tester.getTopLeft(find.byKey(const Key('cand644_far_header'))).dy;
      final yLoin = tester.getTopLeft(find.byKey(const Key('cand2610_card_loin'))).dy;
      expect(yPhoto, lessThan(yRien));
      expect(yRien, lessThan(yHead));
      expect(yHead, lessThan(yLoin));
      expect(find.text('Plus loin de chez toi · à plus de 10 km'), findsOneWidget);
      expect(find.text('Tes candidats (3)'), findsOneWidget, reason: 'personne n\'est masqué');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final size in const <Size>[Size(360, 640), Size(320, 568)]) {
      for (final scale in const <double>[1.0, 1.5]) {
        testWidgets('${size.width.toInt()}×${size.height.toInt()}, caractères ×$scale : aucun débordement (carte, prix, plus tard, réservé, messages)',
            timeout: const Timeout(Duration(minutes: 3)), (tester) async {
          await open(tester, [
            _app('a1', name: 'Maximilienne Dupont-Lefebvre', offer: {..._canOffer, 'status': 'declined', 'amount': 90}, later: _canReserve, dlat: 0.2),
            _app('a2', name: 'Tom Petit', status: 'accepted', bookingId: _bookingId, later: _waiting),
          ], services: const ['home_visit'], width: size.width, height: size.height, textScale: scale);
          expect(tester.takeException(), isNull, reason: 'liste');
          // le candidat réservé (proche) est en haut ; celui à plus de 10 km sous l'intertitre
          await scrollTo(tester, 'cand644_pay_a2');
          expect(find.byKey(const Key('cand644_held_a2')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'réservé');
          await scrollTo(tester, 'cand2610_write_a1');
          expect(find.byKey(const Key('cand644_far_header')), findsOneWidget);
          await scrollTo(tester, 'cand644_later_btn_a1');
          await tapKey(tester, 'cand644_later_btn_a1');
          expect(find.byKey(const Key('cand644_later_confirm_a1')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'confirmation');
          await scrollTo(tester, 'cand644_offer_btn_a1');
          await tapKey(tester, 'cand644_offer_btn_a1');
          expect(find.byKey(const Key('cand644_offer_box_a1')), findsOneWidget);
          await tester.enterText(find.byKey(const Key('cand644_offer_input_a1')), '1');
          await tapKey(tester, 'cand644_offer_send_a1');
          expect(find.byKey(const Key('cand644_error_a1')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'champ prix + erreur');
          await scrollTo(tester, 'cand2610_write_a1', up: true);
          await tapKey(tester, 'cand2610_write_a1');
          expect(find.byKey(const Key('cand644_talk_sheet')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'messages prêts');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  });

  group('« Ajoute ta photo » (gardien / promeneur)', () {
    int added = 0;

    setUp(() async {
      await lotdSetUp(role: 'sitter');
      Get.locale = const Locale('fr', 'FR');
      PhotoNudge644.resetForTest();
      added = 0;
      PhotoNudge644.addPhoto = () async => added++;
      PhotoNudge644.serverHasPhoto = () async => false;
    });
    tearDown(() async {
      PhotoNudge644.resetForTest();
      await Get.deleteAll(force: true);
      Get.reset();
    });

    // Un bouton « candidater » : la feuille éventuelle, PUIS la candidature (toujours).
    Future<List<String>> pumpApply(WidgetTester tester, {Size size = const Size(375, 667), double textScale = 1.0}) async {
      final List<String> applied = <String>[];
      lotdPhone(tester, width: size.width, height: size.height);
      if (textScale != 1.0) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      await tester.pumpWidget(lotdApp(Builder(builder: (ctx) {
        return Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final post in const ['p1', 'p2'])
                GestureDetector(
                  key: Key('apply_$post'),
                  onTap: () async {
                    await PhotoNudge644.maybeShow(post, context: ctx);
                    applied.add(post);
                  },
                  child: Padding(padding: const EdgeInsets.all(16), child: Text('candidater $post')),
                ),
            ],
          ),
        );
      })));
      await lotdSettle(tester);
      return applied;
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(Key(key)));
      await lotdSettle(tester, frames: 8);
    }

    testWidgets('sans photo : la feuille s\'intercale ; « Plus tard » laisse candidater ; une seule fois par demande',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      final applied = await pumpApply(tester);
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsOneWidget);
      expect(find.text('Ajoute ta photo'), findsOneWidget);
      expect(find.text("Les propriétaires choisissent d'abord les profils avec photo."), findsOneWidget);
      expect(find.text('Ajouter ma photo'), findsOneWidget);
      expect(applied, isEmpty, reason: 'la candidature attend la réponse à la feuille');
      await tap(tester, 'photo644_later');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      expect(applied, ['p1'], reason: 'jamais bloquant');
      expect(added, 0);
      // même demande : plus de feuille
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      expect(applied, ['p1', 'p1']);
      // autre demande : une fois encore
      await tap(tester, 'apply_p2');
      expect(find.byKey(const Key('photo644_sheet')), findsOneWidget);
      // fermée par glissement / hors de la feuille : la candidature part quand même
      Navigator.of(tester.element(find.byKey(const Key('photo644_sheet')))).pop();
      await lotdSettle(tester, frames: 8);
      expect(applied, ['p1', 'p1', 'p2']);
      // mémorisé sur le téléphone
      expect((GetStorage().read(PhotoNudge644.storageKey) as List).toSet(), {'p1', 'p2'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('« Ajouter ma photo » ouvre le sélecteur existant puis la candidature part ; même si l\'ajout échoue',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      final applied = await pumpApply(tester);
      await tap(tester, 'apply_p1');
      await tap(tester, 'photo644_add');
      expect(added, 1);
      expect(applied, ['p1']);
      PhotoNudge644.addPhoto = () async => throw StateError('sélecteur fermé');
      await tap(tester, 'apply_p2');
      await tap(tester, 'photo644_add');
      expect(applied, ['p1', 'p2']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('jamais de feuille : photo connue, propriétaire, serveur muet ou qui connaît une photo, option coupée',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      final applied = await pumpApply(tester);
      // serveur sans réponse (hors ligne) : on ne dérange pas
      PhotoNudge644.serverHasPhoto = () async => null;
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      // option coupée
      PhotoNudge644.serverHasPhoto = () async => false;
      PhotoNudge644.enabled = false;
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      PhotoNudge644.enabled = true;
      // propriétaire
      await GetStorage().write(StorageKeys.userRole, 'owner');
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      await GetStorage().write(StorageKeys.userRole, 'walker');
      // photo connue du téléphone
      final profile = Map<String, dynamic>.from(GetStorage().read(StorageKeys.userProfile) as Map);
      await GetStorage().write(StorageKeys.userProfile, {...profile, 'avatar': {'url': 'https://img.test/me.jpg'}});
      expect(PhotoNudge644.localHasPhoto(), isTrue);
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      // photo connue du serveur seulement
      await GetStorage().write(StorageKeys.userProfile, profile);
      PhotoNudge644.serverHasPhoto = () async => true;
      await tap(tester, 'apply_p2');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      expect(applied, ['p1', 'p1', 'p1', 'p1', 'p2']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('réponse vide du serveur (pas un profil) : pas de feuille',
        timeout: const Timeout(Duration(minutes: 2)), (tester) async {
      PhotoNudge644.resetForTest(); // vraie lecture serveur, faux HTTP qui répond {}
      final applied = await pumpApply(tester);
      await tap(tester, 'apply_p1');
      expect(find.byKey(const Key('photo644_sheet')), findsNothing);
      expect(applied, ['p1']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final size in const <Size>[Size(360, 640), Size(320, 568)]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}, caractères ×1,5 : feuille sans débordement',
          timeout: const Timeout(Duration(minutes: 2)), (tester) async {
        await pumpApply(tester, size: size, textScale: 1.5);
        await tap(tester, 'apply_p1');
        expect(find.byKey(const Key('photo644_sheet')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, 'photo644_later');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });
}
