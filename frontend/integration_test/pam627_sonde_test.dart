// 627 (PAM, 28/10/2026) — sonde simulateur : lien « Choisir <prénom> » de
// l'e-mail / du SMS (`/application/<id>?from=email&choose=1`) ouvert par l'app
// → encart « Réserver <prénom> ? » + « Choisir <prénom> et payer · prix » ;
// un geste → choix envoyé au VRAI serveur → écran de paiement (aucune carte
// saisie). Puis la légende « Comprendre la PawMap » (groupes en rond).
// Compte de test propriétaire, demande en zone fictive (pam627_data.py).
// Lancement : ~/hopetsit-social/preuves/pam_627/run_ios627.sh
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:hopetsit/views/map/pawmap_help_screen.dart';
import 'package:integration_test/integration_test.dart';

import 'sonde_586_common.dart';

const String kAppId = String.fromEnvironment('HPS_APP_ID');
const String kTag = String.fromEnvironment('HPS_TAG', defaultValue: 'iphone');
const bool kTapPay = bool.fromEnvironment('HPS_TAP_PAY');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('627 — choose=1 : Choisir et payer', (t) async {
    await sondeSetUp();
    MetaEventsService.skipTrackingPromptForTests = true; // pas de fenêtre ATT par-dessus les captures
    await loginAndEnter(t);
    final size = t.view.physicalSize / t.view.devicePixelRatio;
    say('[PARCOURS] écran logique ${size.width.toStringAsFixed(0)} × ${size.height.toStringAsFixed(0)} pt ($kTag)');
    ok('id de candidature fourni', RegExp(r'^[a-f0-9]{24}$').hasMatch(kAppId));

    // Le lien tel que l'e-mail « candidats reçus » l'envoie (SAM 4dd86df2).
    unawaited(DeepLinkService.instance
        .openRoute('/application/$kAppId?from=email&choose=1'));
    await waitFor(t, () => find.byKey(const Key('cand627_fast')).evaluate().isNotEmpty,
        seconds: 40);
    final fast = find.byKey(const Key('cand627_fast'));
    ok('[PARCOURS] encart « Réserver … ? » affiché', fast.evaluate().isNotEmpty);
    final title = find.byKey(const Key('cand627_fast_title'));
    if (title.evaluate().isNotEmpty) {
      final w = t.widget(find.descendant(of: title, matching: find.byType(Text)).first) as Text;
      say('[PARCOURS] titre : ${w.data ?? w.textSpan?.toPlainText()}');
    }
    final cta = find.byKey(const Key('cand627_fast_cta'));
    if (cta.evaluate().isNotEmpty) {
      final texts = find.descendant(of: cta, matching: find.byType(Text)).evaluate()
          .map((e) => (e.widget as Text).data ?? '').where((s) => s.isNotEmpty).join(' ');
      say('[PARCOURS] bouton : $texts');
      final r = t.getRect(cta);
      final h = MediaQuery.of(t.element(cta)).size.height;
      ok('[PARCOURS] bouton visible sans défiler', r.bottom <= h,
          detail: 'bas ${r.bottom.toStringAsFixed(0)} / ${h.toStringAsFixed(0)}');
    }
    await shot(t, 'pam627_${kTag}_01_encart');

    if (kTapPay && cta.evaluate().isNotEmpty) {
      await t.tap(cta);
      await hold(t, 1500);
      // Le choix part au serveur, la feuille se ferme, le paiement s'ouvre.
      await waitFor(t, () => find.byKey(const Key('cand2610_sheet')).evaluate().isEmpty,
          seconds: 30);
      ok('[PARCOURS] feuille fermée après le choix',
          find.byKey(const Key('cand2610_sheet')).evaluate().isEmpty);
      await hold(t, 6000);
      say('[PARCOURS] route après le choix : ${Get.currentRoute}');
      await shot(t, 'pam627_${kTag}_02_paiement');
      // Retour (aucune carte saisie, rien payé).
      if (Navigator.of(t.element(find.byType(Scaffold).last)).canPop()) {
        Navigator.of(t.element(find.byType(Scaffold).last)).pop();
        await hold(t, 2000);
      }
    }

    // Légende « Comprendre la PawMap » : mémo des formes (groupes en rond).
    Get.to(() => const PawMapHelpScreen());
    await hold(t, 3000);
    final memo = find.text('pawmap_legend_memo'.tr);
    for (var i = 0; i < 25 && memo.evaluate().isEmpty; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await hold(t, 400);
    }
    if (memo.evaluate().isNotEmpty) {
      await t.ensureVisible(memo.first);
      await hold(t, 800);
      final w = t.widget(memo.first) as Text;
      say('[PARCOURS] mémo légende : ${w.data}');
    }
    ok('[PARCOURS] mémo « rond avec un nombre = un groupe » visible', memo.evaluate().isNotEmpty);
    ok('[PARCOURS] plus de « Carré »', find.textContaining('Carré').evaluate().isEmpty);
    await shot(t, 'pam627_${kTag}_03_legende');
    await sondeTearDown(t);
  });
}
