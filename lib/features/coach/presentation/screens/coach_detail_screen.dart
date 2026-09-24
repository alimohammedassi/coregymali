import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../../data/repositories/review_repository.dart';
import '../providers/coach_providers.dart';
import '../providers/stripe_provider.dart';
import '../providers/subscription_providers.dart';
import '../widgets/coach_shared.dart';
import '../../domain/entities/coach_content_entity.dart';
import '../../../../chat/data/repositories/chat_repository.dart';
import '../../../../chat/presentation/providers/chat_providers.dart';
import '../../../../chat/presentation/screens/chat_room_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

class CoachDetailScreen extends StatefulWidget {
  final String coachId;
  const CoachDetailScreen({super.key, required this.coachId});

  @override
  State<CoachDetailScreen> createState() => _CoachDetailScreenState();
}

class _CoachDetailScreenState extends State<CoachDetailScreen> {
  List<ReviewEntity> _reviews = [];
  bool _reviewsLoading = true;
  String? _reviewsError;
  ReviewEntity? _myReview;
  bool _isSubmittingReview = false;

  List<String> _galleryImages = [];
  List<CoachContentEntity> _coachContents = [];
  bool _mediaLoading = true;
  String? _mediaError;
  final _reviewRepo = ReviewRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SelectedCoachNotifier>().fetchCoach(widget.coachId);
      if (!mounted) return;
      final c = context.read<SelectedCoachNotifier>().coach;
      if (c != null) {
        _fetchMedia(c);
        _fetchReviews(c);
      } else {
        if (mounted) setState(() => _reviewsLoading = false);
      }
      // Listen to Stripe payment state changes for snackbar feedback
      context.read<StripePaymentNotifier>().addListener(_onStripeStateChange);
    });
  }

  Future<void> _fetchMedia(CoachEntity coach) async {
    try {
      final supabase = Supabase.instance.client;
      final uid = coach.userId;

      final onb = await supabase.from('coach_onboarding').select('gallery_images').eq('user_id', uid).maybeSingle();
      if (onb != null && onb['gallery_images'] != null) {
        _galleryImages = List<String>.from(onb['gallery_images']);
      }

      // Fetch all public coach_content (certificates, pdfs, images, etc.)
      // New table `coach_content` holds certificates and other files; we show
      // every type so the client sees the coach's full profile when tapping
      // his card. Keep ordering stable: sort_order first, then newest.
      dynamic contentRes;
      try {
        contentRes = await supabase.from('coach_content')
            .select()
            .eq('coach_id', coach.id)
            .eq('is_public', true)
            .order('sort_order', ascending: true)
            .order('created_at', ascending: false);
      } catch (_) {
        // Fallback if sort_order column not yet migrated
        contentRes = await supabase.from('coach_content')
            .select()
            .eq('coach_id', coach.id)
            .eq('is_public', true)
            .order('created_at', ascending: false);
      }

      _coachContents = (contentRes as List).map((e) => CoachContentEntity.fromJson(e as Map<String, dynamic>)).toList();
      _mediaError = null;
    } catch (e) {
      // Visible, non-fatal: the profile still renders without media.
      _mediaError = e.toString();
    }
    if (mounted) {
      setState(() {
        _mediaLoading = false;
      });
    }
  }

  Future<void> _fetchReviews(CoachEntity coach) async {
    try {
      _reviews = await _reviewRepo.fetchReviews(coach.id);
      _reviewsError = null;
      // Also fetch my existing review for edit state
      try {
        _myReview = await _reviewRepo.fetchMyReview(coach.id);
      } catch (_) {
        _myReview = null;
      }
    } catch (e) {
      _reviewsError = e.toString();
    }
    if (mounted) setState(() => _reviewsLoading = false);
  }

  Future<void> _showReviewSheet(CoachEntity coach) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to review', style: AppText.bodyMd.copyWith(color: Colors.white)), backgroundColor: AppColors.error),
      );
      return;
    }
    // Prevent coach reviewing themselves
    if (coach.userId == uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can\'t review your own profile', style: AppText.bodyMd.copyWith(color: Colors.white)), backgroundColor: AppColors.error),
      );
      return;
    }

    int selectedRating = _myReview?.rating ?? 0;
    final commentCtrl = TextEditingController(text: _myReview?.comment ?? '');
    bool isSaving = false;

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(_myReview == null ? 'Rate this coach' : 'Edit your review',
                    style: AppText.headlineSm.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Tap the stars and share your experience. Your review appears on the coach card and profile.',
                    style: AppText.bodySm.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < selectedRating;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: filled ? kCoachGold : AppColors.outline,
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    selectedRating == 0 ? 'Select a rating' : '$selectedRating / 5',
                    style: AppText.labelMd.copyWith(color: selectedRating == 0 ? AppColors.textMuted : kCoachGold, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'What did you like? (optional)',
                    hintStyle: AppText.bodySm.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceContainerHigh,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kCoachGold, width: 1.2)),
                  ),
                  style: AppText.bodyMd.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kCoachGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isSaving || selectedRating == 0
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            try {
                              await _reviewRepo.submitReview(coachId: coach.id, rating: selectedRating, comment: commentCtrl.text);
                              if (ctx.mounted) Navigator.of(ctx).pop({'ok': true});
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString(), style: AppText.bodySm.copyWith(color: Colors.white)), backgroundColor: AppColors.error));
                              }
                            }
                          },
                    child: isSaving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text(_myReview == null ? 'Submit review' : 'Update review', style: AppText.buttonPrimary.copyWith(color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                    child: Text('Cancel', style: AppText.bodySm.copyWith(color: AppColors.textMuted)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    commentCtrl.dispose();
    if (result != null && result['ok'] == true && mounted) {
      final selectedNotifier = context.read<SelectedCoachNotifier>();
      CoachListNotifier? listNotifier;
      try {
        listNotifier = context.read<CoachListNotifier>();
      } catch (_) {}
      setState(() {
        _reviewsLoading = true;
        _isSubmittingReview = true;
      });
      await _fetchReviews(coach);
      // Refresh coach rating on card/profile: refetch selected coach
      try {
        await selectedNotifier.fetchCoach(coach.id);
      } catch (_) {}
      // Also refresh marketplace list rating if available
      if (listNotifier != null) {
        try {
          await listNotifier.fetchCoaches();
        } catch (_) {}
      }
      if (mounted) setState(() => _isSubmittingReview = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review saved ✓', style: AppText.bodyMd.copyWith(color: Colors.black)),
            backgroundColor: kCoachGold,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Safe removal in case initState didn't complete
    try {
      context.read<StripePaymentNotifier>().removeListener(_onStripeStateChange);
    } catch (_) {}
    super.dispose();
  }

  void _onStripeStateChange() {
    final stripeN = context.read<StripePaymentNotifier>();
    if (stripeN.state.status == StripePaymentStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.black),
              const SizedBox(width: 10),
              Text('Subscription activated!',
                  style: AppText.bodyMd.copyWith(color: Colors.black)),
            ],
          ),
          backgroundColor: kCoachGold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      stripeN.reset();
    } else if (stripeN.state.status == StripePaymentStatus.failure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stripeN.state.errorMessage ?? 'Payment failed. Please try again.',
            style: AppText.bodyMd.copyWith(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      stripeN.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SelectedCoachNotifier, ActiveSubscriptionNotifier>(
      builder: (ctx, coachN, subN, _) {
        final coach = coachN.coach;
        final isSubscribed = subN.subscription?.coachId == coach?.id;

        return Scaffold(
          backgroundColor: kCoachBg,
          body: coachN.isLoading
              ?  Center(
                  child: CircularProgressIndicator(
                      color: kCoachGold, strokeWidth: 2))
              : coachN.error != null
                  ? CoachErrorState(
                      message: coachN.error!,
                      onRetry: () =>
                          coachN.fetchCoach(widget.coachId),
                    )
                  : coach == null
                      ? Center(
                          child: Text('Coach not found',
                              style: AppText.bodyMd
                                  .copyWith(color: kCoachMuted)),
                        )
                      : _buildBody(coach, isSubscribed),
          bottomNavigationBar: coach != null
              ? _buildStickyBar(coach, isSubscribed)
              : null,
        );
      },
    );
  }

  Widget _buildBody(CoachEntity coach, bool isSubscribed) {
    return CustomScrollView(
      slivers: [
        _buildHeroAppBar(coach, isSubscribed),
        _buildBioSection(coach),
        if (_mediaError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                'Couldn\'t load media: $_mediaError',
                style: AppText.bodySm.copyWith(color: AppColors.error),
              ),
            ),
          ),
        if (!_mediaLoading && _galleryImages.isNotEmpty) _buildGallerySection(),
        if (!_mediaLoading && _coachContents.isNotEmpty) _buildCoachContentSection(),
        _buildSpecSection(coach),
        _buildReviewsSection(coach),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ── Media Sections ───────────────────────────────────────────────────────

  Widget _buildGallerySection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PHOTOS', style: AppText.labelSm.copyWith(color: kCoachMuted, letterSpacing: 2)),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _galleryImages.length,
                itemBuilder: (ctx, i) {
                  final url = _galleryImages[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
                        body: PhotoView(imageProvider: NetworkImage(url)),
                      )));
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: kCoachCard2,
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachContentSection() {
    // Group by type for readable headings: certificates/images together,
    // pdfs as guides, other files generically.
    final certs = _coachContents.where((c) => c.type.toLowerCase() == 'certificate' || c.type.toLowerCase() == 'certificates').toList();
    final images = _coachContents.where((c) => c.type.toLowerCase() == 'image' || c.type.toLowerCase() == 'images').toList();
    final pdfs = _coachContents.where((c) => c.type.toLowerCase() == 'pdf').toList();
    final others = _coachContents.where((c) {
      final t = c.type.toLowerCase();
      return t != 'pdf' && t != 'certificate' && t != 'certificates' && t != 'image' && t != 'images';
    }).toList();

    Widget fileCard(CoachContentEntity item, IconData icon, Color iconColor) {
      final sizeStr = item.fileSizeKb != null ? '${item.fileSizeKb} KB' : '';
      final isImage = item.type.toLowerCase() == 'certificate' ||
          item.type.toLowerCase() == 'image' ||
          item.type.toLowerCase() == 'images' ||
          item.fileUrl.toLowerCase().endsWith('.jpg') ||
          item.fileUrl.toLowerCase().endsWith('.jpeg') ||
          item.fileUrl.toLowerCase().endsWith('.png') ||
          item.fileUrl.toLowerCase().endsWith('.webp');
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCoachCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kCoachBorder),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: isImage
                  ? () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
                        body: PhotoView(imageProvider: NetworkImage(item.fileUrl)),
                      )));
                    }
                  : null,
              child: Container(
                width: isImage ? 56 : null,
                height: isImage ? 56 : null,
                padding: isImage ? EdgeInsets.zero : const EdgeInsets.all(12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isImage ? kCoachCard2 : iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  image: isImage
                      ? DecorationImage(image: NetworkImage(item.thumbnailUrl ?? item.fileUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: isImage ? null : Icon(icon, color: iconColor, size: 24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : 'Untitled',
                    style: AppText.labelMd.copyWith(color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null && item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.description!, style: AppText.bodySm.copyWith(color: kCoachMuted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (sizeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(sizeStr, style: AppText.bodySm.copyWith(color: kCoachMuted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kCoachGold.withValues(alpha: 0.15),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final url = item.fileUrl;
                final lower = url.toLowerCase();
                final isPdf = item.type.toLowerCase() == 'pdf' || lower.endsWith('.pdf');
                if (isPdf) {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else if (isImage) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
                    body: PhotoView(imageProvider: NetworkImage(url)),
                  )));
                } else {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              child: Text(isImage ? 'View' : 'Open', style: AppText.labelMd.copyWith(color: kCoachGold)),
            ),
          ],
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (certs.isNotEmpty || images.isNotEmpty) ...[
              Text('CERTIFICATES', style: AppText.labelSm.copyWith(color: kCoachMuted, letterSpacing: 2)),
              const SizedBox(height: 10),
              ...[...certs, ...images].map((c) => fileCard(c, Icons.verified_rounded, kCoachGold)),
              const SizedBox(height: 8),
            ],
            if (pdfs.isNotEmpty) ...[
              Text('WORKOUT PLANS & GUIDES', style: AppText.labelSm.copyWith(color: kCoachMuted, letterSpacing: 2)),
              const SizedBox(height: 10),
              ...pdfs.map((pdf) => fileCard(pdf, Icons.picture_as_pdf_rounded, Colors.redAccent)),
              if (others.isNotEmpty) const SizedBox(height: 8),
            ],
            if (others.isNotEmpty) ...[
              Text('FILES', style: AppText.labelSm.copyWith(color: kCoachMuted, letterSpacing: 2)),
              const SizedBox(height: 10),
              ...others.map((o) {
                final t = o.type.toLowerCase();
                IconData icon = Icons.insert_drive_file_rounded;
                Color col = kCoachMuted;
                if (t.contains('video')) { icon = Icons.videocam_rounded; col = Colors.deepPurpleAccent; }
                else if (t.contains('audio')) { icon = Icons.audio_file_rounded; col = Colors.teal; }
                return fileCard(o, icon, col);
              }),
            ],
            if (_coachContents.isNotEmpty && certs.isEmpty && images.isEmpty && pdfs.isEmpty && others.isEmpty) ...[
              Text('FILES', style: AppText.labelSm.copyWith(color: kCoachMuted, letterSpacing: 2)),
              const SizedBox(height: 10),
              ..._coachContents.map((c) => fileCard(c, Icons.insert_drive_file_rounded, kCoachMuted)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Hero ─────────────────────────────────────────────────────────────────

  Widget _buildHeroAppBar(CoachEntity coach, bool isSubscribed) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: kCoachBg,
      leading: Semantics(
        button: true,
        label: 'Back',
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kCoachBorder),
            ),
            child:  Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kCoachGold.withValues(alpha: 0.15), kCoachBg],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Hero(
                    tag: 'coach_avatar_${coach.id}',
                    child: CoachAvatar(
                        url: coach.profile?.avatarUrl, size: 90),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    coach.profile?.name ?? 'Coach',
                    style:
                        AppText.headlineMd.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  CoachStarRating(rating: coach.rating),
                  if (isSubscribed) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: kCoachGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: kCoachGold.withValues(alpha: 0.5)),
                      ),
                      child: Text('✓ ACTIVE SUBSCRIPTION',
                          style: AppText.labelMd
                              .copyWith(color: kCoachGold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bio ──────────────────────────────────────────────────────────────────

  Widget _buildBioSection(CoachEntity coach) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ABOUT',
                style: AppText.labelSm
                    .copyWith(color: kCoachMuted, letterSpacing: 2)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCoachCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCoachBorder),
              ),
              child: Text(coach.bio,
                  style: AppText.bodyMd.copyWith(height: 1.7)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Specializations ──────────────────────────────────────────────────────

  Widget _buildSpecSection(CoachEntity coach) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SPECIALIZATIONS',
                style: AppText.labelSm
                    .copyWith(color: kCoachMuted, letterSpacing: 2)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: coach.specialization
                  .map((s) => CoachSpecChip(label: s))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reviews ──────────────────────────────────────────────────────────────

  Widget _buildReviewsSection(CoachEntity coach) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('REVIEWS',
                    style: AppText.labelSm
                        .copyWith(color: kCoachMuted, letterSpacing: 2)),
                const Spacer(),
                // Client can add / edit his review — stars appear on card + profile
                TextButton.icon(
                  onPressed: _isSubmittingReview ? null : () => _showReviewSheet(coach),
                  icon: Icon(_myReview == null ? Icons.rate_review_outlined : Icons.edit_rounded, size: 14, color: kCoachGold),
                  label: Text(_myReview == null ? 'Write review' : 'Edit review',
                      style: AppText.labelMd.copyWith(color: kCoachGold, fontWeight: FontWeight.w800, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: kCoachGold.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
            if (_myReview != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCoachGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCoachGold.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    CoachStarRating(rating: _myReview!.rating.toDouble()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _myReview!.comment?.isNotEmpty == true ? _myReview!.comment! : 'Your rating: ${_myReview!.rating}/5',
                        style: AppText.bodySm.copyWith(color: AppColors.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_reviewsLoading)
               Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(
                        color: kCoachGold, strokeWidth: 2)),
              )
            else if (_reviewsError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kCoachCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 32),
                    const SizedBox(height: 10),
                    Text('Couldn\'t load reviews',
                        style: AppText.bodyMd
                            .copyWith(color: kCoachMuted)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        final coach = context.read<SelectedCoachNotifier>().coach;
                        if (coach == null) return;
                        setState(() => _reviewsLoading = true);
                        _fetchReviews(coach);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kCoachCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kCoachBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        color: kCoachSubtle, size: 36),
                    const SizedBox(height: 10),
                    Text('No reviews yet',
                        style: AppText.bodyMd
                            .copyWith(color: kCoachMuted)),
                  ],
                ),
              )
            else
              ..._reviews.map((r) => _ReviewCard(review: r)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelSubscription(CoachEntity coach) async {
    final activeN = context.read<ActiveSubscriptionNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel subscription?',
          style: AppText.titleMd.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Your coach workouts and nutrition plan will be hidden until you subscribe again. You can resubscribe anytime.',
          style: AppText.bodySm.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await activeN.cancelActiveSubscription();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription cancelled',
              style: AppText.bodyMd.copyWith(color: AppColors.textPrimary)),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      final msg = activeN.error ?? 'Couldn\'t cancel — check your connection';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: AppText.bodyMd.copyWith(color: Colors.white)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Sticky bottom bar ────────────────────────────────────────────────────

  Widget _buildStickyBar(CoachEntity coach, bool isSubscribed) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration:  BoxDecoration(
        color: kCoachCard,
        border: Border(top: BorderSide(color: kCoachBorder)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PRICE / MO',
                  style: AppText.labelSm
                      .copyWith(color: kCoachMuted, letterSpacing: 1.5)),
              Text('\$${coach.priceMonthly.toStringAsFixed(0)}',
                  style:
                      AppText.headlineSm.copyWith(color: kCoachGold)),
            ],
          ),
          const SizedBox(width: 12),
          if (isSubscribed)
            Semantics(
              button: true,
              label: 'Message coach',
              child: GestureDetector(
                onTap: () => _openChat(context, coach),
                child: Container(
                  width: 48,
                  height: 54,
                  decoration: BoxDecoration(
                    color: kCoachCard2,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:  Icon(Icons.chat_bubble_rounded,
                      color: kCoachGold, size: 22),
                ),
              ),
            ),
          if (isSubscribed) const SizedBox(width: 12),
          Expanded(
            child: Consumer2<StripePaymentNotifier, ActiveSubscriptionNotifier>(
              builder: (ctx, stripeN, subN, _) {
                if (isSubscribed) {
                  // Cancel state — uses ActiveSubscriptionNotifier isLoading
                  final isCancelling = subN.isLoading;
                  return GestureDetector(
                    onTap: isCancelling ? null : () => _confirmCancelSubscription(coach),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: isCancelling
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: AppColors.error, strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close_rounded,
                                      color: AppColors.error, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CANCEL SUBSCRIPTION',
                                    style: AppText.buttonPrimary.copyWith(
                                      color: AppColors.error,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                }
                // Not subscribed — Stripe subscribe CTA
                return GestureDetector(
                  onTap: stripeN.isLoading ? null : () => stripeN.subscribe(coach.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 54,
                    decoration: BoxDecoration(
                      color: kCoachGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: stripeN.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2))
                          : Text(
                              'SUBSCRIBE — SECURE PAYMENT',
                              style: AppText.buttonPrimary.copyWith(
                                color: Colors.black,
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat(BuildContext context, CoachEntity coach) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final repo = ChatRepository(Supabase.instance.client);
    final conv = await repo.getOrCreateConversation(
      clientId: userId,
      coachId: coach.userId,
      subscriptionId: context.read<ActiveSubscriptionNotifier>().subscription?.id,
    );
    if (conv == null || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ChatNotifier(context.read<ChatRepoProvider>().repo, conv.id),
          child: ChatRoomScreen(conversation: conv),
        ),
      ),
    );
  }

  // _showSubscribeSheet is no longer needed — Stripe checkout is triggered directly
}



// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewEntity review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCoachCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCoachBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachStarRating(rating: review.rating.toDouble()),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: AppText.bodySm.copyWith(color: kCoachSubtle),
              ),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
                style: AppText.bodyMd.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}
