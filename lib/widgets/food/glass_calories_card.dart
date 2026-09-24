import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../pixel_art_icons.dart';

/// White/black sweep for the kcal hero digits — dark → white, light → black
/// (the app's established hero treatment; the owner's 2026-09-23 2nd-pass
/// brief pulled the card back to the app theme: no glass-morphic gold).
LinearGradient _voltSweep() => AppColors.isLight
    ? const LinearGradient(
        colors: [Colors.black, Colors.black],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )
    : const LinearGradient(
        colors: [Colors.white, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

/// 12345 → "12,345" — thousands grouping for the kcal hero and the mg-scale
/// micros (sodium 1,380 / 2,300mg), shared by every text in this card.
String _group(int v) =>
    v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

bool _isArabic(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar';

/// Converts Western digits/punctuation to Eastern Arabic when the app is
/// in Arabic — "1,846" → "١٬٨٤٦", "12.5" → "١٢٫٥", "62%" → "٦٢٪".
String _localize(String input, BuildContext context) {
  if (!_isArabic(context)) return input;
  const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  final sb = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final ch = input[i];
    final code = ch.codeUnitAt(0);
    if (code >= 48 && code <= 57) {
      sb.write(eastern[code - 48]);
    } else if (ch == ',') {
      sb.write('٬'); // U+066C Arabic thousands separator
    } else if (ch == '.') {
      sb.write('٫'); // U+066B Arabic decimal separator
    } else if (ch == '%') {
      sb.write('٪'); // U+066A Arabic percent sign
    } else {
      sb.write(ch);
    }
  }
  return sb.toString();
}

String _groupL(int v, BuildContext context) => _localize(_group(v), context);

String _fmtL(double v, BuildContext context) {
  final raw = v >= 100 || v % 1 == 0 ? _group(v.round()) : v.toStringAsFixed(1);
  return _localize(raw, context);
}

/// One metric rendered inside the [GlassCaloriesCard] block.
/// [icon] is passed prebuilt (pixel-art) already sized/tinted, since
/// PixelArtIcon doesn't read IconTheme.
class NutrientChipMetric {
  final String label;
  final double value;
  final double goal;
  final String unit;
  final Color color;
  final Widget icon;

  const NutrientChipMetric({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
    required this.icon,
  });
}

/// "Calories Today" block — two swipeable pages (the pages STAY per the
/// owner's 2026-09-23 rule; 2026-09-24 4th pass reworked page 2 + toggle):
///
///   page 1  — hero surface card (amber-badged pixel flame + title + Today
///             pill, accentCalories amber bar, big volt-sweep kcal number)
///             + three compact macro cards (tinted fill, colored squircle
///             icon badge, colored mini bar, value/goal)
///   page 2  — ONE surface card in the hero's language (no tinted slabs —
///             owner: the old rows read as loose colored slabs) with the
///             three micros as one-line rows split by hairline dividers;
///             color lives only in each row's dot
///   below   — 2 pagination dots (volt active) + COMPACT centered
///             Consumed/Remaining toggle (volt selected, near-black ink)
///
/// Over goal: hero border + bar + kcal number turn amber-warning.
/// Everything is directionality-safe (EdgeInsetsDirectional /
/// AlignmentDirectional); the PageView flips automatically under RTL.
class GlassCaloriesCard extends StatefulWidget {
  final double caloriesConsumed;
  final double caloriesGoal;
  final List<NutrientChipMetric> macros;
  final List<NutrientChipMetric> micros;

  /// Header pill text. Null = today (l10n "TODAY"); home passes a short
  /// date label instead when a past day is selected in the week strip.
  final String? pillText;

  const GlassCaloriesCard({
    super.key,
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.macros,
    required this.micros,
    this.pillText,
  });

  @override
  State<GlassCaloriesCard> createState() => _GlassCaloriesCardState();
}

class _GlassCaloriesCardState extends State<GlassCaloriesCard> {
  // Page geometry: hero 100 + gap 12 + macro cards 102 = 214. Page 2 is a
  // single hero-language surface card (height 214) whose three one-line
  // micro rows share it evenly, split by hairline dividers.
  static const double _pageHeight = 214;
  static const double _heroHeight = 100;
  static const double _cardHeight = 102;

  // keepPage:false — always open on the macros page; no stale PageStorage
  // offset can flash the micros page during a cold start.
  final PageController _pageController = PageController(keepPage: false);
  int _page = 0;
  bool _remainingMode = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isOverGoal =>
      widget.caloriesGoal > 0 && widget.caloriesConsumed > widget.caloriesGoal;

  double get _fillFraction => widget.caloriesGoal > 0
      ? (widget.caloriesConsumed / widget.caloriesGoal).clamp(0.0, 1.0)
      : 0.0;

  /// Value shown for a metric under the current Consumed/Remaining mode.
  double _displayValue(NutrientChipMetric m) =>
      _remainingMode ? (m.goal - m.value).clamp(0.0, double.infinity) : m.value;

  double _fractionFor(NutrientChipMetric m) =>
      m.goal > 0 ? (_displayValue(m) / m.goal).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _pageHeight,
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _page = page),
            children: [_buildMainPage(l10n), _buildMicrosPage(l10n)],
          ),
        ),
        const SizedBox(height: 12),
        _buildPageDots(),
        const SizedBox(height: 12),
        _buildModeSwitch(l10n),
      ],
    );
  }

  // ── Page 1: hero card + three compact macro cards ──
  Widget _buildMainPage(AppLocalizations l10n) {
    return Column(
      children: [
        _buildHeroCard(l10n),
        const SizedBox(height: 12),
        SizedBox(
          height: _cardHeight,
          child: Row(
            children: [
              for (int i = 0; i < widget.macros.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _NutrientCard(metric: widget.macros[i], state: this),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Page 2: ONE surface card — fiber / sugars / sodium as one-line rows ──
  Widget _buildMicrosPage(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < widget.micros.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.glass3,
              ),
            Expanded(
              child: _MicroRow(metric: widget.micros[i], state: this),
            ),
          ],
        ],
      ),
    );
  }

  // ── 2 dots: one per page (volt active — the app's active-state accent) ──
  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (page) {
        final active = _page == page;
        return GestureDetector(
          onTap: () => _pageController.animateToPage(
            page,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: active ? 18 : 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent
                  : AppColors.textMuted.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        );
      }),
    );
  }

  // ── Hero card (surface fill, amber bar, big kcal number) ──
  Widget _buildHeroCard(AppLocalizations l10n) {
    final bool over = _isOverGoal;
    final int display = _remainingMode
        ? (widget.caloriesGoal - widget.caloriesConsumed)
              .clamp(0.0, double.infinity)
              .round()
        : widget.caloriesConsumed.round();

    return Container(
      height: _heroHeight,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: over ? AppColors.overGoalWarningBorder : AppColors.glassBorder,
          width: over ? 1.4 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row — flame sits in a soft amber squircle badge so it
          // reads as a deliberate icon, not a stray emoji-sized glyph.
          SizedBox(
            height: 26,
            child: Row(
              children: [
                _IconBadge(
                  color: AppColors.accentCalories,
                  child: const PixelArtIcon(type: PixelIconType.fire, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    l10n.todayCalories,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.glass3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    _localize(widget.pillText ?? l10n.today, context),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _HeroBar(fraction: _fillFraction, over: over),
          SizedBox(
            height: 32,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: display.toDouble()),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    final text = Text(
                      _groupL(value.round(), context),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -0.6,
                        // Over goal: flat warning reads instantly (no sweep).
                        color: over
                            ? AppColors.overGoalWarning
                            : Colors.white, // mask base — sweep wins
                      ),
                    );
                    if (over) return text;
                    return ShaderMask(
                      shaderCallback: (bounds) =>
                          _voltSweep().createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: text,
                    );
                  },
                ),
                const SizedBox(width: 6),
                Text(
                  _localize(
                    '/ ${_group(widget.caloriesGoal.round())} ${l10n.kcal}',
                    context,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Consumed / Remaining segmented toggle — volt selected pill ──
  // 2026-09-24: COMPACT + centered — the full-width track shouted louder
  // than the hero above it (owner call).
  Widget _buildModeSwitch(AppLocalizations l10n) {
    return Center(
      child: SizedBox(
        width: 264,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glass2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              _buildSegment(
                l10n.eaten,
                selected: !_remainingMode,
                onTap: () {
                  if (_remainingMode) setState(() => _remainingMode = false);
                },
              ),
              _buildSegment(
                l10n.caloriesRemaining,
                selected: _remainingMode,
                onTap: () {
                  if (!_remainingMode) setState(() => _remainingMode = true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegment(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            // Selected segment = the app's volt accent (buttons/nav language)
            // with near-black ink — never a gray wash.
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.3,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? AppColors.onPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tinted decorations (the app's outlined-tint card language) ──────────────
Color _tintFill(Color c) =>
    AppColors.isLight ? c.withValues(alpha: 0.12) : c.withValues(alpha: 0.18);

Color _tintBorder(Color c) =>
    AppColors.isLight ? c.withValues(alpha: 0.26) : c.withValues(alpha: 0.32);

// ─── Squircle icon badge — color-coded, shared by hero and nutrient cards ───
class _IconBadge extends StatelessWidget {
  final Color color;
  final Widget child;

  const _IconBadge({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: _tintFill(color),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _tintBorder(color)),
      ),
      child: Center(child: child),
    );
  }
}

// ─── Nutrient card — ONE anatomy for macros AND micros ──────────────────────
class _NutrientCard extends StatelessWidget {
  final NutrientChipMetric metric;
  final _GlassCaloriesCardState state;

  const _NutrientCard({required this.metric, required this.state});

  @override
  Widget build(BuildContext context) {
    final m = metric;
    final double value = state._displayValue(m);
    final bool over = !state._remainingMode && m.goal > 0 && m.value > m.goal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _tintFill(m.color),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _tintBorder(m.color)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(color: m.color, child: m.icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _MiniBar(fraction: state._fractionFor(m), color: m.color, height: 5),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${_fmtL(value, context)}${m.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: over
                            ? AppColors.overGoalWarning
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '/ ${_fmtL(m.goal, context)}${m.unit}',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Micro-nutrient row (page 2) — one line inside the single surface card ──
/// Colored dot + label + value/goal. The row carries NO chrome of its own —
/// the hero-language surface card around it (see _buildMicrosPage) does.
class _MicroRow extends StatelessWidget {
  final NutrientChipMetric metric;
  final _GlassCaloriesCardState state;

  const _MicroRow({required this.metric, required this.state});

  @override
  Widget build(BuildContext context) {
    final m = metric;
    final double value = state._displayValue(m);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: m.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${_fmtL(value, context)}${m.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '/ ${_fmtL(m.goal, context)}${m.unit}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero progress bar — amber (calories accent), warning on over ───────────
class _HeroBar extends StatelessWidget {
  final double fraction;
  final bool over;

  const _HeroBar({required this.fraction, required this.over});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glass3,
                borderRadius: BorderRadius.circular(3.5),
              ),
            ),
          ),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                if (value <= 0) return const SizedBox.shrink();
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: over
                            ? AppColors.overGoalWarning
                            : AppColors.accentCalories,
                        borderRadius: BorderRadius.circular(3.5),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tiny animated progress bar shared by every nutrient card ───────────────
class _MiniBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const _MiniBar({
    required this.fraction,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.glass3,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              if (value <= 0) return const SizedBox.shrink();
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
