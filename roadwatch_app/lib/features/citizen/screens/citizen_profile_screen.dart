import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/citizen_provider.dart';

class CitizenProfileScreen extends ConsumerWidget {
  const CitizenProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    // During logout the user becomes null for one frame before the router
    // redirects to the login screen. Render nothing instead of crashing on `!`.
    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final complaints = ref.watch(citizenComplaintsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gradient header ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ProfileHeader(user: user),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trust score
                  _TrustCard(score: user.trustScore),
                  const SizedBox(height: 14),

                  // Stats
                  _StatsCard(complaints: complaints),
                  const SizedBox(height: 14),

                  // Safety tips
                  _TipsCard(),
                  const SizedBox(height: 28),

                  // Logout
                  CustomButton(
                    label: 'Logout',
                    variant: ButtonVariant.danger,
                    icon: Icons.logout_rounded,
                    onPressed: () => _confirmLogout(context, ref),
                  ),

                  const SizedBox(height: 110), // floating nav space
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    // Await the dialog result. `await` resumes ONLY after the dialog route is
    // fully popped and the Navigator is idle — so calling logout() afterwards
    // can't collide with the dialog dismissal (no more '_debugLocked' crash).
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name    = user.name as String;
    final phone   = user.phone as String;
    final initial = name[0].toUpperCase();
    final avatar  = user.avatarUrl as String?;

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
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 3),
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
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Name
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

              // Citizen chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Citizen',
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

// ── Trust Card ────────────────────────────────────────────────────────────────

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.score});
  final int score;

  Color get _color {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (score >= 80) return 'Excellent Reporter 🌟';
    if (score >= 50) return 'Good Reporter 👍';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_color.withOpacity(0.14), _color.withOpacity(0.04)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trust Score',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score / 100',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
                Container(
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
            const Spacer(),
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 8,
                backgroundColor: _color.withOpacity(0.15),
                color: _color,
                strokeCap: StrokeCap.round,
              ),
            ),
          ],
        ),
      );
}

// ── Stats Card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.complaints});
  final ComplaintsState complaints;

  @override
  Widget build(BuildContext context) {
    final all      = complaints.complaints;
    final resolved = all.where((c) => c.isResolved).length;
    final pending  = all.where((c) => !c.isResolved).length;

    return Container(
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
      child: Row(
        children: [
          _Stat('${all.length}', 'Total',    AppColors.primary),
          _divider(),
          _Stat('$pending',      'Pending',  AppColors.warning),
          _divider(),
          _Stat('$resolved',     'Resolved', AppColors.success),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: AppColors.divider,
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
                  fontSize: 22, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

// ── Tips Card ─────────────────────────────────────────────────────────────────

class _TipsCard extends StatelessWidget {
  static const _tips = [
    '📸 Submit clear, well-lit photos for accurate AI analysis',
    '📍 Always use GPS tagging for precise complaint location',
    '✅ Verify nearby complaints to help your community',
    '⚠️ Only report genuine hazards to maintain your trust score',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Safety Tips',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
