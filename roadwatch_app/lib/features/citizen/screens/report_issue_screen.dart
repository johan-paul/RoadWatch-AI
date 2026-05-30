import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/ai_analysis_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../data/citizen_repository.dart';
import '../models/complaint_model.dart';
import '../providers/citizen_provider.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _descCtrl   = TextEditingController();
  File?   _image;
  double? _lat, _lng;
  String? _address;
  bool _locating   = false;
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource src) async {
    final status = src == ImageSource.camera
        ? await Permission.camera.request()
        : await Permission.photos.request();

    if (!status.isGranted) {
      _showError('Permission denied. Please allow access in Settings.');
      return;
    }

    final xFile = await ImagePicker().pickImage(
      source: src,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (xFile == null) return;
    setState(() => _image = File(xFile.path));
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
              ),
              title: const Text('Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Use your camera', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.photo_library_rounded, color: AppColors.info),
              ),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Select existing photo',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });

      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            _address = [
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea
            ].where((s) => s != null && s.isNotEmpty).join(', ');
          });
        }
      } catch (_) {}
    } catch (e) {
      _showError('Could not get location: $e');
    } finally {
      setState(() => _locating = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_image == null) {
      _showError('Please attach a photo of the road damage.');
      return;
    }
    if (_lat == null) {
      _showError('Please detect your GPS location first.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final bytes    = await _image!.readAsBytes();
      final filename = _image!.path.split('/').last;

      final complaint = await ref.read(citizenRepositoryProvider).submitComplaint(
            lat:           _lat!,
            lng:           _lng!,
            address:       _address,
            description:   _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            imageBytes:    bytes,
            imageFilename: filename,
          );

      await ref.read(citizenComplaintsProvider.notifier).refresh();
      if (!mounted) return;
      _showSuccess(complaint);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );

  void _showSuccess(ComplaintModel complaint) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true, // render above the shell's floating nav
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (_) => _AIResultSheet(complaint: complaint),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Report Road Hazard'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Step 1: Photo ──────────────────────────────────────────────
            _StepLabel(step: '1', label: 'Attach Photo', required: true),
            const SizedBox(height: 8),
            _PhotoPicker(
              image: _image,
              onTap: _showImageSourceSheet,
            ),

            const SizedBox(height: 22),

            // ── Step 2: Location ───────────────────────────────────────────
            _StepLabel(step: '2', label: 'GPS Location', required: true),
            const SizedBox(height: 8),
            _LocationPicker(
              lat: _lat,
              lng: _lng,
              address: _address,
              locating: _locating,
              onTap: _locating ? null : _getLocation,
            ),

            const SizedBox(height: 22),

            // ── Step 3: Description ────────────────────────────────────────
            _StepLabel(step: '3', label: 'Description', required: false),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText:
                    'Describe the damage — pothole, crack, waterlogging…',
              ),
            ),

            const SizedBox(height: 22),

            // ── Warning ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.warning.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only report genuine road hazards. False reports reduce your trust score and may lead to account suspension.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warning,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────────
            CustomButton(
              label:     'Submit Report',
              variant:   ButtonVariant.gradient,
              onPressed: _submitting ? null : _submit,
              isLoading: _submitting,
              icon:      Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Label ────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.step,
    required this.label,
    required this.required,
  });
  final String step, label;
  final bool required;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          if (required) ...[
            const SizedBox(width: 4),
            const Text(
              '*',
              style:
                  TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      );
}

// ── Photo Picker ──────────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.image, required this.onTap});
  final File? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: image != null ? null : Colors.white,
          gradient: image == null
              ? null
              : LinearGradient(
                  colors: [
                    AppColors.success.withOpacity(0.05),
                    Colors.white
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: image != null
                ? AppColors.success
                : AppColors.divider,
            width: image != null ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: image != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(19),
                    child: Image.file(image!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  // Change photo overlay
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        size: 30, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to add photo',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Camera or Gallery',
                    style: TextStyle(
                        color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Location Picker ───────────────────────────────────────────────────────────

class _LocationPicker extends StatelessWidget {
  const _LocationPicker({
    required this.lat,
    required this.lng,
    required this.address,
    required this.locating,
    required this.onTap,
  });
  final double? lat, lng;
  final String? address;
  final bool locating;
  final VoidCallback? onTap;

  bool get _hasLocation => lat != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hasLocation
              ? AppColors.success.withOpacity(0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasLocation
                ? AppColors.success
                : locating
                    ? AppColors.primary
                    : AppColors.divider,
            width: _hasLocation || locating ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hasLocation
                    ? AppColors.success.withOpacity(0.12)
                    : locating
                        ? AppColors.primary.withOpacity(0.08)
                        : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: locating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : Icon(
                      _hasLocation
                          ? Icons.location_on_rounded
                          : Icons.my_location_rounded,
                      color: _hasLocation
                          ? AppColors.success
                          : AppColors.primary,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: locating
                  ? const Text(
                      'Detecting your location…',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    )
                  : _hasLocation
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              address ??
                                  '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Location detected ✓',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap to detect location',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Required for accurate reporting',
                              style: TextStyle(
                                  color: AppColors.textHint, fontSize: 11),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI Result Bottom Sheet ─────────────────────────────────────────────────────

class _AIResultSheet extends StatelessWidget {
  const _AIResultSheet({required this.complaint});
  final ComplaintModel complaint;

  @override
  Widget build(BuildContext context) {
    final hasAI = complaint.aiConfidenceScore != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Success icon ──────────────────────────────────────────────────
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 38),
          ),
          const SizedBox(height: 14),
          const Text(
            'Report Submitted! 🎉',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            hasAI
                ? 'AI has analysed your photo and assigned it to an officer.'
                : 'Your complaint is submitted and will be assigned shortly.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // ── AI Result Card ────────────────────────────────────────────────
          if (hasAI) ...[
            AIAnalysisCard(
              damageType:      complaint.damageType,
              severity:        complaint.severity,
              confidenceScore: complaint.aiConfidenceScore,
              riskScore:       complaint.aiRiskScore,
              isDuplicate:     complaint.isDuplicate,
            ),

            // Duplicate notice
            if (complaint.isDuplicate)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A similar complaint was already reported nearby. '
                        'Your report has been logged as a duplicate.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // ── Actions ───────────────────────────────────────────────────────
          CustomButton(
            label: 'View My Reports',
            variant: ButtonVariant.gradient,
            onPressed: () {
              Navigator.pop(context);
              context.go('/citizen/complaints');
            },
          ),
          const SizedBox(height: 10),
          CustomButton(
            label: 'Report Another',
            variant: ButtonVariant.outline,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

