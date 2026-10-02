// 607 (ZOE, 02/10/2026) — cas client réel (FLO) : 3 € payés, jamais vérifié. Sur
// iPhone, la caméra répondait toujours « refusé » et l'écran s'ARRÊTAIT. Désormais :
// pop-up « Ouvrir les réglages / Continuer quand même », et « Continuer » ouvre la
// session (POST /kyc/start). Bouton « Lancer » visible dès que c'est payé.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/v565/kyc607_i18n.dart';
import 'package:hopetsit/views/kyc/kyc_verification_screen.dart';

import 'lotd_harness.dart';

const _langs = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const _perm = MethodChannel('flutter.baseflow.com/permissions/methods');

void main() {
  setUp(() async {
    await lotdSetUp(role: 'sitter');
    // permission_handler : caméra (1) et micro (7) REFUSÉES (0), comme l'iPhone sans macros.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_perm, (call) async {
      if (call.method == 'requestPermissions') {
        return <int, int>{for (final p in (call.arguments as List).cast<int>()) p: 0};
      }
      if (call.method == 'checkPermissionStatus') return 0;
      if (call.method == 'openAppSettings') return true;
      return null;
    });
    lotdResponder = (req) {
      if (req.url.path.endsWith('/kyc/status')) {
        return <String, dynamic>{'kycStatus': 'pending_verification', 'kycPaidAt': '2026-09-18T10:00:00Z', 'price': 3};
      }
      if (req.url.path.endsWith('/kyc/start')) return <String, dynamic>{'oneTimeLink': ''};
      return const <String, dynamic>{};
    };
  });

  test('9 langues, aucune clé vide', () {
    for (final l in _langs) {
      for (final k in kyc607I18n['fr']!.keys) {
        expect(kyc607I18n[l]![k]!.trim(), isNotEmpty, reason: '$l $k');
      }
    }
  });

  test('payé = bouton « Lancer » (jamais un second paiement)', () {
    expect(kyc607CanLaunch({'kycStatus': 'pending_verification'}), isTrue);
    expect(kyc607CanLaunch({'kycStatus': 'pending_payment', 'kycPaidAt': '2026-09-18'}), isTrue);
    expect(kyc607CanLaunch({'kycStatus': 'none'}), isFalse);
    expect(kyc607CanLaunch({'kycStatus': 'verified', 'kycPaidAt': '2026-09-18'}), isFalse);
  });

  testWidgets('caméra refusée : pop-up, « Continuer quand même » ouvre la session', (t) async {
    t.view.physicalSize = const Size(375 * 2, 812 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    await t.pumpWidget(lotdApp(const KycVerificationScreen()));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final launch = find.text('kyc_launch_persona_btn'.tr);
    await t.ensureVisible(launch);
    await t.tap(launch);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(kyc607I18n['fr']!['kyc607_cam_title']!), findsOneWidget);
    expect(lotdRequests.where((r) => r.path.endsWith('/kyc/start')), isEmpty);
    await t.tap(find.text(kyc607I18n['fr']!['kyc607_continue']!));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(lotdRequests.where((r) => r.path.endsWith('/kyc/start')), hasLength(1));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
  });

  for (final l in _langs) {
    testWidgets('pop-up 320 px $l : sans débordement', (t) async {
      t.view.physicalSize = const Size(320 * 2, 640 * 2);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      await t.pumpWidget(lotdApp(
        Builder(builder: (c) => Scaffold(
              body: Center(child: ElevatedButton(onPressed: () => showKyc607CameraDialog(c), child: const Text('x'))),
            )),
        locale: Locale(l),
      ));
      await t.tap(find.text('x'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(kyc607I18n[l]!['kyc607_open_settings']!), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
