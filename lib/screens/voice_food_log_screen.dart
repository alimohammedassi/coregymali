import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/voice_food_log_result.dart';
import '../services/nutrition_service.dart';
import '../services/voice_food_log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoiceFoodLogScreen — AI voice logging: record → transcribe → review → save
// ─────────────────────────────────────────────────────────────────────────────

enum _VoicePhase { idle, recording, analyzing, result, error }

class VoiceFoodLogScreen extends StatefulWidget {
  /// Optional pre-selected meal type (breakfast/lunch/dinner/snack).
  final String? initialMealType;

  const VoiceFoodLogScreen({super.key, this.initialMealType});

  @override
  State<VoiceFoodLogScreen> createState() => _VoiceFoodLogScreenState();
}

class _VoiceFoodLogScreenState extends State<VoiceFoodLogScreen>
    with TickerProviderStateMixin {
  final _voiceService = VoiceFoodLogService();
  final _nutritionService = NutritionService();

  static const _meals = [
    (type: 'breakfast', emoji: '🍳'),
    (type: 'lunch', emoji: '🥗'),
    (type: 'dinner', emoji: '🍽'),
    (type: 'snack', emoji: '🥜'),
  ];

  static const _analyzingSteps = [
    'Transcribing speech',
    'Identifying foods',
    'Calculating nutrition',
  ];

  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final AnimationController _resultController;

  Timer? _stepTimer;
  Timer? _elapsedTimer;
  int _stepIndex = 0;
  int _elapsedSeconds = 0;

  _VoicePhase _phase = _VoicePhase.idle;
  String _mealType;
  File? _audioFile;
  VoiceFoodLogResult? _result;
  List<VoiceFoodLogItem> _items = [];
  VoiceLogErrorType? _errorType;
  bool _saving = false;
  VoiceLogErrorType? _saveErrorType;

  _VoiceFoodLogScreenState() : _mealType = _defaultMealType();

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

  String _errorText(AppLocalizations l10n, VoiceLogErrorType type) {
    switch (type) {
      case VoiceLogErrorType.network:
        return l10n.voiceErrorNetwork;
      case VoiceLogErrorType.unauthorized:
        return l10n.voiceErrorUnauthorized;
      case VoiceLogErrorType.microphone:
        return l10n.voiceErrorMicrophone;
      case VoiceLogErrorType.notFood:
        return l10n.voiceErrorNotFood;
      case VoiceLogErrorType.analysisFailed:
        return l10n.voiceErrorAnalysis;
      case VoiceLogErrorType.serverError:
        return l10n.voiceErrorPersist;
      case VoiceLogErrorType.unknown:
        return l10n.voiceErrorUnknown;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMealType != null &&
        _meals.any((m) => m.type == widget.initialMealType)) {
      _mealType = widget.initialMealType!;
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _resultController.dispose();
    _stepTimer?.cancel();
    _elapsedTimer?.cancel();
    _voiceService.cancelRecording();
    super.dispose();
  }

  // ─── actions ──────────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (_phase == _VoicePhase.recording || _phase == _VoicePhase.analyzing || _saving) {
      return;
    }
    HapticFeedback.lightImpact();

    try {
      await _voiceService.startRecording();
    } on VoiceLogException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorType = e.type;
        _phase = _VoicePhase.error;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorType = VoiceLogErrorType.unknown;
        _phase = _VoicePhase.error;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _phase = _VoicePhase.recording;
      _elapsedSeconds = 0;
      _errorType = null;
      _saveErrorType = null;
    });
    HapticFeedback.mediumImpact();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _phase != _VoicePhase.recording) return;
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _stopAndAnalyze() async {
    HapticFeedback.lightImpact();
    _elapsedTimer?.cancel();
    final file = await _voiceService.stopRecording();
    if (!mounted) return;

    if (file == null) {
      setState(() => _phase = _VoicePhase.idle);
      return;
    }

    setState(() {
      _audioFile = file;
      _phase = _VoicePhase.analyzing;
      _stepIndex = 0;
    });
    _startStepCycle();
    await _analyze();
  }

  void _startStepCycle() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted || _phase != _VoicePhase.analyzing) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _analyzingSteps.length);
    });
  }

  Future<void> _analyze() async {
    final file = _audioFile;
    if (file == null) return;

    try {
      final result = await _voiceService.logFromAudio(file);
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _result = result;
        _items = List<VoiceFoodLogItem>.from(result.items);
        _phase = _VoicePhase.result;
      });
      _resultController.forward(from: 0);
    } on VoiceLogException catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _errorType = e.type;
        _phase = _VoicePhase.error;
      });
    } catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _errorType = VoiceLogErrorType.unknown;
        _phase = _VoicePhase.error;
      });
    }
  }

  Future<void> _resetToIdle() async {
    HapticFeedback.selectionClick();
    _stepTimer?.cancel();
    await _voiceService.cancelRecording();
    setState(() {
      _phase = _VoicePhase.idle;
      _audioFile = null;
      _result = null;
      _items = [];
      _elapsedSeconds = 0;
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

    final ok = await _nutritionService.saveVoiceLogItems(
      items: _items,
      mealType: _mealType,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _saveErrorType = VoiceLogErrorType.serverError;
      });
    }
  }

  void _removeItem(int index) {
    HapticFeedback.selectionClick();
    setState(() => _items.removeAt(index));
  }

  // ─── computed helpers ─────────────────────────────────────────────────────
  double get _totalCalories => _items.fold(0, (s, i) => s + i.calories);

  String get _elapsedLabel {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

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
              l10n.voiceTitle,
              style: AppText.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              l10n.voiceSubtitle,
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
                _VoicePhase.idle => _buildIdle(),
                _VoicePhase.recording => _buildRecording(),
                _VoicePhase.analyzing => _buildAnalyzing(),
                _VoicePhase.result => _buildResult(),
                _VoicePhase.error => _buildError(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealPicker() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
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
                          : Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: AppColors.primaryFixed.withOpacity(0.35),
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
      ],
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
          _buildMealPicker(),
          const SizedBox(height: 32),
          Center(child: _micOrb(recording: false)),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l10n.voiceIdleHint,
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
            label: l10n.voiceRecordCta,
            icon: Icons.mic_rounded,
            onTap: _startRecording,
          ),
        ],
      ),
    );
  }

  // ─── RECORDING ────────────────────────────────────────────────────────────
  Widget _buildRecording() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMealPicker(),
          const SizedBox(height: 32),
          Center(child: _micOrb(recording: true)),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record_rounded,
                      size: 12, color: AppColors.error),
                  const SizedBox(width: 7),
                  Text(
                    _elapsedLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              l10n.voiceRecordingHint,
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
            label: l10n.voiceStopCta,
            icon: Icons.stop_rounded,
            onTap: _stopAndAnalyze,
          ),
        ],
      ),
    );
  }

  Widget _micOrb({required bool recording}) {
    final accent = recording ? AppColors.error : AppColors.primaryFixed;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _ringController]),
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_pulseController.value);
        return SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (recording)
                ...[0.0, 0.45].map((delay) {
                  final v =
                      ((_ringController.value - delay) / 1.0).clamp(0.0, 1.0);
                  return Container(
                    width: 124 + (v * 60),
                    height: 124 + (v * 60),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withOpacity(0.4 * (1 - v)),
                        width: 2,
                      ),
                    ),
                  );
                }),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.05 + 0.03 * t),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ],
          ),
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
              (recording ? AppColors.error : AppColors.primaryFixed)
                  .withOpacity(0.16),
              AppColors.secondaryFixed.withOpacity(0.10),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: (recording ? AppColors.error : AppColors.primaryFixed)
                .withOpacity(0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.mic_rounded,
          size: 52,
          color: recording ? AppColors.error : AppColors.primaryFixed,
        ),
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
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surfaceContainerHigh,
                      AppColors.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ringController,
                      builder: (_, __) {
                        final v = _ringController.value;
                        return Container(
                          width: 90 + (v * 80),
                          height: 90 + (v * 80),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryFixed
                                  .withOpacity(0.5 * (1 - v)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    Icon(
                      Icons.graphic_eq_rounded,
                      size: 56,
                      color: AppColors.primaryFixed.withOpacity(0.85),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.voiceAnalyzingTitle,
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
                  color: AppColors.primaryFixed.withOpacity(0.1),
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
                _buildTranscriptHeader(r),
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
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Text(
      'All items removed — go back and re-record',
      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
    ),
  );

  Widget _buildTranscriptHeader(VoiceFoodLogResult r) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerHigh,
            AppColors.surfaceContainerHighest,
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 13,
                color: AppColors.primaryFixed,
              ),
              const SizedBox(width: 5),
              Text(
                l10n.scanAi,
                style:  TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              _confidencePill(r.confidence),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2, end: 6),
                child: Icon(
                  Icons.format_quote_rounded,
                  size: 16,
                  color: AppColors.primaryFixed.withOpacity(0.7),
                ),
              ),
              Expanded(
                child: Text(
                  (r.transcript != null && r.transcript!.isNotEmpty)
                      ? r.transcript!
                      : l10n.voiceTranscriptLabel,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (r.notes != null && r.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r.notes!,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _confidencePill(VoiceLogConfidence c) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (c) {
      VoiceLogConfidence.high => l10n.scanConfidenceHigh,
      VoiceLogConfidence.medium => l10n.scanConfidenceMedium,
      VoiceLogConfidence.low => l10n.scanConfidenceLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildTotalsCard() {
    final l10n = AppLocalizations.of(context)!;
    final p = _items.fold(0.0, (s, i) => s + i.proteinG);
    final c = _items.fold(0.0, (s, i) => s + i.carbsG);
    final f = _items.fold(0.0, (s, i) => s + i.fatG);
    final total = (p + c + f).clamp(0.0001, double.infinity);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryFixed.withOpacity(0.25)),
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

  Widget _buildItemCard(int index, VoiceFoodLogItem item) {
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
            color: AppColors.error.withOpacity(0.15),
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
            border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                      color: AppColors.onSurfaceVariant.withOpacity(0.5),
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
      color: color.withOpacity(0.12),
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
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
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
            color: canSave ? null : AppColors.primaryFixed.withOpacity(0.35),
            boxShadow: canSave
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withOpacity(0.35),
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
                    ?  SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(
                            Icons.add_circle_rounded,
                            size: 20,
                            color: AppColors.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.scanLogToMeal(_mealLabel(l10n)),
                            style:  TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.onPrimary,
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
    final canRetrySameAudio = _audioFile != null &&
        _errorType != VoiceLogErrorType.notFood &&
        _errorType != VoiceLogErrorType.microphone;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _errorCard(
              l10n.scanErrorTitle,
              _errorText(l10n, _errorType ?? VoiceLogErrorType.unknown),
            ),
            const SizedBox(height: 24),
            if (canRetrySameAudio)
              _GradientButton(
                label: l10n.voiceRetrySameAudio,
                icon: Icons.refresh_rounded,
                onTap: () {
                  setState(() {
                    _phase = _VoicePhase.analyzing;
                    _stepIndex = 0;
                  });
                  _startStepCycle();
                  _analyze();
                },
              ),
            if (canRetrySameAudio) const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _resetToIdle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryFixed,
                  side: BorderSide(
                    color: AppColors.primaryFixed.withOpacity(0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.mic_none_rounded, size: 19),
                label: Text(
                  l10n.voiceNewRecording,
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
      border: Border.all(color: AppColors.error.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
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
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.error.withOpacity(0.25)),
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
              color: AppColors.primaryFixed.withOpacity(0.35),
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
