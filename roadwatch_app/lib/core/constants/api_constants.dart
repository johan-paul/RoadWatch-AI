abstract final class ApiConstants {
  // ── Base URL ──────────────────────────────────────────────────────────────
  // Android emulator → 10.0.2.2 maps to host machine's localhost
  // iOS simulator   → localhost
  // Physical device → use your machine's LAN IP or deployed URL
  static const String baseUrl = 'http://10.60.38.116:8000/api/v1'; // ← laptop's WiFi IP (update if it changes)

  // ── Auth endpoints ────────────────────────────────────────────────────────
  static const String checkPhone = '/auth/check-phone';
  static const String login      = '/auth/login';
  static const String register   = '/auth/register';
  static const String refresh    = '/auth/refresh';
  static const String logout     = '/auth/logout';

  // ── Citizen endpoints ─────────────────────────────────────────────────────
  static const String citizenProfile = '/citizen/profile';
  static const String citizenAvatar  = '/citizen/profile/avatar';
  static const String citizenFcmToken = '/citizen/fcm-token';

  // ── Complaint endpoints ───────────────────────────────────────────────────
  static const String complaints = '/complaints';
  static const String heatmap    = '/complaints/map/heatmap';

  // ── Officer endpoints ─────────────────────────────────────────────────────
  static const String officerProfile    = '/officer/profile';
  static const String officerStats      = '/officer/stats';
  static const String officerComplaints = '/officer/complaints';
}
