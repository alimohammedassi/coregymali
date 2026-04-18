import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/coach_media_service.dart';
import '../../domain/entities/coach_content_entity.dart';

class CoachMediaNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CoachMediaService _mediaService = CoachMediaService();

  List<String> _galleryImages = [];
  List<CoachContentEntity> _pdfs = [];
  bool _isUploading = false;
  String? _error;

  List<String> get galleryImages => _galleryImages;
  List<CoachContentEntity> get pdfs => _pdfs;
  bool get isUploading => _isUploading;
  String? get error => _error;

  CoachMediaNotifier() {
    loadMedia();
  }

  Future<void> loadMedia() async {
    try {
      final uid = _supabase.auth.currentUser!.id;
      
      final onboardingRes = await _supabase
          .from('coach_onboarding')
          .select('gallery_images')
          .eq('user_id', uid)
          .maybeSingle();

      List<String> images = [];
      if (onboardingRes != null && onboardingRes['gallery_images'] != null) {
        images = List<String>.from(onboardingRes['gallery_images']);
      }

      final coachRow = await _supabase
          .from('coaches')
          .select('id')
          .eq('user_id', uid)
          .maybeSingle();

      List<CoachContentEntity> pdfList = [];
      if (coachRow != null) {
        final pdfsRes = await _supabase
            .from('coach_content')
            .select()
            .eq('coach_id', coachRow['id'])
            .eq('type', 'pdf')
            .order('created_at', ascending: false);
        
        pdfList = (pdfsRes as List).map((e) => CoachContentEntity.fromJson(e)).toList();
      }

      _galleryImages = images;
      _pdfs = pdfList;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addGalleryImage(File file) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final url = await _mediaService.uploadGalleryImage(file);
      final uid = _supabase.auth.currentUser!.id;
      
      _galleryImages.add(url);
      
      await _supabase
          .from('coach_onboarding')
          .update({'gallery_images': _galleryImages})
          .eq('user_id', uid);

      _isUploading = false;
      notifyListeners();
    } catch (e) {
      _isUploading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeGalleryImage(String url) async {
    try {
      await _mediaService.deleteFile('coach-media', url);
      final uid = _supabase.auth.currentUser!.id;
      
      _galleryImages.remove(url);
      
      await _supabase
          .from('coach_onboarding')
          .update({'gallery_images': _galleryImages})
          .eq('user_id', uid);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addPdf(File file, String title) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      await _mediaService.uploadPdf(file, title);
      await loadMedia();
      _isUploading = false;
      notifyListeners();
    } catch (e) {
      _isUploading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removePdf(String contentId, String fileUrl) async {
    try {
      await _mediaService.deleteFile('coach-pdfs', fileUrl);
      await _supabase.from('coach_content').delete().eq('id', contentId);
      
      _pdfs.removeWhere((pdf) => pdf.id == contentId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
