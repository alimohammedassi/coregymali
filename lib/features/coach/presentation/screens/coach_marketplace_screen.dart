import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../domain/entities/coach_entity.dart';
import '../providers/coach_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/stripe_provider.dart';
import '../../data/services/stripe_service.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../widgets/coach_shared.dart';
import '../../data/repositories/review_repository.dart';
import 'coach_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _kSpecializations = [
  'All',
  'weight loss',
  'muscle gain',
  'nutrition',
  'strength',
  'cardio',
  'flexibility',
];

/// user_id → gallery_images for the card banner. Filled with ONE batched
/// query per coach-list load instead of one query per card inside build
/// (N+1). CoachCard falls back to a per-coach lookup on cache miss and
/// fills the cache, so correctness never depends on the prefetch landing.
final Map<String, List<dynamic>> kCoachGalleryCache = <String, List<dynamic>>{};

class CoachMarketplaceScreen extends StatefulWidget {
  /// True when the marketplace is a root destination inside the home
  /// IndexedStack. In that mode there is nothing to pop, so the back
  /// affordance either hides or, if [onBackToHome] is provided, returns to
  /// the Home tab instead of popping the navigator.
  final bool embeddedInTabs;
  final VoidCallback? onBackToHome;
  const CoachMarketplaceScreen({
    super.key,
    this.embeddedInTabs = false,
    this.onBackToHome,
  });

  @override
  State<CoachMarketplaceScreen> createState() => _CoachMarketplaceScreenState();
}

class _CoachMarketplaceScreenState extends State<CoachMarketplaceScreen> {
  String _selectedSpec = 'All';
  RangeValues _priceRange = const RangeValues(0, 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    await context.read<CoachListNotifier>().fetchCoaches(
      specialization: _selectedSpec == 'All' ? null : _selectedSpec,
      maxPrice: _priceRange.end < 500 ? _priceRange.end : null,
    );
    await _prefetchGalleryBanners();
  }

  /// One query for the whole loaded coach list — CoachCard used to fire its
  /// own `coach_onboarding` lookup per card on every build.
  Future<void> _prefetchGalleryBanners() async {
    final coaches = context.read<CoachListNotifier>().coaches;
    if (coaches == null || coaches.isEmpty) return;
    final missing = coaches
        .map((c) => c.userId)
        .where((id) => !kCoachGalleryCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('coach_onboarding')
          .select('user_id, gallery_images')
          .inFilter('user_id', missing);
      for (final row in (rows as List)) {
        kCoachGalleryCache[row['user_id'] as String] =
            (row['gallery_images'] as List?) ?? const [];
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Left uncached — CoachCard falls back to its own lookup.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async => _fetch(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(),
              _buildFilters(),
              _buildPriceSlider(),
              _buildCoachList(),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!widget.embeddedInTabs || widget.onBackToHome != null)
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      onTap:
                          widget.onBackToHome ?? () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                if (!widget.embeddedInTabs || widget.onBackToHome != null)
                  const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find a coach',
                        style: AppText.headlineSm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'اختر مدربك',
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Coach count instead of a static, purposeless "Premium"
                // badge — a real, live piece of information in the same
                // slot.
                Consumer<CoachListNotifier>(
                  builder: (ctx, notifier, _) {
                    final count = notifier.coaches?.length;
                    if (count == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        '$count coaches',
                        style: AppText.labelMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Spec chips ───────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Specialization',
              style: AppText.labelSm.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _kSpecializations.length,
              itemBuilder: (ctx, i) {
                final spec = _kSpecializations[i];
                final active = spec == _selectedSpec;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: spec,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSpec = spec);
                        _fetch();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.accent
                              : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? AppColors.accent
                                : AppColors.borderSubtle,
                          ),
                        ),
                        child: Text(
                          spec[0].toUpperCase() + spec.substring(1),
                          style: AppText.labelMd.copyWith(
                            color: active
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Price slider ─────────────────────────────────────────────────────────

  Widget _buildPriceSlider() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Price / month',
                    style: AppText.labelSm.copyWith(color: AppColors.textMuted),
                  ),
                  Text(
                    _priceRange.end >= 500
                        ? '\$${_priceRange.start.toInt()}+'
                        : '\$${_priceRange.start.toInt()} – \$${_priceRange.end.toInt()}',
                    style: AppText.titleSm.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.surfaceContainerHigh,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.12),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: RangeSlider(
                  values: _priceRange,
                  min: 0,
                  max: 500,
                  divisions: 20,
                  onChanged: (v) => setState(() => _priceRange = v),
                  onChangeEnd: (_) => _fetch(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Coach list ───────────────────────────────────────────────────────────

  Widget _buildCoachList() {
    return Consumer<CoachListNotifier>(
      builder: (ctx, notifier, _) {
        if (notifier.isLoading) {
          return SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (notifier.error != null) {
          return SliverFillRemaining(
            child: CoachErrorState(message: notifier.error!, onRetry: _fetch),
          );
        }

        final coaches = notifier.coaches ?? [];
        if (coaches.isEmpty) {
          return const SliverFillRemaining(
            child: CoachEmptyState(
              message: 'No coaches found.\nTry different filters.',
              icon: Icons.search_off_rounded,
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Consumer<ActiveSubscriptionNotifier>(
                builder: (ctx, subNotifier, _) {
                  final coach = coaches[i];
                  final isSubscribed =
                      subNotifier.subscription?.coachId == coach.id;
                  return CoachCard(
                    coach: coach,
                    isSubscribed: isSubscribed,
                    isCancelling: isSubscribed && subNotifier.isLoading,
                    onTap: () => _navigateToDetail(coach),
                    onSubscribe: () => _showSubscribeSheet(coach),
                    onCancel: () => _confirmCancelFromMarketplace(ctx, coach, subNotifier),
                  );
                },
              ),
              childCount: coaches.length,
            ),
          ),
        );
      },
    );
  }

  void _navigateToDetail(CoachEntity coach) {
    // Instantiate concretely — no ProxyProvider needed since this is a
    // self-contained navigation scope and dependencies don't change.
    final activeSubNotifier = ActiveSubscriptionNotifier(
      SubscriptionRepositoryImpl(),
    )..fetchActiveSubscription();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) {
                final n = SelectedCoachNotifier(CoachRepositoryImpl());
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => n.fetchCoach(coach.id),
                );
                return n;
              },
            ),
            // Share the same instance so both the UI and StripePaymentNotifier
            // see subscription updates in real time.
            ChangeNotifierProvider.value(value: activeSubNotifier),
            ChangeNotifierProvider(
              create: (_) => StripePaymentNotifier(
                stripeService: StripeService(),
                subscriptionNotifier: activeSubNotifier,
              ),
            ),
          ],
          child: CoachDetailScreen(coachId: coach.id),
        ),
      ),
    );
  }

  Future<void> _confirmCancelFromMarketplace(
    BuildContext ctx, CoachEntity coach, ActiveSubscriptionNotifier subNotifier) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel subscription?',
            style: AppText.titleMd.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          'Your coach workouts and nutrition plan will be hidden until you subscribe again.',
          style: AppText.bodySm.copyWith(color: AppColors.textSecondary, height: 1.5),
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
    if (confirmed != true || !ctx.mounted) return;
    final ok = await subNotifier.cancelActiveSubscription();
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Subscription cancelled' : (subNotifier.error ?? 'Couldn\'t cancel — try again'),
          style: AppText.bodyMd.copyWith(
              color: ok ? AppColors.textPrimary : Colors.white),
        ),
        backgroundColor:
            ok ? AppColors.surfaceContainerHigh : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSubscribeSheet(CoachEntity coach) {
    final subscriptionNotifier = context.read<SubscriptionNotifier>();
    // Passed through so the sheet can refresh the "active subscription"
    // state after a successful subscribe — otherwise the card still says
    // Subscribe until the whole screen is rebuilt.
    final activeSubNotifier = context.read<ActiveSubscriptionNotifier>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionNotifier>.value(
            value: subscriptionNotifier,
          ),
          ChangeNotifierProvider<ActiveSubscriptionNotifier>.value(
            value: activeSubNotifier,
          ),
        ],
        child: _SubscribeBottomSheet(coach: coach),
      ),
    );
  }
}

// ── CoachCard widget ──────────────────────────────────────────────────────────

class CoachCard extends StatelessWidget {
  final CoachEntity coach;
  final bool isSubscribed;
  final bool isCancelling;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final VoidCallback? onCancel;

  const CoachCard({
    super.key,
    required this.coach,
    required this.isSubscribed,
    this.isCancelling = false,
    required this.onTap,
    required this.onSubscribe,
    this.onCancel,
  });

  Widget _initialsFallback() {
    final initials = coach.profile?.name.isNotEmpty == true
        ? coach.profile!.name.substring(0, 1).toUpperCase()
        : '?';
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lightGreen, AppColors.surfaceDim],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppText.headlineLg.copyWith(
            color: AppColors.accent.withValues(alpha: 0.6),
            fontSize: 40,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: coach.profile?.name ?? 'Coach',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSubscribed
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.borderSubtle,
            ),
          ),
          child: Column(
            children: [
              FutureBuilder<dynamic>(
                // Cache hit → zero queries. Miss → single lookup that fills
                // the cache for every later rebuild of this card.
                future: kCoachGalleryCache.containsKey(coach.userId)
                    ? Future.value(kCoachGalleryCache[coach.userId])
                    : Supabase.instance.client
                          .from('coach_onboarding')
                          .select('gallery_images')
                          .eq('user_id', coach.userId)
                          .maybeSingle()
                          .then((row) {
                            final images =
                                (row?['gallery_images'] as List?) ?? const [];
                            kCoachGalleryCache[coach.userId] = images;
                            return images;
                          }),
                builder: (context, snapshot) {
                  final images = snapshot.data;
                  if (images is List && images.isNotEmpty) {
                    final bannerUrl = images.first as String;
                    // A real image widget (with its own loading/error
                    // states) instead of DecorationImage, which fails
                    // silently and leaves a blank banner on a bad URL.
                    return CachedNetworkImage(
                      imageUrl: bannerUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 120,
                        width: double.infinity,
                        color: AppColors.surfaceContainerHigh,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _initialsFallback(),
                    );
                  }

                  return _initialsFallback();
                },
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        CoachAvatar(url: coach.profile?.avatarUrl, size: 52),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      coach.profile?.name ?? 'Coach',
                                      style: AppText.titleMd.copyWith(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isSubscribed)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Active',
                                        style: AppText.labelMd.copyWith(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              CoachStarRating(rating: coach.rating),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bio
                    Text(
                      coach.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Spec chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: coach.specialization
                          .take(3)
                          .map((s) => CoachSpecChip(label: s))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    // Latest review preview — visible while scrolling coaches page
                    _CoachCardReviewPreview(coachId: coach.id),
                    const SizedBox(height: 16),

                    // Price + button
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Price / mo',
                              style: AppText.labelSm.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '\$${coach.priceMonthly.toStringAsFixed(0)}',
                              style: AppText.titleLg.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          enabled: !isCancelling,
                          label: isSubscribed
                              ? (isCancelling ? 'Cancelling' : 'Cancel subscription')
                              : 'Subscribe',
                          child: GestureDetector(
                            onTap: isCancelling
                                ? null
                                : (isSubscribed ? onCancel : onSubscribe),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSubscribed ? 14 : 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSubscribed
                                    ? Colors.transparent
                                    : AppColors.accent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSubscribed
                                    ? Border.all(
                                        color: AppColors.error
                                            .withValues(alpha: 0.85),
                                        width: 1.2,
                                      )
                                    : null,
                              ),
                              child: isCancelling
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.error,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSubscribed) ...[
                                          Icon(Icons.close_rounded,
                                              color: AppColors.error,
                                              size: 14),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          isSubscribed
                                              ? 'Cancel'
                                              : 'Subscribe',
                                          style: AppText.buttonPrimary
                                              .copyWith(
                                            color: isSubscribed
                                                ? AppColors.error
                                                : AppColors.onPrimary,
                                            fontSize:
                                                isSubscribed ? 12 : null,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Review preview on coach card (visible while scrolling marketplace) ───────

class _CoachCardReviewPreview extends StatelessWidget {
  final String coachId;
  const _CoachCardReviewPreview({required this.coachId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ReviewRepository().fetchReviews(coachId),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final reviews = snapshot.data as List;
        if (reviews.isEmpty) return const SizedBox.shrink();
        final latest = reviews.first;
        final rating = (latest as dynamic).rating as int? ?? 0;
        final comment = (latest as dynamic).comment as String?;
        if ((comment == null || comment.trim().isEmpty) && rating == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: AppColors.tertiary, size: 14),
              const SizedBox(width: 4),
              Text('$rating.0', style: AppText.labelSm.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment?.trim().isNotEmpty == true ? comment! : 'Rated $rating stars',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.textSecondary, fontSize: 11.5, height: 1.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Subscribe bottom sheet ────────────────────────────────────────────────────

class _SubscribeBottomSheet extends StatelessWidget {
  final CoachEntity coach;
  const _SubscribeBottomSheet({required this.coach});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          CoachAvatar(url: coach.profile?.avatarUrl, size: 64),
          const SizedBox(height: 16),
          Text(
            coach.profile?.name ?? 'Coach',
            style: AppText.headlineSm.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${coach.priceMonthly.toStringAsFixed(0)} / month',
            style: AppText.titleMd.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 8),
          Text(
            'You can cancel at any time. By subscribing you agree to our Terms of Service.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Consumer<SubscriptionNotifier>(
            builder: (ctx, notifier, _) {
              if (notifier.isLoading) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                );
              }
              return Column(
                children: [
                  if (notifier.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        notifier.error!,
                        style: AppText.bodySm.copyWith(color: AppColors.error),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final activeSub = context
                            .read<ActiveSubscriptionNotifier>();
                        final notifier = ctx.read<SubscriptionNotifier>();
                        await notifier.subscribeToCoach(coach.id);
                        // Failure keeps the sheet open so the error text
                        // above stays visible; success refreshes the active
                        // subscription and closes.
                        if (notifier.error != null) return;
                        await activeSub.fetchActiveSubscription();
                        if (navigator.mounted) navigator.pop();
                      },
                      child: Text(
                        'Confirm subscription',
                        style: AppText.buttonPrimary.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
