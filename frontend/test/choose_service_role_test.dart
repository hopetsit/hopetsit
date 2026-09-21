// v575 — P1-5 : « les services cochés par un pet-sitter partaient sur son
// profil propriétaire ». Le serveur choisit désormais le document à mettre à
// jour d'après le rôle envoyé ; l'app doit traduire son vocabulaire
// (`pet_owner` / `pet_sitter` / `pet_walker`) vers celui du serveur
// (`owner` / `sitter` / `walker`).
//
// `serverRoleForUserType` est une fonction PURE : aucun widget, aucun réseau.

import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/controllers/choose_service_controller.dart';

void main() {
  group('serverRoleForUserType', () {
    test('traduit les 3 types de l\'app vers les rôles du serveur', () {
      expect(serverRoleForUserType('pet_owner'), 'owner');
      expect(serverRoleForUserType('pet_sitter'), 'sitter');
      expect(serverRoleForUserType('pet_walker'), 'walker');
    });

    test('accepte déjà les rôles serveur (idempotent)', () {
      expect(serverRoleForUserType('owner'), 'owner');
      expect(serverRoleForUserType('sitter'), 'sitter');
      expect(serverRoleForUserType('walker'), 'walker');
    });

    test('tolère la casse et les espaces', () {
      expect(serverRoleForUserType('  Pet_Sitter '), 'sitter');
      expect(serverRoleForUserType('PET_WALKER'), 'walker');
    });

    test('renvoie null si inconnu — le serveur garde son comportement d\'avant',
        () {
      expect(serverRoleForUserType(null), isNull);
      expect(serverRoleForUserType(''), isNull);
      expect(serverRoleForUserType('dragon'), isNull);
      // Piège : « pet » seul n'est pas un rôle, ne jamais deviner.
      expect(serverRoleForUserType('pet'), isNull);
    });
  });
}
