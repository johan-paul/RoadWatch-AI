import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/officer_models.dart';
import '../providers/officer_provider.dart';

class OfficerProfileScreen extends ConsumerWidget {
  const OfficerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    // During logout the user is null for one frame before redirect — don't crash.
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final statsAsync = ref.watch(officerStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _OfficerProfileHeader(user: user),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                children: [
                  // Performance stats
                  statsAsync.when(
                    loading: () => _StatsLoading(),
                    error:   (_, __) => const SizedBox.shrink(),
                    data:    (stats) => _PerformanceCard(stats: stats),
                  ),
                  const SizedBox(height: 14),

                  // Avg resolution
                  statsAsync.maybeWhen(
                    data:   (stats) => _AvgResolutionCard(days: stats.avgResolutionDays),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),

                  // Tips
                  _TipsCard(),
                  const SizedBox(height: 28),

                  // Logout
                  CustomButton(
                    label: 'Logout',
                    variant: ButtonVariant.danger,
                    icon: Icons.logout_rounded,
                    onPressed: () => _confirmLogout(context, ref),
                  ),

                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Await the dialog so logout() only runs once the dialog is fully dismissed
    // and the Navigator is idle — avoids the '_debugLocked' collision crash.
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _OfficerProfileHeader extends StatelessWidget {
  const _OfficerProfileHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name    = user.name as String;
    final phone   = user.phone as String;
    final initial = name[0].toUpperCase();
    final avatar  = user.avatarUrl as String?;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.officerHeaderGradient,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 3),
                    ),
                    child: avatar != null
                        ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.officer,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              // Officer chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Field Officer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
}

// ── Performance Card ──────────────────────────────────────────────────────────

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.stats});
  final OfficerStats stats;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Overview',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat('${stats.totalAssigned}',     'Total',       AppColors.primary),
                _divider(),
                _Stat('${stats.inProgress}',         'In Progress', AppColors.warning),
                _divider(),
                _Stat('${stats.resolvedThisMonth}',  'Resolved',    AppColors.success),
                _divider(),
                _Stat('${stats.pendingHighPriority}', 'High Risk',  AppColors.danger),
              ],
            ),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1, height: 40, color: AppColors.divider,
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Avg Resolution Card ───────────────────────────────────────────────────────

class _AvgResolutionCard extends StatelessWidget {
  const _AvgResolutionCard({required this.days});
  final double days;

  Color get _color {
    if (days <= 2) return AppColors.success;
    if (days <= 5) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (days <= 2) return 'Excellent response time! 🏆';
    if (days <= 5) return 'Good response time 👍';
    return 'Needs improvement';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_color.withOpacity(0.12), _color.withOpacity(0.04)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avg. Resolution Time',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${days.toStringAsFixed(1)} days',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _color),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _label,
                      style: TextStyle(
                          fontSize: 11,
                          color: _color,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_rounded, color: _color, size: 28),
            ),
          ],
        ),
      );
}

// ── Tips Card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  static const _tips = [
    '📸 Upload clear before & after photos for every repair',
    '⏱️ Start repairs promptly to improve resolution time',
    '🔴 Prioritise high-severity complaints first',
    '📝 Add detailed resolution notes for audit purposes',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.officer.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.officer.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates_rounded,
                    color: AppColors.officer, size: 18),
                SizedBox(width: 8),
                Text(
                  'Best Practices',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.officer,
                      fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tip,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _StatsLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
