import 'dart:ui';
import 'package:flutter/material.dart';
import 'supabase/supabase_exports.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'theme/auth_app_text.dart';
import 'verify_code_screen.dart';

/// Dark-pinned palette for the forgot/reset flow (same family as the login /
/// signup screens and VerifyCodeScreen). Values mirror the AppColors dark
/// tokens so a light-mode switch elsewhere never washes these screens out.
class _F {
  static const bg = Color(0xFF121310);
  static const card = Color(0x0AFFFFFF);
  static const cardBorder = Color(0x14FFFFFF);
  static const fieldFill = Color(0xFF2B2C26);
  static const ink = Color(0xFFF1F3E9);
  static const muted = Color(0xFFA9ADA0);
  static const outline = Color(0xFF6E7268);
  static const error = Color(0xFFEE7F60);
  static const success = Color(0xFF4CAF6D);
}

// ────────────────────────────────────────────────────────────────────────────
// Forgot Password Screen
// ────────────────────────────────────────────────────────────────────────────
class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback? onBackToLogin;

  const ForgotPasswordScreen({super.key, this.onBackToLogin});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Send the Supabase recovery email, then hand off to the shared
      // VerifyCodeScreen ([Image 1] layout + OTP logic).
      final email = _emailController.text.trim();
      await AuthService().resetPassword(email);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VerifyCodeScreen(
              email: email,
              flow: VerifyFlow.recovery,
              onVerified: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResetPasswordScreen(
                      email: email,
                      otp: '',
                      onBackToLogin: widget.onBackToLogin,
                    ),
                  ),
                );
              },
              onSignInTap: () {
                widget.onBackToLogin?.call();
                Navigator.of(context).popUntil(
                  (route) =>
                      route.settings.name == 'auth' || route.isFirst,
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: _F.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    return Scaffold(
      backgroundColor: _F.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _F.ink),
          onPressed: () {
            widget.onBackToLogin?.call();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          // Glow orb
          Positioned(
            top: -100,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),

                    // Lock icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _F.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryFixed.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryFixed.withValues(alpha: 0.15),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_reset,
                          size: 36,
                          color: AppColors.primaryFixed,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(l10n.forgotTitle1,
                        style: AuthAppText.displaySm.copyWith(
                          fontFamily: font,
                          color: _F.ink,
                        )),
                    Text(
                      l10n.forgotTitle2,
                      style: AuthAppText.displaySm.copyWith(
                        fontFamily: font,
                        color: AppColors.primaryFixed,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      l10n.forgotSubtitle,
                      style: AuthAppText.bodyMd.copyWith(
                        fontFamily: font,
                        color: _F.muted,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Glass card for email
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _F.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _F.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.forgotEmailLabel,
                                style: AuthAppText.labelMd.copyWith(
                                  fontFamily: font,
                                  color: _F.muted,
                                  letterSpacing: isArabic ? 0 : 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'user@kineticsystem.com',
                                prefixIcon: Icons.alternate_email,
                                keyboardType: TextInputType.emailAddress,
                                fontFamily: font,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return l10n.forgotEmailEmpty;
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value!)) {
                                    return l10n.forgotEmailInvalid;
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    ScaleTransition(
                      scale: _buttonAnimation,
                      child: _buildButton(
                        text: l10n.forgotSendButton,
                        isLoading: _isLoading,
                        fontFamily: font,
                        onPressed: _handleSendOTP,
                        onTapDown: (_) => _buttonController.forward(),
                        onTapUp: (_) => _buttonController.reverse(),
                        onTapCancel: () => _buttonController.reverse(),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Back to login
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          widget.onBackToLogin?.call();
                          Navigator.of(context).pop();
                        },
                        child: RichText(
                          text: TextSpan(
                            style: AuthAppText.labelMd.copyWith(
                              fontFamily: font,
                              color: _F.muted,
                            ),
                            children: [
                              TextSpan(text: '${l10n.verifyRemember}  '),
                              TextSpan(
                                text: l10n.verifySignIn,
                                style: AuthAppText.labelMd.copyWith(
                                  fontFamily: font,
                                  color: AppColors.primaryFixed,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Reset Password Screen
// ────────────────────────────────────────────────────────────────────────────
class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  final VoidCallback? onBackToLogin;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
    this.onBackToLogin,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      // Recovery-session guard: updateUser only works while the session that
      // verifyOTP(recovery) created is still alive. If it expired (code
      // verified too long ago, signed out elsewhere, ...), say so plainly and
      // send the user back for a fresh code instead of surfacing the raw
      // "Auth session missing!" exception.
      if (SupabaseConfig.client.auth.currentUser == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.resetSessionExpired,
              ),
              backgroundColor: _F.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          // Stack here is always [..., ForgotPasswordScreen,
          // VerifyCodeScreen, this] (see ForgotPasswordScreen._handleSendOTP),
          // so two pops land back on the forgot-password screen.
          Navigator.of(context)
            ..pop()
            ..pop();
        }
        return;
      }
      try {
        // Update password via Supabase
        await SupabaseConfig.client.auth.updateUser(
          UserAttributes(password: _passwordController.text),
        );
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.resetSuccess),
              backgroundColor: _F.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          widget.onBackToLogin?.call();
          Navigator.of(context).popUntil(
            (route) => route.settings.name == 'auth' || route.isFirst,
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: _F.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = AppText.fontFamily(isArabic: isArabic);
    return Scaffold(
      backgroundColor: _F.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _F.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 2),

                    // Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _F.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primaryFixed.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryFixed.withValues(alpha: 0.15),
                              blurRadius: 30,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.lock_reset,
                          size: 36,
                          color: AppColors.primaryFixed,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(l10n.resetTitle1,
                        style: AuthAppText.displaySm.copyWith(
                          fontFamily: font,
                          color: _F.ink,
                        )),
                    Text(
                      l10n.resetTitle2,
                      style: AuthAppText.displaySm.copyWith(
                        fontFamily: font,
                        color: AppColors.primaryFixed,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      l10n.resetSubtitle,
                      style: AuthAppText.bodyMd.copyWith(
                        fontFamily: font,
                        color: _F.muted,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Glass card for passwords
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _F.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _F.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.resetNewKey,
                                style: AuthAppText.labelMd.copyWith(
                                  fontFamily: font,
                                  color: _F.muted,
                                  letterSpacing: isArabic ? 0 : 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _passwordController,
                                hintText: '••••••••••••',
                                prefixIcon: Icons.key,
                                obscureText: !_isPasswordVisible,
                                fontFamily: font,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: _F.outline,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return l10n.resetPassEmpty;
                                  }
                                  if ((value?.length ?? 0) < 8) {
                                    return l10n.resetPassShort;
                                  }
                                  if (!RegExp(
                                    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
                                  ).hasMatch(value!)) {
                                    return l10n.resetPassWeak;
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              Text(
                                l10n.resetConfirmKey,
                                style: AuthAppText.labelMd.copyWith(
                                  fontFamily: font,
                                  color: _F.muted,
                                  letterSpacing: isArabic ? 0 : 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                hintText: '••••••••••••',
                                prefixIcon: Icons.key,
                                obscureText: !_isConfirmPasswordVisible,
                                fontFamily: font,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: _F.outline,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return l10n.resetPassConfirmEmpty;
                                  }
                                  if (value != _passwordController.text) {
                                    return l10n.resetPassMismatch;
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    ScaleTransition(
                      scale: _buttonAnimation,
                      child: _buildButton(
                        text: l10n.resetButton,
                        isLoading: _isLoading,
                        fontFamily: font,
                        onPressed: _handleResetPassword,
                        onTapDown: (_) => _buttonController.forward(),
                        onTapUp: (_) => _buttonController.reverse(),
                        onTapCancel: () => _buttonController.reverse(),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Back to login
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          widget.onBackToLogin?.call();
                          // Land on the login screen, not the onboarding
                          // carousel underneath it.
                          Navigator.of(context).popUntil(
                            (route) =>
                                route.settings.name == 'auth' ||
                                route.isFirst,
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: AuthAppText.labelMd.copyWith(
                              fontFamily: font,
                              color: _F.muted,
                            ),
                            children: [
                              TextSpan(text: '${l10n.verifyRemember}  '),
                              TextSpan(
                                text: l10n.verifySignIn,
                                style: AuthAppText.labelMd.copyWith(
                                  fontFamily: font,
                                  color: AppColors.primaryFixed,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared Widgets — Kinetic Obsidian Style
// ────────────────────────────────────────────────────────────────────────────

Widget _buildTextField({
  required TextEditingController controller,
  required String hintText,
  required IconData prefixIcon,
  Widget? suffixIcon,
  bool obscureText = false,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  String? fontFamily,
}) {
  final font = fontFamily ?? 'Inter';
  return TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    validator: validator,
    style: TextStyle(
      color: _F.ink,
      fontFamily: font,
      fontSize: 14,
      letterSpacing: 1.0,
    ),
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: _F.outline.withValues(alpha: 0.5),
        fontFamily: font,
        fontSize: 11,
        letterSpacing: 2.0,
      ),
      prefixIcon: Icon(prefixIcon, color: _F.outline, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _F.fieldFill,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: _F.outline, width: 0.5),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: _F.outline.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryFixed, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _F.error, width: 2),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _F.error, width: 2),
      ),
      errorStyle: TextStyle(
        color: _F.error,
        fontFamily: font,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}

Widget _buildButton({
  required String text,
  required bool isLoading,
  required VoidCallback onPressed,
  void Function(TapDownDetails)? onTapDown,
  void Function(TapUpDetails)? onTapUp,
  VoidCallback? onTapCancel,
  String? fontFamily,
}) {
  return GestureDetector(
    onTapDown: onTapDown,
    onTapUp: onTapUp,
    onTapCancel: onTapCancel,
    child: Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.primaryActionGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryFixed.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.onPrimary,
                          ),
                        ),
                      )
                    : Text(
                        text,
                        style: AuthAppText.buttonPrimary.copyWith(
                          fontFamily: fontFamily,
                        ),
                      ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child:  Icon(
                    Icons.bolt,
                    color: AppColors.primaryFixed,
                    size: 18,
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
