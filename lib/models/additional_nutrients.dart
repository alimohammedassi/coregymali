/// Nullable micro-nutrient bundle carried through every food-logging path
/// (manual catalog pick, AI photo scan, text log, voice log, barcode).
///
/// `null` means the source didn't provide the value (unknown) — it is never
/// treated as 0 until the `daily_summary` aggregation step, which sums
/// known values into NOT NULL DEFAULT 0 columns.
class AdditionalNutrients {
  final double? fiberG;
  final double? sugarsG;
  final double? sodiumMg;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? cholesterolMg;
  final double? caffeineMg;

  const AdditionalNutrients({
    this.fiberG,
    this.sugarsG,
    this.sodiumMg,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.cholesterolMg,
    this.caffeineMg,
  });

  static double? _opt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory AdditionalNutrients.fromJson(Map<String, dynamic> json) {
    return AdditionalNutrients(
      fiberG: _opt(json['fiber_g']),
      sugarsG: _opt(json['sugars_g']),
      sodiumMg: _opt(json['sodium_mg']),
      potassiumMg: _opt(json['potassium_mg']),
      calciumMg: _opt(json['calcium_mg']),
      ironMg: _opt(json['iron_mg']),
      cholesterolMg: _opt(json['cholesterol_mg']),
      caffeineMg: _opt(json['caffeine_mg']),
    );
  }

  /// True when at least one value is known — callers use it to decide
  /// between writing the extra columns or leaving them SQL NULL.
  bool get hasAny =>
      fiberG != null ||
      sugarsG != null ||
      sodiumMg != null ||
      potassiumMg != null ||
      calciumMg != null ||
      ironMg != null ||
      cholesterolMg != null ||
      caffeineMg != null;

  /// Column map for Supabase inserts/updates. Unknown values are omitted so
  /// the row keeps SQL NULL (unknown) instead of being forced to 0.
  Map<String, dynamic> toInsertColumns() => {
        if (fiberG != null) 'fiber_g': fiberG,
        if (sugarsG != null) 'sugars_g': sugarsG,
        if (sodiumMg != null) 'sodium_mg': sodiumMg,
        if (potassiumMg != null) 'potassium_mg': potassiumMg,
        if (calciumMg != null) 'calcium_mg': calciumMg,
        if (ironMg != null) 'iron_mg': ironMg,
        if (cholesterolMg != null) 'cholesterol_mg': cholesterolMg,
        if (caffeineMg != null) 'caffeine_mg': caffeineMg,
      };

  /// Builds a bundle from a `foods` catalog row (per-serving values in the
  /// row), already scaled for the quantity being logged.
  factory AdditionalNutrients.fromFoodRow(Map<String, dynamic> row) {
    return AdditionalNutrients.fromJson(row);
  }

  /// Scales every known value by [factor] (e.g. quantity/100 for per-100g
  /// sources, or newWeight/oldWeight when editing a log). Unknown stay null.
  AdditionalNutrients scaledBy(double factor) => AdditionalNutrients(
        fiberG: fiberG == null ? null : fiberG! * factor,
        sugarsG: sugarsG == null ? null : sugarsG! * factor,
        sodiumMg: sodiumMg == null ? null : sodiumMg! * factor,
        potassiumMg: potassiumMg == null ? null : potassiumMg! * factor,
        calciumMg: calciumMg == null ? null : calciumMg! * factor,
        ironMg: ironMg == null ? null : ironMg! * factor,
        cholesterolMg: cholesterolMg == null ? null : cholesterolMg! * factor,
        caffeineMg: caffeineMg == null ? null : caffeineMg! * factor,
      );

  @override
  String toString() =>
      'AdditionalNutrients(fiber: $fiberG, sugars: $sugarsG, sodium: $sodiumMg, '
      'potassium: $potassiumMg, calcium: $calciumMg, iron: $ironMg, '
      'cholesterol: $cholesterolMg, caffeine: $caffeineMg)';
}
