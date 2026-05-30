import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Reusable AI Analysis card shown on complaint detail screens
/// (citizen + officer). Pass null fields to hide those rows.
class AIAnalysisCard extends StatelessWidget {
  const AIAnalysisCard({
    super.key,
    required this.damageType,
    required this.severity,
    required this.confidenceScore,
    required this.riskScore,
    this.isDuplicate = false,
  });

  final String? damageType;
  final String? severity;
  final double? confidenceScore;
  final double? riskScore;
  final bool isDuplicate;

  @override
  Widget build(BuildContext context) {
    if (confidenceScore == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.07),
            AppColors.primary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.smart_toy_outlined,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Analysis',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Spacer(),
                _ConfidencePill(confidenceScore!),
              ],
            ),

            const SizedBox(height: 14),

            // ── Damage type ──────────────────────────────────────────────────
            if (damageType != null) ...[
              Row(
                children: [
                  Text(
                    _damageEmoji(damageType!),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _damageLabel(damageType!),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  // Risk-derived label — keeps the chip consistent with the
                  // Risk Score bar below. Showing the model's raw "high" severity
                  // here when overall risk is actually low (because confidence
                  // dilutes it) looks contradictory to the user.
                  if (riskScore != null) _RiskLevelChip(riskScore!),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // ── Confidence bar ───────────────────────────────────────────────
            _ScoreBar(
              label: 'AI Confidence',
              value: confidenceScore!,
              color: _confidenceColor(confidenceScore!),
            ),

            const SizedBox(height: 10),

            // ── Risk bar ─────────────────────────────────────────────────────
            if (riskScore != null)
              _ScoreBar(
                label: 'Risk Score',
                value: riskScore!,
                color: _riskColor(riskScore!),
              ),

            // ── Duplicate warning ────────────────────────────────────────────
            if (isDuplicate) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.content_copy,
                        size: 15, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Text(
                      'Marked as duplicate — similar complaint nearby.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Color _confidenceColor(double v) {
    if (v >= 0.70) return AppColors.success;
    if (v >= 0.45) return AppColors.warning;
    return AppColors.danger;
  }

  static Color _riskColor(double v) {
    if (v >= 0.70) return AppColors.danger;   // HIGH RISK   ≥ 70%
    if (v >= 0.50) return AppColors.warning;  // MEDIUM      50–70%
    return AppColors.success;                  // LOW         < 50%
  }

  static String _damageEmoji(String type) {
    switch (type) {
      case 'pothole':      return '🕳️';
      case 'crack':        return '⚡';
      case 'waterlogging': return '🌊';
      case 'damaged_road': return '🛣️';
      default:             return '⚠️';
    }
  }

  static String _damageLabel(String type) {
    switch (type) {
      case 'pothole':      return 'Pothole';
      case 'crack':        return 'Road Crack';
      case 'waterlogging': return 'Waterlogging';
      case 'damaged_road': return 'Damaged Road';
      default:             return 'Road Damage';
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill(this.value);
  final double value;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    Color color;
    if (value >= 0.70) {
      color = AppColors.success;
    } else if (value >= 0.45) {
      color = AppColors.warning;
    } else {
      color = AppColors.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$pct% sure',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Risk-level chip derived from the overall risk_score (0–1).
/// We deliberately use risk — NOT the model's raw severity head — because
/// risk already factors in confidence, so the label always agrees with the
/// Risk Score bar shown below.
class _RiskLevelChip extends StatelessWidget {
  const _RiskLevelChip(this.riskScore);
  final double riskScore;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _bucket(riskScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label RISK',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  static (String, Color) _bucket(double v) {
    if (v >= 0.70) return ('HIGH',   AppColors.danger);   // ≥ 70%
    if (v >= 0.50) return ('MEDIUM', AppColors.warning);  // 50–70%
    return ('LOW', AppColors.success);                     // < 50%
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
