import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../providers/coach_setup_provider.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../fitness_home_pages.dart';
import '../widgets/coach_profile_form_widgets.dart';

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

  static const _specializationOptions = [
    'Weight Loss', 'Muscle Gain', 'Strength',
    'Cardio', 'Nutrition', 'Flexibility',
    'Rehabilitation', 'Sports Performance',
  ];

  static const _languageOptions = ['Arabic', 'English', 'French'];

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

    // Sync list selections onto the notifier state, guarding so an already-
    // present value isn't toggled back off.
    final current = notifier.state;
    for (final spec in _specializations) {
      if (!current.specializations.contains(spec)) {
        notifier.toggleSpecialization(spec);
      }
    }
    for (final lang in _languages) {
      if (!current.languages.contains(lang)) {
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SET UP YOUR COACH PROFILE',
                        style: AppText.labelLg.copyWith(
                          color: AppColors.tertiary,
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
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const CoachFormSectionTitle('PERSONAL INFO'),
                    const SizedBox(height: 12),
                    CoachPhotoPicker(
                      localPath: _selectedImagePath,
                      onPick: _pickImage,
                    ),
                    const SizedBox(height: 16),
                    CoachFormField(
                      controller: _displayNameCtrl,
                      label: 'Full Name / Display Name',
                      hint: 'e.g., Ahmed Hassan',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CoachGenderSelector(
                      value: _gender,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    CoachFormField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      hint: '+1 234 567 8900',
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CoachFormField(
                      controller: _cityCtrl,
                      label: 'City',
                      hint: 'e.g., Cairo',
                      validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    const CoachFormSectionTitle('PROFESSIONAL'),
                    const SizedBox(height: 12),
                    CoachSliderRow(
                      label: 'Years of Experience',
                      value: _yearsExp,
                      min: 0,
                      max: 30,
                      onChanged: (v) => setState(() => _yearsExp = v),
                    ),
                    const SizedBox(height: 16),
                    _buildChipGroup(
                      'Specializations',
                      _specializationOptions,
                      _specializations,
                    ),
                    const SizedBox(height: 16),
                    CoachCertificationsEditor(
                      certifications: _certifications,
                      addController: _certCtrl,
                      onAdd: _addCertification,
                      onRemove: (i) => setState(() => _certifications.removeAt(i)),
                    ),
                    const SizedBox(height: 16),
                    _buildChipGroup('Languages', _languageOptions, _languages),
                    const SizedBox(height: 16),
                    CoachBioField(
                      controller: _bioCtrl,
                      hint: 'Describe your coaching approach and experience...',
                    ),
                    const SizedBox(height: 24),
                    const CoachFormSectionTitle('PRICING'),
                    const SizedBox(height: 12),
                    CoachFormField(
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
                    CoachFormField(
                      controller: _premiumCtrl,
                      label: 'Premium Plan — Price per Month (USD)',
                      hint: 'Optional — leave empty for standard only',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    CoachSliderRow(
                      label: 'Max Clients',
                      value: _maxClients.round(),
                      min: 1,
                      max: 50,
                      onChanged: (v) => setState(() => _maxClients = v.toDouble()),
                    ),
                    const SizedBox(height: 24),
                    const CoachFormSectionTitle('OPTIONAL'),
                    const SizedBox(height: 12),
                    CoachFormField(
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
                          backgroundColor: AppColors.tertiary,
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
    );
  }

  Widget _buildChipGroup(
      String title, List<String> options, List<String> selectedValues) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map((s) => CoachSelectChip(
                    label: s,
                    selected: selectedValues.contains(s),
                    onTap: () {
                      setState(() {
                        if (selectedValues.contains(s)) {
                          selectedValues.remove(s);
                        } else {
                          selectedValues.add(s);
                        }
                      });
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}
