import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_semantic_colors.dart';
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

  // Accent colors per level/goal — single source of truth app-wide
  static const Map<String, Color> _levelColors = AppSemanticColors.level;

  static const Map<String, Color> _goalColors = AppSemanticColors.goal;

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
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${program['name']} activated!',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          backgroundColor: AppColors.surfaceContainerHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderSubtle),
          ),
        ),
      );
    } on PostgrestException catch (e) {
      debugPrint('DB Error starting program: ${e.message}');
    }
  }

  void _showProgramDetail(Map<String, dynamic> program) {
    final levelColor =
        _levelColors[program['level']] ?? AppColors.primary;
    final goalColor =
        _goalColors[program['goal']?.toLowerCase()] ?? AppColors.purpleAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.borderSubtle),
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
                  color: AppColors.outlineVariant,
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
                        style: AppText.headlineLg.copyWith(
                          fontSize: 26,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (program['name_ar'] != null)
                        Text(
                          program['name_ar'],
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Duration badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${program['duration_weeks']}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        'WEEKS',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1),
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
                _statPill(Icons.calendar_today_outlined,
                    '${program['days_per_week']} days/week'),
                _pillBadge(program['level'] ?? '', levelColor),
                _pillBadge(program['goal'] ?? '', goalColor),
              ],
            ),

            const SizedBox(height: 24),

            // Divider
            Container(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 20),

            if (program['description'] != null) ...[
              Text(
                'OVERVIEW',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                program['description'],
                style: TextStyle(
                  color: AppColors.textPrimary,
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
                style: TextStyle(
                  color: AppColors.textPrimary,
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
                  gradient: AppColors.primaryActionGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'START PROGRAM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 13),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _pillBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
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

  Widget _buildSectionLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      );

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
          final accent =
              item == 'All' ? AppColors.primary : (_levelColors[item] ?? _goalColors[item] ?? AppColors.primary);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? accent : AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Text(
                  item.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
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

        _buildSectionLabel('LEVEL'),
        const SizedBox(height: 8),
        _buildFilterRow(_levels, _levelFilter, (v) {
          setState(() => _levelFilter = v);
          _loadPrograms();
        }),

        const SizedBox(height: 12),

        _buildSectionLabel('GOAL'),
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
            style: TextStyle(
              color: AppColors.textMuted,
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
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              : _programs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text('No programs match these filters',
                              style: AppText.bodyMd.copyWith(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('Try a different level or goal',
                              style: AppText.bodySm.copyWith(
                                  color: AppColors.textMuted)),
                        ],
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
                              _levelColors[level] ?? AppColors.primary;
                          final goal = program['goal']?.toLowerCase() ?? '';
                          final goalColor = _goalColors[goal] ??
                              AppColors.purpleAccent;

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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent bar
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.levelColor, widget.goalColor],
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
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
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                                if (p['name_ar'] != null)
                                  Text(
                                    p['name_ar'],
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13),
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
                              color: widget.levelColor.withValues(alpha: 0.10),
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

                      const SizedBox(height: 12),

                      // Badges
                      Row(
                        children: [
                          _inlineBadge(p['level'] ?? '', widget.levelColor),
                          const SizedBox(width: 6),
                          _inlineBadge(p['goal'] ?? '', widget.goalColor),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.bolt_rounded,
                                  color: AppColors.textMuted, size: 14),
                              Text(
                                '${p['days_per_week']}×/wk',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12),
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
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Bottom row
                      Row(
                        children: [
                          const Spacer(),
                          Text(
                            'VIEW PROGRAM',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.primary, size: 11),
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
        color: color.withValues(alpha: 0.10),
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
