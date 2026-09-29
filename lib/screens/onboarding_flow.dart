import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/onboarding_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../fitness_home_pages.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../features/coach/presentation/providers/coach_setup_provider.dart';
import '../features/coach/presentation/screens/coach_profile_setup_screen.dart';
import '../widgets/auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Flow
//
// Dark-pinned to the app's dark scheme (AppColors.dark* consts + volt accent)
// so it matches the auth screens regardless of the ambient theme mode.
//
// Calorie math: step previews call the SAME shared function
// (estimateCalorieBreakdown) OnboardingService persists to user_goals —
// Mifflin-St Jeor, upgraded to Katch-McArdle when the user enters an optional
// body-fat %, with the goal adjustment scaled by the pace step. The number
// shown on every step is the number that gets saved.
//
// Visualized, not just asked: a 4-zone BMI gauge with a live marker, and on
// the final step a results dashboard — count-up daily target, the BMR →
// activity → goal build-up, and the recommended macro donut.
//
// Motion/visual language (this file only, logic untouched):
//  - one ambient top-trailing glow whose color shifts per step
//  - a bespoke line-art glyph set (stroke-based CustomPainters) on every
//    option/gender badge instead of stock Material icons
//  - each step's content fades + slides up as it becomes current
//  - the results dashboard reveals in stages: count-up hero → build-up rows
//    staggered in → macro donut overshoot-scale, plus a one-shot sparkle
//    burst around the hero (skipped under reduced motion, never replays).
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

  // ── Data ──
  // No name field: the name is captured once at sign-up — asking again here
  // collected it twice, and an empty field used to NULL the profile name.
  int _age = 25;
  String _gender = 'male';
  double _heightCm = 175.0;
  double _weightKg = 75.0;
  String _goal = 'muscle_gain';
  String _activityLevel = 'moderately_active';
  double _targetWeight = 75.0;
  int _weeklyWorkouts = 4;
  // Precision inputs (calc-only, not persisted as columns):
  double? _bodyFatPct;
  bool _knowsBodyFat = false;
  String _pace = 'standard';

  static const int _totalSteps = 6;

  /// Ambient glow color per step — the canvas breathes with the context:
  /// volt for identity/body, coral for the goal, amber for pace, azure for
  /// activity, and volt again (hotter) for the payoff step.
  /// (AppColors accent statics are adaptive → non-const list.)
  static final List<Color> _stepGlows = [
    AppColors.primaryFixed, // 1 basics
    AppColors.primaryFixed, // 2 body
    AppColors.accentProtein, // 3 goal
    AppColors.accentCalories, // 4 pace
    AppColors.accentSteps, // 5 activity
    AppColors.primaryFixed, // 6 results (intensity lifted below)
  ];

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: AppDurations.medium,
        curve: AppCurves.emphasized,
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
        duration: AppDurations.medium,
        curve: AppCurves.emphasized,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      await OnboardingService().saveOnboarding(
        age: _age,
        gender: _gender,
        heightCm: _heightCm,
        weightKg: _weightKg,
        goal: _goal,
        activityLevel: _activityLevel,
        targetWeight: _targetWeight,
        weeklyWorkouts: _weeklyWorkouts,
        bodyFatPct: _knowsBodyFat ? _bodyFatPct : null,
        pace: _pace,
      );

      if (!mounted) return;
      final profileProv = context.read<ProfileProvider>();
      await profileProv.fetchProfile();

      if (!mounted) return;
      // Coaches still owe their dashboard-side profile setup before home.
      final Widget destination;
      if (profileProv.isCoach && profileProv.needsCoachSetup) {
        destination = ChangeNotifierProvider(
          create: (_) => CoachSetupNotifier(),
          child: const CoachProfileSetupScreen(),
        );
      } else {
        destination = const FitnessHomePage();
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      debugPrint('Onboarding save failed: $e');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FitnessHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Ambient step-colored glow, anchored top-trailing (mirrors RTL).
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: AppDurations.ambient,
                curve: AppCurves.standard,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(isRtl ? -0.75 : 0.75, -0.85),
                    radius: 1.0,
                    colors: [
                      _stepGlows[_currentStep].withValues(
                        alpha: _currentStep == _totalSteps - 1 ? 0.10 : 0.07,
                      ),
                      _stepGlows[_currentStep].withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
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
                        duration: AppDurations.fast,
                        child: GestureDetector(
                          onTap: _prevStep,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.darkSurfaceCard,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.darkBorder),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: AppColors.darkTextPrimary,
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
                                duration: AppDurations.medium,
                                curve: AppCurves.emphasized,
                                height: 4,
                                margin: EdgeInsetsDirectional.only(
                                  end: i < _totalSteps - 1 ? 4 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primaryFixed
                                      : AppColors.darkBorder,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryFixed
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                          ),
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
                      for (var i = 0; i < _totalSteps; i++)
                        _StepReveal(
                          active: _currentStep == i,
                          child: _buildStep(i, l10n),
                        ),
                    ],
                  ),
                ),

                // ── Bottom CTA ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: AuthPrimaryButton(
                    label: _currentStep == _totalSteps - 1
                        ? l10n.flowComplete
                        : l10n.flowContinue,
                    enabled: true,
                    isLoading: _isLoading,
                    onTap: _nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int index, AppLocalizations l10n) {
    return switch (index) {
      0 => _buildStep1(l10n),
      1 => _buildStep2(l10n),
      2 => _buildStep3(l10n),
      3 => _buildStep4(l10n),
      4 => _buildStep5(l10n),
      _ => _buildStep6(l10n),
    };
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
              color: AppColors.darkTextPrimary,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.darkTextSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 1 — Age, Gender
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep1(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n.flow1Title, l10n.flow1Subtitle),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _sectionLabel(l10n.flowAge),
          ),
          const SizedBox(height: 12),
          _DrumPicker(
            value: _age,
            min: 14,
            max: 100,
            unit: l10n.flowYears,
            onChanged: (v) => setState(() => _age = v),
          ),

          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _sectionLabel(l10n.flowGender),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: _GenderCard(
                    glyph: _Glyph.male,
                    label: l10n.onbMale,
                    isSelected: _gender == 'male',
                    onTap: () => setState(() => _gender = 'male'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderCard(
                    glyph: _Glyph.female,
                    label: l10n.onbFemale,
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
  // Step 2 — Height, Weight, optional Body Fat % + live BMI gauge
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep2(AppLocalizations l10n) {
    final bmi = _weightKg / ((_heightCm / 100) * (_heightCm / 100));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n.flow2Title, l10n.flow2Subtitle),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _sectionLabel(l10n.flowHeight),
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
            child: _sectionLabel(l10n.flowWeight),
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

          // Optional body fat % — switches BMR to Katch-McArdle.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _knowsBodyFat
                      ? AppColors.primaryFixed.withValues(alpha: 0.5)
                      : AppColors.darkBorder,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.percent_rounded,
                        size: 18,
                        color: _knowsBodyFat
                            ? AppColors.primaryFixed
                            : AppColors.darkTextSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.flowKnowBodyFat,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: _knowsBodyFat,
                        activeThumbColor: AppColors.primaryFixed,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _knowsBodyFat = v;
                            _bodyFatPct ??= 20;
                          });
                        },
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: AppDurations.fast,
                    crossFadeState: _knowsBodyFat
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DrumPicker(
                          value: _bodyFatPct?.round() ?? 20,
                          min: 5,
                          max: 60,
                          unit: '%',
                          onChanged: (v) =>
                              setState(() => _bodyFatPct = v.toDouble()),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l10n.flowBodyFatHint,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.darkTextSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    secondChild: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.darkBorder.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.flowOptional,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Live BMI gauge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _BmiGauge(bmi: bmi),
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
        desc: l10n.flowGoalDescGain,
        glyph: _Glyph.dumbbell,
      ),
      (
        key: 'weight_loss',
        label: l10n.weightLoss,
        desc: l10n.flowGoalDescLoss,
        glyph: _Glyph.flame,
      ),
      (
        key: 'endurance',
        label: l10n.endurance,
        desc: l10n.flowGoalDescEndurance,
        glyph: _Glyph.stopwatch,
      ),
      (
        key: 'flexibility',
        label: l10n.flexibility,
        desc: l10n.flowGoalDescFlex,
        glyph: _Glyph.lotus,
      ),
      (
        key: 'general_fitness',
        label: l10n.generalFitness,
        desc: l10n.flowGoalDescGeneral,
        glyph: _Glyph.heart,
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n.flow3Title, l10n.flow3Subtitle),
          const SizedBox(height: 24),
          ...options.map(
            (opt) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: _OptionCard(
                glyph: opt.glyph,
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
  // Step 4 — Goal pace (scales the calorie adjustment; N/A for perf goals)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep4(AppLocalizations l10n) {
    final isLoss = _goal == 'weight_loss';
    final isGain = _goal == 'muscle_gain';
    final deltas = isLoss
        ? const {'slow': -250, 'standard': -500, 'fast': -750}
        : const {'slow': 150, 'standard': 300, 'fast': 450};

    final options = [
      (
        key: 'slow',
        label: l10n.flowPaceSlow,
        desc: l10n.flowPaceDescSlow(deltas['slow']!),
        glyph: _Glyph.ripple,
      ),
      (
        key: 'standard',
        label: l10n.flowPaceStandard,
        desc: l10n.flowPaceDescStandard(deltas['standard']!),
        glyph: _Glyph.gauge,
      ),
      (
        key: 'fast',
        label: l10n.flowPaceFast,
        desc: l10n.flowPaceDescFast(deltas['fast']!),
        glyph: _Glyph.bolt,
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n.flow4Title, l10n.flow4Subtitle),
          const SizedBox(height: 24),
          if (isLoss || isGain)
            ...options.map(
              (opt) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: _OptionCard(
                  glyph: opt.glyph,
                  label: opt.label,
                  desc: opt.desc,
                  isSelected: _pace == opt.key,
                  onTap: () => setState(() => _pace = opt.key),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.primaryFixed,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l10n.flowPaceNotNeeded,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 5 — Activity Level (live TDEE preview uses the persisted formula)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep5(AppLocalizations l10n) {
    final breakdown = _breakdown();
    final tdee = breakdown.daily;

    final options = [
      (
        key: 'sedentary',
        label: l10n.sedentary,
        desc: l10n.flowActDescSedentary,
        glyph: _Glyph.armchair,
      ),
      (
        key: 'lightly_active',
        label: l10n.lightlyActive,
        desc: l10n.flowActDescLight,
        glyph: _Glyph.walk,
      ),
      (
        key: 'moderately_active',
        label: l10n.moderatelyActive,
        desc: l10n.flowActDescModerate,
        glyph: _Glyph.bike,
      ),
      (
        key: 'very_active',
        label: l10n.veryActive,
        desc: l10n.flowActDescVery,
        glyph: _Glyph.run,
      ),
      (
        key: 'extra_active',
        label: l10n.extraActive,
        desc: l10n.flowActDescExtra,
        glyph: _Glyph.boltDouble,
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n.flow5Title, l10n.flow5Subtitle),
          const SizedBox(height: 16),

          // TDEE live preview — the shared formula, so this IS the saved value.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                    l10n.flowEstDaily,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$tdee ${l10n.kcal}',
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
              child: _OptionCard(
                glyph: opt.glyph,
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
  // Step 6 — Targets + results dashboard
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildStep6(AppLocalizations l10n) {
    final breakdown = _breakdown();
    final macros = computeGoalMacros(
      dailyCalories: breakdown.daily,
      weightKg: _weightKg,
    );
    final diff = (_targetWeight - _weightKg).abs();
    final isGain = _targetWeight > _weightKg;
    final isAtGoal = _targetWeight == _weightKg;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l10n.flow6Title, l10n.flow6Subtitle),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _sectionLabel(l10n.flowTargetWeight),
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
                  color:
                      (isGain
                              ? AppColors.primaryFixed
                              : AppColors.accentCalories)
                          .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (isGain
                                ? AppColors.primaryFixed
                                : AppColors.accentCalories)
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isGain
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isGain
                          ? AppColors.primaryFixed
                          : AppColors.accentCalories,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isGain
                            ? l10n.flowGainInsight(diff.toStringAsFixed(1))
                            : l10n.flowLoseInsight(diff.toStringAsFixed(1)),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 28),

          // Weekly workouts — 1..7 with a mid-week breathing gap.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _sectionLabel(l10n.weeklyWorkoutsLabel.toUpperCase()),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                for (var index = 0; index < 7; index++) ...[
                  if (index > 0)
                    SizedBox(width: index == 3 ? 10 : 5),
                  _WorkoutCell(
                    count: index + 1,
                    selected: _weeklyWorkouts == index + 1,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _weeklyWorkouts = index + 1);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          _ResultsDashboard(
            breakdown: breakdown,
            macros: macros,
            active: _currentStep == _totalSteps - 1,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// The shared estimate — identical inputs to [OnboardingService.saveOnboarding].
  ({int bmr, int tdee, int adjustment, int daily}) _breakdown() {
    return estimateCalorieBreakdown(
      gender: _gender,
      age: _age,
      heightCm: _heightCm,
      weightKg: _weightKg,
      goal: _goal,
      activityLevel: _activityLevel,
      bodyFatPct: _knowsBodyFat ? _bodyFatPct : null,
      pace: _pace,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step entrance — content fades in and settles up ~10px as the step becomes
// current, so pages don't snap. Replays per activation; skipped entirely
// under reduced motion.
// ─────────────────────────────────────────────────────────────────────────────

class _StepReveal extends StatefulWidget {
  final bool active;
  final Widget child;

  const _StepReveal({required this.active, required this.child});

  @override
  State<_StepReveal> createState() => _StepRevealState();
}

class _StepRevealState extends State<_StepReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _played = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.slow);
    // MediaQuery isn't reachable in initState — defer the first play.
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  @override
  void didUpdateWidget(_StepReveal old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _play();
  }

  void _play() {
    if (_played) return;
    _played = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results dashboard — the payoff reveal: count-up hero with a one-shot
// sparkle burst, build-up rows staggering in, macro donut overshoot-scaling.
// The whole sequence plays ONCE when the step becomes current; later
// rebuilds (drum tweaks) never restart it. Reduced motion shows the final
// state immediately.
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsDashboard extends StatefulWidget {
  final ({int bmr, int tdee, int adjustment, int daily}) breakdown;
  final ({int proteinG, int carbsG, int fatG}) macros;
  final bool active;

  const _ResultsDashboard({
    required this.breakdown,
    required this.macros,
    required this.active,
  });

  @override
  State<_ResultsDashboard> createState() => _ResultsDashboardState();
}

class _ResultsDashboardState extends State<_ResultsDashboard>
    with SingleTickerProviderStateMixin {
  // One controller drives the whole sequence: sparkles + row stagger +
  // donut pop ride intervals of the same timeline so they stay in sync.
  static final Duration _sequence =
      AppDurations.countUp + AppDurations.reveal;

  late final AnimationController _ctrl;
  bool _played = false;
  int _rowCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _sequence);
    // MediaQuery isn't reachable in initState — defer the first play.
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  @override
  void didUpdateWidget(_ResultsDashboard old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _play();
  }

  void _play() {
    if (_played) return;
    _played = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _fmt(int v) {
    final s = '$v';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activityBurn = widget.breakdown.tdee - widget.breakdown.bmr;
    final rows = <({String label, int value, double fraction, Color color, String sign})>[
      (
        label: l10n.flowResultBmr,
        value: widget.breakdown.bmr,
        fraction: widget.breakdown.bmr / widget.breakdown.daily,
        color: AppColors.darkTextSecondary,
        sign: '',
      ),
      (
        label: l10n.flowResultActivity,
        value: activityBurn,
        fraction: activityBurn / widget.breakdown.daily,
        color: AppColors.accentSteps,
        sign: '+',
      ),
      if (widget.breakdown.adjustment != 0)
        (
          label: l10n.flowResultGoal,
          value: widget.breakdown.adjustment,
          fraction: widget.breakdown.adjustment.abs() / widget.breakdown.daily,
          color: widget.breakdown.adjustment > 0
              ? AppColors.accentProtein
              : AppColors.accentCalories,
          sign: widget.breakdown.adjustment > 0 ? '+' : '−',
        ),
    ];
    _rowCount = rows.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryFixed.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          // Registered as "the result" — a visibly stronger halo than any
          // input card in the flow.
          BoxShadow(
            color: AppColors.primaryFixed.withValues(alpha: 0.16),
            blurRadius: 28,
          ),
          BoxShadow(
            color: AppColors.primaryFixed.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero — count-up daily target with a one-shot sparkle burst.
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final t = const Interval(0, 0.4, curve: AppCurves.standard)
                        .transform(_ctrl.value);
                    return (t > 0 && t < 1)
                        ? CustomPaint(painter: _SparklePainter(t: t))
                        : const SizedBox.shrink();
                  },
                ),
              ),
              Column(
                children: [
                  Text(
                    l10n.flowResultDaily,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The count-up intentionally re-tweens when the target
                  // weight drum changes — the number settles to its new value.
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: widget.breakdown.daily),
                    duration: AppDurations.countUp,
                    curve: AppCurves.standard,
                    builder: (context, value, _) => Text(
                      _fmt(value),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        color: AppColors.primaryFixed,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    l10n.flowKcalDay,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Build-up rows — staggered fade/slide-in after the hero lands.
          for (var i = 0; i < rows.length; i++)
            _StaggerIn(
              ctrl: _ctrl,
              beginMs: 450 + i * AppDurations.stagger.inMilliseconds,
              spanMs: 380,
              total: _sequence,
              reduced: MediaQuery.disableAnimationsOf(context),
              child: _BuildUpRow(
                label: rows[i].label,
                value: rows[i].value,
                fraction: rows[i].fraction,
                color: rows[i].color,
                sign: rows[i].sign,
              ),
            ),

          const SizedBox(height: 18),

          // Macro donut + legend — pops in after the rows settle.
          _StaggerIn(
            ctrl: _ctrl,
            beginMs: 500 + (_rowCount + 1) * AppDurations.stagger.inMilliseconds,
            spanMs: AppDurations.reveal.inMilliseconds,
            total: _sequence,
            reduced: MediaQuery.disableAnimationsOf(context),
            scaleFrom: 0.8,
            curve: AppCurves.overshoot,
            child: Column(
              children: [
                Text(
                  l10n.flowResultMacros,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft volt halo behind the donut hub — same glow
                          // language as the step indicator.
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primaryFixed.withValues(
                                    alpha: 0.22,
                                  ),
                                  AppColors.primaryFixed.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              startDegreeOffset: -90,
                              sections: [
                                PieChartSectionData(
                                  value: (widget.macros.proteinG * 4)
                                      .toDouble(),
                                  color: AppColors.accentProtein,
                                  radius: 17,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: (widget.macros.carbsG * 4).toDouble(),
                                  color: AppColors.accentCarbs,
                                  radius: 17,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: (widget.macros.fatG * 9).toDouble(),
                                  color: AppColors.accentFat,
                                  radius: 17,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _fmt(widget.breakdown.daily),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MacroLegend(
                            color: AppColors.accentProtein,
                            label: l10n.protein,
                            grams: widget.macros.proteinG,
                          ),
                          const SizedBox(height: 10),
                          _MacroLegend(
                            color: AppColors.accentCarbs,
                            label: l10n.carbs,
                            grams: widget.macros.carbsG,
                          ),
                          const SizedBox(height: 10),
                          _MacroLegend(
                            color: AppColors.accentFat,
                            label: l10n.fat,
                            grams: widget.macros.fatG,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades + slides a child in over [beginMs, beginMs+spanMs] of [total].
/// With `scaleFrom` set it also scales (for the donut's overshoot pop).
/// Reduced motion: child shown immediately at full opacity.
class _StaggerIn extends StatelessWidget {
  final AnimationController ctrl;
  final int beginMs;
  final int spanMs;
  final Duration total;
  final bool reduced;
  final double scaleFrom;
  final Curve curve;
  final Widget child;

  const _StaggerIn({
    required this.ctrl,
    required this.beginMs,
    required this.spanMs,
    required this.total,
    required this.reduced,
    this.scaleFrom = 1.0,
    this.curve = AppCurves.standard,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (reduced) return child;
    final begin = beginMs / total.inMilliseconds;
    final end = (beginMs + spanMs) / total.inMilliseconds;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final t = Interval(begin.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
                curve: AppCurves.standard)
            .transform(ctrl.value);
        // Local 0→1 progress for the scale curve so the overshoot pops
        // against its own window, not the whole timeline.
        final local =
            ((ctrl.value - begin) / (end - begin)).clamp(0.0, 1.0);
        final s = curve.transform(local);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * s,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// One-shot sparkle burst around the hero number. Particles fly outward from
/// the center with slight gravity, fading as they go — plays exactly once
/// (it only paints while its interval is in (0, 1)) and is never re-armed.
class _SparklePainter extends CustomPainter {
  final double t;
  _SparklePainter({required this.t});

  // AppColors accent statics are adaptive (non-const), so this can't be const.
  static final _colors = [
    AppColors.primaryFixed,
    AppColors.accentCarbs,
    AppColors.accentSteps,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - t).clamp(0.0, 1.0);
    final origin = Offset(size.width / 2, size.height * 0.42);
    final rnd = math.Random(11);
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * math.pi + rnd.nextDouble() * 0.5;
      final speed = 46 + rnd.nextDouble() * 60;
      final dx = origin.dx + math.cos(angle) * speed * t;
      final dy =
          origin.dy + math.sin(angle) * speed * t * 0.9 + 60 * t * t;
      paint.color = _colors[i % _colors.length]
          .withValues(alpha: (0.85 * fade).clamp(0.0, 1.0));
      final r = 1.6 + rnd.nextDouble() * 1.8;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.t != t;
}

class _BuildUpRow extends StatelessWidget {
  final String label;
  final int value;
  final double fraction;
  final Color color;
  final String sign;

  const _BuildUpRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
    required this.sign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                duration: AppDurations.reveal,
                curve: AppCurves.standard,
                builder: (context, t, _) => LinearProgressIndicator(
                  value: t,
                  minHeight: 6,
                  backgroundColor: AppColors.darkBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              '$sign${_fmtInt(value.abs())}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color == AppColors.darkTextSecondary
                    ? AppColors.darkTextPrimary
                    : color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtInt(int v) {
    final s = '$v';
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buf.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }
}

class _MacroLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int grams;

  const _MacroLegend({
    required this.color,
    required this.label,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const Spacer(),
        Text(
          '${grams}g',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.darkTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BMI gauge — 4 color zones proportional to their BMI span, animated marker
// riding a soft glow in its zone color.
// ─────────────────────────────────────────────────────────────────────────────

class _BmiGauge extends StatelessWidget {
  final double bmi;

  const _BmiGauge({required this.bmi});

  static const double _min = 15;
  static const double _max = 40;

  Color get _zoneColor {
    if (bmi < 18.5) return AppColors.accentSteps;
    if (bmi < 25) return AppColors.primaryFixed;
    if (bmi < 30) return AppColors.accentCalories;
    return AppColors.error;
  }

  String _zoneLabel(AppLocalizations l10n) {
    if (bmi < 18.5) return l10n.flowBmiUnder;
    if (bmi < 25) return l10n.flowBmiNormal;
    if (bmi < 30) return l10n.flowBmiOver;
    return l10n.flowBmiObese;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final markerT = ((bmi - _min) / (_max - _min)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.flowBmiTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const Spacer(),
              Text(
                bmi.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _zoneColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _zoneColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _zoneLabel(l10n),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _zoneColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Zone bar — widths proportional to each zone's BMI span.
          SizedBox(
            height: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Row(
                children: [
                  Expanded(
                    flex: ((18.5 - _min) * 10).round(),
                    child: Container(color: AppColors.accentSteps),
                  ),
                  Expanded(
                    flex: ((25 - 18.5) * 10).round(),
                    child: Container(color: AppColors.primaryFixed),
                  ),
                  Expanded(
                    flex: ((30 - 25) * 10).round(),
                    child: Container(color: AppColors.accentCalories),
                  ),
                  Expanded(
                    flex: ((_max - 30) * 10).round(),
                    child: Container(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Animated marker rides the bar on a soft zone-colored glow.
          SizedBox(
            height: 26,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: markerT),
              duration: AppDurations.reveal,
              curve: AppCurves.standard,
              builder: (context, t, _) => Align(
                alignment: AlignmentDirectional(-1 + 2 * t, 0),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _zoneColor.withValues(alpha: 0.4),
                        _zoneColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 3.5,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '15',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              Text(
                '18.5',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              Text(
                '25',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              Text(
                '30',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              Text(
                '40',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drum Picker — large centered number + wheel. The selection highlight is a
// physical slot: layered shadows plus an inset-style top/bottom gradient so
// the middle value reads as recessed.
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
    _ctrl = FixedExtentScrollController(initialItem: widget.value - widget.min);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Selection slot — layered shadow gives it depth.
            Positioned(
              child: Container(
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryFixed.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.08),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
            ),
            // Inset-style shading — top/bottom darken into the slot.
            Positioned(
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.42, 0.58, 1],
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
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
                        AppColors.darkBackground,
                        AppColors.darkBackground.withValues(alpha: 0),
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
                        AppColors.darkBackground,
                        AppColors.darkBackground.withValues(alpha: 0),
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
                            color: isSel
                                ? AppColors.darkTextPrimary
                                : AppColors.darkTextSecondary.withValues(
                                    alpha: 0.4,
                                  ),
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
                                : AppColors.darkTextSecondary.withValues(
                                    alpha: 0.3,
                                  ),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly workouts cell — elastic bounce on select (reduced-motion safe).
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutCell extends StatefulWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _WorkoutCell({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_WorkoutCell> createState() => _WorkoutCellState();
}

class _WorkoutCellState extends State<_WorkoutCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppDurations.bounce);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTap: () {
        if (!selected && !MediaQuery.disableAnimationsOf(context)) {
          _ctrl.forward(from: 0);
        }
        widget.onTap();
      },
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1.0).animate(
          CurvedAnimation(parent: _ctrl, curve: AppCurves.bounce),
        ),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          width: 38,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryFixed : AppColors.darkSurfaceCard,
            borderRadius: BorderRadius.circular(selected ? 14 : 10),
            border: Border.all(
              color: selected ? AppColors.primaryFixed : AppColors.darkBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.onPrimary : AppColors.darkTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom glyph set — line-art stroke glyphs on a 24×24 design grid,
// consistent 2-unit stroke, round caps/joins. Used by the option/gender
// badges instead of stock Material icons so the flow has its own character.
// ─────────────────────────────────────────────────────────────────────────────

enum _Glyph {
  male,
  female,
  dumbbell,
  flame,
  stopwatch,
  lotus,
  heart,
  ripple,
  gauge,
  bolt,
  boltDouble,
  armchair,
  walk,
  bike,
  run,
}

class _FlowGlyph extends StatelessWidget {
  final _Glyph glyph;
  final double size;
  final Color color;

  const _FlowGlyph({
    required this.glyph,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(glyph: glyph, color: color)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final _Glyph glyph;
  final Color color;

  _GlyphPainter({required this.glyph, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final fill = Paint()..color = color;

    // Helpers work in the 24-unit design space.
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1 * s, y1 * s), Offset(x2 * s, y2 * s), stroke);
    void circle(double cx, double cy, double r, {bool filled = false}) =>
        canvas.drawCircle(
            Offset(cx * s, cy * s),
            r * s,
            filled
                ? fill
                : Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.0 * s
                  ..color = color);
    void path(Path p) => canvas.drawPath(p, stroke);
    Path p() => Path();

    switch (glyph) {
      case _Glyph.male:
        circle(9.5, 14.5, 4.8);
        line(12.9, 11.1, 19.5, 4.5);
        line(19.5, 4.5, 19.5, 9.5);
        line(19.5, 4.5, 14.5, 4.5);
      case _Glyph.female:
        circle(12, 8.3, 4.8);
        line(12, 13.1, 12, 21);
        line(8.5, 17.2, 15.5, 17.2);
      case _Glyph.dumbbell:
        line(7, 12, 17, 12);
        line(7, 9, 7, 15);
        line(17, 9, 17, 15);
        line(4, 10, 4, 14);
        line(20, 10, 20, 14);
      case _Glyph.flame:
        path(p()
          ..moveTo(12, 2.8)
          ..cubicTo(9.2, 6.6, 6.4, 9.3, 6.4, 13.2)
          ..arcToPoint(const Offset(17.6, 13.2),
              radius: const Radius.circular(5.6), clockwise: false)
          ..cubicTo(17.6, 9.3, 14.8, 6.6, 12, 2.8)
          ..close());
        path(p()
          ..moveTo(12, 12.4)
          ..cubicTo(10.6, 14, 10.2, 14.9, 10.2, 15.9)
          ..arcToPoint(const Offset(13.8, 15.9),
              radius: const Radius.circular(1.8), clockwise: false)
          ..cubicTo(13.8, 14.9, 13.4, 14, 12, 12.4)
          ..close());
      case _Glyph.stopwatch:
        circle(12, 13.4, 7.2);
        line(12, 2.6, 12, 6.2);
        line(9.4, 2.6, 14.6, 2.6);
        line(12, 13.4, 15.4, 10.4);
      case _Glyph.lotus:
        circle(12, 5.4, 2.1);
        line(12, 7.5, 12, 13.6);
        path(p()
          ..moveTo(5.2, 18.6)
          ..cubicTo(7.6, 13.8, 16.4, 13.8, 18.8, 18.6));
        line(6.8, 19.8, 17.2, 19.8);
      case _Glyph.heart:
        path(p()
          ..moveTo(12, 20)
          ..cubicTo(7, 15.6, 4.2, 12.6, 4.2, 9.4)
          ..cubicTo(4.2, 6.9, 6.1, 5.1, 8.3, 5.1)
          ..cubicTo(9.9, 5.1, 11.3, 6, 12, 7.4)
          ..cubicTo(12.7, 6, 14.1, 5.1, 15.7, 5.1)
          ..cubicTo(17.9, 5.1, 19.8, 6.9, 19.8, 9.4)
          ..cubicTo(19.8, 12.6, 17, 15.6, 12, 20)
          ..close());
      case _Glyph.ripple:
        path(p()
          ..moveTo(12, 4)
          ..arcToPoint(const Offset(20, 12),
              radius: const Radius.circular(8), clockwise: true)
          ..arcToPoint(const Offset(12, 20),
              radius: const Radius.circular(8), clockwise: true));
        path(p()
          ..moveTo(12, 7.6)
          ..arcToPoint(const Offset(16.4, 12),
              radius: const Radius.circular(4.4), clockwise: true));
        canvas.drawCircle(Offset(12 * s, 12 * s), 1.6 * s, fill);
      case _Glyph.gauge:
        path(p()
          ..moveTo(4.6, 16.2)
          ..arcToPoint(const Offset(19.4, 16.2),
              radius: const Radius.circular(7.4), clockwise: true));
        line(12, 16.2, 16.4, 10.4);
        canvas.drawCircle(Offset(12 * s, 16.2 * s), 1.6 * s, fill);
      case _Glyph.bolt:
        path(p()
          ..moveTo(13.2, 2.6)
          ..lineTo(6.4, 13)
          ..lineTo(11.4, 13)
          ..lineTo(10.6, 21.4)
          ..lineTo(17.6, 10.4)
          ..lineTo(12.6, 10.4)
          ..close());
      case _Glyph.boltDouble:
        path(p()
          ..moveTo(10.4, 2.6)
          ..lineTo(5.2, 11)
          ..lineTo(9, 11)
          ..lineTo(8.2, 18.4)
          ..lineTo(13.6, 10)
          ..lineTo(9.8, 10)
          ..close());
        path(p()
          ..moveTo(16.4, 7.4)
          ..lineTo(12.6, 13.4)
          ..lineTo(15.6, 13.4)
          ..lineTo(15, 21.4)
          ..lineTo(19.8, 12.4)
          ..lineTo(16.8, 12.4)
          ..close());
      case _Glyph.armchair:
        path(p()
          ..moveTo(7, 12.2)
          ..lineTo(7, 6.8)
          ..cubicTo(7, 5.5, 8, 4.5, 9.3, 4.5)
          ..lineTo(14.7, 4.5)
          ..cubicTo(16, 4.5, 17, 5.5, 17, 6.8)
          ..lineTo(17, 12.2));
        path(p()
          ..moveTo(4.4, 15.6)
          ..lineTo(4.4, 13.8)
          ..cubicTo(4.4, 12.6, 5.4, 11.7, 6.6, 11.7)
          ..lineTo(17.4, 11.7)
          ..cubicTo(18.6, 11.7, 19.6, 12.6, 19.6, 13.8)
          ..lineTo(19.6, 15.6)
          ..arcToPoint(const Offset(17.6, 17.6),
              radius: const Radius.circular(2), clockwise: false)
          ..lineTo(6.4, 17.6)
          ..arcToPoint(const Offset(4.4, 15.6),
              radius: const Radius.circular(2), clockwise: false)
          ..close());
        line(6.6, 17.6, 6.6, 19.8);
        line(17.4, 17.6, 17.4, 19.8);
      case _Glyph.walk:
        canvas.drawCircle(Offset(11.8 * s, 4.2 * s), 1.9 * s, stroke);
        line(11.8, 6.4, 11.8, 13.2);
        line(11.8, 8.4, 15.8, 10.2);
        line(11.8, 13.2, 8.6, 19.8);
        path(p()
          ..moveTo(11.8, 13.2)
          ..lineTo(14.8, 16.4)
          ..lineTo(14, 19.8));
      case _Glyph.bike:
        circle(6, 16.8, 3.5);
        circle(18, 16.8, 3.5);
        path(p()
          ..moveTo(6, 16.8)
          ..lineTo(10.2, 9.2)
          ..lineTo(14.8, 9.2)
          ..lineTo(18, 16.8));
        line(10.2, 9.2, 12.8, 16.8);
      case _Glyph.run:
        canvas.drawCircle(Offset(13.4 * s, 4.2 * s), 1.9 * s, stroke);
        line(12.6, 6.4, 11.6, 12.8);
        line(12.2, 8.4, 16.2, 9.8);
        path(p()
          ..moveTo(11.6, 12.8)
          ..lineTo(15.2, 15.6)
          ..lineTo(13.8, 19.8));
        line(11.6, 12.8, 8.2, 16.2);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Option Card — custom glyph badge + labels + radio dot.
// ─────────────────────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final _Glyph glyph;
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.glyph,
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
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed.withValues(alpha: 0.08)
              : AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryFixed.withValues(alpha: 0.5)
                : AppColors.darkBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryFixed.withValues(alpha: 0.08),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Glyph badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryFixed.withValues(alpha: 0.12)
                    : AppColors.darkBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _FlowGlyph(
                  glyph: glyph,
                  size: 24,
                  color: isSelected
                      ? AppColors.primaryFixed
                      : AppColors.darkTextSecondary,
                ),
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
                      color: isSelected
                          ? AppColors.darkTextPrimary
                          : AppColors.darkTextSecondary,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.darkTextSecondary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Radio dot
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primaryFixed : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryFixed
                      : AppColors.darkTextSecondary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: AppColors.onPrimary,
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
  final _Glyph glyph;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.glyph,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryFixed.withValues(alpha: 0.1)
              : AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryFixed.withValues(alpha: 0.5)
                : AppColors.darkBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            _FlowGlyph(
              glyph: glyph,
              size: 34,
              color: isSelected
                  ? AppColors.primaryFixed
                  : AppColors.darkTextSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.darkTextPrimary
                    : AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
