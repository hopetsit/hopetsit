// v576 — lot « profils des 3 rôles » (bugs signalés par Daniel le 21/09/2026).
//
// Ce que ces tests verrouillent :
//   1. La barre « profil complété » monte élément par élément, avec les
//      valeurs que CHAQUE écran enregistre réellement (ids de services et
//      d'animaux propres au gardien et au promeneur, ville PLATE sans GPS).
//   2. Un message serveur technique en anglais ne peut JAMAIS s'afficher :
//      `serverErrorKey` renvoie toujours une clé i18n.
//   3. Les libellés de rôle viennent d'une seule source (`roleLabelKey`).
//   4. Le paquet i18n `fixes576` a les MÊMES clés dans les 9 langues.
import 'package:flutter_test/flutter_test.dart';

import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/v565/fixes576_i18n.dart';
import 'package:hopetsit/utils/profile_completion.dart';
import 'package:hopetsit/utils/server_error_message.dart';
import 'package:hopetsit/widgets/role_chip.dart';

// ── Valeurs RÉELLEMENT enregistrées par chaque écran d'édition ───────────
// gardien : edit_sitter_profile_screen.dart (chips « Services proposés »)
const _kSitterServices = <String>['sit_home', 'sit_owner', 'daycare', 'meds', 'vet_transport'];
const _kSitterAnimals = <String>['dog', 'cat', 'rodent', 'bird', 'reptile', 'nac'];
// promeneur : edit_walker_profile_screen.dart (chips « Type de promenade »)
const _kWalkerServices = <String>['individual', 'group', 'long', 'visit'];
const _kWalkerAnimals = <String>['dog', 'cat', 'small', 'nac'];

ProfileFixItem _item(List<ProfileFixItem> items, String key) =>
    items.firstWhere((i) => i.key == key);

bool _done(ProfileCompletionInput input, String role, String key) =>
    _item(profileCompletionItemsFor(input, role), key).done;

void main() {
  // ───────────────────────────────────────────────────────────────────────
  group('complétion — je remplis UN champ, l’élément passe au vert', () {
    for (final role in ['owner', 'sitter', 'walker']) {
      test('rôle $role : chaque élément part rouge et devient vert', () {
        const empty = ProfileCompletionInput();
        // Tout est rouge au départ.
        expect(profileCompletionPercentFor(empty, role), 0);
        for (final i in profileCompletionItemsFor(empty, role)) {
          expect(i.done, isFalse, reason: 'élément « ${i.key} » déjà rempli ?');
        }

        // « Nom » : les DEUX parties sont exigées (v575).
        expect(_done(const ProfileCompletionInput(name: 'Daniel'), role, 'name'), isFalse);
        expect(
          _done(const ProfileCompletionInput(name: 'Daniel Cardelli'), role, 'name'),
          isTrue,
        );

        expect(
          _done(const ProfileCompletionInput(avatarUrl: 'https://cdn/a.jpg'), role, 'photo'),
          isTrue,
        );
        expect(
          _done(const ProfileCompletionInput(mobile: '612345678'), role, 'phone'),
          isTrue,
        );
        expect(
          _done(const ProfileCompletionInput(address: '3 rue des Lilas'), role, 'address'),
          isTrue,
        );
        // Ville PLATE : c'est ce que les 3 écrans envoient quand il n'y a pas
        // de GPS (`payload['city']`), et c'est ce que le serveur renvoie.
        expect(_done(const ProfileCompletionInput(city: 'Paris'), role, 'city'), isTrue);

        // Bio : 20 caractères minimum, comme l'aide de l'écran l'annonce.
        expect(_done(const ProfileCompletionInput(bio: 'Bonjour'), role, 'bio'), isFalse);
        expect(
          _done(
            const ProfileCompletionInput(
                bio: 'Je garde des animaux depuis dix ans.'),
            role,
            'bio',
          ),
          isTrue,
        );
      });
    }

    test('gardien : chaque service réellement enregistré coche « Services »', () {
      for (final s in _kSitterServices) {
        expect(
          _done(ProfileCompletionInput(services: [s]), 'sitter', 'services'),
          isTrue,
          reason: 'service gardien « $s » non pris en compte',
        );
      }
      for (final a in _kSitterAnimals) {
        expect(
          _done(ProfileCompletionInput(acceptedPetTypes: [a]), 'sitter', 'animals'),
          isTrue,
          reason: 'animal gardien « $a » non pris en compte',
        );
      }
    });

    test('promeneur : les ids de promenade sont d’autres valeurs, et marchent', () {
      for (final s in _kWalkerServices) {
        expect(
          _done(ProfileCompletionInput(services: [s]), 'walker', 'services'),
          isTrue,
          reason: 'type de promenade « $s » non pris en compte',
        );
      }
      for (final a in _kWalkerAnimals) {
        expect(
          _done(ProfileCompletionInput(acceptedPetTypes: [a]), 'walker', 'animals'),
          isTrue,
          reason: 'animal promené « $a » non pris en compte',
        );
      }
    });

    test('propriétaire : « Mes animaux » se coche avec un animal enregistré', () {
      expect(_done(const ProfileCompletionInput(petsCount: 1), 'owner', 'pets'), isTrue);
      // Le propriétaire n'a NI services NI animaux acceptés.
      final keys =
          profileCompletionItemsFor(const ProfileCompletionInput(), 'owner')
              .map((e) => e.key);
      expect(keys.contains('services'), isFalse);
      expect(keys.contains('animals'), isFalse);
    });

    test('le pourcentage monte à chaque champ rempli, jusqu’à 100 %', () {
      for (final role in ['owner', 'sitter', 'walker']) {
        var input = const ProfileCompletionInput();
        var last = profileCompletionPercentFor(input, role);
        expect(last, 0);

        input = input.copyForTest(name: 'Daniel Cardelli');
        expect(profileCompletionPercentFor(input, role), greaterThan(last));
        last = profileCompletionPercentFor(input, role);

        input = input.copyForTest(avatarUrl: 'https://cdn/a.jpg');
        expect(profileCompletionPercentFor(input, role), greaterThan(last));
        last = profileCompletionPercentFor(input, role);

        input = input.copyForTest(mobile: '612345678');
        expect(profileCompletionPercentFor(input, role), greaterThan(last));
        last = profileCompletionPercentFor(input, role);

        input = input.copyForTest(address: '3 rue des Lilas');
        expect(profileCompletionPercentFor(input, role), greaterThan(last));
        last = profileCompletionPercentFor(input, role);

        input = input.copyForTest(city: 'Paris');
        expect(profileCompletionPercentFor(input, role), greaterThan(last));
        last = profileCompletionPercentFor(input, role);

        input = input.copyForTest(bio: 'Je garde des animaux depuis dix ans.');
        expect(profileCompletionPercentFor(input, role), greaterThan(last));
        last = profileCompletionPercentFor(input, role);

        if (role == 'owner') {
          input = input.copyForTest(petsCount: 1);
        } else {
          input = input.copyForTest(
            services: role == 'walker' ? _kWalkerServices.take(1).toList() : ['sit_home'],
            acceptedPetTypes: const ['dog'],
          );
        }
        expect(profileCompletionPercentFor(input, role), 100,
            reason: 'rôle $role : le profil complet doit afficher 100 %');
      }
    });

    test('le gardien a bien une cible d’écran pour chaque élément', () {
      // C'est ce qui manquait au promeneur : l'ancre « Animaux acceptés ».
      for (final role in ['sitter', 'walker']) {
        final items = profileCompletionItemsFor(const ProfileCompletionInput(), role);
        expect(_item(items, 'services').focusField, ProfileFocusField.services);
        expect(_item(items, 'animals').focusField, ProfileFocusField.animals);
        expect(_item(items, 'services').target, ProfileFixTarget.editProfile);
        expect(_item(items, 'animals').target, ProfileFixTarget.editProfile);
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('bandeaux — aucun texte serveur anglais ne passe', () {
    test('le message vécu par Daniel devient une clé traduite', () {
      expect(
        serverErrorKey(
          statusCode: 400,
          rawMessage: 'Email must be a non-empty string.',
        ),
        'fixes576_err_email_required',
      );
    });

    test('quelques messages serveur réels du code', () {
      expect(
        serverErrorKey(
          statusCode: 409,
          rawMessage: 'This email is already associated with another account.',
        ),
        'fixes576_err_email_taken',
      );
      expect(
        serverErrorKey(statusCode: 400, rawMessage: 'Name must be a non-empty string.'),
        'fixes576_err_name_required',
      );
      expect(
        serverErrorKey(statusCode: 404, rawMessage: 'Sitter not found.'),
        'fixes576_err_not_found',
      );
      expect(
        serverErrorKey(statusCode: 403, rawMessage: 'Walker role required.'),
        'fixes576_err_forbidden',
      );
    });

    test('le `code` du serveur est prioritaire sur tout le reste', () {
      expect(
        serverErrorKey(code: 'CITY_REQUIRED', statusCode: 400, rawMessage: 'whatever'),
        'fixes576_err_city_required',
      );
    });

    test('statut HTTP seul : une clé par famille', () {
      expect(serverErrorKey(statusCode: 400), 'fixes576_err_invalid');
      expect(serverErrorKey(statusCode: 401), 'fixes576_err_auth');
      expect(serverErrorKey(statusCode: 403), 'fixes576_err_forbidden');
      expect(serverErrorKey(statusCode: 409), 'fixes576_err_conflict');
      expect(serverErrorKey(statusCode: 429), 'fixes576_err_too_many');
      expect(serverErrorKey(statusCode: 500), 'fixes576_err_server');
      expect(serverErrorKey(statusCode: 503), 'fixes576_err_server');
    });

    test('rien de reconnu → message générique, jamais le texte serveur', () {
      final key = serverErrorKey(
        statusCode: 418,
        rawMessage: 'Something totally unexpected happened in the pipeline',
      );
      expect(key, 'fixes576_err_generic');
      expect(key.contains(' '), isFalse, reason: 'ce doit être une CLÉ, pas un texte');
    });

    test('errorKeyFor couvre réseau coupé et serveur trop lent', () {
      expect(
        errorKeyFor(NetworkUnreachableException('no route')),
        'fixes576_err_network',
      );
      expect(
        errorKeyFor(ApiTimeoutException('timeout')),
        'fixes576_err_timeout',
      );
      expect(
        errorKeyFor(ApiException('Email must be a non-empty string.', statusCode: 400)),
        'fixes576_err_email_required',
      );
      // Le `code` du corps JSON est lu dans `details`.
      expect(
        errorKeyFor(ApiException('boom', statusCode: 400, details: {'code': 'CITY_REQUIRED'})),
        'fixes576_err_city_required',
      );
      // Une exception quelconque retombe sur le repli demandé.
      expect(errorKeyFor(StateError('x'), fallbackKey: 'profile_update_failed'),
          'profile_update_failed');
    });

    test('toute clé renvoyée existe dans le paquet i18n', () {
      final en = fixes576I18n['en']!;
      final produced = <String>{
        serverErrorKey(statusCode: 400),
        serverErrorKey(statusCode: 401),
        serverErrorKey(statusCode: 403),
        serverErrorKey(statusCode: 404),
        serverErrorKey(statusCode: 409),
        serverErrorKey(statusCode: 429),
        serverErrorKey(statusCode: 500),
        serverErrorKey(),
        serverErrorKey(code: 'CITY_REQUIRED'),
        serverErrorKey(code: 'EMAIL_TAKEN'),
        serverErrorKey(code: 'INVALID_EMAIL'),
        serverErrorKey(code: 'NAME_REQUIRED'),
        serverErrorKey(rawMessage: 'Email must be a non-empty string.'),
        errorKeyFor(NetworkUnreachableException('x')),
        errorKeyFor(ApiTimeoutException('x')),
      };
      for (final k in produced) {
        expect(en.containsKey(k), isTrue, reason: 'clé i18n manquante : $k');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('pastilles de rôle — une seule source de libellé', () {
    test('roleLabelKey couvre les 3 rôles, casse indifférente', () {
      expect(roleLabelKey('owner'), 'fixes576_role_owner');
      expect(roleLabelKey('Sitter'), 'fixes576_role_sitter');
      expect(roleLabelKey('WALKER'), 'fixes576_role_walker');
      // Valeur inconnue = propriétaire (comportement historique).
      expect(roleLabelKey('autre'), 'fixes576_role_owner');
      expect(roleLabelKey(''), 'fixes576_role_owner');
    });

    test('les 3 libellés existent dans les 9 langues', () {
      for (final entry in fixes576I18n.entries) {
        for (final role in ['owner', 'sitter', 'walker']) {
          final k = roleLabelKey(role);
          expect(entry.value.containsKey(k), isTrue,
              reason: '${entry.key} : $k manquant');
          expect(entry.value[k]!.trim(), isNotEmpty);
        }
      }
    });

    test('français : pas de franglais dans les libellés de rôle', () {
      final fr = fixes576I18n['fr']!;
      expect(fr['fixes576_role_owner'], 'Propriétaire');
      expect(fr['fixes576_role_sitter'], 'Gardien');
      expect(fr['fixes576_role_walker'], 'Promeneur');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('i18n fixes576 — 9 langues, mêmes clés', () {
    const locales = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

    test('les 9 langues sont présentes', () {
      expect(fixes576I18n.keys.toSet(), locales.toSet());
    });

    test('chaque langue porte EXACTEMENT les clés de l’anglais', () {
      final ref = fixes576I18n['en']!.keys.toSet();
      for (final l in locales) {
        final keys = fixes576I18n[l]!.keys.toSet();
        expect(keys.difference(ref), isEmpty, reason: '$l : clés en trop');
        expect(ref.difference(keys), isEmpty, reason: '$l : clés manquantes');
      }
    });

    test('aucune valeur vide, aucune valeur identique à la clé', () {
      for (final entry in fixes576I18n.entries) {
        entry.value.forEach((k, v) {
          expect(v.trim(), isNotEmpty, reason: '${entry.key}/$k vide');
          expect(v, isNot(k), reason: '${entry.key}/$k affiche la clé brute');
        });
      }
    });

    test('toutes les clés portent le préfixe du lot', () {
      for (final k in fixes576I18n['en']!.keys) {
        expect(k.startsWith('fixes576_'), isTrue, reason: 'clé hors lot : $k');
      }
    });

    test('français et anglais ne sont pas identiques (vraie traduction)', () {
      final en = fixes576I18n['en']!;
      final fr = fixes576I18n['fr']!;
      var identical = 0;
      for (final k in en.keys) {
        if (en[k] == fr[k]) identical += 1;
      }
      // « Pet sitter » / « Dog walker » n'existent qu'en anglais ici : on
      // tolère quelques marques, pas une copie du fichier anglais.
      expect(identical, lessThan(3), reason: '$identical valeurs non traduites en fr');
    });
  });
}

/// Petit helper local : `ProfileCompletionInput` est immuable et n'a pas de
/// `copyWith`. On n'en ajoute pas au code de production pour un test.
extension on ProfileCompletionInput {
  ProfileCompletionInput copyForTest({
    String? name,
    String? avatarUrl,
    String? mobile,
    String? address,
    String? city,
    String? bio,
    List<String>? services,
    List<String>? acceptedPetTypes,
    int? petsCount,
  }) =>
      ProfileCompletionInput(
        name: name ?? this.name,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        mobile: mobile ?? this.mobile,
        address: address ?? this.address,
        city: city ?? this.city,
        bio: bio ?? this.bio,
        services: services ?? this.services,
        acceptedPetTypes: acceptedPetTypes ?? this.acceptedPetTypes,
        petsCount: petsCount ?? this.petsCount,
      );
}
