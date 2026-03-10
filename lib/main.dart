import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/mobile/dashboard_screen.dart';
import 'screens/main.dart';
import 'screens/models/company_model.dart';
import 'database/database_helper.dart';
import 'utils/secure_storage.dart';
import 'services/auth_service.dart'; // ← ADD THIS

void main() async {                  // ← make async
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();          // ← ADD THIS
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    // Check both SecureStorage (local) AND Cognito session (cloud)
    final localLogin   = await SecureStorage.isLoggedIn();
    final cognitoLogin = await AuthService.isLoggedIn(); // ← ADD THIS
    final isLoggedIn   = localLogin && cognitoLogin;     // ← both must be true

    if (isLoggedIn) {
      await _initAppState();
    }

    if (mounted) {
      final bool isMobile = Platform.isAndroid || Platform.isIOS;
      final Widget homeScreen =
          isMobile ? const DashboardScreen() : const HomeScreen();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isLoggedIn ? homeScreen : const LoginScreen(),
        ),
      );
    }
  }

  Future<void> _initAppState() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final companyMaps = await db.query('companies');
      final companies = companyMaps.map((m) => Company.fromMap(m)).toList();
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 100,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 24),
            Text(
              'Tally Connector',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}