import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_text.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/review_entity.dart';
import '../providers/coach_providers.dart';
import '../providers/stripe_provider.dart';
import '../providers/subscription_providers.dart';
import '../widgets/coach_shared.dart';
import '../../domain/entities/coach_content_entity.dart';
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
  final List<ReviewEntity> _reviews = [];
  bool _reviewsLoading = false;

  List<String> _galleryImages = [];
  List<CoachContentEntity> _pdfs = [];
  bool _mediaLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SelectedCoachNotifier>().fetchCoach(widget.coachId);
      if (!mounted) return;
      final c = context.read<SelectedCoachNotifier>().coach;
      if (c != null) _fetchMedia(c);
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
      
      final pdfsRes = await supabase.from('coach_content')
          .select()
          .eq('coach_id', coach.id)
          .eq('type', 'pdf')
          .eq('is_public', true)
          .order('created_at', ascending: false);
          
      _pdfs = (pdfsRes as List).map((e) => CoachContentEntity.fromJson(e)).toList();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _mediaLoading = false;
      });
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
              ? const Center(
                  child: CircularProgressIndicator(
                      color: kCoachGold, strokeWidth: 2))
              : coachN.error != null
                  ? CoachErrorState(
                      message: coachN.error!,
                      onRetry: () =>
                          coachN.fetchCoach(widget.coachId),
                    )
                  : coach == null
                      ? const Center(
                          child: Text('Coach not found',
                              style: TextStyle(color: Colors.white54)))
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
        if (!_mediaLoading && _galleryImages.isNotEmpty) _buildGallerySection(),
        if (!_mediaLoading && _pdfs.isNotEmpty) _buildPdfSection(),
        _buildSpecSection(coach),
        _buildReviewsSection(),
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

  Widget _buildPdfSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WORKOUT PLANS & GUIDES', style: AppText.labelSm.copyWith(color: kCoachMuted, letterSpacing: 2)),
            const SizedBox(height: 10),
            ..._pdfs.map((pdf) {
              final sizeStr = pdf.fileSizeKb != null ? '${pdf.fileSizeKb} KB' : '';
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pdf.title, style: AppText.labelMd.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (sizeStr.isNotEmpty) const SizedBox(height: 4),
                          if (sizeStr.isNotEmpty) Text(sizeStr, style: AppText.bodySm.copyWith(color: kCoachMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCoachGold.withOpacity(0.15),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => launchUrl(Uri.parse(pdf.fileUrl), mode: LaunchMode.externalApplication),
                      child: Text('View', style: AppText.labelMd.copyWith(color: kCoachGold)),
                    ),
                  ],
                ),
              );
            }),
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
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
                  colors: [kCoachGold.withOpacity(0.15), kCoachBg],
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
                        AppText.headlineMd.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  CoachStarRating(rating: coach.rating),
                  if (isSubscribed) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: kCoachGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: kCoachGold.withOpacity(0.5)),
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

  Widget _buildReviewsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REVIEWS',
                style: AppText.labelSm
                    .copyWith(color: kCoachMuted, letterSpacing: 2)),
            const SizedBox(height: 10),
            if (_reviewsLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(
                        color: kCoachGold, strokeWidth: 2)),
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

  // ── Sticky bottom bar ────────────────────────────────────────────────────

  Widget _buildStickyBar(CoachEntity coach, bool isSubscribed) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
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
          const SizedBox(width: 20),
          Expanded(
            child: Consumer<StripePaymentNotifier>(
              builder: (ctx, stripeN, _) => GestureDetector(
                onTap: isSubscribed || stripeN.isLoading
                    ? null
                    : () => stripeN.subscribe(coach.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: isSubscribed ? kCoachCard2 : kCoachGold,
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
                            isSubscribed
                                ? '✓ SUBSCRIBED'
                                : 'SUBSCRIBE — SECURE PAYMENT',
                            style: AppText.buttonPrimary.copyWith(
                              color: isSubscribed
                                  ? kCoachMuted
                                  : Colors.black,
                              fontSize: isSubscribed ? null : 11,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
