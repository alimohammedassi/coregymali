import 'package:flutter_test/flutter_test.dart';

import 'package:core/services/nutrition_service.dart';

/// Unit tests for the food-search relevance ranking (TASK 4 fix).
/// Fixtures mirror real rows from the Supabase `foods` table.
void main() {
  final foods = [
    {'name': 'Whole Egg (fried)', 'name_ar': 'بيضة مقلية'},
    {'name': 'White Rice (cooked)', 'name_ar': 'أرز أبيض مطبوخ'},
    {'name': 'White Rice', 'name_ar': 'أرز أبيض'},
    {'name': 'Tuna Steak (grilled)', 'name_ar': 'ستيك تونة مشوي'},
    {'name': 'Tuna Rice Bowl', 'name_ar': 'بول تونة وأرز'},
    {'name': 'Chicken Rice Bowl', 'name_ar': 'بول دجاج وأرز'},
    {'name': 'Rice with Vermicelli', 'name_ar': 'أرز بالشعيرية'},
    {'name': 'Brown Rice', 'name_ar': 'أرز بني'},
    {'name': 'Fried Rice (portion)', 'name_ar': 'أرز مقلي'},
  ];

  group('rankFoods — English', () {
    test('"rice": prefix matches first, positional after, non-matches last', () {
      final ranked = NutritionService.rankFoods(foods, 'rice');
      final names = ranked.map((f) => f['name'] as String).toList();

      // The only name that STARTS with "rice" leads tier 1.
      expect(names.first, 'Rice with Vermicelli');
      // Everything else that matches groups right behind, never an egg.
      expect(names.take(7), everyElement(contains('Rice')));
      // Non-matching stragglers (the stale-"ri" regression case) sink last,
      // alphabetical between themselves.
      expect(names[7], 'Tuna Steak (grilled)');
      expect(names[8], 'Whole Egg (fried)');
    });

    test('"WHEY PROTEIN" is case-insensitive and exact-first', () {
      final ranked = NutritionService.rankFoods([
        {'name': 'Whey Protein Isolate'},
        {'name': 'Whey Protein'},
        {'name': 'Oats'},
      ], 'WHEY PROTEIN');
      expect((ranked.first)['name'], 'Whey Protein');
    });
  });

  group('rankFoods — Arabic (stem typing)', () {
    test('"رز" ranks أرز dishes (stem match at word start) above bowls', () {
      final ranked = NutritionService.rankFoods(foods, 'رز');
      final namesAr = ranked.map((f) => f['name_ar'] as String).toList();

      // "أرز" contains رز at position 1 — must beat وأرز (position 8).
      expect(namesAr.first, startsWith('أرز'));
      expect(namesAr.indexOf('بول تونة وأرز'), greaterThan(2));
      expect(namesAr.indexOf('بول دجاج وأرز'), greaterThan(2));
      // Non-Arabic-relevant rows sink.
      expect(namesAr.last, 'بيضة مقلية');
    });
  });

  test('empty query returns the list unchanged', () {
    final ranked = NutritionService.rankFoods(foods, '  ');
    expect(ranked.map((f) => f['name']), foods.map((f) => f['name']));
  });
}
