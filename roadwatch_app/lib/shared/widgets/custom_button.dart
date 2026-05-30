import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum ButtonVariant { primary, gradient, outline, danger }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.width,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final ButtonVariant variant;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final w = width ?? double.infinity;

    if (variant == ButtonVariant.gradient) {
      return _GradientButton(
        label: label,
        icon: icon,
        isLoading: isLoading,
        onPressed: onPressed,
        width: w,
        height: height,
      );
    }

    return switch (variant) {
      ButtonVariant.primary => _PrimaryButton(
          label: label,
          icon: icon,
          isLoading: isLoading,
          onPressed: onPressed,
          width: w,
          height: height,
        ),
      ButtonVariant.outline => _OutlineButton(
          label: label,
          icon: icon,
          isLoading: isLoading,
          onPressed: onPressed,
          width: w,
          height: height,
        ),
      ButtonVariant.danger => _DangerButton(
          label: label,
          icon: icon,
          isLoading: isLoading,
          onPressed: onPressed,
          width: w,
          height: height,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    required this.width,
    required this.height,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? AppColors.primaryGradient
            : const LinearGradient(colors: [Color(0xFFB0B0B0), Color(0xFF909090)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: EdgeInsets.zero,
        ),
        child: _child(Colors.white),
      ),
    );
  }

  Widget _child(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      );
    }
    return Text(label,
        style:
            TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color));
  }
}

// ── Primary Button ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    required this.width,
    required this.height,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _child(Colors.white),
      ),
    );
  }

  Widget _child(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Text(label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
  }
}

// ── Outline Button ────────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.onPressed,
    required this.width,
    required this.height,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _child(AppColors.primary),
      ),
    );
  }

  Widget _child(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      );
    }
    return Text(label,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: color));
  }
}

// ── Danger Button ─────────────────────────────────────────────────────────────

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.onPressed,
    required this.width,
    required this.height,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _child(Colors.white),
      ),
    );
  }

  Widget _child(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Text(label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600));
  }
}
