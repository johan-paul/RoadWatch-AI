import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../features/citizen/models/complaint_model.dart';
import 'severity_badge.dart';
import 'status_badge.dart';

class ComplaintCard extends StatelessWidget {
  const ComplaintCard({
    super.key,
    required this.complaint,
    required this.onTap,
  });

  final ComplaintModel complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severityColor = AppColors.severityColor(complaint.severity);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: severityColor.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Severity colour stripe ──────────────────────────────────
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [severityColor, severityColor.withOpacity(0.5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // ── Thumbnail ────────────────────────────────────────────────
                CachedNetworkImage(
                  imageUrl: complaint.imageUrl,
                  width: 96,
                  height: 108,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 96,
                    height: 108,
                    color: AppColors.surface,
                    child: const Icon(Icons.image_outlined,
                        color: AppColors.textHint, size: 28),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 96,
                    height: 108,
                    color: AppColors.surface,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textHint, size: 28),
                  ),
                ),

                // ── Details ──────────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badges row
                        Row(
                          children: [
                            SeverityBadge(complaint.severity, small: true),
                            const SizedBox(width: 6),
                            StatusBadge(complaint.status, small: true),
                          ],
                        ),

                        // Damage type
                        Text(
                          AppFormatters.damageLabel(complaint.damageType),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Address
                        if (complaint.locationAddress != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 11, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  complaint.locationAddress!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Time + confirmations
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 11, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              AppFormatters.timeAgo(complaint.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textHint),
                            ),
                            const Spacer(),
                            if (complaint.confirmationCount > 0) ...[
                              Icon(Icons.thumb_up_rounded,
                                  size: 11,
                                  color: AppColors.success.withOpacity(0.8)),
                              const SizedBox(width: 3),
                              Text(
                                '${complaint.confirmationCount}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.success.withOpacity(0.8),
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Arrow ────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.only(right: 10),
                  alignment: Alignment.center,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
