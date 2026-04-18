import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../widgets/premium_glass_bg.dart';
import '../providers/coach_setup_provider.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../fitness_home_pages.dart';

class CoachProfileSetupScreen extends StatefulWidget {
  const CoachProfileSetupScreen({super.key});

  @override
  State<CoachProfileSetupScreen> createState() => _CoachProfileSetupScreenState();
}

class _CoachProfileSetupScreenState extends State<CoachProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();

  String? _selectedImagePath;
  String _gender = 'male';
  int _yearsExp = 1;
  final List<String> _specializations = [];
  final List<String> _certifications = [];
  final List<String> _languages = [];
  double _maxClients = 10;

  final _certCtrl = TextEditingController();
  bool _isPickerActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoachSetupNotifier>().addListener(_onStateChanged);
    });
  }

  void _onStateChanged() {
    // Re-render on provider changes
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    _priceCtrl.dispose();
    _premiumCtrl.dispose();
    _videoCtrl.dispose();
    _certCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickerActive) return;
    _isPickerActive = true;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (picked != null) {
        setState(() => _selectedImagePath = picked.path);
      }
    } on PlatformException catch (e) {
      if (e.code != 'already_active') {
        rethrow;
      }
    } catch (e) {
       // Ignore other errors securely
    } finally {
      _isPickerActive = false;
    }
  }

  void _addCertification() {
    if (_certCtrl.text.trim().isEmpty) return;
    setState(() {
      _certifications.add(_certCtrl.text.trim());
      _certCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = context.read<CoachSetupNotifier>();

    notifier.updateProfileImage(_selectedImagePath);
    notifier.updateDisplayName(_displayNameCtrl.text.trim());
    notifier.updateGender(_gender);
    notifier.updatePhoneNumber(_phoneCtrl.text.trim());
    notifier.updateCity(_cityCtrl.text.trim());
    notifier.updateYearsExperience(_yearsExp);
    notifier.updateBio(_bioCtrl.text.trim());
    notifier.updatePriceMonthly(double.tryParse(_priceCtrl.text) ?? 0);
    notifier.updatePricePremium(double.tryParse(_premiumCtrl.text) ?? 0);
    notifier.updateMaxClients(_maxClients.round());
    notifier.updateIntroVideoUrl(_videoCtrl.text.trim());

    // Update lists directly on state
    final state = notifier.state;
    final s = state.copyWith(
      specializations: _specializations,
      certifications: _certifications,
      languages: _languages,
    );
    // We need to apply them via the notifier
    for (final spec in _specializations) {
      if (!state.specializations.contains(spec)) {
        notifier.toggleSpecialization(spec);
      }
    }
    for (final lang in _languages) {
      if (!state.languages.contains(lang)) {
        notifier.toggleLanguage(lang);
      }
    }

    final err = await notifier.submit();
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (mounted) {
      await context.read<ProfileProvider>().fetchProfile();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const FitnessHomePage()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CoachSetupNotifier>();
    final state = notifier.state;

    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: PremiumGlassmorphismBg(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSectionTitle('PERSONAL INFO'),
                      const SizedBox(height: 12),
                      _buildPhotoPicker(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _displayNameCtrl,
                        label: 'Full Name / Display Name',
                        hint: 'e.g., Ahmed Hassan',
                        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildGenderSelector(),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        hint: '+1 234 567 8900',
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _cityCtrl,
                        label: 'City',
                        hint: 'e.g., Cairo',
                        validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('PROFESSIONAL'),
                      const SizedBox(height: 12),
                      _buildYearsExperience(),
                      const SizedBox(height: 16),
                      _buildSpecializations(),
                      const SizedBox(height: 16),
                      _buildCertifications(),
                      const SizedBox(height: 16),
                      _buildLanguages(),
                      const SizedBox(height: 16),
                      _buildBioField(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('PRICING'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _priceCtrl,
                        label: 'Standard Plan — Price per Month (USD)',
                        hint: 'e.g., 99',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Required';
                          if ((double.tryParse(v!) ?? 0) <= 0) return 'Must be greater than 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _premiumCtrl,
                        label: 'Premium Plan — Price per Month (USD)',
                        hint: 'Optional — leave empty for standard only',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildMaxClientsSlider(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('OPTIONAL'),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _videoCtrl,
                        label: 'Intro Video URL',
                        hint: 'YouTube or Vimeo link',
                      ),
                      const SizedBox(height: 32),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            state.error!,
                            style: AppText.bodySm.copyWith(color: AppColors.error),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: state.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC9A84C),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: state.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  'Start Coaching',
                                  style: AppText.buttonPrimary.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SET UP YOUR COACH PROFILE',
              style: AppText.labelLg.copyWith(
                color: const Color(0xFFC9A84C),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This info will be visible to clients',
              style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppText.labelMd.copyWith(
        color: const Color(0xFFC9A84C),
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.surfaceContainer,
              backgroundImage: _selectedImagePath != null
                  ? FileImage(File(_selectedImagePath!))
                  : null,
              child: _selectedImagePath == null
                  ? const Icon(Icons.person_rounded,
                      color: AppColors.onSurfaceVariant, size: 40)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A84C),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceLowest, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.black, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSegment('Male', 'male')),
            const SizedBox(width: 12),
            Expanded(child: _buildSegment('Female', 'female')),
          ],
        ),
      ],
    );
  }

  Widget _buildSegment(String label, String value) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFC9A84C).withValues(alpha: 0.15)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFC9A84C) : AppColors.outline.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.labelMd.copyWith(
              color: selected ? const Color(0xFFC9A84C) : AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
            filled: true,
            fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC9A84C), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildYearsExperience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Years of Experience',
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const Spacer(),
            Text('$_yearsExp',
                style: AppText.titleMd.copyWith(color: const Color(0xFFC9A84C))),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFC9A84C),
            inactiveTrackColor: AppColors.surfaceContainer,
            thumbColor: const Color(0xFFC9A84C),
            overlayColor: const Color(0xFFC9A84C).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: _yearsExp.toDouble(),
            min: 0,
            max: 30,
            divisions: 30,
            onChanged: (v) => setState(() => _yearsExp = v.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecializations() {
    const specs = [
      'Weight Loss', 'Muscle Gain', 'Strength',
      'Cardio', 'Nutrition', 'Flexibility',
      'Rehabilitation', 'Sports Performance',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Specializations',
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: specs.map((s) => _buildChip(s, _specializations.contains(s), () {
            setState(() {
              if (_specializations.contains(s)) {
                _specializations.remove(s);
              } else {
                _specializations.add(s);
              }
            });
          })).toList(),
        ),
      ],
    );
  }

  Widget _buildCertifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Certifications',
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...List.generate(_certifications.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_certifications[i],
                      style: AppText.bodyMd.copyWith(color: AppColors.onSurface)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _certifications.removeAt(i)),
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.error, size: 18),
              ),
            ],
          ),
        )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _certCtrl,
                style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Add certification',
                  hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
                  filled: true,
                  fillColor: AppColors.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addCertification,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A84C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.black, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguages() {
    const langs = ['Arabic', 'English', 'French'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Languages',
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: langs.map((l) => _buildChip(l, _languages.contains(l), () {
            setState(() {
              if (_languages.contains(l)) {
                _languages.remove(l);
              } else {
                _languages.add(l);
              }
            });
          })).toList(),
        ),
      ],
    );
  }

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Short Bio',
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text('*Required',
                style: AppText.labelSm.copyWith(color: const Color(0xFFC9A84C))),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioCtrl,
          maxLines: 4,
          maxLength: 500,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
          validator: (v) {
            if (v?.trim().isEmpty ?? true) return 'Bio is required';
            if (v!.trim().length > 500) return 'Max 500 characters';
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Describe your coaching approach and experience...',
            hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
            filled: true,
            fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC9A84C), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxClientsSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Max Clients',
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const Spacer(),
            Text('${_maxClients.round()}',
                style: AppText.titleMd.copyWith(color: const Color(0xFFC9A84C))),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFC9A84C),
            inactiveTrackColor: AppColors.surfaceContainer,
            thumbColor: const Color(0xFFC9A84C),
            overlayColor: const Color(0xFFC9A84C).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: _maxClients,
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (v) => setState(() => _maxClients = v),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFC9A84C).withValues(alpha: 0.15)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFFC9A84C)
                : AppColors.outline.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(Icons.check_rounded,
                  color: Color(0xFFC9A84C), size: 14),
            if (selected) const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: AppText.labelMd.copyWith(
                color: selected
                    ? const Color(0xFFC9A84C)
                    : AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
