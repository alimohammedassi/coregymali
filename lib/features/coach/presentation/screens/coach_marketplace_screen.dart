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

class CoachMarketplaceScreen extends StatefulWidget {
  const CoachMarketplaceScreen({super.key});

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

  void _fetch() {
    context.read<CoachListNotifier>().fetchCoaches(
          specialization: _selectedSpec == 'All' ? null : _selectedSpec,
          maxPrice: _priceRange.end < 500 ? _priceRange.end : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCoachBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: kCoachGold,
          backgroundColor: kCoachCard,
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
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kCoachCard2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kCoachBorder),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FIND A COACH',
                          style:
                              AppText.headlineSm.copyWith(color: Colors.white)),
                      Text('اختر مدربك', style: AppText.bodySm),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kCoachGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kCoachGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: kCoachGold, size: 14),
                      const SizedBox(width: 4),
                      Text('Premium',
                          style:
                              AppText.labelMd.copyWith(color: kCoachGold)),
                    ],
                  ),
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
            child: Text('SPECIALIZATION',
                style: AppText.labelSm
                    .copyWith(color: kCoachMuted, letterSpacing: 2)),
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
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedSpec = spec);
                      _fetch();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? kCoachGold : kCoachCard2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? kCoachGold : kCoachBorder,
                        ),
                      ),
                      child: Text(
                        spec.toUpperCase(),
                        style: AppText.labelMd.copyWith(
                          color: active ? Colors.black : kCoachMuted,
                          letterSpacing: 1,
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
            color: kCoachCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kCoachBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PRICE / MONTH',
                      style: AppText.labelSm
                          .copyWith(color: kCoachMuted, letterSpacing: 2)),
                  Text(
                    _priceRange.end >= 500
                        ? '\$${_priceRange.start.toInt()}+'
                        : '\$${_priceRange.start.toInt()} – \$${_priceRange.end.toInt()}',
                    style: AppText.titleSm.copyWith(color: kCoachGold),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: kCoachGold,
                  inactiveTrackColor: kCoachCard2,
                  thumbColor: kCoachGold,
                  overlayColor: kCoachGold.withOpacity(0.12),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 8),
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
          return const SliverFillRemaining(
            child: Center(
                child:
                    CircularProgressIndicator(color: kCoachGold, strokeWidth: 2)),
          );
        }

        if (notifier.error != null) {
          return SliverFillRemaining(
            child: CoachErrorState(
              message: notifier.error!,
              onRetry: _fetch,
            ),
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
                    onTap: () => _navigateToDetail(coach),
                    onSubscribe: () => _showSubscribeSheet(coach),
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
    final activeSubNotifier =
        ActiveSubscriptionNotifier(SubscriptionRepositoryImpl())
          ..fetchActiveSubscription();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SelectedCoachNotifier(CoachRepositoryImpl())
                ..fetchCoach(coach.id),
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

  void _showSubscribeSheet(CoachEntity coach) {
    final subscriptionNotifier = context.read<SubscriptionNotifier>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider<SubscriptionNotifier>.value(
        value: subscriptionNotifier,
        child: _SubscribeBottomSheet(coach: coach),
      ),
    );
  }
}

// ── CoachCard widget ──────────────────────────────────────────────────────────

class CoachCard extends StatelessWidget {
  final CoachEntity coach;
  final bool isSubscribed;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;

  const CoachCard({
    super.key,
    required this.coach,
    required this.isSubscribed,
    required this.onTap,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kCoachCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSubscribed ? kCoachGold.withOpacity(0.4) : kCoachBorder,
          ),
        ),
        child: Column(
          children: [
            FutureBuilder<dynamic>(
              future: Supabase.instance.client
                  .from('coach_onboarding')
                  .select('gallery_images')
                  .eq('user_id', coach.userId)
                  .maybeSingle(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null && snapshot.data['gallery_images'] != null && (snapshot.data['gallery_images'] as List).isNotEmpty) {
                  final bannerUrl = (snapshot.data['gallery_images'] as List).first;
                  return Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(image: NetworkImage(bannerUrl), fit: BoxFit.cover),
                    ),
                  );
                }
                
                final initials = coach.profile?.name.isNotEmpty == true 
                  ? coach.profile!.name.substring(0, 1).toUpperCase() 
                  : '?';

                return Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2C2C2C), Color(0xFF151515)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: AppText.headlineLg.copyWith(color: kCoachGold.withOpacity(0.5), fontSize: 40),
                    ),
                  ),
                );
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
                                    style: AppText.titleMd
                                        .copyWith(color: Colors.white),
                                  ),
                                ),
                                if (isSubscribed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: kCoachGold.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color:
                                              kCoachGold.withOpacity(0.4)),
                                    ),
                                    child: Text('ACTIVE',
                                        style: AppText.labelMd
                                            .copyWith(color: kCoachGold)),
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
                    style: AppText.bodySm.copyWith(height: 1.5),
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
                  const SizedBox(height: 16),

                  // Price + button
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRICE / MO',
                              style: AppText.labelSm.copyWith(
                                  color: kCoachMuted, letterSpacing: 1.5)),
                          Text(
                            '\$${coach.priceMonthly.toStringAsFixed(0)}',
                            style: AppText.titleLg.copyWith(color: kCoachGold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: isSubscribed ? null : onSubscribe,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSubscribed ? kCoachCard2 : kCoachGold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isSubscribed ? 'SUBSCRIBED' : 'SUBSCRIBE',
                            style: AppText.buttonPrimary.copyWith(
                              color: isSubscribed ? kCoachMuted : Colors.black,
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
      decoration: const BoxDecoration(
        color: Color(0xFF1A1919),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          CoachAvatar(url: coach.profile?.avatarUrl, size: 64),
          const SizedBox(height: 16),
          Text(coach.profile?.name ?? 'Coach',
              style: AppText.headlineSm.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text('\$${coach.priceMonthly.toStringAsFixed(0)} / month',
              style: AppText.titleMd.copyWith(color: kCoachGold)),
          const SizedBox(height: 8),
          Text(
            'You can cancel at any time. By subscribing you agree to our Terms of Service.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(height: 1.5),
          ),
          const SizedBox(height: 28),
          Consumer<SubscriptionNotifier>(
            builder: (ctx, notifier, _) {
              if (notifier.isLoading) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: kCoachGold, strokeWidth: 2));
              }
              return Column(
                children: [
                  if (notifier.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(notifier.error!,
                          style: AppText.bodySm
                              .copyWith(color: AppColors.error)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kCoachGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await ctx
                            .read<SubscriptionNotifier>()
                            .subscribeToCoach(coach.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text('CONFIRM SUBSCRIPTION',
                          style: AppText.buttonPrimary
                              .copyWith(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style:
                            AppText.bodySm.copyWith(color: kCoachMuted)),
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
