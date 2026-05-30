import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../models/auth_models.dart';
import '../providers/auth_provider.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  String _countryCode = '+91';
  bool _isLoading = false;

  static const _countryCodes = [
    ('+91', '🇮🇳 India (+91)'),
    ('+1',  '🇺🇸 USA (+1)'),
    ('+44', '🇬🇧 UK (+44)'),
    ('+61', '🇦🇺 Australia (+61)'),
    ('+971','🇦🇪 UAE (+971)'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String get _fullPhone =>
      '$_countryCode${_phoneCtrl.text.trim().replaceAll(RegExp(r'\s'), '')}';

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authProvider.notifier).checkPhone(_fullPhone);
      if (!mounted) return;

      if (result.isSuspended) {
        _showSuspendedDialog();
        return;
      }

      if (result.isNew) {
        context.push('/auth/register', extra: _fullPhone);
      } else {
        context.push('/auth/otp', extra: OtpArgs(phone: _fullPhone, mode: OtpMode.login));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuspendedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Account Suspended'),
          ],
        ),
        content: const Text(
          'Your account has been suspended. Please contact your administrator for assistance.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full gradient background ────────────────────────────────────────
          Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),

          // ── Decorative circles ──────────────────────────────────────────────
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -60,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // ── Scrollable content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Header area with logo + title
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.remove_road_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome to',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'RoadWatch AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Report road hazards and track repairs\nin your neighbourhood.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // White curved card
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          const Text(
                            'Enter your phone number',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "We'll send you a one-time verification code.",
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),

                          // Country code + phone number
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Country code button
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _countryCode,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    borderRadius: BorderRadius.circular(14),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 20, color: AppColors.textSecondary),
                                    items: _countryCodes
                                        .map((c) => DropdownMenuItem(
                                              value: c.$1,
                                              child: Text(c.$2,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _countryCode = v!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Phone field
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: '98765 43210',
                                    prefixIcon: Icon(
                                        Icons.phone_rounded,
                                        size: 20,
                                        color: AppColors.primary),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Enter your phone number';
                                    }
                                    if (v.trim().length < 7) {
                                      return 'Enter a valid phone number';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _continue(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Continue button
                          CustomButton(
                            label: 'Continue',
                            variant: ButtonVariant.gradient,
                            onPressed: _continue,
                            isLoading: _isLoading,
                            icon: Icons.arrow_forward_rounded,
                          ),

                          const SizedBox(height: 20),

                          // Info note
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: AppColors.primary.withOpacity(0.15)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: AppColors.primary, size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Citizens can self-register. Officer accounts are created by the admin.',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
