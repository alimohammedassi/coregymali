import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/text_food_log_result.dart';
import '../services/text_food_log_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TextFoodLogScreen — AI text logging: type → analyze → review → save
// ─────────────────────────────────────────────────────────────────────────────

enum _TextPhase { input, analyzing, result, error }

class TextFoodLogScreen extends StatefulWidget {
  /// Optional pre-selected meal type (breakfast/lunch/dinner/snack).
  final String? initialMealType;

  const TextFoodLogScreen({super.key, this.initialMealType});

  @override
  State<TextFoodLogScreen> createState() => _TextFoodLogScreenState();
}

class _TextFoodLogScreenState extends State<TextFoodLogScreen>
    with TickerProviderStateMixin {
  final _textService = TextFoodLogService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  static const _meals = [
    (type: 'breakfast', emoji: '🍳'),
    (type: 'lunch', emoji: '🥗'),
    (type: 'dinner', emoji: '🍽'),
    (type: 'snack', emoji: '🥜'),
  ];

  static const _analyzingSteps = [
    'Reading description',
    'Identifying foods',
    'Calculating nutrition',
  ];

  static const _maxLength = 1000;

  late final AnimationController _ringController;

  Timer? _stepTimer;
  int _stepIndex = 0;

  _TextPhase _phase = _TextPhase.input;
  late String _mealType = _defaultMealType();
  TextFoodLogResult? _result;
  List<TextFoodLogItem> _items = [];
  List<double> _weightsG = [];
  TextLogErrorType? _errorType;
  bool _saving = false;
  TextLogErrorType? _saveErrorType;

  static String _defaultMealType() {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 16) return 'lunch';
    if (h < 22) return 'dinner';
    return 'snack';
  }

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode == 'ar';

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

  String _errorText(AppLocalizations l10n, TextLogErrorType type) {
    switch (type) {
      case TextLogErrorType.network:
        return l10n.textErrorNetwork;
      case TextLogErrorType.unauthorized:
        return l10n.textErrorUnauthorized;
      case TextLogErrorType.notFood:
        return l10n.textErrorNotFood;
      case TextLogErrorType.analysisFailed:
        return l10n.textErrorAnalysis;
      case TextLogErrorType.serverError:
        return l10n.textErrorPersist;
      case TextLogErrorType.unknown:
        return l10n.textErrorUnknown;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMealType != null &&
        _meals.any((m) => m.type == widget.initialMealType)) {
      _mealType = widget.initialMealType!;
    }
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    _stepTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─── actions ──────────────────────────────────────────────────────────────
  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _phase == _TextPhase.analyzing || _saving) {
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.textEmptyInput),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _phase = _TextPhase.analyzing;
      _stepIndex = 0;
      _errorType = null;
      _saveErrorType = null;
    });
    _startStepCycle();

    try {
      final result = await _textService.analyze(text);
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _result = result;
        _items = List<TextFoodLogItem>.from(result.items);
        _weightsG =
            result.items.map((i) => i.estimatedWeightG.clamp(10.0, 5000.0)).toList();
        _phase = _TextPhase.result;
      });
    } on TextLogException catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _errorType = e.type;
        _phase = _TextPhase.error;
      });
    } catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      setState(() {
        _errorType = TextLogErrorType.unknown;
        _phase = _TextPhase.error;
      });
    }
  }

  void _startStepCycle() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted || _phase != _TextPhase.analyzing) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _analyzingSteps.length);
    });
  }

  /// Back to the input phase keeping whatever the user typed.
  void _editDescription() {
    HapticFeedback.selectionClick();
    setState(() {
      _phase = _TextPhase.input;
      _result = null;
      _items = [];
      _weightsG = [];
      _errorType = null;
      _saveErrorType = null;
    });
  }

  /// Clear everything and start a fresh description.
  void _newDescription() {
    HapticFeedback.selectionClick();
    setState(() {
      _controller.clear();
      _phase = _TextPhase.input;
      _result = null;
      _items = [];
      _weightsG = [];
      _errorType = null;
      _saveErrorType = null;
    });
  }

  void _updateWeight(int index, double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _weightsG[index] = (_weightsG[index] + delta).clamp(10.0, 5000.0);
    });
  }

  void _removeItem(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _items.removeAt(index);
      _weightsG.removeAt(index);
    });
  }

  Future<void> _saveToLog() async {
    if (_items.isEmpty || _saving) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = true;
      _saveErrorType = null;
    });

    final ok = await _textService.saveToLog(
      items: _items,
      weightsG: _weightsG,
      mealType: _mealType,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _saveErrorType = TextLogErrorType.serverError;
      });
    }
  }

  // ─── computed helpers ─────────────────────────────────────────────────────
  double get _totalCalories => _items.asMap().entries
      .fold(0, (s, e) => s + e.value.caloriesFor(_weightsG[e.key]));

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
              l10n.textTitle,
              style: AppText.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              l10n.textSubtitle,
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
                _TextPhase.input => _buildInput(),
                _TextPhase.analyzing => _buildAnalyzing(),
                _TextPhase.result => _buildResult(),
                _TextPhase.error => _buildError(),
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
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primaryFixed.withValues(alpha: 0.35),
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
                          color: sel ? Colors.white : AppColors.onSurfaceVariant,
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

  // ─── INPUT ────────────────────────────────────────────────────────────────
  Widget _buildInput() {
    final l10n = AppLocalizations.of(context)!;
    final canAnalyze = _controller.text.trim().isNotEmpty;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMealPicker(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 3,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxLength),
                  ],
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: AppText.fontFamily(isArabic: _isArabic),
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.textInputHint,
                    hintMaxLines: 2,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontFamily: AppText.fontFamily(isArabic: _isArabic),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_controller.text.length}/$_maxLength',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _GradientButton(
            label: l10n.textAnalyzeCta,
            icon: Icons.auto_awesome_rounded,
            onTap: canAnalyze ? _analyze : null,
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
              child: Container(
                width: 200,
                height: 200,
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
                          width: 80 + (v * 70),
                          height: 80 + (v * 70),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryFixed
                                  .withValues(alpha: 0.5 * (1 - v)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    Icon(
                      Icons.notes_rounded,
                      size: 52,
                      color: AppColors.primaryFixed.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              l10n.textAnalyzingTitle,
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

  // ─── RESULT ───────────────────────────────────────────────────────────────
  Widget _buildResult() {
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
                _buildDescriptionHeader(),
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
      'All items removed — go back and edit your description',
      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
    ),
  );

  Widget _buildDescriptionHeader() {
    final r = _result!;
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 13, color: AppColors.primaryFixed),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  l10n.textTitle,
                  style:  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _editDescription,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 15,
                    color: AppColors.primaryFixed,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
                  color: AppColors.primaryFixed.withValues(alpha: 0.7),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.textWroteLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _controller.text.trim(),
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: AppText.fontFamily(isArabic: _isArabic),
            ),
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

  Widget _confidencePill(TextLogConfidence c) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (c) {
      TextLogConfidence.high => l10n.scanConfidenceHigh,
      TextLogConfidence.medium => l10n.scanConfidenceMedium,
      TextLogConfidence.low => l10n.scanConfidenceLow,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
    final p = _items.asMap().entries.fold(
        0.0, (s, e) => s + e.value.proteinFor(_weightsG[e.key]));
    final c = _items.asMap().entries.fold(
        0.0, (s, e) => s + e.value.carbsFor(_weightsG[e.key]));
    final f = _items.asMap().entries.fold(
        0.0, (s, e) => s + e.value.fatFor(_weightsG[e.key]));
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

  Widget _buildItemCard(int index, TextFoodLogItem item) {
    final w = _weightsG[index];
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
                          '${w.toInt()}g',
                          AppColors.textSecondary,
                        ),
                        _microPill(
                          'P ${item.proteinFor(w).toStringAsFixed(1)}',
                          AppColors.accentProtein,
                        ),
                        _microPill(
                          'C ${item.carbsFor(w).toStringAsFixed(1)}',
                          AppColors.accentCarbs,
                        ),
                        _microPill(
                          'F ${item.fatFor(w).toStringAsFixed(1)}',
                          AppColors.accentFat,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Portion stepper — macros above rescale live.
                    Row(
                      children: [
                        _qtyButton(Icons.remove_rounded,
                            () => _updateWeight(index, -10)),
                        Container(
                          constraints: const BoxConstraints(minWidth: 64),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '${w.toInt()} g',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _qtyButton(
                            Icons.add_rounded, () => _updateWeight(index, 10)),
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
                    item.caloriesFor(w).toInt().toString(),
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

  Widget _qtyButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: _saving ? null : onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      );

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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _errorCard(
              l10n.scanErrorTitle,
              _errorText(l10n, _errorType ?? TextLogErrorType.unknown),
            ),
            const SizedBox(height: 24),
            _GradientButton(
              label: l10n.textEditDescription,
              icon: Icons.edit_rounded,
              onTap: _editDescription,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _newDescription,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryFixed,
                  side: BorderSide(
                    color: AppColors.primaryFixed.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.notes_rounded, size: 19),
                label: Text(
                  l10n.textNewDescription,
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
// Reusable gradient primary CTA button (nullable onTap → disabled styling)
// ─────────────────────────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryFixed, AppColors.secondaryFixed],
                  )
                : null,
            color: enabled ? null : AppColors.surfaceContainerHigh,
            boxShadow: enabled
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
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 22,
                        color: enabled
                            ? Colors.white
                            : AppColors.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: enabled
                            ? Colors.white
                            : AppColors.onSurfaceVariant,
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
}
