
import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'dart:io';

// /// **AuthService - Firebase Authentication Service**
// ///
// /// This service handles all Firebase authentication operations
// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Get current user
//   User? get currentUser => _auth.currentUser;

//   // Auth state changes stream
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   // Sign in with email and password
//   Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
//     try {
//       UserCredential result = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return result;
//     } catch (e) {
//       print('Sign in error: $e');
//       return null;
//     }
//   }

//   // Register with email and password
//   Future<UserCredential?> registerWithEmailAndPassword(String email, String password, String name) async {
//     try {
//       UserCredential result = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       // Create user document in Firestore
//       await _firestore.collection('users').doc(result.user!.uid).set({
//         'name': name,
//         'email': email,
//         'createdAt': FieldValue.serverTimestamp(),
//         'profileImageUrl': '',
//         'bio': '',
//         'age': 0,
//         'weight': 0.0,
//         'height': 0.0,
//         'fitnessGoal': '',
//       });

//       return result;
//     } catch (e) {
//       print('Registration error: $e');
//       return null;
//     }
//   }

//   // Sign out
//   Future<void> signOut() async {
//     try {
//       await _auth.signOut();
//     } catch (e) {
//       print('Sign out error: $e');
//     }
//   }

//   // Reset password
//   Future<bool> resetPassword(String email) async {
//     try {
//       await _auth.sendPasswordResetEmail(email: email);
//       return true;
//     } catch (e) {
//       print('Password reset error: $e');
//       return false;
//     }
//   }
// }

// /// **UserProfileService - User Profile Data Service**
// ///
// /// This service handles user profile data operations with Firestore
// class UserProfileService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseStorage _storage = FirebaseStorage.instance;

//   // Get user profile data
//   Future<Map<String, dynamic>?> getUserProfile(String uid) async {
//     try {
//       DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
//       if (doc.exists) {
//         return doc.data() as Map<String, dynamic>;
//       }
//       return null;
//     } catch (e) {
//       print('Get profile error: $e');
//       return null;
//     }
//   }

//   // Update user profile
//   Future<bool> updateUserProfile(String uid, Map<String, dynamic> data) async {
//     try {
//       await _firestore.collection('users').doc(uid).update(data);
//       return true;
//     } catch (e) {
//       print('Update profile error: $e');
//       return false;
//     }
//   }

//   // Upload profile image
//   Future<String?> uploadProfileImage(String uid, File imageFile) async {
//     try {
//       Reference ref = _storage.ref().child('profile_images').child('$uid.jpg');
//       UploadTask uploadTask = ref.putFile(imageFile);
//       TaskSnapshot snapshot = await uploadTask;
//       String downloadUrl = await snapshot.ref.getDownloadURL();

//       // Update user document with new image URL
//       await updateUserProfile(uid, {'profileImageUrl': downloadUrl});

//       return downloadUrl;
//     } catch (e) {
//       print('Upload image error: $e');
//       return null;
//     }
//   }
// }

// /// **AuthWrapper - Authentication State Wrapper**
// ///
// /// This widget determines whether to show login or profile page based on auth state
// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: AuthService().authStateChanges,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             backgroundColor: Color(0xFF0A0A0A),
//             body: Center(
//               child: CircularProgressIndicator(
//                 color: Color(0xFF6C5CE7),
//               ),
//             ),
//           );
//         }

//         if (snapshot.hasData) {
//           return ProfilePage(user: snapshot.data!);
//         } else {
//           return const LoginPage();
//         }
//       },
//     );
//   }
// }

// /// **LoginPage - Login and Registration Page**
// ///
// /// This page handles user authentication (login and registration)
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
//   final AuthService _authService = AuthService();
//   final _formKey = GlobalKey<FormState>();

//   late TabController _tabController;

//   // Controllers for login
//   final TextEditingController _loginEmailController = TextEditingController();
//   final TextEditingController _loginPasswordController = TextEditingController();

//   // Controllers for registration
//   final TextEditingController _registerNameController = TextEditingController();
//   final TextEditingController _registerEmailController = TextEditingController();
//   final TextEditingController _registerPasswordController = TextEditingController();
//   final TextEditingController _confirmPasswordController = TextEditingController();

//   bool _isLoading = false;
//   bool _obscurePassword = true;
//   bool _obscureConfirmPassword = true;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _loginEmailController.dispose();
//     _loginPasswordController.dispose();
//     _registerNameController.dispose();
//     _registerEmailController.dispose();
//     _registerPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _signIn() async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => _isLoading = true);

//       UserCredential? result = await _authService.signInWithEmailAndPassword(
//         _loginEmailController.text.trim(),
//         _loginPasswordController.text.trim(),
//       );

//       setState(() => _isLoading = false);

//       if (result == null) {
//         _showErrorSnackBar('Login failed. Please check your credentials.');
//       }
//     }
//   }

//   Future<void> _register() async {
//     if (_formKey.currentState!.validate()) {
//       if (_registerPasswordController.text != _confirmPasswordController.text) {
//         _showErrorSnackBar('Passwords do not match');
//         return;
//       }

//       setState(() => _isLoading = true);

//       UserCredential? result = await _authService.registerWithEmailAndPassword(
//         _registerEmailController.text.trim(),
//         _registerPasswordController.text.trim(),
//         _registerNameController.text.trim(),
//       );

//       setState(() => _isLoading = false);

//       if (result == null) {
//         _showErrorSnackBar('Registration failed. Please try again.');
//       }
//     }
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0A0A0A),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             children: [
//               const SizedBox(height: 40),
//               // App Logo/Title
//               Container(
//                 width: 100,
//                 height: 100,
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
//                   ),
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(
//                       color: const Color(0xFF6C5CE7).withOpacity(0.3),
//                       blurRadius: 20,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: const Icon(
//                   Icons.fitness_center,
//                   color: Colors.white,
//                   size: 50,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               const Text(
//                 'Fitness App',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 32,
//                   fontWeight: FontWeight.w800,
//                   letterSpacing: -0.5,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Your fitness journey starts here',
//                 style: TextStyle(
//                   color: Colors.grey[400],
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 40),

//               // Tab Bar
//               Container(
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF1A1A1A),
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(color: const Color(0xFF424242), width: 1),
//                 ),
//                 child: TabBar(
//                   controller: _tabController,
//                   indicator: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
//                     ),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   labelColor: Colors.white,
//                   unselectedLabelColor: Colors.grey[400],
//                   labelStyle: const TextStyle(fontWeight: FontWeight.w600),
//                   tabs: const [
//                     Tab(text: 'Login'),
//                     Tab(text: 'Register'),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 32),

//               // Tab Bar View
//               SizedBox(
//                 height: 400,
//                 child: TabBarView(
//                   controller: _tabController,
//                   children: [
//                     _buildLoginForm(),
//                     _buildRegisterForm(),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildLoginForm() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         children: [
//           _buildTextField(
//             controller: _loginEmailController,
//             label: 'Email',
//             icon: Icons.email_outlined,
//             keyboardType: TextInputType.emailAddress,
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter your email';
//               }
//               if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
//                 return 'Please enter a valid email';
//               }
//               return null;
//             },
//           ),
//           const SizedBox(height: 16),
//           _buildTextField(
//             controller: _loginPasswordController,
//             label: 'Password',
//             icon: Icons.lock_outlined,
//             obscureText: _obscurePassword,
//             suffixIcon: IconButton(
//               icon: Icon(
//                 _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
//                 color: Colors.grey[400],
//               ),
//               onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter your password';
//               }
//               return null;
//             },
//           ),
//           const SizedBox(height: 24),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: _isLoading ? null : _signIn,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF6C5CE7),
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 elevation: 4,
//               ),
//               child: _isLoading
//                   ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         color: Colors.white,
//                         strokeWidth: 2,
//                       ),
//                     )
//                   : const Text(
//                       'Login',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           TextButton(
//             onPressed: () => _showForgotPasswordDialog(),
//             child: Text(
//               'Forgot Password?',
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontSize: 14,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRegisterForm() {
//     return Form(
//       key: _formKey,
//       child: Column(
//         children: [
//           _buildTextField(
//             controller: _registerNameController,
//             label: 'Full Name',
//             icon: Icons.person_outlined,
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter your name';
//               }
//               return null;
//             },
//           ),
//           const SizedBox(height: 16),
//           _buildTextField(
//             controller: _registerEmailController,
//             label: 'Email',
//             icon: Icons.email_outlined,
//             keyboardType: TextInputType.emailAddress,
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter your email';
//               }
//               if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
//                 return 'Please enter a valid email';
//               }
//               return null;
//             },
//           ),
//           const SizedBox(height: 16),
//           _buildTextField(
//             controller: _registerPasswordController,
//             label: 'Password',
//             icon: Icons.lock_outlined,
//             obscureText: _obscurePassword,
//             suffixIcon: IconButton(
//               icon: Icon(
//                 _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
//                 color: Colors.grey[400],
//               ),
//               onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter a password';
//               }
//               if (value.length < 6) {
//                 return 'Password must be at least 6 characters';
//               }
//               return null;
//             },
//           ),
//           const SizedBox(height: 16),
//           _buildTextField(
//             controller: _confirmPasswordController,
//             label: 'Confirm Password',
//             icon: Icons.lock_outlined,
//             obscureText: _obscureConfirmPassword,
//             suffixIcon: IconButton(
//               icon: Icon(
//                 _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
//                 color: Colors.grey[400],
//               ),
//               onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please confirm your password';
//               }
//               return null;
//             },
//           ),
//           const SizedBox(height: 24),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: _isLoading ? null : _register,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF6C5CE7),
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 elevation: 4,
//               ),
//               child: _isLoading
//                   ? const SizedBox(
//                       width: 20,
//                       height: 20,
//                       child: CircularProgressIndicator(
//                         color: Colors.white,
//                         strokeWidth: 2,
//                       ),
//                     )
//                   : const Text(
//                       'Register',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     TextInputType? keyboardType,
//     bool obscureText = false,
//     Widget? suffixIcon,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       style: const TextStyle(color: Colors.white),
//       keyboardType: keyboardType,
//       obscureText: obscureText,
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: TextStyle(color: Colors.grey[400]),
//         prefixIcon: Icon(icon, color: Colors.grey[400]),
//         suffixIcon: suffixIcon,
//         filled: true,
//         fillColor: const Color(0xFF1A1A1A),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
//         ),
//       ),
//       validator: validator,
//     );
//   }

//   void _showForgotPasswordDialog() {
//     final TextEditingController emailController = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF1A1A1A),
//         title: const Text(
//           'Reset Password',
//           style: TextStyle(color: Colors.white),
//         ),
//         content: TextField(
//           controller: emailController,
//           style: const TextStyle(color: Colors.white),
//           decoration: InputDecoration(
//             hintText: 'Enter your email',
//             hintStyle: TextStyle(color: Colors.grey[500]),
//             filled: true,
//             fillColor: const Color(0xFF2A2A2A),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(8),
//               borderSide: BorderSide.none,
//             ),
//           ),
//           keyboardType: TextInputType.emailAddress,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'Cancel',
//               style: TextStyle(color: Colors.grey[400]),
//             ),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               // bool success = await _authService.resetPassword(emailController.text.trim());
//               // if (success) {
//               //   Navigator.pop(context);
//               //   ScaffoldMessenger.of(context).showSnackBar(
//               //     const SnackBar(
//               //       content: Text('Password reset link sent to your email!'),
//               //       backgroundColor: Colors.green,
//               //     ),
//               //   );
//               // } else {
//               //   Navigator.pop(context);
//               //   _showErrorSnackBar('Failed to send reset link. Please try again.');
//               // }
//                Navigator.pop(context); // Temporarily close dialog
//                ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Password reset functionality is not enabled in this demo.'),
//                     backgroundColor: Colors.orange,
//                   ),
//                 );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: const Color(0xFF6C5CE7),
//             ),
//             child: const Text(
//               'Reset',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // For demonstration, using static data. In a real app, this would come from a user object.
  final String userName = "John Doe";
  final String userEmail = "john.doe@example.com";
  final String profileImageUrl =
      "https://images.unsplash.com/photo-1535713875002-d1d0cfd492da?q=80&w=1780&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D";

  @override
  Widget build(BuildContext context) {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            _buildProfileImage(),
            const SizedBox(height: 20),
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userEmail,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            _buildProfileInfoCard(),
            const SizedBox(height: 30),
            _buildActionButton(context, 'Edit Profile', Icons.edit, () {
              // Handle edit profile action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit Profile functionality coming soon!'),
                  backgroundColor: Colors.blueAccent,
                ),
              );
            }),
            const SizedBox(height: 16),
            _buildActionButton(context, 'Logout', Icons.logout, () {
              _showLogoutDialog(context);
            }, isDestructive: true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 70,
          backgroundColor: const Color(0xFF2A2A2A),
          backgroundImage: NetworkImage(profileImageUrl),
          onBackgroundImageError: (exception, stacktrace) {
            debugPrint('Error loading image: $exception');
          },
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF6C5CE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
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
          _buildInfoRow(Icons.cake_outlined, 'Age', '30'),
          _buildDivider(),
          _buildInfoRow(Icons.scale_outlined, 'Weight', '75 kg'),
          _buildDivider(),
          _buildInfoRow(Icons.height_outlined, 'Height', '175 cm'),
          _buildDivider(),
          _buildInfoRow(Icons.track_changes_outlined, 'Fitness Goal', 'Muscle Gain'),
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey[700], height: 20);
  }

  Widget _buildActionButton(BuildContext context, String text, IconData icon, VoidCallback onPressed, {bool isDestructive = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red[700] : const Color(0xFF6C5CE7),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement actual logout logic here (e.g., AuthService().signOut();)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out (demonstration only)!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}