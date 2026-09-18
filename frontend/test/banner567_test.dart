import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

void main() {
  testWidgets('bannière v567 : s\'affiche puis se ferme seule', (tester) async {
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, __) => const GetMaterialApp(home: Scaffold(body: SizedBox())),
    ));
    await tester.pump();
    CustomSnackbar.showSuccess(title: 'Titre zz567', message: 'Message zz567');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Titre zz567'), findsOneWidget);
    expect(find.text('Message zz567'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Titre zz567'), findsNothing);
  });
}
