import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';
import '../pixel_art_icons.dart';

/// Volt hero sweep — the card's gold identity re-anchored to the app accent
/// (Electric Volt #D1FC00 on dark; darkened volt on light so the big kcal
/// number and bar keep contrast on white).
LinearGradient _voltSweep() => AppColors.isLight
    ? const LinearGradient(
        colors: [Color(0xFF9DBF00), Color(0xFF7A9900)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )
    : AppColors.voltGradient;

/// 12345 → "12,345" — thousands grouping for the kcal hero and the mg-scale
/// micros (sodium 1,380 / 2,300mg), shared by every text in this card.
String _group(int v) => v.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );

/// One metric rendered as a chip inside the [GlassCaloriesCard].
/// [icon] is passed prebuilt (pixel-art or Material) already tinted with
/// [color], since PixelArtIcon doesn't read IconTheme.
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

/// Solid-surface "Calories Today" card — two swipeable pages.
///
/// Structure (owner brief 2026-09-18: plain black card like the home page,
/// transparent hero-icon badge, no glow):
///   row 1  — 26×26 transparent icon badge + title + "Today" pill
///   row 2  — big kcal hero number (ShaderMask volt gradient) + "/ goal"
///   row 3  — volt progress bar (no glow)
///   row 4  — "% of goal" / remaining-or-over caption
///   below  — a 2-page PageView (the swipe the owner asked for):
///              page 1 · macronutrient chips (protein / carbs / fat)
///              page 2 · nutrient tiles (fiber, sugars, sodium)
///            No nested horizontal scrollers, so the page swipe always wins.
///            Two pagination dots — one per page; the active dot stretches
///            into a small pill in [AppColors.accent] (Electric Volt, the
///            app's active-state accent, used sparingly per design system).
///
/// Sizing pass: every padding/gap/font-size below was tightened from the
/// first version, which read as too tall on the actual home screen next to
/// the day strip and other cards — this trims the vertical footprint by
/// roughly a third without dropping anything (colors, motion, RTL handling,
/// and the 2-page swipe are unchanged from the original build).
///
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
  // keepPage:false — always open on the macros page; no stale PageStorage
  // offset can flash the micros page during a cold start.
  final PageController _pageController = PageController(keepPage: false);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isOverGoal =>
      widget.caloriesGoal > 0 && widget.caloriesConsumed > widget.caloriesGoal;

  double get _rawPercent => widget.caloriesGoal > 0
      ? widget.caloriesConsumed / widget.caloriesGoal
      : 0.0;

  double get _fillFraction => _rawPercent.clamp(0.0, 1.0);

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool over = _isOverGoal;

    return Container(
      decoration: BoxDecoration(
        // Plain surface fill — same near-black the sibling home cards use.
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: over ? AppColors.overGoalWarningBorder : AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderRow(l10n),
            const SizedBox(height: 8),
            _buildHeroRow(l10n),
            const SizedBox(height: 7),
            _ProgressBar(fraction: _fillFraction, over: over),
            const SizedBox(height: 6),
            _buildCaptionRow(l10n),
            const SizedBox(height: 8),
            _buildPages(),
            const SizedBox(height: 6),
            _buildPageDots(),
          ],
        ),
      ),
    );
  }

  // ── Row 1: icon badge + title + Today pill ──
  Widget _buildHeaderRow(AppLocalizations l10n) {
    return Row(
      children: [
        // Transparent badge — just the volt flame floating on the card
        // (owner brief 2026-09-18: no green box, no glow).
        SizedBox(
          width: 26,
          height: 26,
          child: Center(
            child: PixelArtIcon(
              type: PixelIconType.fire,
              size: 15,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            l10n.todayCalories,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: AppColors.glass3,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            widget.pillText ?? l10n.today,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Row 2: kcal hero (ShaderMask ≙ background-clip: text) ──
  Widget _buildHeroRow(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.caloriesConsumed),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ShaderMask(
            shaderCallback: (bounds) => _voltSweep().createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              _group(value.round()),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '/ ${_group(widget.caloriesGoal.round())} ${l10n.kcal}',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── Row 4: % of goal + remaining/over ──
  Widget _buildCaptionRow(AppLocalizations l10n) {
    final over = _isOverGoal;
    return Row(
      children: [
        Text(
          l10n.percentOfGoal((_rawPercent * 100).round()),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: over ? AppColors.overGoalWarning : AppColors.accent,
          ),
        ),
        const Spacer(),
        Text(
          over
              ? l10n.caloriesOverMsg(
                  (widget.caloriesConsumed - widget.caloriesGoal).round(),
                )
              : l10n.caloriesRemainingMsg(
                  (widget.caloriesGoal - widget.caloriesConsumed).round(),
                ),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: over ? AppColors.overGoalWarning : AppColors.accent,
          ),
        ),
      ],
    );
  }

  // ── The two swipeable pages ──
  Widget _buildPages() {
    return SizedBox(
      height: 112,
      child: PageView(
        controller: _pageController,
        onPageChanged: (page) => setState(() => _page = page),
        children: [
          // Page 1 — macronutrients: 3 equal chips across the card.
          Row(
            children: [
              for (int i = 0; i < widget.macros.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _ChipCard(metric: widget.macros[i])),
              ],
            ],
          ),
          // Page 2 — fiber / sugars / sodium: same anatomy as the macros
          // page (icon badge + label, value/goal, mini bar) and stretched to
          // the same full page height, so swiping between the two pages
          // never changes the card's rhythm (owner brief 2026-09-18: only
          // these three metrics on the micros page).
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < widget.micros.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _MicroTile(metric: widget.micros[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 2 dots: one per page ──
  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (page) {
        final active = _page == page;
        return GestureDetector(
          onTap: () => _goToPage(page),
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
}

// ─── Volt progress bar (no glow — owner brief 2026-09-18) ───────────────────
class _ProgressBar extends StatelessWidget {
  final double fraction;
  final bool over;

  const _ProgressBar({required this.fraction, required this.over});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: Stack(
        children: [
          // Track
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glass3,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          // Fill — animates on data change (~550ms ease-out)
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
                        gradient: over ? null : _voltSweep(),
                        color: over ? AppColors.overGoalWarning : null,
                        borderRadius: BorderRadius.circular(2.5),
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

// ─── Macronutrient chip (page 1) ────────────────────────────────────────────
class _ChipCard extends StatelessWidget {
  final NutrientChipMetric metric;

  const _ChipCard({required this.metric});

  static String _fmt(double v) =>
      v >= 100 || v % 1 == 0 ? _group(v.round()) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final m = metric;
    final double pct = m.goal > 0 ? (m.value / m.goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: m.icon),
          ),
          const SizedBox(height: 6),
          Text(
            m.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  '${_fmt(m.value)}${m.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  '/ ${_fmt(m.goal)}${m.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _MiniBar(fraction: pct, color: m.color, height: 3.5),
        ],
      ),
    );
  }
}

// ─── Additional-nutrient tile (page 2) ──────────────────────────────────────
class _MicroTile extends StatelessWidget {
  final NutrientChipMetric metric;

  const _MicroTile({required this.metric});

  static String _fmt(double v) =>
      v >= 100 || v % 1 == 0 ? _group(v.round()) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final m = metric;
    final double pct = m.goal > 0 ? (m.value / m.goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.glass2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: m.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(child: m.icon),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${_fmt(m.value)}${m.unit}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '/ ${_fmt(m.goal)}${m.unit}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _MiniBar(fraction: pct, color: m.color, height: 3.5),
        ],
      ),
    );
  }
}

// ─── Tiny animated progress bar shared by chips/tiles ───────────────────────
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
