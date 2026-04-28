import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../widgets/premium_glass_bg.dart';
import '../providers/coach_profile_provider.dart';

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
  List<String> _newCertificatePaths = [];
  List<String> _newTransformationPaths = [];

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

  void _addCertification() {
    if (_certCtrl.text.trim().isEmpty) return;
    setState(() {
      _certifications.add(_certCtrl.text.trim());
      _certCtrl.clear();
    });
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
          backgroundColor: Colors.green,
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
          child: CircularProgressIndicator(color: Color(0xFFC9A84C)),
        ),
      );
    }

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
                      _buildPhotoPicker(notifier.profile?.avatarUrl),
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
                      _buildCertificateFiles(),
                      const SizedBox(height: 16),
                      _buildTransformationImages(),
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
                        hint: 'Optional',
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
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: notifier.isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC9A84C),
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
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.onSurface, size: 20),
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
                      color: const Color(0xFFC9A84C),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Update your public coach profile',
                    style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
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

  Widget _buildPhotoPicker(String? existingUrl) {
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
                  : (existingUrl != null ? NetworkImage(existingUrl) : null) as ImageProvider?,
              child: _selectedImagePath == null && existingUrl == null
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
            hintText: 'Describe your coaching approach...',
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

  Widget _buildCertificateFiles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('CERTIFICATE FILES (PDF/IMAGES)'),
        const SizedBox(height: 12),
        ..._existingCertificateFiles.map((url) => _buildMediaItem(url, isUrl: true, onRemove: () {
          setState(() => _existingCertificateFiles.remove(url));
        })),
        ..._newCertificatePaths.map((path) => _buildMediaItem(path, isUrl: false, onRemove: () {
          setState(() => _newCertificatePaths.remove(path));
        })),
        const SizedBox(height: 8),
        _buildAddMediaButton('Add Certificates', _pickCertificates, Icons.upload_file_rounded),
      ],
    );
  }

  Widget _buildTransformationImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('CLIENT TRANSFORMATIONS'),
        const SizedBox(height: 12),
        ..._existingTransformationImages.map((url) => _buildMediaItem(url, isUrl: true, onRemove: () {
          setState(() => _existingTransformationImages.remove(url));
        })),
        ..._newTransformationPaths.map((path) => _buildMediaItem(path, isUrl: false, onRemove: () {
          setState(() => _newTransformationPaths.remove(path));
        })),
        const SizedBox(height: 8),
        _buildAddMediaButton('Add Transformation Images', _pickTransformations, Icons.add_photo_alternate_rounded),
      ],
    );
  }

  Widget _buildMediaItem(String source, {required bool isUrl, required VoidCallback onRemove}) {
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
            source.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            color: const Color(0xFFC9A84C),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isUrl ? source.split('/').last.split('?').first : source.split(Platform.pathSeparator).last,
              style: AppText.bodySm.copyWith(color: AppColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMediaButton(String label, VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC9A84C).withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFC9A84C).withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFC9A84C), size: 20),
            const SizedBox(width: 8),
            Text(label, style: AppText.labelLg.copyWith(color: const Color(0xFFC9A84C))),
          ],
        ),
      ),
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
