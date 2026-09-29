// v599 (29/09/2026) — demande de suivi en direct : LA PERSONNE, PAS LE RÔLE.
// Daniel : son frère (propriétaire) lui envoie une demande depuis le chat ;
// impossible de l'accepter. Entre deux propriétaires amis, la carte
// comparait les rôles et croyait des deux côtés être l'expéditeur.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';

Widget _harness(Widget child) => ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

PawfollowRequestCard _card({bool? isMine}) => PawfollowRequestCard(
      messageId: 'm1',
      requesterRole: 'owner',
      responderRole: 'owner',
      status: 'pending',
      myRole: 'owner',
      isMine: isMine,
      onAccept: () {},
      onRefuse: () {},
    );

void main() {
  testWidgets('deux propriétaires : le DESTINATAIRE voit Accepter / Refuser',
      (tester) async {
    await tester.pumpWidget(_harness(_card(isMine: false)));
    await tester.pumpAndSettle();
    expect(find.text('pawfollow_accept'.tr), findsOneWidget);
    expect(find.text('cs_pf_refuse'.tr), findsOneWidget);
    expect(find.text('pawfollow_request_owner_wants_to_follow'.tr), findsOneWidget);
  });

  testWidgets('deux propriétaires : l\'EXPÉDITEUR voit « envoyée », sans boutons',
      (tester) async {
    await tester.pumpWidget(_harness(_card(isMine: true)));
    await tester.pumpAndSettle();
    expect(find.text('pawfollow_accept'.tr), findsNothing);
    expect(find.text('pawfollow_request_sent_header'.tr), findsOneWidget);
  });

  testWidgets('sans isMine (ancien calcul par rôle) : comportement d\'avant',
      (tester) async {
    await tester.pumpWidget(_harness(_card()));
    await tester.pumpAndSettle();
    // owner == owner → les deux côtés se croyaient expéditeur ET destinataire :
    // en-tête « envoyée » chez le destinataire aussi (le bug de Daniel). Gardé
    // en repli seulement quand l'expéditeur du message est inconnu.
    expect(find.text('pawfollow_request_sent_header'.tr), findsOneWidget);
  });

  test('clés 599 (balade, fond de carte) dans les 9 langues, accents présents', () {
    final all = AppTranslations().keys;
    expect(all.length, 9);
    const keys = [
      'pawmap599_map_preparing', 'help599_sec_balade', 'help599_ex_balade',
      'help599_t_me', 'help599_b_me', 'help599_t_others', 'help599_b_others',
      'help599_t_dot', 'help599_b_dot', 'help599_img_caption',
    ];
    for (final loc in all.keys) {
      for (final k in keys) {
        expect(all[loc]!.containsKey(k), isTrue, reason: '$k ($loc)');
        expect(all[loc]![k]!.trim(), isNotEmpty, reason: '$k ($loc) vide');
      }
    }
    expect(all['fr_FR']!['pawmap599_map_preparing'], 'Carte en préparation…');
    expect(all['fr_FR']!['help599_b_me'], contains('Démarrer'));
    expect(all['fr_FR']!['help599_b_others'], contains('réservation'));
    expect(all['pl_PL']!['help599_b_dot'], contains('ł'));
  });
}
