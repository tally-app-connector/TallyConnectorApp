import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../theme/app_theme.dart';
import '../../utils/message_helper.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;

  Future<void> _handleResendVerification() async {
    setState(() => _isResending = true);

    final result = await AuthService.resendVerification(widget.email);

    setState(() => _isResending = false);

    if (result['success']) {
      MessageHelper.showSuccess(context, result['message'] ?? 'Verification email sent!');
    } else {
      MessageHelper.showError(context, result['message'] ?? 'Failed to send email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Icon(
                  Icons.mark_email_unread,
                  size: 100,
                  color: AppColors.blue, // old: Colors.blue.shade700
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue, // old: Colors.blue.shade700
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  'We\'ve sent a verification link to:',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary, // old: Colors.grey.shade700
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Email
                Text(
                  widget.email,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue, // old: Colors.blue.shade700
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Next Steps:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('1. Check your email inbox'),
                        const SizedBox(height: 8),
                        const Text('2. Click the verification link'),
                        const SizedBox(height: 8),
                        const Text('3. Return to the app'),
                        const SizedBox(height: 12),
                        Text(
                          'Tip: Check your spam folder if you don\'t see the email',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary, // old: Colors.grey.shade600
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Resend button
                OutlinedButton.icon(
                  onPressed: _isResending ? null : _handleResendVerification,
                  icon: _isResending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isResending ? 'Sending...' : 'Resend Verification Email'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Skip for now button
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                  child: const Text('I\'ll verify later'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}