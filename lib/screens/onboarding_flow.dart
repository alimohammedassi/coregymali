import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../fitness_home_pages.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Flow  (upgraded UI — same logic, same data layer)
// Design reference: segmented step bar, drum-picker inputs, radio option cards
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // ── Data (untouched) ──
  String _name = '';
  int _age = 25;
  String _gender = 'male';
  double _heightCm = 175.0;
  double _weightKg = 75.0;
  String _goal = 'muscle_gain';
  String _activityLevel = 'moderately_active';
  double _targetWeight = 75.0;
  int _weeklyWorkouts = 4;

  static const int _totalSteps = 5;

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      await OnboardingService().saveOnboarding(
        name: _name,
        age: _age,
        gender: _gender,
        heightCm: _heightCm,
        weightKg: _weightKg,
        goal: _goal,
        activityLevel: _activityLevel,
        targetWeight: _targetWeight,
        weeklyWorkouts: _weeklyWorkouts,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FitnessHomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Step header bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Back button
                  AnimatedOpacity(
                    opacity: _currentStep > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: _prevStep,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Segmented step indicators
                  Expanded(
                    child: Row(
                      children: List.generate(_totalSteps, (i) {
                        final isActive = i <= _currentStep;
                        final isCurrent = i == _currentStep;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            height: 4,
                            margin: EdgeInsets.only(right: i < _totalSteps - 1 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primaryFixed
                                  : AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryFixed.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // ── Page content ──
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(l10n),
                  _buildStep2(l10n),
                  _buildStep3(l10n),
                  _buildStep4(l10n),
                  _buildStep5(l10n),
                ],
              ),
            ),

            // ── Bottom CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _currentStep == _totalSteps - 1
                              ? 'Complete'
                              : 'Continue',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared header ──
  Widget _buildHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 1 — Name, Age, Gender
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep1(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Let's get to\nknow you", "Enter your basic info"),
          const SizedBox(height: 28),

          // Name input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.fullNameHint,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    hintText: 'John Doe',
                    hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.primaryFixed.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (val) => _name = val,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Age drum picker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'AGE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DrumPicker(
            value: _age,
            min: 14,
            max: 100,
            unit: 'years',
            onChanged: (v) => setState(() => _age = v),
          ),

          const SizedBox(height: 28),

          // Gender
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'GENDER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _GenderCard(
                    icon: Icons.male_rounded,
                    label: 'Male',
                    isSelected: _gender == 'male',
                    onTap: () => setState(() => _gender = 'male'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderCard(
                    icon: Icons.female_rounded,
                    label: 'Female',
                    isSelected: _gender == 'female',
                    onTap: () => setState(() => _gender = 'female'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 2 — Height & Weight
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep2(AppLocalizations l10n) {
    final bmi = _weightKg / ((_heightCm / 100) * (_heightCm / 100));
    final bmiLabel = bmi < 18.5
        ? 'Underweight'
        : bmi < 25
            ? 'Normal'
            : bmi < 30
                ? 'Overweight'
                : 'Obese';
    final bmiColor = bmi < 18.5
        ? AppColors.secondary
        : bmi < 25
            ? AppColors.primaryFixed
            : bmi < 30
                ? AppColors.tertiaryFixed
                : AppColors.error;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Your current\nbody", "Help us tailor your plan"),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'HEIGHT (CM)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DrumPicker(
            value: _heightCm.toInt(),
            min: 140,
            max: 220,
            unit: 'cm',
            onChanged: (v) => setState(() => _heightCm = v.toDouble()),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'WEIGHT (KG)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DrumPicker(
            value: _weightKg.toInt(),
            min: 40,
            max: 150,
            unit: 'kg',
            onChanged: (v) => setState(() => _weightKg = v.toDouble()),
          ),

          const SizedBox(height: 24),

          // BMI insight card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bmiColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bmiColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bmiColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
                      color: bmiColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your BMI: ${bmi.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: bmiColor,
                          ),
                        ),
                        Text(
                          bmiLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 3 — Goal
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep3(AppLocalizations l10n) {
    final options = [
      (
        key: 'muscle_gain',
        label: l10n.muscleGain,
        desc: 'Build strength and mass',
        emoji: '💪',
      ),
      (
        key: 'weight_loss',
        label: l10n.weightLoss,
        desc: 'Burn fat, feel lighter',
        emoji: '🔥',
      ),
      (
        key: 'endurance',
        label: l10n.endurance,
        desc: 'Improve stamina and cardio',
        emoji: '🏃',
      ),
      (
        key: 'flexibility',
        label: l10n.flexibility,
        desc: 'Move better, recover faster',
        emoji: '🧘',
      ),
      (
        key: 'general_fitness',
        label: l10n.generalFitness,
        desc: 'Stay healthy and active',
        emoji: '⚡',
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("What's your\ngoal?", "Select your primary focus"),
          const SizedBox(height: 24),
          ...options.map(
            (opt) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: _RadioOptionCard(
                emoji: opt.emoji,
                label: opt.label,
                desc: opt.desc,
                isSelected: _goal == opt.key,
                onTap: () => setState(() => _goal = opt.key),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 4 — Activity Level
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep4(AppLocalizations l10n) {
    final bmr = _gender == 'male'
        ? 88.36 + (13.4 * _weightKg) + (4.8 * _heightCm) - (5.7 * _age)
        : 447.6 + (9.2 * _weightKg) + (3.1 * _heightCm) - (4.3 * _age);
    final multipliers = {
      'sedentary': 1.2,
      'lightly_active': 1.375,
      'moderately_active': 1.55,
      'very_active': 1.725,
      'extra_active': 1.9,
    };
    final tdee = (bmr * (multipliers[_activityLevel] ?? 1.55)).round();

    final options = [
      (
        key: 'sedentary',
        label: l10n.sedentary,
        desc: 'Little to no exercise',
        emoji: '🪑',
      ),
      (
        key: 'lightly_active',
        label: l10n.lightlyActive,
        desc: '1–3 days / week',
        emoji: '🚶',
      ),
      (
        key: 'moderately_active',
        label: l10n.moderatelyActive,
        desc: '3–5 days / week',
        emoji: '🏋️',
      ),
      (
        key: 'very_active',
        label: l10n.veryActive,
        desc: '6–7 days / week',
        emoji: '🚴',
      ),
      (
        key: 'extra_active',
        label: l10n.extraActive,
        desc: 'Twice daily / athlete',
        emoji: '⚡',
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("How active\nare you?", "Helps calculate your nutrition"),
          const SizedBox(height: 16),

          // TDEE live preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryFixed.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Est. daily calories:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$tdee kcal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryFixed,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          ...options.map(
            (opt) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: _RadioOptionCard(
                emoji: opt.emoji,
                label: opt.label,
                desc: opt.desc,
                isSelected: _activityLevel == opt.key,
                onTap: () => setState(() => _activityLevel = opt.key),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 5 — Target Weight & Weekly Workouts
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep5(AppLocalizations l10n) {
    final diff = (_targetWeight - _weightKg).abs();
    final isGain = _targetWeight > _weightKg;
    final isAtGoal = _targetWeight == _weightKg;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Set your\ntargets", "Build your routine"),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'TARGET WEIGHT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DrumPicker(
            value: _targetWeight.toInt(),
            min: 40,
            max: 150,
            unit: 'kg',
            onChanged: (v) => setState(() => _targetWeight = v.toDouble()),
          ),

          const SizedBox(height: 12),

          // Goal insight
          if (!isAtGoal)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isGain ? AppColors.primaryFixed : AppColors.secondary)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isGain
                            ? AppColors.primaryFixed
                            : AppColors.secondary)
                        .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Text(isGain ? '💪' : '🔥', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${isGain ? 'Gain' : 'Lose'} ${diff.toStringAsFixed(1)} kg from current weight',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 28),

          // Weekly workouts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.weeklyWorkoutsLabel.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final count = index + 1;
                final selected = _weeklyWorkouts == count;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _weeklyWorkouts = count);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: 40,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryFixed
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryFixed
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryFixed.withValues(alpha: 0.3),
                                blurRadius: 10,
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 32),

          // Summary card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryFixed.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.primaryFixed,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You're all set!",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "We've calculated your personalized plan based on your metrics.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drum Picker  (reference: "How old are you?" / "What's your height?" screens)
// Large centered number display + FixedExtentScrollController wheel
// ─────────────────────────────────────────────────────────────────────────────

class _DrumPicker extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _DrumPicker({
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  State<_DrumPicker> createState() => _DrumPickerState();
}

class _DrumPickerState extends State<_DrumPicker> {
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(
      initialItem: widget.value - widget.min,
    );
  }

  @override
  void didUpdateWidget(_DrumPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final target = widget.value - widget.min;
      if (_ctrl.hasClients && (_ctrl.selectedItem != target)) {
        _ctrl.jumpToItem(target);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection highlight
          Positioned(
            child: Container(
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primaryFixed.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          // Top fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 38,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surface,
                      AppColors.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom fade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 38,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.surface,
                      AppColors.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Wheel
          ListWheelScrollView.useDelegate(
            controller: _ctrl,
            itemExtent: 54,
            perspective: 0.003,
            diameterRatio: 2.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              widget.onChanged(widget.min + i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max - widget.min + 1,
              builder: (context, index) {
                final val = widget.min + index;
                final isSel = val == widget.value;
                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$val',
                        style: TextStyle(
                          fontSize: isSel ? 32 : 22,
                          fontWeight: FontWeight.w800,
                          color: isSel ? Colors.white : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.unit,
                        style: TextStyle(
                          fontSize: isSel ? 14 : 11,
                          color: isSel
                              ? AppColors.primaryFixed
                              : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Radio Option Card   (reference: tall cards with right-side radio circle)
// ─────────────────────────────────────────────────────────────────────────────

class _RadioOptionCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _RadioOptionCard({
    required this.emoji,
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed.withValues(alpha: 0.08)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryFixed.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryFixed.withValues(alpha: 0.08),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Emoji badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryFixed.withValues(alpha: 0.12)
                    : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Radio dot (reference pattern)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primaryFixed
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryFixed
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 13,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gender Card
// ─────────────────────────────────────────────────────────────────────────────

class _GenderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed.withValues(alpha: 0.1)
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryFixed.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primaryFixed : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
