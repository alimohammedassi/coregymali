import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_animations.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../data/location_service.dart';
import '../../data/selected_gym.dart';

/// OSM tile + Nominatim endpoints. Nominatim policy requires a descriptive
/// User-Agent; tiles need no custom UA client-side (flutter_map sends one
/// built from [TileLayer.userAgentPackageName]).
const String _kNominatimBase = 'https://nominatim.openstreetmap.org';
const Map<String, String> _kNominatimHeaders = {
  'User-Agent': 'CoreGym/1.0 (fitness app)',
};
const String _kTileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const Duration _kHttpTimeout = Duration(seconds: 10);

/// Default map center (Cairo) shown while locating / when location fails.
const LatLng _kDefaultCenter = LatLng(30.0444, 31.2357);

/// Geofence radius in meters — fixed for Phase 1.
const int _kTrackingRadiusM = 120;

class _SearchResult {
  final String name;
  final double lat;
  final double lon;
  const _SearchResult({required this.name, required this.lat, required this.lon});
}

/// Tap-to-place gym picker on an OpenStreetMap slippy map.
///
/// Two usage modes:
///  - Pushed as a route (MyGym "change gym"): pops with a [SelectedGym].
///  - Embedded in the onboarding flow (body-built step): calls [onSelected]
///    instead of popping, so the flow host never pushes a nested route.
class GymMapPickerScreen extends StatefulWidget {
  /// Embedded mode callback. When null, the screen pops with the result.
  final ValueChanged<SelectedGym>? onSelected;

  const GymMapPickerScreen({super.key, this.onSelected});

  @override
  State<GymMapPickerScreen> createState() => _GymMapPickerScreenState();
}

class _GymMapPickerScreenState extends State<GymMapPickerScreen>
    with SingleTickerProviderStateMixin {
  final LocationService _location = LocationService();
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Repeating pulse for the locating skeleton.
  late final AnimationController _skeletonCtrl;

  Timer? _searchDebounce;
  bool _mapReady = false;

  LatLng _center = _kDefaultCenter;
  LatLng? _pin;
  int _pinPlacement = 0; // bumped on every placement → re-runs the pin/circle entrance
  String _gymName = '';
  double? _pinDistance;

  Position? _userPosition;
  bool _locating = true;
  bool _locFailed = false;

  bool _searching = false;
  bool _searchFailed = false;
  List<_SearchResult> _results = [];

  int _reverseToken = 0;
  bool _reverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    _skeletonCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.ambient,
      lowerBound: .35,
      upperBound: 1,
    )..repeat(reverse: true);
    _locate();
  }

  @override
  void dispose() {
    _skeletonCtrl.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locFailed = false;
    });
    final pos = await _location.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _locating = false;
        _locFailed = true;
      });
      return;
    }
    final ll = LatLng(pos.latitude, pos.longitude);
    _centerOn(ll, zoom: 16);
    setState(() {
      _locating = false;
      _userPosition = pos;
      _pin = ll;
      _pinPlacement++;
      _gymName = '';
      _reverseGeocoding = true;
    });
    _updateDistance();
    _reverseGeocode(ll);
  }

  void _centerOn(LatLng ll, {double zoom = 16}) {
    _center = ll;
    if (_mapReady) _mapController.move(ll, zoom);
  }

  // ── Pin placement + reverse geocoding ─────────────────────────────────────

  void _movePin(LatLng ll, {String? name}) {
    _reverseToken++; // invalidate any in-flight reverse geocode
    _searchFocus.unfocus();
    setState(() {
      _pin = ll;
      _pinPlacement++;
      _gymName = name ?? '';
      _results = [];
      _searchFailed = false;
      _reverseGeocoding = name == null;
    });
    _updateDistance();
    if (name == null) _reverseGeocode(ll);
  }

  Future<double?> _distanceToUser(LatLng ll) async {
    final user = _userPosition;
    if (user == null) return null;
    return _location.distanceBetween(
      user.latitude,
      user.longitude,
      ll.latitude,
      ll.longitude,
    );
  }

  Future<void> _updateDistance() async {
    final pin = _pin;
    if (pin == null) return;
    final d = await _distanceToUser(pin);
    if (!mounted) return;
    setState(() => _pinDistance = d);
  }

  Future<void> _reverseGeocode(LatLng ll) async {
    final token = ++_reverseToken;
    try {
      final uri = Uri.parse('$_kNominatimBase/reverse').replace(
        queryParameters: {
          'format': 'json',
          'lat': '${ll.latitude}',
          'lon': '${ll.longitude}',
          'zoom': '18',
        },
      );
      final resp = await http
          .get(uri, headers: _kNominatimHeaders)
          .timeout(_kHttpTimeout);
      if (!mounted || token != _reverseToken) return;
      if (resp.statusCode != 200) {
        throw http.ClientException('reverse geocode ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final name = (json['display_name'] as String?) ?? '';
      setState(() {
        _reverseGeocoding = false;
        _gymName = name;
      });
    } catch (_) {
      if (!mounted || token != _reverseToken) return;
      // Leave the name empty — the panel falls back to the unnamed label.
      setState(() => _reverseGeocoding = false);
    }
  }

  // ── Nominatim search ──────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      setState(() {
        _results = [];
        _searchFailed = false;
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _searchFailed = false;
    });
    try {
      final uri = Uri.parse('$_kNominatimBase/search').replace(
        queryParameters: {'format': 'json', 'q': q, 'limit': '5'},
      );
      final resp = await http
          .get(uri, headers: _kNominatimHeaders)
          .timeout(_kHttpTimeout);
      if (!mounted) return;
      if (resp.statusCode != 200) {
        throw http.ClientException('search ${resp.statusCode}');
      }
      final list = jsonDecode(resp.body) as List<dynamic>;
      setState(() {
        _searching = false;
        _results = list
            .whereType<Map<String, dynamic>>()
            .map((e) => _SearchResult(
                  name: (e['display_name'] as String?) ?? '',
                  lat: double.tryParse('${e['lat']}') ?? 0,
                  lon: double.tryParse('${e['lon']}') ?? 0,
                ))
            .where((r) => r.name.isNotEmpty)
            .toList();
      });
    } catch (_) {
      // No distinct error key in Phase 1 — the "no results" state doubles as
      // the failure state, inline, never a crash.
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = [];
        _searchFailed = true;
      });
    }
  }

  void _onResultTap(_SearchResult result) {
    final ll = LatLng(result.lat, result.lon);
    _centerOn(ll, zoom: 16);
    // The result's display_name IS the geocoded name — no second round-trip.
    _movePin(ll, name: result.name);
  }

  // ── Confirm ───────────────────────────────────────────────────────────────

  void _confirm() {
    final pin = _pin;
    if (pin == null) return;
    final l10n = AppLocalizations.of(context)!;
    final gym = SelectedGym(
      name: _gymName.isNotEmpty ? _gymName : l10n.gymAttUnnamedGym,
      latitude: pin.latitude,
      longitude: pin.longitude,
      radiusM: _kTrackingRadiusM,
      distanceMeters: _pinDistance,
    );
    if (widget.onSelected != null) {
      widget.onSelected!(gym);
    } else {
      Navigator.of(context).pop(gym);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMap(l10n),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderCard(l10n: l10n),
                  const SizedBox(height: 10),
                  _SearchField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    hint: l10n.gymAttSearchHint,
                    searching: _searching,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() {
                        _results = [];
                        _searchFailed = false;
                      });
                    },
                  ),
                  if (_results.isNotEmpty || _searchFailed) ...[
                    const SizedBox(height: 8),
                    Flexible(child: _buildResults(l10n)),
                  ],
                ],
              ),
            ),
          ),
          // Locate-failure card (Retry) — sits just above the bottom panel.
          if (_locFailed)
            Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: _bottomInset(context)),
                child: _ErrorCard(l10n: l10n, onRetry: _locate),
              ),
            ),
          // Locating scrim — the map is never blank underneath.
          if (_locating) _buildLocatingScrim(l10n),
          // Bottom docked chrome: My Location FAB + "Your Gym" panel.
          Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _MyLocationFab(
                      l10n: l10n,
                      bottomInset: _locFailed ? 0 : 12,
                      onTap: () {
                        final user = _userPosition;
                        if (user != null) {
                          _centerOn(LatLng(user.latitude, user.longitude), zoom: 16);
                        } else {
                          _locate();
                        }
                      },
                    ),
                  ),
                  if (!_locFailed) _GymPanel(
                    l10n: l10n,
                    name: _gymName,
                    reverseGeocoding: _reverseGeocoding,
                    distanceMeters: _pinDistance,
                    onTapConfirm: _pin == null ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps the failure card clear of the always-visible bottom padding.
  double _bottomInset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom + 16;
  }

  Widget _buildMap(AppLocalizations l10n) {
    final pin = _pin;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 15,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
        onMapReady: () => _mapReady = true,
        onTap: (_, latLng) => _movePin(latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: _kTileUrlTemplate,
          userAgentPackageName: 'CoreGym/1.0 (fitness app)',
          // OSM tiles ship light-only cartography — in dark mode an unfiltered
          // map is a glaring white slab on the graphite canvas. Inverted
          // grayscale keeps the map monochrome (no weird inverted hues) and
          // lets the volt geofence ring/pin stay the accent.
          tileBuilder: AppColors.isLight
              ? null
              : (context, tile, _) => ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    -0.2126, -0.7152, -0.0722, 0, 255, //
                    -0.2126, -0.7152, -0.0722, 0, 255, //
                    -0.2126, -0.7152, -0.0722, 0, 255, //
                    0, 0, 0, 1, 0,
                  ]),
                  child: tile,
                ),
        ),
        if (pin != null)
          TweenAnimationBuilder<double>(
            key: ValueKey<int>(_pinPlacement),
            tween: Tween<double>(begin: 0, end: 1),
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            builder: (context, t, _) => CircleLayer(
              circles: [
                CircleMarker(
                  point: pin,
                  radius: _kTrackingRadiusM * t,
                  useRadiusInMeter: true,
                  color: AppColors.accent.withValues(alpha: .14 * t),
                  borderStrokeWidth: 1.5,
                  borderColor: AppColors.accent.withValues(alpha: .55 * t),
                ),
              ],
            ),
          ),
        if (pin != null)
          MarkerLayer(
            markers: [
              Marker(
                point: pin,
                width: 34,
                height: 48,
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<int>(_pinPlacement),
                  tween: Tween<double>(begin: .6, end: 1),
                  duration: AppDurations.medium,
                  curve: AppCurves.overshoot,
                  builder: (context, t, _) => Transform.scale(
                    scale: t,
                    alignment: Alignment.bottomCenter,
                    child: const _GymPin(),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLocatingScrim(AppLocalizations l10n) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.background.withValues(alpha: .55),
        child: Center(
          child: FadeTransition(
            opacity: _skeletonCtrl,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(width: 140, opacity: _skeletonCtrl),
                  const SizedBox(height: 10),
                  _SkeletonBar(width: 90, opacity: _skeletonCtrl),
                  const SizedBox(height: 14),
                  Text(
                    l10n.gymAttMapFinding,
                    style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    if (_searchFailed) {
      return _ResultsShell(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            l10n.gymAttSearchNoResults,
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return _ResultsShell(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _results.length,
        itemBuilder: (context, i) {
          final r = _results[i];
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              Icons.place_rounded,
              size: 20,
              color: AppColors.onPrimaryContainer,
            ),
            title: Text(
              r.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(color: AppColors.textPrimary),
            ),
            onTap: () => _onResultTap(r),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Chrome widgets
// ────────────────────────────────────────────────────────────────────────────

/// CoreGym-style pin: accent-colored rounded head with a surface dot, tip on
/// the placed point (marker is aligned bottom-center above the coordinate).
class _GymPin extends StatelessWidget {
  const _GymPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(15),
          bottom: Radius.circular(4),
        ),
        border: Border.all(
          color: AppColors.surface,
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Title + subtitle floating card, top of the map.
class _HeaderCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _HeaderCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 20,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gymAttMapTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleSm.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.gymAttMapSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          if (searching)
            const SizedBox(
              width: 18,
              height: 18,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppText.bodyMd.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.bodyMd.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "My Location" small round FAB on the map.
class _MyLocationFab extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final double bottomInset;

  const _MyLocationFab({
    required this.l10n,
    required this.onTap,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    final fab = Material(
      color: AppColors.surface.withValues(alpha: .96),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: .25),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.my_location_rounded,
            size: 20,
            color: AppColors.onPrimaryContainer,
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Semantics(
        button: true,
        label: l10n.gymAttMyLocation,
        child: Tooltip(message: l10n.gymAttMyLocation, child: fab),
      ),
    );
  }
}

/// Bottom docked panel — "Your Gym" name + distance + tracking radius + CTA.
/// Compact by design (well under 35% of the map).
class _GymPanel extends StatelessWidget {
  final AppLocalizations l10n;
  final String name;
  final bool reverseGeocoding;
  final double? distanceMeters;
  final VoidCallback? onTapConfirm;

  const _GymPanel({
    required this.l10n,
    required this.name,
    required this.reverseGeocoding,
    required this.distanceMeters,
    required this.onTapConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final location = LocationService();
    return _CardShell(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.gymAttYourGym.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (reverseGeocoding && name.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _SkeletonLine(width: 180),
            )
          else
            Text(
              name.isNotEmpty ? name : l10n.gymAttUnnamedGym,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.titleSm.copyWith(color: AppColors.textPrimary),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (distanceMeters != null) ...[
                Icon(
                  Icons.near_me_rounded,
                  size: 15,
                  color: AppColors.onPrimaryContainer,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.gymAttDistanceValue(location.formatDistance(distanceMeters!)),
                  style: AppText.labelLg.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Icon(
                Icons.radar_rounded,
                size: 15,
                color: AppColors.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${l10n.gymAttTrackingRadius} · ${l10n.gymAttRadiusValue('$_kTrackingRadiusM')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelLg.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onTapConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryFixed,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: AppText.buttonPrimary,
            ),
            child: Text(l10n.gymAttConfirmGym),
          ),
        ],
      ),
    );
  }
}

/// Location-failed card with a Retry action.
class _ErrorCard extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  const _ErrorCard({required this.l10n, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_rounded,
              size: 19,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.gymAttMapLocErrorTitle,
              style: AppText.bodyMd.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent.withValues(alpha: .16),
              foregroundColor: AppColors.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: AppText.buttonSecondary,
            ),
            child: Text(l10n.gymAttRetry),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared shells
// ────────────────────────────────────────────────────────────────────────────

/// Floating glass/card chrome shared by all map overlays (radius 20,
/// borderSubtle, soft shadow).
class _CardShell extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _CardShell({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ResultsShell extends StatelessWidget {
  final Widget child;
  const _ResultsShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  final Animation<double> opacity;

  const _SkeletonBar({required this.width, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: _SkeletonLine(width: width),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;

  const _SkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
