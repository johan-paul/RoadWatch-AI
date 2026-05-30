import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key, this.small = false});

  final String? severity;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color  = AppColors.severityColor(severity);
    final label  = AppFormatters.severityLabel(severity);
    final fSize  = small ? 10.0 : 11.0;
    final vPad   = small ? 2.0  : 4.0;
    final hPad   = small ? 6.0  : 10.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
