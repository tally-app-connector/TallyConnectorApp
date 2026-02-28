import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'utils/secure_storage.dart';

void main() {
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
    await Future.delayed(const Duration(seconds: 2)); // Splash delay

    final isLoggedIn = await SecureStorage.isLoggedIn();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isLoggedIn ? const HomeScreen() : const LoginScreen(),
        ),
      );
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