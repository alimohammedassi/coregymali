import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class AuthService {
  final _client = SupabaseConfig.client;

  // Current user
  User? get currentUser => _client.auth.currentUser;

  // Auth state stream
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail(
      String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<AuthResponse> registerWithEmail(
      String email, String password, String name) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.coregym://login-callback/',
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Error handler — same messages as Firebase version
  String _handleAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    } else if (msg.contains('already registered') ||
        msg.contains('already exists')) {
      return 'An account already exists with this email address.';
    } else if (msg.contains('password')) {
      return 'Password must be at least 6 characters.';
    } else if (msg.contains('email')) {
      return 'Please enter a valid email address.';
    } else if (msg.contains('email not confirmed')) {
      return 'Please confirm your email first.';
    } else if (msg.contains('too many')) {
      return 'Too many failed attempts. Please try again later.';
    }
    return e.message;
  }
}
