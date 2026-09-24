import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../screens/barcode_scan_screen.dart';
import '../screens/food_scan_screen.dart';
import '../screens/text_food_log_screen.dart';
import '../screens/voice_food_log_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'add_food_sheet.dart';
import 'pixel_art_icons.dart';
import 'suggest_meal_sheet.dart';

/// Time-of-day default meal — shared by every FAB entry point so each
/// logging screen opens preselected on the meal the user is most likely
/// logging right now.
String defaultMealForNow() {
  final h = DateTime.now().hour;
  return h < 11
      ? 'breakfast'
      : h < 16
      ? 'lunch'
      : h < 22
      ? 'dinner'
      : 'snack';
}

/// System-level reduced-motion check that doesn't need a [BuildContext] —
/// used by [FoodLogPopupRoute], whose duration getters run before the route
/// has a widget tree to read [MediaQuery] from.
bool get _systemReduceMotion => WidgetsBinding
    .instance
    .platformDispatcher
    .accessibilityFeatures
    .disableAnimations;

// ─────────────────────────────────────────────────────────────────────────────
// Floating Food-Log Button
//
// The single entry point for food logging on every tab: a volt circle
// floating above the liquid nav bar (right edge in both directions — it
// matches the reference app in RTL and Material convention in LTR). It
// follows the nav bar's fold: when [LiquidTabBarController.shared] minimizes
// on scroll-down the button scales away with it and returns when the bar
// expands, so the two never fight for attention over the content.
// ─────────────────────────────────────────────────────────────────────────────

class FoodLogFab extends StatefulWidget {
  /// Called after any entry point actually saved a food log, so the host
  /// can refresh whatever surfaces today's nutrition totals.
  final VoidCallback? onLogged;

  const FoodLogFab({super.key, this.onLogged});

  @override
  State<FoodLogFab> createState() => _FoodLogFabState();
}

class _FoodLogFabState extends State<FoodLogFab> {
  bool _barMinimized = LiquidTabBarController.shared.minimized;

  @override
  void initState() {
    super.initState();
    LiquidTabBarController.shared.addListener(_onBarChanged);
  }

  @override
  void dispose() {
    LiquidTabBarController.shared.removeListener(_onBarChanged);
    super.dispose();
  }

  void _onBarChanged() {
    final minimized = LiquidTabBarController.shared.minimized;
    if (minimized != _barMinimized && mounted) {
      setState(() => _barMinimized = minimized);
    }
  }

  Future<void> _openSheet() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(
      context,
    ).push(FoodLogPopupRoute(onLogged: widget.onLogged));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = !_barMinimized;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Positioned(
      right: 18,
      bottom: LiquidTabBar.reservedHeight(context) + 10,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: visible ? 1 : 0,
          child: AnimatedScale(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: visible ? Curves.easeOutBack : Curves.easeIn,
            scale: visible ? 1 : 0.4,
            // A screen reader has no way to infer "this opens a food
            // logging menu" from a bare "+" icon — give it the same
            // title the sheet itself uses.
            child: Semantics(
              button: true,
              label: l10n.foodLogSheetTitle,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: AppColors.voltGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Elevation only — the standard card shadow. No volt
                      // glow: at any strength it reads as a halo/smudge on
                      // both canvases (owner feedback 2026-09-18).
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _openSheet,
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 31,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Food-Log Popup
//
// A custom [PopupRoute] rather than showModalBottomSheet: the backdrop needs
// a real animated blur (the sheet dims via the route barrier while a
// full-screen BackdropFilter's sigma rides the same animation), and the
// sheet slides up on one easeOutCubic while its cards stagger in behind it.
// ─────────────────────────────────────────────────────────────────────────────

class FoodLogPopupRoute extends PopupRoute<void> {
  FoodLogPopupRoute({this.onLogged});

  final VoidCallback? onLogged;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.5);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss food log sheet';

  @override
  Duration get transitionDuration => _systemReduceMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 460);

  @override
  Duration get reverseTransitionDuration => _systemReduceMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 240);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Full-screen blur first (only the region under a BackdropFilter is
    // blurred, so it must fill the screen — an aligned sheet would leave
    // the backdrop sharp above it), then the sheet riding the slide.
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: curved,
              builder: (_, __) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 16 * curved.value,
                  sigmaY: 16 * curved.value,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: FoodLogSheet(routeAnimation: animation, onLogged: onLogged),
          ),
        ),
      ],
    );
  }

  // The page handles its own entrance (blur + slide); a route-level fade
  // over a BackdropFilter looks muddy on some devices.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class FoodLogSheet extends StatefulWidget {
  final Animation<double> routeAnimation;
  final VoidCallback? onLogged;

  const FoodLogSheet({super.key, required this.routeAnimation, this.onLogged});

  @override
  State<FoodLogSheet> createState() => _FoodLogSheetState();
}

class _FoodLogSheetState extends State<FoodLogSheet>
    with SingleTickerProviderStateMixin {
  // Interactive drag-to-dismiss: the sheet follows the finger in real time
  // instead of only reacting to the release velocity, so it reads as a
  // direct, grabbable object rather than a fixed panel with a hidden
  // gesture attached to it.
  late final AnimationController _snapBackController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() => setState(() {}));
  double _dragStartPixels = 0;
  double _dragPixels = 0;

  static const double _dismissThresholdPx = 120;
  static const double _dismissVelocity = 700;

  @override
  void dispose() {
    _snapBackController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Only the downward direction moves the sheet — an upward flick
    // shouldn't tuck it further under the screen edge.
    setState(() {
      _dragPixels = (_dragPixels + details.delta.dy).clamp(0.0, 400.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > _dismissVelocity || _dragPixels > _dismissThresholdPx) {
      Navigator.of(context).pop();
      return;
    }
    // Released before crossing the threshold — spring back to resting.
    _dragStartPixels = _dragPixels;
    _snapBackController
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final nav = Navigator.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final currentDrag = _snapBackController.isAnimating
        ? _dragStartPixels * (1 - _snapBackController.value)
        : _dragPixels;

    void runOption(Future<bool?> Function() push) async {
      HapticFeedback.lightImpact();
      nav.pop();
      final saved = await push();
      if (saved == true) widget.onLogged?.call();
    }

    void openAddMeal() async {
      HapticFeedback.lightImpact();
      nav.pop();
      var logged = false;
      await AddFoodSheet.show(
        nav.context,
        preselectedMeal: defaultMealForNow(),
        onFoodLogged: () => logged = true,
      );
      if (logged) widget.onLogged?.call();
    }

    // Suggest-a-Meal: close this hub first, then open the full flow sheet —
    // same hand-off pattern as the other AI entries. The remaining budget is
    // read from the same two tables the nutrition screen uses, so the sheet
    // opens with the real target no matter which tab the FAB lives on.
    Future<void> openSuggestMeal() async {
      HapticFeedback.lightImpact();
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      double remain = 0, remainP = 0, remainC = 0, remainF = 0;
      if (uid != null) {
        try {
          final day = DateTime.now().toIso8601String().substring(0, 10);
          final results = await Future.wait([
            client
                .from('daily_summary')
                .select('calories_consumed, protein_g, carbs_g, fat_g')
                .eq('user_id', uid)
                .eq('summary_date', day)
                .maybeSingle(),
            client
                .from('user_goals')
                .select('daily_calories, daily_protein_g, daily_carbs_g, daily_fat_g')
                .eq('user_id', uid)
                .maybeSingle(),
          ]);
          double g(String k) => (results[1]?[k] as num?)?.toDouble() ?? 0;
          double s(String k) => (results[0]?[k] as num?)?.toDouble() ?? 0;
          remain = (g('daily_calories') - s('calories_consumed'))
              .clamp(0.0, double.infinity);
          remainP = (g('daily_protein_g') - s('protein_g'))
              .clamp(0.0, double.infinity);
          remainC = (g('daily_carbs_g') - s('carbs_g'))
              .clamp(0.0, double.infinity);
          remainF = (g('daily_fat_g') - s('fat_g'))
              .clamp(0.0, double.infinity);
        } catch (e) {
          debugPrint('FAB suggest-meal budget read failed: $e');
        }
      }
      if (!mounted) return;
      nav.pop();
      await nav.push(SuggestMealPopupRoute(
        remainingKcal: remain,
        remainingProtein: remainP,
        remainingCarbs: remainC,
        remainingFat: remainF,
        onLogged: widget.onLogged,
      ));
    }

    return Transform.translate(
      offset: Offset(0, currentDrag),
      child: GestureDetector(
        // Grabbing anywhere on the sheet (not just the small handle) starts
        // the drag — matches how native bottom sheets behave and gives a
        // far more forgiving hit area than a 44×4 handle bar.
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle — purely a visual affordance now that the
                    // whole sheet responds to the drag gesture.
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title row
                    _Entrance(
                      animation: widget.routeAnimation,
                      begin: 0.0,
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const PixelArtIcon(
                                  type: PixelIconType.robot,
                                  size: 20,
                                  animate: true,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    l10n.foodLogSheetTitle,
                                    style: AppText.styledHeadlineMd(
                                      isArabic: isArabic,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: MaterialLocalizations.of(
                              context,
                            ).closeButtonLabel,
                            child: IconButton(
                              onPressed: () => nav.pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    _Entrance(
                      animation: widget.routeAnimation,
                      begin: 0.02,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.foodLogSheetSubtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontFamily: AppText.fontFamily(isArabic: isArabic),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hero — AI photo scan. The one volt-filled surface in
                    // the sheet; everything else stays quiet so this reads
                    // first.
                    _Entrance(
                      animation: widget.routeAnimation,
                      begin: 0.05,
                      child: Semantics(
                        button: true,
                        label: '${l10n.scanAi}. ${l10n.aiScanSubtitle}',
                        child: ExcludeSemantics(
                          child: _PressScale(
                            reduceMotion: reduceMotion,
                            onTap: () => runOption(
                              () => nav.push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => FoodScanScreen(
                                    initialMealType: defaultMealForNow(),
                                  ),
                                ),
                              ),
                            ),
                            child: Container(
                              height: 72,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.voltGradient,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.30,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    alignment: Alignment.center,
                                    child: PixelArtIcon(
                                      type: PixelIconType.robot,
                                      size: 22,
                                      animate: true,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                l10n.scanAi,
                                                style: TextStyle(
                                                  fontSize: 15.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.onPrimary,
                                                  fontFamily:
                                                      AppText.fontFamily(
                                                        isArabic: isArabic,
                                                      ),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'AI',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1,
                                                  color: AppColors.onPrimary,
                                                  fontFamily:
                                                      AppText.fontFamily(
                                                        isArabic: isArabic,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          l10n.aiScanSubtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.onPrimary
                                                .withValues(alpha: 0.78),
                                            fontFamily: AppText.fontFamily(
                                              isArabic: isArabic,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 15,
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Suggest-a-Meal — the AI planner entry. Gold/ember
                    // identity (the calorie-target language of the suggest
                    // flow) so it reads as its own path, not a third quiet
                    // tile and not a second volt hero.
                    _Entrance(
                      animation: widget.routeAnimation,
                      begin: 0.075,
                      child: Semantics(
                        button: true,
                        label: '${l10n.suggestMeal}. ${l10n.suggestCardSubtitle}',
                        child: ExcludeSemantics(
                          child: _PressScale(
                            reduceMotion: reduceMotion,
                            onTap: openSuggestMeal,
                            child: Container(
                              height: 64,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentCalories.withValues(
                                  alpha: AppColors.isLight ? 0.12 : 0.16,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppColors.accentCalories.withValues(
                                    alpha: AppColors.isLight ? 0.30 : 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.accentCalories
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: AppColors.accentCalories
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: PixelArtIcon(
                                      type: PixelIconType.plate,
                                      size: 22,
                                      color: AppColors.accentCalories,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.suggestMeal,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textPrimary,
                                            fontFamily: AppText.fontFamily(
                                              isArabic: isArabic,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          l10n.suggestCardSubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            fontFamily: AppText.fontFamily(
                                              isArabic: isArabic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: AppColors.accentCalories,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Voice + Text — the two other AI modes, equal weight.
                    _Entrance(
                      animation: widget.routeAnimation,
                      begin: 0.10,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionCard(
                              icon: Icons.mic_rounded,
                              label: l10n.voiceLog,
                              subtitle: l10n.voiceLogSubtitle,
                              isArabic: isArabic,
                              reduceMotion: reduceMotion,
                              onTap: () => runOption(
                                () => nav.push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => VoiceFoodLogScreen(
                                      initialMealType: defaultMealForNow(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _OptionCard(
                              icon: Icons.edit_note_rounded,
                              label: l10n.quickText,
                              subtitle: l10n.quickTextSubtitle,
                              isArabic: isArabic,
                              reduceMotion: reduceMotion,
                              onTap: () => runOption(
                                () => nav.push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => TextFoodLogScreen(
                                      initialMealType: defaultMealForNow(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Barcode + Add Meal — the non-AI paths, same card
                    // anatomy.
                    _Entrance(
                      animation: widget.routeAnimation,
                      begin: 0.15,
                      child: Row(
                        children: [
                          Expanded(
                            child: _OptionCard(
                              icon: Icons.qr_code_scanner_rounded,
                              label: l10n.barcodeScan,
                              subtitle: l10n.barcodeScanSubtitle,
                              isArabic: isArabic,
                              reduceMotion: reduceMotion,
                              onTap: () => runOption(
                                () => nav.push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => BarcodeScanScreen(
                                      initialMealType: defaultMealForNow(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _OptionCard(
                              icon: Icons.restaurant_rounded,
                              label: l10n.addMeal,
                              subtitle: l10n.addMealSubtitle,
                              isArabic: isArabic,
                              reduceMotion: reduceMotion,
                              onTap: openAddMeal,
                            ),
                          ),
                        ],
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

/// One option tile: tinted icon square, label, one-line hint. Surface-quiet
/// by design — the volt hero above them owns the sheet's attention.
class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isArabic;
  final bool reduceMotion;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isArabic,
    required this.onTap,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $subtitle',
      child: ExcludeSemantics(
        child: _PressScale(
          onTap: onTap,
          reduceMotion: reduceMotion,
          child: Container(
            height: 104,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: AppColors.accent),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Press feedback: scales to 0.96 while the pointer is down, springs back
/// on release. The shared micro-interaction of every tappable in the sheet.
class _PressScale extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool reduceMotion;

  const _PressScale({
    required this.onTap,
    required this.child,
    this.reduceMotion = false,
  });

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _pressed ? 0.96 : 1,
        child: widget.child,
      ),
    );
  }
}

/// Staggered entrance driven by the route's own animation so the whole
/// popup (slide + blur + card stagger) is one continuous motion — cards
/// fade in and rise a little, later ones starting slightly later.
class _Entrance extends StatelessWidget {
  final Animation<double> animation;
  final double begin;
  final Widget child;

  const _Entrance({
    required this.animation,
    this.begin = 0.0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, 1.0, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.14),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
