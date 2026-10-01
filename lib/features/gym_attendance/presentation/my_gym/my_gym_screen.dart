import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/attendance_day.dart';
import '../../data/gym.dart';
import '../../data/gym_service.dart';
import '../../data/selected_gym.dart';
import '../gym_attendance_flow_screen.dart';
import '../map/gym_map_picker_screen.dart';
import '../widgets/attendance_heatmap.dart';

// Live in-progress sessions have no backend yet: [_activeSession] stays null
// and its row stays hidden until a real `GymService.getActiveSession()`
// exists. Manual check-in ([GymService.recordManualCheckIn]) and the
// optional [Gym.address] are implemented.

/// Placeholder shape for an in-progress (not-yet-confirmed) geofence
/// session — move to the data layer once a real active-session lookup exists.
class _ActiveSession {
  final String gymName;
  final DateTime checkInTime;

  const _ActiveSession({required this.gymName, required this.checkInTime});

  int get minutesSoFar => DateTime.now().difference(checkInTime).inMinutes;
}

/// The configured gym's home surface — "Kinetic Pulse" layout (owner's
/// Stitch redesign): telemetry status strip, facility hero card, a metrics
/// grid driven by the Week/Month/Year toggle, the attendance matrix
/// (GitHub-style heatmap with a selected-day bar), the recent check-ins
/// list (including a live in-progress session when one is active), and a
/// persistent bottom action bar. Lives in two places: as the final step of
/// [GymAttendanceFlowScreen] and pushed directly from the profile entry
/// card once a gym is configured.
///
/// Everything reads from the existing gyms/gym_attendance rows — no new
/// data beyond the active-session lookup noted above.
class MyGymScreen extends StatefulWidget {
  const MyGymScreen({super.key});

  @override
  State<MyGymScreen> createState() => _MyGymScreenState();
}

class _MyGymScreenState extends State<MyGymScreen> {
  final GymService _gymService = GymService();

  Gym? _gym;
  bool _loading = true;
  bool _changing = false;

  /// Date-only keys → that day's longest dwell. Null until the first load
  /// resolves; the log section stays hidden until then.
  Map<DateTime, AttendanceDay>? _history;

  /// Raw rows for the recent check-ins list.
  List<AttendanceRecord> _recent = const [];

  /// In-progress geofence session, if the user is inside the gym's area
  /// right now (not yet past the attendance threshold). Shown as the first,
  /// visually distinct row in "Recent check-ins".
  _ActiveSession? _activeSession;

  /// Set briefly after a "Signal Ping" tap — round-trip time of a
  /// lightweight service call, used as an approximate geofence-health
  /// check until a real ping endpoint exists.
  Duration? _pingLatency;
  bool _pinging = false;

  bool _manualCheckingIn = false;

  /// The log section's range — the segmented toggle next to the metrics
  /// title flips the stat tiles AND the matrix below. Defaults to the year
  /// grid (the reference image).
  AttendanceHeatmapRange _logRange = AttendanceHeatmapRange.year;

  /// Day highlighted under the matrix (tap a cell — design's selected-day
  /// bar). Reset when the range flips.
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Strips any time-of-day / DST-shifted hour so every map lookup uses a
  /// canonical local-midnight key — the same shape [GymService] stores.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `days` ago from [today], built via the calendar constructor (not
  /// `subtract(Duration(days: …))`) so a 23/25h DST day can't shift the key
  /// to 23:00 of the previous day and silently zero out the stats.
  static DateTime _daysAgo(DateTime today, int days) =>
      DateTime(today.year, today.month, today.day - days);

  Future<void> _load() async {
    try {
      // Parallel: three independent reads, one wait instead of three.
      final results = await Future.wait([
        _gymService.getActiveGym(),
        _gymService.getAttendanceSince(
          DateTime.now().subtract(const Duration(days: 371)),
        ),
        _gymService.getRecentAttendance(limit: 4),
      ]);
      if (!mounted) return;
      final history = (results[1] as Map<DateTime, AttendanceDay>).map(
        (k, v) => MapEntry(_dateOnly(k), v),
      );
      setState(() {
        _gym = results[0] as Gym?;
        _history = history;
        _recent = results[2] as List<AttendanceRecord>;
        // No active-session backend yet — row stays hidden.
        _activeSession = null;
        // Drop a stale selection whose day is no longer in range/data.
        if (_selectedDay != null &&
            !history.containsKey(_dateOnly(_selectedDay!))) {
          _selectedDay = null;
        }
        _loading = false;
      });
    } catch (_) {
      // Reads already swallow errors into empty values; this is only for
      // truly unexpected failures — never leave the spinner up forever.
      if (!mounted) return;
      setState(() {
        _history ??= const {};
        _loading = false;
      });
    }
  }

  Future<void> _openFlow() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GymAttendanceFlowScreen()));
    if (mounted) _load();
  }

  Future<void> _changeGym() async {
    if (_changing) return;
    setState(() => _changing = true);
    try {
      final gym = await Navigator.of(context).push<SelectedGym>(
        MaterialPageRoute(builder: (_) => const GymMapPickerScreen()),
      );
      if (gym == null) return;
      await _gymService.saveGym(gym);
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: Text(AppLocalizations.of(context)!.gymAttSaveError),
        ),
      );
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  /// "Signal Ping" — approximate geofence/connection health check. Times a
  /// lightweight existing call (`getActiveGym`) as a stand-in round-trip
  /// measurement until a dedicated health-check endpoint exists.
  Future<void> _signalPing() async {
    if (_pinging) return;
    setState(() {
      _pinging = true;
      _pingLatency = null;
    });
    final sw = Stopwatch()..start();
    try {
      await _gymService.getActiveGym();
    } catch (_) {
      // Swallow — a failed ping just shows no latency below.
    } finally {
      sw.stop();
      if (mounted) {
        setState(() {
          _pinging = false;
          _pingLatency = sw.elapsed;
        });
      }
    }
  }

  Future<void> _manualCheckIn() async {
    if (_manualCheckingIn) return;
    setState(() => _manualCheckingIn = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final ok = await _gymService.recordManualCheckIn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok
              ? AppColors.surfaceContainerHigh
              : AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: Text(
            ok ? l10n.gymAttManualCheckInSuccess : l10n.gymAttSaveError,
          ),
        ),
      );
      if (ok) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.gymAttSaveError),
        ),
      );
    } finally {
      if (mounted) setState(() => _manualCheckingIn = false);
    }
  }

  void _openFullLog() {
    final history = _history;
    if (history == null) return;
    final l10n = AppLocalizations.of(context)!;
    final sortedDays = history.keys.toList()..sort((a, b) => b.compareTo(a));
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Text(
                l10n.gymAttRecentTitle,
                style: AppText.headlineSm.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: sortedDays.length,
                  itemBuilder: (context, index) {
                    final day = sortedDays[index];
                    final minutes = history[day]?.minutes ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat(
                                'EEE, d MMM',
                                l10n.localeName,
                              ).format(day),
                              style: AppText.bodyMd.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            minutes > 0
                                ? _formatDuration(l10n, minutes)
                                : l10n.gymAttHeatmapNoVisit,
                            style: AppText.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats ──

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Visits in the rolling last 7 days.
  int get _weekCount {
    final history = _history;
    if (history == null) return 0;
    final today = _today;
    var count = 0;
    for (var i = 0; i < 7; i++) {
      if (history.containsKey(_daysAgo(today, i))) count++;
    }
    return count;
  }

  int get _monthCount {
    final history = _history;
    if (history == null) return 0;
    final today = _today;
    return history.keys
        .where((d) => d.month == today.month && d.year == today.year)
        .length;
  }

  /// Consecutive attended days ending today (or yesterday when today's visit
  /// hasn't happened yet).
  int get _streak {
    final history = _history;
    if (history == null) return 0;
    var day = _today;
    if (!history.containsKey(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var streak = 0;
    while (history.containsKey(day)) {
      streak++;
      // Calendar arithmetic (not Duration) so a 23/25h DST day can't drift
      // the key to 23:00 and break the chain.
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  DateTime? get _lastVisit {
    final history = _history;
    if (history == null || history.isEmpty) return null;
    return history.keys.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Average visits per week over the last 4 weeks (28 days) — recent
  /// behavior rather than lifetime, so slacking off shows up quickly.
  double get _weeklyAverage {
    final history = _history;
    if (history == null) return 0;
    final today = _today;
    var count = 0;
    for (var i = 0; i < 28; i++) {
      if (history.containsKey(_daysAgo(today, i))) count++;
    }
    return count / 4;
  }

  /// Average visits per month over the last 3 months (90 days).
  double get _monthlyAverage {
    final history = _history;
    if (history == null) return 0;
    final today = _today;
    var count = 0;
    for (var i = 0; i < 90; i++) {
      if (history.containsKey(_daysAgo(today, i))) count++;
    }
    return count / 3;
  }

  /// Visits in the rolling last 365 days.
  int get _yearCount {
    final history = _history;
    if (history == null) return 0;
    final today = _today;
    var count = 0;
    for (var i = 0; i < 365; i++) {
      if (history.containsKey(_daysAgo(today, i))) count++;
    }
    return count;
  }

  /// Year-wide pace expressed per month (year count ÷ 12).
  double get _yearlyMonthlyAverage => _yearCount / 12;

  /// Average dwell across every attended day (minutes > 0).
  int? get _avgDwell {
    final history = _history;
    if (history == null || history.isEmpty) return null;
    final attended = history.values.where((d) => d.minutes > 0).toList();
    if (attended.isEmpty) return null;
    final total = attended.fold<int>(0, (sum, d) => sum + d.minutes);
    return total ~/ attended.length;
  }

  // Range-scoped values for the metric tiles (toggle-driven).
  int get _rangeCount => switch (_logRange) {
    AttendanceHeatmapRange.week => _weekCount,
    AttendanceHeatmapRange.month => _monthCount,
    AttendanceHeatmapRange.year => _yearCount,
  };

  double get _rangeAverage => switch (_logRange) {
    AttendanceHeatmapRange.week => _weeklyAverage,
    AttendanceHeatmapRange.month => _monthlyAverage,
    AttendanceHeatmapRange.year => _yearlyMonthlyAverage,
  };

  String _rangeUnit(AppLocalizations l10n) => switch (_logRange) {
    AttendanceHeatmapRange.week => l10n.gymAttPerWeek,
    _ => l10n.gymAttPerMonth,
  };

  /// Rolling-window length (days) matching the current toggle — used for
  /// both the average calc above and the trend delta below.
  int get _rangeWindowDays => switch (_logRange) {
    AttendanceHeatmapRange.week => 7,
    AttendanceHeatmapRange.month => 30,
    AttendanceHeatmapRange.year => 365,
  };

  /// Percent change vs. the immediately preceding window of the same
  /// length (e.g. this week vs. last week). Null when there's no prior
  /// data to compare against, so the tile can omit the delta cleanly.
  double? get _visitsDeltaPercent {
    final history = _history;
    if (history == null) return null;
    final windowDays = _rangeWindowDays;
    final today = _today;
    int countInWindow(int offsetDays) {
      var count = 0;
      for (var i = 0; i < windowDays; i++) {
        if (history.containsKey(_daysAgo(today, offsetDays + i))) {
          count++;
        }
      }
      return count;
    }

    final current = countInWindow(0);
    final previous = countInWindow(windowDays);
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  /// Short trend suffix matching the active range (WoW / MoM / YoY).
  String get _deltaSuffix => switch (_logRange) {
    AttendanceHeatmapRange.week => 'WoW',
    AttendanceHeatmapRange.month => 'MoM',
    AttendanceHeatmapRange.year => 'YoY',
  };

  /// "3" when whole, "2.5" when fractional.
  String _formatAverage(double value) => value == value.roundToDouble()
      ? '${value.round()}'
      : value.toStringAsFixed(1);

  /// "1h 18m" / "47m" style — Arabic "1س 18د".
  String _formatDuration(AppLocalizations l10n, int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0
          ? l10n.gymAttDurationH('$h')
          : l10n.gymAttDurationHM('$h', '$m');
    }
    return l10n.gymAttDurationM('$minutes');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, l10n),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_gym != null) ...[
                            _statusStrip(l10n),
                            const SizedBox(height: 16),
                            _facilityCard(l10n),
                          ] else ...[
                            _setupCta(l10n),
                          ],
                          const SizedBox(height: 24),
                          _metricsSection(l10n),
                          const SizedBox(height: 24),
                          _matrixCard(l10n),
                          if (_activeSession != null || _recent.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _recentHeader(l10n),
                            const SizedBox(height: 12),
                            if (_activeSession != null)
                              _activeSessionRow(l10n, _activeSession!),
                            for (final record in _recent)
                              _recentRow(l10n, record),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _gym == null ? null : _buildBottomBar(l10n),
    );
  }

  /// Header — back arrow, centered screen title, and (1) settings action +
  /// profile avatar trailing (design's top-right icon pair).
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              l10n.gymAttMyGymTitle,
              style: AppText.headlineSm.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  size: 22,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.gymAttSettingsTooltip,
                    onPressed: () {
                      // TODO: route to the gym-attendance-specific settings
                      // screen once it exists (tracking sensitivity, radius
                      // override, etc.) — not yet implemented.
                    },
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 2),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    child: Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Telemetry strip — tracking label + active geofence chip, one pill row.
  Widget _statusStrip(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.gymAttTrackingOn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.glassBorderActive),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.radar_rounded,
                  size: 13,
                  color: AppColors.onPrimaryContainer,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.gymAttGeofenceActive,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Facility hero card — accent-tinted glass, gym name + address, radius +
  /// auto tracking pills, a two-action row (change / signal ping) and the
  /// last-session row.
  Widget _facilityCard(AppLocalizations l10n) {
    final gym = _gym!;
    final lastVisit = _lastVisit;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorderActive),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.gymAttFacilityLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.gps_fixed_rounded,
                size: 16,
                color: AppColors.onPrimaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            gym.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.headlineLg.copyWith(
              color: AppColors.textPrimary,
              fontSize: 26,
              height: 1.12,
            ),
          ),
          if ((gym.address ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 13,
                  color: AppColors.onPrimaryContainer,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    gym.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Stacked full-width status rows, per the design's facility card.
          _pillRow(
            Icons.radar_rounded,
            l10n.gymAttRadiusValue('${gym.radiusM}'),
          ),
          const SizedBox(height: 8),
          _pillRow(Icons.check_circle_rounded, l10n.gymAttAutoPill),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _changing ? null : _changeGym,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.borderSubtle),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppText.buttonSecondary,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.gymAttChangeGym,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pinging ? null : _signalPing,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.borderSubtle),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: AppText.buttonSecondary,
                  ),
                  child: _pinging
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_tethering_rounded, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _pingLatency == null
                                    ? l10n.gymAttSignalPing
                                    : l10n.gymAttSignalPingMs(
                                        '${_pingLatency!.inMilliseconds}',
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (lastVisit != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                // spaceBetween, NOT a Spacer: Spacer is a tight Flexible and
                // halves the free space with the value's Flexible, ellipsizing
                // the date mid-string (seen live: "Wed, 30 Sep • …").
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: AppColors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.gymAttLastSession,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '${DateFormat('EEE, d MMM', l10n.localeName).format(lastVisit)}'
                      ' • ${_formatDuration(l10n, _history?[_dateOnly(lastVisit)]?.minutes ?? 0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Full-width status row inside the facility card (design anatomy).
  Widget _pillRow(IconData icon, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback when no gym is configured yet — straight into the flow.
  Widget _setupCta(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.gymAttEntryDesc,
            style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _openFlow,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryFixed,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: AppText.buttonPrimary,
            ),
            child: Text(l10n.gymAttEntryTitle),
          ),
        ],
      ),
    );
  }

  // ── Metrics ──

  Widget _metricsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.gymAttMetricsTitle.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Design's "METRICS VOLUME ●" telemetry dot.
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                // Scale-down instead of overflowing on narrow screens:
                // the 3-segment toggle's intrinsic width (~250px) + title
                // exceeds 320px cards → was a 28px RenderFlex overflow.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: _buildModeToggle(l10n),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                l10n.gymAttTotalVisits,
                Icons.calendar_month_rounded,
                '$_rangeCount',
                delta: _visitsDeltaPercent,
                deltaSuffix: _deltaSuffix,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                l10n.gymAttPaceAvg,
                Icons.speed_rounded,
                _formatAverage(_rangeAverage),
                unit: _rangeUnit(l10n),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _metricTile(
                l10n.gymAttStatsStreak,
                Icons.local_fire_department_rounded,
                '$_streak',
                unit: l10n.gymAttStatsDays('$_streak'),
                badge: _streak >= 5 ? l10n.gymAttHotBadge : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricTile(
                l10n.gymAttAvgDwell,
                Icons.timer_rounded,
                _avgDwell == null ? '—' : _formatDuration(l10n, _avgDwell!),
                unit: _avgDwell == null ? null : l10n.gymAttPerSession,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricTile(
    String label,
    IconData icon,
    String value, {
    String? unit,
    String? badge,
    double? delta,
    String? deltaSuffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(icon, size: 15, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.headlineMd.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              // Design's telemetry readouts: stable digits, no width wobble.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (unit != null) ...[
            const SizedBox(height: 3),
            Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
            ),
          ],
          if (delta != null && deltaSuffix != null) ...[
            const SizedBox(height: 3),
            Text(
              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% $deltaSuffix',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: delta >= 0 ? AppColors.accent : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Weekly/Monthly/Yearly pill toggle — same mini-segmented language as the
  /// profile Appearance switcher (lime-tinted selected segment). Drives the
  /// metric tiles AND the matrix below.
  Widget _buildModeToggle(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeSegment(l10n.gymAttViewWeekly, AttendanceHeatmapRange.week),
          _modeSegment(l10n.gymAttViewMonthly, AttendanceHeatmapRange.month),
          _modeSegment(l10n.gymAttViewYearly, AttendanceHeatmapRange.year),
        ],
      ),
    );
  }

  Widget _modeSegment(String label, AttendanceHeatmapRange range) {
    final selected = _logRange == range;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: selected
          ? null
          : () => setState(() {
              _logRange = range;
              _selectedDay = null;
            }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.lightGreen
              : AppColors.lightGreen.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppColors.onPrimaryContainer
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Attendance matrix ──

  Widget _matrixCard(AppLocalizations l10n) {
    final subtitle = switch (_logRange) {
      AttendanceHeatmapRange.week => l10n.gymAttMatrixSubWeek,
      AttendanceHeatmapRange.month => l10n.gymAttMatrixSubMonth,
      AttendanceHeatmapRange.year => l10n.gymAttMatrixSubYear,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gymAttMatrixTitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _heatLegend(l10n),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: AttendanceHeatmap(
                key: ValueKey(_logRange),
                data: _history ?? const {},
                anchor: _today,
                localeName: l10n.localeName,
                range: _logRange,
                onDayTap: (day) => setState(() {
                  final normalized = _dateOnly(day);
                  _selectedDay =
                      _selectedDay != null &&
                          _dateOnly(_selectedDay!) == normalized
                      ? null
                      : normalized;
                }),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _selectedDay == null
                ? const SizedBox.shrink(key: ValueKey('no-selection'))
                : _dayDetailRow(l10n, _selectedDay!),
          ),
        ],
      ),
    );
  }

  /// Less → More intensity legend, same scale as the matrix cells.
  Widget _heatLegend(AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.gymAttHeatLess,
          style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
        ),
        const SizedBox(width: 4),
        for (var level = 0; level <= 4; level++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: AttendanceHeatmap.levelColor(level),
              borderRadius: BorderRadius.circular(2),
              border: level == 0
                  ? Border.all(color: AppColors.borderSubtle)
                  : null,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          l10n.gymAttHeatMore,
          style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  /// Selected-day bar — design's two-line detail strip under the matrix:
  /// bold date on top, dwell + verification under, volt bolt badge leading.
  Widget _dayDetailRow(AppLocalizations l10n, DateTime day) {
    final normalized = _dateOnly(day);
    final minutes = _history?[normalized]?.minutes ?? 0;
    final visited = minutes > 0;
    return Container(
      key: ValueKey(normalized),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: visited ? AppColors.accent : AppColors.lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 18,
              color: visited
                  ? AppColors.onPrimary
                  : AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, d MMM', l10n.localeName).format(day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMd.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  visited
                      ? '${_formatDuration(l10n, minutes)} • ${l10n.gymAttRowGeofence}'
                      : l10n.gymAttHeatmapNoVisit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent check-ins ──

  Widget _recentHeader(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.gymAttRecentTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (_history != null)
          GestureDetector(
            onTap: _openFullLog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.gymAttViewFullLog,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Live, in-progress geofence session — the user is inside the gym's area
  /// right now but hasn't crossed the attendance threshold yet. Visually
  /// distinct from completed rows: "Inside Zone" pill + manual confirm.
  Widget _activeSessionRow(AppLocalizations l10n, _ActiveSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorderActive, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.navigation_rounded,
              size: 17,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.gymName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleSm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.gymAttSessionInProgress('${session.minutesSoFar}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.onPrimaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              l10n.gymAttInsideZone.toUpperCase(),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.lightGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentRow(AppLocalizations l10n, AttendanceRecord record) {
    final times = record.checkIn == null
        ? null
        : '${DateFormat('HH:mm', l10n.localeName).format(record.checkIn!.toLocal())}'
              '${record.checkOut == null ? '' : ' – ${DateFormat('HH:mm', l10n.localeName).format(record.checkOut!.toLocal())}'}';
    final subtitleParts = <String>[
      if (times != null) times,
      if (record.minutes > 0) _formatDuration(l10n, record.minutes),
      l10n.gymAttRowGeofence,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.near_me_rounded,
              size: 17,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, d MMM', l10n.localeName).format(record.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleSm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                // Two lines — "19:11 – 19:36 • 25m • Geofence verified" is
                // wider than the row on small screens; one line cut it mid-
                // word ("Geofence veri…").
                Text(
                  subtitleParts.join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Design: "COMPLETED" as glowing caps telemetry text, not a pill.
          Text(
            l10n.gymAttRowCompleted.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom action bar ──

  Widget _buildBottomBar(AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _manualCheckingIn ? null : _manualCheckIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: AppText.buttonPrimary,
                  ),
                  child: _manualCheckingIn
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded, size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l10n.gymAttManualCheckInNow,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: same settings destination as the header's tune
                  // icon — route once that screen exists.
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  side: BorderSide(color: AppColors.borderSubtle),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Icon(Icons.tune_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
