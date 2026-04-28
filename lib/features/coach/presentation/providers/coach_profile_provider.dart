import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProfileData {
  final String displayName;
  final String? avatarUrl;
  final String gender;
  final String phoneNumber;
  final String city;
  final int yearsExperience;
  final List<String> specializations;
  final List<String> certifications;
  final List<String> languages;
  final String bio;
  final double priceMonthly;
  final double pricePremium;
  final int maxClients;
  final String? introVideoUrl;
  final List<String> certificateFiles;
  final List<String> transformationImages;

  CoachProfileData({
    required this.displayName,
    this.avatarUrl,
    required this.gender,
    required this.phoneNumber,
    required this.city,
    required this.yearsExperience,
    required this.specializations,
    required this.certifications,
    required this.languages,
    required this.bio,
    required this.priceMonthly,
    required this.pricePremium,
    required this.maxClients,
    this.introVideoUrl,
    this.certificateFiles = const [],
    this.transformationImages = const [],
  });
}

class CoachProfileNotifier extends ChangeNotifier {
  CoachProfileData? _profile;
  bool _isLoading = false;
  String? _error;

  CoachProfileData? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  Future<void> fetch() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final row = await supabase
          .from('coach_onboarding')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        _profile = null;
      } else {
        _profile = CoachProfileData(
          displayName: row['display_name'] ?? '',
          avatarUrl: row['profile_image_url'],
          gender: row['gender'] ?? 'male',
          phoneNumber: row['phone_number'] ?? '',
          city: row['city'] ?? '',
          yearsExperience: row['years_experience'] ?? 1,
          specializations: List<String>.from(row['specialization'] ?? []),
          certifications: List<String>.from(row['certifications'] ?? []),
          languages: List<String>.from(row['languages'] ?? []),
          bio: row['bio'] ?? '',
          priceMonthly: (row['price_monthly'] ?? 0).toDouble(),
          pricePremium: (row['price_premium'] ?? 0).toDouble(),
          maxClients: row['max_clients'] ?? 10,
          introVideoUrl: row['intro_video_url'],
          certificateFiles: List<String>.from(row['certificate_files'] ?? []),
          transformationImages: List<String>.from(row['transformation_images'] ?? []),
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> save(
    CoachProfileData data, {
    String? newAvatarPath,
    List<String> newCertificatePaths = const [],
    List<String> newTransformationPaths = const [],
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _error = 'Not authenticated';
        _isLoading = false;
        notifyListeners();
        return _error;
      }

      String? avatarUrl = data.avatarUrl;

      // Upload new avatar if changed
      if (newAvatarPath != null && newAvatarPath.isNotEmpty) {
        final file = File(newAvatarPath);
        final bytes = await file.readAsBytes();
        final path = '$userId/avatar.jpg';
        await supabase.storage.from('coach-media').uploadBinary(
          path, 
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
        final publicUrl = supabase.storage.from('coach-media').getPublicUrl(path);
        avatarUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Upload new certificates
      List<String> finalCertFiles = List.from(data.certificateFiles);
      for (final path in newCertificatePaths) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.split(Platform.pathSeparator).last}';
        final storagePath = '$userId/certs/$fileName';
        await supabase.storage.from('coach-media').uploadBinary(storagePath, bytes);
        final publicUrl = supabase.storage.from('coach-media').getPublicUrl(storagePath);
        finalCertFiles.add(publicUrl);
      }

      // Upload new transformations
      List<String> finalTransImages = List.from(data.transformationImages);
      for (final path in newTransformationPaths) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.split(Platform.pathSeparator).last}';
        final storagePath = '$userId/transformations/$fileName';
        await supabase.storage.from('coach-media').uploadBinary(storagePath, bytes);
        final publicUrl = supabase.storage.from('coach-media').getPublicUrl(storagePath);
        finalTransImages.add(publicUrl);
      }

      // Update coach_onboarding
      await supabase.from('coach_onboarding').update({
        'display_name': data.displayName,
        'years_experience': data.yearsExperience,
        'certifications': data.certifications,
        'specialization': data.specializations,
        'bio': data.bio,
        'price_monthly': data.priceMonthly,
        'price_premium': data.pricePremium,
        'languages': data.languages,
        'max_clients': data.maxClients,
        'profile_image_url': avatarUrl,
        'intro_video_url': data.introVideoUrl,
        'phone_number': data.phoneNumber,
        'city': data.city,
        'gender': data.gender,
        'certificate_files': finalCertFiles,
        'transformation_images': finalTransImages,
      }).eq('user_id', userId);

      // Update coaches
      await supabase.from('coaches').update({
        'bio': data.bio,
        'price_monthly': data.priceMonthly,
        'specialization': data.specializations,
      }).eq('user_id', userId);

      _profile = data;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return _error;
    }
  }

  void clear() {
    _profile = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
