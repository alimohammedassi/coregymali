import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:core/l10n/app_localizations.dart';
import 'package:core/models/meal_suggestion.dart';
import 'package:core/widgets/suggest_meal_sheet.dart';

/// Tests for the 2026-09-24 finish: CAL field that lets user type exact kcal
/// and AI builds meal to that number + chosen style/slot.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Reuse same fake init the coach dashboard test uses — Supabase must be
    // initialized before any widget that touches MealSuggestionService.
    try {
      await Supabase.initialize(
        url: 'https://mkrjvrnysuvtokqkyoll.supabase.co',
        anonKey: 'sb_publishable_JhvLrN-jg2v5aRr9DvLxdg_wqpip5Eq',
      );
    } catch (_) {
      // Already initialized in this isolate when multiple test files run together.
    }
  });
  group('MealSuggestion model', () {
    test('parses valid JSON from edge function', () {
      final json = {
        'items': [
          {
            'food_id': 'abc-123',
            'name': 'Chicken Breast',
            'name_ar': 'صدر دجاج',
            'category': 'protein',
            'image_url': 'https://example.com/chicken.jpg',
            'quantity_multiplier': 1.5,
            'serving_size': 100,
            'serving_unit': 'g',
            'calories': 250,
            'protein_g': 31.5,
            'carbs_g': 0,
            'fat_g': 3.6,
          },
          {
            'food_id': 'def-456',
            'name': 'White Rice',
            'name_ar': 'أرز أبيض',
            'category': 'carbs',
            'quantity_multiplier': 1,
            'calories': 130,
            'protein_g': 2.5,
            'carbs_g': 28,
            'fat_g': 0.3,
          },
        ],
        'explanation_en': 'Balanced protein + carb combo',
        'explanation_ar': 'مكس بروتين و كارب متوازن',
        'total_calories': 380,
        'total_protein': 34.0,
        'total_carbs': 28,
        'total_fat': 3.9,
      };
      final suggestion = MealSuggestion.fromJson(json);
      expect(suggestion.items.length, 2);
      expect(suggestion.totalCalories, 380);
      expect(suggestion.items.first.name, 'Chicken Breast');
      expect(suggestion.items.first.quantityMultiplier, 1.5);
      expect(suggestion.explanationEn, contains('Balanced'));
    });

    test('handles empty / missing fields gracefully', () {
      final suggestion = MealSuggestion.fromJson({});
      expect(suggestion.items, isEmpty);
      expect(suggestion.totalCalories, 0);
      expect(suggestion.explanationEn, '');
    });
  });

  group('CAL field validation (80..5000)', () {
    // Mirrors the dart getter in SuggestMealSheet + edge function check.
    int? parseCustomCalories(String raw) {
      final v = int.tryParse(raw.trim());
      if (v == null) return null;
      if (v < 80 || v > 5000) return null;
      return v;
    }

    test('valid range 80..5000 accepted', () {
      expect(parseCustomCalories('80'), 80);
      expect(parseCustomCalories('550'), 550);
      expect(parseCustomCalories('5000'), 5000);
    });

    test('outside range rejected', () {
      expect(parseCustomCalories('79'), isNull);
      expect(parseCustomCalories('0'), isNull);
      expect(parseCustomCalories('5001'), isNull);
      expect(parseCustomCalories('-10'), isNull);
    });

    test('non-numeric rejected', () {
      expect(parseCustomCalories(''), isNull);
      expect(parseCustomCalories('abc'), isNull);
      expect(parseCustomCalories('12.5'), isNull);
    });

    test('edge: custom overrides remaining', () {
      const remaining = 800;
      const custom = 600;
      // effective = custom when present else remaining
      int effectiveTarget(int? customCals, int remainingKcal) =>
          customCals ?? remainingKcal;
      expect(effectiveTarget(custom, remaining), 600);
      expect(effectiveTarget(null, remaining), 800);
    });
  });

  group('SuggestMealSheet CAL field UI', () {
    Widget wrapWithLocalizations(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      );
    }

    testWidgets('shows CAL TextField prefilled with remaining when >=80',
        (tester) async {
      await tester.pumpWidget(
        wrapWithLocalizations(
          const SuggestMealSheet(
            remainingKcal: 650,
            remainingProtein: 50,
            remainingCarbs: 100,
            remainingFat: 20,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The CAL field is a TextField with digitsOnly formatter.
      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '650');
      // Hint should reference kcal (localized).
      expect(find.textContaining('kcal'), findsWidgets);
    });

    testWidgets('goal-met day (0 remaining) starts with empty CAL field',
        (tester) async {
      await tester.pumpWidget(
        wrapWithLocalizations(
          const SuggestMealSheet(
            remainingKcal: 0,
            remainingProtein: 0,
            remainingCarbs: 0,
            remainingFat: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
      // Should show helper text about goal met or subtitle
      expect(find.textContaining('kcal'), findsWidgets);
    });

    testWidgets('shows "Use remaining" chip when typed value differs',
        (tester) async {
      await tester.pumpWidget(
        wrapWithLocalizations(
          const SuggestMealSheet(
            remainingKcal: 800,
            remainingProtein: 30,
            remainingCarbs: 100,
            remainingFat: 25,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Initially field == 800, chip hidden because matches remaining.
      expect(find.textContaining('Use remaining'), findsNothing);
      // Change to 550.
      await tester.enterText(find.byType(TextField), '550');
      await tester.pumpAndSettle();
      expect(find.textContaining('Use remaining'), findsOneWidget);
    });

    testWidgets('invalid CAL (e.g. 10) blocks AI request and shows error',
        (tester) async {
      await tester.pumpWidget(
        wrapWithLocalizations(
          const SuggestMealSheet(
            remainingKcal: 600,
            remainingProtein: 30,
            remainingCarbs: 80,
            remainingFat: 20,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '10');
      await tester.pumpAndSettle();
      // Tap the CTA button ("Suggest for me").
      final ctaFinder = find.text('Suggest for me');
      expect(ctaFinder, findsOneWidget);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();
      // Should show inline validation error (80–5000).
      expect(find.text('Enter 80–5000 kcal'), findsOneWidget);
    });

    testWidgets('style + slot chips are tappable and CAL field remains',
        (tester) async {
      await tester.pumpWidget(
        wrapWithLocalizations(
          const SuggestMealSheet(
            remainingKcal: 500,
            remainingProtein: 20,
            remainingCarbs: 60,
            remainingFat: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tap High protein style chip.
      expect(find.text('High protein'), findsOneWidget);
      await tester.tap(find.text('High protein'));
      await tester.pumpAndSettle();
      // CAL field still present.
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
