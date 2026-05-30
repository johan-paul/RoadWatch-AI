import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Primary gradient (purple → blue) ─────────────────────────────────────
  static const Color primary      = Color(0xFF6C63FF);
  static const Color primaryDark  = Color(0xFF4A3FCC);
  static const Color primaryLight = Color(0xFF9D97FF);

  // ── Citizen accent (coral → orange) ──────────────────────────────────────
  static const Color citizen      = Color(0xFFFF6584);
  static const Color citizenLight = Color(0xFFFFF0F3);

  // ── Officer accent (teal → cyan) ─────────────────────────────────────────
  static const Color officer      = Color(0xFF00C9A7);
  static const Color officerLight = Color(0xFFE6FBF7);

  // ── Alerts ────────────────────────────────────────────────────────────────
  static const Color accent   = Color(0xFF6C63FF);
  static const Color warning  = Color(0xFFFF9F43);
  static const Color danger   = Color(0xFFFF4757);
  static const Color success  = Color(0xFF2ED573);
  static const Color info     = Color(0xFF45B7D1);

  // ── Neutral surfaces ──────────────────────────────────────────────────────
  static const Color surface       = Color(0xFFF5F3FF);
  static const Color cardBg        = Colors.white;
  static const Color divider       = Color(0xFFEEECFF);
  static const Color textPrimary   = Color(0xFF1A1446);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint      = Color(0xFFB8B5CC);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF3A1FCC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient citizenHeaderGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF3ECFDE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient officerHeaderGradient = LinearGradient(
    colors: [Color(0xFF0F3460), Color(0xFF00C9A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient reportGradient = LinearGradient(
    colors: [Color(0xFFFF6584), Color(0xFFFF9A44)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient mapGradient = LinearGradient(
    colors: [Color(0xFF45B7D1), Color(0xFF6C63FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient successGradient = LinearGradient(
    colors: [Color(0xFF2ED573), Color(0xFF1CB960)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Severity ─────────────────────────────────────────────────────────────
  static const Color severityHigh   = Color(0xFFFF4757);
  static const Color severityMedium = Color(0xFFFF9F43);
  static const Color severityLow    = Color(0xFF2ED573);

  static Color severityColor(String? severity) => switch (severity) {
        'high'   => severityHigh,
        'medium' => severityMedium,
        'low'    => severityLow,
        _        => textSecondary,
      };

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color statusPending    = Color(0xFFFF9F43);
  static const Color statusAssigned   = Color(0xFF6C63FF);
  static const Color statusInProgress = Color(0xFF45B7D1);
  static const Color statusResolved   = Color(0xFF2ED573);
  static const Color statusRejected   = Color(0xFFFF4757);
  static const Color statusDuplicate  = Color(0xFFB8B5CC);

  static Color statusColor(String? status) => switch (status) {
        'pending'     => statusPending,
        'assigned'    => statusAssigned,
        'in_progress' => statusInProgress,
        'resolved'    => statusResolved,
        'rejected'    => statusRejected,
        'duplicate'   => statusDuplicate,
        _             => textSecondary,
      };
}
