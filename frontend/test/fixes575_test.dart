// v575 — audit des parcours : les fonctions PURES ajoutées par le lot.
//
//   • durée réelle d'une promenade (P0-1 / P1-6 / P1-7) — elle était écrasée
//     à 30 ou 60 minutes ;
//   • déduplication des bandeaux (P2-6) — un bandeau au message DIFFÉRENT
//     était avalé par le rate-limit global de 600 ms ;
//   • libellé du profil destinataire d'une notification (P1-3).
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/localization/v565/fixes575_i18n.dart';
import 'package:hopetsit/utils/walk_duration.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

void main() {
  group('durée de promenade — bornes du serveur', () {
    test('multiples de 15 entre 15 et 300 minutes', () {
      for (final d in <int>[15, 30, 45, 60, 75, 90, 120, 180, 300]) {
        expect(isValidWalkDuration(d), isTrue, reason: '$d min');
      }
      for (final d in <int>[0, 7, 14, 20, 61, 301, 315, -30]) {
        expect(isValidWalkDuration(d), isFalse, reason: '$d min');
      }
      expect(isValidWalkDuration(null), isFalse);
      expect(isValidWalkDuration(45.5), isFalse);
    });

    test('arrondi au multiple de 15 le plus proche, borné 15–300', () {
      expect(roundToWalkDuration(44), 45);
      expect(roundToWalkDuration(47), 45);
      expect(roundToWalkDuration(53), 60);
      expect(roundToWalkDuration(88), 90);
      expect(roundToWalkDuration(3), 15);
      expect(roundToWalkDuration(9999), 300);
      expect(roundToWalkDuration(0), isNull);
      expect(roundToWalkDuration(-10), isNull);
      expect(roundToWalkDuration(null), isNull);
      expect(roundToWalkDuration(double.nan), isNull);
    });
  });

  group('durée réelle de l\'annonce (P1-6 / P1-7)', () {
    final start = DateTime(2026, 10, 1, 10, 0);

    test('la durée CHOISIE par le propriétaire prime', () {
      expect(
        walkDurationForPost(
          chosen: 90,
          start: start,
          end: start.add(const Duration(minutes: 30)),
        ),
        90,
      );
    });

    test('sans durée choisie : fin − début, sans écrasement à 30 ou 60', () {
      // Le bug : `<= 45 ? 30 : 60` renvoyait 60 pour une annonce de 90 min.
      expect(
        walkDurationForPost(
          start: start,
          end: start.add(const Duration(minutes: 90)),
        ),
        90,
      );
      expect(
        walkDurationForPost(
          start: start,
          end: start.add(const Duration(minutes: 120)),
        ),
        120,
      );
      expect(
        walkDurationForPost(
          start: start,
          end: start.add(const Duration(minutes: 45)),
        ),
        45,
      );
    });

    test('durée non alignée → arrondie, jamais refusée par le serveur', () {
      final d = walkDurationForPost(
        start: start,
        end: start.add(const Duration(minutes: 50)),
      );
      expect(d, 45);
      expect(isValidWalkDuration(d), isTrue);
    });

    test('annonce hors bornes → ramenée dans 15–300', () {
      expect(
        walkDurationForPost(
          start: start,
          end: start.add(const Duration(hours: 9)),
        ),
        300,
      );
      expect(
        walkDurationForPost(
          start: start,
          end: start.add(const Duration(minutes: 2)),
        ),
        15,
      );
    });

    test('durée choisie invalide → on retombe sur les dates', () {
      expect(
        walkDurationForPost(
          chosen: 0,
          start: start,
          end: start.add(const Duration(minutes: 60)),
        ),
        60,
      );
    });

    test('annonce sans dates ni durée → repli 30 min (comportement d\'avant)',
        () {
      expect(walkDurationForPost(), 30);
      expect(walkDurationForPost(start: start), 30);
    });
  });

  group('déduplication des bandeaux (P2-6)', () {
    setUp(CustomSnackbar.debugResetBannerDedupe);

    test('le même couple (titre, message) est bien dédupliqué', () {
      expect(CustomSnackbar.debugShouldSuppress('Erreur', 'Réessaie'), isFalse);
      expect(CustomSnackbar.debugShouldSuppress('Erreur', 'Réessaie'), isTrue);
      expect(CustomSnackbar.debugShouldSuppress('Erreur', 'Réessaie'), isTrue);
    });

    test('un message DIFFÉRENT passe immédiatement (bug des bandeaux avalés)',
        () {
      expect(CustomSnackbar.debugShouldSuppress('Succès', 'Enregistré'), isFalse);
      // Avant : supprimé par le rate-limit global de 600 ms → l'utilisateur
      // ne voyait jamais la seconde information.
      expect(
        CustomSnackbar.debugShouldSuppress('Erreur', 'Carte refusée'),
        isFalse,
      );
      expect(
        CustomSnackbar.debugShouldSuppress('Erreur', 'Durée invalide'),
        isFalse,
      );
    });

    test('même message, titre différent → affiché', () {
      expect(CustomSnackbar.debugShouldSuppress('Erreur', 'Réessaie'), isFalse);
      expect(
        CustomSnackbar.debugShouldSuppress('Attention', 'Réessaie'),
        isFalse,
      );
    });
  });

  group('profil destinataire d\'une notification (P1-3)', () {
    test('chaque rôle a sa clé de libellé', () {
      expect(fixes575RoleLabelKey('owner'), 'fixes575_role_owner');
      expect(fixes575RoleLabelKey('Sitter'), 'fixes575_role_sitter');
      expect(fixes575RoleLabelKey(' walker '), 'fixes575_role_walker');
      expect(fixes575RoleLabelKey(''), 'fixes575_role_owner');
    });
  });

  group('paquet de traductions fixes575', () {
    const langs = <String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

    test('les 9 langues portent EXACTEMENT les mêmes clés', () {
      expect(fixes575I18n.keys.toSet(), langs.toSet());
      final reference = fixes575I18n['en']!.keys.toSet();
      expect(reference, isNotEmpty);
      for (final lang in langs) {
        expect(fixes575I18n[lang]!.keys.toSet(), reference, reason: lang);
      }
    });

    test('toutes les clés sont préfixées et aucune valeur n\'est vide', () {
      for (final lang in langs) {
        fixes575I18n[lang]!.forEach((key, value) {
          expect(key.startsWith('fixes575_'), isTrue, reason: '$lang/$key');
          expect(value.trim(), isNotEmpty, reason: '$lang/$key');
        });
      }
    });

    test('le placeholder {role} est présent dans les 9 langues', () {
      for (final lang in langs) {
        expect(
          fixes575I18n[lang]!['fixes575_notification_other_role'],
          contains('{role}'),
          reason: lang,
        );
      }
    });
  });
}
