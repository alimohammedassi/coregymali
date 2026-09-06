/// Daily targets / limits for the additional micro-nutrients shown in the
/// Nutrition page "Additional Nutrients" card. Purely a tuning surface —
/// change the numbers here and the UI picks them up.
///
/// Sugars, cholesterol and caffeine are CAPS (lower is better); the rest are
/// goals to reach.
class NutrientTargets {
  NutrientTargets._();

  static const double fiberG = 30.0;
  static const double sugarsG = 50.0; // cap
  static const double sodiumMg = 2300.0; // cap
  static const double potassiumMg = 3500.0;
  static const double calciumMg = 1000.0;
  static const double ironMg = 18.0;
  static const double cholesterolMg = 300.0; // cap
  static const double caffeineMg = 400.0; // cap
}
