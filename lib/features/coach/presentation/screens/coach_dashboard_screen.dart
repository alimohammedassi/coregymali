import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_colors.dart';
import '../../../../theme/app_text.dart';

import '../providers/coach_dashboard_providers.dart';
import '../providers/coach_dashboard_stat_providers.dart';
import 'client_data_screen.dart';
import 'coach_edit_profile_screen.dart';
import 'coach_media_screen.dart';
import '../providers/coach_media_provider.dart';

class CoachDashboardScreen extends StatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  State<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends State<CoachDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch stats on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoachDashboardStatNotifier>().fetch();
      context.read<ActiveClientsNotifier>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Dashboard', style: AppText.headlineMd),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChangeNotifierProvider(
                  create: (_) => CoachMediaNotifier(),
                  child: const CoachMediaScreen(),
                )),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoachEditProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<CoachDashboardStatNotifier>().fetch(),
            context.read<ActiveClientsNotifier>().fetch(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _StatsRow(),
              const SizedBox(height: 32),
              Text('Subscribers', style: AppText.headlineMd),
              const SizedBox(height: 16),
              const _SubscribersList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final statsNotifier = context.watch<CoachDashboardStatNotifier>();
    final stats = statsNotifier.stats;

    if (statsNotifier.isLoading && stats == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
    }

    if (statsNotifier.error != null && stats == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error),
        ),
        child: Text(
          'Failed to load stats: ${statsNotifier.error}',
          style: AppText.bodyMd.copyWith(color: AppColors.error),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              width: cardWidth,
              title: 'Active\nSubscribers',
              value: stats?.activeSubscribers.toString() ?? '0',
              icon: Icons.people_rounded,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Avg \nRating',
              value: stats?.avgRating.toStringAsFixed(1) ?? '0.0',
              icon: Icons.star_rounded,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Monthly\nRevenue',
              value: '\$${stats?.monthlyRevenue.toStringAsFixed(0) ?? '0'}',
              icon: Icons.attach_money_rounded,
            ),
            _StatCard(
              width: cardWidth,
              title: 'Open\nSlots',
              value: stats?.openSlots.toString() ?? '0',
              icon: Icons.event_seat_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFC9A84C), size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.headlineLg.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SubscribersList extends StatelessWidget {
  const _SubscribersList();

  @override
  Widget build(BuildContext context) {
    final clientsNotifier = context.watch<ActiveClientsNotifier>();
    final clients = clientsNotifier.clients;

    if (clientsNotifier.isLoading && clients == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C)));
    }

    if (clientsNotifier.error != null && clients == null) {
      return Text('Error: ${clientsNotifier.error}', style: AppText.bodyMd.copyWith(color: AppColors.error));
    }

    if (clients == null || clients.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.group_off_rounded, size: 64, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No subscribers yet', style: AppText.headlineMd),
            const SizedBox(height: 8),
            Text(
              'Share your profile to get clients.',
              style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.share_rounded, color: Colors.black),
              label: Text('Share Profile', style: AppText.labelLg.copyWith(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A84C),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final client = clients[index];
        final tier = 'Standard'; // Just a placeholder, assuming Standard
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ClientDataScreen(clientId: client.clientId)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: client.avatarUrl != null ? NetworkImage(client.avatarUrl!) : null,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: client.avatarUrl == null
                      ? const Icon(Icons.person, color: AppColors.onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(client.name, style: AppText.labelLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.5)),
                            ),
                            child: Text(tier, style: AppText.labelSm.copyWith(color: const Color(0xFFC9A84C))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Last active: Today', style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('${client.todayCalories} kcal', style: AppText.bodySm),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Icon(
                                client.todayWorkoutDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                size: 14,
                                color: client.todayWorkoutDone ? Colors.green : AppColors.onSurfaceVariant,
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
