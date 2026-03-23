import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class MeasurementsService {
  Future<void> saveMeasurement({
    required double weightKg,
    double? bodyFatPct,
    double? muscleMass,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? armsCm,
    double? thighsCm,
    String? notes,
    DateTime? date,
  }) async {
    if (currentUserId == null) return;
    try {
      final d = (date ?? DateTime.now()).toIso8601String().substring(0, 10);
      await supabase.from('body_measurements').upsert({
        'user_id': currentUserId,
        'measured_date': d,
        'weight_kg': weightKg,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
        if (muscleMass != null) 'muscle_mass': muscleMass,
        if (chestCm != null) 'chest_cm': chestCm,
        if (waistCm != null) 'waist_cm': waistCm,
        if (hipsCm != null) 'hips_cm': hipsCm,
        if (armsCm != null) 'arms_cm': armsCm,
        if (thighsCm != null) 'thighs_cm': thighsCm,
        if (notes != null) 'notes': notes,
      }, onConflict: 'user_id,measured_date');

      // Also update daily summary weight
      await supabase.from('daily_summary').upsert({
        'user_id': currentUserId,
        'summary_date': d,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,summary_date');
    } on PostgrestException catch (e) {
      print('Supabase error saving measurement: ${e.message} | code: ${e.code}');
    } catch (e) {
      print('Error saving measurement: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getWeightHistory() async {
    if (currentUserId == null) return [];
    try {
      return await supabase
          .from('body_measurements') // using body_measurements as weight_progress table doesn't exist in the list
          .select()
          .eq('user_id', currentUserId!)
          .order('measured_date');
    } on PostgrestException catch (e) {
      print('Supabase error getting weight history: ${e.message} | code: ${e.code}');
      return [];
    } catch (e) {
      print('Error getting weight history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLatest() async {
    if (currentUserId == null) return null;
    try {
      return await supabase
          .from('body_measurements')
          .select()
          .eq('user_id', currentUserId!)
          .order('measured_date', ascending: false)
          .limit(1)
          .single();
    } on PostgrestException catch (e) {
      print('Supabase error getting latest measurement: ${e.message} | code: ${e.code}');
      return null;
    } catch (e) {
      print('Error getting latest measurement: $e');
      return null;
    }
  }
}
