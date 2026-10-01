// v583 — lot A du chantier du 24/09 : fenêtre de suivi publicitaire d'Apple
// (ATT), décision de Daniel du 23/09.
//
// 606 (ZOE, 01/10) — refus Apple 2.1 : l'examinateur n'a jamais vu la
// fenêtre. Nouvelle règle : présentée dès la 1re session, juste APRÈS la
// question « notifications » (plus jamais repoussée au lancement suivant).
//
// Ce qui est vérifié, sans simulateur :
//   · la règle PURE `attPromptAllowed` : jamais avant l'entrée dans l'app,
//     jamais PENDANT la question « notifications », jamais app inactive,
//     jamais deux fois (statut déjà connu) ;
//   · `runAttPromptWhenReady` rejoue la session unique de l'examinateur
//     (installation neuve → connexion → notifications → ATT) : la fenêtre est
//     demandée UNE fois, dans la même session ;
//   · aucun suivi publicitaire avant « Autoriser » (`adTrackingAllowed`,
//     Info.plist : journal auto Meta et signaux pub Firebase coupés) ;
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
  group('attPromptAllowed (606)', () {
    bool ok({
      bool hasSession = true,
      bool busy = false,
      bool active = true,
      TrackingStatus status = TrackingStatus.notDetermined,
    }) =>
        attPromptAllowed(
          hasSession: hasSession,
          notificationFlowBusy: busy,
          appActive: active,
          status: status,
        );

    test('cas nominal : dans l\'app, pas de question en cours, jamais demandé → oui', () {
      expect(ok(), isTrue);
    });

    test('tout premier lancement, sans compte → non (pas avant l\'inscription)', () {
      expect(ok(hasSession: false), isFalse);
    });

    test('question « notifications » EN COURS → non (l\'ATT passe juste après)', () {
      expect(ok(busy: true), isFalse);
    });

    test('app pas au premier plan → non (iOS ignorerait la demande)', () {
      expect(ok(active: false), isFalse);
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
  });

  group('runAttPromptWhenReady — session unique de l\'examinateur', () {
    const fast = Duration(milliseconds: 5);

    test('installation neuve → connexion → notifications répondues → ATT dans la MÊME session',
        () async {
      var session = false;
      var busy = false;
      var status = TrackingStatus.notDetermined;
      var requests = 0;
      final events = <String>[];
      // Démarrage sans compte : pas de fenêtre, rien de consommé.
      final first = await runAttPromptWhenReady(
        hasSession: () => session,
        notificationFlowBusy: () => busy,
        appActive: () => true,
        readStatus: () async => status,
        request: () async {
          requests++;
          return status = TrackingStatus.authorized;
        },
        initialDelay: fast,
        poll: fast,
      );
      expect(first, isNull);
      expect(requests, 0);

      // Connexion : la question « notifications » est en cours.
      session = true;
      busy = true;
      final f = runAttPromptWhenReady(
        hasSession: () => session,
        notificationFlowBusy: () => busy,
        appActive: () => true,
        readStatus: () async => status,
        request: () async {
          events.add('ATT');
          requests++;
          return status = TrackingStatus.denied;
        },
        initialDelay: fast,
        poll: fast,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(requests, 0, reason: 'jamais par-dessus la question notifications');
      events.add('notifications répondues');
      busy = false;
      final answer = await f;
      expect(requests, 1, reason: 'ATT demandée une fois, même session');
      expect(answer, TrackingStatus.denied);
      expect(events, ['notifications répondues', 'ATT']);
    });

    test('notifications déjà décidées (relance) → ATT tout de suite', () async {
      var requests = 0;
      final r = await runAttPromptWhenReady(
        hasSession: () => true,
        notificationFlowBusy: () => false,
        appActive: () => true,
        readStatus: () async => TrackingStatus.notDetermined,
        request: () async {
          requests++;
          return TrackingStatus.authorized;
        },
        initialDelay: fast,
        poll: fast,
      );
      expect(requests, 1);
      expect(r, TrackingStatus.authorized);
    });

    test('app en arrière-plan → attend le retour au premier plan', () async {
      var active = false;
      var requests = 0;
      final f = runAttPromptWhenReady(
        hasSession: () => true,
        notificationFlowBusy: () => false,
        appActive: () => active,
        readStatus: () async => TrackingStatus.notDetermined,
        request: () async {
          requests++;
          return TrackingStatus.authorized;
        },
        initialDelay: fast,
        poll: fast,
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(requests, 0);
      active = true;
      await f;
      expect(requests, 1);
    });

    test('déjà répondu → aucune nouvelle demande', () async {
      var requests = 0;
      final r = await runAttPromptWhenReady(
        hasSession: () => true,
        notificationFlowBusy: () => false,
        appActive: () => true,
        readStatus: () async => TrackingStatus.denied,
        request: () async {
          requests++;
          return TrackingStatus.denied;
        },
        initialDelay: fast,
        poll: fast,
      );
      expect(r, isNull);
      expect(requests, 0);
    });
  });

  group('aucun suivi publicitaire avant « Autoriser »', () {
    test('adTrackingAllowed : iOS seulement si autorisé ; Android inchangé', () {
      for (final s in TrackingStatus.values) {
        expect(adTrackingAllowed(isIOS: true, status: s), s == TrackingStatus.authorized,
            reason: '$s');
        expect(adTrackingAllowed(isIOS: false, status: s), isTrue);
      }
    });

    test('Info.plist : journal auto Meta, IDFA et signaux pub Firebase coupés au lancement', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      for (final k in [
        'FacebookAutoLogAppEventsEnabled',
        'FacebookAdvertiserIDCollectionEnabled',
        'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE',
        'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA',
        'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS',
      ]) {
        expect(RegExp('<key>$k</key>\\s*<false/>').hasMatch(plist), isTrue, reason: k);
      }
    });

    test('le code ne réactive le suivi Meta qu\'à travers adTrackingAllowed', () {
      final src = File('lib/services/meta_events_service.dart').readAsStringSync();
      expect(src.contains('setAutoLogAppEventsEnabled(true)'), isFalse);
      expect(src.contains('setAdvertiserTracking(enabled: true'), isFalse);
      final reg = src.indexOf('Future<void> logCompletedRegistration');
      final body = src.substring(reg, reg + 500);
      expect(body.indexOf('adTrackingAllowed'), lessThan(body.indexOf('_fb.logCompletedRegistration')));
    });

    test('déclencheurs : démarrage ET arrivée sur l\'accueil', () {
      expect(File('lib/main.dart').readAsStringSync().contains('requestTrackingAfterEntry()'), isTrue);
      expect(
          File('lib/widgets/stacked_navigation_wrapper.dart')
              .readAsStringSync()
              .contains('MetaEventsService.instance.requestTrackingAfterEntry()'),
          isTrue);
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
