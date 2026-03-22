# CoreGym — Firebase → Supabase Migration Agent

## Supabase Credentials
```
URL:      https://mkrjvrnysuvtokqkyoll.supabase.co
ANON KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcmp2cm55c3V2dG9rcWt5b2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNDExMTgsImV4cCI6MjA4OTcxNzExOH0.Nf1xdRt2W1Ped0gulhdId2iAFC0KEp36-JD_4ey9dzg
```

---

## Your Role
You are a Flutter migration agent. Your job is to migrate CoreGym
from Firebase Auth to Supabase completely.

Rules:
- NEVER break any UI widget or layout
- NEVER change navigation flow or screen order
- NEVER remove exercise data from getMuscleData()
- ONLY replace Firebase auth calls with Supabase equivalents
- Run `flutter analyze` after every file change

---

## Database (already created — do NOT run SQL)
The Supabase project already has these tables:
- profiles
- daily_stats
- weekly_activity
- workout_logs
- user_programs

---

## Step 1 — Update pubspec.yaml

Remove these dependencies:
```yaml
  firebase_core: any
  firebase_auth: any
  google_sign_in: any
```

Add this dependency:
```yaml
  supabase_flutter: ^2.5.0
```

Then run:
```bash
flutter pub get
```

---

## Step 2 — Create lib/supabase/ folder with 5 files

### lib/supabase/supabase_config.dart
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://mkrjvrnysuvtokqkyoll.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1rcmp2cm55c3V2dG9rcWt5b2xsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNDExMTgsImV4cCI6MjA4OTcxNzExOH0.Nf1xdRt2W1Ped0gulhdId2iAFC0KEp36-JD_4ey9dzg';

  static SupabaseClient get client => Supabase.instance.client;
}
```

---

### lib/supabase/auth_service.dart
```dart
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
```

---

### lib/supabase/profile_service.dart
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class ProfileService {
  final _client = SupabaseConfig.client;

  Future<Map<String, dynamic>?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      return await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('profiles').update(data).eq('id', userId);
  }
}
```

---

### lib/supabase/stats_service.dart
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

class StatsService {
  final _client = SupabaseConfig.client;

  Future<Map<String, dynamic>> getTodayStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return _emptyStats();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      return await _client
          .from('daily_stats')
          .select()
          .eq('user_id', userId)
          .eq('date', today)
          .single();
    } catch (_) {
      return _emptyStats();
    }
  }

  Future<void> updateTodayStats({
    int? calories,
    int? steps,
    int? activeMinutes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('daily_stats').upsert({
      'user_id': userId,
      'date': today,
      if (calories != null) 'calories': calories,
      if (steps != null) 'steps': steps,
      if (activeMinutes != null) 'active_minutes': activeMinutes,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,date');
  }

  Future<List<Map<String, dynamic>>> getWeeklyActivity() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return _emptyWeek();
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = monday.toIso8601String().substring(0, 10);
    try {
      final response = await _client
          .from('weekly_activity')
          .select()
          .eq('user_id', userId)
          .eq('week_start', weekStart)
          .order('day_index');
      if ((response as List).isEmpty) return _emptyWeek();
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return _emptyWeek();
    }
  }

  Future<void> logWorkout({
    required String muscleGroup,
    required String exerciseName,
    int? setsDone,
    int? repsDone,
    double? weightKg,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('workout_logs').insert({
      'user_id': userId,
      'muscle_group': muscleGroup,
      'exercise_name': exerciseName,
      if (setsDone != null) 'sets_done': setsDone,
      if (repsDone != null) 'reps_done': repsDone,
      if (weightKg != null) 'weight_kg': weightKg,
    });
  }

  Map<String, dynamic> _emptyStats() =>
      {'calories': 0, 'steps': 0, 'active_minutes': 0};

  List<Map<String, dynamic>> _emptyWeek() =>
      List.generate(7, (i) =>
          {'day_index': i, 'actual_pct': 0, 'goal_pct': 0});
}
```

---

### lib/supabase/supabase_exports.dart
```dart
export 'supabase_config.dart';
export 'auth_service.dart';
export 'profile_service.dart';
export 'stats_service.dart';
```

After creating all 5 files run:
```bash
flutter analyze lib/supabase/
```

---

## Step 3 — Update main.dart

Replace the entire main.dart content with:
```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coregym2/supabase/supabase_config.dart';
import 'splashScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Core Gym',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

Then run:
```bash
flutter analyze lib/main.dart
```

---

## Step 4 — Update Login&SignUp.dart

### What to change:
1. Remove these imports at the top:
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
```

2. Add this import:
```dart
import 'package:coregym2/supabase/supabase_exports.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
```

3. Delete the entire `AuthService` class inside this file
   (the Supabase version is in lib/supabase/auth_service.dart)

4. In `_LoginScreenState` — replace `_handleLogin()`:
```dart
Future<void> _handleLogin() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      final response = await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (response.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome back, ${response.user?.email}!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const FitnessHomePage()),
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
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
```

5. Replace `_handleGoogleSignIn()`:
```dart
Future<void> _handleGoogleSignIn() async {
  setState(() => _isLoading = true);
  try {
    final authService = AuthService();
    await authService.signInWithGoogle();
    // Supabase OAuth redirects automatically
    // Navigation handled by auth state listener
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

6. In `_SignupScreenState` — replace `_handleSignup()`:
```dart
Future<void> _handleSignup() async {
  if (_formKey.currentState!.validate() && _agreeToTerms) {
    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      final response = await authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      if (response.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Welcome, ${_nameController.text}! Account created.'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => const FitnessHomePage()),
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
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  } else if (!_agreeToTerms) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please agree to Terms & Conditions'),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
```

Then run:
```bash
flutter analyze lib/Login&SignUp.dart
```

---

## Step 5 — Update forgetpassword.dart

### What to change:
1. Remove Firebase imports if any exist
2. Add:
```dart
import 'package:coregym2/supabase/supabase_exports.dart';
```

3. `_handleSendOTP()` stays exactly the same (simulation only)

4. `_handleVerifyOTP()` stays exactly the same (simulation only)

5. In `ResetPasswordScreen._handleResetPassword()` — after
   Future.delayed simulation, add actual Supabase call:
```dart
Future<void> _handleResetPassword() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);
    try {
      // Update password via Supabase
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset successfully!'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        widget.onBackToLogin?.call();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
}
```

Then run:
```bash
flutter analyze lib/forgetpassword.dart
```

---

## Step 6 — Update profile.dart

Replace the static `ProfilePage` with a StatefulWidget
that loads real data from Supabase:

```dart
import 'package:flutter/material.dart';
import 'package:coregym2/supabase/supabase_exports.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  static const String _defaultAvatar =
      'https://images.unsplash.com/photo-1535713875002-d1d0cfd492da'
      '?q=80&w=1780&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _profileService.getProfile();
    if (mounted) {
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    }
  }

  String get _userName => _profile?['name'] ?? 'User';
  String get _userEmail =>
      _profile?['email'] ??
      SupabaseConfig.client.auth.currentUser?.email ?? '';
  String get _avatarUrl =>
      _profile?['avatar_url'] ?? _defaultAvatar;

  @override
  Widget build(BuildContext context) {
    // Keep the EXACT same build() structure as before
    // Replace: userName → _userName
    // Replace: userEmail → _userEmail
    // Replace: profileImageUrl → _avatarUrl
    // Add loading indicator when _isLoading == true

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C5CE7),
              ),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildProfileImage(),
                  const SizedBox(height: 20),
                  Text(
                    _userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userEmail,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildProfileInfoCard(),
                  const SizedBox(height: 30),
                  _buildActionButton(
                    context, 'Edit Profile', Icons.edit, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit Profile coming soon!'),
                        backgroundColor: Colors.blueAccent,
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    context, 'Logout', Icons.logout,
                    () => _showLogoutDialog(context),
                    isDestructive: true,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // Keep ALL _buildProfileImage, _buildProfileInfoCard,
  // _buildInfoRow, _buildDivider, _buildActionButton,
  // _showLogoutDialog methods EXACTLY as they were
  // Only change _showLogoutDialog logout action:

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Logout',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 70,
          backgroundColor: const Color(0xFF2A2A2A),
          backgroundImage: NetworkImage(_avatarUrl),
        ),
        Positioned(
          bottom: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF6C5CE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt,
                color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF424242), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.cake_outlined, 'Age',
              _profile?['age']?.toString() ?? '—'),
          _buildDivider(),
          _buildInfoRow(Icons.scale_outlined, 'Weight',
              _profile?['weight_kg'] != null
                  ? '${_profile!['weight_kg']} kg' : '—'),
          _buildDivider(),
          _buildInfoRow(Icons.height_outlined, 'Height',
              _profile?['height_cm'] != null
                  ? '${_profile!['height_cm']} cm' : '—'),
          _buildDivider(),
          _buildInfoRow(Icons.track_changes_outlined,
              'Fitness Goal',
              _profile?['fitness_goal'] ?? '—'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFA29BFE), size: 24),
          const SizedBox(width: 16),
          Text(label,
              style: TextStyle(color: Colors.grey[300], fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(color: Colors.grey[700], height: 20);

  Widget _buildActionButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive
              ? Colors.red[700]
              : const Color(0xFF6C5CE7),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
      ),
    );
  }
}
```

Then run:
```bash
flutter analyze lib/profile.dart
```

---

## Step 7 — Update FitnessHomePages.dart

1. Remove Firebase imports
2. Add:
```dart
import 'package:coregym2/supabase/supabase_exports.dart';
```

3. Add StatsService to the state class and load real data:
```dart
// Add to _FitnessHomePageState fields:
final _statsService = StatsService();
Map<String, dynamic> _todayStats =
    {'calories': 0, 'steps': 0, 'active_minutes': 0};

// Add _loadStats() call in initState() after animations:
_loadStats();

// Add this method:
Future<void> _loadStats() async {
  final stats = await _statsService.getTodayStats();
  if (mounted) setState(() => _todayStats = stats);
}
```

4. In `_buildStatItem` calls inside `_buildStatsOverview()`,
   replace static strings with live data:
```dart
_buildStatItem(
  _todayStats['calories'].toString(),
  'Calories',
  Icons.local_fire_department,
),
// divider
_buildStatItem(
  '${((_todayStats['steps'] as int) / 1000).toStringAsFixed(1)}k',
  'Steps Today',
  Icons.directions_walk,
),
// divider
_buildStatItem(
  '${_todayStats['active_minutes']}m',
  'Active Time',
  Icons.timer,
),
```

5. Keep ALL other methods UNCHANGED:
   - _generateBarGroups() — do not touch
   - _buildFeaturedPlans() — do not touch
   - _buildWorkoutPrograms() — do not touch
   - _buildBottomNavigation() — do not touch
   - _navigateToMuscleTraining() — do not touch

Then run:
```bash
flutter analyze lib/FitnessHomePages.dart
```

---

## Step 8 — Update main.dart in AuthService class

Remove the duplicate `AuthService` class from `main.dart`
(keep only the one in lib/supabase/auth_service.dart)

Remove `CoreGymLoginPage` class from main.dart entirely
(it's replaced by the new auth flow)

Then run:
```bash
flutter analyze lib/main.dart
```

---

## Step 9 — Remove Firebase files

Delete these files if they exist:
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

Remove Firebase config from:
- android/app/build.gradle (remove apply plugin: 'com.google.gms.google-services')
- android/build.gradle (remove classpath firebase)

---

## Step 10 — Final verification

```bash
flutter analyze
flutter build apk --debug
```

If build succeeds — migration is complete.
Report all files modified.

---

## Summary of what changes

| File | Change |
|------|--------|
| pubspec.yaml | Remove Firebase, add supabase_flutter |
| main.dart | Supabase.initialize instead of Firebase |
| lib/supabase/ | 5 new service files |
| Login&SignUp.dart | Replace AuthService calls only |
| forgetpassword.dart | Real password reset via Supabase |
| profile.dart | Load real profile from DB |
| FitnessHomePages.dart | Load real stats from DB |
| progrems.dart | NO CHANGES |
| splashScreen.dart | NO CHANGES |
