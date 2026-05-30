import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants/app_colors.dart';
import 'features/auth/models/auth_models.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/auth/screens/phone_entry_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/citizen/screens/citizen_home_screen.dart';
import 'features/citizen/screens/citizen_profile_screen.dart';
import 'features/citizen/screens/complaint_detail_screen.dart';
import 'features/citizen/screens/heatmap_screen.dart';
import 'features/citizen/screens/my_complaints_screen.dart';
import 'features/citizen/screens/report_issue_screen.dart';
import 'features/officer/screens/assigned_complaints_screen.dart';
import 'features/officer/screens/officer_complaint_detail_screen.dart';
import 'features/officer/screens/officer_heatmap_screen.dart';
import 'features/officer/screens/officer_home_screen.dart';
import 'features/officer/screens/officer_profile_screen.dart';
import 'features/officer/screens/repair_upload_screen.dart';

// ── Router notifier ───────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    if (auth.isLoading) return null;

    final loc             = state.matchedLocation;
    final isAuthRoute     = loc.startsWith('/auth') || loc == '/splash';
    final isAuthenticated = auth.isAuthenticated;

    if (!isAuthenticated) {
      return isAuthRoute ? null : '/auth/phone';
    }
    if (isAuthRoute) {
      return auth.user!.isOfficer ? '/officer/home' : '/citizen/home';
    }
    if (auth.user!.isCitizen && loc.startsWith('/officer')) return '/citizen/home';
    if (auth.user!.isOfficer && loc.startsWith('/citizen')) return '/officer/home';
    return null;
  }
}

final _routerNotifierProvider = ChangeNotifierProvider<_RouterNotifier>((ref) {
  return _RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneEntryScreen()),
      GoRoute(
        path: '/auth/register',
        builder: (_, state) => RegisterScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (_, state) => OtpScreen(args: state.extra as OtpArgs),
      ),

      // ── Citizen shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) =>
            CitizenShell(child: child, location: state.matchedLocation),
        routes: [
          GoRoute(path: '/citizen/home',       builder: (_, __) => const CitizenHomeScreen()),
          GoRoute(path: '/citizen/report',     builder: (_, __) => const ReportIssueScreen()),
          GoRoute(path: '/citizen/complaints', builder: (_, __) => const MyComplaintsScreen()),
          GoRoute(
            path: '/citizen/complaints/:id',
            builder: (_, state) =>
                ComplaintDetailScreen(complaintId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/citizen/map',     builder: (_, __) => const HeatmapScreen()),
          GoRoute(path: '/citizen/profile', builder: (_, __) => const CitizenProfileScreen()),
        ],
      ),

      // ── Officer shell ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) =>
            OfficerShell(child: child, location: state.matchedLocation),
        routes: [
          GoRoute(path: '/officer/home',       builder: (_, __) => const OfficerHomeScreen()),
          GoRoute(path: '/officer/complaints', builder: (_, __) => const AssignedComplaintsScreen()),
          GoRoute(
            path: '/officer/complaints/:id',
            builder: (_, state) =>
                OfficerComplaintDetailScreen(complaintId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/officer/repair/:id',
            builder: (_, state) =>
                RepairUploadScreen(complaintId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/officer/map',     builder: (_, __) => const OfficerHeatmapScreen()),
          GoRoute(path: '/officer/profile', builder: (_, __) => const OfficerProfileScreen()),
        ],
      ),
    ],
  );
});

// ── App ───────────────────────────────────────────────────────────────────────

class RoadWatchApp extends ConsumerWidget {
  const RoadWatchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return MaterialApp.router(
      title: 'RoadWatch AI',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildTheme() {
    final base = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      useMaterial3: true,
      textTheme: base,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.citizen,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}

// ── Citizen Shell ─────────────────────────────────────────────────────────────

class CitizenShell extends StatefulWidget {
  const CitizenShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  static const _tabs = [
    '/citizen/home',
    '/citizen/report',
    '/citizen/complaints',
    '/citizen/map',
    '/citizen/profile',
  ];
  static const _icons = [
    Icons.home_rounded,
    Icons.add_circle_rounded,
    Icons.receipt_long_rounded,
    Icons.map_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Home', 'Report', 'Reports', 'Map', 'Profile'];

  bool _navVisible = true;

  bool _onScroll(UserScrollNotification n) =>
      _handleNavScroll(n, () => _navVisible, (v) => setState(() => _navVisible = v));

  @override
  void didUpdateWidget(covariant CitizenShell old) {
    super.didUpdateWidget(old);
    // Reveal the nav again whenever the user switches tabs.
    if (old.location != widget.location && !_navVisible) {
      setState(() => _navVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _tabs.indexWhere((t) => widget.location.startsWith(t));
    final active = idx < 0 ? 0 : idx;
    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
      extendBody: true,
      bottomNavigationBar: _AnimatedNavWrapper(
        visible: _navVisible,
        child: _FloatingNav(
          tabs: _tabs,
          icons: _icons,
          labels: _labels,
          activeIndex: active,
          activeColor: AppColors.primary,
          accentColor: AppColors.citizen,
          isReport: (i) => i == 1,
        ),
      ),
    );
  }
}

// ── Shared scroll-direction handler ─────────────────────────────────────────────
// Hides the nav when scrolling DOWN (reading content), shows it when scrolling UP.
bool _handleNavScroll(
  UserScrollNotification n,
  bool Function() isVisible,
  void Function(bool) setVisible,
) {
  if (n.metrics.axis != Axis.vertical) return false;
  // Don't hide if the content isn't actually scrollable (short pages).
  if (n.metrics.maxScrollExtent < 100) {
    if (!isVisible()) setVisible(true);
    return false;
  }
  if (n.direction == ScrollDirection.reverse && isVisible()) {
    setVisible(false);
  } else if (n.direction == ScrollDirection.forward && !isVisible()) {
    setVisible(true);
  }
  return false;
}

// ── Animated wrapper that slides + fades the floating nav in/out ────────────────
class _AnimatedNavWrapper extends StatelessWidget {
  const _AnimatedNavWrapper({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

// ── Officer Shell ─────────────────────────────────────────────────────────────

class OfficerShell extends StatefulWidget {
  const OfficerShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  State<OfficerShell> createState() => _OfficerShellState();
}

class _OfficerShellState extends State<OfficerShell> {
  static const _tabs = [
    '/officer/home',
    '/officer/complaints',
    '/officer/map',
    '/officer/profile',
  ];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.assignment_rounded,
    Icons.map_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Dashboard', 'Tasks', 'Map', 'Profile'];

  bool _navVisible = true;

  bool _onScroll(UserScrollNotification n) =>
      _handleNavScroll(n, () => _navVisible, (v) => setState(() => _navVisible = v));

  @override
  void didUpdateWidget(covariant OfficerShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location && !_navVisible) {
      setState(() => _navVisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _tabs.indexWhere((t) => widget.location.startsWith(t));
    final active = idx < 0 ? 0 : idx;
    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
      extendBody: true,
      bottomNavigationBar: _AnimatedNavWrapper(
        visible: _navVisible,
        child: _FloatingNav(
          tabs: _tabs,
          icons: _icons,
          labels: _labels,
          activeIndex: active,
          activeColor: AppColors.officer,
          accentColor: AppColors.officer,
          isReport: (_) => false,
        ),
      ),
    );
  }
}

// ── Floating Navigation Bar ───────────────────────────────────────────────────

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.tabs,
    required this.icons,
    required this.labels,
    required this.activeIndex,
    required this.activeColor,
    required this.accentColor,
    required this.isReport,
  });

  final List<String> tabs;
  final List<IconData> icons;
  final List<String> labels;
  final int activeIndex;
  final Color activeColor;
  final Color accentColor;
  final bool Function(int) isReport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (i) {
            final selected = i == activeIndex;
            final report   = isReport(i);

            if (report) {
              return GestureDetector(
                onTap: () => context.go(tabs[i]),
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.reportGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.citizen.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icons[i], color: Colors.white, size: 26),
                ),
              );
            }

            return GestureDetector(
              onTap: () => context.go(tabs[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 14 : 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? activeColor.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      color: selected ? activeColor : AppColors.textHint,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? activeColor : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
