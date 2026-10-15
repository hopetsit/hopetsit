// 616 (PAM, §2 du 615, capture Daniel 10/10 San Francisco) — logique des
// bulles de prix, rejouée avec les DONNÉES RÉELLES renvoyées par
// /friends/members/nearby le 15/10 (Rhoda, Agiimaa, Jazel) :
//   · Rhoda M. : gardienne + propriétaire, priceFrom 0 partout, pas de tarif
//     semaine/mois → AUCUNE bulle, c'est le comportement voulu ;
//   · Agiimaa Z. : propriétaire + gardienne 75 USD + promeneuse 0 → « $75 »
//     pour un propriétaire ; rien pour un gardien/promeneur (l'autre côté du
//     marché seulement, handoff §1 v590) ;
//   · Jazel M. : promeneur 10 USD + gardien 50 USD → bulle DUO « $50|$10 ».
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/views/map/pawmap_person.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';

String _fmt(String cur, double p) {
  final n = p == p.roundToDouble() ? p.toInt().toString() : p.toString();
  return cur == 'USD' ? '\$$n' : (cur == 'EUR' ? '$n €' : '$n $cur');
}

String _unit(String u) => u == 'week' ? '/sem' : '/mois';

// Comme le serveur (`/friends/members/nearby`) : le point porte le 1er rôle
// ET ses champs de tarif au premier niveau, plus la liste `roles`.
Map<String, dynamic> _person(String name, List<Map<String, dynamic>> roles) =>
    {
      'id': roles.first['id'],
      '_role': roles.first['role'],
      'name': name,
      'priceFrom': roles.first['priceFrom'],
      'priceAlt': roles.first['priceAlt'],
      'currency': roles.first['currency'],
      'roles': roles,
    };

({String text, String role})? _bubble(Map<String, dynamic> p, String viewer,
        {Set<String> shown = const {}}) =>
    pawMapPersonPriceBubble(
      pawMapExpandRoles(p),
      shows: (r) => pawMapShowsPriceBubble(viewer, r),
      shownRoles: shown,
      format: _fmt,
      unitSuffix: _unit,
    );

void main() {
  final rhoda = _person('Rhoda M.', [
    {'id': 's1', 'role': 'sitter', 'priceFrom': 0, 'priceAlt': null, 'currency': 'USD'},
    {'id': 'o1', 'role': 'owner', 'priceFrom': 0, 'priceAlt': null, 'currency': 'USD'},
  ]);
  final agiimaa = _person('Agiimaa Z.', [
    {'id': 'o2', 'role': 'owner', 'priceFrom': 0, 'currency': 'USD'},
    {'id': 's2', 'role': 'sitter', 'priceFrom': 75, 'currency': 'USD'},
    {'id': 'w2', 'role': 'walker', 'priceFrom': 0, 'currency': 'USD'},
  ]);
  final jazel = _person('Jazel M.', [
    {'id': 'w3', 'role': 'walker', 'priceFrom': 10, 'currency': 'USD'},
    {'id': 's3', 'role': 'sitter', 'priceFrom': 50, 'currency': 'USD'},
  ]);
  final girma = _person('Girma', [
    {
      'id': 's4',
      'role': 'sitter',
      'priceFrom': 0,
      'priceAlt': {'amount': 100, 'unit': 'week'},
      'currency': 'EUR'
    },
  ]);

  test('Rhoda : aucun tarif → aucune bulle (pour les 3 rôles de spectateur)',
      () {
    for (final v in ['owner', 'sitter', 'walker', '']) {
      expect(_bubble(rhoda, v), isNull, reason: 'spectateur $v');
    }
  });

  test('Agiimaa : « \$75 » garde pour un propriétaire, devise du prestataire',
      () {
    final b = _bubble(agiimaa, 'owner');
    expect(b, isNotNull);
    expect(b!.text, '\$75');
    expect(b.role, 'sitter');
  });

  test('Agiimaa vue par un gardien ou un promeneur : pas de tarif concurrent',
      () {
    expect(_bubble(agiimaa, 'sitter'), isNull);
    expect(_bubble(agiimaa, 'walker'), isNull);
  });

  test('visiteur sans compte : voit les tarifs des prestataires', () {
    expect(_bubble(agiimaa, '')?.text, '\$75');
  });

  test('Jazel : gardien + promeneur → bulle duo « garde|promenade »', () {
    final b = _bubble(jazel, 'owner');
    expect(b?.text, '\$50|\$10');
    expect(b?.role, 'duo');
  });

  test('filtre de rôles de la carte : promeneurs seuls → bulle promenade',
      () {
    final b = _bubble(jazel, 'owner', shown: {'walker'});
    expect(b?.text, '\$10');
    expect(b?.role, 'walker');
  });

  test('tarif semaine seulement (EUR) → « 100 €/sem »', () {
    final b = _bubble(girma, 'owner');
    expect(b?.text, '100 €/sem');
    expect(b?.role, 'sitter');
  });

  test('tout prestataire AVEC un tarif a une bulle, quelle que soit sa devise',
      () {
    for (final cur in ['EUR', 'USD', 'GBP', 'PLN']) {
      final p = _person('X', [
        {'id': 'w9', 'role': 'walker', 'priceFrom': 12, 'currency': cur},
      ]);
      final b = _bubble(p, 'owner');
      expect(b, isNotNull, reason: cur);
      expect(b!.text, _fmt(cur, 12));
    }
  });
}
