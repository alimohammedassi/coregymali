import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';
import '../../../../widgets/pixel_art_icons.dart';
import '../../data/health_service.dart';
import '../../domain/daily_activity.dart';
import '../providers/health_providers.dart';

class TodayActivityCard extends ConsumerStatefulWidget {
  final int stepGoal;
  final VoidCallback? onSynced;

  const TodayActivityCard({super.key, this.stepGoal = 10000, this.onSynced});

  @override
  ConsumerState<TodayActivityCard> createState() => _TodayActivityCardState();
}

class _TodayActivityCardState extends ConsumerState<TodayActivityCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _progressAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final permStatusAsync = ref.watch(healthPermissionStatusProvider);
    final activityAsync = ref.watch(todayActivityProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title, Smartwatch badge, Sync button
          _buildHeader(
            isArabic,
            permStatusAsync.asData?.value,
            activityAsync.isLoading,
            activityAsync.asData?.value,
          ),
          const SizedBox(height: 16),

          // Content: Check activity data first, fallback to permission state
          activityAsync.when(
            data: (activity) {
              final status = permStatusAsync.asData?.value;

              if (status == HealthPermissionStatus.notInstalled) {
                return _buildNotInstalledState(isArabic);
              } else if (status == HealthPermissionStatus.unsupported) {
                return _buildUnsupportedState(isArabic);
              }

              // If we have steps/calories or granted status, show the active metrics!
              if (activity.steps > 0 ||
                  activity.activeCaloriesBurned > 0 ||
                  status == HealthPermissionStatus.granted) {
                return _buildConnectedState(isArabic, activity);
              }

              // Otherwise prompt to connect
              return _buildPermissionRequiredState(isArabic);
            },
            loading: () => _buildLoadingState(isArabic),
            error: (e, _) => _buildErrorState(isArabic, e.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    bool isArabic,
    HealthPermissionStatus? status,
    bool isSyncing,
    DailyActivity? activity,
  ) {
    final hasData =
        (activity != null &&
        (activity.steps > 0 || activity.activeCaloriesBurned > 0));
    final isConnected = status == HealthPermissionStatus.granted || hasData;
    final sourceName = Platform.isIOS ? 'Apple Health' : 'Health Connect';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const PixelArtIcon(type: PixelIconType.sneaker, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic
                    ? 'نشاط اليوم من الساعة ⌚'
                    : 'Today\'s Smartwatch Activity ⌚',
                style: AppText.styledHeadlineSm(
                  isArabic: isArabic,
                  color: AppColors.textPrimary,
                ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.primaryGreen
                          : AppColors.accentCalories,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isConnected
                        ? (isArabic
                              ? 'متصل بـ $sourceName'
                              : 'Linked with $sourceName')
                        : (isArabic ? 'غير متصل' : 'Not Connected'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFamily: AppText.fontFamily(isArabic: isArabic),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (isConnected)
          IconButton(
            icon: isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
            tooltip: isArabic ? 'مزامنة الآن' : 'Sync Now',
            onPressed: isSyncing
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(todayActivityProvider.notifier)
                        .refresh(forceSync: true);
                    widget.onSynced?.call();
                  },
          ),
      ],
    );
  }

  Widget _buildConnectedState(bool isArabic, DailyActivity activity) {
    final stepProgress = (activity.steps / widget.stepGoal).clamp(0.0, 1.0);

    return Column(
      children: [
        // Steps Progress Section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_walk_rounded,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isArabic ? 'الخطوات' : 'Steps',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontFamily: AppText.fontFamily(isArabic: isArabic),
                        ),
                      ),
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: AppText.fontFamily(isArabic: isArabic),
                        color: AppColors.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: '${activity.steps} ',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        TextSpan(
                          text: '/ ${widget.stepGoal}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stepProgress * _progressAnim.value,
                      minHeight: 8,
                      backgroundColor: AppColors.borderSubtle,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Multi-Metric Grid: Calories Burned, Heart Rate, Exercise Minutes
        Row(
          children: [
            // Active Calories
            Expanded(
              child: _buildMetricTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.accentCalories,
                label: isArabic ? 'سعرات نشطة' : 'Active Cals',
                value: '${activity.activeCaloriesBurned.toInt()}',
                unit: isArabic ? 'سعرة' : 'kcal',
                isArabic: isArabic,
              ),
            ),
            const SizedBox(width: 8),

            // Heart Rate (if available, else Exercise time)
            if (activity.heartRateAvg != null)
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE53935),
                  label: isArabic ? 'النبض' : 'Heart Rate',
                  value: '${activity.heartRateAvg!.toInt()}',
                  unit: 'BPM',
                  isArabic: isArabic,
                ),
              ),

            if (activity.heartRateAvg != null) const SizedBox(width: 8),

            // Exercise Minutes
            Expanded(
              child: _buildMetricTile(
                icon: Icons.timer_rounded,
                iconColor: const Color(0xFF3B82F6),
                label: isArabic ? 'تمرين' : 'Exercise',
                value: activity.exerciseMinutes != null
                    ? '${activity.exerciseMinutes!.toInt()}'
                    : '0',
                unit: isArabic ? 'دقيقة' : 'min',
                isArabic: isArabic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required bool isArabic,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isConnecting = false;

  Future<void> _handlePermissionRequest(bool isArabic) async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await ref
          .read(todayActivityProvider.notifier)
          .requestPermissions();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result.isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.isSuccess
                      ? (isArabic
                            ? '✅ تم ربط الساعة ومزامنة النشاط بنجاح!'
                            : '✅ Smartwatch connected and synced successfully!')
                      : (isArabic ? result.message : result.message),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: result.isSuccess
              ? AppColors.primaryGreen
              : (result.status == HealthPermissionStatus.notInstalled
                    ? const Color(0xFFF57F17)
                    : const Color(0xFFDC2626)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      if (result.isSuccess) {
        widget.onSynced?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Widget _buildPermissionRequiredState(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            isArabic
                ? 'اربط ساعتك الذكية (Apple Watch أو Galaxy Watch وغيرها) لقراءة خطواتك وسعراتك التلقائية!'
                : 'Connect your smartwatch (Apple Watch, Galaxy Watch, etc.) to track steps and burned calories automatically!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontFamily: AppText.fontFamily(isArabic: isArabic),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isConnecting
                ? null
                : () => _handlePermissionRequest(isArabic),
            icon: _isConnecting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.watch_rounded, size: 18),
            label: Text(
              _isConnecting
                  ? (isArabic ? 'جاري الاتصال بالساعة...' : 'Connecting...')
                  : (isArabic
                        ? 'ربط الساعة الذكية والموافقة'
                        : 'Connect Smartwatch & Grant Access'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFamily: AppText.fontFamily(isArabic: isArabic),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotInstalledState(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFF57F17),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'تطبيق Health Connect مطلوب على جهازك لمزامنة الساعة'
                      : 'Google Health Connect is required to sync smartwatch data',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE65100),
                    fontFamily: AppText.fontFamily(isArabic: isArabic),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isConnecting
                ? null
                : () => _handlePermissionRequest(isArabic),
            icon: _isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: Text(
              isArabic ? 'تثبيت من Google Play' : 'Install from Google Play',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57F17),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedState(bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          isArabic
              ? 'مزامنة الساعات الذكية متوفرة على أجهزة iOS و Android'
              : 'Smartwatch sync is available on iOS and Android devices',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isArabic, String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isArabic
                  ? 'تعذر جلب بيانات الساعة'
                  : 'Could not fetch watch data',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref
                .read(todayActivityProvider.notifier)
                .refresh(forceSync: true),
            child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
