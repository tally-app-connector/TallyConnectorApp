import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../utils/message_helper.dart';
import '../../widgets/custom_text_field.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';
import '../home/home_screen.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
   if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  final result = await AuthService.login(
    email: _emailController.text.trim(),
    password: _passwordController.text,
  );

  // Debug print
  print('Login result: $result');
  print('Success: ${result['success']}');
  print('User data: ${result['user']}');

  setState(() => _isLoading = false);

  if (result['success'] == true) {
    // Safely get user data
    final user = result['user'] as Map<String, dynamic>?;
    
    if (user == null) {
      MessageHelper.showError(context, "Failed to load user data");
      return;
    }
    
    final isVerified = user['is_verified'] as bool? ?? false;

    MessageHelper.showSuccess(context, "Login successful!");

    // Wait a moment for the message to show
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (!isVerified) {
      // Show verification prompt
      _showVerificationPrompt();
    } else {
      // Go to home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
            Icon(Icons.warning_amber, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Email Not Verified'),
          ],
        ),
        content: const Text(
          'Your email is not verified yet. Would you like to verify it now?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
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
                  // Logo
                  Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Tally Connector',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back! Login to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    validator: Validators.validatePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Signup link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
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