import io

p = "lib/forgetpassword.dart"
s = io.open(p, encoding="utf-8").read()

old = """import 'supabase/supabase_exports.dart';
import 'package:supabase_flutter/supabase_flutter.dart';"""
new = """import 'supabase/supabase_exports.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase/auth_service.dart';"""
assert old in s
s = s.replace(old, new)

old = """  Future<void> _handleSendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              email: _emailController.text,
              onBackToLogin: widget.onBackToLogin,
            ),
          ),
        );
      }
    }
  }"""
new = """  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // Actually send the Supabase recovery email — this used to be a
      // 2-second fake delay that sent nothing.
      await AuthService().resetPassword(_emailController.text.trim());
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              email: _emailController.text.trim(),
              onBackToLogin: widget.onBackToLogin,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red[600],
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
  }"""
assert old in s
s = s.replace(old, new)

old = """  Future<void> _handleVerifyOTP() async {
    if (_isOTPComplete()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              email: widget.email,
              otp: _getOTPValue(),
              onBackToLogin: widget.onBackToLogin,
            ),
          ),
        );
      }
    } else {"""
new = """  Future<void> _handleVerifyOTP() async {
    if (_isOTPComplete()) {
      setState(() => _isLoading = true);
      try {
        // Verify the recovery code against Supabase — success also signs the
        // user in, which is what lets the next screen update the password.
        // Any 6 digits used to pass here.
        await SupabaseConfig.client.auth.verifyOTP(
          type: OtpType.recovery,
          email: widget.email.trim(),
          token: _getOTPValue(),
        );
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                email: widget.email,
                otp: _getOTPValue(),
                onBackToLogin: widget.onBackToLogin,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red[600],
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
    } else {"""
assert old in s
s = s.replace(old, new)

old = """  Future<void> _handleResendOTP() async {
    setState(() => _isResending = true);
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isResending = false;
      _resendTimer = 30;
    });
    _startResendTimer();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP sent successfully!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }"""
new = """  Future<void> _handleResendOTP() async {
    setState(() => _isResending = true);
    try {
      await AuthService().resetPassword(widget.email.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP sent successfully!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
          // Supabase rate-limits recovery emails to one per minute.
          _resendTimer = 60;
        });
        _startResendTimer();
      }
    }
  }"""
assert old in s
s = s.replace(old, new)

# Back-nav: OTP screen SIGN IN (22-space indent)
old = """                      onTap: () {
                        widget.onBackToLogin?.call();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },"""
assert s.count(old) == 1, s.count(old)
new = """                      onTap: () {
                        widget.onBackToLogin?.call();
                        // Land on the login screen, not the onboarding
                        // carousel underneath it.
                        Navigator.of(context).popUntil(
                          (route) =>
                              route.settings.name == 'auth' ||
                              route.isFirst,
                        );
                      },"""
s = s.replace(old, new)

# Reset screen SIGN IN (24-space indent)
old = """                        onTap: () {
                          widget.onBackToLogin?.call();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },"""
assert s.count(old) == 1, s.count(old)
new = """                        onTap: () {
                          widget.onBackToLogin?.call();
                          // Land on the login screen, not the onboarding
                          // carousel underneath it.
                          Navigator.of(context).popUntil(
                            (route) =>
                                route.settings.name == 'auth' ||
                                route.isFirst,
                          );
                        },"""
s = s.replace(old, new)

# Reset success navigation — same landing
old = """          widget.onBackToLogin?.call();
          Navigator.of(context).popUntil((route) => route.isFirst);"""
new = """          widget.onBackToLogin?.call();
          Navigator.of(context).popUntil(
            (route) => route.settings.name == 'auth' || route.isFirst,
          );"""
assert old in s
s = s.replace(old, new)

io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("forgetpassword ok")
