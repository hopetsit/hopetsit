// 1711 (NEO, ordre de Daniel du 17/11/2026) — inscription « e-mail d'abord ».
//
// Ce que ces tests rejouent, sur le VRAI écran de l'assistant, contre un faux
// serveur (harnais lot D) qui répond comme `backend/src/routes/emailFirst1711.js` :
//   · l'assistant s'ouvre sur « Ton e-mail », pas sur le formulaire ;
//   · adresse invalide → message, aucun appel ;
//   · faute de frappe du domaine → suggestion cliquable → code envoyé ;
//   · compte déjà existant → « Se connecter » ;
//   · mauvais code → essais restants, rien n'est créé ; bon code → suite de
//     l'assistant avec l'e-mail confirmé, non modifiable ;
//   · compte à rebours « Renvoyer dans 60 s », puis renvoi ;
//   · collage du code ; retour arrière étape par étape ;
//   · POST /auth/signup porte `emailProof`, et AUCUN écran de code après ;
//   · preuve expirée → retour à l'e-mail, saisie gardée ;
//   · repli 404 : parcours d'avant (champ e-mail, signup sans preuve, écran de
//     code) ;
//   · retour dans l'app : adresse en attente ou preuve retrouvées ;
//   · 3 rôles, mode sombre, 9 langues.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';

import 'package:hopetsit/controllers/email_first1711.dart';
import 'package:hopetsit/controllers/sign_up_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/localization/v565/emailfirst1711_i18n.dart';
import 'package:hopetsit/localization/v565/v565_i18n.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/otp_verification_screen.dart';
import 'package:hopetsit/views/auth/signup_wizard_screen.dart';
import 'package:hopetsit/widgets/city_location_picker.dart';

import 'lotd_harness.dart';

const _langs = <String>['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const _email = 'lea.martin@example.test';

/// Faux serveur « e-mail d'abord » : mêmes réponses que la route réelle.
class _Server {
  String goodCode = '123456';
  int left = 5;
  bool route404 = false;
  bool exists = false;
  int? signupStatus;
  String? signupCode;

  Map<String, dynamic> call(http.Request req) {
    final path = req.url.path;
    if (path.endsWith('/auth/email-first/send')) {
      if (route404) return {'__status': 404, 'error': 'Not found'};
      final email = (lotdRequests.last.body?['email'] ?? '').toString();
      if (email.endsWith('@gmail.con')) {
        return {'suggestion': email.replaceAll('@gmail.con', '@gmail.com')};
      }
      if (exists) return {'exists': true};
      return {'ok': true, 'sent': true, 'retryAfter': 60};
    }
    if (path.endsWith('/auth/email-first/check')) {
      final code = (lotdRequests.last.body?['code'] ?? '').toString();
      if (code == goodCode) return {'emailProof': 'proof-abc', 'expiresIn': 3600};
      left -= 1;
      if (left < 0) return {'__status': 429, 'code': 'TOO_MANY_TRIES', 'error': 'TOO_MANY_TRIES'};
      return {'__status': 400, 'code': 'CODE_INVALID', 'error': 'CODE_INVALID', 'left': left};
    }
    if (path.endsWith('/auth/signup') && signupStatus != null) {
      return {'__status': signupStatus, 'code': signupCode, 'error': signupCode};
    }
    return const <String, dynamic>{};
  }
}

List<LotdRequest> _calls(String suffix) =>
    lotdRequests.where((r) => r.path.endsWith(suffix)).toList();

SignUpController _put(String userType) => Get.put(
      SignUpController(userType: userType, authRepository: Get.find<AuthRepository>()),
      tag: userType,
      permanent: true,
    );

Future<void> _open(WidgetTester tester, String userType,
    {Brightness brightness = Brightness.light, Locale locale = const Locale('fr', 'FR')}) async {
  lotdPhone(tester);
  await tester.pumpWidget(lotdApp(SignupWizardScreen(userType: userType),
      brightness: brightness, locale: locale));
  await lotdSettle(tester);
}

Future<void> _typeEmail(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('ef_email_field')), email);
  await tester.pump();
  await tester.tap(find.byKey(const Key('ef_primary')));
  await lotdSettle(tester);
}

Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(
      find.descendant(of: find.byType(Pinput), matching: find.byType(EditableText)), code);
  await lotdSettle(tester);
}

/// Fin de test : arrête le compte à rebours et laisse partir les bannières.
Future<void> _finish(WidgetTester tester, SignUpController c) async {
  c.emailFirst.dispose();
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
}

void _fillOwner(SignUpController c) {
  c.firstNameController.text = 'Léa';
  c.lastNameController.text = 'Martin';
  c.passwordController.text = 'Hopetsit2026!';
  c.confirmPasswordController.text = 'Hopetsit2026!';
  c.cityController.text = 'Zone test';
  markCityPicked610(c.cityController, 'Zone test');
  c.postalCodeController.text = '97500';
  c.selectedServices.add('walk');
  c.agreeToTerms.value = true;
}

void main() {
  late _Server server;

  setUp(() async {
    await lotdSetUp(role: 'owner');
    // Personne n'est connecté pendant une inscription.
    await GetStorage().erase();
    server = _Server();
    lotdResponder = server.call;
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('textes', () {
    test('9 langues, mêmes clés partout, aucune valeur vide, {s} et {n} conservés', () {
      expect(emailFirst1711I18n.keys.toSet(), _langs.toSet());
      final keys = emailFirst1711I18n['fr']!.keys.toSet();
      expect(keys.length, 35);
      for (final l in _langs) {
        final m = emailFirst1711I18n[l]!;
        expect(m.keys.toSet(), keys, reason: l);
        expect(m.values.every((v) => v.trim().isNotEmpty), isTrue, reason: l);
        expect(m['ef_code_resend_in'], contains('{s}'), reason: l);
        expect(m['ef_err_code_wrong'], contains('{n}'), reason: l);
      }
    });

    test('paquet branché dans le registre et dans AppTranslations', () {
      expect(v565Packs.contains(emailFirst1711I18n), isTrue);
      final all = AppTranslations().keys;
      for (final l in _langs) {
        final locale =
            all.keys.firstWhere((k) => k == l || k.startsWith('${l}_'), orElse: () => '');
        expect(locale, isNotEmpty, reason: l);
        expect(all[locale]!['ef_email_title'], emailFirst1711I18n[l]!['ef_email_title'],
            reason: locale);
      }
    });

    test('code extrait d\'un texte collé', () {
      expect(EmailFirst1711.extractCode('123456'), '123456');
      expect(EmailFirst1711.extractCode('123 456'), '123456');
      expect(EmailFirst1711.extractCode('123-456'), '123456');
      expect(EmailFirst1711.extractCode('654321 — ton code HoPetSit'), '654321');
      expect(EmailFirst1711.extractCode('Voici ton code : 908172. Valable 60 minutes.'), '908172');
      expect(EmailFirst1711.extractCode('bonjour'), '');
      expect(EmailFirst1711.extractCode('12345'), '');
      expect(EmailFirst1711.extractCode('1234567'), '');
    });
  });

  group('parcours', () {
    testWidgets('l\'assistant s\'ouvre sur « Ton e-mail » ; adresse invalide = message, aucun appel',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      expect(find.text('Ton e-mail'), findsOneWidget);
      expect(find.text('Recevoir mon code'), findsOneWidget);
      expect(find.text('Prénom'), findsNothing, reason: 'le formulaire vient après le code');
      await _typeEmail(tester, 'pas-une-adresse');
      expect(find.text('Saisis une adresse e-mail valide.'), findsOneWidget);
      expect(_calls('/auth/email-first/send'), isEmpty);
      expect(tester.takeException(), isNull);
      await _finish(tester, c);
    });

    testWidgets('faute de frappe du domaine : suggestion cliquable, puis code envoyé à la bonne adresse',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, 'lea@gmail.con');
      expect(find.byKey(const Key('ef_suggestion')), findsOneWidget);
      expect(find.text('lea@gmail.com'), findsOneWidget);
      expect(find.byKey(const Key('ef_code_step')), findsNothing, reason: 'rien n\'est envoyé');
      await tester.tap(find.byKey(const Key('ef_suggestion')));
      await lotdSettle(tester);
      final sends = _calls('/auth/email-first/send');
      expect(sends.length, 2);
      expect(sends.last.body?['email'], 'lea@gmail.com');
      expect(_langs.contains(sends.last.body?['lang']), isTrue,
          reason: 'langue de l\'app envoyée (une des 9)');
      expect(find.byKey(const Key('ef_code_step')), findsOneWidget);
      expect(find.text('lea@gmail.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester, c);
    });

    testWidgets('compte déjà existant : « Se connecter » ouvre la connexion, aucun code',
        (tester) async {
      server.exists = true;
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      expect(find.byKey(const Key('ef_exists')), findsOneWidget);
      expect(find.text('Tu as déjà un compte'), findsOneWidget);
      expect(find.byKey(const Key('ef_code_step')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('ef_login')));
      await tester.tap(find.byKey(const Key('ef_login')));
      await lotdSettle(tester, frames: 8);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_calls('/auth/signup'), isEmpty);
      await _finish(tester, c);
    });

    testWidgets('mauvais code : essais restants, rien de créé ; bon code : suite avec e-mail confirmé non modifiable',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, 'Lea.Martin@Example.test');
      expect(find.byKey(const Key('ef_code_step')), findsOneWidget);
      expect(find.text('Code reçu par e-mail'), findsOneWidget);
      expect(find.text(_email), findsOneWidget, reason: 'adresse en minuscules');

      await _typeCode(tester, '000000');
      expect(_calls('/auth/email-first/check').length, 1, reason: 'envoi dès la 6e case');
      expect(_calls('/auth/email-first/check').single.body, {'email': _email, 'code': '000000'});
      expect(find.text('Code incorrect. Il te reste 4 essais.'), findsOneWidget);
      expect(find.byKey(const Key('ef_code_step')), findsOneWidget);
      expect(c.emailFirst.codeController.text, isEmpty, reason: 'cases vidées');
      expect(c.emailFirst.proof, isNull);
      // Dès qu'on retape, le message du code précédent disparaît.
      await _typeCode(tester, '48');
      expect(find.byKey(const Key('ef_error')), findsNothing);
      expect(_calls('/auth/email-first/check').length, 1, reason: 'pas d\'envoi avant 6 chiffres');
      // Bouton « Valider » avec un code incomplet : message, aucun appel.
      await tester.tap(find.byKey(const Key('ef_primary')));
      await lotdSettle(tester);
      expect(find.text('Saisis les 6 chiffres du code.'), findsOneWidget);
      expect(_calls('/auth/email-first/check').length, 1);

      server.left = 2;
      await _typeCode(tester, '111111');
      expect(find.text('Code incorrect. Il te reste 1 essai.'), findsOneWidget);
      await _typeCode(tester, '222222');
      expect(
          find.text(
              'Trop de codes incorrects. Réessaie dans 1 heure, ou continue avec Google ou Apple.'),
          findsOneWidget);
      expect(_calls('/auth/signup'), isEmpty, reason: 'aucun compte avant le bon code');

      server.left = 5;
      await _typeCode(tester, '123456');
      expect(c.emailFirst.phase.value, EmailGatePhase.done);
      expect(c.emailFirst.proof, 'proof-abc');
      expect(find.byKey(const Key('ef_code_step')), findsNothing);
      expect(find.text('Prénom'), findsOneWidget, reason: 'suite de l\'assistant');
      await tester.scrollUntilVisible(find.byKey(const Key('ef_confirmed')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(_email), findsOneWidget);
      expect(find.text('E-mail confirmé'), findsOneWidget);
      expect(
          find.byWidgetPredicate((w) => w is TextField && w.controller == c.emailController),
          findsNothing,
          reason: 'e-mail non modifiable');
      expect(_calls('/auth/signup'), isEmpty);
      expect(tester.takeException(), isNull);
      await _finish(tester, c);
    });

    testWidgets('compte à rebours « Renvoyer dans 60 s », puis renvoi possible', (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      expect(c.emailFirst.resendIn.value, inInclusiveRange(58, 60));
      expect(find.byKey(const Key('ef_resend_wait')), findsOneWidget);
      expect(find.byKey(const Key('ef_resend')), findsNothing);
      // `Timer` de test + horloge réelle : on vérifie le texte tel qu'affiché.
      expect(
          find.text('Renvoyer dans ${c.emailFirst.resendIn.value} s'), findsOneWidget);
      // Le temps est écoulé (comme au retour dans l'app après 60 s).
      c.emailFirst.debugExpireCountdown();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byKey(const Key('ef_resend')), findsOneWidget);
      expect(find.text('Renvoyer le code'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ef_resend')));
      await lotdSettle(tester);
      expect(_calls('/auth/email-first/send').length, 2);
      expect(find.text('Nouveau code envoyé.'), findsOneWidget);
      expect(find.byKey(const Key('ef_resend_wait')), findsOneWidget);
      await _finish(tester, c);
    });

    testWidgets('« Coller le code » : le code copié depuis l\'e-mail est vérifié', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '123 456 — ton code HoPetSit'};
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final c = _put('pet_sitter');
      await _open(tester, 'pet_sitter');
      await _typeEmail(tester, _email);
      await tester.tap(find.byKey(const Key('ef_paste')));
      await lotdSettle(tester);
      expect(_calls('/auth/email-first/check').single.body?['code'], '123456');
      expect(c.emailFirst.phase.value, EmailGatePhase.done);
      await _finish(tester, c);
    });

    testWidgets('retour arrière : code → e-mail ; 1re étape → e-mail, « Continuer » sans nouveau code',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      await tester.tap(find.byKey(const Key('ef_change')));
      await lotdSettle(tester);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      expect(c.emailController.text, _email, reason: 'adresse gardée');
      // Même adresse dans la minute : le serveur répond 429 RESEND_TOO_SOON →
      // on retrouve l'écran du code avec le temps restant.
      lotdResponder = (req) => req.url.path.endsWith('/send')
          ? {'__status': 429, 'code': 'RESEND_TOO_SOON', 'error': 'RESEND_TOO_SOON', 'retryAfter': 41}
          : server.call(req);
      await tester.tap(find.byKey(const Key('ef_primary')));
      await lotdSettle(tester);
      expect(find.byKey(const Key('ef_code_step')), findsOneWidget);
      expect(c.emailFirst.resendIn.value, inInclusiveRange(39, 41));
      lotdResponder = server.call;
      // Flèche retour de la barre : code → e-mail.
      await tester.tap(find.byType(BackButton));
      await lotdSettle(tester);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ef_primary')));
      await lotdSettle(tester);
      await _typeCode(tester, '123456');
      expect(c.emailFirst.phase.value, EmailGatePhase.done);
      final sendsBefore = _calls('/auth/email-first/send').length;
      // 1re étape de l'assistant → retour = étape e-mail, adresse confirmée.
      await tester.tap(find.byType(BackButton));
      await lotdSettle(tester);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      expect(find.text('Continuer'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ef_primary')));
      await lotdSettle(tester);
      expect(c.emailFirst.phase.value, EmailGatePhase.done);
      expect(_calls('/auth/email-first/send').length, sendsBefore, reason: 'aucun nouveau code');
      expect(tester.takeException(), isNull);
      await _finish(tester, c);
    });

    testWidgets('inscription : POST /auth/signup porte emailProof, et aucun écran de code après',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      await _typeCode(tester, '123456');
      _fillOwner(c);
      // Quelqu'un a retouché le champ entre-temps : c'est l'adresse CONFIRMÉE qui part.
      c.emailController.text = 'autre@example.test';
      await c.handleWizardSignUp(email: c.emailController.text);
      await lotdSettle(tester, frames: 8);
      final signup = _calls('/auth/signup').single;
      expect(signup.body?['emailProof'], 'proof-abc');
      expect(signup.body?['role'], 'owner');
      expect((signup.body?['user'] as Map)['email'], _email);
      expect((signup.body?['user'] as Map)['city'], 'Zone test');
      expect((signup.body?['user'] as Map)['postalCode'], '97500');
      expect((signup.body?['user'] as Map)['acceptedTerms'], isTrue);
      expect(find.byType(OtpVerificationScreen), findsNothing,
          reason: 'jamais d\'écran de code après une inscription avec preuve');
      // Le faux serveur ne délivre pas de session : la connexion automatique
      // échoue → écran de connexion (compte déjà vérifié), pas l'écran de code.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(GetStorage().read(EmailFirst1711.storageKey), isNull, reason: 'mémoire effacée');
      expect(c.emailFirst.proof, isNull);
      await _finish(tester, c);
    });

    testWidgets('preuve refusée par le serveur (expirée) : retour à l\'e-mail, saisie gardée',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      await _typeCode(tester, '123456');
      _fillOwner(c);
      server
        ..signupStatus = 400
        ..signupCode = 'EMAIL_PROOF_INVALID';
      await c.handleWizardSignUp(email: _email);
      await lotdSettle(tester);
      expect(_calls('/auth/signup').length, 1);
      expect(c.emailFirst.phase.value, EmailGatePhase.email);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      expect(find.text('Ton code a expiré. Demande-en un nouveau pour terminer.'), findsOneWidget);
      expect(c.firstNameController.text, 'Léa', reason: 'saisie conservée');
      expect(c.emailController.text, _email);
      expect(find.byType(OtpVerificationScreen), findsNothing);
      await _finish(tester, c);
    });

    testWidgets('repli 404 (serveur pas à jour) : parcours d\'avant, signup SANS preuve, écran de code',
        (tester) async {
      server.route404 = true;
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      expect(c.emailFirst.phase.value, EmailGatePhase.legacy);
      expect(find.byKey(const Key('ef_email_step')), findsNothing);
      expect(find.byKey(const Key('ef_code_step')), findsNothing);
      expect(find.text('Prénom'), findsOneWidget, reason: 'assistant d\'avant');
      expect(find.byKey(const Key('ef_confirmed')), findsNothing);
      expect(
          find.byWidgetPredicate((w) => w is TextField && w.controller == c.emailController),
          findsOneWidget,
          reason: 'champ e-mail modifiable, déjà rempli');
      expect(c.emailController.text, _email);
      expect(tester.takeException(), isNull);
      _fillOwner(c);
      await c.handleWizardSignUp(email: c.emailController.text);
      await lotdSettle(tester, frames: 8);
      final signup = _calls('/auth/signup').single;
      expect(signup.body?.containsKey('emailProof'), isFalse);
      expect((signup.body?['user'] as Map)['email'], _email);
      expect(find.byType(OtpVerificationScreen), findsOneWidget,
          reason: 'parcours d\'avant : compte puis code');
      // L'écran de code d'avant a son propre compte à rebours (60 s).
      for (int i = 0; i < 65; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await _finish(tester, c);
    });

    testWidgets('repli 404 mais preuve exigée par le serveur (400 EMAIL_PROOF_REQUIRED) : retour à l\'e-mail, pas d\'écran de code',
        (tester) async {
      server.route404 = true;
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      expect(c.emailFirst.phase.value, EmailGatePhase.legacy);
      _fillOwner(c);
      server
        ..signupStatus = 400
        ..signupCode = 'EMAIL_PROOF_REQUIRED';
      await c.handleWizardSignUp(email: c.emailController.text);
      await lotdSettle(tester);
      expect(c.emailFirst.phase.value, EmailGatePhase.email);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(c.firstNameController.text, 'Léa', reason: 'saisie conservée');
      await _finish(tester, c);
    });

    testWidgets('trop de codes dans la journée, adresse de test, e-mail non parti : messages clairs',
        (tester) async {
      final c = _put('pet_walker');
      await _open(tester, 'pet_walker');
      Map<String, dynamic> next = {'__status': 429, 'code': 'TOO_MANY', 'error': 'TOO_MANY'};
      lotdResponder = (_) => next;
      await _typeEmail(tester, _email);
      expect(
          find.text(
              'Trop de codes demandés aujourd\'hui. Réessaie demain, ou continue avec Google ou Apple.'),
          findsOneWidget);
      next = {'__status': 403, 'code': 'TEST_ACCOUNT', 'error': 'TEST_ACCOUNT'};
      await tester.tap(find.byKey(const Key('ef_primary')));
      await lotdSettle(tester);
      expect(find.text('Cette adresse ne peut pas recevoir de code.'), findsOneWidget);
      next = {'__status': 502, 'code': 'EMAIL_NOT_SENT', 'error': 'EMAIL_NOT_SENT'};
      await tester.tap(find.byKey(const Key('ef_primary')));
      await lotdSettle(tester);
      expect(find.text('L\'e-mail n\'a pas pu partir. Vérifie l\'adresse et réessaie.'),
          findsOneWidget);
      expect(c.emailFirst.phase.value, EmailGatePhase.email, reason: 'pas de repli hors 404');
      await _finish(tester, c);
    });
  });

  group('retour dans l\'app', () {
    testWidgets('code envoyé puis app fermée : on retrouve l\'écran du code avec l\'adresse',
        (tester) async {
      final now = DateTime.now();
      await GetStorage().write(EmailFirst1711.storageKey, <String, dynamic>{
        'email': _email,
        'sentAt': now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
        'resendAt': now.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
      });
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      expect(c.emailFirst.phase.value, EmailGatePhase.code);
      expect(find.byKey(const Key('ef_code_step')), findsOneWidget);
      expect(find.text(_email), findsOneWidget);
      expect(find.byKey(const Key('ef_resend')), findsOneWidget, reason: '60 s écoulées');
      expect(_calls('/auth/email-first/send'), isEmpty, reason: 'aucun code renvoyé tout seul');
      await _typeCode(tester, '123456');
      expect(c.emailFirst.phase.value, EmailGatePhase.done);
      await _finish(tester, c);
    });

    testWidgets('preuve encore valable : on reprend à l\'assistant, e-mail confirmé', (tester) async {
      await GetStorage().write(EmailFirst1711.storageKey, <String, dynamic>{
        'email': _email,
        'proof': 'proof-xyz',
        'proofExp': DateTime.now().add(const Duration(minutes: 40)).millisecondsSinceEpoch,
      });
      final c = _put('pet_sitter');
      await _open(tester, 'pet_sitter');
      expect(c.emailFirst.phase.value, EmailGatePhase.done);
      expect(c.emailFirst.proof, 'proof-xyz');
      expect(c.emailController.text, _email);
      expect(find.text('Prénom'), findsOneWidget);
      await _finish(tester, c);
    });

    testWidgets('preuve expirée et code de plus de 60 min : on repart de l\'adresse', (tester) async {
      final old = DateTime.now().subtract(const Duration(minutes: 61));
      await GetStorage().write(EmailFirst1711.storageKey, <String, dynamic>{
        'email': _email,
        'sentAt': old.millisecondsSinceEpoch,
        'proof': 'proof-old',
        'proofExp': old.millisecondsSinceEpoch,
      });
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      expect(c.emailFirst.phase.value, EmailGatePhase.email);
      expect(c.emailFirst.proof, isNull);
      expect(GetStorage().read(EmailFirst1711.storageKey), isNull);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      await _finish(tester, c);
    });

    testWidgets('preuve expirée pendant l\'assistant : nouveau code demandé AVANT tout appel d\'inscription',
        (tester) async {
      final c = _put('pet_owner');
      await _open(tester, 'pet_owner');
      await _typeEmail(tester, _email);
      await _typeCode(tester, '123456');
      _fillOwner(c);
      c.emailFirst.debugExpireProof();
      await c.handleWizardSignUp(email: _email);
      await lotdSettle(tester);
      expect(_calls('/auth/signup'), isEmpty);
      expect(c.emailFirst.phase.value, EmailGatePhase.email);
      expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
      await _finish(tester, c);
    });
  });

  group('rendu', () {
    for (final role in const ['pet_owner', 'pet_sitter', 'pet_walker']) {
      for (final b in Brightness.values) {
        testWidgets('$role, ${b.name} : e-mail puis code, sans exception ni débordement',
            (tester) async {
          final c = _put(role);
          await _open(tester, role, brightness: b);
          expect(find.byKey(const Key('ef_email_step')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'e-mail');
          await _typeEmail(tester, _email);
          expect(find.byKey(const Key('ef_code_step')), findsOneWidget);
          expect(find.byType(Pinput), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'code');
          await _typeCode(tester, '123456');
          expect(find.text('Prénom'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: 'assistant, e-mail confirmé');
          await _finish(tester, c);
        });
      }
    }

    for (final l in _langs) {
      testWidgets('petit écran 320 × 568, langue $l : aucune exception, aucune clé brute',
          (tester) async {
        final c = _put('pet_owner');
        lotdPhone(tester, width: 320, height: 568);
        await tester.pumpWidget(
            lotdApp(const SignupWizardScreen(userType: 'pet_owner'), locale: Locale(l)));
        await lotdSettle(tester);
        expect(find.text(emailFirst1711I18n[l]!['ef_email_title']!), findsWidgets);
        expect(find.textContaining('ef_'), findsNothing, reason: 'clé brute');
        expect(tester.takeException(), isNull, reason: 'e-mail');
        // Les blocs « suggestion » et « compte existant » aussi.
        c.emailFirst.suggestion.value = 'lea.martin@gmail.com';
        c.emailFirst.exists.value = true;
        c.emailFirst.error.value = 'ef_err_too_many'.tr;
        await lotdSettle(tester);
        expect(find.textContaining('ef_'), findsNothing, reason: 'clé brute');
        expect(tester.takeException(), isNull, reason: 'suggestion + compte existant');
        c.emailFirst.onEmailEdited();
        await _typeEmail(tester, _email);
        expect(find.text(emailFirst1711I18n[l]!['ef_code_title']!), findsWidgets);
        c.emailFirst.error.value = 'ef_err_blocked'.tr;
        await lotdSettle(tester);
        expect(find.textContaining('ef_'), findsNothing, reason: 'clé brute');
        expect(tester.takeException(), isNull, reason: 'code');
        await _finish(tester, c);
      });
    }
  });
}
