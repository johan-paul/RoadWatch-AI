import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/ai_analysis_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/severity_badge.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/complaint_model.dart';
import '../providers/citizen_provider.dart';

class ComplaintDetailScreen extends ConsumerStatefulWidget {
  const ComplaintDetailScreen({super.key, required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  bool _verifying = false;

  Future<void> _verify(String response) async {
    setState(() => _verifying = true);
    try {
      await ref.read(citizenRepositoryProvider).verifyComplaint(
            complaintId: widget.complaintId,
            response: response,
          );
      ref.invalidate(complaintDetailProvider(widget.complaintId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response == 'confirmed' ? 'Confirmed! Thanks for verifying.' : 'Marked as rejected.'),
          backgroundColor: response == 'confirmed' ? AppColors.success : AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(complaintDetailProvider(widget.complaintId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Complaint Details')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (c) => _Body(complaint: c, verifying: _verifying, onVerify: _verify),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.complaint, required this.verifying, required this.onVerify});

  final ComplaintModel complaint;
  final bool verifying;
  final void Function(String) onVerify;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ────────────────────────────────────────────────────────
          CachedNetworkImage(
            imageUrl: complaint.imageUrl,
            width: double.infinity,
            height: 240,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(height: 240, color: AppColors.divider),
            errorWidget: (_, __, ___) => Container(
              height: 240,
              color: AppColors.divider,
              child: const Icon(Icons.broken_image, size: 48, color: AppColors.textHint),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badges ───────────────────────────────────────────────
                Row(
                  children: [
                    SeverityBadge(complaint.severity),
                    const SizedBox(width: 8),
                    StatusBadge(complaint.status),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Type & Date ───────────────────────────────────────────
                Text(
                  AppFormatters.damageLabel(complaint.damageType),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reported ${AppFormatters.timeAgo(complaint.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),

                if (complaint.description != null) ...[
                  const SizedBox(height: 12),
                  Text(complaint.description!, style: const TextStyle(fontSize: 14, height: 1.5)),
                ],

                const SizedBox(height: 20),

                // ── Repair Timeline ───────────────────────────────────────
                _RepairTimeline(complaint: complaint),
                const SizedBox(height: 20),

                // ── Assigned Officer ──────────────────────────────────────
                if (complaint.assignedOfficerName != null) ...[
                  const _InfoDivider('Assigned Officer'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.7)
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              complaint.assignedOfficerName![0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              complaint.assignedOfficerName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const Text(
                              'Field Officer',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── AI Analysis Card ──────────────────────────────────────
                AIAnalysisCard(
                  damageType:      complaint.damageType,
                  severity:        complaint.severity,
                  confidenceScore: complaint.aiConfidenceScore,
                  riskScore:       complaint.aiRiskScore,
                  isDuplicate:     complaint.isDuplicate,
                ),

                // ── Community ─────────────────────────────────────────────
                const _InfoDivider('Community Verification'),
                Row(
                  children: [
                    _VerificationChip(
                      icon: Icons.thumb_up,
                      count: complaint.confirmationCount,
                      color: AppColors.success,
                      label: 'Confirmed',
                    ),
                    const SizedBox(width: 12),
                    _VerificationChip(
                      icon: Icons.thumb_down,
                      count: complaint.rejectionCount,
                      color: AppColors.danger,
                      label: 'Rejected',
                    ),
                  ],
                ),

                // ── Location ──────────────────────────────────────────────
                const SizedBox(height: 20),
                const _InfoDivider('Location'),
                if (complaint.locationAddress != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      complaint.locationAddress!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 180,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(complaint.locationLat, complaint.locationLng),
                        initialZoom: 16,
                        // Let the parent ScrollView own vertical drags; map only
                        // responds to pinch-zoom & double-tap (no drag/rotate fights).
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.roadwatch.app',
                          maxZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(complaint.locationLat, complaint.locationLng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin,
                                  color: AppColors.danger, size: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Resolution notes ──────────────────────────────────────
                if (complaint.resolutionNotes != null) ...[
                  const SizedBox(height: 20),
                  const _InfoDivider('Resolution Notes'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(complaint.resolutionNotes!),
                  ),
                ],

                // ── Verify actions (community) ────────────────────────────
                if (!complaint.isResolved) ...[
                  const SizedBox(height: 24),
                  const Text('Have you seen this hazard?',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Confirm',
                          icon: Icons.thumb_up_outlined,
                          isLoading: verifying,
                          onPressed: () => onVerify('confirmed'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          label: 'Reject',
                          icon: Icons.thumb_down_outlined,
                          isLoading: verifying,
                          variant: ButtonVariant.outline,
                          onPressed: () => onVerify('rejected'),
                        ),
                      ),
                    ],
                  ),
                ],

                // Clear the floating bottom-nav bar (~100px) so content
                // (AI card, verify buttons) isn't hidden behind it.
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 8),
          ],
        ),
      );
}

class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.icon, required this.count, required this.color, required this.label});
  final IconData icon;
  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text('$count $label', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
}

// ── Repair Timeline ────────────────────────────────────────────────────────────

class _RepairTimeline extends StatelessWidget {
  const _RepairTimeline({required this.complaint});
  final ComplaintModel complaint;

  static const _steps = [
    ('pending',     'Submitted',    Icons.upload_rounded),
    ('assigned',    'Assigned',     Icons.person_pin_rounded),
    ('in_progress', 'In Progress',  Icons.construction_rounded),
    ('resolved',    'Resolved',     Icons.check_circle_rounded),
  ];

  int _activeStep() {
    switch (complaint.status) {
      case 'assigned':    return 1;
      case 'in_progress': return 2;
      case 'resolved':    return 3;
      default:            return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show for rejected/duplicate
    if (complaint.status == 'rejected' || complaint.status == 'duplicate') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Text(
              complaint.status == 'rejected'
                  ? 'This complaint was rejected by the officer.'
                  : 'This complaint was marked as duplicate.',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final active = _activeStep();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REPAIR PROGRESS',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(_steps.length, (i) {
            final done    = i <= active;
            final current = i == active;
            final color   = done ? AppColors.primary : AppColors.divider;

            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        // Node
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: current ? 38 : 32,
                          height: current ? 38 : 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done
                                ? AppColors.primary
                                : AppColors.surface,
                            border: Border.all(
                              color: color,
                              width: current ? 2.5 : 1.5,
                            ),
                            boxShadow: current
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.25),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            _steps[i].$3,
                            size: current ? 18 : 16,
                            color: done ? Colors.white : AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _steps[i].$2,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: current
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: done
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Connector line (not after last step)
                  if (i < _steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: i < active
                                ? [AppColors.primary, AppColors.primary]
                                : [AppColors.divider, AppColors.divider],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}
