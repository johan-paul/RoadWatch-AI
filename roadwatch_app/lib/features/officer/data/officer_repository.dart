import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../citizen/models/complaint_model.dart';
import '../models/officer_models.dart';

class OfficerRepository {
  const OfficerRepository(this._client);
  final ApiClient _client;

  // ── Assigned complaints ───────────────────────────────────────────────────

  Future<List<ComplaintModel>> getAssignedComplaints({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final res = await _client.get(
      ApiConstants.officerComplaints,
      query: {
        'page':      page,
        'page_size': pageSize,
        if (status != null) 'status': status,
      },
    );
    final data  = res.data as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ComplaintModel.fromJson).toList();
  }

  Future<ComplaintModel> getComplaint(String id) async {
    final res = await _client.get('${ApiConstants.complaints}/$id');
    return ComplaintModel.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Start repair ──────────────────────────────────────────────────────────

  Future<void> startRepair(String complaintId) async {
    await _client.post(
      '${ApiConstants.officerComplaints}/$complaintId/start',
      data: {},
    );
  }

  // ── Complete repair ───────────────────────────────────────────────────────

  /// Returns the AI repair verification result from the backend.
  Future<RepairVerificationResult> completeRepair({
    required String complaintId,
    required List<int> afterImageBytes,
    required String afterImageFilename,
    String? notes,
  }) async {
    final formData = FormData.fromMap({
      if (notes != null) 'notes': notes,
      'after_image': MultipartFile.fromBytes(
        afterImageBytes,
        filename: afterImageFilename,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final res = await _client.postForm(
      '${ApiConstants.officerComplaints}/$complaintId/complete',
      formData,
    );
    return RepairVerificationResult.fromJson(
        res.data as Map<String, dynamic>);
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<OfficerStats> getStats() async {
    final res  = await _client.get(ApiConstants.officerStats);
    return OfficerStats.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Heatmap (reuse citizen endpoint — officers see all complaints) ─────────

  Future<List<HeatmapPoint>> getHeatmap({
    double? minLat, double? maxLat,
    double? minLng, double? maxLng,
  }) async {
    final res = await _client.get(
      ApiConstants.heatmap,
      query: {
        if (minLat != null) 'min_lat': minLat,
        if (maxLat != null) 'max_lat': maxLat,
        if (minLng != null) 'min_lng': minLng,
        if (maxLng != null) 'max_lng': maxLng,
      },
    );
    final data   = res.data as Map<String, dynamic>;
    final points = (data['points'] as List).cast<Map<String, dynamic>>();
    return points.map(HeatmapPoint.fromJson).toList();
  }
}
