class ComplaintModel {
  const ComplaintModel({
    required this.id,
    required this.citizenId,
    required this.locationLat,
    required this.locationLng,
    this.locationAddress,
    required this.imageUrl,
    this.videoUrl,
    this.description,
    this.damageType,
    this.severity,
    this.aiConfidenceScore,
    this.aiRiskScore,
    required this.status,
    this.assignedOfficerId,
    this.assignedOfficerName,
    this.assignedOfficerPhone,
    this.assignedAt,
    required this.isDuplicate,
    this.verifiedConfidenceScore,
    required this.confirmationCount,
    required this.rejectionCount,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String citizenId;
  final double locationLat;
  final double locationLng;
  final String? locationAddress;
  final String imageUrl;
  final String? videoUrl;
  final String? description;
  final String? damageType;     // pothole | crack | waterlogging | damaged_road | other
  final String? severity;       // low | medium | high
  final double? aiConfidenceScore;
  final double? aiRiskScore;
  final String status;           // pending | assigned | in_progress | resolved | rejected | duplicate
  final String? assignedOfficerId;
  final String? assignedOfficerName;
  final String? assignedOfficerPhone;
  final DateTime? assignedAt;
  final bool isDuplicate;
  final double? verifiedConfidenceScore;
  final int confirmationCount;
  final int rejectionCount;
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ComplaintModel.fromJson(Map<String, dynamic> json) => ComplaintModel(
        id:                      json['id'] as String,
        citizenId:               json['citizen_id'] as String,
        locationLat:             (json['location_lat'] as num).toDouble(),
        locationLng:             (json['location_lng'] as num).toDouble(),
        locationAddress:         json['location_address'] as String?,
        imageUrl:                json['image_url'] as String,
        videoUrl:                json['video_url'] as String?,
        description:             json['description'] as String?,
        damageType:              json['damage_type'] as String?,
        severity:                json['severity'] as String?,
        aiConfidenceScore:       (json['ai_confidence_score'] as num?)?.toDouble(),
        aiRiskScore:             (json['ai_risk_score'] as num?)?.toDouble(),
        status:                  json['status'] as String,
        assignedOfficerId:       json['assigned_officer_id']    as String?,
        assignedOfficerName:     json['assigned_officer_name']  as String?,
        assignedOfficerPhone:    json['assigned_officer_phone'] as String?,
        assignedAt: json['assigned_at'] != null
            ? DateTime.parse(json['assigned_at'] as String)
            : null,
        isDuplicate:             json['is_duplicate'] as bool? ?? false,
        verifiedConfidenceScore: (json['verified_confidence_score'] as num?)?.toDouble(),
        confirmationCount:       json['confirmation_count'] as int? ?? 0,
        rejectionCount:          json['rejection_count'] as int? ?? 0,
        resolutionNotes:         json['resolution_notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  bool get isResolved   => status == 'resolved';
  bool get isPending    => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isHighRisk   => severity == 'high';
}

class HeatmapPoint {
  const HeatmapPoint({
    required this.lat,
    required this.lng,
    required this.weight,
    required this.complaintId,
    required this.status,
  });

  final double lat;
  final double lng;
  final double weight;
  final String complaintId;
  final String status;

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) => HeatmapPoint(
        lat:         (json['lat']    as num).toDouble(),
        lng:         (json['lng']    as num).toDouble(),
        weight:      (json['weight'] as num).toDouble(),
        complaintId: json['complaint_id'] as String,
        status:      json['status']       as String,
      );
}
