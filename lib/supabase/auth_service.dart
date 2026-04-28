import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
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
      String email, String password, String name, {String role = 'user'}) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name, 'role': role},
      );
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google (Native Flow)
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // NOTE: Replace with your actual WEB Client ID from Google Cloud Console
      // This is the one you pasted in Supabase Dashboard
      const webClientId = '878197831804-50hoh253cbqhugc283bbuo6siujc9b9s.apps.googleusercontent.com'; 
      
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId,
      );
      
      debugPrint("Starting Google Sign-In...");
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("Google User is NULL (canceled or failed)");
        throw 'Google Sign-In canceled';
      }

      debugPrint("Google User: ${googleUser.email}");
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      debugPrint("ID Token length: ${idToken?.length ?? 0}");
      debugPrint("Access Token length: ${accessToken?.length ?? 0}");

      if (idToken == null) {
        throw 'No ID Token found. Make sure you configured the Web Client ID correctly.';
      }

      debugPrint("Signing into Supabase with ID Token...");
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      debugPrint("Supabase Sign-In Successful: ${response.user?.id}");
      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('network_error')) {
        throw 'Network error. Please check your internet connection.';
      }
      throw e.toString();
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
