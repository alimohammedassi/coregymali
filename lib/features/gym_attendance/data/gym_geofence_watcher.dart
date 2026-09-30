import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'gym.dart';
import 'gym_service.dart';

/// Detection state of the in-app geofence watcher.
///
/// There is deliberately NO "exited/left" state: leaving the area simply
/// discards (or already-recorded) session data and returns to [idle].
enum GymGeofenceState {
  /// No active session — the watcher only watches (or is not even armed).
  idle,

  /// The user is inside the gym's radius and a dwell session is running;
  /// the home banner shows the countdown.
  inside,

  /// The visit was recorded (25-minute dwell completed). Transient — the
  /// watcher returns to [idle] after a short confirmation echo.
  confirmed,
}

/// Foreground-only automatic gym-visit detection.
///
/// Pure in-app: a medium-accuracy position stream from geolocator checked
/// against the active gym's radius. No background plugin, no notifications —
/// the only output is this ChangeNotifier, which the home banner listens to.
///
/// State machine:
/// - ENTER  (distance <= radius, and not suppressed by a same-visit cancel):
///   a dwell session starts and the 25-minute countdown runs.
/// - 25:00  reached: the visit is recorded via [GymService.recordAttendance],
///   state flips to [GymGeofenceState.confirmed] for a 5 s echo, then [idle].
/// - EXIT   (distance > radius + hysteresis margin) while still inside:
///   the session is discarded silently and the state returns to [idle].
/// - Cancelling from the banner while still physically inside suppresses
///   re-alerting: only a real EXIT followed by a fresh ENTER re-arms.
///
/// Battery rules: the position stream is the ONLY always-on resource (medium
/// accuracy, 25 m distance filter); the 1 s dwell timer exists only while a
/// session is running. GPS dropouts are swallowed — the state never regresses
/// because of a stream error.
class GymGeofenceWatcher extends ChangeNotifier {
  GymGeofenceWatcher._();

  /// App-lifetime singleton — home and the banner both listen to [instance].
  static final GymGeofenceWatcher instance = GymGeofenceWatcher._();

  /// Dwell time required before a visit is recorded.
  static const dwellMinutes = 25;

  /// EXIT hysteresis: leaving is only detected beyond radius + this margin,
  /// so boundary jitter (GPS noise around the fence line) never flickers
  /// the session.
  static const int _exitMarginM = 40;

  /// How long the [GymGeofenceState.confirmed] echo stays visible.
  static const Duration _confirmedEcho = Duration(seconds: 5);

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 25,
  );

  final GymService _gymService = GymService();

  GymGeofenceState _state = GymGeofenceState.idle;
  Gym? _gym;
  StreamSubscription<Position>? _positionSub;
  Timer? _dwellTimer;
  Timer? _confirmedTimer;
  bool _started = false;

  /// Set when a session ends while the user is still physically inside
  /// (banner cancel, or the auto-record echo) — blocks an immediate re-enter
  /// until a real EXIT re-arms detection.
  bool _needsExitBeforeRearm = false;

  /// When the current dwell session started (null when not [inside]).
  DateTime? sessionStart;

  /// Minutes recorded for the last completed visit — feeds the banner's
  /// confirmation line. Null until a visit completes.
  int? confirmedMinutes;

  /// Live straight-line distance to the gym, meters. Best-effort diagnostic;
  /// no UI animates off it (no notifyListeners per fix).
  double? currentDistanceM;

  GymGeofenceState get state => _state;

  /// Time left before the visit is recorded, or null when not [inside].
  /// Clamps at zero so a slow final tick reads 00:00, never negative.
  Duration? get remainingDwell {
    final start = sessionStart;
    if (_state != GymGeofenceState.inside || start == null) return null;
    final left =
        const Duration(minutes: dwellMinutes) - DateTime.now().difference(start);
    return left.isNegative ? Duration.zero : left;
  }

  /// Arms the watcher once per app open. Idempotent: a second call is a
  /// no-op — use [refresh] to re-evaluate gym/permission after changes.
  /// Without a configured gym or when-in-use permission the watcher stays
  /// [GymGeofenceState.idle] and does nothing.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _reloadAndSync();
  }

  /// Re-loads the active gym + permission and (re)starts detection if
  /// needed. Called after the user configures/changes their gym so a new
  /// gym starts detecting without an app restart.
  Future<void> refresh() => _reloadAndSync();

  Future<void> _reloadAndSync() async {
    final gym = await _gymService.getActiveGym();
    final granted = await _hasWhenInUsePermission();
    final gymChanged = gym?.id != _gym?.id;
    _gym = gym;

    if (gym == null || !granted) {
      await _stopPositionStream();
      if (_state == GymGeofenceState.inside) _discardSession();
      return;
    }
    // The active gym changed mid-session — the dwell no longer refers to a
    // real visit at the configured fence, so drop it silently.
    if (gymChanged && _state == GymGeofenceState.inside) _discardSession();
    await _startPositionStream();
  }

  Future<bool> _hasWhenInUsePermission() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startPositionStream() async {
    if (_positionSub != null) return;
    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        _onPosition,
        // GPS dropouts / transient plugin errors must never crash the app
        // or regress the state — ignore and let the next fix speak.
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('GymGeofenceWatcher: position stream failed: $e');
      _positionSub = null;
    }
  }

  Future<void> _stopPositionStream() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  void _onPosition(Position position) {
    final gym = _gym;
    if (gym == null) return;
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      gym.latitude,
      gym.longitude,
    );
    currentDistanceM = distance;

    // Real EXIT — only beyond the fence plus hysteresis margin. Always
    // re-arms detection for a future visit, wherever we currently are.
    if (distance > gym.radiusM + _exitMarginM) {
      _needsExitBeforeRearm = false;
      if (_state == GymGeofenceState.inside) _discardSession();
      return;
    }

    switch (_state) {
      case GymGeofenceState.idle:
        // ENTER — also covers "app opened while already inside".
        if (!_needsExitBeforeRearm) _enter();
      case GymGeofenceState.inside:
      case GymGeofenceState.confirmed:
        // Inside and already tracked (or already recorded) — nothing to do.
        break;
    }
  }

  // ── Session lifecycle ──────────────────────────────────────────────────

  void _enter() {
    _state = GymGeofenceState.inside;
    sessionStart = DateTime.now();
    // Single 1 s ticker, alive ONLY while the session runs — it drives the
    // banner's mm:ss countdown and fires the auto-record at 25:00.
    _dwellTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void _tick() {
    if (_state != GymGeofenceState.inside) return;
    final remaining = remainingDwell;
    if (remaining != null && remaining <= Duration.zero) {
      // Paint 00:00 once before the (async) record flips the banner to the
      // confirmation state.
      notifyListeners();
      unawaited(_completeSession());
      return;
    }
    notifyListeners();
  }

  /// 25:00 reached — record the visit, flash the confirmation, collapse.
  Future<void> _completeSession() async {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    final start = sessionStart;
    if (start == null) {
      _resetToIdle();
      return;
    }
    final elapsed = DateTime.now().difference(start).inMinutes;
    final minutes = elapsed < dwellMinutes ? dwellMinutes : elapsed;
    // A cancel during the write must win over the auto-record.
    if (_state != GymGeofenceState.inside) return;

    await _gymService.recordAttendance(
      sessionStart: start,
      durationMinutes: minutes,
    );
    if (_state != GymGeofenceState.inside) return;

    sessionStart = null;
    confirmedMinutes = minutes;
    _needsExitBeforeRearm = true;
    _state = GymGeofenceState.confirmed;
    notifyListeners();
    _confirmedTimer = Timer(_confirmedEcho, () {
      _confirmedTimer = null;
      if (_state == GymGeofenceState.confirmed) _resetToIdle();
    });
  }

  /// EXIT while inside (< 25 min): the dwell never matured — discard the
  /// session silently and stop counting.
  void _discardSession() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    sessionStart = null;
    _resetToIdle();
  }

  /// Banner cancel. The user may still be physically inside, so detection
  /// is suppressed until a real EXIT re-arms it — no banner re-fire loop.
  void cancelSession() {
    if (_state == GymGeofenceState.idle) return;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _confirmedTimer?.cancel();
    _confirmedTimer = null;
    sessionStart = null;
    _needsExitBeforeRearm = true;
    _resetToIdle();
  }

  void _resetToIdle() {
    if (_state == GymGeofenceState.idle) return;
    _state = GymGeofenceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _confirmedTimer?.cancel();
    _positionSub?.cancel();
    _positionSub = null;
    super.dispose();
  }
}
