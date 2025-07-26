import 'package:flutter/material.dart';
import 'login&SignUp.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen>
    with TickerProviderStateMixin {
  String? selectedGender;
  late AnimationController _animationController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _floatingAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Title Section
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Column(
                          children: [
                            const Text(
                              'Select your',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF6c5ce7), Color(0xFFa29bfe)],
                              ).createShader(bounds),
                              child: const Text(
                                'Gender',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Help us personalize your experience with\ncontent that matters to you',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                height: 1.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 80),

                // Gender Options
                Expanded(
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value * 2),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Column(
                            children: [
                              // Female Option
                              GestureDetector(
                                onTap: () {
                                  setState(() => selectedGender = 'female');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AuthWrapper(),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: selectedGender == 'female'
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFFff6b9d),
                                              Color(0xFFc44569),
                                            ],
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFF2c2c54),
                                              Color(0xFF40407a),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: selectedGender == 'female'
                                            ? const Color(
                                                0xFFff6b9d,
                                              ).withOpacity(0.4)
                                            : Colors.black.withOpacity(0.2),
                                        blurRadius: selectedGender == 'female'
                                            ? 20
                                            : 10,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: selectedGender == 'female'
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.female,
                                          size: 32,
                                          color: selectedGender == 'female'
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Text(
                                        'Female',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: selectedGender == 'female'
                                              ? Colors.white
                                              : Colors.white70,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (selectedGender == 'female')
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // Male Option
                              GestureDetector(
                                onTap: () {
                                  setState(() => selectedGender = 'male');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AuthWrapper(),
                                    ),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: selectedGender == 'male'
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFF3742fa),
                                              Color(0xFF2f3542),
                                            ],
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFF2c2c54),
                                              Color(0xFF40407a),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: selectedGender == 'male'
                                            ? const Color(
                                                0xFF3742fa,
                                              ).withOpacity(0.4)
                                            : Colors.black.withOpacity(0.2),
                                        blurRadius: selectedGender == 'male'
                                            ? 20
                                            : 10,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: selectedGender == 'male'
                                          ? Colors.white.withOpacity(0.3)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.male,
                                          size: 32,
                                          color: selectedGender == 'male'
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Text(
                                        'Male',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: selectedGender == 'male'
                                              ? Colors.white
                                              : Colors.white70,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (selectedGender == 'male')
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // Next Button
                // AnimatedBuilder(
                //   animation: _fadeAnimation,
                //   builder: (context, child) {
                //     return Transform.translate(
                //       offset: Offset(0, _slideAnimation.value * 3),
                //       child: Opacity(
                //         opacity: _fadeAnimation.value,
                //         child: AnimatedContainer(
                //           duration: const Duration(milliseconds: 300),
                //           width: double.infinity,
                //           height: 60,
                //           child: ElevatedButton(
                //             onPressed: selectedGender != null
                //                 ? () {
                //                     // Handle next action
                //                   }
                //                 : null,
                //             style: ElevatedButton.styleFrom(
                //               backgroundColor: selectedGender != null
                //                   ? const Color(0xFF6c5ce7)
                //                   : const Color(0xFF40407a),
                //               foregroundColor: Colors.white,
                //               elevation: selectedGender != null ? 8 : 2,
                //               shadowColor: const Color(
                //                 0xFF6c5ce7,
                //               ).withOpacity(0.4),
                //               shape: RoundedRectangleBorder(
                //                 borderRadius: BorderRadius.circular(30),
                //               ),
                //             ),
                //             child: const Text(
                //               'Continue',
                //               style: TextStyle(
                //                 fontSize: 18,
                //                 fontWeight: FontWeight.w600,
                //                 letterSpacing: 1.0,
                //               ),
                //             ),
                //           ),
                //         ),
                //       ),
                //     );
                //   },
                // ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Usage in your app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gender Selection',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display', // Use system font
      ),
      home: const GenderSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(const MyApp());
}
