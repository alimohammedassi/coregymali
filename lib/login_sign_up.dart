import 'dart:ui';
import 'package:coregym2/fitness_home_pages.dart';
import 'package:flutter/material.dart';
import 'package:coregym2/l10n/app_localizations.dart';
import 'package:coregym2/supabase/supabase_exports.dart';
import 'providers/profile_provider.dart';
import 'services/supabase_client.dart';
import 'screens/onboarding_flow.dart';
import 'forgetpassword.dart';
import 'features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'features/coach/presentation/screens/coach_profile_setup_screen.dart';
import 'features/coach/presentation/providers/coach_dashboard_providers.dart';
import 'package:provider/provider.dart';
import 'features/coach/presentation/providers/coach_setup_provider.dart';
import 'theme/app_colors.dart';
import 'theme/auth_app_text.dart';
import 'widgets/language_toggle.dart';
import 'widgets/premium_glass_bg.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Auth Wrapper
// ─────────────────────────────────────────────────────────────────────────────

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with TickerProviderStateMixin {
  bool isLogin = true;

  late AnimationController _bgController;
  late AnimationController _switchController;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fade = CurvedAnimation(parent: _switchController, curve: Curves.easeInOut);
    _slide = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _switchController,
            curve: Curves.easeOutCubic,
          ),
        );

    _switchController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _switchController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => isLogin = !isLogin);
    _switchController.reset();
    _switchController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGlassmorphismBg(
      child: Stack(
        children: [
          // Corner brackets
          Positioned.directional(textDirection: Directionality.of(context), top: 0, start: 0, child: _CornerBracket(corner: 0)),
          Positioned.directional(textDirection: Directionality.of(context), top: 0, end: 0, child: _CornerBracket(corner: 1)),
          Positioned(
            bottom: 0,
            left: 0,
            child: _CornerBracket(corner: 2),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: _CornerBracket(corner: 3),
          ),

          // Content
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: isLogin
                  ? LoginScreen(onToggle: _toggle)
                  : SignupScreen(onToggle: _toggle),
            ),
          ),
          Positioned(
            top: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LanguageToggle(compact: false),
              ),
            ),
          ),
        ],
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

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;

  late AnimationController _entryController;
  late List<Animation<double>> _itemFades;
  late List<Animation<Offset>> _itemSlides;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _itemFades = List.generate(
      6,
      (i) => CurvedAnimation(
        parent: _entryController,
        curve: Interval(i * 0.08, i * 0.08 + 0.5, curve: Curves.easeOut),
      ),
    );
    _itemSlides = List.generate(
      6,
      (i) =>
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _entryController,
              curve: Interval(
                i * 0.08,
                i * 0.08 + 0.5,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => FadeTransition(
    opacity: _itemFades[i],
    child: SlideTransition(position: _itemSlides[i], child: child),
  );

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final res = await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final profileProv = context.read<ProfileProvider>();
      await profileProv.fetchProfile();
      if (!mounted) return;

      context._showSnack('Welcome back, ${res.user?.email}!', isError: false);

      if (profileProv.needsUserOnboarding) {
        Navigator.pushReplacement(context, _route(const OnboardingFlow()));
      } else if (profileProv.isCoach) {
        if (profileProv.needsCoachSetup) {
          Navigator.pushReplacement(context, _route(ChangeNotifierProvider(create: (_) => CoachSetupNotifier(), child: const CoachProfileSetupScreen())));
        } else {
          Navigator.pushReplacement(context, _route(const FitnessHomePage()));
        }
      } else {
        Navigator.pushReplacement(context, _route(const FitnessHomePage()));
      }
    } catch (e) {
      if (mounted) context._showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _getUserRole() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      return response['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      debugPrint("Starting Google Sign-In process...");
      final res = await AuthService().signInWithGoogle();
      debugPrint("Google Sign-In successful. User ID: ${res.user?.id}");
      
      final profileProv = context.read<ProfileProvider>();
      debugPrint("Fetching profile...");
      await profileProv.fetchProfile();
      debugPrint("Profile fetched. needsRoleSelection: ${profileProv.needsRoleSelection}");

      if (profileProv.needsRoleSelection) {
        if (!mounted) return;
        debugPrint("Showing Role Selection Dialog...");
        final role = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _RoleSelectionDialog(),
        );
        
        if (role != null) {
          debugPrint("Setting role to: $role");
          await profileProv.setRole(role);
        }
      }
      
      if (!mounted) return;

      context._showSnack('Signed in with Google!', isError: false);

      if (profileProv.needsUserOnboarding) {
        debugPrint("Navigating to OnboardingFlow");
        Navigator.pushReplacement(context, _route(const OnboardingFlow()));
      } else if (profileProv.isCoach) {
        if (profileProv.needsCoachSetup) {
          debugPrint("Navigating to CoachProfileSetupScreen");
          Navigator.pushReplacement(context, _route(ChangeNotifierProvider(create: (_) => CoachSetupNotifier(), child: const CoachProfileSetupScreen())));
        } else {
          debugPrint("Navigating to FitnessHomePage (Coach)");
          Navigator.pushReplacement(context, _route(const FitnessHomePage()));
        }
      } else {
        debugPrint("Navigating to FitnessHomePage (Athlete)");
        Navigator.pushReplacement(context, _route(const FitnessHomePage()));
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) context._showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Top bar
                _animated(0, _TopBar()),
                const SizedBox(height: 32),

                // Logo mark
                _animated(1, _LogoMark()),
                const SizedBox(height: 32),

                // Headline
                _animated(
                  2,
                  _Headline(
                    line1: AppLocalizations.of(context)!.loginTitle,
                    line2: AppLocalizations.of(context)!.loginSubtitle,
                    sub: AppLocalizations.of(context)!.loginDesc,
                  ),
                ),
                const SizedBox(height: 28),

                // Form card
                _animated(
                  3,
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(AppLocalizations.of(context)!.operatorId),
                        const SizedBox(height: 8),
                        KineticTextField(
                          controller: _emailController,
                          hint: AppLocalizations.of(context)!.emailHint,
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidator,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _FieldLabel(AppLocalizations.of(context)!.encryptedKey),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                _route(ForgotPasswordScreen()),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.forgotPassword,
                                style: AuthAppText.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        KineticTextField(
                          controller: _passwordController,
                          hint: AppLocalizations.of(context)!.passwordHint,
                          icon: Icons.key_rounded,
                          obscureText: !_passwordVisible,
                          validator: _passwordValidator,
                          suffix: GestureDetector(
                            onTap: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                            child: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.outline,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // CTA button
                _animated(
                  4,
                  KineticButton(
                    label: AppLocalizations.of(context)!.initializeSession,
                    isLoading: _isLoading,
                    onTap: _handleLogin,
                  ),
                ),
                const SizedBox(height: 28),

                // Divider
                _animated(5, _AuthDivider()),
                const SizedBox(height: 20),

                // Social
                _animated(
                  5,
                  Row(
                    children: [
                      Expanded(
                        child: _SocialBtn(
                          icon: Icons.g_mobiledata_rounded,
                          label: AppLocalizations.of(context)!.google,
                          onTap: _handleGoogleSignIn,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SocialBtn(
                          icon: Icons.apple_rounded,
                          label: AppLocalizations.of(context)!.apple,
                          onTap: () => context._showSnack(
                            'Apple sign-in coming soon',
                            isError: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Toggle
                _animated(
                  5,
                  _ToggleLink(
                    prefix: AppLocalizations.of(context)!.newOperative,
                    action: AppLocalizations.of(context)!.enrollNow,
                    onTap: widget.onToggle,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
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
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _passVisible = false;
  bool _confVisible = false;
  bool _agreed = false;
  bool _isLoading = false;
  String _selectedRole = 'client';

  late AnimationController _entryController;
  late List<Animation<double>> _fades;
  late List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fades = List.generate(
      6,
      (i) => CurvedAnimation(
        parent: _entryController,
        curve: Interval(i * 0.07, i * 0.07 + 0.45, curve: Curves.easeOut),
      ),
    );
    _slides = List.generate(
      6,
      (i) =>
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _entryController,
              curve: Interval(
                i * 0.07,
                i * 0.07 + 0.45,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Widget _a(int i, Widget w) => FadeTransition(
    opacity: _fades[i],
    child: SlideTransition(position: _slides[i], child: w),
  );

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      context._showSnack('Please agree to Terms & Conditions', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Register with role stored in auth metadata
      final res = await AuthService().registerWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _nameCtrl.text.trim(),
        role: _selectedRole,
      );

      if (res.user != null) {
        if (!mounted) return;

        // Insert into profiles table with the selected role
        try {
          await supabase.from('profiles').upsert({
            'id': res.user!.id,
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'role': _selectedRole,
          }, onConflict: 'id');
        } catch (_) {}

        context._showSnack('Welcome, ${_nameCtrl.text}!', isError: false);

        final profileProv = context.read<ProfileProvider>();
        await profileProv.fetchProfile();

        if (!mounted) return;

        if (profileProv.needsUserOnboarding) {
          Navigator.pushReplacement(context, _route(const OnboardingFlow()));
        } else if (profileProv.isCoach) {
          if (profileProv.needsCoachSetup) {
            Navigator.pushReplacement(context, _route(ChangeNotifierProvider(create: (_) => CoachSetupNotifier(), child: const CoachProfileSetupScreen())));
          } else {
            Navigator.pushReplacement(context, _route(const FitnessHomePage()));
          }
        } else {
          Navigator.pushReplacement(context, _route(const FitnessHomePage()));
        }
      }
    } catch (e) {
      if (mounted) context._showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _a(0, _TopBar()),
                const SizedBox(height: 32),
                _a(
                  1,
                  _Headline(
                    line1: AppLocalizations.of(context)!.signupTitle,
                    line2: AppLocalizations.of(context)!.signupSubtitle,
                    sub: AppLocalizations.of(context)!.signupDesc,
                  ),
                ),
                const SizedBox(height: 24),

                _a(
                  2,
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(AppLocalizations.of(context)!.operativeName),
                        const SizedBox(height: 8),
                        KineticTextField(
                          controller: _nameCtrl,
                          hint: AppLocalizations.of(context)!.fullNameHint,
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              (v?.length ?? 0) < 2 ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(AppLocalizations.of(context)!.operatorId),
                        const SizedBox(height: 8),
                        KineticTextField(
                          controller: _emailCtrl,
                          hint: 'Email Address',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: _emailValidator,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _a(
                  3,
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(AppLocalizations.of(context)!.encryptedKey),
                        const SizedBox(height: 8),
                        KineticTextField(
                          controller: _passCtrl,
                          hint: 'Password',
                          icon: Icons.key_rounded,
                          obscureText: !_passVisible,
                          validator: _passwordValidator,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _passVisible = !_passVisible),
                            child: Icon(
                              _passVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.outline,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _FieldLabel(AppLocalizations.of(context)!.confirmKey),
                        const SizedBox(height: 8),
                        KineticTextField(
                          controller: _confCtrl,
                          hint: 'Confirm Password',
                          icon: Icons.key_rounded,
                          obscureText: !_confVisible,
                          validator: (v) => v != _passCtrl.text
                              ? 'Passwords do not match'
                              : null,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _confVisible = !_confVisible),
                            child: Icon(
                              _confVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.outline,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Role Selection
                _a(
                  4,
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Choose your path'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = 'client'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'client'
                                        ? AppColors.primaryFixed.withOpacity(0.2)
                                        : AppColors.glass1,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _selectedRole == 'client'
                                          ? AppColors.primaryFixed
                                          : AppColors.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.fitness_center_rounded,
                                        color: _selectedRole == 'client'
                                            ? AppColors.primaryFixed
                                            : AppColors.onSurfaceVariant,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Athlete',
                                        style: AuthAppText.labelMd.copyWith(
                                          color: _selectedRole == 'client'
                                              ? AppColors.primaryFixed
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRole = 'coach'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _selectedRole == 'coach'
                                        ? AppColors.primaryFixed.withOpacity(0.2)
                                        : AppColors.glass1,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _selectedRole == 'coach'
                                          ? AppColors.primaryFixed
                                          : AppColors.outline.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.sports_rounded,
                                        color: _selectedRole == 'coach'
                                            ? AppColors.primaryFixed
                                            : AppColors.onSurfaceVariant,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Coach',
                                        style: AuthAppText.labelMd.copyWith(
                                          color: _selectedRole == 'coach'
                                              ? AppColors.primaryFixed
                                              : AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Terms
                _a(
                  4,
                  _TermsRow(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                  ),
                ),
                const SizedBox(height: 24),

                _a(
                  4,
                  KineticButton(
                    label: AppLocalizations.of(context)!.createOperative,
                    isLoading: _isLoading,
                    onTap: _handleSignup,
                  ),
                ),
                const SizedBox(height: 28),

                _a(5, _AuthDivider()),
                const SizedBox(height: 20),

                _a(
                  5,
                  Row(
                    children: [
                      Expanded(
                        child: _SocialBtn(
                          icon: Icons.g_mobiledata_rounded,
                          label: AppLocalizations.of(context)!.google,
                          onTap: () async {
                            if (!_agreed) {
                              context._showSnack('Agree to Terms first', isError: true);
                              return;
                            }
                            setState(() => _isLoading = true);
                            try {
                              debugPrint("SignupScreen: Starting Google Sign-In...");
                              await AuthService().signInWithGoogle();
                              
                              final profileProv = context.read<ProfileProvider>();
                              debugPrint("SignupScreen: Fetching profile...");
                              await profileProv.fetchProfile();

                              if (profileProv.needsRoleSelection) {
                                if (!mounted) return;
                                debugPrint("SignupScreen: Showing Role Selection Dialog...");
                                final role = await showDialog<String>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const _RoleSelectionDialog(),
                                );
                                
                                if (role != null) {
                                  debugPrint("SignupScreen: Setting role to $role");
                                  await profileProv.setRole(role);
                                }
                              }

                              if (!mounted) return;

                              if (profileProv.needsUserOnboarding) {
                                Navigator.pushReplacement(context, _route(const OnboardingFlow()));
                              } else if (profileProv.isCoach) {
                                if (profileProv.needsCoachSetup) {
                                  Navigator.pushReplacement(context, _route(ChangeNotifierProvider(create: (_) => CoachSetupNotifier(), child: const CoachProfileSetupScreen())));
                                } else {
                                  Navigator.pushReplacement(context, _route(const FitnessHomePage()));
                                }
                              } else {
                                Navigator.pushReplacement(context, _route(const FitnessHomePage()));
                              }
                            } catch (e) {
                              debugPrint("SignupScreen: Google Sign-In Error: $e");
                              if (mounted)
                                context._showSnack(e.toString(), isError: true);
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SocialBtn(
                          icon: Icons.apple_rounded,
                          label: AppLocalizations.of(context)!.apple,
                          onTap: () => context._showSnack(
                            'Apple sign-up coming soon',
                            isError: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                _a(
                  5,
                  _ToggleLink(
                    prefix: AppLocalizations.of(context)!.alreadyEnrolled,
                    action: AppLocalizations.of(context)!.signIn,
                    onTap: widget.onToggle,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI Components
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Logo pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryFixed.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'COREGYM',
                style: TextStyle(
                  color: AppColors.primaryFixed,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'v2.4 // KINETIC',
          style: AuthAppText.labelSm.copyWith(
            color: AppColors.onSurfaceVariant.withOpacity(0.6),
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryFixed.withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
          // Mid ring
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryFixed.withOpacity(0.25),
                width: 1,
              ),
            ),
          ),
          // Icon box
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.glass1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryFixed.withOpacity(0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryFixed.withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 26,
              color: AppColors.primaryFixed,
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  final String line1, line2, sub;
  const _Headline({
    required this.line1,
    required this.line2,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(line1, style: AuthAppText.displaySm),
        Text(
          line2,
          style: AuthAppText.displaySm.copyWith(color: AppColors.primaryFixed),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 20,
              height: 1.5,
              color: AppColors.primaryFixed.withOpacity(0.5),
            ),
            const SizedBox(width: 8),
            Text(
              sub,
              style: AuthAppText.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glass1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Stack(
            children: [
              // Left accent
              Positioned(
                left: -24,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryFixed,
                        AppColors.primaryFixed.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AuthAppText.labelSm.copyWith(
      color: AppColors.onSurfaceVariant,
      letterSpacing: 2.0,
      fontSize: 10,
    ),
  );
}

/// Improved text field — cleaner underline style matching existing theme
class KineticTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const KineticTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  State<KineticTextField> createState() => _KineticTextFieldState();
}

class _KineticTextFieldState extends State<KineticTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _focusCtrl;
  late Animation<double> _focusAnim;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnim = CurvedAnimation(parent: _focusCtrl, curve: Curves.easeOut);
    _focus.addListener(() {
      if (_focus.hasFocus)
        _focusCtrl.forward();
      else
        _focusCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _focusCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color.lerp(
              AppColors.outline.withOpacity(0.2),
              AppColors.primaryFixed.withOpacity(0.6),
              _focusAnim.value,
            )!,
            width: 1 + _focusAnim.value * 0.5,
          ),
        ),
        child: child,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        validator: widget.validator,
        style: TextStyle(
          color: AppColors.onSurface,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: AppColors.outline.withOpacity(0.4),
            fontSize: 12,
            letterSpacing: 1.5,
          ),
          prefixIcon: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: AppColors.outline.withOpacity(0.7),
                  size: 18,
                )
              : null,
          suffixIcon: widget.suffix != null
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: widget.suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Main CTA button — kinetic pill with animated press
class KineticButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const KineticButton({
    super.key,
    required this.label,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  State<KineticButton> createState() => _KineticButtonState();
}

class _KineticButtonState extends State<KineticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.primaryActionGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFixed.withOpacity(0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 52),
              if (widget.isLoading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Text(widget.label, style: AuthAppText.buttonPrimary),
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsetsDirectional.only(end: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.outline.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            AppLocalizations.of(context)!.externalAuth,
            style: AuthAppText.labelSm.copyWith(
              color: AppColors.outline.withOpacity(0.6),
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.outline.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  State<_SocialBtn> createState() => _SocialBtnState();
}

class _SocialBtnState extends State<_SocialBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.glass1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: AppColors.onSurface, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: AuthAppText.buttonSecondary.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.5,
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

class _TermsRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _TermsRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryFixed,
            checkColor: Colors.white,
            side: BorderSide(color: AppColors.outline.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AuthAppText.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
              children: [
                TextSpan(text: AppLocalizations.of(context)!.agreeTerms),
                TextSpan(
                  text: AppLocalizations.of(context)!.termsConditions,
                  style: AuthAppText.bodySm.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    fontSize: 11,
                  ),
                ),
                TextSpan(text: AppLocalizations.of(context)!.and),
                TextSpan(
                  text: AppLocalizations.of(context)!.privacyPolicy,
                  style: AuthAppText.bodySm.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleLink extends StatelessWidget {
  final String prefix, action;
  final VoidCallback onTap;
  const _ToggleLink({
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: TextSpan(
            style: AuthAppText.labelMd.copyWith(color: AppColors.onSurfaceVariant),
            children: [
              TextSpan(text: prefix),
              TextSpan(
                text: action,
                style: AuthAppText.labelMd.copyWith(
                  color: AppColors.primaryFixed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background decorations
// ─────────────────────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ),
  );
}

class _GridPainterWidget extends StatelessWidget {
  const _GridPainterWidget();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _CornerBracket extends StatelessWidget {
  final int corner; // 0=TL, 1=TR, 2=BL, 3=BR
  const _CornerBracket({required this.corner});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _CornerPainter(corner: corner),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final int corner;
  const _CornerPainter({required this.corner});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryFixed.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const len = 14.0;
    final w = size.width;
    final h = size.height;

    switch (corner) {
      case 0: // TL
        canvas.drawLine(Offset(0, len), const Offset(0, 0), paint);
        canvas.drawLine(const Offset(0, 0), Offset(len, 0), paint);
        break;
      case 1: // TR
        canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
        canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
        break;
      case 2: // BL
        canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
        canvas.drawLine(Offset(0, h), Offset(len, h), paint);
        break;
      case 3: // BR
        canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
        canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String? _emailValidator(String? v) {
  if (v?.isEmpty ?? true) return 'Please enter your email';
  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!))
    return 'Please enter a valid email';
  return null;
}

String? _passwordValidator(String? v) {
  if (v?.isEmpty ?? true) return 'Please enter your password';
  if ((v?.length ?? 0) < 6) return 'Password must be at least 6 characters';
  return null;
}

PageRoute _route(Widget page) => PageRouteBuilder(
  pageBuilder: (_, a, __) => page,
  transitionsBuilder: (_, a, __, child) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 350),
);

extension on BuildContext {
  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _RoleSelectionDialog extends StatelessWidget {
  const _RoleSelectionDialog();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glass2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: AppColors.primaryFixed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'WELCOME TO CORE GYM',
                style: AuthAppText.headlineSm.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your path to get started',
                textAlign: TextAlign.center,
                style: AuthAppText.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              _RoleOption(
                icon: Icons.fitness_center_rounded,
                title: 'ATHLETE',
                subtitle: 'I want to track my workouts',
                onTap: () => Navigator.pop(context, 'client'),
              ),
              const SizedBox(height: 16),
              _RoleOption(
                icon: Icons.sports_rounded,
                title: 'COACH',
                subtitle: 'I want to manage my clients',
                onTap: () => Navigator.pop(context, 'coach'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.glass1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryFixed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryFixed),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AuthAppText.labelLg.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AuthAppText.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.outline,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
