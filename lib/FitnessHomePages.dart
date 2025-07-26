import 'package:coregym2/profile.dart';
import 'package:coregym2/progrems.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitness App',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
      home: const FitnessHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// **FitnessHomePage - Main Fitness Home Page**
///
/// This is the main interface of the app. It's a `StatefulWidget` because it needs to manage
/// the selection state in the bottom navigation bar and control animations.
class FitnessHomePage extends StatefulWidget {
  const FitnessHomePage({super.key});

  @override
  State<FitnessHomePage> createState() => _FitnessHomePageState();
}

class _FitnessHomePageState extends State<FitnessHomePage>
    with TickerProviderStateMixin {
  // Animation controllers for managing entrance effects.
  late AnimationController _fadeController; // For controlling fade effect
  late AnimationController _slideController; // For controlling slide effect

  // Animations to provide smooth entrance effects.
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Variable to track the currently selected item in the bottom navigation bar.
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // --- Animation Initialization ---
    // Initialize controllers and set animation duration.
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Define animation type (0 to 1 for opacity, bottom to top for position).
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animation when page loads.
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    // --- Dispose Controllers ---
    // It's essential to dispose controllers when closing the page to free resources and prevent memory leaks.
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// **_navigateToMuscleTraining - Navigation function for muscle training pages**
  ///
  /// This function is responsible for navigating to the specified muscle training page.
  void _navigateToMuscleTraining(String muscleGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MuscleTrainingPage(muscleGroup: muscleGroup),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Build Main Interface ---
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Main background color
      body: SafeArea(
        // Ensures content doesn't overlap with system areas (like status bar).
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              // Allows scrolling if content is longer than screen.
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(), // Build header section
                  const SizedBox(height: 32),
                  _buildStatsOverview(), // Build stats card
                  const SizedBox(height: 32),
                  _buildCaloriesCard(), // Build calories card
                  const SizedBox(height: 32),
                  _buildFeaturedPlans(), // Build featured plans section
                  const SizedBox(height: 32),
                  _buildWorkoutPrograms(), // Build workout programs section
                  const SizedBox(
                    height: 120,
                  ), // Extra space for floating bottom bar
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar:
          _buildBottomNavigation(), // Build bottom navigation bar
    );
  }

  /// **_buildHeader - Build Header Section**
  ///
  /// This section displays welcome message, date, and notification icon.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Friday, May 20',
                style: TextStyle(
                  color: Color(0xFFA0A0A0),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Good Morning',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('🔥', style: TextStyle(fontSize: 28)),
                ],
              ),
            ],
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF424242), const Color(0xFF212121)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  /// **_buildStatsOverview - Build Stats Overview Card**
  ///
  /// This card displays a summary of key statistics like calories burned,
  /// step count, and active time.
  Widget _buildStatsOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C5CE7).withOpacity(0.8),
            const Color(0xFFA29BFE).withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatItem(
              '2,847',
              'Calories',
              Icons.local_fire_department,
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withOpacity(0.2)),
          Expanded(
            child: _buildStatItem(
              '12.5k',
              'Steps Today',
              Icons.directions_walk,
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white.withOpacity(0.2)),
          Expanded(child: _buildStatItem('45m', 'Active Time', Icons.timer)),
        ],
      ),
    );
  }

  /// **_buildStatItem - Build Single Stat Item**
  ///
  /// Helper widget to create an individual stat item containing icon, value, and label.
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// **_buildCaloriesCard - Build Weekly Activity Card (Calories)**
  ///
  /// This card contains a bar chart showing weekly activity.
  Widget _buildCaloriesCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF424242), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4AA).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Weekly Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4AA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '+12%',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(height: 220, child: _buildCaloriesChart()),
        ],
      ),
    );
  }

  /// **_buildCaloriesChart - Build Calories Chart**
  ///
  /// Uses `fl_chart` library to create an interactive bar chart.
  Widget _buildCaloriesChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            // tooltipBgColor: Colors.black87,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()}%',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[value.toInt()],
                      style: const TextStyle(
                        color: Color(0xFFA0A0A0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _generateBarGroups(),
        backgroundColor: Colors.transparent,
      ),
    );
  }

  /// **_generateBarGroups - Generate Chart Data**
  ///
  /// Helper function to create dummy data for the weekly chart.
  List<BarChartGroupData> _generateBarGroups() {
    final List<double> weekData = [30, 45, 35, 50, 40, 60, 55];
    final List<double> goalData = [80, 90, 75, 85, 95, 70, 88];

    return List.generate(weekData.length, (index) {
      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: weekData[index],
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 12,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          BarChartRodData(
            toY: goalData[index],
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C5CE7).withOpacity(0.3),
                const Color(0xFFA29BFE).withOpacity(0.3),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 12,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
        ],
      );
    });
  }

  /// **_buildFeaturedPlans - Build Featured Plans Section**
  ///
  /// Displays a horizontal list of featured workout plan cards.
  Widget _buildFeaturedPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Featured Plans',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () => debugPrint('View all plans tapped'),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _buildFeaturedPlanCard(
                'Lower Body Workout',
                '15 exercises',
                'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
                const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                ),
                'legs',
              ),
              const SizedBox(width: 20),
              _buildFeaturedPlanCard(
                'Upper Body Strength',
                '12 exercises',
                'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400',
                const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                ),
                'chest',
              ),
              const SizedBox(width: 20),
              _buildFeaturedPlanCard(
                'Core Power',
                '10 exercises',
                'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
                const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                ),
                'core',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// **_buildFeaturedPlanCard - Build Featured Plan Card**
  ///
  /// Helper widget to create a single workout plan card with image and details.
  Widget _buildFeaturedPlanCard(
    String title,
    String subtitle,
    String imageUrl,
    Gradient gradient,
    String muscleGroup,
  ) {
    return GestureDetector(
      onTap: () => _navigateToMuscleTraining(muscleGroup),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                width: 300,
                height: 220,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 220,
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 300,
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Start Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildWorkoutPrograms() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workout Programs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildWorkoutProgramCard(
              'Chest',
              'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400',
              const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
              ),
              Icons.fitness_center,
            ),
            _buildWorkoutProgramCard(
              'Arms',
              'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400',
              const LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
              ),
              Icons.sports_gymnastics,
            ),
            _buildWorkoutProgramCard(
              'Legs',
              'https://images.unsplash.com/photo-1434682772747-f16d3ea162c3?w=400',
              const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
              ),
              Icons.directions_run,
            ),
            _buildWorkoutProgramCard(
              'Core',
              'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
              const LinearGradient(
                colors: [Color(0xFFFD79A8), Color(0xFFE84393)],
              ),
              Icons.self_improvement,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkoutProgramCard(
    String title,
    String imageUrl,
    Gradient gradient,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _navigateToMuscleTraining(title.toLowerCase()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    splashColor: Colors.white.withOpacity(0.1),
                    highlightColor: Colors.white.withOpacity(0.05),
                    onTap: () => _navigateToMuscleTraining(title.toLowerCase()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 88,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 34),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // --- Main Glass Bar ---
          Container(
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(44),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 60,
                  offset: const Offset(0, 20),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1.2, -1.2),
                    end: const Alignment(1.2, 1.2),
                    stops: const [0.0, 0.3, 0.7, 1.0],
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.18),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildUltraGlassNavItem(Icons.analytics_outlined, 0, onTap: () {  }),
                    const SizedBox(width: 75), // Empty space for center button
                    _buildUltraGlassNavItem(
                      Icons.person_rounded,
                      2,
                      onTap: () {
                        setState(() {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // --- Floating Center Button ---
          Positioned(
            top: -32,
            child: Container(
              width: 75,
              height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 50,
                    offset: const Offset(0, 25),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: ClipOval(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.6),
                      radius: 1.8,
                      colors: _selectedNavIndex == 1
                          ? [
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.08),
                              Colors.transparent,
                            ]
                          : [
                              Colors.white.withOpacity(0.25),
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                              Colors.transparent,
                            ],
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(37.5),
                      splashColor: Colors.white.withOpacity(0.15),
                      highlightColor: Colors.white.withOpacity(0.08),
                      onTap: () {
                        setState(() {
                          _selectedNavIndex = 1;
                        });
                      },
                      child: Center(
                        child: Icon(
                          Icons.home_rounded,
                          color: _selectedNavIndex == 1
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltraGlassNavItem(IconData icon, int index, {required Null Function() onTap}) {
    final bool isSelected = _selectedNavIndex == index;

    return Expanded(
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          gradient: isSelected
              ? RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 2.5,
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                    Colors.transparent,
                  ],
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(44),
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            onTap: () {
              setState(() {
                _selectedNavIndex = index;
              });
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
                  border: isSelected
                      ? Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
