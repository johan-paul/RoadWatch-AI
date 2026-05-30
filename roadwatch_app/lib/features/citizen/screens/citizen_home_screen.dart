import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/complaint_card.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/citizen_provider.dart';

class CitizenHomeScreen extends ConsumerWidget {
  const CitizenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final complaints = ref.watch(citizenComplaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _GradientHeader(user: user),
          ),

          // ── Stats row ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _StatsRow(complaints: complaints),
            ),
          ),

          // ── Quick actions ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _QuickActions(),
            ),
          ),

          // ── Section header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Reports',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (complaints.complaints.isNotEmpty)
                    GestureDetector(
                      onTap: () => context.go('/citizen/complaints'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            color: AppColors.primary,
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

          // ── Complaint list ────────────────────────────────────────────────
          if (complaints.isLoading && complaints.complaints.isEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const LoadingCard(),
                childCount: 3,
              ),
            )
          else if (complaints.complaints.isEmpty)
            SliverToBoxAdapter(child: _EmptyState())
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => ComplaintCard(
                  complaint: complaints.complaints[i],
                  onTap: () => context.push(
                    '/citizen/complaints/${complaints.complaints[i].id}',
                  ),
                ),
                childCount: complaints.complaints.take(5).length,
              ),
            ),

          // ── Bottom padding for floating nav ───────────────────────────────
          const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
        ],
      ),
    );
  }
}

// ── Gradient Header ───────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final firstName = (user.name as String).split(' ').first;
    final initial   = (user.name as String)[0].toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.citizenHeaderGradient,
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
                  // Greeting + title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $firstName! 👋',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Report Road Hazards',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Help make your city safer 🛣️',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
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
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 2),
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

              const SizedBox(height: 16),

              // Trust score badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      'Trust Score: ${user.trustScore}',
                      style: const TextStyle(
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

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.complaints});
  final ComplaintsState complaints;

  @override
  Widget build(BuildContext context) {
    final all      = complaints.complaints;
    final pending  = all.where((c) => c.isPending).length;
    final resolved = all.where((c) => c.isResolved).length;

    return Row(
      children: [
        _StatCard(label: 'Total',    value: '${all.length}', color: AppColors.primary),
        const SizedBox(width: 10),
        _StatCard(label: 'Pending',  value: '$pending',      color: AppColors.warning),
        const SizedBox(width: 10),
        _StatCard(label: 'Resolved', value: '$resolved',     color: AppColors.success),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.14), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
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
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionCard(
              gradient: AppColors.reportGradient,
              shadowColor: AppColors.citizen,
              icon: Icons.camera_alt_rounded,
              label: 'Report\nHazard',
              onTap: () => context.go('/citizen/report'),
            ),
            const SizedBox(width: 10),
            _ActionCard(
              gradient: AppColors.mapGradient,
              shadowColor: AppColors.info,
              icon: Icons.map_rounded,
              label: 'Hazard\nMap',
              onTap: () => context.go('/citizen/map'),
            ),
            const SizedBox(width: 10),
            _ActionCard(
              gradient: AppColors.successGradient,
              shadowColor: AppColors.success,
              icon: Icons.receipt_long_rounded,
              label: 'My\nReports',
              onTap: () => context.go('/citizen/complaints'),
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
                  color: shadowColor.withOpacity(0.3),
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
              color: AppColors.citizen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.report_problem_outlined,
                size: 36, color: AppColors.citizen),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reports yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Spotted a road hazard?\nReport it and help your community!',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.go('/citizen/report'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.reportGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.citizen.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Text(
                'Report First Hazard',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
