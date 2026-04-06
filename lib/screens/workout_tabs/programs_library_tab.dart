import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramsLibraryTab extends StatefulWidget {
  const ProgramsLibraryTab({super.key});

  @override
  State<ProgramsLibraryTab> createState() => _ProgramsLibraryTabState();
}

class _ProgramsLibraryTabState extends State<ProgramsLibraryTab>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _programs = [];
  String _levelFilter = 'All';
  String _goalFilter = 'All';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _levels = ['All', 'beginner', 'intermediate', 'advanced'];
  final List<String> _goals = ['All', 'strength', 'muscle gain', 'weight loss'];

  // Accent colors per level
  static const Map<String, Color> _levelColors = {
    'beginner': Color(0xFF34D399),
    'intermediate': Color(0xFFFBBF24),
    'advanced': Color(0xFFF87171),
    'All': Color(0xFFD4FF57),
  };

  static const Map<String, Color> _goalColors = {
    'strength': Color(0xFFFF6B35),
    'muscle gain': Color(0xFF7C3AED),
    'weight loss': Color(0xFF06B6D4),
    'All': Color(0xFFD4FF57),
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadPrograms();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPrograms() async {
    setState(() => _isLoading = true);
    _fadeController.reset();
    try {
      var query = supabase.from('training_programs').select();
      if (_levelFilter != 'All') query = query.eq('level', _levelFilter);
      if (_goalFilter != 'All') query = query.ilike('goal', '%$_goalFilter%');

      final data = await query.order('level');
      if (mounted) {
        setState(() {
          _programs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } on PostgrestException catch (e) {
      debugPrint('DB Error [${e.code}]: ${e.message}');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading programs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startProgram(Map<String, dynamic> program) async {
    if (currentUserId == null) return;
    try {
      await supabase.from('user_active_program').upsert({
        'user_id': currentUserId,
        'program_id': program['id'],
        'started_at': DateTime.now().toIso8601String(),
        'current_week': 1,
        'current_day': 1,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFFD4FF57), size: 20),
              const SizedBox(width: 12),
              Text('${program['name']} activated!',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('DB Error starting program: ${e.message}');
    }
  }

  void _showProgramDetail(Map<String, dynamic> program) {
    final levelColor =
        _levelColors[program['level']] ?? const Color(0xFFD4FF57);
    final goalColor =
        _goalColors[program['goal']?.toLowerCase()] ?? const Color(0xFF7C3AED);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program['name'] ?? '',
                        style: const TextStyle(
                          fontFamily: 'Bebas Neue',
                          fontSize: 32,
                          color: Colors.white,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                      if (program['name_ar'] != null)
                        Text(
                          program['name_ar'],
                          style: const TextStyle(
                              color: Color(0xFF8E8E93), fontSize: 14),
                        ),
                    ],
                  ),
                ),
                // Duration badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4FF57).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFD4FF57).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${program['duration_weeks']}',
                        style: const TextStyle(
                          color: Color(0xFFD4FF57),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'WEEKS',
                        style:
                            TextStyle(color: Color(0xFFD4FF57), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Stat pills row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statPill(
                    Icons.calendar_today_outlined,
                    '${program['days_per_week']} days/week',
                    const Color(0xFF2C2C2E)),
                _pillBadge(program['level'] ?? '', levelColor),
                _pillBadge(program['goal'] ?? '', goalColor),
              ],
            ),

            const SizedBox(height: 24),

            // Divider
            Container(height: 1, color: Colors.white10),
            const SizedBox(height: 20),

            if (program['description'] != null) ...[
              const Text(
                'OVERVIEW',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                program['description'],
                style: const TextStyle(
                  color: Color(0xFFE5E5EA),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (program['description_ar'] != null) ...[
              Text(
                program['description_ar'],
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFFE5E5EA),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),

            // CTA Button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _startProgram(program);
              },
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4FF57),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'START PROGRAM',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.black, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 13),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _pillBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFilterRow(
      List<String> items, String selected, Function(String) onSelect) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected == item;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: () => onSelect(item),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFD4FF57)
                        : const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFD4FF57)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    item.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Section label
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'LEVEL',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildFilterRow(_levels, _levelFilter, (v) {
          setState(() => _levelFilter = v);
          _loadPrograms();
        }),

        const SizedBox(height: 12),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'GOAL',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildFilterRow(_goals, _goalFilter, (v) {
          setState(() => _goalFilter = v);
          _loadPrograms();
        }),

        const SizedBox(height: 20),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _isLoading ? '' : '${_programs.length} PROGRAMS',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4FF57),
                    strokeWidth: 2,
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: _programs.length,
                    itemBuilder: (context, index) {
                      final program = _programs[index];
                      final level = program['level'] ?? '';
                      final levelColor =
                          _levelColors[level] ?? const Color(0xFFD4FF57);
                      final goal = program['goal']?.toLowerCase() ?? '';
                      final goalColor =
                          _goalColors[goal] ?? const Color(0xFF7C3AED);

                      return _ProgramCard(
                        program: program,
                        levelColor: levelColor,
                        goalColor: goalColor,
                        onTap: () => _showProgramDetail(program),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProgramCard extends StatefulWidget {
  final Map<String, dynamic> program;
  final Color levelColor;
  final Color goalColor;
  final VoidCallback onTap;

  const _ProgramCard({
    required this.program,
    required this.levelColor,
    required this.goalColor,
    required this.onTap,
  });

  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTapDown: (_) => _pressController.reverse(),
        onTapUp: (_) {
          _pressController.forward();
          widget.onTap();
        },
        onTapCancel: () => _pressController.forward(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent bar
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.levelColor, widget.goalColor],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                                if (p['name_ar'] != null)
                                  Text(
                                    p['name_ar'],
                                    style: const TextStyle(
                                        color: Color(0xFF8E8E93), fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Duration chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.levelColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${p['duration_weeks']}W',
                              style: TextStyle(
                                color: widget.levelColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Badges
                      Row(
                        children: [
                          _inlineBadge(p['level'] ?? '', widget.levelColor),
                          const SizedBox(width: 6),
                          _inlineBadge(p['goal'] ?? '', widget.goalColor),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded,
                                  color: Color(0xFF8E8E93), size: 14),
                              Text(
                                '${p['days_per_week']}×/wk',
                                style: const TextStyle(
                                    color: Color(0xFF8E8E93), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (p['description'] != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          p['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF636366),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Bottom row
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            'VIEW PROGRAM',
                            style: TextStyle(
                              color: widget.levelColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: widget.levelColor, size: 11),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inlineBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}