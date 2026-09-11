import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/app_localizations.dart';
import '../services/rank_service.dart';
import 'client_profile_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Weekly commitment leaderboard — ranked by the server-side score
/// (60% calorie adherence + 40% water adherence, rolling window).
///
/// UX upgrades in this version:
/// - Classic podium (1st centered & taller, 2nd/3rd flanking)
/// - Sticky "your rank" card so the client always sees where they stand,
///   even if they're #142 and nowhere near the visible list
/// - Search field to instantly find a name in a large gym roster
/// - Skeleton shimmer loading instead of a bare spinner
/// - Row entrance animation + haptic feedback on tap
/// - Score breakdown tooltip so the formula isn't a mystery
class LeaderboardScreen extends StatefulWidget {
  /// Pass the signed-in client's userId so we can highlight their row
  /// and pin a "your rank" card if they scroll past it or aren't visible.
  final String? currentUserId;

  const LeaderboardScreen({super.key, this.currentUserId});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final RankService _service = RankService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<LeaderboardEntry>? _entries;
  String? _error;
  int _days = 7;
  String _query = '';
  bool _meVisibleOnScreen = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = null;
    });
    try {
      final entries = await _service.getLeaderboard(days: _days);
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  List<LeaderboardEntry> get _filtered {
    final all = _entries ?? [];
    if (_query.isEmpty) return all;
    return all.where((e) => e.name.toLowerCase().contains(_query)).toList();
  }

  int? get _myIndex {
    if (widget.currentUserId == null || _entries == null) return null;
    final i = _entries!.indexWhere((e) => e.userId == widget.currentUserId);
    return i == -1 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showMePinned =
        _myIndex != null &&
        _myIndex! >= 3 &&
        !_meVisibleOnScreen &&
        _query.isEmpty;

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
            tooltip: '60% calorie adherence + 40% water adherence',
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
            onRefresh: _load,
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
                  Row(
                    children: [
                      _rangeChip(l10n, 7, l10n.rankLast7),
                      const SizedBox(width: 8),
                      _rangeChip(l10n, 30, l10n.rankLast30),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_entries != null && _entries!.length > 5) _searchField(),
                  if (_entries != null && _entries!.length > 5)
                    const SizedBox(height: 16),
                  if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _load)
                  else if (_entries == null)
                    const _LeaderboardSkeleton()
                  else if (_filtered.isEmpty && _query.isNotEmpty)
                    _NoSearchResults(query: _query)
                  else if (_entries!.isEmpty)
                    _EmptyState(l10n: l10n)
                  else if (_query.isNotEmpty)
                    // Search mode: flat filtered list, no podium.
                    for (var i = 0; i < _filtered.length; i++)
                      _rankRow(
                        l10n,
                        _entries!.indexOf(_filtered[i]) + 1,
                        _filtered[i],
                        isMe: _filtered[i].userId == widget.currentUserId,
                        index: i,
                      )
                  else ...[
                    _podium(l10n),
                    const SizedBox(height: 20),
                    for (var i = 3; i < _entries!.length; i++)
                      _rankRow(
                        l10n,
                        i + 1,
                        _entries![i],
                        isMe: _entries![i].userId == widget.currentUserId,
                        index: i - 3,
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Pinned "your rank" bar — the single most useful addition for a
          // client scrolling a long roster: they never lose sight of themselves.
          if (showMePinned)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MyRankPinnedCard(
                position: _myIndex! + 1,
                entry: _entries![_myIndex!],
                onTap: () => _scrollToMe(),
              ),
            ),
        ],
      ),
    );
  }

  void _updateMeVisibility() {
    final i = _myIndex;
    if (i == null || i < 3) return;
    // Rough heuristic: each row ~72px, podium+chips+search header ~260px.
    final rowOffset = 260 + (i - 3) * 72.0;
    final viewTop = _scrollController.hasClients ? _scrollController.offset : 0;
    final viewBottom = viewTop + (_scrollController.position.viewportDimension);
    final visible = rowOffset >= viewTop && rowOffset <= viewBottom;
    if (visible != _meVisibleOnScreen) {
      setState(() => _meVisibleOnScreen = visible);
    }
  }

  void _scrollToMe() {
    final i = _myIndex;
    if (i == null) return;
    final target = 260 + (i - 3) * 72.0;
    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _showScoreInfo(BuildContext context) {
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
              'How your score is calculated',
              style: AppText.headlineSm.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _scoreBar('Calorie adherence', 0.6, AppColors.primaryFixed),
            const SizedBox(height: 10),
            _scoreBar('Water adherence', 0.4, AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Scored over your selected rolling window (7 or 30 days). '
              'Log consistently to climb the board.',
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
          width: 130,
          child: Text(
            label,
            style: AppText.labelMd.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainer,
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
    return TextField(
      controller: _searchController,
      style: AppText.bodyMd.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search a name…',
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

  Widget _rangeChip(AppLocalizations l10n, int days, String label) {
    final active = _days == days;
    return GestureDetector(
      onTap: () {
        if (_days == days) return;
        HapticFeedback.selectionClick();
        _days = days;
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryFixed : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppText.labelMd.copyWith(
            color: active ? AppColors.onPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Classic podium: 1st place centered and taller, 2nd/3rd flanking —
  /// reads instantly as a podium instead of three equal boxes.
  Widget _podium(AppLocalizations l10n) {
    if (_entries!.length < 3) {
      // Fewer than 3 entries: fall back to simple row so layout never breaks.
      return Row(
        children: [
          for (var i = 0; i < _entries!.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i < _entries!.length - 1 ? 10 : 0,
                ),
                child: _podiumCard(l10n, _entries![i], i, height: 190),
              ),
            ),
        ],
      );
    }
    final top = _entries!.take(3).toList();
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
    const medalColors = [
      Color(0xFFE8B93E),
      Color(0xFFB8BFC9),
      Color(0xFFCE8A5B),
    ];
    final isMe = e.userId == widget.currentUserId;
    final avatarRadius = rankIndex == 0 ? 32.0 : 24.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _openProfile(e);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
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
                    color: medalColors[0].withValues(alpha: 0.25),
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
              isMe ? 'You' : e.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.labelMd.copyWith(
                color: isMe ? AppColors.primaryFixed : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _tierChip(e.tier, e.score),
            const SizedBox(height: 6),
            Text(
              l10n.rankDaysLogged(e.daysLogged),
              style: AppText.labelSm.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rankRow(
    AppLocalizations l10n,
    int position,
    LeaderboardEntry e, {
    required bool isMe,
    required int index,
  }) {
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.primaryFixed.withValues(alpha: 0.10)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMe ? AppColors.primaryFixed : AppColors.borderSubtle,
              width: isMe ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#$position',
                  style: AppText.labelMd.copyWith(
                    color: isMe
                        ? AppColors.primaryFixed
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
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
                            isMe ? 'You' : e.name,
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
                              'YOU',
                              style: AppText.labelSm.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.rankDaysLogged(e.daysLogged),
                      style: AppText.labelSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _tierChip(e.tier, e.score),
            ],
          ),
        ),
      ),
    );
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

  Widget _tierChip(RankTier tier, int score) {
    final colors = _tierColors(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${colors.$2} $score',
        style: AppText.labelSm.copyWith(
          color: colors.$1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

(Color, String) _tierColors(RankTier tier) => switch (tier) {
  RankTier.diamond => (const Color(0xFF4DC591), '💎'),
  RankTier.gold => (const Color(0xFFE8B93E), '🥇'),
  RankTier.silver => (const Color(0xFF9AA3AF), '🥈'),
  RankTier.bronze => (const Color(0xFFCE8A5B), '🥉'),
  RankTier.unranked => (AppColors.textSecondary, '—'),
};

/// Sticky bottom card showing the signed-in client's own position when
/// it scrolls off screen — the core "make it serve the client" fix.
class _MyRankPinnedCard extends StatelessWidget {
  final int position;
  final LeaderboardEntry entry;
  final VoidCallback onTap;

  const _MyRankPinnedCard({
    required this.position,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _tierColors(entry.tier);
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
                'Your rank — tap to jump there',
                style: AppText.labelMd.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${colors.$2} ${entry.score}',
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

/// Shimmering placeholder rows — replaces the bare spinner so the layout
/// (podium + list) is legible the instant data streams in.
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
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _skeletonBox(height: 60, opacity: opacity),
              ),
          ],
        );
      },
    );
  }

  Widget _skeletonBox({required double height, required double opacity}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(18),
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
            l10n.rankEmpty,
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Log a meal or a workout today to claim the first spot.',
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
            'No one named "$query" on this leaderboard',
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
