import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../fitness_home_pages.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  
  // Data
  String _name = '';
  int _age = 25;
  String _gender = 'male';
  double _heightCm = 175.0;
  double _weightKg = 75.0;
  String _goal = 'muscle_gain';
  String _activityLevel = 'moderately_active';
  double _targetWeight = 75.0;
  int _weeklyWorkouts = 4;

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // or AppColors.surfaceLowest
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _prevStep,
                    ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 5,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryFixed),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentStep + 1}/5',
                    style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                ],
              ),
            ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          _currentStep == 4 ? 'COMPLETE' : 'NEXT',
                          style: AppText.buttonPrimary.copyWith(color: Colors.black),
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.displaySm),
        const SizedBox(height: 8),
        Text(subtitle, style: AppText.bodyMd),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Let's get to know you", "Enter your basic info"),
          Text("Full Name", style: AppText.labelMd),
          const SizedBox(height: 8),
          TextField(
            style: AppText.bodyLg.copyWith(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceContainer,
              hintText: 'John Doe',
              hintStyle: AppText.bodyLg.copyWith(color: AppColors.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => _name = val,
          ),
          const SizedBox(height: 24),
          Text("Age: $_age", style: AppText.labelMd),
          Slider(
            value: _age.toDouble(),
            min: 14,
            max: 100,
            activeColor: AppColors.primaryFixed,
            onChanged: (val) {
              setState(() => _age = val.toInt());
            },
          ),
          const SizedBox(height: 24),
          Text("Gender", style: AppText.labelMd),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OptionCard(
                  icon: Icons.male,
                  label: "Male",
                  desc: "",
                  isSelected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _OptionCard(
                  icon: Icons.female,
                  label: "Female",
                  desc: "",
                  isSelected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStep2() {
    double bmi = _weightKg / ((_heightCm / 100) * (_heightCm / 100));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Your current body", "Help us tailor your plan"),
          Text("Height: ${_heightCm.toInt()} cm", style: AppText.labelMd),
          Slider(
            value: _heightCm,
            min: 140,
            max: 220,
            activeColor: AppColors.primaryFixed,
            onChanged: (val) => setState(() => _heightCm = val),
          ),
          const SizedBox(height: 24),
          Text("Weight: ${_weightKg.toInt()} kg", style: AppText.labelMd),
          Slider(
            value: _weightKg,
            min: 40,
            max: 150,
            activeColor: AppColors.primaryFixed,
            onChanged: (val) => setState(() => _weightKg = val),
          ),
          const SizedBox(height: 48),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryFixed, width: 2),
              ),
              child: Column(
                children: [
                  Text("BMI", style: AppText.labelMd),
                  Text(bmi.toStringAsFixed(1), style: AppText.displaySm),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("What's your goal?", "Select your primary focus"),
          _OptionCard(
            label: 'Muscle Gain',
            desc: 'Build strength and mass',
            icon: Icons.fitness_center,
            isSelected: _goal == 'muscle_gain',
            onTap: () => setState(() => _goal = 'muscle_gain'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Weight Loss',
            desc: 'Burn fat, feel lighter',
            icon: Icons.local_fire_department,
            isSelected: _goal == 'weight_loss',
            onTap: () => setState(() => _goal = 'weight_loss'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Endurance',
            desc: 'Improve stamina and cardio',
            icon: Icons.directions_run,
            isSelected: _goal == 'endurance',
            onTap: () => setState(() => _goal = 'endurance'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Flexibility',
            desc: 'Move better, recover faster',
            icon: Icons.self_improvement,
            isSelected: _goal == 'flexibility',
            onTap: () => setState(() => _goal = 'flexibility'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'General Fitness',
            desc: 'Stay healthy and active',
            icon: Icons.bolt,
            isSelected: _goal == 'general_fitness',
            onTap: () => setState(() => _goal = 'general_fitness'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    double bmr = _gender == 'male'
        ? 88.36 + (13.4 * _weightKg) + (4.8 * _heightCm) - (5.7 * _age)
        : 447.6 + (9.2 * _weightKg) + (3.1 * _heightCm) - (4.3 * _age);
    final multipliers = {
      'sedentary': 1.2,
      'lightly_active': 1.375,
      'moderately_active': 1.55,
      'very_active': 1.725,
      'extra_active': 1.9,
    };
    int tdee = (bmr * (multipliers[_activityLevel] ?? 1.55)).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("How active are you?", "Helps calculate your nutrition"),
          _OptionCard(
            label: 'Sedentary',
            desc: 'Little to no exercise',
            icon: Icons.chair,
            isSelected: _activityLevel == 'sedentary',
            onTap: () => setState(() => _activityLevel = 'sedentary'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Lightly Active',
            desc: '1-3 days/week',
            icon: Icons.directions_walk,
            isSelected: _activityLevel == 'lightly_active',
            onTap: () => setState(() => _activityLevel = 'lightly_active'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Moderately Active',
            desc: '3-5 days/week',
            icon: Icons.directions_run,
            isSelected: _activityLevel == 'moderately_active',
            onTap: () => setState(() => _activityLevel = 'moderately_active'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Very Active',
            desc: '6-7 days/week',
            icon: Icons.fitness_center,
            isSelected: _activityLevel == 'very_active',
            onTap: () => setState(() => _activityLevel = 'very_active'),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            label: 'Extra Active',
            desc: 'Twice daily',
            icon: Icons.electric_bolt,
            isSelected: _activityLevel == 'extra_active',
            onTap: () => setState(() => _activityLevel = 'extra_active'),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              "EST. MAINTENANCE: $tdee KCAL",
              style: AppText.labelLg.copyWith(color: AppColors.primaryFixed),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Set your targets", "Build your routine"),
          Text("Target Weight: ${_targetWeight.toInt()} kg", style: AppText.labelMd),
          Slider(
            value: _targetWeight,
            min: 40,
            max: 150,
            activeColor: AppColors.primaryFixed,
            onChanged: (val) => setState(() => _targetWeight = val),
          ),
          const SizedBox(height: 32),
          Text("Weekly Workouts", style: AppText.labelMd),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: List.generate(7, (index) {
              final count = index + 1;
              final selected = _weeklyWorkouts == count;
              return GestureDetector(
                onTap: () => setState(() => _weeklyWorkouts = count),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryFixed : AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: AppText.titleMd.copyWith(
                      color: selected ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.glass1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryFixed.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.primaryFixed, size: 48),
                const SizedBox(height: 16),
                Text(
                  "You're all set!",
                  style: AppText.headlineSm,
                ),
                const SizedBox(height: 8),
                Text(
                  "We've calculated your personalized plan based on your metrics.",
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryFixed.withValues(alpha: 0.1) : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryFixed : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryFixed : AppColors.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.titleSm.copyWith(
                      color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
