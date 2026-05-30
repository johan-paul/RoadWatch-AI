import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.small = false});

  final String? status;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(status);
    final label = AppFormatters.statusLabel(status);
    final fSize = small ? 10.0 : 11.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical:   small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
