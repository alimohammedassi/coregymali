import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachSetupState {
  // Personal
  String? profileImagePath;
  String displayName;
  String gender; // 'male' | 'female'
  String phoneNumber;
  String city;

  // Professional
  int yearsExperience;
  List<String> specializations;
  List<String> certifications;
  List<String> languages;
  String bio;

  // Pricing
  double priceMonthly;
  double pricePremium;
  int maxClients;

  // Optional
  String? introVideoUrl;

  bool isLoading;
  String? error;

  CoachSetupState({
    this.profileImagePath,
    this.displayName = '',
    this.gender = 'male',
    this.phoneNumber = '',
    this.city = '',
    this.yearsExperience = 1,
    this.specializations = const [],
    this.certifications = const [],
    this.languages = const [],
    this.bio = '',
    this.priceMonthly = 0,
    this.pricePremium = 0,
    this.maxClients = 10,
    this.introVideoUrl,
    this.isLoading = false,
    this.error,
  });

  CoachSetupState copyWith({
    String? profileImagePath,
    String? displayName,
    String? gender,
    String? phoneNumber,
    String? city,
    int? yearsExperience,
    List<String>? specializations,
    List<String>? certifications,
    List<String>? languages,
    String? bio,
    double? priceMonthly,
    double? pricePremium,
    int? maxClients,
    String? introVideoUrl,
    bool? isLoading,
    String? error,
  }) {
    return CoachSetupState(
      profileImagePath: profileImagePath ?? this.profileImagePath,
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      city: city ?? this.city,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      specializations: specializations ?? this.specializations,
      certifications: certifications ?? this.certifications,
      languages: languages ?? this.languages,
      bio: bio ?? this.bio,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      pricePremium: pricePremium ?? this.pricePremium,
      maxClients: maxClients ?? this.maxClients,
      introVideoUrl: introVideoUrl ?? this.introVideoUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CoachSetupNotifier extends ChangeNotifier {
  CoachSetupState _state = CoachSetupState();

  CoachSetupState get state => _state;

  void updateProfileImage(String? path) {
    _state = _state.copyWith(profileImagePath: path);
    notifyListeners();
  }

  void updateDisplayName(String v) {
    _state = _state.copyWith(displayName: v);
    notifyListeners();
  }

  void updateGender(String v) {
    _state = _state.copyWith(gender: v);
    notifyListeners();
  }

  void updatePhoneNumber(String v) {
    _state = _state.copyWith(phoneNumber: v);
    notifyListeners();
  }

  void updateCity(String v) {
    _state = _state.copyWith(city: v);
    notifyListeners();
  }

  void updateYearsExperience(int v) {
    _state = _state.copyWith(yearsExperience: v);
    notifyListeners();
  }

  void toggleSpecialization(String spec) {
    final specs = List<String>.from(_state.specializations);
    if (specs.contains(spec)) {
      specs.remove(spec);
    } else {
      specs.add(spec);
    }
    _state = _state.copyWith(specializations: specs);
    notifyListeners();
  }

  void addCertification(String cert) {
    if (cert.trim().isEmpty) return;
    final certs = List<String>.from(_state.certifications);
    certs.add(cert.trim());
    _state = _state.copyWith(certifications: certs);
    notifyListeners();
  }

  void removeCertification(int index) {
    final certs = List<String>.from(_state.certifications);
    if (index < certs.length) {
      certs.removeAt(index);
      _state = _state.copyWith(certifications: certs);
      notifyListeners();
    }
  }

  void toggleLanguage(String lang) {
    final langs = List<String>.from(_state.languages);
    if (langs.contains(lang)) {
      langs.remove(lang);
    } else {
      langs.add(lang);
    }
    _state = _state.copyWith(languages: langs);
    notifyListeners();
  }

  void updateBio(String v) {
    _state = _state.copyWith(bio: v);
    notifyListeners();
  }

  void updatePriceMonthly(double v) {
    _state = _state.copyWith(priceMonthly: v);
    notifyListeners();
  }

  void updatePricePremium(double v) {
    _state = _state.copyWith(pricePremium: v);
    notifyListeners();
  }

  void updateMaxClients(int v) {
    _state = _state.copyWith(maxClients: v);
    notifyListeners();
  }

  void updateIntroVideoUrl(String? v) {
    _state = _state.copyWith(introVideoUrl: v?.trim());
    notifyListeners();
  }

  String? validate() {
    if (_state.displayName.trim().isEmpty) return 'Display name is required';
    if (_state.phoneNumber.trim().isEmpty) return 'Phone number is required';
    if (_state.city.trim().isEmpty) return 'City is required';
    if (_state.yearsExperience < 0) return 'Years of experience is required';
    if (_state.specializations.isEmpty) return 'Select at least one specialization';
    if (_state.languages.isEmpty) return 'Select at least one language';
    if (_state.bio.trim().isEmpty) return 'Bio is required';
    if (_state.bio.trim().length > 500) return 'Bio must be 500 characters or less';
    if (_state.priceMonthly <= 0) return 'Standard plan price is required';
    return null;
  }

  Future<String?> submit() async {
    final validationError = validate();
    if (validationError != null) {
      _state = _state.copyWith(error: validationError);
      notifyListeners();
      return validationError;
    }

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _state = _state.copyWith(isLoading: false, error: 'Not authenticated');
        notifyListeners();
        return 'Not authenticated';
      }

      String? avatarUrl;

      // Upload profile photo if selected
      if (_state.profileImagePath != null && _state.profileImagePath!.isNotEmpty) {
        final file = File(_state.profileImagePath!);
        final bytes = await file.readAsBytes();
        final path = '$userId/avatar.jpg';
        await supabase.storage.from('coach-media').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
        final publicUrl = supabase.storage.from('coach-media').getPublicUrl(path);
        // add query parameter to bypass cache
        avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Insert coach_onboarding
      await supabase.from('coach_onboarding').insert({
        'user_id': userId,
        'display_name': _state.displayName.trim(),
        'years_experience': _state.yearsExperience,
        'certifications': _state.certifications,
        'specialization': _state.specializations,
        'bio': _state.bio.trim(),
        'price_monthly': _state.priceMonthly,
        'price_premium': _state.pricePremium,
        'languages': _state.languages,
        'max_clients': _state.maxClients,
        'profile_image_url': avatarUrl,
        'intro_video_url': _state.introVideoUrl?.trim(),
        'phone_number': _state.phoneNumber.trim(),
        'city': _state.city.trim(),
        'gender': _state.gender,
        'is_completed': true,
      });

      // Insert coaches
      await supabase.from('coaches').insert({
        'user_id': userId,
        'bio': _state.bio.trim(),
        'price_monthly': _state.priceMonthly,
        'specialization': _state.specializations,
        'is_active': true,
      });

      // Update profiles role to coach
      await supabase.from('profiles').update({'role': 'coach'}).eq('id', userId);

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return null;
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
      notifyListeners();
      return e.toString();
    }
  }
}
