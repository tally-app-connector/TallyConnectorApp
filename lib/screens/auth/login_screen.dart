import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../utils/message_helper.dart';
import '../../utils/secure_storage.dart';
import '../../widgets/custom_text_field.dart';
import '../../database/database_helper.dart';
import '../../models/company_model.dart';
import '../../main.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final bool _isMobile = Platform.isAndroid || Platform.isIOS;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      debugPrint('Failed to init AppState after login: $e');
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final userMap = result['user'] as Map<String, dynamic>?;

      if (userMap == null) {
        MessageHelper.showError(context, "Failed to load user data");
        return;
      }

      // ✅ Save JWT token — isLoggedIn() in SplashScreen checks this
      final token = await AuthService.getAccessToken();
      if (token != null) await SecureStorage.saveToken(token);

      // ✅ Save full user JSON — matches User model fields
      await SecureStorage.saveUser(jsonEncode(userMap));

      final isVerified = userMap['is_verified'] as bool? ?? false;

      MessageHelper.showSuccess(context, "Login successful!");
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      if (!isVerified) {
        _showVerificationPrompt();
      } else {
        await _initAppState();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => AppShell(isMobile: _isMobile)),
          (route) => false,
        );
      }
    } else {
      MessageHelper.showError(
        context,
        result['message'] as String? ?? 'Login failed',
      );
    }
  }

  void _showVerificationPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.amber), // old: Colors.orange.shade700
            const SizedBox(width: 8),
            const Text('Email Not Verified'),
          ],
        ),
        content: const Text(
          'Your email is not verified yet. Would you like to verify it now?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _initAppState();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => AppShell(isMobile: _isMobile)),
                (route) => false,
              );
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => EmailVerificationScreen(
                    email: _emailController.text.trim(),
                  ),
                ),
                (route) => false,
              );
            },
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // old: default
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.account_balance_wallet, size: 80, color: AppColors.blue), // old: Colors.blue.shade700
                  const SizedBox(height: 16),
                  Text(
                    'Tally Connector',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.blue), // old: Colors.blue.shade700
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back! Login to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary), // old: Colors.grey.shade600
                  ),
                  const SizedBox(height: 40),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    validator: Validators.validatePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      ),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}