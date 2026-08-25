import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../providers/coach_profile_provider.dart';
import '../widgets/coach_profile_form_widgets.dart';

class CoachEditProfileScreen extends StatefulWidget {
  const CoachEditProfileScreen({super.key});

  @override
  State<CoachEditProfileScreen> createState() => _CoachEditProfileScreenState();
}

class _CoachEditProfileScreenState extends State<CoachEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  String? _selectedImagePath;
  String _gender = 'male';
  int _yearsExp = 1;
  List<String> _specializations = [];
  List<String> _certifications = [];
  List<String> _languages = [];
  double _maxClients = 10;
  bool _isLoaded = false;

  List<String> _existingCertificateFiles = [];
  List<String> _existingTransformationImages = [];
  final List<String> _newCertificatePaths = [];
  final List<String> _newTransformationPaths = [];

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
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    final notifier = context.read<CoachProfileNotifier>();
    await notifier.fetch();
    if (!mounted) return;

    final profile = notifier.profile;
    if (profile != null) {
      setState(() {
        _displayNameCtrl.text = profile.displayName;
        _phoneCtrl.text = profile.phoneNumber;
        _cityCtrl.text = profile.city;
        _bioCtrl.text = profile.bio;
        _priceCtrl.text = profile.priceMonthly > 0 ? profile.priceMonthly.toString() : '';
        _premiumCtrl.text = profile.pricePremium > 0 ? profile.pricePremium.toString() : '';
        _videoCtrl.text = profile.introVideoUrl ?? '';
        _gender = profile.gender;
        _yearsExp = profile.yearsExperience;
        _specializations = List.from(profile.specializations);
        _certifications = List.from(profile.certifications);
        _languages = List.from(profile.languages);
        _maxClients = profile.maxClients.toDouble();
        _existingCertificateFiles = List.from(profile.certificateFiles);
        _existingTransformationImages = List.from(profile.transformationImages);
        _selectedImagePath = null; // Will show existing avatar from provider
        _isLoaded = true;
      });
    } else {
      setState(() => _isLoaded = true);
    }
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked != null) {
      setState(() => _selectedImagePath = picked.path);
    }
  }

  Future<void> _pickCertificates() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _newCertificatePaths.addAll(result.paths.whereType<String>());
      });
    }
  }

  Future<void> _pickTransformations() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(maxWidth: 1024, maxHeight: 1024);
    if (picked.isNotEmpty) {
      setState(() {
        _newTransformationPaths.addAll(picked.map((e) => e.path));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = context.read<CoachProfileNotifier>();

    final profile = CoachProfileData(
      displayName: _displayNameCtrl.text.trim(),
      avatarUrl: notifier.profile?.avatarUrl,
      gender: _gender,
      phoneNumber: _phoneCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      yearsExperience: _yearsExp,
      specializations: _specializations,
      certifications: _certifications,
      languages: _languages,
      bio: _bioCtrl.text.trim(),
      priceMonthly: double.tryParse(_priceCtrl.text) ?? 0,
      pricePremium: double.tryParse(_premiumCtrl.text) ?? 0,
      maxClients: _maxClients.round(),
      introVideoUrl: _videoCtrl.text.trim().isEmpty ? null : _videoCtrl.text.trim(),
      certificateFiles: _existingCertificateFiles,
      transformationImages: _existingTransformationImages,
    );

    final err = await notifier.save(
      profile,
      newAvatarPath: _selectedImagePath,
      newCertificatePaths: _newCertificatePaths,
      newTransformationPaths: _newTransformationPaths,
    );
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: AppColors.greenAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CoachProfileNotifier>();

    if (!_isLoaded || notifier.isLoading && notifier.profile == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLowest,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.tertiary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildAppBar()),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const CoachFormSectionTitle('PERSONAL INFO'),
                    const SizedBox(height: 12),
                    CoachPhotoPicker(
                      localPath: _selectedImagePath,
                      networkUrl: notifier.profile?.avatarUrl,
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
                        'Specializations', _specializationOptions, _specializations),
                    const SizedBox(height: 16),
                    CoachCertificationsEditor(
                      certifications: _certifications,
                      addController: _certCtrl,
                      onAdd: () {
                        if (_certCtrl.text.trim().isEmpty) return;
                        setState(() {
                          _certifications.add(_certCtrl.text.trim());
                          _certCtrl.clear();
                        });
                      },
                      onRemove: (i) =>
                          setState(() => _certifications.removeAt(i)),
                    ),
                    const SizedBox(height: 16),
                    _buildMediaSection(
                      title: 'CERTIFICATE FILES (PDF/IMAGES)',
                      existingUrls: _existingCertificateFiles,
                      onRemoveExisting: (url) =>
                          setState(() => _existingCertificateFiles.remove(url)),
                      newPaths: _newCertificatePaths,
                      onRemoveNew: (path) =>
                          setState(() => _newCertificatePaths.remove(path)),
                      addLabel: 'Add Certificates',
                      onAdd: _pickCertificates,
                      addIcon: Icons.upload_file_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildMediaSection(
                      title: 'CLIENT TRANSFORMATIONS',
                      existingUrls: _existingTransformationImages,
                      onRemoveExisting: (url) => setState(
                          () => _existingTransformationImages.remove(url)),
                      newPaths: _newTransformationPaths,
                      onRemoveNew: (path) =>
                          setState(() => _newTransformationPaths.remove(path)),
                      addLabel: 'Add Transformation Images',
                      onAdd: _pickTransformations,
                      addIcon: Icons.add_photo_alternate_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildChipGroup('Languages', _languageOptions, _languages),
                    const SizedBox(height: 16),
                    CoachBioField(
                      controller: _bioCtrl,
                      hint: 'Describe your coaching approach...',
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
                      hint: 'Optional',
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
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: notifier.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tertiary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: notifier.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'Save Changes',
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.onSurface, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EDIT COACH PROFILE',
                  style: AppText.labelLg.copyWith(
                    color: AppColors.tertiary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Update your public coach profile',
                  style:
                      AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildMediaSection({
    required String title,
    required List<String> existingUrls,
    required ValueChanged<String> onRemoveExisting,
    required List<String> newPaths,
    required ValueChanged<String> onRemoveNew,
    required String addLabel,
    required VoidCallback onAdd,
    required IconData addIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoachFormSectionTitle(title),
        const SizedBox(height: 12),
        ...existingUrls.map((url) => _mediaItem(url,
            isUrl: true, onRemove: () => onRemoveExisting(url))),
        ...newPaths.map((path) => _mediaItem(path,
            isUrl: false, onRemove: () => onRemoveNew(path))),
        const SizedBox(height: 8),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.tertiary.withValues(alpha: 0.5), width: 1),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.tertiary.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(addIcon, color: AppColors.tertiary, size: 20),
                const SizedBox(width: 8),
                Text(addLabel,
                    style:
                        AppText.labelLg.copyWith(color: AppColors.tertiary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mediaItem(String source,
      {required bool isUrl, required VoidCallback onRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            source.toLowerCase().endsWith('.pdf')
                ? Icons.picture_as_pdf_rounded
                : Icons.image_rounded,
            color: AppColors.tertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isUrl
                  ? source.split('/').last.split('?').first
                  : source.split(Platform.pathSeparator).last,
              style: AppText.bodySm.copyWith(color: AppColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }
}
