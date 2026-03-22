import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:coregym2/supabase/supabase_exports.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileService = ProfileService();
  bool _isLoading = true;

  String _userName = "John Doe";
  String _userEmail = "john.doe@example.com";
  String _avatarUrl =
      "https://images.unsplash.com/photo-1535713875002-d1d0cfd492da?q=80&w=1780&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _profileService.getProfile();
      if (data != null && mounted) {
        setState(() {
          _userName = data['name'] ?? 'User';
          _userEmail = data['email'] ?? '';
          _avatarUrl = data['avatar_url'] ?? _avatarUrl;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryFixed),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        title: Text(
          'PROFILE',
          style: AppText.headlineSm.copyWith(fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.settings_outlined, color: AppColors.outline),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Glow orb
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryFixed.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                _buildProfileImage(),
                const SizedBox(height: 20),
                Text(_userName.toUpperCase(), style: AppText.headlineMd),
                const SizedBox(height: 6),
                Text(
                  _userEmail.toUpperCase(),
                  style: AppText.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 32),
                _buildProfileInfoCard(),
                const SizedBox(height: 24),
                _buildActionButton(context, 'EDIT PROFILE', Icons.edit, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Edit Profile functionality coming soon!'),
                      backgroundColor: Colors.blueAccent,
                    ),
                  );
                }),
                const SizedBox(height: 12),
                _buildActionButton(context, 'SIGN OUT', Icons.logout, () {
                  _showLogoutDialog(context);
                }, isDestructive: true),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryFixed.withValues(alpha: 0.3),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryFixed.withValues(alpha: 0.15),
                blurRadius: 30,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 65,
            backgroundColor: AppColors.surfaceContainerHigh,
            backgroundImage: NetworkImage(_avatarUrl),
            onBackgroundImageError: (exception, stacktrace) {
              debugPrint('Error loading image: $exception');
            },
          ),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryFixed.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt,
              color: AppColors.onPrimary,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.glass1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERATIVE DATA',
                style: AppText.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoRow(Icons.cake_outlined, 'AGE', '30'),
              _buildDivider(),
              _buildInfoRow(Icons.scale_outlined, 'WEIGHT', '75 KG'),
              _buildDivider(),
              _buildInfoRow(Icons.height_outlined, 'HEIGHT', '175 CM'),
              _buildDivider(),
              _buildInfoRow(Icons.track_changes_outlined, 'GOAL', 'MUSCLE GAIN'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glass2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: AppColors.primaryFixed, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: AppText.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppText.titleSm.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppColors.outlineVariant.withValues(alpha: 0.15),
      height: 16,
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDestructive
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.glass1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDestructive
                    ? AppColors.error.withValues(alpha: 0.3)
                    : AppColors.glassBorder,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: isDestructive ? AppColors.error : AppColors.primaryFixed,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: AppText.labelMd.copyWith(
                          color: isDestructive ? AppColors.error : AppColors.onSurface,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Text(
          'SIGN OUT',
          style: AppText.headlineSm.copyWith(fontSize: 20),
        ),
        content: Text(
          'ARE YOU SURE YOU WANT TO SIGN OUT?',
          style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'CANCEL',
              style: AppText.labelMd.copyWith(color: AppColors.outline),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'SIGN OUT',
              style: AppText.labelMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}