import 'dart:io';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../widgets/premium_glass_bg.dart';
import '../providers/coach_media_provider.dart';

class CoachMediaScreen extends StatefulWidget {
  const CoachMediaScreen({super.key});

  @override
  State<CoachMediaScreen> createState() => _CoachMediaScreenState();
}

class _CoachMediaScreenState extends State<CoachMediaScreen> {
  final _picker = ImagePicker();

  Future<void> _pickAndUploadImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      context.read<CoachMediaNotifier>().addGalleryImage(File(picked.path));
    }
  }

  void _confirmDeleteImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('Remove Image?', style: AppText.titleMd.copyWith(color: AppColors.onSurface)),
        content: Text('This image will no longer be visible on your profile.', style: AppText.bodySm.copyWith(color: AppColors.outline)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CoachMediaNotifier>().removeGalleryImage(url);
            },
            child: Text('Remove', style: AppText.bodySm.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPdf() async {
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      
      final titleCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text('PDF Details', style: AppText.titleMd.copyWith(color: AppColors.onSurface)),
          content: TextField(
            controller: titleCtrl,
            style: AppText.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'e.g. 4-Week Hypertrophy Plan',
              hintStyle: AppText.bodySm.copyWith(color: AppColors.outline),
              filled: true,
              fillColor: AppColors.surfaceLowest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC9A84C)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Upload', style: AppText.bodySm.copyWith(color: Colors.black)),
            ),
          ],
        ),
      );

      if (confirm == true && titleCtrl.text.trim().isNotEmpty) {
        context.read<CoachMediaNotifier>().addPdf(file, titleCtrl.text.trim());
      }
    }
  }

  void _confirmDeletePdf(String id, String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('Remove PDF?', style: AppText.titleMd.copyWith(color: AppColors.onSurface)),
        content: Text('This file will be permanently deleted.', style: AppText.bodySm.copyWith(color: AppColors.outline)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CoachMediaNotifier>().removePdf(id, url);
            },
            child: Text('Remove', style: AppText.bodySm.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CoachMediaNotifier>();

    return Scaffold(
      backgroundColor: AppColors.surfaceLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Media', style: AppText.titleLg.copyWith(color: AppColors.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PremiumGlassmorphismBg(
        child: state.isUploading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)))
            : CustomScrollView(
                slivers: [
                  if (state.error != null)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: AppColors.error.withOpacity(0.1),
                        child: Text(state.error!, style: AppText.bodySm.copyWith(color: AppColors.error)),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Profile Images', 'Shown to clients browsing your profile'),
                          const SizedBox(height: 16),
                          _buildGalleryCarousel(state.galleryImages),
                          const SizedBox(height: 40),
                          Row(
                            children: [
                              Expanded(child: _buildSectionHeader('Workout Plans & Guides', 'Visible to all users on your profile')),
                              IconButton(
                                onPressed: _pickAndUploadPdf,
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFC9A84C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.upload_file_rounded, color: Colors.black, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPdfsList(state.pdfs),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.titleMd.copyWith(color: AppColors.onSurface)),
        const SizedBox(height: 2),
        Text(subtitle, style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildGalleryCarousel(List<String> images) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length < 6 ? images.length + 1 : images.length,
        itemBuilder: (ctx, i) {
          if (i == images.length && images.length < 6) {
            return _buildAddImageCard();
          }
          return _buildImageCard(images[i]);
        },
      ),
    );
  }

  Widget _buildAddImageCard() {
    return GestureDetector(
      onTap: _pickAndUploadImage,
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFC9A84C), size: 32),
            const SizedBox(height: 8),
            Text('Add Photo', style: AppText.labelSm.copyWith(color: const Color(0xFFC9A84C))),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(String url) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: GestureDetector(
          onTap: () => _confirmDeleteImage(url),
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfsList(List pdfs) {
    if (pdfs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('No PDFs uploaded yet.', style: AppText.bodySm.copyWith(color: AppColors.outline)),
        ),
      );
    }
    
    return Column(
      children: pdfs.map((pdf) => _buildPdfRow(pdf)).toList(),
    );
  }

  Widget _buildPdfRow(dynamic pdf) {
    final sizeKb = pdf.fileSizeKb ?? 0;
    final sizeStr = sizeKb > 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '$sizeKb KB';
    final dateStr = DateFormat('MMM d, yyyy').format(pdf.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pdf.title, style: AppText.labelMd.copyWith(color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(sizeStr, style: AppText.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('•', style: AppText.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text(dateStr, style: AppText.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _confirmDeletePdf(pdf.id, pdf.fileUrl),
          ),
        ],
      ),
    );
  }
}
