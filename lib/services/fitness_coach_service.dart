import 'dart:convert';

/// Mood levels for workout intensity adjustment
enum WorkoutMood {
  tired,
  light,
  medium,
  energetic,
  fullPower,
}

/// Muscle group targets
enum MuscleGroup {
  chest('الصدر'),
  back('الظهر'),
  shoulders('الأكتاف'),
  biceps('العضلات'),
  triceps('الترايسبس'),
  legs('القدمين'),
  abs('البطن'),
  cardio('كارديو');

  final String arabicName;
  const MuscleGroup(this.arabicName);
}

/// Generated exercise model
class CoachExercise {
  final String name;
  final int sets;
  final String reps;
  final int rest;
  final String muscle;
  final String tip;

  CoachExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.muscle,
    required this.tip,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'rest': rest,
        'muscle': muscle,
        'tip': tip,
      };
}

/// Generated workout plan
class WorkoutPlan {
  final String intro;
  final List<CoachExercise> exercises;

  WorkoutPlan({required this.intro, required this.exercises});

  Map<String, dynamic> toJson() => {
        'intro': intro,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());
}

/// Professional Fitness Coach AI Service
class FitnessCoachService {
  // Exercise database in Arabic
  static final Map<MuscleGroup, List<Map<String, dynamic>>> _exerciseDb = {
    MuscleGroup.chest: [
      {
        'name': 'بنش بريس',
        'sets': 4,
        'reps': '8-12',
        'rest': 90,
        'tip': 'حافظ على استقامة الكتفين واضغط بشكل متحكم',
      },
      {
        'name': 'بنش بريس مائل',
        'sets': 4,
        'reps': '10-12',
        'rest': 90,
        'tip': 'استهدف الجزء العلوي من الصدر',
      },
      {
        'name': 'ديد بنش',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حافظ على زاوية قائمة والكوع قريب من الجسم',
      },
      {
        'name': 'كيبل كروس',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'اقلب الاتجاه في النهاية للتنفس العميق',
      },
      {
        'name': 'تمارين الضغط',
        'sets': 3,
        'reps': 'حتى الفشل',
        'rest': 60,
        'tip': 'انزل حتى يصبح الكتف بموازاة المرفق',
      },
      {
        'name': 'فلاي بالدمبل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حافظ على انحناء خفيف في المرفقين',
      },
    ],
    MuscleGroup.back: [
      {
        'name': 'ديدليفت',
        'sets': 4,
        'reps': '6-8',
        'rest': 120,
        'tip': 'حافظ على استقامة الظهر والركبتة في زاوية صغيرة',
      },
      {
        'name': 'بول أب',
        'sets': 4,
        'reps': '8-12',
        'rest': 90,
        'tip': 'اسحب حتى تتجاوز الذقن البار',
      },
      {
        'name': 'سيتد راو',
        'sets': 4,
        'reps': '10-12',
        'rest': 90,
        'tip': 'اسحب نحو السرة وادفع بالمرفقين',
      },
      {
        'name': 'لات بول داون',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ركز على الانقباض وليس الوزن',
      },
      {
        'name': 'سيتد هيبريست',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حافظ على ثبات الجذع ولا تتأرجح',
      },
      {
        'name': 'تسلق الحبل',
        'sets': 3,
        'reps': 'حتى الفشل',
        'rest': 60,
        'tip': 'استخدم الساقين للمساعدة',
      },
    ],
    MuscleGroup.shoulders: [
      {
        'name': 'أوفرهيد بريس',
        'sets': 4,
        'reps': '8-12',
        'rest': 90,
        'tip': 'حافظ على مركزية الحركة ولا ترفع الحوض',
      },
      {
        'name': 'لاتيرال ريز',
        'sets': 4,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ارفع حتى يصبح الكوع بموازاة الكتف',
      },
      {
        'name': 'فرونت ريز',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حافظ على شد البطن وتجنب التأرجح',
      },
      {
        'name': 'فيرسايد ريير',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ادفع نحو الخلف بأعلى كتف',
      },
      {
        'name': 'شوغ بريس',
        'sets': 3,
        'reps': '10-12',
        'rest': 90,
        'tip': 'اضغط للأعلى بشكل متحكم',
      },
      {
        'name': 'فلاي خلفي',
        'sets': 3,
        'reps': '15-20',
        'rest': 60,
        'tip': 'ركز على العزله ولا تستخدم زخم',
      },
    ],
    MuscleGroup.biceps: [
      {
        'name': 'بار بريس كيرل',
        'sets': 4,
        'reps': '10-12',
        'rest': 60,
        'tip': 'حافظ على ثبات المرفقين بجانب الجسم',
      },
      {
        'name': 'هامر كيرل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'استهدف الراس القصير للعضلة',
      },
      {
        'name': 'بريتشر كيرل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'اقلب الرسغ في النهاية',
      },
      {
        'name': 'كونسنتريشن كيرل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ركز على النزول البطيء',
      },
      {
        'name': 'كابل كيرل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حافظ على توتر مستمر',
      },
    ],
    MuscleGroup.triceps: [
      {
        'name': 'كلوز غريب بريس',
        'sets': 4,
        'reps': '8-12',
        'rest': 90,
        'tip': 'حافظ على مرفقين متقاربين',
      },
      {
        'name': 'تراي ريز',
        'sets': 4,
        'reps': '10-12',
        'rest': 60,
        'tip': 'انزل_until كتف متوازي ثم اضغط',
      },
      {
        'name': 'كيبل بوش داون',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ركز على قبضه اليد لا الساعد',
      },
      {
        'name': 'سكل كراشر',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'اضغط بشكل متحكم ولا تفرقع المفصل',
      },
      {
        'name': 'ديبس',
        'sets': 3,
        'reps': 'حتى الفشل',
        'rest': 60,
        'tip': 'انزل بزاوية 90 درجة',
      },
    ],
    MuscleGroup.legs: [
      {
        'name': 'سكوات',
        'sets': 4,
        'reps': '8-12',
        'rest': 120,
        'tip': 'حافظ على استقامة الظهر والقدم بعرض الكتف',
      },
      {
        'name': 'ليج بريس',
        'sets': 4,
        'reps': '10-12',
        'rest': 90,
        'tip': 'انزل حتى زاوية 90 درجة',
      },
      {
        'name': 'لينج',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حافظ على قدم اماميه مستقيمة',
      },
      {
        'name': 'ليج كيرل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'حرك ببطء للتحكم',
      },
      {
        'name': 'ليج اكستنشن',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ركز على الانقباض في الاعلى',
      },
      {
        'name': 'كاف ريز',
        'sets': 4,
        'reps': '12-15',
        'rest': 60,
        'tip': 'انزل على الكعب وليس أطراف الأصابع',
      },
      {
        'name': 'جلوت هامل',
        'sets': 3,
        'reps': '12-15',
        'rest': 60,
        'tip': 'ادفع من العقب not الاصابع',
      },
    ],
    MuscleGroup.abs: [
      {
        'name': 'بلانك',
        'sets': 3,
        'reps': '30-60 ثانية',
        'rest': 30,
        'tip': 'حافظ على خط مستقيم من الرأس للقدمين',
      },
      {
        'name': 'كرانش',
        'sets': 3,
        'reps': '15-20',
        'rest': 30,
        'tip': 'لا تسحب الرقبة استعمل البطن',
      },
      {
        'name': 'ليج ريز',
        'sets': 3,
        'reps': '15-20',
        'rest': 30,
        'tip': 'انزل ببطء ولا تلمس الارض',
      },
      {
        'name': 'بلانك سايد',
        'sets': 3,
        'reps': '30-45 ثانية',
        'rest': 30,
        'tip': 'حافظ على خط مستقيم من القدم للرأس',
      },
      {
        'name': 'ماونتن كلمبر',
        'sets': 3,
        'reps': '20-30',
        'rest': 30,
        'tip': 'حافظ على core مشدود طوال الوقت',
      },
      {
        'name': 'بيلاري',
        'sets': 3,
        'reps': '12-15',
        'rest': 30,
        'tip': 'حافظ على ثبات اسفل الظهر',
      },
    ],
    MuscleGroup.cardio: [
      {
        'name': 'جري خفيف',
        'sets': 1,
        'reps': '5-10 دقائق',
        'rest': 0,
        'tip': 'حافظ على معدل نبض مناسب',
      },
      {
        'name': 'نط الحبل',
        'sets': 3,
        'reps': '1 دقيقة',
        'rest': 30,
        'tip': 'هبط على أطراف الأصابع',
      },
      {
        'name': 'بيربي',
        'sets': 3,
        'reps': '30 ثانية',
        'rest': 30,
        'tip': 'حافظ على شكل صحيح طوال الوقت',
      },
      {
        'name': 'جاك',
        'sets': 3,
        'reps': '30 ثانية',
        'rest': 20,
        'tip': 'استخدم الذراعين للمساعدة',
      },
      {
        'name': 'هاي نيز',
        'sets': 3,
        'reps': '30 ثانية',
        'rest': 20,
        'tip': 'ارفع الركبتين حتى مستوى الحوض',
      },
      {
        'name': 'كارديو بيضاوي',
        'sets': 1,
        'reps': '10-15 دقيقة',
        'rest': 0,
        'tip': 'حافظ على سرعة ثابتة',
      },
    ],
  };

  // Warm-up exercises
  static final List<Map<String, dynamic>> _warmupExercises = [
    {
      'name': 'تمارين الإحماء الخفيفة',
      'sets': 1,
      'reps': '3-5 دقائق',
      'rest': 0,
      'tip': 'حرك جميع المفاصل ببطء',
    },
    {
      'name': 'تمديد ديناميكي',
      'sets': 1,
      'reps': '5-10 دقائق',
      'rest': 0,
      'tip': 'ركز على العضلات المستهدفة',
    },
  ];

  // Motivation messages by mood (in Arabic)
  static final Map<WorkoutMood, List<String>> _motivationByMood = {
    WorkoutMood.tired: [
      'جسمك يحتاج للراحة، لكن التمرين الخفيف سينعشك. دعنا نبدأ بلطف.',
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
      'استعد لافضل تمرين في حياتك. الطاقه كامله!',
    ],
  };

  /// Generate a personalized workout plan
  WorkoutPlan generateWorkoutPlan({
    required WorkoutMood mood,
    required List<MuscleGroup> muscles,
    required int durationMinutes,
  }) {
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    // Calculate number of exercises based on duration
    int exerciseCount;
    if (durationMinutes <= 30) {
      exerciseCount = 4 + (random % 2); // 4-5 exercises
    } else if (durationMinutes <= 60) {
      exerciseCount = 6 + (random % 3); // 6-8 exercises
    } else {
      exerciseCount = 8 + (random % 3); // 8-10 exercises
    }

    // Adjust intensity based on mood
    final intensityMultiplier = _getIntensityMultiplier(mood);

    // Select exercises for each muscle group
    List<CoachExercise> exercises = [];
    exercises.add(_createWarmup());

    // Distribute exercises among muscle groups
    final exercisesPerMuscle = exerciseCount ~/ muscles.length;
    final extraExercises = exerciseCount % muscles.length;

    for (int i = 0; i < muscles.length; i++) {
      final muscleExercises = exercisesPerMuscle + (i < extraExercises ? 1 : 0);
      exercises.addAll(_selectExercisesForMuscle(
        muscles[i],
        muscleExercises,
        mood,
      ));
    }

    // Generate motivational intro
    final intro = _generateIntro(mood, muscles);

    return WorkoutPlan(intro: intro, exercises: exercises);
  }

  double _getIntensityMultiplier(WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return 0.6;
      case WorkoutMood.light:
        return 0.75;
      case WorkoutMood.medium:
        return 1.0;
      case WorkoutMood.energetic:
        return 1.15;
      case WorkoutMood.fullPower:
        return 1.3;
    }
  }

  CoachExercise _createWarmup() {
    final warmup = _warmupExercises[DateTime.now().millisecondsSinceEpoch % _warmupExercises.length];
    return CoachExercise(
      name: warmup['name'],
      sets: 1,
      reps: warmup['reps'],
      rest: 0,
      muscle: 'إحماء',
      tip: warmup['tip'],
    );
  }

  List<CoachExercise> _selectExercisesForMuscle(
    MuscleGroup muscle,
    int count,
    WorkoutMood mood,
  ) {
    final availableExercises = _exerciseDb[muscle] ?? [];
    if (availableExercises.isEmpty) return [];

    final selected = <CoachExercise>[];
    final usedIndices = <int>{};
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < count && usedIndices.length < availableExercises.length; i++) {
      final index = (random + i * 17) % availableExercises.length;
      if (usedIndices.contains(index)) continue;
      usedIndices.add(index);

      final exercise = availableExercises[index];
      final adjustedSets = _adjustSetsForMood(exercise['sets'], mood);
      final adjustedReps = _adjustRepsForMood(exercise['reps'], mood);
      final adjustedRest = _adjustRestForMood(exercise['rest'], mood);

      selected.add(CoachExercise(
        name: exercise['name'],
        sets: adjustedSets,
        reps: adjustedReps,
        rest: adjustedRest,
        muscle: muscle.arabicName,
        tip: exercise['tip'],
      ));
    }

    return selected;
  }

  int _adjustSetsForMood(int baseSets, WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return baseSets - 1 > 0 ? baseSets - 1 : 1;
      case WorkoutMood.light:
        return baseSets;
      case WorkoutMood.medium:
        return baseSets;
      case WorkoutMood.energetic:
        return baseSets + 1;
      case WorkoutMood.fullPower:
        return baseSets + 1;
    }
  }

  String _adjustRepsForMood(String baseReps, WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return '15-20';
      case WorkoutMood.light:
        return '12-15';
      case WorkoutMood.medium:
        return baseReps;
      case WorkoutMood.energetic:
        return baseReps;
      case WorkoutMood.fullPower:
        if (baseReps.contains('-')) {
          final parts = baseReps.split('-');
          final lower = int.tryParse(parts[0]) ?? 8;
          return '${lower - 2}-${(int.tryParse(parts[1]) ?? 12) - 2}';
        }
        return baseReps;
    }
  }

  int _adjustRestForMood(int baseRest, WorkoutMood mood) {
    switch (mood) {
      case WorkoutMood.tired:
        return baseRest + 30;
      case WorkoutMood.light:
        return baseRest + 15;
      case WorkoutMood.medium:
        return baseRest;
      case WorkoutMood.energetic:
        return baseRest - 15 > 0 ? baseRest - 15 : baseRest;
      case WorkoutMood.fullPower:
        return baseRest - 30 > 0 ? baseRest - 30 : 60;
    }
  }

  String _generateIntro(WorkoutMood mood, List<MuscleGroup> muscles) {
    final motivations = _motivationByMood[mood] ?? _motivationByMood[WorkoutMood.medium]!;
    final randomIndex = DateTime.now().millisecondsSinceEpoch % motivations.length;
    final baseMotivation = motivations[randomIndex];

    final muscleNames = muscles.map((m) => m.arabicName).join(' و ');
    final durationText = _getDurationText(muscles.length);

    return '$baseMotivation سنساعدك اليوم على تدريب $muscleNames خلال $durationText.';
  }

  String _getDurationText(int muscleCount) {
    if (muscleCount <= 2) {
      return '30-45 دقيقة';
    } else if (muscleCount <= 4) {
      return '45-60 دقيقة';
    } else {
      return '60-90 دقيقة';
    }
  }

  /// Get mood from energy level string
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
      case 'full power':
      case 'طاقة كاملة':
        return WorkoutMood.fullPower;
      default:
        return WorkoutMood.medium;
    }
  }

  /// Get muscle group from string
  static MuscleGroup? muscleFromString(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'chest':
      case 'صدر':
        return MuscleGroup.chest;
      case 'back':
      case 'ظهر':
        return MuscleGroup.back;
      case 'shoulders':
      case 'أكتاف':
        return MuscleGroup.shoulders;
      case 'biceps':
      case 'عضلات':
        return MuscleGroup.biceps;
      case 'triceps':
      case 'ترايسبس':
        return MuscleGroup.triceps;
      case 'legs':
      case 'قدمين':
        return MuscleGroup.legs;
      case 'abs':
      case 'بطن':
        return MuscleGroup.abs;
      case 'cardio':
      case 'كارديو':
        return MuscleGroup.cardio;
      default:
        return null;
    }
  }
}
