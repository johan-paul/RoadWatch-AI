class RepairVerificationResult {
  const RepairVerificationResult({
    required this.aiVerified,
    required this.aiVerificationScore,
    required this.reason,
    required this.message,
  });

  final bool   aiVerified;
  final double aiVerificationScore;
  final String reason;
  final String message;

  factory RepairVerificationResult.fromJson(Map<String, dynamic> json) =>
      RepairVerificationResult(
        aiVerified:           json['ai_verified']           as bool?   ?? false,
        aiVerificationScore:  (json['ai_verification_score'] as num?)?.toDouble() ?? 0.0,
        reason:               json['reason']                as String? ?? '',
        message:              json['message']               as String? ?? '',
      );
}

class OfficerStats {
  const OfficerStats({
    required this.totalAssigned,
    required this.inProgress,
    required this.resolvedThisMonth,
    required this.avgResolutionDays,
    required this.pendingHighPriority,
  });

  final int totalAssigned;
  final int inProgress;
  final int resolvedThisMonth;
  final double avgResolutionDays;
  final int pendingHighPriority;

  factory OfficerStats.fromJson(Map<String, dynamic> json) => OfficerStats(
        totalAssigned:      json['total_assigned']        as int? ?? 0,
        inProgress:         json['in_progress']           as int? ?? 0,
        resolvedThisMonth:  json['resolved_this_month']   as int? ?? 0,
        avgResolutionDays:  (json['avg_resolution_days']  as num?)?.toDouble() ?? 0.0,
        pendingHighPriority: json['pending_high_priority'] as int? ?? 0,
      );
}
