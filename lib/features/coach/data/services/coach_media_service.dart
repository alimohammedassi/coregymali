import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CoachMediaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Upload single image to coach-media/{uid}/gallery/{uuid}.jpg
  // Returns public URL
  Future<String> uploadGalleryImage(File imageFile) async {
    final uid = _supabase.auth.currentUser!.id;
    final ext = imageFile.path.split('.').last;
    final path = '$uid/gallery/${const Uuid().v4()}.$ext';
    await _supabase.storage
        .from('coach-media')
        .upload(path, imageFile,
            fileOptions: const FileOptions(upsert: false));
    return _supabase.storage.from('coach-media').getPublicUrl(path);
  }

  // Upload PDF to coach-pdfs/{uid}/{uuid}.pdf
  // Returns public URL
  Future<String> uploadPdf(File pdfFile, String title) async {
    final uid = _supabase.auth.currentUser!.id;
    final path = '$uid/${const Uuid().v4()}.pdf';
    final bytes = await pdfFile.readAsBytes();
    await _supabase.storage
        .from('coach-pdfs')
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ));
    final url = _supabase.storage.from('coach-pdfs').getPublicUrl(path);

    // Also save to coach_content table
    final coachRow = await _supabase
        .from('coaches')
        .select('id')
        .eq('user_id', uid)
        .single();

    await _supabase.from('coach_content').insert({
      'coach_id': coachRow['id'],
      'title': title,
      'type': 'pdf',
      'file_url': url,
      'is_public': true,
      'file_size_kb': bytes.length ~/ 1024,
    });
    return url;
  }

  // Delete file from storage by its public URL
  Future<void> deleteFile(String bucket, String publicUrl) async {
    final uri = Uri.parse(publicUrl);
    final pathSegments = uri.pathSegments;
    // Extract path after /object/public/{bucket}/
    final bucketIndex = pathSegments.indexOf(bucket);
    if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      await _supabase.storage.from(bucket).remove([filePath]);
    }
  }
}
