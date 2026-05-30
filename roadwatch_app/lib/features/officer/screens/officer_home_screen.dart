import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/complaint_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/officer_provider.dart';

class OfficerHomeScreen extends ConsumerWidget {
  const OfficerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final statsAsync = ref.watch(officerStatsProvider);
    final complaints = ref.watch(officerComplaintsProvider);
    final recent     = complaints.complaints.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _OfficerHeader(user: user),
          ),

          // ── Stats grid ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: statsAsync.when(
                loading: () => _StatsSkeletons(),
                error:   (_, __) => const SizedBox.shrink(),
                data:    (stats) => _StatsGrid(stats: stats),
              ),
            ),
          ),

          // ── Quick actions ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _QuickActions(),
            ),
          ),

          // ── Recent assignments header ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Assignments',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (recent.isNotEmpty)
                    GestureDetector(
                      onTap: () => context.go('/officer/complaints'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.officer.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            color: AppColors.officer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Complaints ────────────────────────────────────────────────────
          if (complaints.isLoading && recent.isEmpty)
            SliverToBoxAdapter(
              child: const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.officer),
                ),
              ),
            )
          else if (recent.isEmpty)
            SliverToBoxAdapter(child: _EmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => ComplaintCard(
                  complaint: recent[i],
                  onTap: () =>
                      context.push('/officer/complaints/${recent[i].id}'),
                ),
                childCount: recent.length,
              ),
            ),

          // Bottom padding for floating nav
          const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
        ],
      ),
    );
  }
}

// ── Officer Header ────────────────────────────────────────────────────────────

class _OfficerHeader extends StatelessWidget {
  const _OfficerHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final firstName = (user.name as String).split(' ').first;
    final initial   = (user.name as String)[0].toUpperCase();

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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
                          'Welcome back, $firstName! 👮',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Officer Dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage & resolve road hazards 🛠️',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.35), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Officer badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Field Officer · Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final dynamic stats;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          _StatTile(
            label: 'Total Assigned',
            value: '${stats.totalAssigned}',
            icon:  Icons.assignment_rounded,
            color: AppColors.primary,
          ),
          _StatTile(
            label: 'In Progress',
            value: '${stats.inProgress}',
            icon:  Icons.construction_rounded,
            color: AppColors.warning,
          ),
          _StatTile(
            label: 'Resolved',
            value: '${stats.resolvedThisMonth}',
            icon:  Icons.check_circle_rounded,
            color: AppColors.success,
          ),
          _StatTile(
            label: 'High Priority',
            value: '${stats.pendingHighPriority}',
            icon:  Icons.priority_high_rounded,
            color: AppColors.danger,
          ),
        ],
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatsSkeletons extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionCard(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shadowColor: AppColors.primary,
              icon: Icons.assignment_rounded,
              label: 'All\nComplaints',
              onTap: () => context.go('/officer/complaints'),
            ),
            const SizedBox(width: 10),
            _ActionCard(
              gradient: AppColors.mapGradient,
              shadowColor: AppColors.info,
              icon: Icons.map_rounded,
              label: 'Hazard\nMap',
              onTap: () => context.go('/officer/map'),
            ),
            const SizedBox(width: 10),
            _ActionCard(
              gradient: AppColors.officerHeaderGradient,
              shadowColor: AppColors.officer,
              icon: Icons.person_rounded,
              label: 'My\nProfile',
              onTap: () => context.go('/officer/profile'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.gradient,
    required this.shadowColor,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Gradient gradient;
  final Color shadowColor;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.officer.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_turned_in_rounded,
                size: 36, color: AppColors.officer),
          ),
          const SizedBox(height: 16),
          const Text(
            'No assignments yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'New complaints assigned to you\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
