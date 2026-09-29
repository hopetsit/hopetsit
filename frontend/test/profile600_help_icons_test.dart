// v600 (PAM, 29/09) — Profil → Aide : les icônes « Conditions » et
// « Confidentialité » ne sont plus grises (taupe #B69C96 à 12 % sur blanc).
// On rend les 4 rangées de la section Aide comme dans `profile_categories.dart`
// (PawMap = violet, Idées = ambre, Conditions = encre chaude, Confidentialité =
// accent du rôle) pour les 3 rôles, en clair et en nuit, sans exception, et on
// vérifie que chaque teinte de pastille a une saturation ≥ 0,25.
// Si `HPS_PROOF_DIR` est défini, une image PNG par rôle × thème est écrite
// (preuve visuelle sans compte connecté).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_categories.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

const Map<String, String> kRoles = <String, String>{
  'owner': 'Propriétaire',
  'sitter': 'Gardien',
  'walker': 'Promeneur',
};

Widget _help(Color accent) => ProfileGroupCard(children: [
      const ProfileRow(
        icon: PawIcon.map,
        title: 'Comprendre la PawMap',
        subtitle: 'Épingles, rail, découverte guidée',
        color: Color(0xFF6A5AE0),
      ),
      const ProfileRow(
        icon: PawIcon.bulb,
        title: 'Boîte à idées',
        subtitle: 'Une idée pour HoPetSit ?',
        color: Color(0xFFF59E0B),
      ),
      const ProfileRow(
        icon: PawIcon.doc,
        title: 'Conditions d’utilisation',
        subtitle: 'Lire les conditions',
        color: ProfileCategories.helpInk,
      ),
      ProfileRow(
        icon: PawIcon.shield,
        title: 'Confidentialité',
        subtitle: 'Comment tes données sont protégées',
        color: accent,
      ),
    ]);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final String? proofDir = Platform.environment['HPS_PROOF_DIR'];

  for (final MapEntry<String, String> r in kRoles.entries) {
    for (final Brightness b in <Brightness>[Brightness.light, Brightness.dark]) {
      final String theme = b == Brightness.light ? 'clair' : 'nuit';
      testWidgets('Aide — ${r.value} — $theme', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(375, 420);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final Color accent = AppColors.roleAccent(r.key);
        final GlobalKey key = GlobalKey();
        await tester.pumpWidget(ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, __) => GetMaterialApp(
            theme: ThemeData(brightness: b),
            home: RepaintBoundary(
              key: key,
              child: Scaffold(
                backgroundColor: b == Brightness.light
                    ? AppColors.scaffoldOwnerLight
                    : AppColors.backgroundDark,
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    ProfileSectionTitle('Aide (${r.value})',
                        icon: Icons.help_rounded),
                    _help(accent),
                  ]),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ProfileRow), findsNWidgets(4));
        expect(HSLColor.fromColor(ProfileCategories.helpInk).saturation,
            greaterThanOrEqualTo(0.25));
        expect(HSLColor.fromColor(accent).saturation,
            greaterThanOrEqualTo(0.25));
        if (proofDir != null && proofDir.isNotEmpty) {
          final RenderRepaintBoundary rb = key.currentContext!
              .findRenderObject()! as RenderRepaintBoundary;
          final ui.Image img = await rb.toImage(pixelRatio: 2.0);
          final ByteData? bytes =
              await img.toByteData(format: ui.ImageByteFormat.png);
          File('$proofDir/aide_${r.key}_$theme.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        }
      });
    }
  }
}
