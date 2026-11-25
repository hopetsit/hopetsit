// 646 (ZOE, contrôle du 25/11/2026) — vu au simulateur : depuis que le serveur
// écrit ses refus dans la langue du compte (commit e37fe674), deux refus SANS
// `code` n'étaient plus reconnus par l'app → bandeau rouge sans bouton.
// Corps de réponse ci-dessous = ceux du serveur (applicationController.js).
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/rate646.dart';

ApiException _refus(String error, {String? code, String? details}) => ApiException(error, statusCode: 400, details: <String, dynamic>{
      'error': error,
      if (code != null) 'code': code,
      if (details != null) 'details': details,
    });

void main() {
  const noRateDetails = 'Update your profile with a non-zero rate and try again.';
  const walkDetails = 'Open your profile and set a price for 30 min or 60 min walks.';

  test('gardien sans aucun tarif sur une demande de visites (texte français, pas de code) → il manque le tarif par visite', () {
    final e = _refus('Ajoute ton tarif dans Mes tarifs pour répondre à cette demande.', details: noRateDetails);
    expect(rateNeedOfError646(e, role: 'sitter', service: 'home_visit'), 'visit');
    expect(rateNeedOfError646(e, role: 'sitter', service: 'house_sitting'), 'day');
    expect(rateNeedOfError646(e, role: 'sitter'), 'any');
  });

  test('même refus en japonais et en polonais : reconnu aussi', () {
    expect(rateNeedOfError646(_refus('この依頼に応募するには、「料金設定」で料金を追加してください。', details: noRateDetails), role: 'sitter', service: 'home_visit'), 'visit');
    expect(rateNeedOfError646(_refus('Dodaj stawkę w „Moje stawki”, aby odpowiedzieć na to zgłoszenie.', details: noRateDetails), role: 'sitter', service: 'home_visit'), 'visit');
  });

  test('promeneur sans tarif de balade (texte français, pas de code) → il manque le tarif de balade', () {
    final e = _refus('Ajoute ton tarif de balade dans Mes tarifs pour répondre aux demandes.', details: walkDetails);
    expect(rateNeedOfError646(e, role: 'walker', service: 'dog_walking'), 'walk');
    expect(needKey646('walk'), 'pam646_need_walk');
  });

  test('refus avec code : inchangés', () {
    expect(rateNeedOfError646(_refus('Ajoute ton tarif par visite…', code: 'VISIT_RATE_REQUIRED'), role: 'sitter', service: 'home_visit'), 'visit');
    expect(rateNeedOfError646(_refus('Cette demande n\'est pas une simple balade…', code: 'RATE_REQUIRED'), role: 'walker', service: 'house_sitting'), 'not_for_walker');
    expect(needKey646('not_for_walker'), 'pam646_walker_not_for_you');
    expect(rateNeedOfError646(_refus('Ajoute ton tarif pour ce service…', code: 'RATE_REQUIRED'), role: 'sitter', service: 'home_visit'), 'visit');
  });

  test('un autre refus 400 (trop loin) n’ouvre pas la feuille « tarif »', () {
    expect(rateNeedOfError646(_refus('Too far.', code: 'TOO_FAR'), role: 'sitter', service: 'house_sitting'), isNull);
    expect(rateNeedOfError646(_refus('You cannot apply to your own request.', code: 'OWN_POST'), role: 'sitter'), isNull);
  });
}
