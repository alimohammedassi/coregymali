import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MuscleTrainingPage extends StatefulWidget {
  final String muscleGroup;

  const MuscleTrainingPage({super.key, required this.muscleGroup});

  @override
  State<MuscleTrainingPage> createState() => _MuscleTrainingPageState();
}

class _MuscleTrainingPageState extends State<MuscleTrainingPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Map<String, dynamic> getMuscleData(String muscle) {
    final data = {
      'chest': {
        'title': '💪 CHEST Training',
        'intro':
            'The chest muscles are the foundation of upper body strength and create that powerful, defined look that commands respect. Training your chest not only builds impressive mass but also enhances your pushing power for daily activities.',
        'gradient': const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
        ),
        'icon': Icons.fitness_center,
        'exercises': [
          {
            'name': 'Push-Ups',
            'description':
                'Classic bodyweight movement targeting the entire chest',
            'sets': '3 sets × 12-15 reps',
            'video': 'https://youtube.com/watch?v=IODxDxX7oi4',
            'image': 'assets/images/push_ups.jpg',
          },
          {
            'name': 'Bench Press',
            'description':
                'The king of chest exercises for building mass and strength',
            'sets': '4 sets × 8-10 reps',
            'video': 'https://youtube.com/watch?v=rT7DgCr-3pg',
            'image': 'assets/images/bench_press.jpg',
          },
          {
            'name': 'Incline Dumbbell Press',
            'description': 'Targets upper chest for a well-rounded development',
            'sets': '3 sets × 10-12 reps',
            'video': 'https://youtube.com/watch?v=8iPEnn-ltC8',
            'image': 'assets/images/incline_dumbbell_press.jpg',
          },
          {
            'name': 'Chest Dips',
            'description':
                'Compound movement that sculpts the lower chest effectively',
            'sets': '3 sets × 8-12 reps',
            'video': 'https://youtube.com/watch?v=2z8JmcrW-As',
            'image': 'assets/images/chest_dips.jpg',
          },
          {
            'name': 'Cable Fly',
            'description':
                'Isolation exercise for chest definition and muscle separation',
            'sets': '3 sets × 12-15 reps',
            'video': 'https://youtube.com/watch?v=QENKPHhQVi4',
            'image': 'assets/images/cable_fly.jpg',
          },
          {
            'name': 'Dumbbell Pullover',
            'description': 'Expands the rib cage and targets the chest and lats',
            'sets': '3 sets × 10-12 reps',
            'video': 'https://youtube.com/watch?v=fkd6F_f9_zI',
            'image': 'assets/images/dumbbell_pullover.jpg',
          },
          {
            'name': 'Pec Deck Fly',
            'description': 'Machine-based isolation for inner chest development',
            'sets': '3 sets × 15-20 reps',
            'video': 'https://youtube.com/watch?v=Z5CYvQ4f1bE',
            'image': 'assets/images/pec_deck_fly.jpg',
          },
        ],
        'tips': [
          'Always warm up with light cardio and dynamic stretches',
          'Focus on controlled movements rather than heavy weights',
          'Keep your shoulder blades retracted during pressing movements',
          'Don\'t arch your back excessively during bench press',
        ],
        'quote':
            '"The iron never lies to you. You can walk outside and listen to all kinds of talk, get told that you\'re a god or a total bastard. The iron will always kick you the real deal." - Henry Rollins',
      },
     'arms': {
        'title': '💥 ARMS Training',
        'intro':
            'Strong arms are essential for everyday functionality and athletic performance. Well-developed biceps and triceps not only look impressive but provide the power needed for pulling and pushing movements in daily life.',
        'gradient': const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
        ),
        'icon': Icons.sports_gymnastics,
        'exercises': [
            {
            'name': 'Bicep Curls',
            'description':
                'Classic isolation exercise for building bicep peaks',
            'sets': '3 sets × 12-15 reps',
            'video': 'https://youtube.com/watch?v=ykJmrZ5v0Oo',
            'image': 'assets/images/bicep_curls.jpg',
          },
          {
            'name': 'Tricep Dips',
            'description': 'Compound movement targeting the back of your arms',
            'sets': '3 sets × 10-12 reps',
            'video': 'https://youtube.com/watch?v=6kALZikXxLc',
            'image': 'assets/images/tricep_dips.jpg',
          },
          {
            'name': 'Hammer Curls',
            'description':
                'Targets both biceps and forearms for complete arm development',
            'sets': '3 sets × 12-14 reps',
            'video': 'https://youtube.com/watch?v=zC3nLlEvin4',
            'image': 'assets/images/hammer_curls.jpg',
          },
          {
            'name': 'Overhead Tricep Extension',
            'description': 'Isolation exercise for tricep mass and definition',
            'sets': '3 sets × 10-12 reps',
            'video': 'https://youtube.com/watch?v=YbX7Wd8jQ-Q',
            'image': 'assets/images/overhead_tricep_extension.jpg',
          },
          {
            'name': 'Pull-Ups',
            'description':
                'Compound exercise that builds incredible arm and back strength',
            'sets': '3 sets × 6-10 reps',
            'video': 'https://youtube.com/watch?v=eGo4IYlbE5g',
            'image': 'assets/images/pull_ups.jpg',
          },
          {
            'name': 'Concentration Curls',
            'description': 'Focuses on isolating the bicep for peak contraction',
            'sets': '3 sets × 10-12 reps each arm',
            'video': 'https://youtube.com/watch?v=0AUGkch3tzc',
            'image': 'assets/images/concentration_curls.jpg',
          },
          {
            'name': 'Close-Grip Bench Press',
            'description': 'Excellent for building tricep mass and strength',
            'sets': '4 sets × 8-10 reps',
            'video': 'https://youtube.com/watch?v=cXa1_p1y7tM',
            'image': 'assets/images/close_grip_bench_press.jpg',
          },
        ],
        'tips': [
          'Don\'t swing or use momentum during curls',
          'Focus on the mind-muscle connection',
          'Train biceps and triceps equally for balanced development',
          'Use full range of motion for maximum muscle activation',
        ],
        'quote':
            '"Strength does not come from physical capacity. It comes from an indomitable will." - Mahatma Gandhi',
      },
      'legs': {
        'title': '🦵 LEGS Training',
        'intro':
            'Your legs contain the largest muscle groups in your body and are the foundation of all athletic movement. Strong legs not only boost your metabolism but also support your entire physique and improve functional strength.',
        'gradient': const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
        ),
        'icon': Icons.directions_run,
        'exercises': [
            {
            'name': 'Squats',
            'description':
                'The king of all exercises, targeting quads, glutes, and core',
            'sets': '4 sets × 12-15 reps',
            'video': 'https://youtube.com/watch?v=Dy28eq2PjcM',
            'image': 'assets/images/squats.jpg',
          },
          {
            'name': 'Lunges',
            'description':
                'Unilateral movement that builds functional leg strength',
            'sets': '3 sets × 12 reps each leg',
            'video': 'https://youtube.com/watch?v=QOVaHwm-Q6U',
            'image': 'assets/images/lunges.jpg',
          },
          {
            'name': 'Deadlifts',
            'description':
                'Compound movement targeting hamstrings, glutes, and back',
            'sets': '4 sets × 8-10 reps',
            'video': 'https://youtube.com/watch?v=ytGaGIn3SjE',
            'image': 'assets/images/deadlifts.jpg',
          },
          {
            'name': 'Calf Raises',
            'description':
                'Isolation exercise for building defined calf muscles',
            'sets': '3 sets × 15-20 reps',
            'video': 'https://youtube.com/watch?v=gwLzBJYoWlI',
            'image': 'assets/images/calf_raises.jpg',
          },
          {
            'name': 'Bulgarian Split Squats',
            'description':
                'Advanced single-leg exercise for quad and glute development',
            'sets': '3 sets × 10-12 reps each leg',
            'video': 'https://youtube.com/watch?v=2C-uNgKwPLE',
            'image': 'assets/images/bulgarian_split_squats.jpg',
          },
          {
            'name': 'Leg Press',
            'description': 'Machine-based exercise for overall leg development',
            'sets': '3 sets × 10-15 reps',
            'video': 'https://youtube.com/watch?v=IZxyjW7MPJQ',
            'image': 'assets/images/leg_press.jpg',
          },
          {
            'name': 'Hamstring Curls',
            'description': 'Isolation exercise for hamstrings',
            'sets': '3 sets × 12-15 reps',
            'video': 'https://youtube.com/watch?v=F4h_y1y4y1Y',
            'image': 'assets/images/hamstring_curls.jpg',
          },        ],
        'tips': [
          'Keep your knees aligned with your toes during squats',
          'Don\'t let your knees cave inward during movements',
          'Focus on proper depth in squats for maximum activation',
          'Include both bilateral and unilateral exercises',
        ],
        'quote':
            '"The successful warrior is the average man with laser-like focus." - Bruce Lee',
      },
      'core': {
        'title': '🔥 CORE Training',
        'intro':
            'Your core is the powerhouse of your body, connecting your upper and lower body while providing stability and strength. A strong core improves posture, reduces back pain, and enhances performance in all other exercises.',
        'gradient': const LinearGradient(
          colors: [Color(0xFFFD79A8), Color(0xFFE84393)],
        ),
        'icon': Icons.self_improvement,
        'exercises': [
            {
            'name': 'Plank',
            'description':
                'Isometric exercise that strengthens the entire core',
            'sets': '3 sets × 30-60 seconds',
            'video': 'https://youtube.com/watch?v=ASdvN_XEl_c',
            'image': 'assets/images/plank.jpg',
          },
          {
            'name': 'Russian Twists',
            'description':
                'Rotational movement targeting obliques and deep core muscles',
            'sets': '3 sets × 20 reps each side',
            'video': 'https://youtube.com/watch?v=wkD8rjkodUI',
            'image': 'assets/images/russian_twists.jpg',
          },
          {
            'name': 'Mountain Climbers',
            'description':
                'Dynamic exercise combining core strength with cardio',
            'sets': '3 sets × 20 reps each leg',
            'video': 'https://youtube.com/watch?v=kLh-uczlPLg',
            'image': 'assets/images/mountain_climbers.jpg',
          },
          {
            'name': 'Dead Bug',
            'description':
                'Core stability exercise that teaches proper spine alignment',
            'sets': '3 sets × 10 reps each side',
            'video': 'https://youtube.com/watch?v=g_BYB0R-4Ws',
            'image': 'assets/images/dead_bug.jpg',
          },
          {
            'name': 'Bicycle Crunches',
            'description':
                'Dynamic movement targeting the entire abdominal region',
            'sets': '3 sets × 15 reps each side',
            'video': 'https://youtube.com/watch?v=9FGilxCbdz8',
            'image': 'assets/images/bicycle_crunches.jpg',
          },
          {
            'name': 'Leg Raises',
            'description': 'Targets lower abs and improves core strength',
            'sets': '3 sets × 15-20 reps',
            'video': 'https://youtube.com/watch?v=JB2oyawG92I',
            'image': 'assets/images/leg_raises.jpg',
          },
          {
            'name': 'Side Plank',
            'description': 'Strengthens obliques and improves lateral stability',
            'sets': '3 sets × 30-45 seconds each side',
            'video': 'https://youtube.com/watch?v=NXr5D_y_G5Q',
            'image': 'assets/images/side_plank.jpg',
          },
        ],
        'tips': [
          'Focus on quality over quantity in core exercises',
          'Breathe normally during planks and holds',
          'Keep your lower back pressed to the floor during crunches',
          'Engage your deep core muscles throughout each movement',
        ],
        'quote':
            '"Success isn\'t always about greatness. It\'s about consistency. Consistent hard work leads to success." - Dwayne Johnson',
      },
    };





    return data[muscle.toLowerCase()] ?? data['chest']!;
  }

  Future<void> _launchVideo(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch video')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muscleData = getMuscleData(widget.muscleGroup);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(muscleData),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildIntroduction(muscleData),
                        const SizedBox(height: 32),
                        _buildExercisesSection(muscleData),
                        const SizedBox(height: 32),
                        _buildTipsSection(muscleData),
                        const SizedBox(height: 32),
                        _buildMotivationalQuote(muscleData),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Map<String, dynamic> muscleData) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0A),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: muscleData['gradient']),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(muscleData['icon'], size: 48, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    muscleData['title'],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction(Map<String, dynamic> muscleData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Introduction',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            muscleData['intro'],
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesSection(Map<String, dynamic> muscleData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Effective Exercises',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        ...muscleData['exercises']
            .map<Widget>(
              (exercise) =>
                  _buildExerciseCard(exercise, muscleData['gradient']),
            )
            .toList(),
      ],
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise, Gradient gradient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exercise["image"] != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                exercise["image"],
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercise["name"],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _launchVideo(exercise["video"]),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            exercise["description"],
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800]!.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              exercise["sets"],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection(Map<String, dynamic> muscleData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber[400], size: 24),
              const SizedBox(width: 12),
              const Text(
                'Training Tips',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...muscleData['tips']
              .map<Widget>(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8, right: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildMotivationalQuote(Map<String, dynamic> muscleData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: muscleData['gradient'],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.format_quote, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(
            muscleData['quote'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
