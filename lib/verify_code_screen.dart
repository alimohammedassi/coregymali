import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n/app_localizations.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'widgets/auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VerifyCodeScreen — email OTP entry (Supabase Auth).
//
// UI/structure refactor: same dark theme + shared header as Login/Sign Up
// (AuthBackground, AuthLogo with Hero 'app_logo', GhostLangPill), fully
// RTL-safe — digit boxes stay LTR internally, everything else mirrors.
//
// LOGIC IS UNTOUCHED: adaptive 6–10 digit codes (this project emails 8),
// paste / OTP-autofill instant verify, 60 s resend cooldown, shake on error,
// OtpType.signup / OtpType.recovery, onVerified / onSignInTap callbacks.
//
// Requires in the Supabase dashboard:
//   Auth → Providers → Email → "Confirm email" ON
//   Auth → Email Templates → "Confirm signup" (and "Reset password") must
//   print {{ .Token }} instead of {{ .ConfirmationURL }}.
// ─────────────────────────────────────────────────────────────────────────────

enum VerifyFlow { signup, recovery }

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final VerifyFlow flow;

  /// Called after the code is verified and a session exists.
  /// Default: pop back to the first route (an auth-state listener / AuthGate
  /// will then route the user in).
  final VoidCallback? onVerified;

  /// Called when "SIGN IN" at the bottom is tapped. Default: pop to first route.
  final VoidCallback? onSignInTap;

  const VerifyCodeScreen({
    super.key,
    required this.email,
    this.flow = VerifyFlow.signup,
    this.onVerified,
    this.onSignInTap,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen>
    with SingleTickerProviderStateMixin {
  static const int _minCodeLength = 6;
  static const int _maxCodeLength = 10;
  static const int _resendSeconds = 60;

  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake;

  Timer? _timer;
  int _cooldown = 0;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  /// Length of the code before the last input edit — lets _onChanged detect
  /// a paste / keyboard OTP autofill (the whole code lands in one edit).
  int _lastLength = 0;

  String get _code => _controller.text;

  bool get _isArabic =>
      Localizations.localeOf(context).languageCode == 'ar';

  String? get _font => AppText.fontFamily(isArabic: _isArabic);

  /// Boxes rendered: 6 by design, grows to match a longer (7–10 digit) code
  /// as it's typed, so an 8-digit code from the server fits visually.
  int get _boxCount =>
      math.max(_minCodeLength, math.min(_maxCodeLength, _code.length));

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shake.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ─── Cooldown ──────────────────────────────────────────────────────────────
  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  // ─── Input ─────────────────────────────────────────────────────────────────
  void _onChanged(String text) {
    // A paste or keyboard OTP autofill replaces/inserts the WHOLE code in a
    // single edit (length jumps by >1). That is an explicit "here's my full
    // code" — verify it immediately. Typing digit-by-digit never auto-submits:
    // the server's OTP length is a dashboard setting (6–10) and this project
    // sends 8, so firing at 6 digits would guarantee a failed attempt.
    final jumped = (text.length - _lastLength).abs() > 1;
    _lastLength = text.length;
    setState(() => _error = null);
    if (jumped && text.length >= _minCodeLength) _verify();
  }

  // ─── Verify ────────────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (_verifying) return;
    final l10n = AppLocalizations.of(context)!;
    if (_code.length < _minCodeLength) {
      _fail(l10n.verifyErrIncomplete);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await _supabase.auth.verifyOTP(
        email: widget.email,
        token: _code,
        type: widget.flow == VerifyFlow.signup
            ? OtpType.signup
            : OtpType.recovery,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      if (widget.onVerified != null) {
        widget.onVerified!();
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (e.statusCode == '429' || msg.contains('rate limit')) {
        _fail(l10n.verifyErrRateLimit);
      } else if (msg.contains('expired') || msg.contains('invalid')) {
        // A 6-digit entry rejected as "invalid" most often means the code
        // wasn't fully typed yet (this project emails 8 digits) — nudge the
        // user to keep going instead of dead-ending them.
        _fail(_code.length == _minCodeLength
            ? l10n.verifyErrKeepTyping
            : l10n.verifyErrInvalid);
      } else {
        _fail(e.message);
      }
    } catch (_) {
      if (!mounted) return;
      _fail(l10n.verifyErrConnection);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _fail(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = message;
      _controller.clear();
      _lastLength = 0; // keep paste-detection in sync with the clear
    });
    _shake.forward(from: 0);
    _focus.requestFocus();
  }

  // ─── Resend ────────────────────────────────────────────────────────────────
  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    final l10n = AppLocalizations.of(context)!;
    HapticFeedback.lightImpact();
    setState(() {
      _resending = true;
      _error = null;
    });

    try {
      if (widget.flow == VerifyFlow.signup) {
        await _supabase.auth.resend(type: OtpType.signup, email: widget.email);
      } else {
        await _supabase.auth.resetPasswordForEmail(widget.email);
      }
      if (!mounted) return;
      _controller.clear();
      _lastLength = 0; // keep paste-detection in sync with the clear
      _startCooldown();
      _snack(l10n.verifySnackResent);
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      _snack(
        (e.statusCode == '429' || msg.contains('rate limit'))
            ? l10n.verifySnackWait
            : e.message,
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;
      _snack(l10n.verifySnackFailed, isError: true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _snack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: TextStyle(fontFamily: _font)),
          backgroundColor:
              isError ? AppColors.error : AppColors.darkTextPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _goSignIn() {
    if (widget.onSignInTap != null) {
      widget.onSignInTap!();
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Semantics(
                      label: MaterialLocalizations.of(context).backButtonTooltip,
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Padding(
                          padding: const EdgeInsets.all(10), // 44 px target
                          child: Icon(
                            isRtl
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_back_rounded,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: AuthLogo(height: 40)),
                    const GhostLangPill(),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 8),
                        _buildSubtitle(),
                        const SizedBox(height: 24),
                        _buildCodeBoxes(),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 12.5,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildVerifyButton(),
                        const SizedBox(height: 16),
                        Center(child: _buildResendRow()),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        // Recovery flow asks a different question than signup.
                        widget.flow == VerifyFlow.recovery
                            ? AppLocalizations.of(context)!
                                .verifyDidntRemember
                            : AppLocalizations.of(context)!.verifyRemember,
                        style: TextStyle(
                          fontFamily: _font,
                          fontSize: 11,
                          letterSpacing: _isArabic ? 0 : 1.4,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _goSignIn,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            AppLocalizations.of(context)!.verifySignIn,
                            style: TextStyle(
                              fontFamily: _font,
                              fontSize: 11,
                              letterSpacing: _isArabic ? 0 : 1.4,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryFixed,
                            ),
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
      ),
    );
  }

  Widget _buildSubtitle() {
    final l10n = AppLocalizations.of(context)!;
    final email = _isArabic ? widget.email : widget.email.toUpperCase();
    return Text(
      l10n.verifySubtitle(email),
      style: TextStyle(
        fontFamily: _font,
        fontSize: 14,
        height: 1.5,
        letterSpacing: _isArabic ? 0 : 0.6,
        color: AppColors.darkTextSecondary,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildTitle() {
    final l10n = AppLocalizations.of(context)!;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: _font,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        children: [
          TextSpan(
            text: l10n.verifyTitle1,
            style:
                const TextStyle(color: AppColors.darkTextPrimary),
          ),
          const TextSpan(text: ' '),
          TextSpan(
            text: l10n.verifyTitle2,
            style: TextStyle(color: AppColors.primaryFixed),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBoxes() {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: SizedBox(
        height: 64,
        // Digits always flow left-to-right, even in RTL locales.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              // Visual boxes
              Row(
                children: List.generate(_boxCount, (i) {
                  final filled = i < _code.length;
                  final active = _focus.hasFocus &&
                      i == math.min(_code.length, _boxCount - 1);
                  final hasError = _error != null;
                  return Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: i == _boxCount - 1 ? 0 : 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasError
                                ? AppColors.error
                                : active
                                    ? AppColors.primaryFixed
                                    : AppColors.darkBorder,
                            width: active || hasError ? 2 : 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          filled ? _code[i] : '',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              // Invisible input on top: handles typing, paste and OTP autofill
              Positioned.fill(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  cursorColor: Colors.transparent,
                  style:
                      const TextStyle(color: Colors.transparent, fontSize: 1),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_maxCodeLength),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _verify(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final l10n = AppLocalizations.of(context)!;
    final enabled = _code.length >= _minCodeLength && !_verifying;
    return Opacity(
      opacity: (enabled || _verifying) ? 1 : 0.6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _verify : null,
        child: Semantics(
          button: true,
          enabled: enabled,
          child: Container(
            height: 56,
            padding: const EdgeInsetsDirectional.only(start: 24, end: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppColors.primaryActionGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryFixed.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.verifyButton,
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 16,
                        letterSpacing: _isArabic ? 0 : 2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.onPrimary,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: _verifying
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primaryFixed,
                          ),
                        )
                      : Icon(Icons.bolt_rounded,
                          size: 20, color: AppColors.primaryFixed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResendRow() {
    final l10n = AppLocalizations.of(context)!;
    final labelStyle = TextStyle(
      fontFamily: _font,
      fontSize: 11,
      letterSpacing: _isArabic ? 0 : 1.4,
      fontWeight: FontWeight.w800,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.verifyDidntReceive,
            style:
                labelStyle.copyWith(color: AppColors.darkTextSecondary)),
        const SizedBox(width: 8),
        if (_cooldown > 0)
          Text(l10n.verifyResendIn(_cooldown),
              style: labelStyle.copyWith(
                  color: AppColors.darkTextSecondary
                      .withValues(alpha: 0.7)))
        else
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _resend,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _resending
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryFixed),
                    )
                  : Text(l10n.verifyResend,
                      style: labelStyle.copyWith(
                          color: AppColors.primaryFixed,
                          fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}
