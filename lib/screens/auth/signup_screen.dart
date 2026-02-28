import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../utils/message_helper.dart';
import '../../widgets/custom_text_field.dart';
import 'email_verification_screen.dart';
import 'otp_verification_screen.dart';
import '../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.signup(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      MessageHelper.showSuccess(context, "Account created successfully!");

      // Wait a bit for the message to show
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Show verification options dialog
        _showVerificationOptionsDialog();
      }
    } else {
      MessageHelper.showError(
        context,
        result['message'] ?? 'Signup failed',
      );
    }
  }

  void _showVerificationOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Text('Verify Your Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose how you\'d like to verify your email address:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildVerificationOption(
              icon: Icons.email,
              title: 'Email Link',
              description: 'We\'ll send a verification link to your email',
            ),
            const SizedBox(height: 12),
            _buildVerificationOption(
              icon: Icons.pin,
              title: 'OTP Code',
              description: 'We\'ll send a 6-digit code to your email',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmailVerificationScreen(
                      email: _emailController.text.trim(),
                    ),
                  ),
                );
              }
            },
            child: const Text('Email Link'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              if (!mounted) return;
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => WillPopScope(
                  onWillPop: () async => false,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
              
              // Send OTP
              final result = await AuthService.sendOtp(
                _emailController.text.trim(),
              );
              
              if (!mounted) return;
              
              // Close loading
              Navigator.pop(context);
              
              if (result['success']) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtpVerificationScreen(
                      email: _emailController.text.trim(),
                    ),
                  ),
                );
              } else {
                MessageHelper.showError(
                  context,
                  result['message'] ?? 'Failed to send OTP',
                );
              }
            },
            child: const Text('OTP Code'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationOption({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon
                Icon(
                  Icons.person_add_alt_1,
                  size: 80,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Sign Up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account to get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Full Name
                CustomTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icons.person_outline,
                  validator: Validators.validateName,
                ),
                const SizedBox(height: 16),

                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),

                // Phone (Optional)
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone (Optional)',
                  hintText: 'Enter your phone number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.validatePhone,
                ),
                const SizedBox(height: 16),

                // Password
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
                const SizedBox(height: 16),

                // Confirm Password
                CustomTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Signup button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
                          'Sign Up',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}