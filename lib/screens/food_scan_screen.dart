import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/food_scan_result.dart';
import '../l10n/app_localizations.dart';
import '../services/food_scan_service.dart';
import '../services/nutrition_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FoodScanScreen — AI food photo scan: capture → analyze → review → save
// ─────────────────────────────────────────────────────────────────────────────

enum _ScanPhase { idle, analyzing, result, error }

class FoodScanScreen extends StatefulWidget {
  /// Optional pre-selected meal type (breakfast/lunch/dinner/snack).
  final String? initialMealType;

  const FoodScanScreen({super.key, this.initialMealType});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen>
    with TickerProviderStateMixin {
  final _scanService = FoodScanService();
  final _nutritionService = NutritionService();
  final _picker = ImagePicker();

  static const _meals = [
    (type: 'breakfast', emoji: '🍳'),
    (type: 'lunch', emoji: '🥗'),
    (type: 'dinner', emoji: '🍽'),
    (type: 'snack', emoji: '🥜'),
  ];

  static const _analyzingSteps = [
    'Detecting food items',
    'Estimating portions',
    'Calculating nutrition',
  ];

  late final AnimationController _scanController;
  late final AnimationController _pulseController;
  late final AnimationController _resultController;

  Timer? _stepTimer;
  int _stepIndex = 0;

  _ScanPhase _phase = _ScanPhase.idle;
  String _mealType;
  XFile? _imageFile;
  FoodScanResult? _result;
  List<FoodScanItem> _items = [];
  FoodScanErrorType? _errorType;
  bool _saving = false;
  FoodScanErrorType? _saveErrorType;

  _FoodScanScreenState() : _mealType = _defaultMealType();

  static String _defaultMealType() {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 22) return 'dinner';
    return 'snack';
  }

  String _mealLabel(AppLocalizations l10n) => _mealName(l10n, _mealType);

  static String _mealName(AppLocalizations l10n, String type) {
    switch (type) {
      case 'breakfast':
        return l10n.breakfast;
      case 'lunch':
        return l10n.lunch;
      case 'dinner':
        return l10n.dinner;
      default:
        return l10n.snack;
    }
  }

  String _errorText(AppLocalizations l10n, FoodScanErrorType type) {
    switch (type) {
      case FoodScanErrorType.network:
        return l10n.scanErrorNetwork;
      case FoodScanErrorType.unauthorized:
        return l10n.scanErrorUnauthorized;
      case FoodScanErrorType.notFood:
        return l10n.scanErrorNotFood;
      case FoodScanErrorType.analysisFailed:
        return l10n.scanErrorAnalysis;
      case FoodScanErrorType.serverError:
        return l10n.scanErrorPersist;
      case FoodScanErrorType.unknown:
        return l10n.scanErrorUnknown;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMealType != null &&
        _meals.any((m) => m.type == widget.initialMealType)) {
      _mealType = widget.initialMealType!;
    }
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _resultController.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  // ─── actions ──────────────────────────────────────────────────────────────
  Future<void> _pickAndAnalyze(ImageSource source) async {
    if (_phase == _ScanPhase.analyzing || _saving) return;
    HapticFeedback.lightImpact();

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
    } catch (_) {
      picked = null;
    }
    if (picked == null || !mounted) return;

    setState(() {
      _imageFile = picked;
      _phase = _ScanPhase.analyzing;
      _errorType = null;
      _saveErrorType = null;
      _stepIndex = 0;
    });
    _startStepCycle();
    await _analyze();
  }

  void _startStepCycle() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted || _phase != _ScanPhase.analyzing) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _analyzingSteps.length);
    });
  }

  Future<void> _analyze() async {
    final image = _imageFile;
    if (image == null) return;

    try {
      final result = await _scanService.analyzeFood(image);
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _result = result;
        _items = List<FoodScanItem>.from(result.items);
        _phase = _ScanPhase.result;
      });
      _resultController.forward(from: 0);
    } on FoodScanException catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _errorType = e.type;
        _phase = _ScanPhase.error;
      });
    } catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _errorType = FoodScanErrorType.unknown;
        _phase = _ScanPhase.error;
      });
    }
  }

  void _resetToIdle() {
    HapticFeedback.selectionClick();
    _stepTimer?.cancel();
    setState(() {
      _phase = _ScanPhase.idle;
      _imageFile = null;
      _result = null;
      _items = [];
      _errorType = null;
      _saveErrorType = null;
    });
  }

  Future<void> _saveToLog() async {
    if (_result == null || _items.isEmpty || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _saveErrorType = null;
    });

    final ok = await _nutritionService.saveScannedItems(
      items: _items,
      mealType: _mealType,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _saveErrorType = FoodScanErrorType.serverError;
      });
    }
  }

  void _removeItem(int index) {
    HapticFeedback.selectionClick();
    setState(() => _items.removeAt(index));
  }

  // ─── computed helpers ─────────────────────────────────────────────────────
  double get _totalCalories => _items.fold(0, (s, i) => s + i.calories);

  // ─── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.scanTitle,
              style: AppText.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              l10n.scanSubtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: switch (_phase) {
                _ScanPhase.idle => _buildIdle(),
                _ScanPhase.analyzing => _buildAnalyzing(),
                _ScanPhase.result => _buildResult(),
                _ScanPhase.error => _buildError(),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── IDLE ─────────────────────────────────────────────────────────────────
  Widget _buildIdle() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.scanSaveToMeal,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _meals.map((m) {
              final sel = _mealType == m.type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _mealType = m.type);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsetsDirectional.only(
                      end: m.type == 'snack' ? 0 : 8,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primaryFixed,
                                AppColors.secondaryFixed,
                              ],
                            )
                          : null,
                      color: sel ? null : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? Colors.transparent
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: AppColors.primaryFixed.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 220),
                          scale: sel ? 1.12 : 1.0,
                          child: Text(
                            m.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _mealName(l10n, m.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: sel
                                ? Colors.white
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (_, child) {
                final t = Curves.easeInOut.transform(_pulseController.value);
                return Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryFixed.withValues(alpha: 0.05 + 0.03 * t),
                  ),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.16),
                      AppColors.secondaryFixed.withValues(alpha: 0.10),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryFixed.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.restaurant_rounded,
                  size: 52,
                  color: AppColors.primaryFixed,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l10n.scanIdleHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _GradientButton(
            label: l10n.scanCameraCta,
            icon: Icons.photo_camera_rounded,
            onTap: () => _pickAndAnalyze(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _pickAndAnalyze(ImageSource.gallery),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryFixed,
                side: BorderSide(
                  color: AppColors.primaryFixed.withValues(alpha: 0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: Text(
                l10n.scanGalleryCta,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ANALYZING ────────────────────────────────────────────────────────────
  Widget _buildAnalyzing() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_imageFile != null)
                      Image.file(
                        File(_imageFile!.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _scanFallback(),
                      )
                    else
                      _scanFallback(),
                    // subtle darken so the scan line and text stay legible
                    Container(color: Colors.black.withValues(alpha: 0.18)),
                    AnimatedBuilder(
                      animation: _scanController,
                      builder: (_, __) {
                        final top = _scanController.value * 220;
                        return Positioned(
                          top: top - 2,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryFixed.withValues(alpha: 0),
                                  AppColors.primaryFixed,
                                  AppColors.secondaryFixed,
                                  AppColors.primaryFixed.withValues(alpha: 0),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryFixed.withValues(alpha: 
                                    0.7,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    ..._scanCorners(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.scanAnalyzingTitle,
              style: AppText.titleMd.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.scanAnalyzingSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Container(
                key: ValueKey(_stepIndex),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _analyzingSteps[_stepIndex],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryFixed,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 160,
                height: 4,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryFixed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _scanCorners() {
    const size = 22.0;
    const thickness = 2.5;
    Widget corner({required bool top, required bool left}) => Positioned(
      top: top ? 10 : null,
      bottom: top ? null : 10,
      left: left ? 10 : null,
      right: left ? null : 10,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: 0,
              right: 0,
              child: Container(
                height: thickness,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            Positioned(
              top: top ? 0 : null,
              bottom: top ? null : 0,
              left: left ? 0 : null,
              right: left ? null : 0,
              child: Container(
                width: thickness,
                height: size,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
    return [
      corner(top: true, left: true),
      corner(top: true, left: false),
      corner(top: false, left: true),
      corner(top: false, left: false),
    ];
  }

  Widget _scanFallback() => Container(
    color: AppColors.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Icon(
      Icons.restaurant_rounded,
      size: 56,
      color: AppColors.primaryFixed.withValues(alpha: 0.6),
    ),
  );

  // ─── RESULT ───────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final r = _result!;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultHeader(r),
                const SizedBox(height: 16),
                _buildTotalsCard(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Text(
                        l10n.scanItemsHeader,
                        style: AppText.titleMd.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l10n.items(_items.length),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_items.isEmpty)
                  _emptyItemsHint()
                else
                  ..._items.asMap().entries.map(
                    (e) => _buildItemCard(e.key, e.value),
                  ),
                if (_saveErrorType != null) ...[
                  const SizedBox(height: 12),
                  _errorBanner(_errorText(l10n, _saveErrorType!)),
                ],
              ],
            ),
          ),
        ),
        _buildSaveBar(),
      ],
    );
  }

  Widget _emptyItemsHint() => Container(
    padding: const EdgeInsets.symmetric(vertical: 22),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Text(
      'All items removed — go back to rescan',
      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
    ),
  );

  Widget _buildResultHeader(FoodScanResult r) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 152,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageFile != null)
              Image.file(
                File(_imageFile!.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoFallback(),
              )
            else
              _photoFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _confidencePill(r.confidence),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppLocalizations.of(context)!.scanAi,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  if (r.notes != null && r.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      r.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
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

  Widget _confidencePill(FoodScanConfidence c) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (c) {
      FoodScanConfidence.high => l10n.scanConfidenceHigh,
      FoodScanConfidence.medium => l10n.scanConfidenceMedium,
      FoodScanConfidence.low => l10n.scanConfidenceLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _photoFallback() => Container(
    color: AppColors.surfaceContainerHighest,
    alignment: Alignment.center,
    child: Icon(
      Icons.image_rounded,
      color: AppColors.onSurfaceVariant,
      size: 30,
    ),
  );

  Widget _buildTotalsCard() {
    final l10n = AppLocalizations.of(context)!;
    final p = _items.fold(0.0, (s, i) => s + i.proteinG);
    final c = _items.fold(0.0, (s, i) => s + i.carbsG);
    final f = _items.fold(0.0, (s, i) => s + i.fatG);
    final total = (p + c + f).clamp(0.0001, double.infinity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryFixed.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _totalCalories.toInt().toString(),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  Text(
                    l10n.kcal,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _macroCol(
                '${p.toStringAsFixed(0)}g',
                l10n.protein,
                AppColors.accentProtein,
              ),
              const SizedBox(width: 16),
              _macroCol(
                '${c.toStringAsFixed(0)}g',
                l10n.carbs,
                AppColors.accentCarbs,
              ),
              const SizedBox(width: 16),
              _macroCol(
                '${f.toStringAsFixed(0)}g',
                l10n.fat,
                AppColors.accentFat,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 7,
              child: Row(
                children: [
                  Expanded(
                    flex: (p / total * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.accentProtein),
                  ),
                  Expanded(
                    flex: (c / total * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.accentCarbs),
                  ),
                  Expanded(
                    flex: (f / total * 1000).round().clamp(1, 1000),
                    child: Container(color: AppColors.accentFat),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCol(String value, String label, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
      ),
    ],
  );

  Widget _buildItemCard(int index, FoodScanItem item) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${item.name}_$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Dismissible(
        key: ValueKey('dismiss_${item.name}_$index'),
        direction: _saving
            ? DismissDirection.none
            : DismissDirection.endToStart,
        onDismissed: (_) => _removeItem(index),
        background: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
            size: 22,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppText.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.nameAr != null && item.nameAr!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.nameAr!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _microPill(
                          '${item.estimatedWeightG.toInt()}g',
                          AppColors.textSecondary,
                        ),
                        _microPill(
                          'P ${item.proteinG.toStringAsFixed(1)}',
                          AppColors.accentProtein,
                        ),
                        _microPill(
                          'C ${item.carbsG.toStringAsFixed(1)}',
                          AppColors.accentCarbs,
                        ),
                        _microPill(
                          'F ${item.fatG.toStringAsFixed(1)}',
                          AppColors.accentFat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.calories.toInt().toString(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryFixed,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.kcal,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              if (!_saving)
                GestureDetector(
                  onTap: () => _removeItem(index),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _microPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
    ),
  );

  Widget _buildSaveBar() {
    final l10n = AppLocalizations.of(context)!;
    final canSave = _items.isNotEmpty && !_saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: canSave
                ? LinearGradient(
                    colors: [AppColors.primaryFixed, AppColors.secondaryFixed],
                  )
                : null,
            color: canSave ? null : AppColors.primaryFixed.withValues(alpha: 0.35),
            boxShadow: canSave
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: canSave ? _saveToLog : null,
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_circle_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.scanLogToMeal(_mealLabel(l10n)),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── ERROR ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    final l10n = AppLocalizations.of(context)!;
    final canRetrySamePhoto = _imageFile != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _errorCard(
              l10n.scanErrorTitle,
              _errorText(l10n, _errorType ?? FoodScanErrorType.unknown),
            ),
            const SizedBox(height: 24),
            if (canRetrySamePhoto)
              _GradientButton(
                label: l10n.scanRetrySamePhoto,
                icon: Icons.refresh_rounded,
                onTap: () {
                  setState(() {
                    _phase = _ScanPhase.analyzing;
                    _stepIndex = 0;
                  });
                  _startStepCycle();
                  _analyze();
                },
              ),
            if (canRetrySamePhoto) const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _resetToIdle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryFixed,
                  side: BorderSide(
                    color: AppColors.primaryFixed.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_rounded, size: 19),
                label: Text(
                  l10n.scanNewPhoto,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String title, String message) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.error_outline_rounded,
            size: 28,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: AppText.titleLg.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ],
    ),
  );

  Widget _errorBanner(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 12, color: AppColors.error, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable gradient primary CTA button
// ─────────────────────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryFixed, AppColors.secondaryFixed],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryFixed.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
