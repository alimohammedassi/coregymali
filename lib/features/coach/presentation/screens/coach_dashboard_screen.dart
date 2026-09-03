import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../supabase/auth_service.dart';
import '../../../../login_sign_up.dart' show AuthWrapper;
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../l10n/app_localizations.dart';

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
Color get _kGold => AppColors.tertiary;
Color get _kGoldGlow => AppColors.tertiary.withValues(alpha: 0.20);
Color get _kGoldSubtle => AppColors.tertiary.withValues(alpha: 0.10);
Color get _kSuccess => AppColors.greenAccent;
Color get _kWarning => AppColors.orangeAccent;
Color get _kBlue => AppColors.secondary;

const _kCardR = BorderRadius.all(Radius.circular(20));
const _kBadgeR = BorderRadius.all(Radius.circular(8));
const _kPillR = BorderRadius.all(Radius.circular(12));

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(l10n),
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
                title: l10n.dashboardSubscribers,
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

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dashboardEyebrow,
            style: AppText.labelSm.copyWith(
              color: _kGold,
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(l10n.dashboardOverview, style: AppText.headlineMd),
        ],
      ),
      actions: [
        _AppBarBtn(
          icon: Icons.photo_library_rounded,
          semanticLabel: 'My media',
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
          semanticLabel: 'Edit coach profile',
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
        const SizedBox(width: 8),
        _SignOutBtn(),
        const SizedBox(width: 12),
      ],
    );
  }
}

// ── Sign out button ─────────────────────────────────────────────────────────────

class _SignOutBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context)?.signOut ?? 'Sign out',
      child: Material(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          onTap: () => _showSignOutDialog(context),
          splashColor: AppColors.error.withValues(alpha: 0.2),
          child: SizedBox(
            width: 44,
            height: 44,
            child:  Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext ctx) {
    final l = AppLocalizations.of(ctx)!;
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l.signOutTitle,
          style: AppText.headlineSm.copyWith(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: Text(
          l.signOutConfirm,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text(
              l.cancel,
              style: AppText.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(dCtx);
              await AuthService().signOut();
              if (ctx.mounted) {
                // Same destination as the client sign-out flow — this app
                // registers no named routes, so pushNamed('/login') throws.
                Navigator.of(ctx).pushAndRemoveUntil(
                  PageRouteBuilder(
                    pageBuilder: (_, a, __) => const AuthWrapper(),
                    transitionsBuilder: (_, a, __, child) => FadeTransition(
                      opacity:
                          CurvedAnimation(parent: a, curve: Curves.easeOut),
                      child: child,
                    ),
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              l.signOutTitle,
              style: AppText.labelMd.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar icon button ───────────────────────────────────────────────────────

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  const _AppBarBtn({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          onTap: onTap,
          splashColor: _kGoldSubtle,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
          ),
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
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

// ── Subscriber count badge ────────────────────────────────────────────────────

class _SubscriberCountBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<CoachSubscriptionsNotifier>(
      builder: (_, n, __) {
        final count = n.subscriptions?.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kGoldSubtle,
            borderRadius: _kBadgeR,
            border: Border.all(color: _kGold.withValues(alpha: 0.3)),
          ),
          child: Text(
            l10n.subscriberCount(count),
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
    final l10n = AppLocalizations.of(context)!;
    final statsNotifier = context.watch<CoachDashboardStatNotifier>();
    final stats = statsNotifier.stats;

    if (statsNotifier.isLoading && stats == null) {
      return const _ShimmerStatsRow();
    }

    if (statsNotifier.error != null && stats == null) {
      return _ErrorCard(
        message: l10n.failedToLoadStats(statsNotifier.error!),
        onRetry: () => context.read<CoachDashboardStatNotifier>().fetch(),
      );
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
              title: l10n.statActiveSubscribers,
              value: stats?.activeSubscribers.toString() ?? '0',
              icon: Icons.people_rounded,
              accentColor: _kSuccess,
            ),
            _StatCard(
              width: cardWidth,
              title: l10n.statAvgRating,
              value: stats?.avgRating.toStringAsFixed(1) ?? '0.0',
              icon: Icons.star_rounded,
              accentColor: _kWarning,
            ),
            _StatCard(
              width: cardWidth,
              title: l10n.statMonthlyRevenue,
              value: '\$${stats?.monthlyRevenue.toStringAsFixed(0) ?? '0'}',
              icon: Icons.attach_money_rounded,
              accentColor: _kGold,
            ),
            _StatCard(
              width: cardWidth,
              title: l10n.statOpenSlots,
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
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
                  color: AppColors.surfaceContainerLow.withValues(alpha: _anim.value),
                  borderRadius: _kCardR,
                  border: Border.all(
                    color: _kGold.withValues(alpha: _anim.value * 0.3),
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

// ── Shimmer placeholder for the subscriptions list (matches stats shimmer) ───

class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
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
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (_, __) => Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 132,
            decoration: BoxDecoration(
              color:
                  AppColors.surfaceContainerLow.withValues(alpha: _anim.value),
              borderRadius: _kCardR,
              border: Border.all(
                color: AppColors.borderSubtle,
              ),
            ),
          ),
        ),
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
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: _kCardR,
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with colored background
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
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
              color: AppColors.textPrimary,
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

  List<(String, IconData)> _tabs(AppLocalizations l10n) => [
        (l10n.filterAll, Icons.grid_view_rounded),
        (l10n.filterActive, Icons.check_circle_outline),
        (l10n.filterPending, Icons.schedule_rounded),
        (l10n.filterExpired, Icons.cancel_outlined),
      ];

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CoachSubscriptionsNotifier>();

    if (notifier.isLoading && notifier.subscriptions == null) {
      return const _ShimmerList();
    }

    if (notifier.error != null && notifier.subscriptions == null) {
      return _ErrorCard(
        message: notifier.error!,
        onRetry: () => context.read<CoachSubscriptionsNotifier>().fetch(),
      );
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
    final l10n = AppLocalizations.of(context)!;
    final tabs = _tabs(l10n);
    final all = notifier.subscriptions ?? [];
    final counts = [
      all.length,
      all.where((s) => s.status == 'active').length,
      all.where((s) => s.status == 'pending').length,
      all.where((s) => s.status == 'expired' || s.status == 'cancelled').length,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _selectedTab == i;
          final (label, icon) = tabs[i];
          return Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
            child: Semantics(
              button: true,
              selected: selected,
              label: label,
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _kGold : Colors.transparent,
                    borderRadius:
                        const BorderRadius.all(Radius.circular(20)),
                    border: selected
                        ? null
                        : Border.all(color: AppColors.borderSubtle),
                    boxShadow: selected
                        ? [BoxShadow(color: _kGoldGlow, blurRadius: 10)]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: selected
                            ? Colors.black
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: AppText.bodySm.copyWith(
                          color: selected
                              ? Colors.black
                              : AppColors.onSurfaceVariant,
                          fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    if (counts[i] > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.black.withValues(alpha: 0.2)
                              : AppColors.surfaceContainerHigh,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          '${counts[i]}',
                          style: AppText.labelSm.copyWith(
                            fontSize: 10,
                            color: selected
                                ? Colors.black
                                : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                  ),
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
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: _kCardR,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child:  Icon(
              Icons.group_off_rounded,
              size: 34,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.of(context)!.noSubscribersYet,
              style: AppText.headlineMd),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.completeProfileHint,
            style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => CoachProfileNotifier(),
                    child: const CoachEditProfileScreen(),
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.tune_rounded,
              color: Colors.black,
              size: 18,
            ),
            label: Text(
              AppLocalizations.of(context)!.completeProfileCta,
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
  final VoidCallback? onRetry;
  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: _kCardR,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
               Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppText.bodyMd.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon:  Icon(Icons.refresh_rounded,
                    size: 16, color: AppColors.error),
                label: Text('RETRY',
                    style: AppText.labelMd.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ),
          ],
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
    final l10n = AppLocalizations.of(context)!;
    final totalDays = model.expiresAt
        .difference(model.startedAt)
        .inDays
        .clamp(1, 99999);
    final daysElapsed = DateTime.now().difference(model.startedAt).inDays;
    final daysLeft = model.expiresAt.difference(DateTime.now()).inDays;
    final progressValue = (daysElapsed / totalDays).clamp(0.0, 1.0);

    final daysLeftText = daysLeft <= 0
        ? l10n.statusExpired
        : daysLeft <= 7
        ? l10n.daysLeft(daysLeft)
        : l10n.daysRemaining(daysLeft);

    final daysLeftColor = daysLeft <= 0
        ? AppColors.error
        : daysLeft <= 7
        ? AppColors.orangeAccent
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
                  ChangeNotifierProvider(
                    create: (_) => SelectedDateRangeNotifier(),
                  ),
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
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: _kCardR,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ① Header
              _CardHeader(model: model),

              // ② Divider
               Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: AppColors.borderSubtle, height: 1),
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
                      ? _kGold.withValues(alpha: 0.6)
                      : AppColors.borderSubtle,
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
                    ?  Icon(
                        Icons.person,
                        color: AppColors.onSurfaceVariant,
                        size: 22,
                      )
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
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kGoldSubtle,
                        borderRadius: _kBadgeR,
                      ),
                      child: Text(
                        model.planName,
                        style: AppText.labelSm.copyWith(
                          color: _kGold,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '\$${model.priceUsd.toStringAsFixed(0)}/mo',
                    style: AppText.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
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
                 Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: _kGold,
                ),
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
             Icon(
              Icons.route_rounded,
              size: 13,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.planPhases,
              style: AppText.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: AppColors.borderSubtle)),
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
                 Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.onSurfaceVariant,
                ),
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
                color: _kGold,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
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
            valueColor:  AlwaysStoppedAnimation(_kGold),
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
    final l10n = AppLocalizations.of(context)!;
    final (bg, fg, label, icon) = switch (status) {
      'active' => (
        _kSuccess.withValues(alpha: 0.12),
        _kSuccess,
        l10n.filterActive,
        Icons.check_circle_rounded,
      ),
      'pending' => (
        _kWarning.withValues(alpha: 0.12),
        _kWarning,
        l10n.filterPending,
        Icons.schedule_rounded,
      ),
      'paused' => (
        _kBlue.withValues(alpha: 0.12),
        _kBlue,
        l10n.statusPaused,
        Icons.pause_circle_rounded,
      ),
      'expired' => (
        AppColors.error.withValues(alpha: 0.12),
        AppColors.error,
        l10n.statusExpired,
        Icons.cancel_rounded,
      ),
      _ => (
        AppColors.onSurfaceVariant.withValues(alpha: 0.12),
        AppColors.onSurfaceVariant,
        l10n.statusCancelled,
        Icons.block_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: _kBadgeR,
        border: Border.all(color: fg.withValues(alpha: 0.5)),
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
      'paid' => (
        Icons.check_circle_rounded,
        _kSuccess,
        AppLocalizations.of(context)!.paymentPaid,
      ),
      'unpaid' => (
        Icons.warning_amber_rounded,
        _kWarning,
        AppLocalizations.of(context)!.paymentUnpaid,
      ),
      'refunded' => (
        Icons.replay_rounded,
        _kBlue,
        AppLocalizations.of(context)!.paymentRefunded,
      ),
      _ => (
        Icons.help_outline_rounded,
        AppColors.onSurfaceVariant,
        '?',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: _kBadgeR,
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    'workout' => Icons.fitness_center_rounded,
    'nutrition' => Icons.restaurant_rounded,
    'combined' => Icons.auto_awesome_rounded,
    _ => Icons.circle_outlined,
  };

  String _weekLabel(BuildContext context) {
    if (phase.startedAt == null) return '';
    final w = DateTime.now().difference(phase.startedAt!).inDays ~/ 7 + 1;
    return AppLocalizations.of(context)!.phaseWeek(w);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isFirst && prevStatus != null)
          _StepLine(
            active: prevStatus == 'completed' || prevStatus == 'in_progress',
          ),
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
                    _weekLabel(context),
                    style: AppText.bodySm.copyWith(color: _kGold, fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          _StepLine(
            active:
                phase.status == 'completed' || phase.status == 'in_progress',
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
        decoration:  BoxDecoration(color: _kGold, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.black, size: 16),
      ),
      'in_progress' => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: _kGold, width: 2),
          boxShadow: [
            BoxShadow(color: _kGoldGlow, blurRadius: 10, spreadRadius: 2),
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
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
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
        color: active ? _kGold : AppColors.onSurfaceVariant.withValues(alpha: 0.25),
      ),
    );
  }
}
