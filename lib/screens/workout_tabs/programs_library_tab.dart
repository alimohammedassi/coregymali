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

class _ProgramsLibraryTabState extends State<ProgramsLibraryTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _programs = [];
  String _levelFilter = 'All';
  String _goalFilter = 'All';

  final List<String> _levels = ['All', 'beginner', 'intermediate', 'advanced'];
  // Ensure goals match what's in the DB exactly, or just use case-insensitive ilike filtering
  final List<String> _goals = ['All', 'strength', 'muscle gain', 'weight loss'];

  @override
  void initState() {
    super.initState();
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('training_programs').select();
      if (_levelFilter != 'All') {
        query = query.eq('level', _levelFilter);
      }
      if (_goalFilter != 'All') {
        query = query.ilike('goal', '%$_goalFilter%');
      }
      
      final data = await query.order('level');
      if (mounted) {
        setState(() {
          _programs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
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
        SnackBar(content: Text('Started ${program['name']}!')),
      );
    } on PostgrestException catch (e) {
      debugPrint('DB Error starting program: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start program: ${e.message}')),
      );
    }
  }

  void _showProgramDetail(Map<String, dynamic> program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(program['name'] ?? '', style: AppText.headlineSm),
              if (program['name_ar'] != null) Text(program['name_ar'], style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 16),
              Row(
                children: [
                   _buildBadge(program['level'] ?? '', AppColors.primaryFixed),
                   const SizedBox(width: 8),
                   _buildBadge(program['goal'] ?? '', Colors.blueAccent),
                ]
              ),
              const SizedBox(height: 16),
              Text('${program['days_per_week']} Days/Week • ${program['duration_weeks']} Weeks', style: AppText.labelSm),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFixed,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _startProgram(program);
                  },
                  child: const Text('Start This Program', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
      child: Text(text.toUpperCase(), style: AppText.labelSm.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterChips(List<String> items, String selected, Function(String) onSelect) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected == item;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.toUpperCase(), style: AppText.labelSm.copyWith(
                color: isSelected ? Colors.black : Colors.white
              )),
              selected: isSelected,
              selectedColor: AppColors.primaryFixed,
              backgroundColor: AppColors.surfaceContainerHigh,
              onSelected: (_) => onSelect(item),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildFilterChips(_levels, _levelFilter, (v) { setState(() => _levelFilter = v); _loadPrograms(); }),
        const SizedBox(height: 8),
        _buildFilterChips(_goals, _goalFilter, (v) { setState(() => _goalFilter = v); _loadPrograms(); }),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryFixed))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 90),
                  itemCount: _programs.length,
                  itemBuilder: (context, index) {
                    final program = _programs[index];
                    return Card(
                      color: AppColors.surfaceContainer,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () => _showProgramDetail(program),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(program['name'] ?? '', style: AppText.titleSm),
                              if (program['name_ar'] != null) Text(program['name_ar'], style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildBadge(program['level'] ?? '', AppColors.primaryFixed),
                                  _buildBadge(program['goal'] ?? '', Colors.blueAccent),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${program['days_per_week']} Days/Week • ${program['duration_weeks']} Weeks', style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
