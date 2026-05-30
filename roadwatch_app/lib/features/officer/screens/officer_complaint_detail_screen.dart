import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/ai_analysis_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/severity_badge.dart';
import '../../../shared/widgets/status_badge.dart';
import '../providers/officer_provider.dart';

class OfficerComplaintDetailScreen extends ConsumerStatefulWidget {
  const OfficerComplaintDetailScreen({super.key, required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<OfficerComplaintDetailScreen> createState() =>
      _OfficerComplaintDetailScreenState();
}

class _OfficerComplaintDetailScreenState
    extends ConsumerState<OfficerComplaintDetailScreen> {
  bool _actionLoading = false;

  Future<void> _openNavigation(double lat, double lng) async {
    final googleMapsUrl =
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps.')),
      );
    }
  }

  Future<void> _startRepair() async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(officerRepositoryProvider).startRepair(widget.complaintId);
      // Refresh list + stats in the background
      ref.read(officerComplaintsProvider.notifier).refresh();
      ref.invalidate(officerStatsProvider);
      // Force a fresh fetch of THIS complaint and AWAIT it so the button
      // updates immediately (invalidate alone is fire-and-forget here).
      ref.invalidate(officerComplaintDetailProvider(widget.complaintId));
      await ref.read(officerComplaintDetailProvider(widget.complaintId).future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repair started — status set to In Progress.'),
          backgroundColor: AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(officerComplaintDetailProvider(widget.complaintId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Complaint Details')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text(e.toString())),
        data:    (complaint) {
          final isAssigned   = complaint.status == 'assigned';
          final isInProgress = complaint.status == 'in_progress';
          final isResolved   = complaint.isResolved;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ──────────────────────────────────────────────────
                CachedNetworkImage(
                  imageUrl:    complaint.imageUrl,
                  width:       double.infinity,
                  height:      240,
                  fit:         BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(height: 240, color: AppColors.divider),
                  errorWidget: (_, __, ___) => Container(
                    height: 240,
                    color: AppColors.divider,
                    child: const Icon(Icons.broken_image,
                        size: 48, color: AppColors.textHint),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Badges ────────────────────────────────────────────
                      Row(
                        children: [
                          SeverityBadge(complaint.severity),
                          const SizedBox(width: 8),
                          StatusBadge(complaint.status),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Type & Date ───────────────────────────────────────
                      Text(
                        AppFormatters.damageLabel(complaint.damageType),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported ${AppFormatters.timeAgo(complaint.createdAt)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),

                      if (complaint.description != null) ...[
                        const SizedBox(height: 12),
                        Text(complaint.description!,
                            style:
                                const TextStyle(fontSize: 14, height: 1.5)),
                      ],

                      const SizedBox(height: 20),

                      // ── AI Analysis Card ─────────────────────────────────
                      AIAnalysisCard(
                        damageType:      complaint.damageType,
                        severity:        complaint.severity,
                        confidenceScore: complaint.aiConfidenceScore,
                        riskScore:       complaint.aiRiskScore,
                        isDuplicate:     complaint.isDuplicate,
                      ),

                      // ── Community verification ────────────────────────────
                      const _SectionHeader('Community Verification'),
                      Row(
                        children: [
                          _VerChip(
                            icon:  Icons.thumb_up,
                            count: complaint.confirmationCount,
                            color: AppColors.success,
                            label: 'Confirmed',
                          ),
                          const SizedBox(width: 12),
                          _VerChip(
                            icon:  Icons.thumb_down,
                            count: complaint.rejectionCount,
                            color: AppColors.danger,
                            label: 'Rejected',
                          ),
                        ],
                      ),

                      // ── Location ──────────────────────────────────────────
                      const SizedBox(height: 20),
                      const _SectionHeader('Location'),
                      if (complaint.locationAddress != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            complaint.locationAddress!,
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 180,
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(
                                complaint.locationLat,
                                complaint.locationLng,
                              ),
                              initialZoom: 16,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.pinchZoom |
                                    InteractiveFlag.doubleTapZoom,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.roadwatch.app',
                                maxZoom: 19,
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      complaint.locationLat,
                                      complaint.locationLng,
                                    ),
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: AppColors.danger,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Resolution notes ──────────────────────────────────
                      if (complaint.resolutionNotes != null) ...[
                        const SizedBox(height: 20),
                        const _SectionHeader('Resolution Notes'),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(complaint.resolutionNotes!),
                        ),
                      ],

                      // ── Officer actions ───────────────────────────────────
                      const SizedBox(height: 24),
                      // Navigate button — always visible
                      OutlinedButton.icon(
                        onPressed: () => _openNavigation(
                          complaint.locationLat,
                          complaint.locationLng,
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('Navigate to Site'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      if (!isResolved) ...[
                        const SizedBox(height: 12),
                        if (isAssigned)
                          CustomButton(
                            label:     'Start Repair',
                            icon:      Icons.construction,
                            isLoading: _actionLoading,
                            onPressed: _actionLoading ? null : _startRepair,
                          ),
                        if (isInProgress)
                          CustomButton(
                            label: 'Upload Repair Completion',
                            icon:  Icons.check_circle_outline,
                            onPressed: () =>
                                context.push('/officer/repair/${widget.complaintId}'),
                          ),
                      ],

                      // Clear the floating bottom-nav bar (~100px).
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 8),
          ],
        ),
      );
}


class _VerChip extends StatelessWidget {
  const _VerChip({
    required this.icon,
    required this.count,
    required this.color,
    required this.label,
  });
  final IconData icon;
  final int count;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text('$count $label',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      );
}
