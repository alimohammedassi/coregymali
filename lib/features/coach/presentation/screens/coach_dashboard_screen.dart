import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

import '../../data/models/subscription_model.dart';
import '../../data/models/phase_model.dart';

import '../providers/coach_dashboard_providers.dart';
import '../providers/coach_dashboard_stat_providers.dart';
import '../providers/coach_subscriptions_notifier.dart';
import 'client_data_screen.dart';
import 'coach_edit_profile_screen.dart';
import 'coach_media_screen.dart';
import '../providers/coach_media_provider.dart';
import '../providers/coach_profile_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kGold       = Color(0xFFC9A84C);
const _kGoldDim    = Color(0xFFA07832);
const _kGoldGlow   = Color(0x33C9A84C);
const _kGoldSubtle = Color(0x1AC9A84C);
const _kSuccess    = Color(0xFF52B788);
const _kWarning    = Color(0xFFFFC107);
const _kBlue       = Color(0xFF64B5F6);
const _kError      = Color(0xFFEF5350);

const _kCardR  = BorderRadius.all(Radius.circular(20));
const _kBadgeR = BorderRadius.all(Radius.circular(8));
const _kPillR  = BorderRadius.all(Radius.circular(12));

// ── Screen ────────────────────────────────────────────────────────────────────

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoachDashboardStatNotifier>().fetch();
      context.read<ActiveClientsNotifier>().fetch();
      context.read<CoachSubscriptionsNotifier>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: _kGold,
        backgroundColor: AppColors.surfaceContainerLow,
        displacement: 20,
        onRefresh: () async {
          await Future.wait([
            context.read<CoachDashboardStatNotifier>().fetch(),
            context.read<ActiveClientsNotifier>().fetch(),
            context.read<CoachSubscriptionsNotifier>().fetch(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StatsRow(),
              const SizedBox(height: 32),
              _SectionHeader(
                title: 'Subscribers', // TODO: l10n
                trailing: _SubscriberCountBadge(),
              ),
              const SizedBox(height: 16),
              const _SubscriptionsList(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MY DASHBOARD', // TODO: l10n
            style: AppText.labelSm.copyWith(
              color: _kGold,
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text('Overview', style: AppText.headlineMd), // TODO: l10n
        ],
      ),
      actions: [
        _AppBarBtn(
          icon: Icons.photo_library_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => CoachMediaNotifier(),
                child: const CoachMediaScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _AppBarBtn(
          icon: Icons.edit_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => CoachProfileNotifier(),
                child: const CoachEditProfileScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

// ── App bar icon button ───────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow.withOpacity(0.6),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        onTap: onTap,
        splashColor: _kGoldSubtle,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            color: _kGold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppText.headlineMd),
        if (trailing != null) ...[
          const Spacer(),
          trailing!,
        ],
      ],
    );
  }
}

// ── Subscriber count badge ────────────────────────────────────────────────────

class _SubscriberCountBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CoachSubscriptionsNotifier>(
      builder: (_, n, __) {
        final count = n.subscriptions?.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kGoldSubtle,
            borderRadius: _kBadgeR,
            border: Border.all(color: _kGold.withOpacity(0.3)),
          ),
          child: Text(
            '$count total', // TODO: l10n
            style: AppText.labelSm.copyWith(color: _kGold, fontSize: 11),
          ),
        );
      },
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final statsNotifier = context.watch<CoachDashboardStatNotifier>();
    final stats = statsNotifier.stats;

    if (statsNotifier.isLoading && stats == null) {
      return const _ShimmerStatsRow();
    }

    if (statsNotifier.error != null && stats == null) {
      return _ErrorCard(message: 'Failed to load stats: ${statsNotifier.error}'); // TODO: l10n
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              width: cardWidth,
              title: 'Active\nSubscribers', // TODO: l10n
              value: stats?.activeSubscribers.toString() ?? '0',
              icon: Icons.people_rounded,
              accentColor: _kSuccess,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Avg\nRating', // TODO: l10n
              value: stats?.avgRating.toStringAsFixed(1) ?? '0.0',
              icon: Icons.star_rounded,
              accentColor: _kWarning,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Monthly\nRevenue', // TODO: l10n
              value: '\$${stats?.monthlyRevenue.toStringAsFixed(0) ?? '0'}',
              icon: Icons.attach_money_rounded,
              accentColor: _kGold,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Open\nSlots', // TODO: l10n
              value: stats?.openSlots.toString() ?? '0',
              icon: Icons.event_seat_rounded,
              accentColor: _kBlue,
            ),
          ],
        );
      },
    );
  }
}

// ── Shimmer stats placeholder ─────────────────────────────────────────────────

class _ShimmerStatsRow extends StatefulWidget {
  const _ShimmerStatsRow();

  @override
  State<_ShimmerStatsRow> createState() => _ShimmerStatsRowState();
}

class _ShimmerStatsRowState extends State<_ShimmerStatsRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => LayoutBuilder(
        builder: (context, constraints) {
          final w = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              4,
              (_) => Container(
                width: w,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow.withOpacity(_anim.value),
                  borderRadius: _kCardR,
                  border: Border.all(
                    color: _kGold.withOpacity(_anim.value * 0.3),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final double width;
  final String title, value;
  final IconData icon;
  final Color accentColor;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withOpacity(0.7),
        borderRadius: _kCardR,
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with colored background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppText.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.headlineLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subscriptions list ────────────────────────────────────────────────────────

class _SubscriptionsList extends StatefulWidget {
  const _SubscriptionsList();

  @override
  State<_SubscriptionsList> createState() => _SubscriptionsListState();
}

class _SubscriptionsListState extends State<_SubscriptionsList> {
  int _selectedTab = 0;

  static const _tabs = [
    (label: 'All',     icon: Icons.grid_view_rounded),        // TODO: l10n
    (label: 'Active',  icon: Icons.check_circle_outline),     // TODO: l10n
    (label: 'Pending', icon: Icons.schedule_rounded),         // TODO: l10n
    (label: 'Expired', icon: Icons.cancel_outlined),          // TODO: l10n
  ];

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CoachSubscriptionsNotifier>();

    if (notifier.isLoading && notifier.subscriptions == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 32),
          child: CircularProgressIndicator(
            color: _kGold,
            strokeWidth: 2,
            backgroundColor: _kGoldSubtle,
          ),
        ),
      );
    }

    if (notifier.error != null && notifier.subscriptions == null) {
      return _ErrorCard(message: notifier.error!);
    }

    final list = notifier.filtered(_selectedTab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilterBar(notifier),
        const SizedBox(height: 16),
        if (list.isEmpty)
          _EmptyState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _SubscriptionCard(model: list[i]),
          ),
      ],
    );
  }

  Widget _buildFilterBar(CoachSubscriptionsNotifier notifier) {
    final all   = notifier.subscriptions ?? [];
    final counts = [
      all.length,
      all.where((s) => s.status == 'active').length,
      all.where((s) => s.status == 'pending').length,
      all.where((s) => s.status == 'expired' || s.status == 'cancelled').length,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final selected = _selectedTab == i;
          final tab = _tabs[i];
          return Padding(
            padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? _kGold : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                  border: selected
                      ? null
                      : Border.all(color: AppColors.glassBorder),
                  boxShadow: selected
                      ? [const BoxShadow(color: _kGoldGlow, blurRadius: 10)]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 14,
                      color: selected ? Colors.black : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tab.label,
                      style: AppText.bodySm.copyWith(
                        color: selected ? Colors.black : AppColors.onSurfaceVariant,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    if (counts[i] > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.black.withOpacity(0.2)
                              : AppColors.surfaceContainerHigh,
                          borderRadius: const BorderRadius.all(
                              Radius.circular(6)),
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: AppText.labelSm.copyWith(
                            fontSize: 10,
                            color: selected ? Colors.black : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withOpacity(0.4),
        borderRadius: _kCardR,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.group_off_rounded,
                size: 34, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text('No subscribers yet', style: AppText.headlineMd), // TODO: l10n
          const SizedBox(height: 8),
          Text(
            'Share your profile link to start getting clients.', // TODO: l10n
            style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Profile link copied!'), // TODO: l10n
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.share_rounded, color: Colors.black, size: 18),
            label: Text(
              'Share Profile', // TODO: l10n
              style: AppText.labelLg.copyWith(color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: _kCardR,
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyMd.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subscription card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel model;
  const _SubscriptionCard({required this.model});

  String _fmt(DateTime d) => DateFormat('MMM d').format(d);

  @override
  Widget build(BuildContext context) {
    final totalDays =
        model.expiresAt.difference(model.startedAt).inDays.clamp(1, 99999);
    final daysElapsed =
        DateTime.now().difference(model.startedAt).inDays;
    final daysLeft =
        model.expiresAt.difference(DateTime.now()).inDays;
    final progressValue = (daysElapsed / totalDays).clamp(0.0, 1.0);

    final daysLeftText = daysLeft <= 0
        ? 'Expired' // TODO: l10n
        : daysLeft <= 7
            ? '$daysLeft days left' // TODO: l10n
            : '$daysLeft days remaining'; // TODO: l10n

    final daysLeftColor = daysLeft <= 0
        ? AppColors.error
        : daysLeft <= 7
            ? Colors.orange
            : AppColors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: _kCardR,
      child: InkWell(
        borderRadius: _kCardR,
        splashColor: _kGoldSubtle,
        onTap: () {
          final repoProvider = context.read<CoachDashboardRepositoryProvider>();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultiProvider(
                providers: [
                  ChangeNotifierProvider(create: (_) => SelectedDateRangeNotifier()),
                  ChangeNotifierProvider(
                    create: (_) => ClientDataNotifier(repoProvider.repository),
                  ),
                ],
                child: ClientDataScreen(clientId: model.clientId),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withOpacity(0.5),
            borderRadius: _kCardR,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ① Header
              _CardHeader(model: model),

              // ② Divider
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppColors.glassBorder, height: 1),
              ),

              // ③ Date + payment
              _DatePaymentRow(model: model, fmtFn: _fmt),

              // ④ Goals
              if (model.goals != null && model.goals!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.flag_rounded,
                  iconColor: _kGold,
                  text: model.goals!,
                  maxLines: 2,
                ),
              ],

              // ⑤ Notes
              if (model.notes != null && model.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.notes_rounded,
                  iconColor: AppColors.onSurfaceVariant,
                  text: model.notes!,
                  maxLines: 1,
                  textColor: AppColors.onSurfaceVariant,
                ),
              ],

              // ⑥ Phases
              if (model.phases.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PhaseSection(phases: model.phases),
              ],

              // ⑦ Progress bar
              if (model.status == 'active') ...[
                const SizedBox(height: 14),
                _ProgressSection(
                  daysLeftText: daysLeftText,
                  daysLeftColor: daysLeftColor,
                  progressValue: progressValue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card sub-widgets ──────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final SubscriptionModel model;
  const _CardHeader({required this.model});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar with gold ring for active
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: model.status == 'active'
                      ? _kGold.withOpacity(0.6)
                      : AppColors.glassBorder,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: model.clientAvatarUrl != null
                    ? NetworkImage(model.clientAvatarUrl!)
                    : null,
                backgroundColor: AppColors.surfaceContainerHigh,
                child: model.clientAvatarUrl == null
                    ? const Icon(Icons.person,
                        color: AppColors.onSurfaceVariant, size: 22)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.clientName,
                style: AppText.labelLg.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kGoldSubtle,
                        borderRadius: _kBadgeR,
                      ),
                      child: Text(
                        model.planName,
                        style: AppText.labelSm.copyWith(
                          color: _kGold, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '\$${model.priceUsd.toStringAsFixed(0)}/mo',
                    style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(status: model.status),
      ],
    );
  }
}

class _DatePaymentRow extends StatelessWidget {
  final SubscriptionModel model;
  final String Function(DateTime) fmtFn;
  const _DatePaymentRow({required this.model, required this.fmtFn});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kGoldSubtle,
              borderRadius: _kPillR,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 12, color: _kGold),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${fmtFn(model.startedAt)}  →  ${fmtFn(model.expiresAt)}',
                    style: AppText.bodySm.copyWith(color: _kGold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _PaymentBadge(status: model.paymentStatus),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final int maxLines;
  final Color? textColor;
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.maxLines = 2,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: iconColor, size: 13),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: textColor),
          ),
        ),
      ],
    );
  }
}

class _PhaseSection extends StatelessWidget {
  final List<PhaseModel> phases;
  const _PhaseSection({required this.phases});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.route_rounded,
                size: 13, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'PLAN PHASES', // TODO: l10n
              style: AppText.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.glassBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: phases.asMap().entries.map((e) {
              return _PhaseStep(
                phase: e.value,
                isFirst: e.key == 0,
                isLast: e.key == phases.length - 1,
                prevStatus: e.key > 0 ? phases[e.key - 1].status : null,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final String daysLeftText;
  final Color daysLeftColor;
  final double progressValue;
  const _ProgressSection({
    required this.daysLeftText,
    required this.daysLeftColor,
    required this.progressValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  daysLeftText,
                  style: AppText.bodySm.copyWith(color: daysLeftColor),
                ),
              ],
            ),
            Text(
              '${(progressValue * 100).toStringAsFixed(0)}%',
              style: AppText.labelSm.copyWith(
                color: _kGold, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 6,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: const AlwaysStoppedAnimation(_kGold),
          ),
        ),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (status) {
      'active'    => (const Color(0xFF1B4332), _kSuccess,  'Active',    Icons.check_circle_rounded),    // TODO: l10n
      'pending'   => (const Color(0xFF3D2B00), _kWarning,  'Pending',   Icons.schedule_rounded),        // TODO: l10n
      'paused'    => (const Color(0xFF003060), _kBlue,     'Paused',    Icons.pause_circle_rounded),    // TODO: l10n
      'expired'   => (const Color(0xFF3B0000), _kError,    'Expired',   Icons.cancel_rounded),          // TODO: l10n
      _           => (const Color(0xFF1A1A1A), AppColors.onSurfaceVariant, 'Cancelled', Icons.block_rounded), // TODO: l10n
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _kBadgeR,
        border: Border.all(color: fg.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: AppText.labelSm.copyWith(color: fg, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Payment badge ─────────────────────────────────────────────────────────────

class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      'paid'     => (Icons.check_circle_rounded,  _kSuccess, 'Paid'),     // TODO: l10n
      'unpaid'   => (Icons.warning_amber_rounded, _kWarning, 'Unpaid'),   // TODO: l10n
      'refunded' => (Icons.replay_rounded,        _kBlue,    'Refunded'), // TODO: l10n
      _          => (Icons.help_outline_rounded,  AppColors.onSurfaceVariant, 'Unknown'), // TODO: l10n
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: _kBadgeR,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.labelSm.copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Phase step ────────────────────────────────────────────────────────────────

class _PhaseStep extends StatelessWidget {
  final PhaseModel phase;
  final bool isFirst, isLast;
  final String? prevStatus;

  const _PhaseStep({
    required this.phase,
    required this.isFirst,
    required this.isLast,
    this.prevStatus,
  });

  IconData _typeIcon(String type) => switch (type) {
    'workout'   => Icons.fitness_center_rounded,
    'nutrition' => Icons.restaurant_rounded,
    'combined'  => Icons.auto_awesome_rounded,
    _           => Icons.circle_outlined,
  };

  String _weekLabel() {
    if (phase.startedAt == null) return '';
    final w = DateTime.now().difference(phase.startedAt!).inDays ~/ 7 + 1;
    return 'Week $w'; // TODO: l10n
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst && prevStatus != null)
          _StepLine(active: prevStatus == 'completed' || prevStatus == 'in_progress'),
        SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepCircle(phase: phase, icon: _typeIcon(phase.type)),
              const SizedBox(height: 6),
              Text(
                phase.title,
                style: AppText.labelSm.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (phase.status == 'in_progress')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _weekLabel(),
                    style: AppText.bodySm.copyWith(
                      color: _kGold, fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          _StepLine(
            active: phase.status == 'completed' || phase.status == 'in_progress',
          ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final PhaseModel phase;
  final IconData icon;
  const _StepCircle({required this.phase, required this.icon});

  @override
  Widget build(BuildContext context) {
    return switch (phase.status) {
      'completed' => Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: _kGold,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.black, size: 16),
        ),
      'in_progress' => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: _kGold, width: 2),
            boxShadow: const [
              BoxShadow(
                color: _kGoldGlow,
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: _kGold, size: 15),
        ),
      _ => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.onSurfaceVariant.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.onSurfaceVariant.withOpacity(0.3),
            size: 15,
          ),
        ),
    };
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: active ? _kGold : AppColors.onSurfaceVariant.withOpacity(0.25),
      ),
    );
  }
}