import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/complaint_model.dart';

class CitizenRepository {
  const CitizenRepository(this._client);
  final ApiClient _client;

  // ── Complaints ────────────────────────────────────────────────────────────

  Future<List<ComplaintModel>> getMyComplaints({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final res = await _client.get(
      ApiConstants.complaints,
      query: {
        'page':      page,
        'page_size': pageSize,
        if (status != null) 'status': status,
      },
    );
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ComplaintModel.fromJson).toList();
  }

  Future<ComplaintModel> getComplaint(String id) async {
    final res = await _client.get('${ApiConstants.complaints}/$id');
    return ComplaintModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ComplaintModel> submitComplaint({
    required double lat,
    required double lng,
    String? address,
    String? description,
    required List<int> imageBytes,
    required String imageFilename,
  }) async {
    final formData = FormData.fromMap({
      'location_lat': lat,
      'location_lng': lng,
      if (address != null)     'location_address': address,
      if (description != null) 'description':      description,
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: imageFilename,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });

    final res = await _client.postForm(ApiConstants.complaints, formData);
    return ComplaintModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> verifyComplaint({
    required String complaintId,
    required String response, // 'confirmed' | 'rejected'
    String? notes,
  }) async {
    await _client.post(
      '${ApiConstants.complaints}/$complaintId/verify',
      data: {
        'response': response,
        if (notes != null) 'notes': notes,
      },
    );
  }

  // ── Heatmap ───────────────────────────────────────────────────────────────

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
    final data = res.data as Map<String, dynamic>;
    final points = (data['points'] as List).cast<Map<String, dynamic>>();
    return points.map(HeatmapPoint.fromJson).toList();
  }
}
