// v598 — ZOE : preuve chiffrée du `cacheWidth` posé sur les images 1024 px
// affichées en petit (logo invité, mur d'inscription, RoleChip, connexion,
// onboarding, logo Premium). Sans cacheWidth, une source 1024×1024 est
// décodée entière : 4 Mo par image dans le cache et sur le GPU.
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> _bytesFor(WidgetTester tester, Widget image) async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  await tester.pumpWidget(MaterialApp(home: Center(child: image)));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  return PaintingBinding.instance.imageCache.currentSizeBytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logo-mark.png : décodage à 160 px au lieu de 1024 px', (tester) async {
    final full = await _bytesFor(tester,
        Image.asset('assets/brand/png/logo-mark.png', width: 38, height: 38));
    final small = await _bytesFor(tester,
        Image.asset('assets/brand/png/logo-mark.png', width: 38, height: 38, cacheWidth: 160));
    // 1024 × 1024 × 4 octets ≈ 4,2 Mo ; 160 × 160 × 4 ≈ 0,1 Mo.
    expect(full, greaterThanOrEqualTo(4 * 1024 * 1024));
    expect(small, lessThan(200 * 1024));
    expect(small, greaterThan(0));
  });

  testWidgets('ic_launcher.png (RoleChip) : décodage à 96 px', (tester) async {
    final small = await _bytesFor(tester,
        Image.asset('assets/brand/png/ic_launcher.png', width: 22, height: 22, cacheWidth: 96));
    expect(small, lessThan(100 * 1024));
    expect(small, greaterThan(0));
  });
}
