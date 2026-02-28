import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../../utils/message_helper.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  
  const OtpVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      MessageHelper.showError(context, 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() => _isVerifying = true);

    final result = await AuthService.verifyOtp(
      email: widget.email,
      otp: _otpController.text.trim(),
    );

    setState(() => _isVerifying = false);

    if (result['success']) {
      
MessageHelper.showSuccess(context, 'Email verified successfully!');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      MessageHelper.showError(context, result['message'] ?? 'Invalid OTP');
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() => _isResending = true);

    final result = await AuthService.sendOtp(widget.email);

    setState(() => _isResending = false);

    if (result['success']) {
      MessageHelper.showSuccess(context, 'New OTP sent to your email!');
    } else {
      MessageHelper.showError(context, result['message'] ?? 'Failed to send OTP');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
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
                  Icons.verified_user,
                  size: 100,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Enter Verification Code',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  'We\'ve sent a 6-digit code to:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
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
                    color: Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // OTP Input
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Verify button
                ElevatedButton(
                  onPressed: _isVerifying ? null : _handleVerifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 24),

                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Didn't receive the code? "),
                    TextButton(
                      onPressed: _isResending ? null : _handleResendOtp,
                      child: Text(_isResending ? 'Sending...' : 'Resend OTP'),
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