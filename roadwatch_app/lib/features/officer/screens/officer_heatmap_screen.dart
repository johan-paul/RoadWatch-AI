import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../citizen/models/complaint_model.dart';
import '../providers/officer_provider.dart';

class OfficerHeatmapScreen extends ConsumerWidget {
  const OfficerHeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(officerHeatmapProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Hazard Heatmap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(officerHeatmapProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          async.when(
            loading: () => const _MapPlaceholder(),
            error:   (e, _) => Center(child: Text('Failed to load: $e')),
            data:    (points) => _OfficerMap(points: points),
          ),

          // Legend
          Positioned(
            bottom: 16,
            left:   16,
            child:  _Legend(),
          ),

          // Total count badge
          Positioned(
            top:   16,
            right: 16,
            child: async.maybeWhen(
              data:      (pts) => _CountBadge(count: pts.length),
              orElse:    () => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map ───────────────────────────────────────────────────────────────────────

class _OfficerMap extends StatelessWidget {
  const _OfficerMap({required this.points});
  final List<HeatmapPoint> points;

  Color _color(HeatmapPoint p) {
    if (p.weight >= 3.0) return AppColors.danger.withOpacity(0.7);
    if (p.weight >= 2.0) return AppColors.warning.withOpacity(0.7);
    return AppColors.success.withOpacity(0.7);
  }

  double _radius(HeatmapPoint p) {
    if (p.weight >= 3.0) return 22;
    if (p.weight >= 2.0) return 16;
    return 12;
  }

  @override
  Widget build(BuildContext context) {
    final centre = points.isEmpty
        ? const LatLng(20.5937, 78.9629)
        : LatLng(
            points.map((p) => p.lat).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.lng).reduce((a, b) => a + b) / points.length,
          );

    return FlutterMap(
      options: MapOptions(
        initialCenter: centre,
        initialZoom:   points.isEmpty ? 5 : 12,
      ),
      children: [
        TileLayer(
          urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.roadwatch.app',
        ),
        CircleLayer(
          circles: points
              .map((p) => CircleMarker(
                    point:             LatLng(p.lat, p.lng),
                    radius:            _radius(p),
                    color:             _color(p),
                    borderColor:       _color(p).withOpacity(0.9),
                    borderStrokeWidth: 2,
                  ))
              .toList(),
        ),
        // High-risk warning markers
        MarkerLayer(
          markers: points
              .where((p) => p.weight >= 3.0)
              .map((p) => Marker(
                    point: LatLng(p.lat, p.lng),
                    child: const Icon(
                      Icons.warning,
                      color: AppColors.danger,
                      size: 18,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(color: AppColors.divider),
          const Center(child: CircularProgressIndicator()),
        ],
      );
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.primary.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow:    const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              '$count hazards',
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ── Legend ────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  _Legend();

  static const _items = [
    ('High Risk',   AppColors.danger),
    ('Medium Risk', AppColors.warning),
    ('Low Risk',    AppColors.success),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow:    const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: _items
              .map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width:  12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: i.$2, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(i.$1,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );
}
