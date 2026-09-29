import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/coach/presentation/providers/coach_setup_provider.dart';
import 'features/coach/presentation/screens/coach_profile_setup_screen.dart';
import 'fitness_home_pages.dart';
import 'forgetpassword.dart';
import 'l10n/app_localizations.dart';
import 'providers/profile_provider.dart';
import 'screens/onboarding_flow.dart';
import 'services/supabase_client.dart';
import 'supabase/supabase_exports.dart';
import 'theme/app_animations.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'verify_code_screen.dart';
import 'widgets/auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CoreGym Auth — Dark redesign (UI/structure refactor only).
//
// Auth LOGIC is untouched: every Supabase call, validator rule, controller,
// navigation target, provider access and callback below is identical to the
// previous revision — only widgets, styling and string sourcing changed.
// ─────────────────────────────────────────────────────────────────────────────

final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLogin = true;

  void _toggle(bool login) {
    if (login == isLogin) return;
    setState(() => isLogin = login);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const AuthHeader(),
                const SizedBox(height: 16),
                Semantics(
                  label: '${l10n.loginTab} ${l10n.signUpTab}',
                  child: AuthSegmentedTabs(
                    isLogin: isLogin,
                    onChanged: _toggle,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                            position: slide, child: child),
                      );
                    },
                    child: isLogin
                        ? LoginScreen(
                            key: const ValueKey('login'),
                            onToggle: () => _toggle(false),
                          )
                        : SignupScreen(
                            key: const ValueKey('signup'),
                            onToggle: () => _toggle(true),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login Screen
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const LoginScreen({super.key, required this.onToggle});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _formValid = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_syncState);
    _passwordController.addListener(_syncState);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _emailError(AppLocalizations l10n, String? v) {
    if (v?.isEmpty ?? true) return l10n.authEmailEmpty;
    if (!_emailRegex.hasMatch(v!)) return l10n.authEmailError;
    return null;
  }

  String? _passwordError(AppLocalizations l10n, String? v) {
    if (v?.isEmpty ?? true) return l10n.authPassEmpty;
    if ((v?.length ?? 0) < 6) return l10n.authPassShort;
    return null;
  }

  /// First validation error, shown under the form (inline Flutter errors are
  /// hidden by design so the 54 px boxes never jump).
  String? _collectError(AppLocalizations l10n) =>
      _emailError(l10n, _emailController.text) ??
      _passwordError(l10n, _passwordController.text);

  void _syncState() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _formError = _collectError(l10n);
      _formValid = _formError == null;
    });
  }

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _formError = _collectError(l10n));
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final profileProv = context.read<ProfileProvider>();
    try {
      final res = await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await profileProv.fetchProfile();
      if (!mounted) return;
      context._showSnack(
        l10n.authWelcomeBack(res.user?.email ?? ''),
        isError: false,
      );
      _navigateAfterAuth(context, profileProv);
    } catch (e) {
      if (mounted) {
        context._showSnack(
          _friendlyError(e,
              isArabic:
                  Localizations.localeOf(context).languageCode == 'ar'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    final profileProv = context.read<ProfileProvider>();
    try {
      final res = await AuthService().signInWithGoogle();
      debugPrint('Google Sign-In successful. User ID: ${res.user?.id}');
      await profileProv.fetchProfile();
      if (!mounted) return;
      context._showSnack(l10n.authGoogleOk, isError: false);
      _navigateAfterAuth(context, profileProv);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        context._showSnack(
          _friendlyError(e,
              isArabic:
                  Localizations.localeOf(context).languageCode == 'ar'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTwoToneTitle(
                      first: l10n.authLoginTitleA,
                      second: l10n.authLoginTitleB,
                      subtitle: l10n.loginDesc,
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: _emailController,
                      label: l10n.operatorId,
                      hint: l10n.emailHint,
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => _emailError(l10n, v),
                      onChanged: (_) => _syncState(),
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _passwordController,
                      label: l10n.encryptedKey,
                      hint: l10n.passwordHint,
                      icon: Icons.lock_outline_rounded,
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) => _passwordError(l10n, v),
                      onChanged: (_) => _syncState(),
                      suffix: _VisibilityToggle(
                        visible: _passwordVisible,
                        onTap: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.push(
                          context,
                          _route(const ForgotPasswordScreen()),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            l10n.forgotPassword,
                            style: TextStyle(
                              fontFamily: AppText.fontFamily(
                                  isArabic: Localizations.localeOf(context)
                                          .languageCode ==
                                      'ar'),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryFixed,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AuthFormError(message: _formError),
                  ],
                ),
              ),
            ),
          ),
        ),
        AuthPrimaryButton(
          label: l10n.initializeSession,
          enabled: _formValid,
          isLoading: _isLoading,
          onTap: _handleLogin,
        ),
        const SizedBox(height: 16),
        AuthDivider(label: l10n.externalAuth),
        const SizedBox(height: 12),
        AuthSocialButtons(
          onGoogle: _handleGoogleSignIn,
          onApple: () =>
              context._showSnack(l10n.authAppleSoon, isError: false),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Signup Screen
// ─────────────────────────────────────────────────────────────────────────────

class SignupScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const SignupScreen({super.key, required this.onToggle});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _passVisible = false;
  bool _confVisible = false;
  bool _agreed = false;
  bool _termsError = false;
  bool _isLoading = false;
  bool _formValid = false;
  String? _formError;
  late AnimationController _termsShake;

  @override
  void initState() {
    super.initState();
    _termsShake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    for (final c in [_nameCtrl, _emailCtrl, _passCtrl, _confCtrl]) {
      c.addListener(_syncState);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    _termsShake.dispose();
    super.dispose();
  }

  String? _nameError(AppLocalizations l10n, String? v) {
    if ((v?.length ?? 0) < 2) return l10n.authNameError;
    return null;
  }

  String? _emailError(AppLocalizations l10n, String? v) {
    if (v?.isEmpty ?? true) return l10n.authEmailEmpty;
    if (!_emailRegex.hasMatch(v!)) return l10n.authEmailError;
    return null;
  }

  String? _passError(AppLocalizations l10n, String? v) {
    if (v?.isEmpty ?? true) return l10n.authPassEmpty;
    if ((v?.length ?? 0) < 6) return l10n.authPassShort;
    return null;
  }

  String? _confirmError(AppLocalizations l10n, String? v) {
    if (v != _passCtrl.text) return l10n.authPassMismatch;
    return null;
  }

  String? _collectError(AppLocalizations l10n) =>
      _nameError(l10n, _nameCtrl.text) ??
      _emailError(l10n, _emailCtrl.text) ??
      _passError(l10n, _passCtrl.text) ??
      _confirmError(l10n, _confCtrl.text);

  void _syncState() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _formError = _collectError(l10n);
      // The CTA stays pressable while the terms box is unchecked so the
      // shake + error feedback can fire; only the fields gate it.
      _formValid = _formError == null;
    });
  }

  void _shakeTerms() {
    setState(() => _termsError = true);
    _termsShake.forward(from: 0);
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _formError = _collectError(l10n));
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      _shakeTerms();
      context._showSnack(l10n.authAgreeTerms, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final email = _emailCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final res = await AuthService().registerWithEmail(
        email,
        _passCtrl.text,
        name,
        // Accounts created in the app are always customers. Coach accounts
        // come from the Core Dashboard website only.
        role: 'client',
      );
      if (res.user != null) {
        if (!mounted) return;
        // Email confirmation ON → no session yet: route through the shared
        // VerifyCodeScreen. verifyOTP(signup) creates the session, then we
        // upsert the profile (RLS needs auth) and route in.
        if (res.session == null) {
          if (mounted) setState(() => _isLoading = false);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerifyCodeScreen(
                email: email,
                flow: VerifyFlow.signup,
                onVerified: () async {
                  try {
                    final userId = AuthService().currentUser?.id;
                    if (userId != null) {
                      try {
                        await supabase.from('profiles').upsert({
                          'id': userId,
                          'name': name,
                          'email': email,
                          'role': 'client',
                        }, onConflict: 'id');
                      } catch (_) {}
                    }
                    if (!mounted) return;
                    context._showSnack(l10n.authWelcomeNew(name),
                        isError: false);
                    final profileProv = context.read<ProfileProvider>();
                    await profileProv.fetchProfile();
                    if (!mounted) return;
                    _navigateAfterAuth(context, profileProv);
                  } catch (e) {
                    if (mounted) {
                      context._showSnack(_friendlyError(e,
                          isArabic: Localizations.localeOf(context)
                                  .languageCode ==
                              'ar'), isError: true);
                    }
                  }
                },
              ),
            ),
          );
          return;
        }
        try {
          await supabase.from('profiles').upsert({
            'id': res.user!.id,
            'name': name,
            'email': email,
            'role': 'client',
          }, onConflict: 'id');
        } catch (_) {}
        context._showSnack(l10n.authWelcomeNew(name), isError: false);
        final profileProv = context.read<ProfileProvider>();
        await profileProv.fetchProfile();
        if (!mounted) return;
        _navigateAfterAuth(context, profileProv);
      }
    } catch (e) {
      if (mounted) {
        context._showSnack(
            _friendlyError(e,
                isArabic:
                    Localizations.localeOf(context).languageCode == 'ar'),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignup() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_agreed) {
      _shakeTerms();
      context._showSnack(l10n.authAgreeTermsShort, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
      final profileProv = context.read<ProfileProvider>();
      await profileProv.fetchProfile();
      if (!mounted) return;
      _navigateAfterAuth(context, profileProv);
    } catch (e) {
      debugPrint('SignupScreen: Google Sign-In Error: $e');
      if (mounted) {
        context._showSnack(
            _friendlyError(e,
                isArabic:
                    Localizations.localeOf(context).languageCode == 'ar'),
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final confirm = _confCtrl.text;
    final confirmMatches = confirm.isNotEmpty && confirm == _passCtrl.text;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTwoToneTitle(
                      first: l10n.authSignupTitleA,
                      second: l10n.authSignupTitleB,
                      subtitle: l10n.signupDesc,
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      controller: _nameCtrl,
                      label: l10n.operativeName,
                      hint: l10n.fullNameHint,
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) => _nameError(l10n, v),
                      onChanged: (_) => _syncState(),
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _emailCtrl,
                      label: l10n.operatorId,
                      hint: l10n.emailHint,
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => _emailError(l10n, v),
                      onChanged: (_) => _syncState(),
                    ),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _passCtrl,
                      label: l10n.encryptedKey,
                      hint: l10n.passwordHint,
                      icon: Icons.lock_outline_rounded,
                      obscureText: !_passVisible,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => _passError(l10n, v),
                      onChanged: (_) => _syncState(),
                      suffix: _VisibilityToggle(
                        visible: _passVisible,
                        onTap: () =>
                            setState(() => _passVisible = !_passVisible),
                      ),
                    ),
                    PasswordStrengthBar(password: _passCtrl.text),
                    const SizedBox(height: 14),
                    AuthTextField(
                      controller: _confCtrl,
                      label: l10n.confirmKey,
                      hint: l10n.passwordHint,
                      icon: Icons.lock_outline_rounded,
                      obscureText: !_confVisible,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => _confirmError(l10n, v),
                      onChanged: (_) => _syncState(),
                      suffix: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (confirmMatches)
                            Semantics(
                              label: l10n.authPassMatch,
                              child: Icon(Icons.check_circle_rounded,
                                  size: 20, color: AppColors.primaryFixed),
                            ),
                          _VisibilityToggle(
                            visible: _confVisible,
                            onTap: () => setState(
                                () => _confVisible = !_confVisible),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AuthFormError(message: _formError),
                    const SizedBox(height: 4),
                    AuthTermsRow(
                      value: _agreed,
                      showError: _termsError,
                      shakeController: _termsShake,
                      onChanged: (v) => setState(() {
                        _agreed = v;
                        if (v) _termsError = false;
                      }),
                      onLegalTap: () => context._showSnack(
                          l10n.authLegalSoon,
                          isError: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AuthPrimaryButton(
          label: l10n.createOperative,
          enabled: _formValid,
          isLoading: _isLoading,
          onTap: () {
            if (!_agreed) _shakeTerms();
            _handleSignup();
          },
        ),
        const SizedBox(height: 16),
        AuthDivider(label: l10n.externalAuth),
        const SizedBox(height: 12),
        AuthSocialButtons(
          onGoogle: _handleGoogleSignup,
          onApple: () =>
              context._showSnack(l10n.authAppleSoon, isError: false),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Show/hide password eye with a 44 px hit target and semantics.
class _VisibilityToggle extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;
  const _VisibilityToggle({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: visible ? l10n.authHidePass : l10n.authShowPass,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsetsDirectional.only(start: 4, end: 8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              visible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: AppColors.darkTextSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers (unchanged behavior)
// ─────────────────────────────────────────────────────────────────────────────

void _navigateAfterAuth(BuildContext context, ProfileProvider profileProv) {
  if (profileProv.needsUserOnboarding) {
    Navigator.pushReplacement(context, _route(const OnboardingFlow()));
  } else if (profileProv.isCoach) {
    if (profileProv.needsCoachSetup) {
      Navigator.pushReplacement(
        context,
        _route(
          ChangeNotifierProvider(
            create: (_) => CoachSetupNotifier(),
            child: const CoachProfileSetupScreen(),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(context, _route(const FitnessHomePage()));
    }
  } else {
    Navigator.pushReplacement(context, _route(const FitnessHomePage()));
  }
}

String _friendlyError(Object e, {bool isArabic = false}) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid login') ||
      msg.contains('invalid credentials') ||
      msg.contains('invalid_grant')) {
    return isArabic
        ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
        : 'Incorrect email or password.';
  }
  if (msg.contains('already registered') || msg.contains('already exists')) {
    return isArabic
        ? 'يوجد حساب مسجل بهذا البريد مسبقاً.'
        : 'An account with this email already exists.';
  }
  if (msg.contains('network') ||
      msg.contains('socketexception') ||
      msg.contains('failed host lookup')) {
    return isArabic
        ? 'خطأ في الاتصال — يرجى التحقق من اتصالك بالإنترنت.'
        : 'Network error — please check your connection.';
  }
  return isArabic
      ? 'حدث خطأ ما. يرجى المحاولة مرة أخرى.'
      : 'Something went wrong. Please try again.';
}

PageRoute _route(Widget page) => PageRouteBuilder(
      pageBuilder: (_, a, __) => page,
      transitionsBuilder: (context, a, __, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        return FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: AppCurves.standard),
          child: child,
        );
      },
      transitionDuration: AppDurations.medium,
    );

extension on BuildContext {
  void _showSnack(String msg, {required bool isError}) {
    final isArabic = Localizations.localeOf(this).languageCode == 'ar';
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: AppText.fontFamily(isArabic: isArabic),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isError ? Colors.white : AppColors.onPrimary,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primaryFixed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
