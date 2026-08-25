import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';
import '../models/barcode_product_result.dart';
import '../services/barcode_lookup_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BarcodeScanScreen — camera scan → lookup → review macros → save to log
// ─────────────────────────────────────────────────────────────────────────────

enum _BarcodePhase { scanning, loading, result, nameHint, error }

class BarcodeScanScreen extends StatefulWidget {
  /// Optional pre-selected meal type (breakfast/lunch/dinner/snack).
  final String? initialMealType;

  const BarcodeScanScreen({super.key, this.initialMealType});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen>
    with TickerProviderStateMixin {
  final _lookupService = BarcodeLookupService();

  static const _meals = [
    (type: 'breakfast', emoji: '🍳'),
    (type: 'lunch', emoji: '🥗'),
    (type: 'dinner', emoji: '🍽'),
    (type: 'snack', emoji: '🥜'),
  ];

  MobileScannerController? _cameraController;
  bool _isProcessingFrame = false;

  late AnimationController _frameController;
  late Animation<double> _frameOpacity;

  _BarcodePhase _phase = _BarcodePhase.scanning;
  String _mealType;
  String _barcode = '';
  BarcodeProductResult? _product;
  double _quantityG = 100;
  BarcodeLookupErrorType? _errorType;

  _BarcodeScanScreenState() : _mealType = _defaultMealType();

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

  @override
  void initState() {
    super.initState();
    if (widget.initialMealType != null &&
        _meals.any((m) => m.type == widget.initialMealType)) {
      _mealType = widget.initialMealType!;
    }
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _frameOpacity = Tween(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _frameController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _frameController.dispose();
    super.dispose();
  }

  // ─── actions ──────────────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingFrame || _phase != _BarcodePhase.scanning) return;

    String? raw;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        raw = v;
        break;
      }
    }

    if (raw == null || !RegExp(r'^\d{6,14}$').hasMatch(raw)) return;

    _isProcessingFrame = true;
    HapticFeedback.mediumImpact();
    _cameraController?.stop();
    _lookup(raw);
  }

  Future<void> _lookup(String barcode, {String? productNameHint}) async {
    setState(() {
      _barcode = barcode;
      _phase = _BarcodePhase.loading;
      _errorType = null;
    });

    try {
      final product =
          await _lookupService.lookup(barcode, productNameHint: productNameHint);
      if (!mounted) return;
      if (product.needsNameHint) {
        setState(() => _phase = _BarcodePhase.nameHint);
        return;
      }
      setState(() {
        _product = product;
        _quantityG = product.servingSizeG > 0 ? product.servingSizeG : 100;
        _phase = _BarcodePhase.result;
      });
    } on BarcodeLookupException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorType = e.type;
        _phase = _BarcodePhase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorType = BarcodeLookupErrorType.unknown;
        _phase = _BarcodePhase.error;
      });
    }
  }

  void _resetToScanning() {
    HapticFeedback.selectionClick();
    _isProcessingFrame = false;
    _product = null;
    _barcode = '';
    _quantityG = 100;
    _cameraController?.start();
    setState(() => _phase = _BarcodePhase.scanning);
  }

  Future<void> _saveToLog() async {
    final product = _product;
    if (product == null || _saveInProgress) return;
    HapticFeedback.mediumImpact();
    setState(() => _saveInProgress = true);

    final ok = await _lookupService.saveToLog(
      product: product,
      quantityG: _quantityG,
      mealType: _mealType,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saveInProgress = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saving failed. Please try again.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.error.withValues(alpha: .3)),
          ),
        ),
      );
    }
  }

  bool _saveInProgress = false;

  // ─── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barcode Scanner',
              style: AppText.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              l10n.scanSubtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
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
              _BarcodePhase.scanning => _buildScanner(),
              _BarcodePhase.loading => _buildLoading(),
              _BarcodePhase.result => _buildResult(),
              _BarcodePhase.nameHint => _buildNameHint(),
              _BarcodePhase.error => _buildError(),
            },
          ),
        ),
      ),
    );
  }

  // ─── SCANNING ─────────────────────────────────────────────────────────────
  Widget _buildScanner() {
    _cameraController ??= MobileScannerController();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            'Point the camera at the barcode on the package',
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _cameraController,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) =>
                    _buildCameraError(error),
              ),
              // Scan frame
              Center(
                child: FadeTransition(
                  opacity: _frameOpacity,
                  child: Container(
                    width: 260,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: .25),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: .35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 19),
              label: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraError(Exception error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_outlined,
              size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'Camera unavailable.\nCheck that camera permission is enabled.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOADING ──────────────────────────────────────────────────────────────
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 20),
          Text(
            'Looking up product…',
            style: AppText.bodyMd.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Barcode $_barcode',
            style: AppText.bodySm.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ─── RESULT ───────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final p = _product!;
    final l10n = AppLocalizations.of(context)!;
    final kcal = p.caloriesFor(_quantityG);
    final protein = p.proteinFor(_quantityG);
    final carbs = p.carbsFor(_quantityG);
    final fat = p.fatFor(_quantityG);
    final total = (protein + carbs + fat).clamp(0.0001, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal picker
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
                                      AppColors.primary,
                                      AppColors.secondaryGreen,
                                    ],
                                  )
                                : null,
                            color: sel
                                ? null
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel
                                  ? Colors.transparent
                                  : AppColors.borderSubtle,
                            ),
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
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Product header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .03),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_rounded,
                              size: 13, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'BARCODE $_barcode',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .5,
                                color: AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.isEstimate)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.tertiary.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        AppColors.tertiary.withValues(alpha: .4)),
                              ),
                              child: Text(
                                'AI ESTIMATE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        p.productName,
                        style: AppText.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      if (p.productNameAr != null &&
                          p.productNameAr!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            p.productNameAr!,
                            style: AppText.bodySm.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      if (p.brand != null && p.brand!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            p.brand!,
                            style: AppText.bodySm.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quantity stepper
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Quantity',
                        style: AppText.bodyMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      _qtyButton(Icons.remove_rounded, () {
                        HapticFeedback.selectionClick();
                        setState(() =>
                            _quantityG = (_quantityG - 10).clamp(10, 5000));
                      }),
                      Container(
                        constraints: const BoxConstraints(minWidth: 76),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${_quantityG.toInt()} g',
                          textAlign: TextAlign.center,
                          style: AppText.metricMd.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      _qtyButton(Icons.add_rounded, () {
                        HapticFeedback.selectionClick();
                        setState(() =>
                            _quantityG = (_quantityG + 10).clamp(10, 5000));
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Macros card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: .25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: kcal.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: '  kcal',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _macroCol('${protein.toStringAsFixed(1)}g', 'Protein',
                              AppColors.accentProtein),
                          const SizedBox(width: 22),
                          _macroCol('${carbs.toStringAsFixed(1)}g', 'Carbs',
                              AppColors.accentCarbs),
                          const SizedBox(width: 22),
                          _macroCol('${fat.toStringAsFixed(1)}g', 'Fat',
                              AppColors.accentFat),
                          const Spacer(),
                          Text(
                            'per ${_quantityG.toInt()}g',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
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
                                flex:
                                    (protein / total * 1000).round().clamp(1, 1000),
                                child: Container(color: AppColors.accentProtein),
                              ),
                              Expanded(
                                flex:
                                    (carbs / total * 1000).round().clamp(1, 1000),
                                child: Container(color: AppColors.accentCarbs),
                              ),
                              Expanded(
                                flex: (fat / total * 1000).round().clamp(1, 1000),
                                child: Container(color: AppColors.accentFat),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildSaveBar(),
      ],
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
      );

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
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      );

  Widget _buildSaveBar() {
    final l10n = AppLocalizations.of(context)!;
    final canSave = !_saveInProgress;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
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
                ? AppColors.primaryActionGradient
                : null,
            color: canSave ? null : AppColors.primary.withValues(alpha: .35),
            boxShadow: canSave
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .3),
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
                child: _saveInProgress
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

  // ─── NAME HINT ────────────────────────────────────────────────────────────
  Widget _buildNameHint() {
    final ctrl = TextEditingController(text: _productNameHint);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.search_off_rounded,
                size: 32, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            "Couldn't find this product",
            textAlign: TextAlign.center,
            style: AppText.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'What is it called? We\'ll estimate its nutrition for you.\nBarcode $_barcode',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => _submitHint(v),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Chocolate wafer bar',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: AppColors.primaryActionGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .3),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => _submitHint(ctrl.text),
                  child: const Center(
                    child: Text(
                      'ESTIMATE NUTRITION',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resetToScanning,
            child: Text(
              'Scan another barcode',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _productNameHint = '';

  void _submitHint(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    _productNameHint = v;
    _lookup(_barcode, productNameHint: v);
  }

  // ─── ERROR ────────────────────────────────────────────────────────────────
  Widget _buildError() {
    final message = switch (_errorType ?? BarcodeLookupErrorType.unknown) {
      BarcodeLookupErrorType.network =>
        'No internet connection. Check your network and try again.',
      BarcodeLookupErrorType.unauthorized =>
        'Please sign in first to use the scanner.',
      BarcodeLookupErrorType.invalidRequest =>
        'That barcode does not look valid. Try scanning again.',
      BarcodeLookupErrorType.upstreamUnreachable =>
        "The product database is unreachable right now. Please try again.",
      BarcodeLookupErrorType.analysisFailed =>
        "We couldn't identify that product. Please try again.",
      BarcodeLookupErrorType.serverError =>
        'Something went wrong on our side. Please try again.',
      BarcodeLookupErrorType.unknown =>
        'Something unexpected went wrong. Please try again.',
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: .3)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: .1),
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
                    'Oops!',
                    style: AppText.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.bodySm.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _resetToScanning,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: .35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                label: const Text(
                  'Scan again',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
