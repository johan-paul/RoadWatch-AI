import 'package:intl/intl.dart';

abstract final class AppFormatters {
  static final _dateTime = DateFormat('d MMM yyyy, h:mm a');
  static final _date     = DateFormat('d MMM yyyy');
  static final _time     = DateFormat('h:mm a');

  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());
  static String date(DateTime dt)     => _date.format(dt.toLocal());
  static String time(DateTime dt)     => _time.format(dt.toLocal());

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return date(dt);
  }

  static String severityLabel(String? s) => switch (s) {
        'high'   => 'High Risk',
        'medium' => 'Medium Risk',
        'low'    => 'Low Risk',
        _        => 'Unknown',
      };

  static String statusLabel(String? s) => switch (s) {
        'pending'     => 'Pending',
        'assigned'    => 'Assigned',
        'in_progress' => 'In Progress',
        'resolved'    => 'Resolved',
        'rejected'    => 'Rejected',
        'duplicate'   => 'Duplicate',
        _             => 'Unknown',
      };

  static String damageLabel(String? s) => switch (s) {
        'pothole'      => 'Pothole',
        'crack'        => 'Road Crack',
        'waterlogging' => 'Waterlogging',
        'damaged_road' => 'Damaged Road',
        'other'        => 'Other',
        _              => 'Road Damage',
      };
}
