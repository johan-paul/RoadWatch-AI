import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../models/auth_models.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});
  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _fields     = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  String? _verificationId;
  bool _isVerifying = false;
  bool _isSending   = false;
  int  _resendTimer = 60;
  Timer? _timer;

  String get _otp => _fields.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _fields) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ── Firebase OTP ──────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    setState(() => _isSending = true);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.args.phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        await _signInWithCredential(cred);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isSending = false);
        _showError('OTP failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isSending      = false;
          _resendTimer    = 60;
        });
        _startTimer();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) { _showError('Enter the complete 6-digit OTP'); return; }
    if (_verificationId == null) { _showError('OTP not sent yet. Please wait.'); return; }

    setState(() => _isVerifying = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => _isVerifying = false);
      _showError('Invalid OTP: ${e.message}');
    } catch (e) {
      setState(() => _isVerifying = false);
      _showError(e.toString());
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken  = await userCred.user!.getIdToken();
      if (!mounted) return;

      final notifier = ref.read(authProvider.notifier);

      if (widget.args.mode == OtpMode.register) {
        await notifier.register(
          phone:           widget.args.phone,
          name:            widget.args.name!,
          firebaseIdToken: idToken!,
        );
      } else {
        await notifier.login(
          firebaseIdToken: idToken!,
          phone:           widget.args.phone,
        );
      }

      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        final role = authState.user!.role;
        context.go(role == 'officer' ? '/officer/home' : '/citizen/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendTimer <= 0) {
        _timer?.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
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

  void _onFieldChanged(int index, String value) {
    if (value.length == 1 && index < 5) _focusNodes[index + 1].requestFocus();
    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
    if (_otp.length == 6) _verifyOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.args.mode == OtpMode.register;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gradient background ─────────────────────────────────────────────
          Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),

          // ── Decorative circles ──────────────────────────────────────────────
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Header
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        // SMS icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(Icons.sms_rounded,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isRegister ? 'Verify & Register' : 'Verify your number',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.7)),
                            children: [
                              const TextSpan(text: 'Code sent to '),
                              TextSpan(
                                text: widget.args.phone,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
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
                          'Enter 6-digit OTP',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Check your SMS inbox for the code.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 28),

                        // OTP boxes or sending state
                        if (_isSending)
                          Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                const CircularProgressIndicator(
                                    color: AppColors.primary),
                                const SizedBox(height: 16),
                                Text(
                                  'Sending OTP to ${widget.args.phone}…',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          )
                        else ...[
                          // 6 OTP boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              6,
                              (i) => _OtpBox(
                                controller: _fields[i],
                                focusNode:  _focusNodes[i],
                                onChanged:  (v) => _onFieldChanged(i, v),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Verify button
                          CustomButton(
                            label:     'Verify OTP',
                            variant:   ButtonVariant.gradient,
                            onPressed: _isVerifying ? null : _verifyOtp,
                            isLoading: _isVerifying,
                            icon:      Icons.verified_rounded,
                          ),

                          const SizedBox(height: 20),

                          // Resend
                          Center(
                            child: _resendTimer > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined,
                                          size: 14,
                                          color: AppColors.textHint),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resend OTP in ${_resendTimer}s',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13),
                                      ),
                                    ],
                                  )
                                : GestureDetector(
                                    onTap: _sendOtp,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Resend OTP',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],

                        const SizedBox(height: 8),
                      ],
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

// ── OTP Box ───────────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: _focused
            ? AppColors.primary.withOpacity(0.07)
            : filled
                ? AppColors.surface
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.primary
              : filled
                  ? AppColors.primary.withOpacity(0.4)
                  : AppColors.divider,
          width: _focused ? 2 : 1.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode:  widget.focusNode,
        textAlign:  TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _focused ? AppColors.primary : AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
