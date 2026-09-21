// v575 — Daniel : « le pourcentage ne se met pas à jour », « ça ouvre les
// mêmes », « dans mon profil j'ai que "nom" et pas "nom et prénom" ».
//
// Le calcul de la barre « profil complété à X % » vit désormais dans une
// fonction PURE (`lib/utils/profile_completion.dart`). Ce test vérifie, pour
// les TROIS rôles :
//   · chaque élément passe à « rempli » avec la valeur que l'écran enregistre
//     réellement (c'est la cause du « ça refuse » : la ville n'était jamais
//     envoyée sans GPS, l'élément restait rouge à vie) ;
//   · chaque élément ouvre SON écran, avec le champ à cibler ;
//   · le pourcentage bouge dès qu'un élément est rempli ;
//   · le découpage prénom / nom (compte historique qui n'a que `name`).
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/utils/profile_completion.dart';

ProfileCompletionInput _empty() => const ProfileCompletionInput();

/// Profil complet du rôle demandé (100 %).
ProfileCompletionInput _full(String role) => ProfileCompletionInput(
      name: 'Daniel Cardelli',
      firstName: 'Daniel',
      lastName: 'Cardelli',
      avatarUrl: 'https://cdn/x.jpg',
      mobile: '612345678',
      address: '3 rue des Lilas',
      city: 'Paris',
      bio: 'Je m’occupe des animaux depuis dix ans, avec beaucoup de patience.',
      services: role == 'owner' ? const [] : const ['sit_home'],
      acceptedPetTypes: role == 'owner' ? const [] : const ['dog'],
      petsCount: role == 'owner' ? 1 : 0,
    );

ProfileFixItem _item(List<ProfileFixItem> items, String key) =>
    items.firstWhere((i) => i.key == key);

void main() {
  group('éléments par rôle', () {
    test('le propriétaire a 7 éléments, dont « animaux » et pas « services »', () {
      final keys = profileCompletionItemsFor(_empty(), 'owner').map((e) => e.key).toList();
      expect(keys, ['name', 'photo', 'phone', 'address', 'city', 'bio', 'pets']);
    });

    test('gardien et promeneur ont les mêmes 8 éléments', () {
      final sitter = profileCompletionItemsFor(_empty(), 'sitter').map((e) => e.key).toList();
      final walker = profileCompletionItemsFor(_empty(), 'walker').map((e) => e.key).toList();
      expect(sitter, walker);
      expect(sitter, ['name', 'photo', 'phone', 'address', 'city', 'bio', 'services', 'animals']);
    });

    test('un rôle inconnu est traité comme un prestataire (comportement historique)', () {
      expect(profileCompletionItemsFor(_empty(), '').length, 8);
    });
  });

  group('destination de chaque élément (plus « les mêmes »)', () {
    for (final role in ['owner', 'sitter', 'walker']) {
      test('$role : chaque élément ouvre le bon écran', () {
        final items = profileCompletionItemsFor(_empty(), role);
        expect(_item(items, 'photo').target, ProfileFixTarget.photo);
        for (final k in ['phone', 'address', 'city']) {
          expect(_item(items, k).target, ProfileFixTarget.contactSheet, reason: k);
        }
        expect(_item(items, 'name').target, ProfileFixTarget.editProfile);
        expect(_item(items, 'name').focusField, ProfileFocusField.name);
        expect(_item(items, 'bio').target, ProfileFixTarget.editProfile);
        expect(_item(items, 'bio').focusField, ProfileFocusField.bio);
        if (role == 'owner') {
          expect(_item(items, 'pets').target, ProfileFixTarget.pets);
        } else {
          expect(_item(items, 'services').focusField, ProfileFocusField.services);
          expect(_item(items, 'animals').focusField, ProfileFocusField.animals);
        }
      });

      test('$role : deux éléments « à corriger » ne pointent jamais au même endroit sans distinction', () {
        final items = profileCompletionItemsFor(_empty(), role);
        final editItems = items.where((i) => i.target == ProfileFixTarget.editProfile);
        final focuses = editItems.map((i) => i.focusField).toList();
        expect(focuses.toSet().length, focuses.length,
            reason: 'chaque élément de l’écran d’édition cible un champ différent');
        expect(focuses.contains(null), isFalse);
      });
    }
  });

  group('condition exacte de chaque élément', () {
    test('nom : rempli seulement avec prénom ET nom', () {
      expect(_item(profileCompletionItemsFor(_empty(), 'owner'), 'name').done, isFalse);
      expect(
        _item(profileCompletionItemsFor(
                const ProfileCompletionInput(name: 'Madonna'), 'owner'), 'name')
            .done,
        isFalse,
      );
      expect(
        _item(profileCompletionItemsFor(
                const ProfileCompletionInput(name: 'Daniel Cardelli'), 'owner'), 'name')
            .done,
        isTrue,
      );
      expect(
        _item(profileCompletionItemsFor(
                const ProfileCompletionInput(
                    name: '', firstName: 'Daniel', lastName: 'Cardelli'),
                'owner'), 'name')
            .done,
        isTrue,
      );
    });

    test('photo : une URL non vide suffit', () {
      expect(
        _item(profileCompletionItemsFor(
                const ProfileCompletionInput(avatarUrl: ' '), 'sitter'), 'photo')
            .done,
        isFalse,
      );
      expect(
        _item(profileCompletionItemsFor(
                const ProfileCompletionInput(avatarUrl: 'https://cdn/x.jpg'), 'sitter'),
            'photo').done,
        isTrue,
      );
    });

    test('ville : le champ PLAT `city` suffit, sans GPS', () {
      final p = const ProfileCompletionInput(city: 'Paris');
      expect(_item(profileCompletionItemsFor(p, 'walker'), 'city').done, isTrue);
    });

    test('bio : au moins $kProfileBioMinLength caractères', () {
      final court = ProfileCompletionInput(bio: 'a' * (kProfileBioMinLength - 1));
      final pile = ProfileCompletionInput(bio: 'a' * kProfileBioMinLength);
      expect(_item(profileCompletionItemsFor(court, 'owner'), 'bio').done, isFalse);
      expect(_item(profileCompletionItemsFor(pile, 'owner'), 'bio').done, isTrue);
    });

    test('propriétaire : « animaux » compte les animaux, pas les services', () {
      final p = const ProfileCompletionInput(petsCount: 2, services: ['sit_home']);
      expect(_item(profileCompletionItemsFor(p, 'owner'), 'pets').done, isTrue);
    });

    test('prestataire : services et animaux acceptés sont des champs PROPRES au rôle', () {
      final p = const ProfileCompletionInput(
          services: ['sit_home'], acceptedPetTypes: ['dog'], petsCount: 0);
      final items = profileCompletionItemsFor(p, 'sitter');
      expect(_item(items, 'services').done, isTrue);
      expect(_item(items, 'animals').done, isTrue);
    });
  });

  group('pourcentage', () {
    for (final role in ['owner', 'sitter', 'walker']) {
      test('$role : profil vide = 0 %, profil complet = 100 %', () {
        expect(profileCompletionPercentFor(_empty(), role), 0);
        expect(profileCompletionPercentFor(_full(role), role), 100);
      });

      test('$role : remplir un élément fait monter le pourcentage tout de suite', () {
        final avant = profileCompletionPercentFor(_empty(), role);
        final apres = profileCompletionPercentFor(
            const ProfileCompletionInput(mobile: '612345678'), role);
        expect(apres, greaterThan(avant));
      });

      test('$role : un élément rempli disparaît de la liste des manquants', () {
        final manquants = profileCompletionItemsFor(
                const ProfileCompletionInput(city: 'Paris'), role)
            .where((i) => !i.done)
            .map((e) => e.key);
        expect(manquants, isNot(contains('city')));
      });
    }

    test('le propriétaire et le prestataire ne se comparent pas sur le même total', () {
      // 7 éléments vs 8 : un même champ rempli ne vaut pas le même pourcentage.
      final p = const ProfileCompletionInput(mobile: '612345678');
      expect(profileCompletionPercentFor(p, 'owner'), 14);
      expect(profileCompletionPercentFor(p, 'sitter'), 13);
    });
  });

  group('prénom / nom (compte historique)', () {
    test('découpage : 1er mot = prénom, le reste = nom', () {
      expect(splitPersonName('Daniel Cardelli'),
          (firstName: 'Daniel', lastName: 'Cardelli'));
      expect(splitPersonName('Jean Pierre de La Tour'),
          (firstName: 'Jean', lastName: 'Pierre de La Tour'));
      expect(splitPersonName('Madonna'), (firstName: 'Madonna', lastName: ''));
      expect(splitPersonName('   '), (firstName: '', lastName: ''));
      expect(splitPersonName('  Daniel   Cardelli  '),
          (firstName: 'Daniel', lastName: 'Cardelli'));
    });

    test('les champs explicites gagnent sur le découpage', () {
      expect(
        splitPersonName('Daniel Cardelli', firstName: 'Dan', lastName: 'C'),
        (firstName: 'Dan', lastName: 'C'),
      );
    });

    test('recomposition sans espace parasite', () {
      expect(joinPersonName('Daniel', 'Cardelli'), 'Daniel Cardelli');
      expect(joinPersonName('Madonna', ''), 'Madonna');
      expect(joinPersonName('  Daniel  ', ' Cardelli '), 'Daniel Cardelli');
      expect(joinPersonName('', ''), '');
    });
  });
}
