import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/widgets/top_glow.dart';

/// Pumps [glow] as the first Stack child over a tappable button, mirroring
/// the Home integration (Stack: TopGlow → content).
Future<void> _pumpGlow(
  WidgetTester tester,
  TopGlow glow,
  VoidCallback onTap,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            glow,
            Center(
              child: TextButton(onPressed: onTap, child: const Text('tap')),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TopGlow builds behind content and never intercepts taps', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await _pumpGlow(tester, const TopGlow(), () => tapped = true);

    expect(find.byType(TopGlow), findsOneWidget);
    // Root is IgnorePointer so content underneath stays interactive.
    final root = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(TopGlow),
        matching: find.byType(IgnorePointer),
      ).first,
    );
    expect(root.ignoring, isTrue);

    await tester.tap(find.text('tap'));
    expect(tapped, isTrue);
  });

  testWidgets('TopGlow is static by default: opacity never moves', (
    WidgetTester tester,
  ) async {
    await _pumpGlow(tester, const TopGlow(), () {});
    double opacity() =>
        tester.widget<Opacity>(find.byType(Opacity).first).opacity;

    expect(opacity(), moreOrLessEquals(1.0));
    await tester.pump(const Duration(seconds: 6));
    expect(opacity(), moreOrLessEquals(1.0));
  });

  testWidgets('TopGlow breathes when animate:true (6s loop)', (
    WidgetTester tester,
  ) async {
    await _pumpGlow(tester, const TopGlow(animate: true), () {});

    double opacity() =>
        tester.widget<Opacity>(find.byType(Opacity).first).opacity;

    await tester.pump(const Duration(seconds: 6)); // forward leg done
    final endOfForward = opacity();
    await tester.pump(const Duration(seconds: 6)); // reverse leg done
    final end = opacity();

    expect(endOfForward, inInclusiveRange(0.71, 0.73)); // 1.0 → 0.72
    expect(end, inInclusiveRange(0.99, 1.01)); // …and back to ~1.0
  });

  testWidgets('TopGlow honors color/spread/intensity overrides', (
    WidgetTester tester,
  ) async {
    await _pumpGlow(
      tester,
      const TopGlow(color: Colors.red, spread: 1.5, intensity: 0.5),
      () {},
    );
    expect(find.byType(TopGlow), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TopGlow keeps approved stops in light mode, dims them in dark mode',
    (WidgetTester tester) async {
      Future<double> outerAlpha(Brightness brightness) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const Scaffold(body: Stack(children: [TopGlow()])),
          ),
        );
        // MaterialApp animates theme changes (AnimatedTheme): settle past
        // the lerp so Theme.of reports the new brightness.
        await tester.pumpAndSettle();
        final outer = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(TopGlow),
                matching: find.byType(Container),
              )
              .first,
        );
        final gradient =
            (outer.decoration! as BoxDecoration).gradient! as RadialGradient;
        return gradient.colors.first.a;
      }

      // 8-bit color quantization: allow a small epsilon.
      expect(
        await outerAlpha(Brightness.light),
        moreOrLessEquals(0.20, epsilon: 0.005),
      );
      expect(
        await outerAlpha(Brightness.dark),
        moreOrLessEquals(0.20 * 0.35, epsilon: 0.005),
      );
    },
  );
}
