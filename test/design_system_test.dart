import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/app_spacing.dart';
import 'package:concorde_efb/core/ui_text.dart';
import 'package:concorde_efb/design_system/design_lab.dart';

void main() {
  group('Design System Tokens Test', () {
    test('AppSpacing maintains mathematical 4px/8px progression', () {
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 20.0);
      expect(AppSpacing.xxl, 24.0);
      expect(AppSpacing.xxxl, 32.0);
    });

    test('AppRadii tokens are properly defined', () {
      expect(AppRadii.xs.topLeft.x, 4.0);
      expect(AppRadii.sm.topLeft.x, 6.0);
      expect(AppRadii.md.topLeft.x, 8.0);
      expect(AppRadii.lg.topLeft.x, 10.0);
      expect(AppRadii.xl.topLeft.x, 12.0);
    });

    testWidgets('AppTypography styles return correct weights and sizes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final disp = AppTypography.display(context, color: Colors.white);
              final hdr = AppTypography.sectionHeader(context, color: Colors.white);
              final body = AppTypography.body(context, color: Colors.white);
              final readout = AppTypography.readout(context, color: Colors.white);
              final cap = AppTypography.caption(context, color: Colors.white);

              expect(disp.fontSize, 20.0);
              expect(disp.fontWeight, FontWeight.w700);

              expect(hdr.fontSize, 14.0);
              expect(hdr.fontWeight, FontWeight.w600);

              expect(body.fontSize, 12.0);
              expect(body.fontWeight, FontWeight.w400);

              expect(readout.fontSize, 13.0);
              expect(readout.fontWeight, FontWeight.w700);

              expect(cap.fontSize, 10.0);
              expect(cap.fontWeight, FontWeight.w600);

              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('DesignLabScreen renders without throwing', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: DesignLabScreen()));
      await tester.pumpAndSettle();

      expect(find.text('CONCORDE EFB — DESIGN LAB'), findsOneWidget);
      expect(find.text('1. SEMANTIC COLOR TOKENS (AppColors)'), findsOneWidget);
      expect(find.text('2. TYPOGRAPHIC SCALE (AppTypography)'), findsOneWidget);
      expect(find.text('3. ATOMIC COMPONENTS & CARDS'), findsOneWidget);
    });
  });
}
