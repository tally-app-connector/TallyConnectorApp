import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../utils/secure_storage.dart';

class AuthService {
  // Signup
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.signup),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': fullName,
              'email': email,
              'password': password,
              'phone': phone,
            }),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Save token
        await SecureStorage.saveToken(data['access_token']);
        
        // Save user
        await SecureStorage.saveUser(jsonEncode(data['user']));

        return {'success': true, 'user': User.fromJson(data['user'])};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Signup failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

 // Login
static Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse(ApiConfig.login),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(ApiConfig.timeout);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');  // Debug print

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Save token
      await SecureStorage.saveToken(data['access_token'] as String);
      
      // Make sure user data is not null
      if (data['user'] != null) {
        await SecureStorage.saveUser(jsonEncode(data['user']));
        
        return {
          'success': true,
          'user': data['user'] as Map<String, dynamic>,
        };
      } else {
        return {
          'success': false,
          'message': 'User data not received from server'
        };
      }
    } else {
      return {
        'success': false,
        'message': data['detail'] ?? 'Login failed'
      };
    }
  } catch (e) {
    print('Login error: $e');  // Debug print
    return {'success': false, 'message': 'Connection error: $e'};
  }
}
  // Forgot Password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.forgotPassword),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Request failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Reset Password
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.resetPassword),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'new_password': newPassword,
            }),
          )
          .timeout(ApiConfig.timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Reset failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Get Current User
  static Future<User?> getCurrentUser() async {
    try {
      final token = await SecureStorage.getToken();
      if (token == null) return null;

      final response = await http
          .get(
            Uri.parse(ApiConfig.getCurrentUser),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      final token = await SecureStorage.getToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.logout),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      // Ignore errors on logout
    } finally {
      await SecureStorage.clearAll();
    }
  }

  // Add to existing auth_service.dart file

// Resend Verification Email
static Future<Map<String, dynamic>> resendVerification(String email) async {
  try {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.resendVerification}?email=$email'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {
        'success': false,
        'message': data['detail'] ?? 'Failed to resend verification'
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Connection error: $e'};
  }
}

// Send OTP
static Future<Map<String, dynamic>> sendOtp(String email) async {
  try {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.sendOtp}?email=$email'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {
        'success': false,
        'message': data['detail'] ?? 'Failed to send OTP'
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Connection error: $e'};
  }
}

// Verify OTP
static Future<Map<String, dynamic>> verifyOtp({
  required String email,
  required String otp,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.verifyOtp}?email=$email&otp=$otp'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(ApiConfig.timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {'success': true, 'message': data['message']};
    } else {
      return {
        'success': false,
        'message': data['detail'] ?? 'Invalid OTP'
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Connection error: $e'};
  }
}
}