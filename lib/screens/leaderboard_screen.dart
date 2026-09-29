import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/rank_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/leaderboard/leaderboard_category_tabs.dart';
import '../widgets/leaderboard/leaderboard_competition_header.dart';
import '../widgets/leaderboard/leaderboard_rank_delta.dart';
import '../widgets/leaderboard/leaderboard_recap.dart';
import '../widgets/leaderboard/leaderboard_sparkline.dart';
import '../widgets/leaderboard/leaderboard_streak_badge.dart';
import '../widgets/leaderboard/leaderboard_tier_chip.dart';
import '../widgets/leaderboard/leaderboard_user_card.dart';
import 'client_profile_screen.dart';

/// CoreGym competitive hub — the weekly/monthly commitment competition
/// (server score: 60% calorie adherence + 40% water adherence, rolling
/// window — logic untouched, served by get_leaderboard_v2).
///
/// Psychological loop: see position → understand movement → identify the
/// next achievable target → act → come back and check.
///
/// Structure (top → bottom):
/// competition header (cycle + reset) → last-cycle recap → your rank card
/// (next target + tier milestone) → category tabs → podium → board rows.
///
/// Preserved from the previous version: podium, search, tier chips,
/// pinned-your-rank card, skeleton loading, row entrance stagger, haptics,
/// and the score-breakdown sheet (now localized + showing real adherence).
class LeaderboardScreen extends StatefulWidget {
  /// Signed-in client's id — highlights their row, drives the "your rank"
  /// card and the pinned jump-back bar.
  final String? currentUserId;

  const LeaderboardScreen({super.key, this.currentUserId});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final RankService _service = RankService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _rowKeys = {};
  static const String _recapDismissPref = 'lb_recap_dismissed_cycle';

  /// Boards per (category, window) — switching back is instant, no refetch.
  final Map<String, LeaderboardResult> _cache = {};
  LeaderboardCategory _category = LeaderboardCategory.overall;
  int _days = 7;
  String? _error;
  String _query = '';
  bool _meVisibleOnScreen = true;

  WeeklyRecap? _recap;
  bool _recapDismissed = true;
  bool _highlightMe = false;
  Timer? _highlightTimer;

  String get _cacheKey => '${_category.wire}_$_days';
  LeaderboardResult? get _result => _cache[_cacheKey];

  @override
  void initState() {
    super.initState();
    _loadBoard();
    _loadRecap();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBoard({bool force = false}) async {
    if (!force && _cache.containsKey(_cacheKey)) return;
    setState(() => _error = null);
    try {
      final result = await _service.getLeaderboardV2(
        category: _category,
        days: _days,
        forUserId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _cache[_cacheKey] = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadRecap() async {
    // Dismissal is persisted per cycle so the recap shows once, not forever.
    try {
      final prefs = await SharedPreferences.getInstance();
      final recap = await _service.getWeeklyRecap(days: 7);
      if (!mounted) return;
      setState(() {
        _recap = recap;
        _recapDismissed =
            recap != null && prefs.getString(_recapDismissPref) == recap.periodStart.toIso8601String();
      });
    } catch (_) {
      // Recap is a garnish — a failure here never touches the board.
      if (mounted) setState(() => _recap = null);
    }
  }

  Future<void> _dismissRecap() async {
    final recap = _recap;
    if (recap == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recapDismissPref, recap.periodStart.toIso8601String());
    if (!mounted) return;
    setState(() => _recapDismissed = true);
  }

  void _switchCategory(LeaderboardCategory category) {
    setState(() => _category = category);
    _rowKeys.clear();
    _loadBoard();
  }

  void _switchDays(int days) {
    if (_days == days) return;
    HapticFeedback.selectionClick();
    setState(() => _days = days);
    _loadBoard();
  }

  /// Fri..Thu weekly cycle (matches the home week selector) or the calendar
  /// month for the 30-day board — real dates, real progress, real reset.
  ({int daysLeft, double progress, DateTime resetsOn, bool monthly}) _cycle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_days >= 30) {
      final start = DateTime(today.year, today.month, 1);
      final next = DateTime(today.year, today.month + 1, 1);
      final total = next.difference(start).inDays;
      final elapsed = today.difference(start).inDays + 1;
      return (
        daysLeft: total - elapsed + 1,
        progress: elapsed / total,
        resetsOn: next,
        monthly: true,
      );
    }
    // Dart weekday: Mon=1 .. Fri=5 .. Sun=7 → days since Friday.
    final daysSinceFriday = (today.weekday - 5 + 7) % 7;
    final start = today.subtract(Duration(days: daysSinceFriday));
    return (
      daysLeft: 7 - daysSinceFriday,
      progress: (daysSinceFriday + 1) / 7,
      resetsOn: start.add(const Duration(days: 7)),
      monthly: false,
    );
  }

  void _scrollToMe() {
    final me = _result?.me;
    if (me == null) return;
    final key = _rowKeys[me.rank];
    final rowContext = key?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: AppDurations.slow,
        curve: AppCurves.standard,
        alignment: 0.12,
      );
    } else {
      // Row not built (beyond the visible extent) — best-effort estimate.
      final target = 470.0 + (me.rank - 4) * 78.0;
      _scrollController.animateTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: AppDurations.slow,
        curve: AppCurves.standard,
      );
    }
    _highlightTimer?.cancel();
    setState(() => _highlightMe = true);
    _highlightTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _highlightMe = false);
    });
  }

  void _updateMeVisibility() {
    final me = _result?.me;
    if (me == null || me.rank <= 3) return;
    // Rough heuristic — only decides when the pinned bar appears.
    final rowOffset = 470.0 + (me.rank - 4) * 78.0;
    final viewTop = _scrollController.hasClients ? _scrollController.offset : 0;
    final viewBottom = viewTop + _scrollController.position.viewportDimension;
    final visible = rowOffset >= viewTop && rowOffset <= viewBottom;
    if (visible != _meVisibleOnScreen) {
      setState(() => _meVisibleOnScreen = visible);
    }
  }

  void _openProfile(LeaderboardEntry e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientProfileScreen(
          userId: e.userId,
          name: e.name,
          avatarUrl: e.avatarUrl,
          score: e.score,
          tier: e.tier,
        ),
      ),
    );
  }

  void _openMyProfile(LeaderboardStanding me) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientProfileScreen(
          userId: me.userId,
          name: me.name,
          avatarUrl: me.avatarUrl,
          score: me.score,
          tier: me.tier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final me = result?.me;
    final recapVisible = _recap != null && !_recapDismissed && _query.isEmpty;
    final showMePinned =
        me != null && me.rank > 3 && !_meVisibleOnScreen && _query.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          l10n.rankTitle,
          style: AppText.headlineSm.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: l10n.lbScoreTooltip,
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () => _showScoreInfo(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primaryFixed,
            onRefresh: () async {
              await Future.wait([_loadBoard(force: true), _loadRecap()]);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _updateMeVisibility();
                return false;
              },
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 8, 20, showMePinned ? 96 : 40),
                children: [
                  LeaderboardCompetitionHeader(
                    monthly: _days >= 30,
                    windowDays: _days,
                    daysLeft: _cycle().daysLeft,
                    cycleProgress: _cycle().progress,
                    resetsOn: _cycle().resetsOn,
                    onWindowChanged: _switchDays,
                  ),
                  if (recapVisible) ...[
                    const SizedBox(height: 12),
                    LeaderboardRecapCard(
                      recap: _recap!,
                      onDismiss: _dismissRecap,
                    ),
                  ],
                  if (me != null) ...[
                    const SizedBox(height: 12),
                    LeaderboardUserCard(
                      me: me,
                      category: _category,
                      onOpenProfile: () => _openMyProfile(me),
                    ),
                  ],
                  const SizedBox(height: 14),
                  LeaderboardCategoryTabs(
                    selected: _category,
                    onChanged: _switchCategory,
                  ),
                  const SizedBox(height: 6),
                  if (result != null && result.entries.length > 5) ...[
                    const SizedBox(height: 10),
                    _searchField(),
                  ],
                  const SizedBox(height: 16),
                  _boardSection(l10n, result),
                ],
              ),
            ),
          ),
          // Pinned "your rank" bar — the client never loses sight of
          // themselves on a long roster.
          if (showMePinned)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MyRankPinnedCard(
                position: me.rank,
                score: me.score,
                onTap: _scrollToMe,
              ),
            ),
        ],
      ),
    );
  }

  /// Podium + rows / search results / empty / error / skeleton — crossfades
  /// softly on category or window change instead of hard-jumping.
  Widget _boardSection(AppLocalizations l10n, LeaderboardResult? result) {
    Widget child;
    if (_error != null) {
      child = _ErrorCard(message: _error!, onRetry: () => _loadBoard(force: true));
    } else if (result == null) {
      child = const _LeaderboardSkeleton();
    } else if (_query.isNotEmpty) {
      child = _searchResults(l10n, result);
    } else if (result.entries.isEmpty) {
      child = _EmptyState(l10n: l10n);
    } else {
      child = _board(l10n, result);
    }

    return AnimatedSwitcher(
      duration: AppDurations.medium,
      switchInCurve: AppCurves.standard,
      switchOutCurve: AppCurves.exit,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(
          'board_${_category.wire}_${_days}_${_error == null ? (result == null ? 'sk' : 'ok') : 'err'}',
        ),
        child: child,
      ),
    );
  }

  Widget _board(AppLocalizations l10n, LeaderboardResult result) {
    return Column(
      children: [
        _podium(l10n, result),
        const SizedBox(height: 20),
        for (var i = 3; i < result.entries.length; i++)
          _rankRow(
            l10n,
            result.entries[i],
            position: result.entries[i].rank == 0 ? i + 1 : result.entries[i].rank,
            isMe: result.entries[i].userId == widget.currentUserId,
            index: i - 3,
          ),
      ],
    );
  }

  Widget _searchResults(AppLocalizations l10n, LeaderboardResult result) {
    final matches = result.entries
        .where((e) => e.name.toLowerCase().contains(_query))
        .toList();
    if (matches.isEmpty) return _NoSearchResults(query: _query);
    return Column(
      children: [
        for (final e in matches)
          _rankRow(
            l10n,
            e,
            position: e.rank == 0 ? result.entries.indexOf(e) + 1 : e.rank,
            isMe: e.userId == widget.currentUserId,
            index: matches.indexOf(e),
          ),
      ],
    );
  }

  void _showScoreInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final me = _result?.me;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lbScoreCalcTitle,
              style: AppText.headlineSm.copyWith(color: AppColors.textPrimary),
            ),
            if (me != null) ...[
              const SizedBox(height: 8),
              Text(
                '${me.score} ${l10n.lbUnitPts}',
                style: AppText.metricLg.copyWith(color: AppColors.textPrimary),
              ),
            ],
            const SizedBox(height: 16),
            _scoreBar(
              l10n.cpCalories,
              (me?.calAdherence ?? 0) / 100,
              AppColors.accentCalories,
            ),
            const SizedBox(height: 10),
            _scoreBar(
              l10n.cpWater,
              (me?.waterAdherence ?? 0) / 100,
              AppColors.accentWater,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.lbScoreFormula,
              style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(String label, double fraction, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppText.labelMd.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(fraction * 100).round()}%',
          style: AppText.labelMd.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _searchField() {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: _searchController,
      style: AppText.bodyMd.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: l10n.lbSearchHint,
        hintStyle: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => _searchController.clear(),
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// Classic podium: 1st centered and taller, 2nd/3rd flanking — reads
  /// instantly as a podium. Category-aware value chip; the winner keeps
  /// the strongest visual emphasis.
  Widget _podium(AppLocalizations l10n, LeaderboardResult result) {
    if (result.entries.length < 3) {
      // Fewer than 3 entries: fall back to simple row so layout never breaks.
      return Row(
        children: [
          for (var i = 0; i < result.entries.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i < result.entries.length - 1 ? 10 : 0,
                ),
                child: _podiumCard(
                  l10n,
                  result.entries[i],
                  i,
                  height: 190,
                ),
              ),
            ),
        ],
      );
    }
    final top = result.entries.take(3).toList();
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _podiumCard(l10n, top[1], 1, height: 190)),
          const SizedBox(width: 10),
          Expanded(child: _podiumCard(l10n, top[0], 0, height: 220)),
          const SizedBox(width: 10),
          Expanded(child: _podiumCard(l10n, top[2], 2, height: 170)),
        ],
      ),
    );
  }

  Widget _podiumCard(
    AppLocalizations l10n,
    LeaderboardEntry e,
    int rankIndex, {
    required double height,
  }) {
    const medals = [
      Icons.emoji_events,
      Icons.workspace_premium,
      Icons.military_tech,
    ];
    final medalColors = [
      AppColors.tierGold,
      AppColors.tierSilver,
      AppColors.tierBronze,
    ];
    final isMe = e.userId == widget.currentUserId;
    // 3rd place card is the shortest — hierarchy says drop its least
    // important line instead of overflowing the fixed podium height.
    final compact = height < 200;
    final avatarRadius = rankIndex == 0 ? 32.0 : (compact ? 20.0 : 24.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openProfile(e);
      },
      child: AnimatedContainer(
        duration: AppDurations.medium,
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMe
                ? AppColors.primaryFixed
                : medalColors[rankIndex].withValues(alpha: 0.5),
            width: isMe ? 2 : 1.5,
          ),
          boxShadow: rankIndex == 0
              ? [
                  BoxShadow(
                    color: AppColors.tierGold.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _avatar(e, radius: avatarRadius),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Icon(
                    medals[rankIndex],
                    color: medalColors[rankIndex],
                    size: rankIndex == 0 ? 26 : 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isMe ? l10n.lbYou : e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.labelMd.copyWith(
                color: isMe ? AppColors.primaryFixed : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _valueChip(e),
            const SizedBox(height: 6),
            LeaderboardStreakBadge(streak: e.currentStreak),
            // The shortest card only fits the days line when no streak
            // badge is taking its slot.
            if (!compact || e.currentStreak <= 0) ...[
              const SizedBox(height: 6),
              Text(
                l10n.rankDaysLogged(e.daysLogged),
                style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Category-aware value chip: tier pill on Overall, unit-valued pill
  /// elsewhere (days for streaks, count for workouts, pts for adherence).
  Widget _valueChip(LeaderboardEntry e) {
    if (_category == LeaderboardCategory.overall) {
      return LeaderboardTierChip(tier: e.tier, score: e.score);
    }
    final l10n = AppLocalizations.of(context)!;
    final unit = switch (_category) {
      LeaderboardCategory.calories => l10n.lbUnitPts,
      LeaderboardCategory.water => l10n.lbUnitPts,
      LeaderboardCategory.workouts => l10n.lbUnitWorkouts,
      LeaderboardCategory.streak => l10n.lbUnitDays,
      LeaderboardCategory.longestStreak => l10n.lbUnitDays,
      LeaderboardCategory.overall => l10n.lbUnitPts,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${e.score} $unit',
        style: AppText.labelSm.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _rankRow(
    AppLocalizations l10n,
    LeaderboardEntry e, {
    required int position,
    required bool isMe,
    required int index,
  }) {
    final rowKey = _rowKeys.putIfAbsent(position, GlobalKey.new);
    final highlight = isMe && _highlightMe;
    final unit = switch (_category) {
      LeaderboardCategory.calories => l10n.lbUnitPts,
      LeaderboardCategory.water => l10n.lbUnitPts,
      LeaderboardCategory.workouts => l10n.lbUnitWorkouts,
      LeaderboardCategory.streak => l10n.lbUnitDays,
      LeaderboardCategory.longestStreak => l10n.lbUnitDays,
      LeaderboardCategory.overall => l10n.lbUnitPts,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 10) * 30)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _openProfile(e);
        },
        child: Container(
          key: rowKey,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primaryFixed.withValues(alpha: highlight ? 0.18 : 0.10)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe
                  ? AppColors.primaryFixed
                  : AppColors.borderSubtle,
              width: isMe ? (highlight ? 2 : 1.5) : 1,
            ),
          ),
          child: Row(
            children: [
              // Rank + movement stacked — the "am I climbing?" glance.
              SizedBox(
                width: 34,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$position',
                      style: AppText.labelMd.copyWith(
                        color: isMe
                            ? AppColors.primaryFixed
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    LeaderboardRankDelta(delta: e.rankDelta, compact: true),
                  ],
                ),
              ),
              _avatar(e, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isMe ? l10n.lbYou : e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelMd.copyWith(
                              color: isMe
                                  ? AppColors.primaryFixed
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.lbYouBadge,
                              style: AppText.labelSm.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    e.currentStreak > 0
                        ? LeaderboardStreakBadge(streak: e.currentStreak)
                        : Text(
                            l10n.rankDaysLogged(e.daysLogged),
                            style: AppText.labelSm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              LeaderboardSparkline(values: e.trend),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${e.score}',
                    style: AppText.labelLg.copyWith(
                      color: isMe
                          ? AppColors.onPrimaryContainer
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    unit,
                    style: AppText.labelSm.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(LeaderboardEntry e, {double radius = 20}) {
    final initial = e.name.isNotEmpty ? e.name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryFixed.withValues(alpha: 0.15),
      backgroundImage: (e.avatarUrl != null && e.avatarUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(e.avatarUrl!)
          : null,
      child: (e.avatarUrl == null || e.avatarUrl!.isEmpty)
          ? Text(
              initial,
              style: AppText.headlineSm.copyWith(
                color: AppColors.primaryFixed,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}

/// Sticky bottom card showing the signed-in client's own position when
/// it scrolls off screen — the core "make it serve the client" fix.
class _MyRankPinnedCard extends StatelessWidget {
  final int position;
  final int score;
  final VoidCallback onTap;

  const _MyRankPinnedCard({
    required this.position,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryFixed.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '#$position',
              style: AppText.headlineSm.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.lbPinJump,
                style: AppText.labelMd.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$score',
              style: AppText.labelMd.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_upward_rounded,
              color: AppColors.onPrimary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholder shaped like the real layout (header, me card,
/// tabs, podium, rows) so the page never shows a bare spinner.
class _LeaderboardSkeleton extends StatefulWidget {
  const _LeaderboardSkeleton();

  @override
  State<_LeaderboardSkeleton> createState() => _LeaderboardSkeletonState();
}

class _LeaderboardSkeletonState extends State<_LeaderboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = 0.35 + 0.25 * (0.5 - (t - 0.5).abs()) * 2;
        return Column(
          children: [
            _skeletonBox(height: 118, opacity: opacity),
            const SizedBox(height: 12),
            _skeletonBox(height: 132, opacity: opacity),
            const SizedBox(height: 14),
            _skeletonBox(height: 36, opacity: opacity, radius: 18),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _skeletonBox(height: 190, opacity: opacity)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBox(height: 220, opacity: opacity)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBox(height: 170, opacity: opacity)),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _skeletonBox(height: 64, opacity: opacity),
              ),
          ],
        );
      },
    );
  }

  Widget _skeletonBox({
    required double height,
    required double opacity,
    double radius = 20,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.lbEmptyCategory,
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.lbEmptyCategorySub,
            textAlign: TextAlign.center,
            style: AppText.labelSm.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  final String query;
  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.lbNoSearchResults(query),
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 32),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
