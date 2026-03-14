// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'screens/auth/login_screen.dart';
// import 'screens/home/home_screen.dart';
// import 'screens/mobile/dashboard_screen.dart';
// import 'screens/main.dart';
// import 'screens/models/company_model.dart';
// import 'database/database_helper.dart';
// import 'utils/secure_storage.dart';
// import 'services/auth_service.dart'; // ← ADD THIS

// void main() async {                  // ← make async
//   WidgetsFlutterBinding.ensureInitialized();
//   await AuthService.init();          // ← ADD THIS
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Tally Connector',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         useMaterial3: true,
//       ),
//       home: const SplashScreen(),
//     );
//   }
// }

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({Key? key}) : super(key: key);

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _checkLoginStatus();
//   }

//   Future<void> _checkLoginStatus() async {
//     await Future.delayed(const Duration(seconds: 2));

//     // Check both SecureStorage (local) AND Cognito session (cloud)
//     final localLogin   = await SecureStorage.isLoggedIn();
//     final cognitoLogin = await AuthService.isLoggedIn(); // ← ADD THIS
//     final isLoggedIn   = localLogin && cognitoLogin;     // ← both must be true

//     if (isLoggedIn) {
//       await _initAppState();
//     }

//     if (mounted) {
//       final bool isMobile = Platform.isAndroid || Platform.isIOS;
//       final Widget homeScreen =
//           isMobile ? const DashboardScreen() : const HomeScreen();

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => isLoggedIn ? homeScreen : const LoginScreen(),
//         ),
//       );
//     }
//   }

//   Future<void> _initAppState() async {
//     try {
//       final db = await DatabaseHelper.instance.database;
//       final companyMaps = await db.query('companies');
//       final companies = companyMaps.map((m) => Company.fromMap(m)).toList();
//       AppState.companies = companies;

//       final savedGuid = await SecureStorage.getSelectedCompanyGuid();
//       if (savedGuid != null && savedGuid.isNotEmpty) {
//         final match = companies.where((c) => c.guid == savedGuid);
//         AppState.selectedCompany = match.isNotEmpty
//             ? match.first
//             : (companies.isNotEmpty ? companies.first : null);
//       } else if (companies.isNotEmpty) {
//         AppState.selectedCompany = companies.first;
//       }
//     } catch (e) {
//       debugPrint('Failed to init AppState: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.account_balance_wallet,
//               size: 100,
//               color: Colors.blue.shade700,
//             ),
//             const SizedBox(height: 24),
//             Text(
//               'Tally Connector',
//               style: TextStyle(
//                 fontSize: 32,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.blue.shade700,
//               ),
//             ),
//             const SizedBox(height: 32),
//             const CircularProgressIndicator(),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/mobile/dashboard_screen.dart';
import 'screens/main.dart';
import 'screens/models/company_model.dart';
import 'database/database_helper.dart';
import 'utils/secure_storage.dart';
import 'services/auth_service.dart';

// ── Navigation destination imports ────────────────────────────────────────────
import 'screens/desktop/setting_screen.dart';
import 'screens/mobile/database_overview_screen.dart';
import 'screens/home/analytics_dashboard.dart';
import 'screens/Analysis/analysis_home_screen.dart';
import 'screens/mobile/reports_overview_screen.dart';
import 'screens/mobile/mobile_profile_tab.dart';
import 'screens/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally Connector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash Screen
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  static const Color _primary = Color(0xFF1A6FD8);
  static const Color _accent  = Color(0xFF00C9A7);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));
    _animCtrl.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final localLogin   = await SecureStorage.isLoggedIn();
    final cognitoLogin = await AuthService.isLoggedIn();
    final isLoggedIn   = localLogin && cognitoLogin;

    if (isLoggedIn) {
      await _initAppState();
    }

    if (mounted) {
      final bool isMobile = Platform.isAndroid || Platform.isIOS;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLoggedIn
              ? AppShell(isMobile: isMobile)
              : const LoginScreen(),
        ),
      );
    }
  }

  Future<void> _initAppState() async {
    try {
      final db         = await DatabaseHelper.instance.database;
      final companyMaps = await db.query('companies');
      final companies  = companyMaps.map((m) => Company.fromMap(m)).toList();
      AppState.companies = companies;

      final savedGuid = await SecureStorage.getSelectedCompanyGuid();
      if (savedGuid != null && savedGuid.isNotEmpty) {
        final match = companies.where((c) => c.guid == savedGuid);
        AppState.selectedCompany = match.isNotEmpty
            ? match.first
            : (companies.isNotEmpty ? companies.first : null);
      } else if (companies.isNotEmpty) {
        AppState.selectedCompany = companies.first;
      }
    } catch (e) {
      debugPrint('Failed to init AppState: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo mark
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primary, _accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Tally Connector',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2340),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sync · Analyse · Report',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8A94A6),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _primary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppShell — persistent navigation wrapper
//
// Desktop/Windows: top TabBar inside an AppBar (scrollable tabs)
// Mobile (Android/iOS): BottomNavigationBar
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  final bool isMobile;
  const AppShell({Key? key, required this.isMobile}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {

  int _currentIndex = 0;
  TabController? _tabController;

  // ── Design tokens ────────────────────────────────────────────────────────────
  static const Color _primary   = Color(0xFF1A6FD8);
  static const Color _textMuted = Color(0xFF8A94A6);
  static const Color _cardBg    = Colors.white;

  // ── Desktop destinations (5 tabs in top TabBar) ──────────────────────────────
  static const List<_Dest> _desktopDestinations = [
    _Dest(Icons.home_rounded, 'Home'),
    _Dest(Icons.analytics_rounded, 'Analytics'),
    _Dest(Icons.home_work_rounded, 'Analysis'),
    _Dest(Icons.storage_rounded, 'Database'),
    _Dest(Icons.settings_rounded, 'Settings'),
  ];

  // ── Mobile destinations (3 tabs in bottom nav — same as Dashboard had) ────────
  static const List<_Dest> _mobileDestinations = [
    _Dest( Icons.home_rounded,             'Home'),
    _Dest( Icons.bar_chart_rounded,        'Reports'),
    _Dest( Icons.person_outline_rounded,   'Profile'),
  ];

  List<_Dest> get _destinations =>
      widget.isMobile ? _mobileDestinations : _desktopDestinations;

  @override
  void initState() {
    super.initState();
    // TabController only used on desktop
    if (!widget.isMobile) {
      _tabController = TabController(
          length: _desktopDestinations.length, vsync: this)
        ..addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _onTabChanged() {
    final tc = _tabController;
    if (tc == null || tc.indexIsChanging) return;
    setState(() => _currentIndex = tc.index);
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentIndex = index);
  }

  // ── Screens ───────────────────────────────────────────────────────────────────

  // Mobile: 0=DashboardHomePage, 1=ReportsOverviewScreen, 2=MobileProfileTab
  Widget _mobileScreenForIndex(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const ReportsOverviewScreen();
      case 2: return const MobileProfileTab();
      default: return const DashboardScreen();
    }
  }

  // Desktop: 0=HomeScreen, 1=Analytics, 2=Analysis, 3=Database, 4=Settings
  Widget _desktopScreenForIndex(int index) {
    switch (index) {
      case 0: return const HomeScreen();
      case 1: return AnalyticsDashboard();
      case 2: return AnalysisHomeScreen();
      case 3: return const DatabaseOverviewScreen();
      case 4: return const DesktopSettingsScreen();
      default: return const HomeScreen();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return widget.isMobile ? _buildMobileShell() : _buildDesktopShell();
  }

  // ── Desktop: AppBar + TabBar on top ──────────────────────────────────────────

  Widget _buildDesktopShell() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          // ── Shared TabBar strip ──────────────────────────────────────────
          Material(
            color: _cardBg,
            elevation: 1,
            shadowColor: Colors.black12,
            child: SafeArea(
              bottom: false,
              child: TabBar(
                controller: _tabController!,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicatorSize: TabBarIndicatorSize.label,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _primary.withOpacity(0.09),
                ),
                dividerColor: Colors.transparent,
                labelColor: _primary,
                unselectedLabelColor: _textMuted,
                tabs: _desktopDestinations.map((d) => _desktopTab(d)).toList(),
              ),
            ),
          ),
          // ── Screen content ───────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: List.generate(
                _desktopDestinations.length,
                (i) => _desktopScreenForIndex(i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopTab(_Dest d) {
    return Tab(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(d.icon, size: 17),
          const SizedBox(width: 6),
          Text(d.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildMobileShell() {
    const mobileCount = 3; // Home · Reports · Profile
    final clampedIndex = _currentIndex.clamp(0, mobileCount - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: clampedIndex,
        children: List.generate(
            mobileCount, (i) => _mobileScreenForIndex(i)),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(mobileCount, (i) {
                final d      = _mobileDestinations[i];
                final active = clampedIndex == i;
                return GestureDetector(
                  onTap: () => _onBottomNavTapped(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 7),
                    decoration: BoxDecoration(
                      color: active
                          ? _primary.withOpacity(0.09)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(d.icon,
                          size: 24,
                          color: active ? _primary : _textMuted),
                      const SizedBox(height: 3),
                      Text(
                        d.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active ? _primary : _textMuted,
                        ),
                      ),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Data class ─────────────────────────────────────────────────────────────────

class _Dest {
  final IconData icon;
  final String label;
  const _Dest(this.icon, this.label);
}