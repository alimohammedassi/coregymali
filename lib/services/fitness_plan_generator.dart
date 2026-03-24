import 'dart:convert';
import 'exercise_database.dart';

enum WorkoutMood {
  tired,
  light,
  medium,
  energetic,
  fullPower,
}

class PlannedExercise {
  final Exercise exercise;
  final int sets;
  final String reps;
  final int restSeconds;
  final bool isWarmup;

  PlannedExercise({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.isWarmup = false,
  });

  Map<String, dynamic> toJson() => {
    'id': exercise.id,
    'name': exercise.nameAr,
    'sets': sets,
    'reps': reps,
    'rest': restSeconds,
    'muscle': exercise.muscleGroup,
    'tip': exercise.formTips,
    'isWarmup': isWarmup,
    'youtubeId': exercise.youtubeVideoId,
  };
}

class WorkoutPlan {
  final String intro;
  final List<PlannedExercise> exercises;
  final DateTime generatedAt;
  final int totalDurationMinutes;
  final String targetMuscles;
  final String userMood;

  WorkoutPlan({
    required this.intro,
    required this.exercises,
    required this.generatedAt,
    required this.totalDurationMinutes,
    required this.targetMuscles,
    required this.userMood,
  });

  Map<String, dynamic> toJson() => {
    'intro': intro,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
    'totalDurationMinutes': totalDurationMinutes,
    'targetMuscles': targetMuscles,
    'userMood': userMood,
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class FitnessPlanGenerator {
  static const Map<String, String> _muscleTranslations = {
    'chest': 'صدر',
    'back': 'ظهر',
    'shoulders': 'أكتاف',
    'biceps': 'بايسبس',
    'triceps': 'ترايسبس',
    'legs': 'رجل',
    'abs': 'بطن',
    'cardio': 'كارديو',
  };

  static const Map<String, List<String>> _muscleSynonyms = {
    'صدر': ['chest', 'pecs', 'pec'],
    'ظهر': ['back', 'lats', 'lat'],
    'أكتاف': ['shoulders', 'delts', 'delt'],
    'بايسبس': ['biceps', 'bicep', 'arms'],
    'ترايسبس': ['triceps', 'tricep', 'arms'],
    'رجل': ['legs', 'quads', 'hamstrings', 'thighs'],
    'بطن': ['abs', 'core', 'stomach'],
    'كارديو': ['cardio', 'cardio', 'heart'],
  };

  static String _translateMuscle(String muscle) {
    final lower = muscle.toLowerCase();
    for (final entry in _muscleSynonyms.entries) {
      if (entry.value.contains(lower) || entry.key.contains(lower)) {
        return entry.key;
      }
    }
    return _muscleTranslations[lower] ?? muscle;
  }

  static final Map<WorkoutMood, String> _moodTexts = {
    WorkoutMood.tired: 'متعب',
    WorkoutMood.light: 'خفيف',
    WorkoutMood.medium: 'متوسط',
    WorkoutMood.energetic: 'نشيط',
    WorkoutMood.fullPower: 'طاقة كاملة',
  };

  static final Map<WorkoutMood, List<String>> _introMessages = {
    WorkoutMood.tired: [
      'جسمك يحتاج للراحة، لكن التمرين الخفيف سينعشك اليوم.',
      'لا بأس بالتعب، اليوم مناسب لتمارين خفيفة تنشط الدورة الدموية.',
      'الطاقة تنبعث من الحركة حتى الصغيرة منها. هيا نبدأ!',
    ],
    WorkoutMood.light: [
      'مزاجك جيد، سنستغل هذا لشد عضلاتك بلطف.',
      'تمرين خفيف أفضل من لا شيء. استعد!',
      'اليوم فرصة لتعويد جسمك على الروتين. هيا!',
    ],
    WorkoutMood.medium: [
      'مستوى الطاقة جيد! سنحقق نتائج ممتازة اليوم.',
      'هذا هو الوقت المثالي لتمارين متوسطة الجودة.',
      'جاهز لبناء جسمك؟ هيا نبدأ بقوة متوسطة!',
    ],
    WorkoutMood.energetic: [
      'طاقتك عالية! حان وقت التحدي والضغط.',
      'نشعر بالحماس! استعد لتمارين مكثفة.',
      'الجسد جاهز والعقل مركز. هيا نكسر حدودنا!',
    ],
    WorkoutMood.fullPower: [
      'قمة الطاقة! اليوم هو يوم الارقام القياسية.',
      'لا حدود اليوم! استغل كل الطاقة المتاحة.',
      'استعد لافضل تمرين في حياتك. الطاقة كاملة!',
    ],
  };

  static WorkoutPlan generatePlan({
    required WorkoutMood mood,
    required List<String> muscles,
    required int durationMinutes,
  }) {
    final seed = DateTime.now().millisecondsSinceEpoch;
    final translatedMuscles = muscles.map(_translateMuscle).toList();

    List<PlannedExercise> exercises = [];

    // Add warmup first
    exercises.addAll(_generateWarmup());

    // Calculate remaining time after warmup (5-10 minutes)
    final workoutMinutes = durationMinutes - 8;
    final targetExerciseCount = _calculateExerciseCount(workoutMinutes);

    // Distribute exercises among muscle groups
    final exercisesPerMuscle = targetExerciseCount ~/ translatedMuscles.length;
    final extraExercises = targetExerciseCount % translatedMuscles.length;

    for (int i = 0; i < translatedMuscles.length; i++) {
      final muscle = translatedMuscles[i];
      final count = exercisesPerMuscle + (i < extraExercises ? 1 : 0);
      exercises.addAll(_selectExercisesForMuscle(muscle, count, mood, seed + i));
    }

    // Generate intro message
    final introIndex = seed % _introMessages[mood]!.length;
    final baseIntro = _introMessages[mood]![introIndex];
    final muscleNames = translatedMuscles.join(' و ');

    String intro = '$baseIntro ';
    if (translatedMuscles.length == 1) {
      intro += 'سنساعدك على تدريب $muscleNames بشكل احترافي.';
    } else {
      intro += 'سنساعدك على تدريب $muscleNames بشكل متكامل.';
    }

    return WorkoutPlan(
      intro: intro,
      exercises: exercises,
      generatedAt: DateTime.now(),
      totalDurationMinutes: durationMinutes,
      targetMuscles: translatedMuscles.join(', '),
      userMood: _moodTexts[mood]!,
    );
  }

  static List<PlannedExercise> _generateWarmup() {
    return [
      PlannedExercise(
        exercise: Exercise(
          id: 'warmup_jump',
          nameAr: 'إحماء خفيف - نط الحبل',
          nameEn: 'Light Jump Rope',
          muscleGroup: 'كارديو',
          difficulty: 'سهل',
          equipment: 'حبل',
          youtubeVideoId: 'FJmRQ5iTXKE',
          description: 'إحماء خفيف لتنشيط الدورة الدموية',
          formTips: 'نط بخفة على أطراف الأصابع لمدة 2-3 دقائق',
        ),
        sets: 1,
        reps: '2-3 دقائق',
        restSeconds: 0,
        isWarmup: true,
      ),
      PlannedExercise(
        exercise: Exercise(
          id: 'warmup_stretch',
          nameAr: 'تمديد ديناميكي',
          nameEn: 'Dynamic Stretching',
          muscleGroup: 'كارديو',
          difficulty: 'سهل',
          equipment: 'بدون',
          youtubeVideoId: 'i1gE_3eV3ME',
          description: 'تمديد ديناميكي للعضلات المستهدفة',
          formTips: 'حرك كل مفصل بشكل دائري لمدة 30 ثانية',
        ),
        sets: 1,
        reps: '5 دقائق',
        restSeconds: 0,
        isWarmup: true,
      ),
    ];
  }

  static int _calculateExerciseCount(int workoutMinutes) {
    if (workoutMinutes <= 20) return 3;
    if (workoutMinutes <= 30) return 4;
    if (workoutMinutes <= 45) return 5;
    if (workoutMinutes <= 60) return 6;
    if (workoutMinutes <= 75) return 7;
    return 8;
  }

  static List<PlannedExercise> _selectExercisesForMuscle(
    String muscle,
    int count,
    WorkoutMood mood,
    int seed,
  ) {
    final available = ExerciseDatabase.getByMuscle(muscle);
    if (available.isEmpty) return [];

    final selected = <PlannedExercise>[];
    final usedIndices = <int>{};
    var currentSeed = seed;

    for (var i = 0; i < count && usedIndices.length < available.length; i++) {
      currentSeed = (currentSeed * 31 + i * 17) % available.length;
      var index = currentSeed;

      // Avoid repeats
      var attempts = 0;
      while (usedIndices.contains(index) && attempts < available.length) {
        index = (index + 1) % available.length;
        attempts++;
      }

      if (usedIndices.contains(index)) continue;
      usedIndices.add(index);

      final exercise = available[index];
      final planned = _createPlannedExercise(exercise, mood);
      selected.add(planned);
    }

    return selected;
  }

  static PlannedExercise _createPlannedExercise(Exercise exercise, WorkoutMood mood) {
    int baseSets;
    String baseReps;
    int baseRest;

    // Determine base values based on difficulty and muscle
    switch (exercise.difficulty) {
      case 'سهل':
        baseSets = 3;
        baseReps = '12-15';
        baseRest = 60;
        break;
      case 'متوسط':
        baseSets = 4;
        baseReps = '8-12';
        baseRest = 90;
        break;
      case 'متقدم':
        baseSets = 4;
        baseReps = '6-8';
        baseRest = 120;
        break;
      default:
        baseSets = 3;
        baseReps = '10-12';
        baseRest = 90;
    }

    // Adjust for cardio
    if (exercise.muscleGroup == 'كارديو') {
      baseSets = 3;
      baseReps = '30 ثانية - 1 دقيقة';
      baseRest = 20;
    }

    // Adjust based on mood
    final adjusted = _adjustForMood(baseSets, baseReps, baseRest, mood);

    return PlannedExercise(
      exercise: exercise,
      sets: adjusted['sets']!,
      reps: adjusted['reps']!,
      restSeconds: adjusted['rest']!,
    );
  }

  static Map<String, dynamic> _adjustForMood(
    int sets,
    String reps,
    int rest,
    WorkoutMood mood,
  ) {
    switch (mood) {
      case WorkoutMood.tired:
        return {
          'sets': sets > 2 ? sets - 1 : 2,
          'reps': '15-20',
          'rest': rest + 30,
        };
      case WorkoutMood.light:
        return {
          'sets': sets,
          'reps': '12-15',
          'rest': rest + 15,
        };
      case WorkoutMood.medium:
        return {'sets': sets, 'reps': reps, 'rest': rest};
      case WorkoutMood.energetic:
        return {
          'sets': sets + 1,
          'reps': reps,
          'rest': rest > 60 ? rest - 15 : rest,
        };
      case WorkoutMood.fullPower:
        return {
          'sets': sets + 1,
          'reps': _decreaseReps(reps),
          'rest': rest > 60 ? rest - 30 : 60,
        };
    }
  }

  static String _decreaseReps(String reps) {
    if (reps.contains('-')) {
      final parts = reps.split('-');
      final lower = int.tryParse(parts[0]) ?? 8;
      final upper = int.tryParse(parts[1]) ?? 12;
      return '${(lower - 2).clamp(4, lower)}-${(upper - 2).clamp(6, upper)}';
    }
    return reps;
  }

  static WorkoutMood moodFromString(String mood) {
    switch (mood.toLowerCase()) {
      case 'tired':
      case 'متعب':
        return WorkoutMood.tired;
      case 'light':
      case 'خفيف':
        return WorkoutMood.light;
      case 'medium':
      case 'متوسط':
        return WorkoutMood.medium;
      case 'energetic':
      case 'نشيط':
        return WorkoutMood.energetic;
      case 'fullpower':
      case 'full power':
      case 'طاقة كاملة':
        return WorkoutMood.fullPower;
      default:
        return WorkoutMood.medium;
    }
  }
}
