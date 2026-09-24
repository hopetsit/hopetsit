// v583 — lot A du chantier du 24/09 : fenêtre de suivi publicitaire d'Apple
// (ATT), décision de Daniel du 23/09.
//
// Ce qui est vérifié, sans simulateur :
//   · la règle PURE `attPromptAllowed` : jamais avant l'entrée dans l'app,
//     jamais tant que la question « notifications » n'a pas sa réponse, jamais
//     dans la même session qu'une fenêtre système de notifications, jamais
//     deux fois (statut déjà connu) ;
//   · les 9 traductions `InfoPlist.strings` existent dans `ios/Runner/<lang>.lproj/`
//     avec la clé NSUserTrackingUsageDescription, et le projet Xcode les
//     embarque (variant group + phase Resources + knownRegions) — sinon elles
//     ne sont PAS dans l'IPA. ⚠️ `frontend/ios` est local au Mac : ce test
//     échoue volontairement si le dossier isolé de publication ne l'a pas reçu.
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/meta_events_service.dart';

const List<String> _langs = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

void main() {
  group('attPromptAllowed', () {
    bool ok({
      bool hasSession = true,
      bool decided = true,
      bool shown = false,
      TrackingStatus status = TrackingStatus.notDetermined,
    }) =>
        attPromptAllowed(
          hasSession: hasSession,
          notificationsDecided: decided,
          notificationPromptShownThisSession: shown,
          status: status,
        );

    test('cas nominal : entré dans l\'app, notifications déjà décidées, jamais demandé → oui', () {
      expect(ok(), isTrue);
    });

    test('tout premier lancement, sans compte → non (plus de fenêtre avant l\'inscription)', () {
      expect(ok(hasSession: false), isFalse);
    });

    test('la question « notifications » n\'a pas encore de réponse → non', () {
      expect(ok(decided: false), isFalse);
    });

    test('la fenêtre des notifications a été posée dans CETTE session → non', () {
      expect(ok(shown: true), isFalse);
    });

    test('Apple a déjà une réponse (autorisé, refusé, restreint) → non', () {
      for (final s in [
        TrackingStatus.authorized,
        TrackingStatus.denied,
        TrackingStatus.restricted,
      ]) {
        expect(ok(status: s), isFalse, reason: '$s');
      }
    });

    test('session d\'inscription : notifications posées puis décidées → toujours non cette session', () {
      // Après « Activer » à l'entrée dans l'app, le statut devient décidé
      // DANS la session : le drapeau « posée cette session » bloque quand même.
      expect(ok(decided: true, shown: true), isFalse);
    });
  });

  group('traductions ATT embarquées (ios/Runner)', () {
    final root = Directory('ios/Runner');

    test('9 fichiers <lang>.lproj/InfoPlist.strings avec la clé ATT', () {
      expect(root.existsSync(), isTrue,
          reason: 'frontend/ios absent : copier le dossier iOS local du Mac');
      for (final l in _langs) {
        final f = File('ios/Runner/$l.lproj/InfoPlist.strings');
        expect(f.existsSync(), isTrue, reason: '$l manquant');
        final txt = f.readAsStringSync();
        final m = RegExp(r'"NSUserTrackingUsageDescription"\s*=\s*"(.+)";').firstMatch(txt);
        expect(m, isNotNull, reason: '$l : clé NSUserTrackingUsageDescription absente');
        expect(m!.group(1)!.trim().length, greaterThan(20), reason: '$l : texte vide');
        expect(txt.contains('HoPetSit'), isTrue, reason: '$l : le nom de l\'app doit apparaître');
      }
    });

    test('le projet Xcode embarque chaque langue (sinon absentes de l\'IPA)', () {
      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(pbx.contains('name = InfoPlist.strings;'), isTrue, reason: 'variant group absent');
      expect(pbx.contains('/* InfoPlist.strings in Resources */,'), isTrue,
          reason: 'InfoPlist.strings absent de la phase Resources');
      for (final l in _langs) {
        expect(pbx.contains('path = $l.lproj/InfoPlist.strings;'), isTrue,
            reason: '$l.lproj non référencé dans le projet');
      }
      final known = RegExp(r'knownRegions = \(([^)]*)\);').firstMatch(pbx);
      expect(known, isNotNull);
      for (final l in _langs) {
        expect(RegExp('\\b$l,').hasMatch(known!.group(1)!), isTrue,
            reason: '$l absent de knownRegions');
      }
    });

    test('Info.plist déclare les 9 langues (CFBundleLocalizations)', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      final block = RegExp(r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>', dotAll: true)
          .firstMatch(plist);
      expect(block, isNotNull);
      for (final l in _langs) {
        expect(block!.group(1)!.contains('<string>$l</string>'), isTrue, reason: l);
      }
    });
  });
}
