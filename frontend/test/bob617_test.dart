// 617 (BOB, 16/10/2026) — ce que ces tests verrouillent :
//   1. Les codes serveur du 16/10 (TOO_FAR, CURRENCY_MISMATCH, DUPLICATE_REQUEST)
//      donnent un vrai motif, plus jamais « pas la permission ».
//   2. Plafond 200 km : une demande au-delà n'est plus proposée (même constante
//      que le serveur, applicationDistance1610.DEFAULT_MAX_KM).
//   3. Message après publication : N et le rayon viennent de la réponse du
//      serveur ; « 0 prévenu » n'est reconnu que si le serveur l'a DIT.
//   4. Lien profond : la demande d'avis ouvre la réservation, « N prévenus »
//      ouvre la demande.
//   5. Le paquet i18n 617 a les MÊMES clés dans les 9 langues.
import 'package:flutter_test/flutter_test.dart';

import 'package:hopetsit/controllers/publish_reservation_request_controller.dart';
import 'package:hopetsit/localization/v565/bob617_i18n.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/apply_distance617.dart';
import 'package:hopetsit/utils/server_error_message.dart';

void main() {
  group('codes serveur du 16/10', () {
    test('TOO_FAR → motif distance (403 ne donne plus « pas la permission »)', () {
      expect(serverErrorKey(code: 'TOO_FAR', statusCode: 403), 'bob617_err_too_far');
    });
    test('CURRENCY_MISMATCH (403 à la création, 409 à l’acceptation)', () {
      expect(serverErrorKey(code: 'CURRENCY_MISMATCH', statusCode: 403), 'bob617_err_currency');
      expect(serverErrorKey(code: 'currency_mismatch', statusCode: 409), 'bob617_err_currency');
    });
    test('DUPLICATE_REQUEST → doublon de publication', () {
      expect(serverErrorKey(code: 'DUPLICATE_REQUEST', statusCode: 409), 'bob617_err_duplicate');
    });
    test('le texte français cite la même limite que le serveur (200 km)', () {
      expect(bob617I18n['fr']!['bob617_err_too_far'], contains('${kApplyMaxKm617.round()} km'));
      expect(bob617I18n['en']!['bob617_err_too_far'], contains('${kApplyMaxKm617.round()} km'));
    });
  });

  group('plafond de candidature 200 km', () {
    test('même valeur que le serveur', () => expect(kApplyMaxKm617, 200.0));
    test('199,9 km gardée, 200 gardée, 200,1 et 11 254 km (Busan) écartées', () {
      final kept = withinApplyRange617<double>(
          <double>[199.9, 200.0, 200.1, 11254.0, 162.0], (k) => k);
      expect(kept, <double>[199.9, 200.0, 162.0]);
    });
    test('sans distance connue → écartée de la liste « plus proches »', () {
      expect(withinApplyRange617<double?>(<double?>[null, 5.0], (k) => k), <double?>[5.0]);
    });
  });

  group('message après publication (§D.1 / §D.2)', () {
    test('rayon lu dans la réponse, 100 par défaut', () {
      expect(PublishReservationRequestController.alertRadiusKmFromResponse({'alertRadiusKm': 80}), 80);
      expect(PublishReservationRequestController.alertRadiusKmFromResponse({}), 100);
    });
    test('0 prévenu seulement si le serveur l’a dit', () {
      expect(PublishReservationRequestController.nobodyNotified617({'notified': 0}), isTrue);
      expect(PublishReservationRequestController.nobodyNotified617({'post': {'notified': 0}}), isTrue);
      expect(PublishReservationRequestController.nobodyNotified617({'notified': 3}), isFalse);
      expect(PublishReservationRequestController.nobodyNotified617({}), isFalse);
    });
    test('id de la demande pour le lien à partager', () {
      expect(PublishReservationRequestController.createdPostId617({'post': {'id': 'abc'}}), 'abc');
      expect(PublishReservationRequestController.createdPostId617({'post': {'_id': 'x1'}}), 'x1');
      expect(PublishReservationRequestController.createdPostId617({}), '');
    });
    test('texte « N gardiens à moins de X km » : {n} et {km} présents dans les 9 langues', () {
      for (final lang in bob617I18n.keys) {
        for (final k in ['bob617_sent_sitters', 'bob617_sent_walkers']) {
          expect(bob617I18n[lang]![k], contains('{n}'), reason: '$lang/$k');
          expect(bob617I18n[lang]![k], contains('{km}'), reason: '$lang/$k');
        }
        expect(bob617I18n[lang]!['bob617_nothing_within_max'], contains('{max}'), reason: lang);
        expect(bob617I18n[lang]!['bob617_share_text'], contains('{link}'), reason: lang);
      }
    });
  });

  group('lien profond', () {
    const b = '6ad183f79192ac7f829af1a7';
    test('demande d’avis → la réservation (bouton Laisser un avis)', () {
      expect(DeepLinkService.routeForNotification('review_request_617', {'bookingId': b}, role: 'owner'),
          '/bookings/$b');
    });
    test('« N prévenus » → la demande', () {
      expect(DeepLinkService.routeForNotification('post_published_617', {'postId': b}, role: 'owner'),
          '/post/$b');
    });
    test('candidature reçue → Choisir → Payer (inchangé)', () {
      expect(DeepLinkService.routeForNotification('application_new', {'applicationId': b}, role: 'owner'),
          '/application/$b');
    });
  });

  test('i18n 617 : mêmes clés dans les 9 langues', () {
    const langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
    final ref = bob617I18n['en']!.keys.toSet();
    expect(ref, isNotEmpty);
    for (final l in langs) {
      expect(bob617I18n[l]!.keys.toSet(), ref, reason: l);
      for (final v in bob617I18n[l]!.values) {
        expect(v.trim(), isNotEmpty, reason: l);
      }
    }
  });
}
