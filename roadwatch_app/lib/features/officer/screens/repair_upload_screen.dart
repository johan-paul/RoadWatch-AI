import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../models/officer_models.dart';
import '../providers/officer_provider.dart';

class RepairUploadScreen extends ConsumerStatefulWidget {
  const RepairUploadScreen({super.key, required this.complaintId});
  final String complaintId;

  @override
  ConsumerState<RepairUploadScreen> createState() => _RepairUploadScreenState();
}

class _RepairUploadScreenState extends ConsumerState<RepairUploadScreen> {
  final _notesCtrl = TextEditingController();
  File? _afterImage;
  bool  _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
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
      source:       src,
      imageQuality: 80,
      maxWidth:     1280,
    );
    if (xFile == null) return;
    setState(() => _afterImage = File(xFile.path));
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_afterImage == null) {
      _showError('Please attach a photo of the completed repair.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final bytes    = await _afterImage!.readAsBytes();
      final filename = _afterImage!.path.split('/').last;
      final notes    = _notesCtrl.text.trim();

      final result = await ref.read(officerRepositoryProvider).completeRepair(
            complaintId:        widget.complaintId,
            afterImageBytes:    bytes,
            afterImageFilename: filename,
            notes:              notes.isEmpty ? null : notes,
          );

      // Refresh relevant providers
      ref.invalidate(officerComplaintDetailProvider(widget.complaintId));
      ref.read(officerComplaintsProvider.notifier).refresh();
      ref.invalidate(officerStatsProvider);

      if (!mounted) return;
      _showVerificationResult(result);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
      );

  void _showVerificationResult(RepairVerificationResult result) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true, // render above the shell's floating nav
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        isDismissible: false,
        builder: (_) => _RepairVerificationSheet(
          result:      result,
          onDone:      () {
            Navigator.pop(context);
            context.go('/officer/complaints');
          },
          onRetry:     result.aiVerified
              ? null
              : () => Navigator.pop(context),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Upload Repair Photo'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Upload a clear after-repair photo to mark this complaint as resolved.',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── After-repair photo ─────────────────────────────────────────
            const _SectionLabel('1. After-Repair Photo *'),
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _afterImage != null
                        ? AppColors.success
                        : AppColors.divider,
                    width: _afterImage != null ? 2 : 1,
                  ),
                ),
                child: _afterImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(_afterImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 52, color: AppColors.textHint),
                          SizedBox(height: 10),
                          Text(
                            'Tap to attach after-repair photo',
                            style:
                                TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Resolution notes ───────────────────────────────────────────
            const _SectionLabel('2. Resolution Notes (optional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines:   4,
              maxLength:  500,
              decoration: const InputDecoration(
                hintText:
                    'Describe what was done — filled pothole, resurfaced road…',
              ),
            ),

            const SizedBox(height: 28),

            // ── Submit ─────────────────────────────────────────────────────
            CustomButton(
              label:     'Mark as Resolved',
              icon:      Icons.check_circle_outline,
              isLoading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

// ── AI Repair Verification Bottom Sheet ──────────────────────────────────────

class _RepairVerificationSheet extends StatelessWidget {
  const _RepairVerificationSheet({
    required this.result,
    required this.onDone,
    this.onRetry,
  });

  final RepairVerificationResult result;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final verified = result.aiVerified;
    final color    = verified ? AppColors.success : AppColors.warning;
    final icon     = verified ? Icons.verified_rounded : Icons.warning_amber_rounded;
    final title    = verified ? 'Repair Verified! ✅' : 'Verification Needed';
    final score    = result.aiVerificationScore;

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

          // ── Icon ─────────────────────────────────────────────────────────
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 38),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          // ── AI Verification Score bar ─────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('AI Verification Score',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    Text('${(score * 100).round()}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  result.reason,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      height: 1.4),
                ),
              ],
            ),
          ),

          // ── Actions ───────────────────────────────────────────────────────
          CustomButton(
            label:     verified ? 'Done — Great Work!' : 'Back to Complaints',
            icon:      verified ? Icons.check_rounded : Icons.arrow_back,
            variant:   ButtonVariant.gradient,
            onPressed: onDone,
          ),

          if (onRetry != null) ...[
            const SizedBox(height: 10),
            CustomButton(
              label:     'Re-upload Photo',
              icon:      Icons.camera_alt_outlined,
              variant:   ButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
