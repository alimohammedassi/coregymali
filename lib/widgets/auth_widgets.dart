import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared auth UI — Login / Sign Up / Verify Code.
//
// Dark-pinned (the auth flow's primary theme): only AppColors dark-scheme
// consts + mode-independent consts are used, so a light-mode switch elsewhere
// never washes these screens out. No hardcoded hex.
// All widgets are RTL-safe (Directional paddings/alignments, ambient rows).
// ─────────────────────────────────────────────────────────────────────────────

/// Canonical brand logo: `assets/logo/9a1b06b2-14a3-4355-b66d-09b492435da1.png`
/// — the "C" mark on a transparent backdrop.
///
/// The C sits centered in the artwork occupying ≈ 37% of its side, so a center
/// zoom keeps only the mark: [logoCrop] of the image side is shown, letting
/// the C fill the box with a little breathing room.
class AuthLogo extends StatelessWidget {
  final double height;
  const AuthLogo({super.key, this.height = 44});

  static const _asset =
      'assets/logo/9a1b06b2-14a3-4355-b66d-09b492435da1.png';
  /// Fraction of the source image side kept by the center zoom.
  static const _logoCrop = 0.46;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.appName;
    final zoomed = height / _logoCrop;
    return Semantics(
      label: label,
      image: true,
      child: Hero(
        tag: 'app_logo',
        child: SizedBox(
          width: height,
          height: height,
          child: OverflowBox(
            maxWidth: zoomed,
            maxHeight: zoomed,
            alignment: Alignment.center,
            child: Image.asset(
              _asset,
              width: zoomed,
              height: zoomed,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.fitness_center_rounded,
                color: AppColors.primaryFixed,
                size: height * 0.7,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost language pill: transparent fill, 1px border, lime text, 36 px tall
/// (padded to a 44 px hit target). Same behavior as the old toggle.
class GhostLangPill extends StatelessWidget {
  const GhostLangPill({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final isAr = provider.isArabic;
    return Semantics(
      label: isAr ? 'EN' : 'عر',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: provider.toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            height: 36,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    AppColors.primaryFixed.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Text(
              isAr ? 'EN' : 'عر',
              style: TextStyle(
                fontFamily: AppText.fontFamily(isArabic: isAr),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryFixed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header shared by the auth screens: real logo at the directional start,
/// ghost language pill at the directional end.
class AuthHeader extends StatelessWidget {
  final bool showLanguage;
  final Widget? trailing;
  const AuthHeader({super.key, this.showLanguage = true, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AuthLogo(),
        const Spacer(),
        if (trailing != null) trailing!,
        if (showLanguage) const GhostLangPill(),
      ],
    );
  }
}

/// Auth screen background: solid near-black plus ONE subtle top radial lime
/// glow (alpha 0.06) rendered as a gradient — no blob images.
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBackground,
      child: Stack(
        children: [
          Positioned(
            top: -140,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 320,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 0.75,
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Two-tone headline: first word white, second word lime, muted subtitle.
class AuthTwoToneTitle extends StatelessWidget {
  final String first;
  final String second;
  final String? subtitle;
  const AuthTwoToneTitle({
    super.key,
    required this.first,
    required this.second,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: font,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
            children: [
              TextSpan(
                text: first,
                style: const TextStyle(color: AppColors.darkTextPrimary),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: second,
                style: TextStyle(color: AppColors.primaryFixed),
              ),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: font,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Single auth field directly on the background: neutral dark surface fill,
/// 1 px subtle border, radius 14, height 54. Focus → animated 1.5 px lime
/// border. Error → red border + helper text under the field.
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.autofillHints,
    this.onChanged,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: font,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? AppColors.primaryFixed : AppColors.darkBorder,
              width: _focused ? 1.5 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: AppColors.primaryFixed.withValues(alpha: 0.18),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            cursorColor: AppColors.primaryFixed,
            style: TextStyle(
              color: AppColors.darkTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: font,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(widget.icon, size: 20,
                  color: _focused
                      ? AppColors.primaryFixed
                      : AppColors.darkTextSecondary),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}

/// Form-level error line (the field itself hides Flutter's inline error so
/// the 54 px box never jumps; errors render here instead).
class AuthFormError extends StatelessWidget {
  final String? message;
  const AuthFormError({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message!,
        style: TextStyle(
          fontFamily: AppText.fontFamily(isArabic: isArabic),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.error,
        ),
      ),
    );
  }
}

/// Sticky primary CTA: height 56, lime gradient, dark text, soft shadow.
/// Disabled until the form is valid, spinner while loading.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.enabled,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final active = enabled && !isLoading;
    return Semantics(
      button: true,
      enabled: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? onTap : null,
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: active ? 1 : 0.45,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.primaryActionGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      AppColors.primaryFixed.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Muted divider with 1 px lines ("or continue with").
class AuthDivider extends StatelessWidget {
  final String label;
  const AuthDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.darkBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppText.fontFamily(isArabic: isArabic),
              color: AppColors.darkTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.darkBorder)),
      ],
    );
  }
}

/// Official multicolor Google "G" (24-unit brand artwork, transcribed).
class GoogleGIcon extends StatelessWidget {
  final double size;
  const GoogleGIcon({super.key, this.size = 20});

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The brand artwork below lives on a 24×24 grid — scale by 24, not 48,
    // or the G renders at half size pinned to the top-left corner.
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s);
    void fill(Path p, Color c) =>
        canvas.drawPath(p, Paint()..color = c..style = PaintingStyle.fill);

    final blue = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10.0)
      ..lineTo(12, 10)
      ..lineTo(12, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    final green = Path()
      ..moveTo(12, 23)
      ..cubicTo(14.97, 23, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1)
      ..lineTo(2.18, 14.1)
      ..lineTo(2.18, 16.94)
      ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
      ..close();
    final yellow = Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12.0)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.07)
      ..lineTo(2.18, 7.07)
      ..cubicTo(1.44, 8.55, 1, 10.22, 1, 12)
      ..cubicTo(1, 13.78, 1.44, 15.45, 2.18, 16.93)
      ..lineTo(5.84, 14.09)
      ..close();
    final red = Path()
      ..moveTo(12, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
      ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
      ..lineTo(5.84, 9.91)
      ..cubicTo(6.71, 7.31, 9.14, 5.38, 12, 5.38)
      ..close();

    fill(blue, GoogleGIcon._blue);
    fill(green, GoogleGIcon._green);
    fill(yellow, GoogleGIcon._yellow);
    fill(red, GoogleGIcon._red);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Apple glyph (white silhouette).
class AppleMark extends StatelessWidget {
  final double size;
  const AppleMark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ApplePainter()),
    );
  }
}

class _ApplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Artwork is the 384×512 FontAwesome apple: scale UNIFORMLY to the box
    // height (a per-axis scale stretches it fat in a square box) and center
    // the narrower result horizontally.
    final s = size.height / 512;
    final dx = (size.width - 384 * s) / 2;
    canvas.save();
    canvas.translate(dx, 0);
    canvas.scale(s);
    final p = Path()
      ..moveTo(318.7, 268.7)
      ..cubicTo(318.5, 232.0, 335.1, 204.3, 368.7, 183.9)
      ..cubicTo(349.9, 157.0, 321.5, 142.2, 284.0, 139.3)
      ..cubicTo(248.5, 136.5, 209.7, 160.0, 195.5, 160.0)
      ..cubicTo(180.5, 160.0, 146.1, 140.3, 119.1, 140.3)
      ..cubicTo(63.3, 141.2, 4, 184.8, 4, 273.5)
      ..quadraticBezierTo(4, 312.8, 18.4, 354.7)
      ..cubicTo(31.2, 391.4, 77.4, 481.4, 125.6, 479.9)
      ..cubicTo(150.8, 479.3, 168.6, 462.0, 201.4, 462.0)
      ..cubicTo(233.2, 462.0, 249.7, 479.9, 277.8, 479.9)
      ..cubicTo(326.4, 479.2, 368.2, 397.4, 380.4, 360.6)
      ..cubicTo(315.2, 329.9, 318.7, 270.6, 318.7, 268.7)
      ..moveTo(262.1, 104.5)
      ..cubicTo(289.4, 72.1, 286.9, 42.6, 286.1, 32.0)
      ..cubicTo(262.0, 33.4, 234.1, 48.4, 218.2, 66.9)
      ..cubicTo(200.7, 86.7, 190.4, 111.2, 192.6, 138.8)
      ..cubicTo(218.7, 140.8, 242.5, 127.4, 262.1, 104.5)
      ..close();
    canvas.drawPath(
        p, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Outlined dark social buttons, equal height 52, side by side.
class AuthSocialButtons extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  const AuthSocialButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            icon: const GoogleGIcon(),
            label: l10n.google,
            onTap: onGoogle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            icon: const AppleMark(),
            label: l10n.apple,
            onTap: onApple,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppText.fontFamily(isArabic: isArabic),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin password-strength bar (localized label).
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  static int scoreOf(String value) {
    var score = 0;
    if (value.length >= 6) score++;
    if (value.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'[a-z]').hasMatch(value)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score.clamp(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (password.isEmpty) return const SizedBox.shrink();
    final score = scoreOf(password);
    final fraction = score / 5;
    final Color color;
    final String label;
    if (score <= 1) {
      color = AppColors.error;
      label = l10n.authStrengthWeak;
    } else if (score <= 3) {
      color = AppColors.accentCalories;
      label = l10n.authStrengthFair;
    } else {
      color = AppColors.primaryFixed;
      label = l10n.authStrengthStrong;
    }
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: AppColors.darkBorder,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppText.fontFamily(isArabic: isArabic),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim segmented Login/Sign Up switcher, height 46, animated lime pill.
class AuthSegmentedTabs extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;
  const AuthSegmentedTabs({
    super.key,
    required this.isLogin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder, width: 1),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppDurations.medium,
            curve: AppCurves.standard,
            alignment: isLogin
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryActionGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Tab(
                  label: l10n.loginTab,
                  font: font,
                  selected: isLogin,
                  onTap: () => onChanged(true),
                ),
              ),
              Expanded(
                child: _Tab(
                  label: l10n.signUpTab,
                  font: font,
                  selected: !isLogin,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String? font;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({
    required this.label,
    required this.font,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: AppDurations.fast,
          style: TextStyle(
            fontFamily: font,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? AppColors.onPrimary
                : AppColors.darkTextSecondary,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Terms row: muted body text, lime underlined links (tap → callback),
/// custom rounded-square checkbox (lime fill + dark check when selected),
/// error tint + shake handled by the parent via [shake] + [showError].
class AuthTermsRow extends StatelessWidget {
  final bool value;
  final bool showError;
  final AnimationController? shakeController;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLegalTap;
  const AuthTermsRow({
    super.key,
    required this.value,
    required this.showError,
    required this.onChanged,
    required this.onLegalTap,
    this.shakeController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: l10n.agreeTerms,
          checked: value,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.all(11), // 44 px hit target
              child: AnimatedContainer(
                duration: AppDurations.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.primaryFixed : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: showError && !value
                        ? AppColors.error
                        : value
                            ? AppColors.primaryFixed
                            : AppColors.darkTextSecondary,
                    width: 1.5,
                  ),
                ),
                child: value
                    ? Icon(Icons.check_rounded,
                        size: 15, color: AppColors.onPrimary)
                    : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: font,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.darkTextSecondary,
                height: 1.5,
              ),
              children: [
                TextSpan(text: l10n.agreeTerms),
                TextSpan(
                  text: l10n.termsConditions,
                  style: TextStyle(
                    color: AppColors.primaryFixed,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onLegalTap,
                ),
                TextSpan(text: l10n.and),
                TextSpan(
                  text: l10n.privacyPolicy,
                  style: TextStyle(
                    color: AppColors.primaryFixed,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onLegalTap,
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final controller = shakeController;
    if (controller == null) return row;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final t = controller.value;
        // Damped oscillation: ±8 px decaying to rest.
        final dx = (t == 0 || t == 1)
            ? 0.0
            : 8 * (1 - t) * math.sin(t * 4 * math.pi);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: row,
    );
  }
}
