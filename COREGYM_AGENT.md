# CoreGym — Full App Agent Prompt
# Supabase: https://mkrjvrnysuvtokqkyoll.supabase.co
# Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcmp2cm55c3V2dG9rcWt5b2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNDExMTgsImV4cCI6MjA4OTcxNzExOH0.Nf1xdRt2W1Ped0gulhdId2iAFC0KEp36-JD_4ey9dzg

---

## Your Role
You are a senior Flutter developer. Build CoreGym as a complete,
real, production-ready fitness app connected fully to Supabase.
Every screen must read/write real data. No static/dummy data.

## Rules
- Every number shown in the UI must come from Supabase
- Every user action must be saved to Supabase
- Preserve all existing UI styles and navigation flow
- Run `flutter analyze` after every file
- Use supabase_flutter ^2.5.0 (already in pubspec)

---

## Database Schema (already created in Supabase)

Tables:
- profiles          → user info (name, email, gender, age, etc.)
- onboarding        → onboarding answers per user
- user_goals        → daily targets (calories, protein, steps, etc.)
- daily_summary     → one row per user per day (auto-updated by triggers)
- nutrition_logs    → food entries per meal per day
- foods             → food database (20 foods seeded + custom)
- workout_sessions  → one session per workout
- workout_sets      → sets/reps/weight per exercise per session
- body_measurements → weight/measurements over time
- weekly_activity   → weekly chart data

Views (read-only, use for charts):
- weekly_progress   → 7-day data with goal percentages
- weight_progress   → body weight over time with change delta
- personal_records  → best weight per exercise per user

Triggers (automatic, don't worry about them):
- nutrition_log_sync  → auto-updates daily_summary nutrition
- workout_session_sync → auto-updates daily_summary workout

---

## Step 1 — Supabase Services

Create these files in lib/services/:

### lib/services/supabase_client.dart
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
String? get currentUserId => supabase.auth.currentUser?.id;
```

### lib/services/onboarding_service.dart
```dart
import 'supabase_client.dart';

class OnboardingService {
  Future<bool> isCompleted() async {
    if (currentUserId == null) return false;
    try {
      final row = await supabase
          .from('onboarding')
          .select('completed')
          .eq('user_id', currentUserId!)
          .single();
      return row['completed'] == true;
    } catch (_) { return false; }
  }

  Future<void> saveOnboarding({
    required int age,
    required String gender,
    required double heightCm,
    required double weightKg,
    required String goal,
    required String activityLevel,
    required double targetWeight,
    required int weeklyWorkouts,
  }) async {
    if (currentUserId == null) return;
    await supabase.from('onboarding').upsert({
      'user_id': currentUserId,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': goal,
      'activity_level': activityLevel,
      'target_weight': targetWeight,
      'weekly_workouts': weeklyWorkouts,
      'completed': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // Also update profiles + create user_goals
    await supabase.from('profiles').update({
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'fitness_goal': goal,
    }).eq('id', currentUserId!);

    // Calculate TDEE-based calorie goal
    double bmr = gender == 'male'
        ? 88.36 + (13.4 * weightKg) + (4.8 * heightCm) - (5.7 * age)
        : 447.6 + (9.2 * weightKg) + (3.1 * heightCm) - (4.3 * age);
    final multipliers = {
      'sedentary': 1.2, 'lightly_active': 1.375,
      'moderately_active': 1.55, 'very_active': 1.725,
      'extra_active': 1.9
    };
    int tdee = (bmr * (multipliers[activityLevel] ?? 1.55)).round();
    if (goal == 'weight_loss') tdee -= 500;
    if (goal == 'muscle_gain') tdee += 300;

    await supabase.from('user_goals').upsert({
      'user_id': currentUserId,
      'daily_calories': tdee,
      'daily_protein_g': (weightKg * 2.2).round(),
      'daily_carbs_g': ((tdee * 0.45) / 4).round(),
      'daily_fat_g': ((tdee * 0.25) / 9).round(),
      'target_weight_kg': targetWeight,
      'weekly_workouts': weeklyWorkouts,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // Save initial body measurement
    await supabase.from('body_measurements').upsert({
      'user_id': currentUserId,
      'weight_kg': weightKg,
      'measured_date': DateTime.now().toIso8601String().substring(0,10),
    }, onConflict: 'user_id,measured_date');
  }
}
```

### lib/services/nutrition_service.dart
```dart
import 'supabase_client.dart';

class NutritionService {
  // Search foods
  Future<List<Map<String,dynamic>>> searchFoods(String query) async {
    return await supabase
        .from('foods')
        .select()
        .ilike('name', '%$query%')
        .limit(20);
  }

  // Log food
  Future<void> logFood({
    required String foodId,
    required String foodName,
    required String mealType,
    required double quantity,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    DateTime? date,
  }) async {
    if (currentUserId == null) return;
    final d = (date ?? DateTime.now()).toIso8601String().substring(0,10);
    await supabase.from('nutrition_logs').insert({
      'user_id': currentUserId,
      'food_id': foodId,
      'food_name': foodName,
      'meal_type': mealType,
      'quantity': quantity,
      'calories': calories * (quantity / 100),
      'protein_g': proteinG * (quantity / 100),
      'carbs_g': carbsG * (quantity / 100),
      'fat_g': fatG * (quantity / 100),
      'logged_date': d,
    });
  }

  // Get today's logs grouped by meal
  Future<Map<String, List<Map<String,dynamic>>>> getTodayLogs() async {
    if (currentUserId == null) return {};
    final today = DateTime.now().toIso8601String().substring(0,10);
    final rows = await supabase
        .from('nutrition_logs')
        .select()
        .eq('user_id', currentUserId!)
        .eq('logged_date', today)
        .order('logged_at');
    final Map<String, List<Map<String,dynamic>>> grouped = {
      'breakfast': [], 'lunch': [], 'dinner': [], 'snack': []
    };
    for (final row in rows) {
      grouped[row['meal_type']]?.add(row);
    }
    return grouped;
  }

  // Delete food log
  Future<void> deleteLog(String logId) async {
    await supabase.from('nutrition_logs').delete().eq('id', logId);
  }

  // Add custom food
  Future<void> addCustomFood({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double servingSize = 100,
  }) async {
    await supabase.from('foods').insert({
      'name': name,
      'calories': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fat_g': fat,
      'serving_size': servingSize,
      'is_custom': true,
      'created_by': currentUserId,
    });
  }
}
```

### lib/services/workout_service.dart
```dart
import 'supabase_client.dart';

class WorkoutService {
  // Start a new session
  Future<String?> startSession({
    required String muscleGroup,
    String? sessionName,
  }) async {
    if (currentUserId == null) return null;
    final row = await supabase.from('workout_sessions').insert({
      'user_id': currentUserId,
      'muscle_group': muscleGroup,
      'session_name': sessionName ?? '$muscleGroup workout',
      'session_date': DateTime.now().toIso8601String().substring(0,10),
    }).select().single();
    return row['id'];
  }

  // Log a set
  Future<void> logSet({
    required String sessionId,
    required String exerciseName,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSec,
  }) async {
    if (currentUserId == null) return;
    await supabase.from('workout_sets').insert({
      'session_id': sessionId,
      'user_id': currentUserId,
      'exercise_name': exerciseName,
      'set_number': setNumber,
      if (reps != null) 'reps': reps,
      if (weightKg != null) 'weight_kg': weightKg,
      if (durationSec != null) 'duration_sec': durationSec,
    });
  }

  // End session
  Future<void> endSession(String sessionId, int durationMin) async {
    await supabase.from('workout_sessions').update({
      'ended_at': DateTime.now().toIso8601String(),
      'duration_min': durationMin,
    }).eq('id', sessionId);
  }

  // Get today's sessions
  Future<List<Map<String,dynamic>>> getTodaySessions() async {
    if (currentUserId == null) return [];
    final today = DateTime.now().toIso8601String().substring(0,10);
    return await supabase
        .from('workout_sessions')
        .select('*, workout_sets(*)')
        .eq('user_id', currentUserId!)
        .eq('session_date', today)
        .order('started_at');
  }

  // Get sets for a session
  Future<List<Map<String,dynamic>>> getSessionSets(String sessionId) async {
    return await supabase
        .from('workout_sets')
        .select()
        .eq('session_id', sessionId)
        .order('set_number');
  }

  // Personal records
  Future<List<Map<String,dynamic>>> getPersonalRecords() async {
    if (currentUserId == null) return [];
    return await supabase
        .from('personal_records')
        .select()
        .eq('user_id', currentUserId!);
  }
}
```

### lib/services/stats_service.dart
```dart
import 'supabase_client.dart';

class StatsService {
  // Get today's summary
  Future<Map<String,dynamic>> getTodaySummary() async {
    if (currentUserId == null) return _empty();
    final today = DateTime.now().toIso8601String().substring(0,10);
    try {
      return await supabase
          .from('daily_summary')
          .select()
          .eq('user_id', currentUserId!)
          .eq('summary_date', today)
          .single();
    } catch (_) { return _empty(); }
  }

  // Update manual stats (steps, water, sleep, mood)
  Future<void> updateTodaySummary(Map<String,dynamic> data) async {
    if (currentUserId == null) return;
    final today = DateTime.now().toIso8601String().substring(0,10);
    await supabase.from('daily_summary').upsert({
      'user_id': currentUserId,
      'summary_date': today,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,summary_date');
  }

  // Get weekly progress (for charts — last 7 days)
  Future<List<Map<String,dynamic>>> getWeeklyProgress() async {
    if (currentUserId == null) return [];
    final from = DateTime.now().subtract(const Duration(days: 6));
    return await supabase
        .from('weekly_progress')
        .select()
        .eq('user_id', currentUserId!)
        .gte('summary_date', from.toIso8601String().substring(0,10))
        .order('summary_date');
  }

  // Get user goals
  Future<Map<String,dynamic>> getGoals() async {
    if (currentUserId == null) return _defaultGoals();
    try {
      return await supabase
          .from('user_goals')
          .select()
          .eq('user_id', currentUserId!)
          .single();
    } catch (_) { return _defaultGoals(); }
  }

  Map<String,dynamic> _empty() => {
    'calories_consumed': 0, 'calories_burned': 0,
    'protein_g': 0, 'carbs_g': 0, 'fat_g': 0,
    'steps': 0, 'active_minutes': 0, 'water_ml': 0,
    'workout_done': false, 'workout_duration': 0,
  };

  Map<String,dynamic> _defaultGoals() => {
    'daily_calories': 2000, 'daily_protein_g': 150,
    'daily_carbs_g': 250, 'daily_fat_g': 65,
    'daily_water_ml': 2500, 'daily_steps': 10000,
  };
}
```

### lib/services/measurements_service.dart
```dart
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
    final d = (date ?? DateTime.now()).toIso8601String().substring(0,10);
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
  }

  Future<List<Map<String,dynamic>>> getWeightHistory() async {
    if (currentUserId == null) return [];
    return await supabase
        .from('weight_progress')
        .select()
        .eq('user_id', currentUserId!)
        .order('measured_date');
  }

  Future<Map<String,dynamic>?> getLatest() async {
    if (currentUserId == null) return null;
    try {
      return await supabase
          .from('body_measurements')
          .select()
          .eq('user_id', currentUserId!)
          .order('measured_date', ascending: false)
          .limit(1)
          .single();
    } catch (_) { return null; }
  }
}
```

---

## Step 2 — Onboarding Screens

Create `lib/screens/onboarding_flow.dart` — a multi-step onboarding
that saves data to Supabase when completed.

The flow has 5 steps (show a progress bar at top):

### Step 1 — Personal Info
- Title: "Let's get to know you"
- Fields: Full Name, Age (number picker), Gender (Male/Female cards)

### Step 2 — Body Measurements
- Title: "Your current body"
- Fields: Height (cm slider 140–220), Weight (kg slider 40–150)
- Show live BMI calculation below sliders

### Step 3 — Your Goal
- Title: "What's your goal?"
- 5 option cards (icon + label + description):
  🏋️ Muscle Gain → "Build strength and mass"
  🔥 Weight Loss → "Burn fat, feel lighter"
  🏃 Endurance   → "Improve stamina and cardio"
  🧘 Flexibility → "Move better, recover faster"
  ⚡ General Fitness → "Stay healthy and active"

### Step 4 — Activity Level
- Title: "How active are you?"
- 5 option cards:
  😴 Sedentary       → "Little to no exercise"
  🚶 Lightly Active  → "1-3 days/week"
  🏃 Moderately Active → "3-5 days/week"
  💪 Very Active     → "6-7 days/week"
  🔥 Extra Active    → "Twice daily"
- Show calculated TDEE below selection

### Step 5 — Target & Schedule
- Title: "Set your targets"
- Target weight slider
- Weekly workouts (1–7 pill selector)
- Show "Your daily calorie goal: X kcal" card

### Complete button
- Calls OnboardingService.saveOnboarding() with all collected data
- Shows loading indicator
- On success: Navigator.pushReplacement → FitnessHomePage

### Style
- Same dark background as existing app (#0A0A0A)
- Each step: SlideTransition from right
- Selection cards: AnimatedContainer with purple accent on select
- Progress bar: LinearProgressIndicator at top, purple fill

---

## Step 3 — Update main.dart

After Supabase.initialize, check auth state and onboarding:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mkrjvrnysuvtokqkyoll.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcmp2cm55c3V2dG9rcWt5b2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNDExMTgsImV4cCI6MjA4OTcxNzExOH0.Nf1xdRt2W1Ped0gulhdId2iAFC0KEp36-JD_4ey9dzg',
  );
  runApp(const MyApp());
}
```

In SplashScreen after 3s delay, check:
```dart
final user = supabase.auth.currentUser;
if (user == null) {
  // go to GenderSelectionScreen (existing flow)
} else {
  final done = await OnboardingService().isCompleted();
  if (done) {
    // go to FitnessHomePage
  } else {
    // go to OnboardingFlow
  }
}
```

After login/signup success in Login&SignUp.dart:
```dart
final done = await OnboardingService().isCompleted();
if (done) {
  Navigator.pushReplacement(context,
    MaterialPageRoute(builder: (_) => const FitnessHomePage()));
} else {
  Navigator.pushReplacement(context,
    MaterialPageRoute(builder: (_) => const OnboardingFlow()));
}
```

---

## Step 4 — Home Screen (FitnessHomePages.dart)

Load real data in initState:

```dart
final _statsService = StatsService();
Map<String,dynamic> _summary = {};
Map<String,dynamic> _goals = {};
List<Map<String,dynamic>> _weeklyProgress = [];
bool _loading = true;

@override
void initState() {
  super.initState();
  _loadData();
  // ... animations
}

Future<void> _loadData() async {
  final results = await Future.wait([
    _statsService.getTodaySummary(),
    _statsService.getGoals(),
    _statsService.getWeeklyProgress(),
  ]);
  if (mounted) setState(() {
    _summary = results[0] as Map<String,dynamic>;
    _goals   = results[1] as Map<String,dynamic>;
    _weeklyProgress = results[2] as List<Map<String,dynamic>>;
    _loading = false;
  });
}
```

### Stats Card — use real data:
- Calories: `_summary['calories_consumed']?.toString() ?? '0'`
- Steps: `'${((_summary['steps'] ?? 0) / 1000).toStringAsFixed(1)}k'`
- Active: `'${_summary['active_minutes'] ?? 0}m'`

### Weekly Chart — use real data from _weeklyProgress:
Replace `_generateBarGroups()` with:
```dart
List<BarChartGroupData> _generateBarGroups() {
  final days = List.generate(7, (i) {
    if (i < _weeklyProgress.length) {
      return _weeklyProgress[i];
    }
    return {'calorie_pct': 0, 'steps_pct': 0};
  });

  return List.generate(7, (index) {
    final day = days[index];
    return BarChartGroupData(
      x: index,
      barsSpace: 4,
      barRods: [
        BarChartRodData(
          toY: (day['calorie_pct'] as num? ?? 0).toDouble(),
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 12,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        BarChartRodData(
          toY: (day['steps_pct'] as num? ?? 0).toDouble(),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6C5CE7).withOpacity(0.3),
              const Color(0xFFA29BFE).withOpacity(0.3),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 12,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ],
    );
  });
}
```

---

## Step 5 — Nutrition Screen

Create `lib/screens/nutrition_screen.dart`:

### Layout (TabBar with 2 tabs):

#### Tab 1 — Today
- Header: date + total calories ring (CircularProgressIndicator styled)
  shows calories_consumed / goal_calories
- Macro row: Protein / Carbs / Fat — each with progress bar + grams
- 4 meal sections (Breakfast / Lunch / Dinner / Snack):
  Each section:
  - Header: meal name + total calories + "+" add button
  - List of logged foods (name, quantity, calories)
  - Swipe to delete

- FAB or "+" button → opens food search bottom sheet:
  - Search field (calls NutritionService.searchFoods)
  - Results list: food name + calories per 100g
  - On tap: show quantity input → log food

#### Tab 2 — History
- Calendar or week selector
- Bar chart: calories per day for selected week
- List of days with: calories, protein, workout done (✓/✗)

### Connect to Supabase:
- initState: load getTodayLogs() + getTodaySummary() + getGoals()
- After adding food: reload summary
- After deleting: reload summary

---

## Step 6 — Workout Screen (update progrems.dart)

When user taps "Start Now" on any exercise card:

1. Call `WorkoutService().startSession(muscleGroup: muscleGroup)`
   → returns sessionId

2. Show active workout bottom sheet or screen:
   - Exercise name + set counter
   - Weight input (kg) + reps input
   - "Log Set" button → calls logSet()
   - Shows all logged sets below
   - Rest timer countdown
   - "Finish Workout" → calls endSession()

3. After finishing: show summary card:
   - Total sets, total volume (kg × reps)
   - Duration
   - Personal record badge if new max weight

### My Workouts tab
Add a new screen `lib/screens/workout_history_screen.dart`:
- List of past sessions grouped by date
- Each session: muscle group, duration, sets count
- Tap → see all sets logged

---

## Step 7 — Progress Screen

Create `lib/screens/progress_screen.dart`:

### Sections:

#### Body Weight Chart
- Line chart (fl_chart LineChart)
- Data from MeasurementsService.getWeightHistory()
- X axis: dates, Y axis: weight kg
- Show weight change vs start: "+2.5 kg" or "-3 kg"
- "Log Today's Weight" button → input field → saveMeasurement()

#### Body Measurements Card
- Shows latest: weight, body fat %, waist, chest, arms
- "Update Measurements" button → form with all fields

#### Weekly Activity Chart
- Bar chart from getWeeklyProgress()
- Toggle between: Calories / Steps / Workouts

#### Personal Records
- List from WorkoutService.getPersonalRecords()
- Exercise name + max weight + date

#### Monthly Streak
- Calendar grid (7 cols) showing workout_done per day
- Green dot = workout done, grey = missed, empty = future

---

## Step 8 — Update Bottom Navigation

Update `_buildBottomNavigation()` in FitnessHomePages.dart
to have 4 or 5 items:

```
0 = Home (home_rounded)
1 = Nutrition (restaurant_outlined)  → NutritionScreen
2 = Workout (fitness_center)         → center elevated button
3 = Progress (trending_up_outlined)  → ProgressScreen
4 = Profile (person_rounded)         → ProfilePage
```

Each tab navigator push to corresponding screen.

---

## Step 9 — Profile Page (update profile.dart)

Load real data and show:
- Name, email, avatar from profiles table
- Age, weight, height, goal from profiles + onboarding
- Goals card: daily calorie goal, protein goal
- Stats this month: total workouts, total calories logged
- "Edit Goals" button → edit user_goals
- "Log Measurements" button → body measurements form
- Real logout via AuthService().signOut()

---

## Step 10 — Final Check

```bash
flutter analyze
flutter build apk --debug
```

---

## File Summary

| File | Action |
|------|--------|
| lib/services/supabase_client.dart     | CREATE |
| lib/services/onboarding_service.dart  | CREATE |
| lib/services/nutrition_service.dart   | CREATE |
| lib/services/workout_service.dart     | CREATE |
| lib/services/stats_service.dart       | CREATE |
| lib/services/measurements_service.dart| CREATE |
| lib/screens/onboarding_flow.dart      | CREATE |
| lib/screens/nutrition_screen.dart     | CREATE |
| lib/screens/workout_history_screen.dart | CREATE |
| lib/screens/progress_screen.dart      | CREATE |
| lib/main.dart                         | UPDATE |
| lib/splashScreen.dart                 | UPDATE (auth check) |
| lib/Login&SignUp.dart                 | UPDATE (onboarding check) |
| lib/FitnessHomePages.dart             | UPDATE (real data + new nav) |
| lib/progrems.dart                     | UPDATE (log sets) |
| lib/profile.dart                      | UPDATE (real data) |
